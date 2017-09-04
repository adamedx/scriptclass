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
. "$here\$sut"

Describe "ClassDefinitionInterface" {
    Context "When declaring a simple class" {
        It "succeeds with trivial parameters for the new-class cmdlet" {
            $result = add-class SimpleClass1 {}

            $result | Should BeExactly $null
        }

        It "throws an exception when you try to redefine a class" {
            add-class SimpleClass3 {}
            { add-class SimpleClass3 {} } | Should Throw
        }

        It "can be found by get-class" {
            $className = 'SimpleClass4'
            add-class $className {} | out-null
            $classType = get-class $className
            $classType.TypeName | Should BeExactly $className
        }

        It "has a ScriptBlock member by default" {
            add-class SimpleClass5 { 5 }
            $classType = get-class SimpleClass5
            $invokeResult = invoke-command -scriptblock $classType.members.ScriptBlock.value
            $invokeResult | Should BeExactly 5
        }
    }

    Context "When declaring a class with __class" {
       It "succeeds when using the __class alias" {
            $result = __class ClassClass1 {}
            $result | Should BeOfType [scriptblock]
       }

        It "defines a class function with the name of the class" {
            $className = "ClassClass2"
            __class $className {} | out-null
            test-path "function:script:$className" | Should BeExactly $true
        }

        It "defines a class function that can be successfully executed" {
           { . (__class ClassClass3 { }) } | Should Not Throw
        }

        It "has a class function that throws if executed more than once to define the class" {
            $classBlock = __class ClassClass4 { }
            (. $classBlock) | out-null
            { . $classBlock } | Should Throw
        }

        It "allows the user to define a property on the class" {
            $className = 'ClassClass5'
            $propertyName = 'description'
            .(
                __class $className {
                    __property $propertyName
                }
            )

            $typeData = get-class $className

            $typeData.members.keys -contains $propertyName | Should BeExactly $true
        }

        It "throws an exception if there's an attempt to redefine a property" {
            $className = 'ClassClass6'
            $propertyName = 'description'
            { .(
                __class $className {
                    __property $propertyName
                    __property $propertyName
                }
            ) } | Should Throw
        }

        It "can create a new object using new-object with the specified type" {
            $className = 'ClassClass7'
            . ( __class $className {} )

            $newInstance = new-instance $className
            $newInstance.PSTypeName | Should BeExactly $className
        }

        It "can create a new object that includes additional properties to the default properties" {
            $className = 'ClassClass8'
            $property1 = 'property1'
            $property2 = 'property2'

            .(
                __class $className {
                    __property $property1
                    __property $property2
                }
            )

            $newInstance = new-instance $className
            $newInstance.psobject.properties.match($property1) | Should BeExactly $true
            $newInstance.psobject.properties.match($property2) | Should BeExactly $true
            $newInstance.psobject.properties.match('propdoesntexist') | Should BeExactly $null
        }

        It "can create a new object that includes additional properties set to default values" {
            $className = 'ClassClass9'
            $property1 = 'property1'
            $property2 = 'property2'

            .(
                __class $className {
                    __property $property1, 1
                    __property $property2, 2
                }
            )

            $newInstance = new-instance $className
            $newInstance.$property1 | Should BeExactly 1
            $newInstance.$property2 | Should BeExactly 2
        }

        It "can create a new object that defines the type of members" {
            $className = 'ClassClass10'
            $property1 = 'property1'
            $property2 = 'property2'

            .(
                __class $className {
                    __property [int32] $property1
                    __property [Type]  $property2
                }
            )

            $newInstance = new-instance $className

            { $newInstance.$property1 = 1 } | Should Not Throw
            { $newInstance.$property1 = new-object object } | Should Throw
            { $newInstance.$property2 = ([string]) } | Should Not Throw
            { $newInstance.$property2 = '2' } | Should Throw
        }

        It "can create a new object that includes additional typed properties set to default values" {
            $className = 'ClassClass11'
            $property1 = 'property1'
            $property2 = 'property2'
            $value1 = 1
            $value2 = [int32]

            .(
                __class $className {
                    __property [int32] $property1, $value1
                    __property [Type] $property2, $value2
                }
            )

            $newInstance = new-instance $className
            $newInstance.$property1 | Should BeExactly $value1
            $newInstance.$property2 | Should BeExactly $value2
        }

        It "can define methods on the class" {
            $className = 'ClassClass15'
            $function1 = "testFunc"
            $function2 = "testFunc2"
            $function1Result = "f1output"

            .(
                __class $className {
                    function testFunc {
                        "f1output"
                    }
                    function testFunc2 ($arg1, $arg2) {
                        $arg1 + $arg2
                    }
                }
            )

            $newInstance = new-instance $className

            ($newInstance.psobject.members | select Name).name -contains $function1 | Should BeExactly $true
            ($newInstance.psobject.members | select Name).name -contains $function2 | Should BeExactly $true
            call $newInstance.$function1 | Should BeExactly $function1Result
            call $newInstance.$function2 4 5 | Should BeExactly 9
        }


        It "can supply a `$this reference to methods on the class to provide access to properties defined by __class" {
            $className = 'ClassClass16'
            $identityResult = "me"

            .(
                __class $className {
                    __property identity, $identityResult

                    function showme {
                        $this.identity
                    }
                }
            )

            $newInstance = new-instance $className
            call $newInstance.showme | should BeExactly $identityResult
        }

        It "throws an exception in class definition if a typed property of the class is initialized with a value of an incompatible type" {
            $className = 'ClassClass12'
            $invalidIntegerValue = 2

            { .(
                  __class $className {
                      __property [Type] typeProperty, $invalidIntegerValue
                  }
              )
            } | Should Throw
        }

        It "cleans up PowerShell type data when one property definition throws an exception" {
            $className = 'ClassClass13'
            $invalidIntegerValue = 2

            { .(
                  __class $className {
                      __property validProperty
                      __property [Type] typeProperty, $invalidIntegerValue
                  }
              )
            } | Should Throw
            get-typedata $className | Should BeExactly $null
        }
    }

    Context "When new-instance is used to create a new instance of a lass" {
        It "calls the specified initializer function on the new object" {
            $className = 'ClassClass25'
            $initialStateValue = 3

            .(
                __class $className {
                    __property objectState
                    function __initialize {
                        $this.objectState = 3
                    }
                }
            )
            $newInstance = new-instance $className

            $newInstance.objectState | Should BeExactly $initialStateValue
        }

        It "calls the specified initializer function on the new object with multiple arguments" {
            $className = 'ClassClass26'
            $initialStateValue = 9

            .(
                __class $className {
                    __property objectState
                    function __initialize($arg1, $arg2) {
                        $this.objectState = $arg1 + $arg2
                    }
                }
            )
            $newInstance = new-instance $className 3 6

            $newInstance.objectState | Should BeExactly $initialStateValue

        }

        It "enables calls to the initializer to call other methods defined on the object" {
            $className = 'ClassClass27'
            $initialStateValue = 11

            .(
                __class $className {
                    __property objectState
                    function __initialize($arg1, $arg2) {
                        sum $arg1 $arg2
                    }

                    function sum($first, $second) {
                       $this.objectState = $first + $second
                    }
                }
            )
            $newInstance = new-instance $className 4 7

            $newInstance.objectState | Should BeExactly $initialStateValue
        }
    }

    Context "When a method is invoked on an object defined with __class" {
        It "can invoke other methods on the object even when the other method is defined after the calling method" {
            $className = 'ClassClass20'
            $nestedResult = 'nested'

            .(
                __class $className {
                    function outer {
                        inner
                    }

                    function inner {
                        'nested'
                    }
                }
            )

            $newInstance = new-instance $className
            call $newInstance.outer | Should BeExactly 'nested'
        }

        It "can invoke other methods in the object that return properties referenced from the `$this variable" {
            $className = 'ClassClass21'
            $nestedThisResult = 'nestedthis'

            .(
                __class $className {
                    __property objectState,'nestedthis'
                    function outer {
                        inner
                    }

                    function inner {
                        $this.objectState
                    }
                }
            )

            $newInstance = new-instance $className

            call $newInstance.outer | Should BeExactly $nestedThisResult
        }

        It "can take multiple arguments and invoke other methods in the object that take multiple arguments and return results using properties referenced from the `$this variable" {
            $className = 'ClassClass22'
            $bracketResult = '[1 + (3 * 4) + 2]'

            .(
                __class $className {
                    __property outerBracket,'['
                    __property outerBracketRight, ']'
                    __property innerBracket, '('
                    __property innerBracketRight, ')'
                    function sum($arg1, $arg2, $arg3, $arg4) {
                        $inner = product $arg3 $arg4
                        "$($this.outerBracket)$arg1 + $inner + $($arg2)$($this.outerBracketRight)"
                    }

                    function product($mult1, $mult2) {
                    "$($this.innerBracket)$mult1 * $($mult2)$($this.innerBracketRight)"
                    }
                }
            )

            $newInstance = new-instance $className

            call $newInstance.sum 1 2 3 4 | Should BeExactly $bracketResult
        }

        It "can invoke other methods in the object using the call alias with the `$this variable" {
            $className = 'ClassClass23'

            .(
                __class $className {
                    __property mainValue,7
                    function outer($arg1, $arg2, $arg3) {
                        call $this.inner $arg3 ($arg1 + $arg2)
                    }

                    function inner($first, $second) {
                        $this.mainValue + $first + $second
                    }
                }
            )

            $newInstance = new-instance $className
            call $newInstance.outer 4 5 6 | Should BeExactly 22
        }

            It "can invoke other methods in the object using the call alias with the `$this variable and passing variable arguments using @args" {
            $className = 'ClassClass24'

            .(
                __class $className {
                    __property mainValue,7
                    function outer {
                        call $this.inner @args
                    }

                    function inner($first, $second, $third) {
                        $this.mainValue + $first + $second + $third
                    }
                }
            )

            $newInstance = new-instance $className
            call $newInstance.outer 4 5 6 | Should BeExactly 22
        }
    }

    Context "When inspecting classes with get-class" {
        It "successfully retrieves class data for a defined class" {
            $className = 'GetSimpleClass1'
            add-class $className {}

            $classType = get-class GetSimpleClass1

            $classType | Should BeOfType [System.Management.Automation.Runspaces.TypeData]
            $classType.TypeName | Should BeExactly $className
        }

        It "throws an exception when a class is not found" {
            { get-class ClassDoesNotExist } | Should Throw
        }
    }


}


