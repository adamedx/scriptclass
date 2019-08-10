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
    $patcherVariable = get-variable -scope script __MethodPatcher_Singleton -erroraction ignore

    $patcher = if ( $patcherVariable ) {
        $patcherVariable.value
    }

    if ( $patcher ) {
        return $script:__MethodPatcher_Singleton
    }

    $newPatcher = [PSCustomObject] @{
        PatchedClasses = @{}
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
        $__result = . ([ScriptBlock]::Create($__objectMockScriptBlock.tostring())) @args
        return $__result
    }} else {{
        if ( ! $__patchedMethod.AllInstances ) {{
            # Invoke the original unmocked method
            $__result = . ([ScriptBlock]::Create($__patchedMethod.OriginalScriptBlock.tostring())) @args
            return $__result
        }}
    }}
}}
# Invoke the all-instance mock of this method
{0} @args
'@
}

function __MethodPatcher_GetPatchedClass($patcher, $originalClassInfo) {
    $classInfo = $patcher.PatchedClasses[$originalClassInfo.classDefinition.name]

    if ( ! $classInfo ) {
        $classInfo = [ClassInfo]::New($originalClassInfo.classDefinition, $originalClassInfo.prototype, $originalClassInfo.module)
    }

    $classInfo
}

function __MethodPatcher_SetPatchedClass($patcher, $classInfo) {
    $patcher.PatchedClasses[$classInfo.classDefinition.name] = $classInfo
}

function __MethodPatcher_RemovePatchedClass($patcher, $className) {
    $patcher.PatchedClasses.Remove($className)
}

function __MethodPatcher_GetPatchedMethods($patcher) {
    $patcher.Methods.Values
}

function __MethodPatcher_QueryPatchedMethods($patcher, $className, $method, $staticMethods, $object) {
    $methodClass = $className
    $methodNames = if ( $method ) {
        @($method)
    } else {
        $classInfo = if ( $ClassName ) {
            __MethodPatcher_GetClassDefinition $patcher $className
        } else {
            __MethodPatcher_GetClassDefinition $patcher $object.scriptclass.classname
        }

        $methodClass = $classInfo.classDefinition.name

        if ( $staticMethods ) {
            $classInfo.prototype.scriptclass.psobject.methods | select -expandproperty name
        } else {
            $classInfo.classDefinition.GetInstanceMethods().name
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

function __MethodPatcher_GetClassModule($classInfo) {
    $classInfo.module
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
        $classModule = __MethodPatcher_GetClassModule $classDefinition

        $originalMethodBlock = __MethodPatcher_GetClassMethod $classDefinition $methodName $isStatic

        $replacementMethodBlock = __MethodPatcher_CreateMethodPatchScriptBlock $patcher $functionName $isStatic $classModule

        $newFunc = . $classModule.NewBoundScriptBlock({param($functionName, $originalMethodBlock) new-item "function:$functionName" -value $originalMethodBlock -force ; export-modulemember -function $functionName}) $functionName $originalMethodBlock

        $anotherfunc = . $classModule.NewBoundScriptBlock({param([object[]] $functions) $functions | foreach { new-item "function:$($_.name)" -value $_.scriptblock -force }} ) (get-item function:__MethodPatcher_Get, function:__MethodPatcher_GetPatchedMethodByFunctionName, function:__PatchedClassMethod_GetMockedObjectScriptBlock)

        $classInfo = __MethodPatcher_GetPatchedClass $patcher $classDefinition $classDefinition

        $patchedClassMethod = __PatchedClassMethod_New $classInfo $methodName $isStatic $allInstances $originalMethodBlock $replacementMethodBlock
        $patcher.Methods[$patchedClassMethod.FunctionName] = $patchedClassMethod

        $patchedClassMethod
    }
}

function __MethodPatcher_CreateScriptBlockInModule($module, $block) {
    if ( $module ) {
        $module.NewBoundScriptBlock($block)
    } else {
        $block
    }
}

function __MethodPatcher_GetClassDefinition($className) {
    $classInfo = [ClassManager]::Get().FindClassInfo($className)

    if ( ! $classInfo ) {
        throw "The specified class '$className' was not found"
    }

    $classInfo
}

function __MethodPatcher_GetClassMethod($classDefinition, $methodName, $isStatic) {
    $methodBlock = if ( $isStatic ) {
        $classDefinition.prototype.scriptclass.psobject.methods[$methodName].script
    } else {
        $method = $classDefinition.classDefinition.GetMethod($methodName, $false)
        if( $method ) {
            $method.block
        }
    }

    if ( ! $methodBlock ) {
        throw "Method '$methodName', static='$isStatic', was not found for class '$($classDefinition.classDefinition.name)'"
    }

    $methodBlock
}

function __MethodPatcher_CreateMethodPatchScriptBlock($patcher, $functionName, $isStatic, $module) {
    $newBlock = if ( $isStatic ) {
        [ScriptBlock]::Create($patcher.StaticMethodTemplate -f $functionName)
    } else {
        [ScriptBlock]::Create($patcher.NonstaticMethodTemplate -f $functionName)
    }

    __MethodPatcher_CreateScriptBlockInModule $module $newBlock
}

function __MethodPatcher_PatchMethod(
    $patcher,
    $className,
    $methodName,
    $isStatic,
    $object
) {
    $original = [ClassManager]::Get().GetClassInfo($className)

    $mockableMethod = __MethodPatcher_GetMockableMethodFunction $patcher $className $methodName $isStatic ($object -eq $null)

    __PatchedClassMethod_Patch $mockableMethod $object

    $newClassInfo = __MethodPatcher_RegisterMethodClassInfo $mockableMethod

    $mockableMethod.classInfo = $newClassInfo

    $mockableMethod
}

function __MethodPatcher_GetPatchedMethodByFunctionName($patcher, $functionName) {
    $patcher.Methods[$functionName]
}

function __MethodPatcher_Unpatch($patcher, $patchedMethod, $object) {
    __PatchedClassMethod_Unpatch $patchedMethod $object

    if ( ! ( __PatchedClassMethod_IsActive $patchedMethod ) ) {
        . $patchedMethod.originalscriptblock.module.newboundscriptblock({param($functionname) get-item "function:$functionname" | remove-item}) $patchedMethod.functionname

        $restoredClassInfo = __MethodPatcher_GetPatchedClass $patcher $patchedMethod.classInfo
        __MethodPatcher_RemovePatchedClass $patcher $restoredClassInfo.classDefinition.name
        $patcher.Methods.Remove($patchedMethod.functionname)
        [ClassManager]::Get().SetClass($restoredClassInfo)
    } else {
        __MethodPatcher_RegisterMethodClassInfo $patchedMethod | out-null
    }
}

function __MethodPatcher_RegisterMethodClassInfo($updatedMethod) {
    $classContext = [ClassDefinitionContext]::new($updatedMethod.classInfo.classDefinition, $updatedMethod.classInfo.module, $updatedMethod.classInfo.prototype.scriptclass.module)
    $classBuilder = [ScriptClassBuilder]::new($classContext)

    $newClassInfo = $classBuilder.ToClassInfo($null)
    $newStaticPrototype = $newClassInfo.prototype.scriptclass

    # The updated method's class prototype is correct for instance methods
    # but not for static methods, so we correct this before we register
    # the updated class information that includes the updated method

    $newClassInfo.prototype = $updatedMethod.classInfo.Prototype
    $newClassInfo.prototype.scriptclass = $newStaticPrototype

    [ClassManager]::Get().SetClass($newClassInfo)

    $newClassInfo
}
