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

function MethodPatcher_Get {
    $patcherVariable = get-variable -scope script MethodPatcher_Singleton -erroraction ignore

    $patcher = if ( $patcherVariable ) {
        $patcherVariable.value
    }

    if ( $patcher ) {
        return $script:MethodPatcher_Singleton
    }

    $newPatcher = [PSCustomObject] @{
        PatchedClasses = @{}
        Methods = @{}
        StaticMethodTemplate = $null
        NonstaticMethodTemplate = $null
    }

    $script:MethodPatcher_Singleton = $newPatcher

    $newPatcher

    $newPatcher.StaticMethodTemplate =  @'
{0} @args
'@

    $newPatcher.NonstaticMethodTemplate = @'
set-strictmode -version 2
$__patchedMethod = MethodPatcher_GetPatchedMethodByFunctionName (MethodPatcher_Get) '{0}'
if ( $__patchedMethod ) {{
    $__objectMockScriptBlock = PatchedClassMethod_GetMockedObjectScriptBlock $__patchedMethod $this
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

function MethodPatcher_GetPatchedClass($patcher, $originalClassInfo) {
    $classInfo = $patcher.PatchedClasses[$originalClassInfo.classDefinition.name]

    if ( ! $classInfo ) {
        $classInfo = [ClassInfo]::New($originalClassInfo.classDefinition, $originalClassInfo.prototype, $originalClassInfo.module)
    }

    $classInfo
}

function MethodPatcher_SetPatchedClass($patcher, $classInfo) {
    $patcher.PatchedClasses[$classInfo.classDefinition.name] = $classInfo
}

function MethodPatcher_RemovePatchedClass($patcher, $className) {
    $patcher.PatchedClasses.Remove($className)
}

function MethodPatcher_GetPatchedMethods($patcher) {
    $patcher.Methods.Values
}

function MethodPatcher_QueryPatchedMethods($patcher, $className, $method, $staticMethods, $object) {
    $methodClass = $className
    $methodNames = if ( $method ) {
        @($method)
    } else {
        $classInfo = if ( $ClassName ) {
            MethodPatcher_GetClassDefinition $patcher $className
        } else {
            MethodPatcher_GetClassDefinition $patcher $object.scriptclass.classname
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
        MethodPatcher_GetMockableMethodFunction $patcher $methodClass $_ $staticMethods ($object -eq $null)
    }

    $patchedClassMethods
}

function MethodPatcher_GetClassModule($classInfo) {
    $classInfo.module
}

function MethodPatcher_GetMockableMethodFunction(
    $patcher,
    $className,
    $methodName,
    $isStatic,
    $allInstances
) {
    $functionName = PatchedClassMethod_GetMockableMethodName $className $methodName $isStatic

    $existingPatchMethod = MethodPatcher_GetPatchedMethodByFunctionName $patcher $functionName

    if ( $existingPatchMethod ) {
        $existingPatchMethod
    } else {
        $classDefinition = MethodPatcher_GetClassDefinition $className
        $classModule = MethodPatcher_GetClassModule $classDefinition

        $originalMethodBlock = MethodPatcher_GetClassMethod $classDefinition $methodName $isStatic

        $replacementMethodBlock = MethodPatcher_CreateMethodPatchScriptBlock $patcher $functionName $isStatic $classModule

        $newFunc = . $classModule.NewBoundScriptBlock({param($functionName, $originalMethodBlock) new-item "function:$functionName" -value $originalMethodBlock -force ; export-modulemember -function $functionName}) $functionName $originalMethodBlock

        $anotherfunc = . $classModule.NewBoundScriptBlock({param([object[]] $functions) $functions | foreach { new-item "function:$($_.name)" -value $_.scriptblock -force }} ) (get-item function:MethodPatcher_Get, function:MethodPatcher_GetPatchedMethodByFunctionName, function:PatchedClassMethod_GetMockedObjectScriptBlock)

        $classInfo = MethodPatcher_GetPatchedClass $patcher $classDefinition $classDefinition

        $patchedClassMethod = PatchedClassMethod_New $classInfo $methodName $isStatic $allInstances $originalMethodBlock $replacementMethodBlock
        $patcher.Methods[$patchedClassMethod.FunctionName] = $patchedClassMethod

        $patchedClassMethod
    }
}

function MethodPatcher_CreateScriptBlockInModule($module, $block) {
    if ( $module ) {
        $module.NewBoundScriptBlock($block)
    } else {
        $block
    }
}

function MethodPatcher_GetClassDefinition($className) {
    $classInfo = [ClassManager]::Get().FindClassInfo($className)

    if ( ! $classInfo ) {
        throw "The specified class '$className' was not found"
    }

    $classInfo
}

function MethodPatcher_GetClassMethod($classDefinition, $methodName, $isStatic) {
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

function MethodPatcher_CreateMethodPatchScriptBlock($patcher, $functionName, $isStatic, $module) {
    $newBlock = if ( $isStatic ) {
        [ScriptBlock]::Create($patcher.StaticMethodTemplate -f $functionName)
    } else {
        [ScriptBlock]::Create($patcher.NonstaticMethodTemplate -f $functionName)
    }

    MethodPatcher_CreateScriptBlockInModule $module $newBlock
}

function MethodPatcher_PatchMethod(
    $patcher,
    $className,
    $methodName,
    $isStatic,
    $object
) {
    $original = [ClassManager]::Get().GetClassInfo($className)

    $mockableMethod = MethodPatcher_GetMockableMethodFunction $patcher $className $methodName $isStatic ($object -eq $null)

    PatchedClassMethod_Patch $mockableMethod $object

    $newClassInfo = MethodPatcher_RegisterMethodClassInfo $mockableMethod

    $mockableMethod.classInfo = $newClassInfo

    $mockableMethod
}

function MethodPatcher_GetPatchedMethodByFunctionName($patcher, $functionName) {
    $patcher.Methods[$functionName]
}

function MethodPatcher_Unpatch($patcher, $patchedMethod, $object) {
    PatchedClassMethod_Unpatch $patchedMethod $object

    if ( ! ( PatchedClassMethod_IsActive $patchedMethod ) ) {
        . $patchedMethod.originalscriptblock.module.newboundscriptblock({param($functionname) get-item "function:$functionname" | remove-item}) $patchedMethod.functionname

        $restoredClassInfo = MethodPatcher_GetPatchedClass $patcher $patchedMethod.classInfo
        MethodPatcher_RemovePatchedClass $patcher $restoredClassInfo.classDefinition.name
        $patcher.Methods.Remove($patchedMethod.functionname)
        [ClassManager]::Get().SetClass($restoredClassInfo)
    } else {
        MethodPatcher_RegisterMethodClassInfo $patchedMethod | out-null
    }
}

function MethodPatcher_RegisterMethodClassInfo($updatedMethod) {
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
