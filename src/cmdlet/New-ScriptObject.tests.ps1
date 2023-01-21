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

Describe 'The New-ScriptObject cmdlet' {
    BeforeAll {
        remove-module $thismodule -force -erroraction ignore
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction ignore
    }

Context "when creating an object from a class declared with ScriptClass" {
        ScriptClass ClassClass53 {}

        It "can create a new object using new-scriptobject with the specified type" {
            $className = 'ClassClass7'
            ScriptClass $className {}

            $newInstance = new-scriptobject $className
            $newInstance.scriptclass.classname | Should BeExactly $className
            $newInstance.psobject.typenames -contains $className | Should Be $true
        }

        It "can create a new object using new-so alias for new-scriptobject with the specified type" {
            ScriptClass ClassClass66 {}

            $newInstance = new-so ClassClass66
            $newInstance.ScriptClass.ClassName | Should BeExactly ClassClass66
            $newInstance.psobject.typenames -contains 'ClassClass66' | Should Be $true
        }

        It "has a 'scriptclass' member that has a className member equal to the class name" {
            $newInstance = new-scriptobject ClassClass53

            $newInstance.scriptclass.classname  | Should BeExactly 'ClassClass53'
        }

        It "has a 'scriptclass' member that has a className member equal to the class name" {
            $newInstance = new-scriptobject ClassClass53
            $newInstance.scriptclass | Should Not Be $null
        }

        It "has a 'scriptclass' member that has a null scriptclass  member" {
            $newInstance = new-scriptobject ClassClass53
            $newInstance.scriptclass.scriptclass | Should BeExactly $null
        }

        It "has a 'scriptclass' member that has exactly three noteproperty properties" {
            $newInstance = new-scriptobject ClassClass53
            ($newInstance.scriptclass | gm -membertype noteproperty).count | Should BeExactly 3
        }

        It "has a 'scriptclass' member that is the same object instance as the 'scriptclass' member of a another object of the same scriptclass" {
            $newInstance = new-scriptobject ClassClass53
            $newInstance2 = new-scriptobject ClassClass53

            $newInstance.scriptclass.gethashcode() | Should BeExactly $newInstance2.scriptclass.gethashcode()
        }


        It "can create a new object that includes additional properties to the default properties" {
            $className = 'ClassClass8'
            $prop1 = 'property1'
            $prop2 = 'property2'

            ScriptClass $className {
                $property1 = $null
                $property2 = $null
            }

            $newInstance = new-scriptobject $className
            $newInstance.psobject.properties.match($prop1) | Should BeExactly $true
            $newInstance.psobject.properties.match($prop2) | Should BeExactly $true
            $newInstance.psobject.properties.match('propdoesntexist') | Should BeExactly $null
        }

        It "can create a new object that includes additional properties set to default values" {
            $className = 'ClassClass9'
            $prop1 = 'property1'
            $prop2 = 'property2'

            ScriptClass $className {
                $property1 = 1
                $property2 = 2
            }

            $newInstance = new-scriptobject $className
            $newInstance.$prop1 | Should BeExactly 1
            $newInstance.$prop2 | Should BeExactly 2
        }

        It "can create a new object that defines the type of members with strict-val" {
            $className = 'ClassClass48'
            $prop1 = 'property1'
            $prop2 = 'property2'

            ScriptClass $className {
                $property1 = strict-val [int32]
                $property2 = strict-val [Type]
            }

            $newInstance = new-scriptobject $className

            { $newInstance.$prop1 = 1 } | Should Not Throw
            { $newInstance.$prop1 = new-object object } | Should Throw
            { $newInstance.$prop2 = ([string]) } | Should Not Throw
            { $newInstance.$prop2 = '2' } | Should Throw
        }

        It "can create a new object that includes additional typed properties set to default values with strict-val" {
            $className = 'ClassClass49'
            $prop1 = 'property1'
            $prop2 = 'property2'
            $value1 = 1
            $value2 = [int32]

            ScriptClass $className {
                $property1 = strict-val [int32]
                $property2 = strict-val [Type]
                function __initialize($arg1, $arg2) {
                    $this.property1 = $arg1
                    $this.property2 = $arg2
                }
            }

            $newInstance = new-scriptobject $className $value1 $value2
            $newInstance.$prop1 | Should BeExactly $value1
            $newInstance.$prop2 | Should BeExactly $value2
        }

        It "can create a new object that uses a type with an ambiguous short name like the ordered hashtable type in some PowerShell versions such as 7.3.1" {
            # Added this test because strict-val [ordered] @{} was causing problems on PowerShell 7.3.1 but not other versions. Issue was that
            # within scriptclass we made use of evaluating the string "[$type]" where the variable $type was actually a type, not a string, and for
            # the ordered hash table this evaluated as "ordered" which is not the actual name of the type. Relying on an implied ToString() of the type is
            # not a good idea in general, so the ultimate fix was to use the FullName property of the type which is fully qualified and already a string, giving
            # the unambiguous type required for deterministic behavior across PowerShell versions and other environmental influences.
            $className = 'ClassClass49'
            $prop1 = 'property1'
            $prop2 = 'property2'
            $value1 = @{}
            $value2 = [ordered] @{}

            ScriptClass $className {
                $property1 = strict-val @{}.GetType()
                $property2 = strict-val ([ordered] @{}).GetType()

                function __initialize($arg1, $arg2) {
                    $this.property1 = $arg1
                    $this.property2 = $arg2
                }
            }

            $newInstance = new-scriptobject $className $value1 $value2
            $newInstance.$prop1 | Should BeExactly $value1
            $newInstance.$prop2 | Should BeExactly $value2

            { $newInstance.$prop1 = $prop2 } | Should Throw '"Cannot convert'
            { $newInstance.$prop2 = $prop1 } | Should Throw '"Cannot convert'
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

            $newInstance = new-scriptobject $className

            ($newInstance.psobject.members | select Name).name -contains $function1 | Should BeExactly $true
            ($newInstance.psobject.members | select Name).name -contains $function2 | Should BeExactly $true
            withobject $newInstance $function1 | Should BeExactly $function1Result
            withobject $newInstance $function2 4 5 | Should BeExactly 9
        }


        It "can supply a `$this reference to methods on the class to provide access to properties defined by ScriptClass"  {
            $className = 'ClassClass16'
            $identityResult = "me"

            ScriptClass $className {
                $identity = $null

                function __initialize($resultArg) {
                    $this.identity = $resultArg
                }

                function showme {
                    $this.identity
                }
            }

            $newInstance = new-scriptobject $className $identityResult
            withobject $newInstance showme | should BeExactly $identityResult
        }

        It "throws an exception in class definition if a typed property of the class is initialized with a value of an incompatible type" {
            $className = 'ClassClass12'
            $invalidIntegerValue = 2

            {
                ScriptClass $className {
                    $typeProperty = strict-val [Type] $invalidIntegerValue
                }
            } | Should Throw
        }

        It "cleans up PowerShell type data when one property definition throws an exception" {
            $className = 'ClassClass13'
            $invalidIntegerValue = 2

            {
                ScriptClass $className {
                    $validProperty = $null
                    $typeProperty = strict-val [Type] $invalidIntegerValue
                }
            } | Should Throw
            get-typedata $className | Should BeExactly $null
        }

        Context 'when passing a scriptclass as an argument to a function' {
            ScriptClass ClassClass62 {}
            It "should throw an exception on an attempt to pass it to a function that expects a PSCustomObject with a different PSTypeName" {
                {
                    function typedfunc([PSTypeName('somethertype')] $arg1) {}
                    typedfunc $::.ClassClass62
                } | Should Throw
            }

            It "should not throw an exception on an attempt to pass it to a function that expects a PSCustomObject with PSTypeName identical to the class name" {
                . {
                    function typedfunc([PSTypeName('ClassClass62')] $arg1) {
                        $arg1.scriptclass.classname
                    }
                    typedfunc (new-scriptobject ClassClass62)
                } | Should BeExactly 'ClassClass62'
            }
        }
    }

    Context "When new-scriptobject is used to create a new instance of a class" {
        It "calls the specified initializer function on the new object" {
            $className = 'ClassClass25'
            $initialStateValue = 3

            ScriptClass $className {
                $objectState = $null
                function __initialize {
                    $this.objectState = 3
                }
            }

            $newInstance = new-scriptobject $className

            $newInstance.objectState | Should BeExactly $initialStateValue
        }

        It "calls the specified initializer function on the new object with multiple arguments" {
            $className = 'ClassClass26'
            $initialStateValue = 9

            ScriptClass $className {
                $objectState = $null
                function __initialize($arg1, $arg2) {
                    $this.objectState = $arg1 + $arg2
                }
            }

            $newInstance = new-scriptobject $className 3 6

            $newInstance.objectState | Should BeExactly $initialStateValue

        }

        It "enables calls to the initializer to call other methods defined on the object" {
            $className = 'ClassClass27'
            $initialStateValue = 11

            ScriptClass $className {
                $objectState = $null
                function __initialize($arg1, $arg2) {
                    withobject $this sum $arg1 $arg2
                }

                function sum($first, $second) {
                    $this.objectState = $first + $second
                }
            }

            $newInstance = new-scriptobject $className 4 7

            $newInstance.objectState | Should BeExactly $initialStateValue
        }

        It "can use the new-so alias from within the __initialize method" {
            ScriptClass ClassClass67 { $value = 5 }
            ScriptClass ClassClass68 {
                $indirectValue = $null

                function __initialize {
                    $this.indirectValue = new-so ClassClass67
                }
            }

            $newInstance = new-so ClassClass68

            $newInstance.indirectValue.value | Should BeExactly 5
        }
    }
}
