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

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$thismodule = join-path (split-path -parent $here) 'ScriptClass.psd1'

Describe 'New-ScriptObjectMock cmdlet' {
    BeforeAll {
        remove-module $thismodule -force -erroraction silentlycontinue
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction silentlycontinue
    }

    Context 'A mocked object created from an object with state and methods' {
        ScriptClass MockObjectClass {
            $data1 = 0
            $data2 = 1
            function __initialize {
                $this.data1 = 1
                $this.data2 = 2
            }
            function Times($param1, $param2) {
                $param1 * $param2 * $this.data1
            }

            function Add($param1, $param2) {
                $param1 + $param2 + $this.data2
            }
        }

        It "should throw an exception containing 'does not exist' if a non-existent class is passed as the ClassName parameter" {
            { $mockedObject = New-ScriptObjectMock ClassDoesNotExist } | Should Throw 'does not exist'
        }

        It "should throw an exception that contains the sequence '[string]' if any keys of the MethodMocks parameter are not of type [string]" {
            { $mockedObject = New-ScriptObjectMock MockObjectClass -methodmocks @{Times={4};3={4}} } | Should Throw '[string]'
        }

        It "should throw an exception that contains the sequence '[ScriptBlock]' if any values of the MethodMocks parameter are not of type [ScriptBlock]" {
            { $mockedObject = New-ScriptObjectMock MockObjectClass -methodmocks @{Times={4};Add=4} } | Should Throw '[ScriptBlock]'
        }

        It "should throw an exception that contains the sequence 'was not found for class' if any keys of the MethodMocks parameter are not the names of valid methods of the class" {
            { $mockedObject = New-ScriptObjectMock MockObjectClass -methodmocks @{Times={4};Plus={4};Add={5}} -ModuleName ScriptClass } | Should Throw 'was not found for class'
        }

        It "should throw an exception that contains the sequence '[string]' if any keys of the PropertyValues parameter are not of type [string]" {
            { $mockedObject = New-ScriptObjectMock MockObjectClass -propertyvalues @{data1=7;2='two'} } | Should Throw '[string]'
        }

        It "should throw an exception that contains the sequence 'cannot be found on this object' if any keys of the MethodMocks parameter are not the names of valid methods of the class" {
            { $mockedObject = New-ScriptObjectMock MockObjectClass -propertyvalues @{data1=4;data2=5;data3=2} } | Should Throw 'cannot be found on this object'
        }

        It "The mocked object should have the '__ScriptClassMockedObjectId' method when called with no constructors" {
            $mockedObject = New-ScriptObjectMock MockObjectClass

            { $mockedObject.__ScriptClassMockedObjectId() } | Should Not throw
            $mockedObject.__ScriptClassMockedObjectId() | Should Not Be $null
        }

        It 'The constructor should not be called and the object state should reflect pre-constructor values' {
            $mockedObject = New-ScriptObjectMock MockObjectClass

            $mockedObject.data1 | Should Be 0
            $mockedObject.data2 | Should Be 1
        }

        It 'The unmocked methods should function on the pre-constructor state' {
            $mockedObject = New-ScriptObjectMock MockObjectClass

            $mockedObject |=> Times 4 8 | Should Be 0
            $mockedObject |=> Add 4 8 | Should Be 13
        }

        It 'Should be possible to mock methods and properties using only the parameters to New-ScriptObjectMock' {
            $mockedObject = New-ScriptObjectMock MockObjectClass -MethodMocks @{Times={param($param1, $param2) ($param1 + $param2) + $this.data1 * $this.data2 };Add={param($param1, $param2) ($param1 * $param2) + $this.data1 + $this.data2}} -propertyvalues @{data1=3;data2=8} -ModuleName ScriptClass

            $mockedObject |=> Times 3 7 | Should Be 34
            $mockedObject |=> Add 2 5 | Should Be 21
        }

        It 'Should be possible to mock a methods from a mocked object returned by New-ScriptObjectMock' {
            $mockedObject = New-ScriptObjectMock MockObjectClass

            Mock-ScriptClassMethod $mockedObject Times {param($param1, $param2) ($param1 + $param2) + $this.data1 * $this.data2 + 3} -ModuleName ScriptClass
            Mock-ScriptClassMethod $mockedObject Add {param($param1, $param2) ($param1 * $param2) + $this.data1 + $this.data2 + 9} -ModuleName ScriptClass

            $mockedObject.data1 = 3
            $mockedObject.data2 = 8

            $mockedObject |=> Times 3 7 | Should Be 37
            $mockedObject |=> Add 2 5 | Should Be 30
        }
    }
}
