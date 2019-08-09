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
        $classData = if ( $ClassName ) {
            __MethodPatcher_GetClassDefinition $patcher $className
        } else {
            __MethodPatcher_GetClassDefinition $patcher $object.scriptclass.classname
        }

        $methodClass = $classData.classDefinition.name

        if ( $staticMethods ) {
            $classData.prototype.scriptclass.psobject.methods | select -expandproperty name
        } else {
            $classData.classDefinition.GetInstanceMethods().name
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
#    ($classInfo.prototype.psobject.methods | where name -eq invokemethod).script.module
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

#        $replacementMethodBlock = __MethodPatcher_CreateMethodPatchScriptBlock $patcher $functionName $isStatic $originalMethodBlock.module
        $replacementMethodBlock = __MethodPatcher_CreateMethodPatchScriptBlock $patcher $functionName $isStatic $classModule

<#
        $newFunc = if ( $classDefinition.parentModule ) {
            . $classDefinition.parentModule.NewBoundScriptBlock({param($functionName, $originalMethodBlock) new-item "function:$functionName" -value $originalMethodBlock -force | out-null }) $functionName $originalMethodBlock
        } else {
            new-item "function:`$script:$functionName" -value $originalMethodBlock -force
        }
#>

#        $classModule = $originalMethodBlock.module

#        . $classModule.NewBoundScriptBlock({get-childitem function:\ | select name, source | write-host -fore magenta})
        $newFunc = . $classModule.NewBoundScriptBlock({param($functionName, $originalMethodBlock) new-item "function:$functionName" -value $originalMethodBlock -force ; export-modulemember -function $functionName}) $functionName $originalMethodBlock
#        . $classModule.NewBoundScriptBlock({get-childitem function:\ | select name, source | write-host -fore cyan})

        $anotherfunc = . $classModule.NewBoundScriptBlock({param([object[]] $functions) $functions | foreach { new-item "function:$($_.name)" -value $_.scriptblock -force }} ) (get-item function:__MethodPatcher_Get, function:__MethodPatcher_GetPatchedMethodByFunctionName, function:__PatchedClassMethod_GetMockedObjectScriptBlock)


#        new-item "function:$functionName" -value $originalMethodBlock -force | out-null

#        $classInfo = [ClassInfo]::New($classDefinition.classDefinition, $classDefinition.prototype, $classDefinition.module)
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

    $classContext = [ClassDefinitionContext]::new($mockableMethod.classData.classDefinition, $mockableMethod.classData.module, $mockableMethod.classData.prototype.scriptclass.module)

    $classBuilder = [ScriptClassBuilder]::new($classContext)
    $classInfo = $classBuilder.ToClassInfo($null)
    $staticPrototype = $classInfo.prototype.scriptclass

    [ScriptClassBuilder]::AddStaticCommonMethods($classInfo.module, $staticPrototype)
    $classInfo.prototype = $mockableMethod.classData.prototype
    $classInfo.prototype.scriptclass = $staticPrototype

    __MethodPatcher_SetPatchedClass $patcher $classInfo
    [ClassManager]::Get().SetClass($classInfo)
#    . $classInfo.Module.NewBoundScriptBlock({get-childitem function:\ | select name, source | write-host -fore magenta})
    $mockableMethod.classData = $classInfo


    $mockableMethod
}

function __MethodPatcher_GetPatchedMethodByFunctionName($patcher, $functionName) {
    $patcher.Methods[$functionName]
}

function __MethodPatcher_Unpatch($patcher, $patchedMethod, $object) {
    __PatchedClassMethod_Unpatch $patchedMethod $object
#     $patchedMethod.classdata.classdefinition.staticmethods.values | out-host

    if ( ! ( __PatchedClassMethod_IsActive $patchedMethod ) ) {
#        get-item "function:$($patchedmethod.originalscriptblock.module.name)\$($patchedMethod.functionname)" | remove-item
        . $patchedMethod.originalscriptblock.module.newboundscriptblock({param($functionname) get-item "function:$functionname" | remove-item}) $patchedMethod.functionname

        $patchedClass = __MethodPatcher_GetPatchedClass $patcher $patchedMethod.classData
        __MethodPatcher_RemovePatchedClass $patcher $patchedClass.classDefinition.name
        $patcher.Methods.Remove($patchedMethod.functionname)
        [ClassManager]::Get().SetClass($patchedClass)
    } else {
        $classContext = [ClassDefinitionContext]::new($patchedMethod.classData.classDefinition, $patchedMethod.classData.module, $patchedMethod.classData.prototype.scriptclass.module)

        $classBuilder = [ScriptClassBuilder]::new($classContext)
        $existingClassInfo = [ClassManager]::Get().GetClassInfo($classContext.classDefinition.name)
        $mockedClassInfo = $classBuilder.ToClassInfo($null)
        $restoredStaticPrototype = $mockedClassInfo.prototype.scriptclass
        [ScriptClassBuilder]::AddStaticCommonMethods($classContext.staticmodule, $restoredStaticPrototype)
        $mockedClassInfo.prototype = $existingClassInfo.prototype
        $mockedClassInfo.prototype.scriptclass = $restoredStaticPrototype
        $mockedClassInfo.prototype.scriptclass.psobject.methods | where membertype -eq 'scriptmethod' | foreach {
#            write-host -fore yellow $_.name, $_.script.module
        }
        [ClassManager]::Get().SetClass($mockedClassInfo)
    }
}

