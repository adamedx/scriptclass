# Copyright 2019, Adam Edwards
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function PatchedClassMethod_New(
    $classInfo,
    $methodName,
    $isStatic,
    $allInstances,
    $unpatchedMethodBlock,
    $patchedMethodBlock
) {
    $className = $classInfo.classDefinition.name
    $functionName = PatchedClassMethod_GetMockableMethodName $className $methodName $isStatic
    if ( $isStatic -and ! $allInstances ) {
        throw [ArgumentException]::new("Mocking of a static method was specified, but allInstances was $false")
    }

    [PSCustomObject] @{
        Id = $functionName
        FunctionName = $functionName
        ClassName = $className
        MethodName = $methodName
        IsStatic = $isStatic
        ClassInfo = $classInfo
        AllInstances = $allInstances
        PatchedObjects = @{}
        OriginalScriptBlock = $unpatchedMethodBlock
        ReplacementScriptBlock = $patchedMethodBlock
    }
}

function PatchedClassMethod_IsActive($patchedMethod, $object) {
    $isActive = $patchedMethod.AllInstances -or $patchedMethod.PatchedObjects.Count -gt 0

    if ( $isActive ) {
        if ( $object ) {
            $patchedMethod.PatchedObjects.Contains($object.__ScriptClassMockedObjectId())
        } else {
            $true
        }
    } else {
        $false
    }
}

function PatchedClassMethod_PatchObjectMethod($patchedMethod, $object) {
    $objectId = PatchedObject_GetUniqueId $object

    $patchedObject = PatchedObject_New $object

    $patchedMethod.PatchedObjects[$objectId] = $patchedObject
}

function PatchedClassMethod_GetPatchedObject($patchedMethod, $object) {
    $objectId = PatchedObject_GetUniqueId $object

    $patchedObject = $patchedMethod.PatchedObjects[$objectId]

    if ( ! $patchedObject ) {
        throw [ArgumentException]::new("The specified object is not patched or mocked")
    }

    $patchedObject
}

function PatchedClassMethod_GetMockedObjectScriptblock($patchedMethod, $object) {
    if ( $object | gm __ScriptClassMockedObjectId -erroraction ignore ) {
        $objectId = $object.__ScriptClassMockedObjectId()
        $patchedObject = if ( $objectId ) {
            $patchedMethod.PatchedObjects[$objectId]
        }

        if ( $patchedObject ) {
            $patchedObject.MockScriptBlock
        }
    }
}

function PatchedClassMethod_GetMockableMethodName(
    $className,
    $methodName,
    $isStatic
) {
    if ( ! $className ) {
        throw 'Specified class name may not be null'
    }

    $methodType = if ( $isStatic ) {
        'static'
    } else {
        'allinstances'
    }

    "__MockScriptClassMethod_$($methodType)_$($classname)_$($methodName)__"
}

function PatchedClassMethod_Patch($mockableMethod, $object) {
    if ( $mockableMethod.IsStatic ) {
        PatchedClassMethod_PatchStaticMethod $mockableMethod
    } else {
        PatchedClassMethod_PatchNonstaticMethod $mockableMethod

        if ( $object ) {
            PatchedClassMethod_PatchObjectMethod $mockableMethod $object
        }
    }
}

function PatchedClassMethod_PatchStaticMethod($mockFunctionInfo) {
    $mockFunctionInfo.classInfo.classDefinition.GetMethod($mockFunctionInfo.methodName, $true).block = $mockFunctionInfo.ReplacementScriptBlock
}

function PatchedClassMethod_PatchNonstaticMethod($mockFunctionInfo) {
    $mockFunctionInfo.classInfo.classDefinition.GetMethod($mockFunctionInfo.methodName, $false).block = $mockFunctionInfo.ReplacementScriptBlock
}

function PatchedClassMethod_UnpatchNonstaticMethod($patchedMethod) {
    $patchedMethod.AllInstances = $false
    if ( $patchedMethod.PatchedObjects.count -eq 0 ) {
        $patchedMethod.classInfo.classDefinition.GetMethod($patchedMethod.methodName, $false).block = $patchedMethod.OriginalScriptBlock
    }
}

function PatchedClassMethod_UnpatchObject($patchedMethod, $object) {
    if ( ! (PatchedObject_IsPatched $object) ) {
        throw [ArgumentException]::new("The specified object is not patched or mocked")
    }

    if ( ! (PatchedClassMethod_IsActive $patchedMethod $object) ) {
        throw [ArgumentException]::new("There are no mocked objects for the method '$($patchedMethod.methodName)'")
    }

    $objectId = $object.__ScriptClassMockedObjectId()

    $patchedMethod.PatchedObjects.Remove($objectId)

    if ( ! (PatchedClassMethod_IsActive $patchedMethod ) ) {
        $patchedMethod.classInfo.classDefinition.GetMethod($patchedMethod.methodName, $false).block = $patchedMethod.OriginalScriptBlock
    }

    $object | add-member -name __ScriptClassMockedObjectId -membertype scriptmethod -value {} -force
}

function PatchedClassMethod_UnpatchStaticMethod($patchedMethod) {
    $patchedMethod.classInfo.classDefinition.GetMethod($patchedMethod.methodName, $true).block = $patchedMethod.OriginalScriptBlock
}

function PatchedClassMethod_SetObjectMethod($object, $methodname, $originalScriptBlock) {
    $object | add-member -name $methodname -membertype scriptmethod -value $originalScriptblock -force
}

function PatchedClassMethod_Unpatch($patchedMethod, $object) {
    if ( $object ) {
        PatchedClassMethod_UnpatchObject $patchedMethod $object
    } elseif ( $patchedMethod.IsStatic ) {
        PatchedClassMethod_UnpatchStaticMethod $patchedMethod
    } else {
        PatchedClassMethod_UnpatchNonstaticMethod $patchedMethod
    }
}

