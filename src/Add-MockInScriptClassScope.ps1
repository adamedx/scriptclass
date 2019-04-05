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

set-alias Mock-InScriptClassScope Add-MockInScriptClassScope

function Add-MockInScriptClassScope {
    [cmdletbinding(positionalbinding=$false)]
    param(
        [parameter(position=0, mandatory=$true)]
        [String] $ClassName,

        [parameter(position=1, mandatory=$true)]
        [String] $CommandName,

        [parameter(position=2, mandatory=$true)]
        [ScriptBlock] $MockWith = {},

        $MockContext,

        [ScriptBlock] $ParameterFilter,

        [Switch] $Verifiable
    )

    $normalizedParameterFilter = if ( $ParameterFilter ) {
        $ParameterFilter
    } else {
        { $true }
    }

    $classModule = (__ScriptClass__GetClass $ClassName).classModule

    . $classModule.newboundscriptblock(
        {
            param(
                $Module,
                [string] $CommandNameToMock,
                [ScriptBlock] $MockWithScriptBlock,
                [ScriptBlock] $ParameterFilterBlock,
                [bool] $IsVerifiable,
                $Context
            )

            $Module | import-module -warningaction ignore

            $MockContext = $Context
            Mock -CommandName $CommandNameToMock -ModuleName $Module.name -ParameterFilter $ParameterFilterBlock -MockWith $MockWithScriptBlock -Verifiable:$IsVerifiable
        }
    ) $classModule $CommandName $MockWith $normalizedParameterFilter $Verifiable.IsPresent $MockContext
}


