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

set-alias Unmock-ScriptClassMethod Remove-ScriptClassMock

function Remove-ScriptClassMock {
    [cmdletbinding()]
    param(
        [parameter(parametersetname='specific', position=0, mandatory=$true)]
        $MockTarget,

        [parameter(parametersetname='specific', position=1)]
        [string] $MethodName,

        [parameter(parametersetname='specific', position=2)]
        [switch] $Static,

        [parameter(parametersetname='all', mandatory=$true)]
        [switch] $All
    )

    $ScriptObject = $null
    $ClassName = $MockTarget

    if ( $MockTarget -is [PSCustomObject] ) {
        if ( $Static.IsPresent ) {
            throw [ArgumentException]::new("Argument 'Static' may not be specified when the type of argument 'MockTarget' is [PSCustomObject]. Specify a ScriptClass class name of type [String] for 'MockTarget' to use 'Static'")
        }

        $ScriptObject = $MockTarget
        $ClassName = $MockTarget.ScriptClass.ClassName
    } elseif ( $MockTarget -isnot [String] ) {
        throw [ArgumentException]::new("Argument 'MockTarget' of type '$($MockTarget.gettype())' is not of valid type [String] or [PSCustomObject]")
    }

    MethodMocker_Unmock $ClassName $MethodName $Static.IsPresent $ScriptObject $All.IsPresent
}
