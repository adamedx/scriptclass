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

set-strictmode -version 2

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$thismodule = join-path (split-path -parent $here) '../scriptclass.psd1'

Describe 'The New-ScriptClass cmdlet' {
    BeforeAll {
        remove-module $thismodule -force -erroraction ignore
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction ignore
    }

    Context "When declaring a simple class" {
        It "succeeds with trivial parameters for the new-class cmdlet" {
            $result = New-ScriptClass SimpleClass1 {}
            $result | Should BeExactly $null
        }

        It 'should capture variables defined by assignment in the class script block as data members' {
            Scriptclass ClassClass46 {
                $notypenoval = $null
                $typeimpliedbyval = 7
                $typenullvalint = [int] $null
                $typeandval = [double] 7
            }

            $newInstance = new-scriptobject ClassClass46

            $newInstance.notypenoval | Should BeExactly $null
            { ($newInstance.notypenoval).gettype() } | Should Throw

            $newInstance.typeimpliedbyval | Should BeExactly 7
            ($newInstance.typeimpliedbyval).gettype() | Should BeExactly 'int'

            $newInstance.typenullvalint | Should BeExactly 0
            ($newInstance.typenullvalint).gettype() | Should BeExactly 'int'

            $newInstance.typeandval | Should BeExactly 7
            ($newInstance.typeandval).gettype() | Should BeExactly 'double'
        }

        It "Does not throw an exception if New-ScriptClass is used inside an New-ScriptClass definition of a function" {
            {
                New-ScriptClass ClassClassOuter72 {
                    New-ScriptClass ClassClassOuter73 {}
                }
            } | Should Not Throw
        }

        It "Allows parameters to be passed to the class definition block that may be aassigned to instance members" {
            ScriptClass ParameterizedClass1 -ArgumentList 5 {
                param($classParam)
                $classData = $classParam

                function GetParam {
                    $this.classData
                }
            }

            $instance = new-so ParameterizedClass1

            $instance |=> GetParam | Should Be 5
        }

        It "Allows parameters to be passed to the class definition block that may be assigned to static members" {
            ScriptClass ParameterizedClass2 -ArgumentList 4 {
                param($classParam)

                static {
                    $staticData = $classParam
                    function GetParam {
                        $this.staticData
                    }
                }
            }

            $::.ParameterizedClass2 |=> GetParam | Should Be 4
        }

        It "Should return the value of the parameter passed to a class definition if an instance method attempts to access that parameter and return it in the pipelinne" {
            ScriptClass ParameterizedClass3 -ArgumentList 6 {
                param($classParam)

                function GetParam {
                    $classParam
                }
            }

            $instance = new-so ParameterizedClass3

            $instance |=> GetParam | Should Be 6
        }

        It "Should throw an exception if an instance method attempts to access a parameter as a property of the instance using the this variable" {
            ScriptClass ParameterizedClass4 -ArgumentList 7 {
                param($classParam)

                function GetParam {
                    $this.classParam
                }
            }

            $instance = new-so ParameterizedClass4

            { $instance |=> GetParam } | Should Throw "The property 'classParam' cannot be found"
        }
    }

    Context "When declaring a class with ScriptClass" {
        It "succeeds when using the ScriptClass alias" {
            $result = ScriptClass ClassClass1 {}
            $result | Should BeExactly $null
        }

        It "Does not throw an exception if ScriptClass is used inside a ScriptClass definition of a function" {
            {
                ScriptClass ClassClassOuter70 {
                    ScriptClass ClassClassOuter71 {}
                }
            } | Should Not Throw
        }

        It "allows the user to define a property on the class" {
            ScriptClass ClassClass63 {
                $mydescription = $null
            }

            $typeProperties = (Get-ScriptClass ClassClass63 -detailed).classdefinition.InstanceProperties
            $typeProperties.keys -contains 'mydescription' | Should BeExactly $true
        }

        It "throws an exception if you fail to initialize a property" {
            {
                ScriptClass ClassClass50 {
                    $description
                }
            } | Should Throw
        }

        It "redefines a property with the last value if it is defined more than once" {
            $className = 'ClassClass6'
            $propertyName = 'description'
            ScriptClass $className {
                $description = 1
                $description = 2
            }

            $newInstance = new-scriptobject $className
            $newInstance.description | Should BeExactly 2
        }
    }

    Context "When a class is composed with another class" {
        ScriptClass Inner {
            $state = 0
            function __initialize($initState) {
                $this.state = $initState
            }

            function Eval($base, $exponent) {
                [Math]::Pow($base, $exponent) + $this.state
            }
        }

        ScriptClass Outer {
            $evaluator = $null
            function __initialize($initialOffset) {
                $this.evaluator = new-scriptobject Inner $initialOffset
            }

            function getvalue($base, $exp) {
                withobject $this.evaluator Eval $base $exp
            }
        }

        It "Should have instances that can call methods of one class from another class" {
            $newInstance = new-scriptobject Outer 5
            withobject $newInstance getvalue 2 3 | Should BeExactly 13
        }
    }

    Context "When redefining a class" {
        It "doesn't throw an exception when the class is defined the same way twice" {
            ScriptClass SimpleClass3 {}
            { ScriptClass SimpleClass3 {} } | Should Not Throw
        }

        It "redefines an existing class if it already exists" {
            ScriptClass ClassClass51 {
                $prop1 = 1
                $prop2 = 2
                $prop3 = strict-val [int] 3
                function method1 { $this.prop1 }
                function method2 { $this.prop2 }
                function method3 { $this.prop3 }
            }

            ScriptClass ClassClass51 {
                $prop2 = 21
                $prop3 = strict-val [string] '31'
                $prop4 = 4
                $prop5 = $null
                function method2 { $this.prop4 }
                function method4 { $this.prop3 }
                function method5 { $this.prop5 }
                function __initialize { $this.prop5 = 5 }
            }

            $newInstance = new-scriptobject ClassClass51

            $newInstance | gm prop1 | Should Be $null
            $newInstance.prop2 | Should BeExactly 21
            $newInstance.prop3 | Should BeExactly '31'
            $newInstance.prop4 | Should BeExactly 4
            $newInstance.prop5 | Should BeExactly 5

            { $newInstance |=> method1 | out-null } | Should Throw
            $newInstance |=> method2 | Should BeExactly 4
            { $newInstance |=> method3 | out-null } | Should Throw
            $newInstance |=> method4 | Should BeExactly '31'
            $newInstance |=> method5 | Should BeExactly 5
        }
    }
}
