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

    Context "When declaring a class with ScriptClass" {
        It "succeeds when using the ScriptClass alias" {
            $result = ScriptClass ClassClass1 {}
            $result | Should BeExactly $null
        }

        It "allows the user to define a property on the class" {
            $className = 'ClassClass5'
            $propertyName = 'description'

            ScriptClass $className {
                __property $propertyName
            }

            $typeData = get-class $className

            $typeData.members.keys -contains $propertyName | Should BeExactly $true
        }

        It "throws an exception if there's an attempt to redefine a property" {
            $className = 'ClassClass6'
            $propertyName = 'description'
            {
                ScriptClass $className {
                    __property $propertyName
                    __property $propertyName
                }
            } | Should Throw
        }

        It "can create a new object using new-object with the specified type" {
            $className = 'ClassClass7'
            ScriptClass $className {}

            $newInstance = new-instance $className
            $newInstance.PSTypeName | Should BeExactly $className
        }

        It "can create a new object that includes additional properties to the default properties" {
            $className = 'ClassClass8'
            $property1 = 'property1'
            $property2 = 'property2'

            ScriptClass $className {
                __property $property1
                __property $property2
            }

            $newInstance = new-instance $className
            $newInstance.psobject.properties.match($property1) | Should BeExactly $true
            $newInstance.psobject.properties.match($property2) | Should BeExactly $true
            $newInstance.psobject.properties.match('propdoesntexist') | Should BeExactly $null
        }

        It "can create a new object that includes additional properties set to default values" {
            $className = 'ClassClass9'
            $property1 = 'property1'
            $property2 = 'property2'

            ScriptClass $className {
                __property $property1, 1
                __property $property2, 2
            }

            $newInstance = new-instance $className
            $newInstance.$property1 | Should BeExactly 1
            $newInstance.$property2 | Should BeExactly 2
        }

        It "can create a new object that defines the type of members" {
            $className = 'ClassClass10'
            $property1 = 'property1'
            $property2 = 'property2'

            ScriptClass $className {
                __property [int32] $property1
                __property [Type]  $property2
            }

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

            ScriptClass $className {
                __property [int32] $property1, $value1
                __property [Type] $property2, $value2
            }

            $newInstance = new-instance $className
            $newInstance.$property1 | Should BeExactly $value1
            $newInstance.$property2 | Should BeExactly $value2
        }

        It "can define methods on the class" {
            $className = 'ClassClass15'
            $function1 = "testFunc"
            $function2 = "testFunc2"
            $function1Result = "f1output"

            ScriptClass $className {
                function testFunc {
                    "f1output"
                }
                function testFunc2 ($arg1, $arg2) {
                    $arg1 + $arg2
                }
            }

            $newInstance = new-instance $className

            ($newInstance.psobject.members | select Name).name -contains $function1 | Should BeExactly $true
            ($newInstance.psobject.members | select Name).name -contains $function2 | Should BeExactly $true
            with $newInstance $function1 | Should BeExactly $function1Result
            with $newInstance $function2 4 5 | Should BeExactly 9
        }


        It "can supply a `$this reference to methods on the class to provide access to properties defined by ScriptClass" {
            $className = 'ClassClass16'
            $identityResult = "me"

            ScriptClass $className {
                __property identity, $identityResult

                function showme {
                    $this.identity
                }
            }

            $newInstance = new-instance $className
            with $newInstance showme | should BeExactly $identityResult
        }

        It "throws an exception in class definition if a typed property of the class is initialized with a value of an incompatible type" {
            $className = 'ClassClass12'
            $invalidIntegerValue = 2

            {
                ScriptClass $className {
                    __property [Type] typeProperty, $invalidIntegerValue
                }
            } | Should Throw
        }

        It "cleans up PowerShell type data when one property definition throws an exception" {
            $className = 'ClassClass13'
            $invalidIntegerValue = 2

            {
                ScriptClass $className {
                    __property validProperty
                    __property [Type] typeProperty, $invalidIntegerValue
                }
            } | Should Throw
            get-typedata $className | Should BeExactly $null
        }
    }

    Context "When new-instance is used to create a new instance of a class" {
        It "calls the specified initializer function on the new object" {
            $className = 'ClassClass25'
            $initialStateValue = 3

            ScriptClass $className {
                __property objectState
                function __initialize {
                    $this.objectState = 3
                }
            }

            $newInstance = new-instance $className

            $newInstance.objectState | Should BeExactly $initialStateValue
        }

        It "calls the specified initializer function on the new object with multiple arguments" {
            $className = 'ClassClass26'
            $initialStateValue = 9

            ScriptClass $className {
                __property objectState
                function __initialize($arg1, $arg2) {
                    $this.objectState = $arg1 + $arg2
                }
            }

            $newInstance = new-instance $className 3 6

            $newInstance.objectState | Should BeExactly $initialStateValue

        }

        It "enables calls to the initializer to call other methods defined on the object" {
            $className = 'ClassClass27'
            $initialStateValue = 11

            ScriptClass $className {
                __property objectState
                function __initialize($arg1, $arg2) {
                    with $this sum $arg1 $arg2
                }

                function sum($first, $second) {
                    $this.objectState = $first + $second
                }
            }

            $newInstance = new-instance $className 4 7

            $newInstance.objectState | Should BeExactly $initialStateValue
        }
    }

    Context "When a method is invoked on an object defined with ScriptClass" {
        It "can invoke other methods on the object even when the other method is defined after the calling method" {
            $className = 'ClassClass20'
            $nestedResult = 'nested'

            ScriptClass $className {
                function outer {
                    with $this inner
                }

                function inner {
                    'nested'
                }
            }

            $newInstance = new-instance $className
             with $newInstance outer | Should BeExactly 'nested'
        }

        It "can invoke other methods in the object that return properties referenced from the `$this variable" {
            $className = 'ClassClass21'
            $nestedThisResult = 'nestedthis'

            ScriptClass $className {
                __property objectState,'nestedthis'
                function outer {
                    with $this inner
                }

                function inner {
                    $this.objectState
                }
            }

            $newInstance = new-instance $className

            with $newInstance outer | Should BeExactly $nestedThisResult
        }

        It "can take multiple arguments and invoke other methods in the object that take multiple arguments and return results using properties referenced from the `$this variable" {
            $className = 'ClassClass22'
            $bracketResult = '[1 + (3 * 4) + 2]'

            ScriptClass $className {
                __property outerBracket,'['
                __property outerBracketRight, ']'
                __property innerBracket, '('
                __property innerBracketRight, ')'
                function sum($arg1, $arg2, $arg3, $arg4) {
                    $inner = with $this product $arg3 $arg4
                    "$($this.outerBracket)$arg1 + $inner + $($arg2)$($this.outerBracketRight)"
                }

                function product($mult1, $mult2) {
                    "$($this.innerBracket)$mult1 * $($mult2)$($this.innerBracketRight)"
                }
            }

            $newInstance = new-instance $className

            with $newInstance sum 1 2 3 4 | Should BeExactly $bracketResult
        }

        It "can invoke other methods in the object using 'with' with the `$this variable" {
            $className = 'ClassClass23'

            ScriptClass $className {
                __property mainValue,7
                function outer($arg1, $arg2, $arg3) {
                    with $this inner $arg3 ($arg1 + $arg2)
                }

                function inner($first, $second) {
                    $this.mainValue + $first + $second
                }
            }

            $newInstance = new-instance $className
            with $newInstance outer 4 5 6 | Should BeExactly 22
        }

        It "can invoke other methods in the object using the call alias with the `$this variable and passing variable arguments using @args" {

            $className = 'ClassClass24'

            ScriptClass $className {
                __property mainValue,7
                function outer {
                    with $this inner @args
                }

                function inner($first, $second, $third) {
                    $this.mainValue + $first + $second + $third
                }
            }

            $newInstance = new-instance $className
            with $newInstance outer 4 5 6 | Should BeExactly 22
        }

        It "can invoke other methods in the object using 'with' without the `$this variable by implying it" {
            $className = 'ClassClass42'

            ScriptClass $className {
                __property mainValue,7
                function outer($arg1, $arg2, $arg3) {
                    inner $arg3 ($arg1 + $arg2)
                }

                function inner($first, $second) {
                    $this.mainValue + $first + $second
                }
            }

            $newInstance = new-instance $className
            with $newInstance outer 4 5 6 | Should BeExactly 22
        }

        It "can invoke other methods in the object using normal cmdlet call syntax against methods and implied `$this variable" {

            $className = 'ClassClass41'

            ScriptClass $className {
                __property mainValue,7
                function outer {
                    inner @args
                }

                function inner($first, $second, $third) {
                    $this.mainValue + $first + $second + $third
                }
            }

            $newInstance = new-instance $className
            with $newInstance outer 4 5 6 | Should BeExactly 22
        }

        It "can use the -do parameter to specify a method or scriptblock" {

            $className = 'ClassClass44'

            ScriptClass $className {
                __property mainValue,7
                function outer {
                    inner @args
                }

                function inner($first, $second, $third) {
                    $this.mainValue + $first + $second + $third
                }
            }

            $newInstance = new-instance $className
            with $newInstance -do outer 4 5 6 | Should BeExactly 22
            with $newInstance -do { outer 3 2 1 } | Should BeExactly 13
        }

    }

    Context "When a class is composed with another class" {
        scriptclass Inner {
            __property state,0
            function __initialize($initState) {
                $this.state = $initState
            }

            function Eval($base, $exponent) {
                [Math]::Pow($base, $exponent) + $this.state
            }
        }

        scriptclass Outer {
            __property evaluator
            function __initialize($initialOffset) {
                $this.evaluator = new-instance Inner $initialOffset
            }

            function getvalue($base, $exp) {
                with $this.evaluator Eval $base $exp
            }
        }

        It "Should have instances that can call methods of one class from another class" {
            $newInstance = new-instance Outer 5
            with $newInstance getvalue 2 3 | Should BeExactly 13
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

Describe "'with' function for object-based command context" {
    Context "When invoking an object's method through with" {
        $className = 'ClassClass32'

        scriptclass $className {
            __property mainValue,7
            function outer {
                with $this inner @args
            }

            function inner($first, $second, $third) {
                $this.mainValue + $first + $second + $third
            }

            function singlearg($first) {
                $this.mainValue + $first
            }
        }

        $newInstance = new-instance $className

        It "throws an exception if a null object is specified" {
            { with $null inner } | Should Throw
        }

        It "throws an exception if a non-string or non-scriptblock type is passed as the action" {
           { with $newInstance 3.0 } | Should Throw
        }

        It "throws an exception the context object is of a type cannot be cast as a PSCustomObject" {
            { with 3 'tostring' } | Should Throw
        }

        It "successfully executes a method that takes no arguments" {
            with $newInstance outer | Should BeExactly 7
        }

        It "successfully executes a method that takes 1 argument" {
            with $newInstance singlearg 4 | Should BeExactly 11
        }

        It "successfully executes a method that takes more than one argument" {
            with $newInstance outer 5 6 7 | Should BeExactly 25
        }

        It "throws an exception if a non-existent method for the object is specified" {
            { with $newInstance idontexist } | Should Throw
        }

        It "successfully executes a block that takes no arguments" {
            with $newInstance {$this.mainValue} | Should BeExactly 7
        }

        It "successfully executes a block that takes at least one argument" {
            with $newInstance {$this.mainValue + $args[0]} 2 | Should BeExactly 9
        }

        It "successfully executes a block that uses a method like a function" {
            with $newInstance { outer 10 20 30 } | Should BeExactly 67
        }

        It "successfully executes a block that uses a method like a function and passes arguments to it through @args" {
            with $newInstance { outer @args } 10 20 40 | Should BeExactly 77
        }
    }

    Context "When invoking an pscustomobject's method through with" {
        $newInstance = [PSCustomObject]@{first=1;second=2;third=3}
        $summethod = @{name='sum';memberType='ScriptMethod';value={$this.first + $this.second + $this.third}}
        $addmethod = @{name='add';memberType='ScriptMethod';value={param($firstarg, $secondarg) $firstarg + $secondarg}}
        $addtomethod = @{name='addto';memberType='ScriptMethod';value={param($firstarg) $this.sum() + $firstarg}}

        $newInstance | add-member @summethod
        $newInstance | add-member @addmethod
        $newInstance | add-member @addtomethod

        It "successfully executes a method that takes no arguments" {
            with $newInstance { sum } | Should BeExactly 6
        }

        It "successfully executes a method that takes 1 argument" {
            with $newInstance { addto 10 } Should Be Exactly 16
        }

        It "successfully executes a method that takes more than one argument" {
            with $newInstance { add 5 7 } Should Be Exactly 12
        }

        It "throws an exception if a non-existent method for the object is specified" {
            { with $newInstance { run } } | Should Throw
        }

        It "successfully executes a block that takes no arguments" {
           with $newInstance { $this.first } | Should BeExactly 1
        }

        It "successfully executes a block that takes at least one argument" {
            with $newInstance { add @args } 4 6 | Should BeExactly 10
            with $newInstance { addto @args } 7 | Should BeExactly 13
        }
    }

}

Describe 'The => invocation function' {
    Context "When a method is invoked through the => function" {
        $initialValue = 10
        ScriptClass ClassClass43 {
            __property sum, $initialValue
            function add($first, $second) {
                $first + $second
            }

            function addto($firstarg) {
                $this.sum += $firstarg
                current
            }

            function current() {
                $this.sum
            }
        }

        $newInstance = new-instance ClassClass43
        $newInstance2 = new-instance ClassClass43
        $newInstance3 = new-instance ClassClass43

        It "Should execute a method with no arguments" {
            $newInstance | => current | Should BeExactly $initialValue
        }

        It "Should execute a method with two arguments" {
            $newInstance | => add 1 3 | Should BeExactly 4
        }

        It "Should execute a method that takes an argument and incorporates object state" {
            $newInstance | => addto 2 | Should BeExactly 12
        }

        It "Should execute the same method on two different objects" {
            $newInstance2 |=> addto 3 | out-null
            $results = $newInstance2, $newInstance3 |=> addto 4

            $results[0] | Should BeExactly 17
            $results[1] | Should BeExactly 14
        }

        It "Should throw an exception if nothing is piped to it" {
            { => $newInstance current } | Should Throw
        }

        It "Should throw an exception if no method is specified" {
            { $newInstance | => } | Should Throw
        }

        It "Should throw an exception if a non-existent method is specified" {
           {$newInstance |=> nonexistent} | Should Throw
        }
    }
}
