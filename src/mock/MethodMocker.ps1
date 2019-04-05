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

function __MethodMocker_Mock($mockManager, $className, $methodName, $isStatic, $object, $mockScriptBlock, $parameterFilter, $isVerifiableMock, $moduleName, $mockContext) {
    $patchedMethod = __MethodPatcher_PatchMethod $mockManager.MethodPatcher $className $MethodName $isStatic $object

    $objectModule = if ( $object ) {
        (__ScriptClass__GetClass $object.scriptclass.classname).classModule
#        $object.scriptclass.Module
    } else {
        $classModule = (__ScriptClass__GetClass $classname).classModule
        $classModule
    }

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
            import-module $patchedmethod.originalscriptblock.module -warningaction ignore | out-null
            $MockContext = $Context
            Mock $patchedMethod.FunctionName @parameterFilterArgument -Verifiable:$IsVerifiableMock -MockWith $mockScriptBlock $patchedmethod.originalscriptblock.module.name
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

    $targetMethods | foreach {
        __MethodPatcher_Unpatch $patcher $_ $object
    }
}
