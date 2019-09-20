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

function MethodMocker_Get {
    $mockerVariable = get-variable -scope script __MethodMocker -erroraction ignore
    $mocker = if ( $mockerVariable ) {
        $mockerVariable.value
    }

    if ( ! $mocker ) {
        $mocker = [PSCustomObject] @{
            MethodPatcher = MethodPatcher_Get
        }

        $script:__MethodMocker = $mocker
    }

    $mocker
}

function MethodMocker_GetClassModule($object, $className) {
    $arguments = @{}
    if ( $object ) { $arguments['object'] = $object }
    if ( $className) { $arguments['className'] = $className }

    $classInfo = Get-ScriptClass -detailed @arguments
    MethodPatcher_GetClassModule $classInfo
}

function MethodMocker_Mock($mockManager, $className, $methodName, $isStatic, $object, $mockScriptBlock, $parameterFilter, $isVerifiableMock, $moduleName, $mockContext) {
    $patchedMethod = MethodPatcher_PatchMethod $mockManager.MethodPatcher $className $MethodName $isStatic $object

    $objectModule = if ( $object ) {
        MethodMocker_GetClassModule -object $object
    } else {
        MethodMocker_GetClassModule -className $className
    }

    MethodMocker_MockPatchedMethod $patchedMethod $object $mockScriptBlock $parameterFilter $isVerifiableMock $objectModule.Name $objectModule $mockContext
}

function MethodMocker_MockPatchedMethod($patchedMethod, $object, $mockScriptBlock, $parameterFilter, $isVerifiableMock, $moduleName, $module, $mockContext) {
    $adjustedParameterFilter = if ( $object ) {
        $patchedObject = PatchedClassMethod_GetPatchedObject $patchedMethod $Object
        PatchedObject_Mock $patchedObject $mockScriptBlock $parameterFilter
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

            $importModule = $patchedmethod.ClassInfo.module
            import-module $importmodule -force -warningaction ignore | out-null

            $MockContext = $Context

            $mockModuleName = if ( $patchedMethod.IsStatic ) {
                $importModule.Name
            } else {
                {}.module.name
            }

            Mock $patchedMethod.FunctionName @parameterFilterArgument -Verifiable:$IsVerifiableMock -MockWith $mockScriptBlock -ModuleName $mockModuleName
        }
    ) $patchedMethod $parameterFilterArgument $IsVerifiableMock $mockScriptBlock $moduleArgument $mockContext
}

function MethodMocker_Unmock($className, $methodName, $isStatic, $object, $allMocks) {
    $patcher = MethodPatcher_Get

    $targetMethods = if ( $allMocks ) {
        MethodPatcher_GetPatchedMethods $patcher
    } else {
        MethodPatcher_QueryPatchedMethods $patcher $ClassName $MethodName $Static $Object
    }

    $targetMethods | foreach {
        MethodPatcher_Unpatch $patcher $_ $object
    }
}
