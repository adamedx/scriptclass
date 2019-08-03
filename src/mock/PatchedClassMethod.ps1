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

function __PatchedClassMethod_New(
    $classDefinition,
    $methodName,
    $isStatic,
    $allInstances,
    $unpatchedMethodBlock,
    $patchedMethodBlock
) {
    $className = $classDefinition.classDefinition.name
    $functionName = __PatchedClassMethod_GetMockableMethodName $className $methodName $isStatic
    if ( $isStatic -and ! $allInstances ) {
        throw [ArgumentException]::new("Mocking of a static method was specified, but allInstances was $false")
    }

    [PSCustomObject] @{
        Id = $functionName
        FunctionName = $functionName
        ClassName = $className
        MethodName = $methodName
        IsStatic = $isStatic
        ClassData = $classDefinition
        AllInstances = $allInstances
        PatchedObjects = @{}
        OriginalScriptBlock = $unpatchedMethodBlock
        ReplacementScriptBlock = $patchedMethodBlock
    }
}

function __PatchedClassMethod_IsActive($patchedMethod, $object) {
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

function __PatchedClassMethod_PatchObjectMethod($patchedMethod, $object) {
    $objectId = __PatchedObject_GetUniqueId $object

    $patchedObject = __PatchedObject_New $object

    $patchedMethod.PatchedObjects[$objectId] = $patchedObject
}

function __PatchedClassMethod_GetPatchedObject($patchedMethod, $object) {
    $objectId = __PatchedObject_GetUniqueId $object

    $patchedObject = $patchedMethod.PatchedObjects[$objectId]

    if ( ! $patchedObject ) {
        throw [ArgumentException]::new("The specified object is not patched or mocked")
    }

    $patchedObject
}

function __PatchedClassMethod_GetMockedObjectScriptblock($patchedMethod, $object) {
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

function __PatchedClassMethod_GetMockableMethodName(
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

function __PatchedClassMethod_Patch($mockableMethod, $object) {
    if ( $mockableMethod.IsStatic ) {
        __PatchedClassMethod_PatchStaticMethod $mockableMethod
    } else {
        __PatchedClassMethod_PatchNonstaticMethod $mockableMethod

        if ( $object ) {
            __PatchedClassMethod_PatchObjectMethod $mockableMethod $object
        }
    }
}

function __PatchedClassMethod_PatchStaticMethod($mockFunctionInfo) {
#    write-host -fore cyan before
#    $mockFunctionInfo.classData.prototype.scriptclass.psobject.methods | out-host
#    __PatchedClassMethod_SetObjectMethod $mockFunctionInfo.classData.prototype.scriptclass $mockFunctionInfo.methodname $mockFunctionInfo.ReplacementScriptblock
    $mockFunctionInfo.classData.classDefinition.GetMethod($mockFunctionInfo.methodName, $true).block = $mockFunctionInfo.ReplacementScriptBlock
#    write-host -fore cyan after
}

function __PatchedClassMethod_PatchNonstaticMethod($mockFunctionInfo) {
    $mockFunctionInfo.classData.classDefinition.GetMethod($mockFunctionInfo.methodName, $false).block = $mockFunctionInfo.ReplacementScriptBlock
}

function __PatchedClassMethod_UnpatchNonstaticMethod($patchedMethod) {
    $patchedMethod.AllInstances = $false
    if ( $patchedMethod.PatchedObjects.count -eq 0 ) {
        $patchedMethod.classData.classDefinition.GetMethod($patchedMethod.methodName, $false).block = $patchedMethod.OriginalScriptBlock
    }
}

function __PatchedClassMethod_UnpatchObject($patchedMethod, $object) {
    if ( ! (__PatchedObject_IsPatched $object) ) {
        throw [ArgumentException]::new("The specified object is not patched or mocked")
    }

    if ( ! (__PatchedClassMethod_IsActive $patchedMethod $object) ) {
        throw [ArgumentException]::new("There are no mocked objects for the method '$($patchedMethod.methodName)'")
    }

    $objectId = $object.__ScriptClassMockedObjectId()

    $patchedMethod.PatchedObjects.Remove($objectId)

    if ( ! (__PatchedClassMethod_IsActive $patchedMethod ) ) {
        $patchedMethod.classData.classDefinition.GetMethod($patchedMethod.methodName, $false).block = $patchedMethod.OriginalScriptBlock
    }

    $object | add-member -name __ScriptClassMockedObjectId -membertype scriptmethod -value {} -force
}

function __PatchedClassMethod_UnpatchStaticMethod($patchedMethod) {
    $patchedMethod.classData.classDefinition.GetMethod($patchedMethod.methodName, $true).block = $patchedMethod.OriginalScriptBlock
#    __PatchedClassMethod_SetObjectMethod $patchedMethod.classData.prototype.scriptclass $patchedMethod.methodname $patchedMethod.originalScriptblock

}

function __PatchedClassMethod_SetObjectMethod($object, $methodname, $originalScriptBlock) {
    $object | add-member -name $methodname -membertype scriptmethod -value $originalScriptblock -force
}

function __PatchedClassMethod_Unpatch($patchedMethod, $object) {
    if ( $object ) {
        __PatchedClassMethod_UnpatchObject $patchedMethod $object
    } elseif ( $patchedMethod.IsStatic ) {
        __PatchedClassMethod_UnpatchStaticMethod $patchedMethod
    } else {
        __PatchedClassMethod_UnpatchNonstaticMethod $patchedMethod
    }
}

