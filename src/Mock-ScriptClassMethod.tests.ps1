# Copyright 2017, Adam Edwards
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
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$thismodule = join-path (split-path -parent $here) 'scriptclass.psd1'
. $here/$sut

Describe 'Mock-ScriptClassObject cmdlet' {
    BeforeAll {
        remove-module $thismodule -force -erroraction silentlycontinue
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction silentlycontinue
    }

    Context 'Invoking simple commands' {
        It "Should not throw an exception when mocking an existing class method" {
        }

        It "Should not throw an exception when mocking an existing class static method" {
        }

        It "Should not throw an exception when mocking an existing object method" {
        }

        It "Should throw an exception with a specific message when attempting to mock a class that does not exist" {
            { Mock-ScriptClassMethod ClassThatDoesNotExist nonexistentmethod { 'nothing' } } | Should Throw 'not found'
        }
    }

    Context 'Mocking instance methods of a class' {
    }

    Context 'Mocking static methods of a class' {
    }

    Context 'Mocking instance methods of an object' {
    }
}

Describe 'inprogress' {
    BeforeAll {
        remove-module $thismodule -force -erroraction silentlycontinue
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction silentlycontinue
    }

    Context 'When mocking a class instance method' {
        It "Should return the mocked value instead of original if the mock is invoked before the object is created" {
            ScriptClass TestClassInstanceMethod {
                $data = 9
                function RealMethod($parameter1, $parameter2) {
                    $this.data + $parameter1 + $parameter2
                }
            }

            Mock-ScriptClassMethod TestClassInstanceMethod RealMethod { 5 }

            $testClass = new-so TestClassInstanceMethod

            ($testClass |=> RealMethod 3 7) | Should Be 5
        }

        It "Should return the original method result before mocking if the object is created before the mock is invoked, and a different value for the method on the same object after the mock is invoked" {
            ScriptClass TestClassInstanceMethod2 {
                $data = 9
                function RealMethod($parameter1, $parameter2) {
                    $this.data + $parameter1 + $parameter2
                }
            }

            $testClass = new-so TestClassInstanceMethod2
            ($testClass |=> RealMethod 3 7) | Should Be ($testClass.data + 3 + 7)

            Mock-ScriptClassMethod TestClassInstanceMethod2 RealMethod { 5 }

            ($testClass |=> RealMethod 3 7) | Should Be 5

        }

        It "Should return the mocked value after mocking and then the original value after the mock is removed from the class" {
            ScriptClass TestClassInstanceMethod3 {
                $data = 9
                function RealMethod($parameter1, $parameter2) {
                    $this.data + $parameter1 + $parameter2
                }
            }

            Mock-ScriptClassMethod TestClassInstanceMethod3 RealMethod { 5 }

            $testClass = new-so TestClassInstanceMethod3

            ($testClass |=> RealMethod 3 7) | Should Be 5

            Remove-ScriptClassMethodMock TestClassInstanceMethod3 RealMethod

            ($testClass |=> RealMethod 3 7) | Should Be 19
        }
    }

    Context "When mocking a static method" {
        It "Should return the mocked value instead of original if the mock is invoked before the object is created" {
            ScriptClass TestClassStaticMethod {
                static {
                    $staticdata = 11

                    function StaticRealMethod($parameter1, $parameter2) {
                        $this.staticdata + $parameter1 * $parameter2
                    }
                }
            }

            ($::.TestClassStaticMethod |=> StaticRealMethod 3 7) | Should Be ( $::.TestClassStaticMethod.staticdata + 3 * 7 )

            Mock-ScriptClassMethod TestClassStaticMethod StaticRealMethod { 3 } -static

            ($::.TestClassStaticMethod |=> StaticRealMethod 3 7) | Should Be 3
        }

        It "Should return the original value after it was mocked and returned a mocked value" {
            ScriptClass TestClassStaticMethod2 {
                static {
                    $staticdata = 11

                    function StaticRealMethod($parameter1, $parameter2) {
                        $this.staticdata + $parameter1 * $parameter2
                    }
                }
            }

            ($::.TestClassStaticMethod2 |=> StaticRealMethod 3 7) | Should Be ( $::.TestClassStaticMethod.staticdata + 3 * 7 )

            Mock-ScriptClassMethod TestClassStaticMethod2 StaticRealMethod { 3 } -static

            ($::.TestClassStaticMethod2 |=> StaticRealMethod 3 7) | Should Be 3

            Remove-ScriptClassMethodMock TestClassStaticMethod2 StaticRealMethod -static

            ($::.TestClassStaticMethod2 |=> StaticRealMethod 3 7) | Should Be ( $::.TestClassStaticMethod.staticdata + 3 * 7 )
        }
    }
}
