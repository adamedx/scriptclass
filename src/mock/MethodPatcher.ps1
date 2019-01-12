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

function __MethodPatcher_Get {
    $patcher = try {
        $script:__MethodPatcher_Singleton
    } catch {
    }

    if ( $patcher ) {
        return $script:__MethodPatcher_Singleton
    }

    $newPatcher = [PSCustomObject] @{
        Methods = @{}
        StaticMethodTemplate = $null
        NonstaticMethodTemplate = $null
    }

    $script:__MethodPatcher_Singleton = $newPatcher

    $newPatcher

    $newPatcher.StaticMethodTemplate =  @'
{0} @args
'@

    $newPatcher.NonstaticMethodTemplate = @'
set-strictmode -version 2
$__patchedMethod = __MethodPatcher_GetPatchedMethodByFunctionName (__MethodPatcher_Get) '{0}'
if ( $__patchedMethod ) {{
    $__objectMockScriptBlock = __PatchedClassMethod_GetMockedObjectScriptBlock $__patchedMethod $this
    if ( $__objectMockScriptBlock ) {{
        # Invoke the object-specific mock
        $__result = . $__objectMockScriptBlock @args
        return $__result
    }} else {{
        if ( ! $__patchedMethod.AllInstances ) {{
            # Invoke the original unmocked method
            $__result = . $__patchedMethod.OriginalScriptBlock @args
            return $__result
        }}
    }}
}}
# Invoke the all-instance mock of this method
{0} @args
'@
}

function __MethodPatcher_GetPatchedMethods($patcher) {
    $patcher.Methods.Values
}

function __MethodPatcher_QueryPatchedMethods($patcher, $className, $method, $staticMethods, $object) {
    $methodClass = $className
    $methodNames = if ( $method ) {
        @($method)
    } else {
        $classData = if ( $ClassName ) {
            __MethodPatcher_GetClassDefinition $patcher $className
        } else {
            __MethodPatcher_GetClassDefinition $patcher $object.scriptclass.classname
        }

        $methodClass = $classData.prototype.pstypename

        if ( $staticMethods ) {
            $classData.prototype.scriptclass.psobject.methods | select -expandproperty name
        } else {
            $classData.instancemethods.keys
        }
    }

    if ( $object ) {
        $methodClass = $object.scriptclass.classname
    }

    $patchedClassMethods = $methodNames | foreach {
        __MethodPatcher_GetMockableMethodFunction $patcher $methodClass $_ $staticMethods ($object -eq $null)
    }

    $patchedClassMethods
}

function __MethodPatcher_GetMockableMethodFunction(
    $patcher,
    $className,
    $methodName,
    $isStatic,
    $allInstances
) {
    $functionName = __PatchedClassMethod_GetMockableMethodName $className $methodName $isStatic

    $existingPatchMethod = __MethodPatcher_GetPatchedMethodByFunctionName $patcher $functionName

    if ( $existingPatchMethod ) {
        $existingPatchMethod
    } else {
        $classDefinition = __MethodPatcher_GetClassDefinition $className

        $originalMethodBlock = __MethodPatcher_GetClassMethod $classDefinition $methodName $isStatic

        $replacementMethodBlock = __MethodPatcher_CreateMethodPatchScriptBlock $patcher $functionName $isStatic

        new-item "function:script:$($functionName)" -value $originalMethodBlock -force | out-null

        $patchedClassMethod = __PatchedClassMethod_New $classDefinition $methodName $isStatic $allInstances $originalMethodBlock $replacementMethodBlock

        $patcher.Methods[$patchedClassMethod.FunctionName] = $patchedClassMethod

        $patchedClassMethod
    }
}

function __MethodPatcher_GetClassDefinition($className) {
    $classDefinition = $__classTable[$className]

    if ( ! $classDefinition ) {
        throw "The specified class '$className' was not found"
    }

    $classDefinition
}

function __MethodPatcher_GetClassMethod($classDefinition, $methodName, $isStatic) {
    $methodBlock = if ( $isStatic ) {
        $classDefinition.prototype.scriptclass.psobject.methods[$methodName].script
    } else {
        $classDefinition.instancemethods[$methodName]
    }

    if ( ! $methodBlock ) {
        throw "Method '$methodName', static='$isStatic', was not found for class '$($classDefinition.prototype.pstypename)'"
    }

    $methodBlock
}

function __MethodPatcher_CreateMethodPatchScriptBlock($patcher, $functionName, $isStatic ) {
    if ( $isStatic ) {
        [ScriptBlock]::Create($patcher.StaticMethodTemplate -f $functionName)
    } else {
        [ScriptBlock]::Create($patcher.NonstaticMethodTemplate -f $functionName)
    }
}

function __MethodPatcher_PatchMethod(
    $patcher,
    $className,
    $methodName,
    $isStatic,
    $object
) {
    $mockableMethod = __MethodPatcher_GetMockableMethodFunction $patcher $className $methodName $isStatic ($object -eq $null)

    __PatchedClassMethod_Patch $mockableMethod $object

    $mockableMethod
}

function __MethodPatcher_GetPatchedMethodByFunctionName($patcher, $functionName) {
    $patcher.Methods[$functionName]
}

function __MethodPatcher_Unpatch($patcher, $patchedMethod, $object) {
    __PatchedClassMethod_Unpatch $patchedMethod $object
    if ( ! ( __PatchedClassMethod_IsActive $patchedMethod ) ) {
        gi "function:$($_.functionname)" | remove-item
        $patcher.Methods.Remove($patchedMethod.functionname)
    }
}

