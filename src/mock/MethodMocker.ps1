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

function __MethodMocker_Get {
    $mocker = try {
        $script:__MethodMocker
    } catch {
    }

    if ( ! $mocker ) {
        $mocker = [PSCustomObject] @{
            MethodPatcher = __MethodPatcher_Get
        }

        $script:__MethodMocker = $mocker
    }

    $mocker
}

function __MethodMocker_GetClassModule($object, $className) {
    $arguments = @{}
    if ( $object ) { $arguments['object'] = $object }
    if ( $className) { $arguments['className'] = $className }

    $classInfo = Get-ScriptClass -detailed @arguments
    __MethodPatcher_GetClassModule $classInfo
}

function __MethodMocker_Mock($mockManager, $className, $methodName, $isStatic, $object, $mockScriptBlock, $parameterFilter, $isVerifiableMock, $moduleName, $mockContext) {
    $patchedMethod = __MethodPatcher_PatchMethod $mockManager.MethodPatcher $className $MethodName $isStatic $object

    $objectModule = if ( $object ) {
        __MethodMocker_GetClassModule -object $object
#        $object.scriptclass.Module
    } else {
        __MethodMocker_GetClassModule -className $className
    }

#    . $patchedMethod.classData.module.newboundscriptblock({get-childitem function:\ | select name, source | write-host -fore green})

#    . $objectModule.NewBoundScriptBlock({get-childitem function:\ | select name, source | write-host -fore yellow})
 #   (get-scriptclass -detailed $className).module.NewBoundScriptBlock({get-childitem function:\ | select name, source | write-host -fore yellow})

    __MethodMocker_MockPatchedMethod $patchedMethod $object $mockScriptBlock $parameterFilter $isVerifiableMock $objectModule.Name $objectModule $mockContext
}

function __MethodMocker_MockPatchedMethod($patchedMethod, $object, $mockScriptBlock, $parameterFilter, $isVerifiableMock, $moduleName, $module, $mockContext) {
    $adjustedParameterFilter = if ( $object ) {
        $patchedObject = __PatchedClassMethod_GetPatchedObject $patchedMethod $Object
        __PatchedObject_Mock $patchedObject $mockScriptBlock $parameterFilter
        $patchedObject.ParameterFilter
    } else {
        $parameterFilter
    }

    $parameterFilterArgument = if ( $adjustedParameterFilter ) {
        @{ParameterFilter=$adjustedParameterFilter}
    } else {
        @{}
    }

    $moduleArgument = @{moduleName=$module.Name}

    . $module.newboundscriptblock(
        {
            param($patchedMethod, $parameterFilterArgument, $IsVerifiableMock, $mockScriptBlock, $moduleArgument, $Context)
#            . $patchedMethod.classData.module.newboundscriptblock({get-childitem function:\ | select name, source | write-host -fore green})
            $importModule = $patchedmethod.ClassData.module
#            . $importModule.newboundscriptblock({get-childitem function:\ | select name, source | write-host -fore green})
#            import-module {}.module -force -warningaction ignore | out-null
            import-module $importmodule -force -warningaction ignore | out-null

#            import-module $importModule -warningaction ignore | out-null
#            import-module $patchedmethod.originalscriptblock.module -warningaction ignore | out-null

            $MockContext = $Context
#            get-command ___MockScriptClassMethod_static_SimpleClass_StaticMethod__  | fl * | out-host
#            function ___MockScriptClassMethod_static_SimpleClass_StaticMethod__ { write-host hi }
#            function blah {}
#            Mock blah {} -modulename {}.module.name
#            Mock ___MockScriptClassMethod_static_SimpleClass_StaticMethod__ -mockwith {} -modulename {}.module.name
            $moduleArg = @{}
            $mockModuleName = if ( $patchedMethod.IsStatic ) {
 #               $patchedmethod.originalscriptblock.module.name
#                {}.module.name
#                get-command ___MockScriptClassMethod_static_TestClassStaticMethod_StaticRealMethod__ | out-host
                $importModule.Name
                $moduleArg['ModuleName'] = $importModule.name
            } else {
                $moduleArg['ModuleName'] = {}.module.name
#                {}.module.name
                $importModule.Name
            }

            # . {}.module.newboundscriptblock({get-childitem function:\ | select name, source | write-host -fore green})
#            . $importModule.newboundscriptblock({get-childitem function:\ | select name, source | write-host -fore green})
#            . (get-module $importModule.name).newboundscriptblock({get-childitem function:\ | select name, source | write-host -fore green})
            Mock $patchedMethod.FunctionName @parameterFilterArgument -Verifiable:$IsVerifiableMock -MockWith $mockScriptBlock @moduleArg # -modulename $mockModuleName # $patchedmethod.originalscriptblock.module.name
            # -modulename {}.module.name
        }
    ) $patchedMethod $parameterFilterArgument $IsVerifiableMock $mockScriptBlock $moduleArgument $mockContext


#    if ( ! $module ) {
#    Mock $patchedMethod.FunctionName @parameterFilterArgument -Verifiable:$IsVerifiableMock -MockWith $mockScriptBlock @moduleArgument
    <#
    } else {
        . $module.newboundscriptblock(
            {
                param($patchedMethod, $parameterFilterArgument, $IsVerifiableMock, $mockScriptBlock, $moduleArgument)
                import-module $patchedmethod.originalscriptblock.module -warningaction ignore | out-null
                Mock $patchedMethod.FunctionName @parameterFilterArgument -Verifiable:$IsVerifiableMock -MockWith $mockScriptBlock $patchedmethod.originalscriptblock.module.name
            }
        ) $patchedMethod $parameterFilterArgument $IsVerifiableMock $mockScriptBlock $moduleArgument
    }
#>
}

function __MethodMocker_Unmock($className, $methodName, $isStatic, $object, $allMocks) {
    $patcher = __MethodPatcher_Get

    $targetMethods = if ( $allMocks ) {
        __MethodPatcher_GetPatchedMethods $patcher
    } else {
        __MethodPatcher_QueryPatchedMethods $patcher $ClassName $MethodName $Static $Object
    }

#    write-host -fore yellow patched
#    $targetMethods | out-host
#    write-host -fore yellow patchedend

    $targetMethods | foreach {
        __MethodPatcher_Unpatch $patcher $_ $object
    }
}
