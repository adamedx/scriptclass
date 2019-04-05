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

Describe 'Mock-ScriptClassObject cmdlet' {
    BeforeAll {
        remove-module $thismodule -force -erroraction silentlycontinue
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction silentlycontinue
    }

    Context 'Invoking simple commands' {
        ScriptClass SimpleClass {
            static {
                function StaticMethod {}
            }

            function InstanceMethod {}
        }

        It "Should not throw an exception when mocking an existing class method" {
            { Mock-ScriptClassMethod SimpleClass InstanceMethod } | Should Not Throw
        }

        It "Should not throw an exception when mocking an existing class static method" {
            { Mock-ScriptClassMethod SimpleClass StaticMethod -static -ModuleName ScriptClass } | Should Not Throw
        }

        It "Should not throw an exception when mocking an existing object method" {
            { Mock-ScriptClassMethod SimpleClass StaticMethod -static -ModuleName ScriptClass } | Should Not Throw
        }

        It "Should throw an exception with a specific message when attempting to mock a class that does not exist" {
            { Mock-ScriptClassMethod ClassThatDoesNotExist nonexistentmethod { 'nothing' } -ModuleName ScriptClass } | Should Throw 'not found'
        }

        It "Should throw an exception with a specific message when attempting to mock a class instance method that does not exist on a class that exists" {
            { Mock-ScriptClassMethod SimpleClass nonexistentmethod { 'nothing' } -ModuleName ScriptClass } | Should Throw 'not found'
        }

        It "Should throw an exception with a specific message when attempting to mock a static method that does not exist on a class that exists" {
            { Mock-ScriptClassMethod SimpleClass nonexistentstaticmethod { 'nothing' } -ModuleName ScriptClass } | Should Throw 'not found'
        }

        It "Should throw an exception with a specific message when attempting to mock an instance method of a particular object with a method name that does not exist on that object" {
            $testObject = new-so SimpleClass
            { Mock-ScriptClassMethod $testObject nonexistentmethod { 'nothing' } } | Should Throw 'not found'
        }
    }

    Context 'Mocking instance methods of a class' {
        It "Should return the mocked value instead of original if the mock is invoked before the object is created" {
            ScriptClass TestClassInstanceMethod {
                $data = 9
                function RealMethod($parameter1, $parameter2) {
                    $this.data + $parameter1 + $parameter2
                }
            }

            Mock-ScriptClassMethod TestClassInstanceMethod RealMethod { 5 } -ModuleName ScriptClass

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

            Mock-ScriptClassMethod TestClassInstanceMethod2 RealMethod { 5 } -ModuleName ScriptClass

            ($testClass |=> RealMethod 3 7) | Should Be 5

        }

        It "Should allow context to be passed to the mock function with the MockContext parameter" {
            ScriptClass TestClassInstanceMethodParam1 {
                $data = 9
                function RealMethod($parameter1, $parameter2) {
                    $this.data + $parameter1 + $parameter2
                }
            }

            $testClass = new-so TestClassInstanceMethodParam1
            ($testClass |=> RealMethod 3 7) | Should Be ($testClass.data + 3 + 7)

            $mockValue = 17
            Mock-ScriptClassMethod TestClassInstanceMethodParam1 RealMethod { $MockContext } -ModuleName ScriptClass -MockContext $mockValue

            ($testClass |=> RealMethod 3 7) | Should Be $mockValue
        }

        It 'should only use the mock if the parameter filter passes' {
            ScriptClass ParamFilter1 {
                function mymethod($param1, $param2) {
                    $param1 + $param2
                }
            }

            $testObject = new-so ParamFilter1
            $testObject |=> mymethod 1 5 | Should Be 6
            $testObject |=> mymethod 5 1 | Should Be 6

            Mock-ScriptClassMethod ParamFilter1 mymethod { $param1 * $param2 } -parameterfilter { $param2 -eq 1 } -ModuleName ScriptClass

            $testObject |=> mymethod 1 5 | Should Be 6
            $testObject |=> mymethod 5 1 | Should Be 5
        }

        It 'should allow the user of multiple parameter mocks' {
            ScriptClass ParamFilter3 {
                function mymethod($param1, $param2) {
                    $param1 + $param2
                }
            }

            $testObject = new-so ParamFilter3

            $testObject |=> mymethod 3 7 | Should Be 10

            Mock-ScriptClassMethod ParamFilter3 mymethod { $param1 * $param2 } -parameterfilter { $param1 -eq 2 } -ModuleName ScriptClass
            Mock-ScriptClassMethod ParamFilter3 mymethod { $param1 * $param2 + 1 } -parameterfilter { $param2 -eq 5 } -ModuleName ScriptClass

            $testObject |=> mymethod 3 7 | Should Be 10
            $testObject |=> mymethod 2 7 | Should Be 14

            $testObject |=> mymethod 8 5 | Should Be 41
            $testObject |=> mymethod 2 5 | Should Be 11
        }

        It 'should allow the use of the $this variable in the parameter filter to filter specific objects' -Pending {
            ScriptClass ParamFilter2 {
                $state = 0
                function mymethod($param1, $param2) {
                    $this.state + $param1 * $param2
                }
            }

            $testObject = new-so ParamFilter2
            $testObject.state = 3
            $testObject2 = new-so ParamFilter2
            $testObject2.state = -7

            $testObject |=> mymethod 4 5 | Should Be 23
            $testObject2 |=> mymethod 4 5 | Should Be 13

            Mock-ScriptClassMethod ParamFilter2 mymethod { $this.state * $param1 * $param2 } -parameterfilter { $this -eq $testObject2 } -ModuleName ScriptClass

            $testObject |=> mymethod 4 5 | Should Be 23
            $testObject2 |=> mymethod 4 5 | Should Be -140
        }

        It 'should be mocked if .net method call syntax is used' {
            ScriptClass TestDotNetCalls {
                $data = 5
                function compute($arg1, $arg2) {
                    $this.data + $arg1 + $arg2
                }
            }

            $testObject = new-so TestDotNetCalls

            $testObject |=> compute 4 3 | Should Be 12
            $testObject.compute(4,3) | Should Be 12

            Mock-ScriptClassMethod TestDotNetCalls compute { -1 } -ModuleName ScriptClass

            $testObject |=> compute 4 3 | Should Be -1
            $testObject.compute(4,3) | Should Be -1
        }

        Context 'Mocking methods of multiple classes' {
            ScriptClass TestClassInstanceMethod3 {
                $state = 11
                function MockMe($arg1, $arg2) {
                    $this.state + $arg1 + $arg2
                }
            }

            ScriptClass TestClassInstanceMethod4 {
                $thisstate = 13
                $includedObject = $null
                function __initialize {
                    $this.includedObject = new-so TestClassInstanceMethod3
                }
                function GetData($arg1) {
                    $this.thisState + ($this.includedObject |=> MockMe $arg1 3)
                }
                function GetState {
                    $this.thisstate
                }
            }

            ScriptClass ReplacementClass1 {
                function GetReplacedValue($otherObject) {
                    $otherobject.thisstate + 1
                }
            }

            It 'When invoking a method that invokes a mocked method, should return a result that reflects the mocked method' {
                $testObject = new-so TestClassInstanceMethod3
                $testObject |=> MockMe 4 5 | Should Be 20

                $testObject2 = new-so TestClassInstanceMethod4
                $testObject2 |=> GetData 4 | Should Be 31

                Mock-ScriptClassMethod TestClassInstanceMethod3 MockMe { -3 } -ModuleName ScriptClass

                $testObject2 |=> GetData 4 | Should Be 10
            }

            It 'When invoking a mocked method whose replacement mock invokes a mocked method, the result reflects the mocked method in the replacement mock' {
                $testObject = new-so TestClassInstanceMethod4
                $testObject.thisstate = 15
                $testObject |=> GetState | Should Be 15

                Mock-ScriptClassMethod TestClassInstanceMethod4 GetState { $replacer = new-so ReplacementClass1; $replacer |=> GetReplacedValue $this } -ModuleName ScriptClass
                $testObject |=> GetState | Should Be 16

                Mock-ScriptClassMethod ReplacementClass1 GetReplacedValue { $otherObject.thisstate - 4 } -ModuleName ScriptClass

                $testObject |=> GetState | Should Be 11
            }
        }
    }

    Context 'Mocking static methods of a class' {
        It "Should return the mocked value instead of the original" {
            ScriptClass TestClassStaticMethod {
                static {
                    $staticdata = 11

                    function StaticRealMethod($parameter1, $parameter2) {
                        $this.staticdata + $parameter1 * $parameter2
                    }
                }
            }

            ($::.TestClassStaticMethod |=> StaticRealMethod 3 7) | Should Be ( $::.TestClassStaticMethod.staticdata + 3 * 7 )

            Mock-ScriptClassMethod TestClassStaticMethod StaticRealMethod { 3 } -static -ModuleName ScriptClass

            ($::.TestClassStaticMethod |=> StaticRealMethod 3 7) | Should Be 3
        }

        It "Should allow context to be passed to the mock function with the MockContext parameter" {
            ScriptClass TestClassInstanceMethodParam2 {
                static {
                    function RealMethod($parameter1, $parameter2) {
                        $parameter1 + $parameter2
                    }
                }
            }

            $::.TestClassInstanceMethodParam2 |=> RealMethod 3 7 | Should Be (3 + 7)

            $mockValue = 18
            Mock-ScriptClassMethod TestClassInstanceMethodParam2 RealMethod { $MockContext } -Static -MockContext $mockValue

            $::.TestClassInstanceMethodParam2 |=> RealMethod 3 7 | Should Be $mockValue
        }
    }

    Context 'Mocking instance methods of an object' {
        It "Should return the mocked value instead of the original" {
            ScriptClass TestClassObjectMethod {
                $objectdata = 17

                function RealObjectMethod($parameter1, $parameter2) {
                    $this.objectdata + $parameter1 * $parameter2 + 1
                }
            }

            $testObject = new-so TestClassObjectMethod

            ($testObject |=> RealObjectMethod 3 7) | Should Be ( $testObject.objectData + 3 * 7  + 1 )

            Mock-ScriptClassMethod $testObject RealObjectMethod { 2 } -ModuleName ScriptClass

            ($testObject |=> RealObjectMethod 3 7) | Should Be 2
        }

        It "Should return the mocked value instead of the original for the mocked object, and the orignal value for an unmocked object of the same clas" {
            ScriptClass TestClassObjectMethod2 {
                $objectdata = 23

                function RealObjectMethod($parameter1, $parameter2, $parameter3) {
                    $this.objectdata + $parameter1 * $parameter2 * $parameter3 + 1
                }
            }

            $testObject = new-so TestClassObjectMethod2

            ($testObject |=> RealObjectMethod 3 7 2) | Should Be ( $testObject.objectData + 3 * 7 * 2 + 1 )

            Mock-ScriptClassMethod $testObject RealObjectMethod { 9 } -ModuleName ScriptClass

            ($testObject |=> RealObjectMethod 3 7 2) | Should Be 9

            $testObject2 = new-so TestClassObjectMethod2

            ($testObject2 |=> RealObjectMethod 3 7 2) | Should Be ( $testObject.objectData + 3 * 7 * 2 + 1 )
        }

        It "Should allow context to be passed to the mock function with the MockContext parameter" {
            ScriptClass TestClassObjectMethodContext2 {
                $objectdata = 29

                function RealObjectMethod($parameter1, $parameter2, $parameter3) {
                    $this.objectdata + $parameter1 * $parameter2 * $parameter3 + 1
                }
            }

            $testObject = new-so TestClassObjectMethodContext2

            ($testObject |=> RealObjectMethod 3 7 2) | Should Be ( $testObject.objectData + 3 * 7 * 2 + 1 )

            $mockOutput = 37
            Mock-ScriptClassMethod $testObject RealObjectMethod { $MockContext } -MockContext $mockOutput

            ($testObject |=> RealObjectMethod 3 7 2) | Should Be $mockOutput

            $testObject2 = new-so TestClassObjectMethodContext2

            ($testObject2 |=> RealObjectMethod 3 7 2) | Should Be ( $testObject.objectData + 3 * 7 * 2 + 1 )
        }
    }
}

