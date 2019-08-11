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
$thismodule = join-path (split-path -parent $here) '../ScriptClass.psd1'

Describe "Invoke-Method cmdlet for object-based command invocation with context" {
    BeforeAll {
        remove-module $thismodule -force -erroraction ignore
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction ignore
    }

    Context "When invoking an object's method through withobject" {
        $className = 'ClassClass32'

        ScriptClass $className {
            $mainValue = 7
            function outer {
                withobject $this inner @args
            }

            function inner($first, $second, $third) {
                $this.mainValue + $first + $second + $third
            }

            function singlearg($first) {
                $this.mainValue + $first
            }

            function invokeme($myblock) {
                (. $myblock)
            }
        }

        $newInstance = new-scriptobject $className

        It "throws an exception if a null object is specified" {
            { withobject $null inner } | Should Throw
        }

        It "throws an exception if a non-string or non-scriptblock type is passed as the action" {
           { withobject $newInstance 3.0 } | Should Throw
        }

        It "throws an exception the context object is of a type cannot be cast as a PSCustomObject" {
            { withobject 3 'tostring' } | Should Throw
        }

        It "successfully executes a method that takes no arguments" {
            withobject $newInstance outer | Should BeExactly 7
        }

        It "successfully executes a method that takes 1 argument" {
            withobject $newInstance singlearg 4 | Should BeExactly 11
        }

        It "successfully executes a method that takes more than one argument" {
            withobject $newInstance outer 5 6 7 | Should BeExactly 25
        }

        It "throws an exception if a non-existent method for the object is specified" {
            { withobject $newInstance idontexist } | Should Throw
        }

        It "successfully executes a block that takes no arguments" {
            withobject $newInstance {$this.mainValue} | Should BeExactly 7
        }

        It "successfully executes a block that takes at least one argument" {
            withobject $newInstance {$this.mainValue + $args[0]} 2 | Should BeExactly 9
        }

        It "successfully executes a block that uses a method like a function" {
            withobject $newInstance { outer 10 20 30 } | Should BeExactly 67
        }

        It "successfully executes a block that uses a method like a function and passes arguments to it through @args" {
            withobject $newInstance { outer @args } 10 20 40 | Should BeExactly 77
        }
    }

    Context "When invoking an pscustomobject's method through 'withobject'" {
        $newInstance = [PSCustomObject]@{first=1;second=2;third=3}
        $summethod = @{name='sum';memberType='ScriptMethod';value={$this.first + $this.second + $this.third}}
        $addmethod = @{name='add';memberType='ScriptMethod';value={param($firstarg, $secondarg) $firstarg + $secondarg}}
        $addtomethod = @{name='addto';memberType='ScriptMethod';value={param($firstarg) $this.sum() + $firstarg}}

        $newInstance | add-member @summethod
        $newInstance | add-member @addmethod
        $newInstance | add-member @addtomethod

        It "successfully executes a method that takes no arguments" {
            withobject $newInstance { sum } | Should BeExactly 6
        }

        It "successfully executes a method that takes 1 argument" {
            withobject $newInstance { addto 10 } Should Be Exactly 16
        }

        It "successfully executes a method that takes more than one argument" {
            withobject $newInstance { add 5 7 } Should Be Exactly 12
        }

        It "throws an exception if a non-existent method for the object is specified" {
            { withobject $newInstance { run } } | Should Throw
        }

        It "successfully executes a block that takes no arguments" {
           withobject $newInstance { $this.first } | Should BeExactly 1
        }

        It "successfully executes a block that takes at least one argument" {
            withobject $newInstance { add @args } 4 6 | Should BeExactly 10
            withobject $newInstance { addto @args } 7 | Should BeExactly 13
        }
    }

    Context "When a method is invoked on an object defined with ScriptClass" {
        It "can invoke other methods on the object even when the other method is defined after the calling method" {
            $className = 'ClassClass20'
            $nestedResult = 'nested'

            ScriptClass $className {
                function outer {
                    withobject $this inner
                }

                function inner {
                    'nested'
                }
            }

            $newInstance = new-scriptobject $className
             withobject $newInstance outer | Should BeExactly 'nested'
        }

        It "can invoke other methods in the object that return properties referenced from the `$this variable" {
            $className = 'ClassClass21'
            $nestedThisResult = 'nestedthis'

            ScriptClass $className {
                $objectState = 'nestedthis'
                function outer {
                    withobject $this inner
                }

                function inner {
                    $this.objectState
                }
            }

            $newInstance = new-scriptobject $className

            withobject $newInstance outer | Should BeExactly $nestedThisResult
        }

        It "can take multiple arguments and invoke other methods in the object that take multiple arguments and return results using properties referenced from the `$this variable" {
            $className = 'ClassClass22'
            $bracketResult = '[1 + (3 * 4) + 2]'

            ScriptClass $className {
                $outerBracket = '['
                $outerBracketRight = ']'
                $innerBracket = '('
                $innerBracketRight = ')'
                function sum($arg1, $arg2, $arg3, $arg4) {
                    $inner = withobject $this product $arg3 $arg4
                    "$($this.outerBracket)$arg1 + $inner + $($arg2)$($this.outerBracketRight)"
                }

                function product($mult1, $mult2) {
                    "$($this.innerBracket)$mult1 * $($mult2)$($this.innerBracketRight)"
                }
            }

            $newInstance = new-scriptobject $className

            withobject $newInstance sum 1 2 3 4 | Should BeExactly $bracketResult
        }

        It "can invoke other methods in the object using 'withobject' with the `$this variable" {
            $className = 'ClassClass23'

            ScriptClass $className {
                $mainValue = 7
                function outer($arg1, $arg2, $arg3) {
                    withobject $this inner $arg3 ($arg1 + $arg2)
                }

                function inner($first, $second) {
                    $this.mainValue + $first + $second
                }
            }

            $newInstance = new-scriptobject $className
            withobject $newInstance outer 4 5 6 | Should BeExactly 22
        }

        It "can invoke other methods in the object using the 'withobject' alias with the `$this variable and passing variable arguments using @args" {

            $className = 'ClassClass24'

            ScriptClass $className {
                $mainValue = 7
                function outer {
                    withobject $this inner @args
                }

                function inner($first, $second, $third) {
                    $this.mainValue + $first + $second + $third
                }
            }

            $newInstance = new-scriptobject $className
            withobject $newInstance outer 4 5 6 | Should BeExactly 22
        }

        It "can invoke other methods in the object using 'withobject' without the `$this variable by implying it" {
            $className = 'ClassClass42'

            ScriptClass $className {
                $mainValue = 7
                function outer($arg1, $arg2, $arg3) {
                    inner $arg3 ($arg1 + $arg2)
                }

                function inner($first, $second) {
                    $this.mainValue + $first + $second
                }
            }

            $newInstance = new-scriptobject $className
            withobject $newInstance outer 4 5 6 | Should BeExactly 22
        }

        It "can invoke other methods in the object using normal cmdlet call syntax against methods and implied `$this variable" {

            $className = 'ClassClass41'

            ScriptClass $className {
                $mainValue = 7
                function outer {
                    inner @args
                }

                function inner($first, $second, $third) {
                    $this.mainValue + $first + $second + $third
                }
            }

            $newInstance = new-scriptobject $className
            withobject $newInstance outer 4 5 6 | Should BeExactly 22
        }

        It "can use the -action parameter to specify a method or scriptblock" {

            $className = 'ClassClass44'

            ScriptClass $className {
                $mainValue = 7
                function outer {
                    inner @args
                }

                function inner($first, $second, $third) {
                    $this.mainValue + $first + $second + $third
                }
            }

            $newInstance = new-scriptobject $className
            withobject $newInstance -action outer 4 5 6 | Should BeExactly 22
            withobject $newInstance -action { outer 3 2 1 } | Should BeExactly 13
        }
    }
}
