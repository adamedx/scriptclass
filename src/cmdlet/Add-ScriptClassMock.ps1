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

set-alias Mock-ScriptClassMethod Add-ScriptClassMock

function Add-ScriptClassMock {
    [cmdletbinding(positionalbinding=$false)]
    param(
        [parameter(position=0, mandatory=$true)]
        $MockTarget,

        [parameter(position=1, mandatory=$true)]
        [String] $MethodName,

        [parameter(position=2)]
        [ScriptBlock] $MockWith = {},

        [parameter(position=3)]
        [ScriptBlock] $ParameterFilter,

        $MockContext,

        [parameter(parametersetname='static')]
        [Switch] $Static,

        [Switch] $Verifiable
    )

    $ScriptObject = $null
    $ClassName = $MockTarget

    if ( test-scriptobject $MockTarget ) {
        if ( $Static.IsPresent ) {
            throw [ArgumentException]::new("Argument 'Static' may not be specified when the type of argument 'MockTarget' is [PSCustomObject]. Specify a ScriptClass class name of type [String] for 'MockTarget' to use 'Static'")
        }

        $ScriptObject = $MockTarget
        $ClassName = $MockTarget.PSTypeName
    } elseif ( $MockTarget -isnot [String] ) {
        throw [ArgumentException]::new("Argument 'MockTarget' of type '$($MockTarget.gettype())' is not of valid type [String] or a [PSCustomObject] ScriptClass object")
    }

    $normalizedParameterFilter = if ( $ParameterFilter ) {
        $ParameterFilter
    } else {
        { $true }
    }

    $mocker = MethodMocker_Get

    MethodMocker_Mock $mocker $className  $methodName $Static.IsPresent $ScriptObject $MockWith $normalizedParameterFilter $Verifiable.IsPresent $null $MockContext
}

