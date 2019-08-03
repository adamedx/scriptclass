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

function New-ScriptObjectMock {
    [cmdletbinding(positionalbinding=$false)]
    param(
        [parameter(position=0, mandatory=$true)]
        $ClassName,

        [HashTable] $MethodMocks,

        [HashTable] $PropertyValues,

        [string] $ModuleName
    )

    $classDefinition = Get-ScriptClass $className -detailed

    if ( ! $classDefinition ) {
        throw [ArgumentException]::new("The specified class '$ClassName' does not exist")
    }

    if ( $methodMocks ) {
        $MethodMocks.keys | foreach {
            if ( $_ -isnot [string] ) {
                throw [ArgumentException]::new("Method mock hash table must contain only keys that are names of methods and of type [string]")
            }

            if ( $MethodMocks[$_] -isnot [ScriptBlock] ) {
                throw [ArgumentException]::new("Method mock value '$_' in MethodMocks parameter was not of type [ScriptBlock]")
            }
        }
    }

    if ( $propertyValues ) {
        $PropertyValues.keys | foreach {
            if ( $_ -isnot [string] ) {
                throw [ArgumentException]::new("Property value hash table must contain only keys that are names of properties and of type [string]")
            }
        }
    }

    $mockedObject = $classDefinition.prototype.psobject.copy()

    # This actually updates the object to have the unique id method,
    # thus making it an officially mocked object even if no methods
    # are currently mocked
    __PatchedObject_GetUniqueId $mockedObject | out-null

    if ( $propertyValues ) {
        $propertyValues.keys | foreach {
            $mockedObject.$_ = $propertyValues[$_]
        }
    }

    if ( $methodMocks ) {
        $mocker = __MethodMocker_Get

        $MethodMocks.keys | foreach {
            __MethodMocker_Mock $mocker $className $_ $false $mockedObject $MethodMocks[$_] { $true } $false $ModuleName
        }
    }

    $mockedObject
}
