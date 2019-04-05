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
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$thismodule = join-path (split-path -parent $here) 'ScriptClass.psd1'

Describe "The class definition interface" {
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

    Context "when creating an object from a class declared with ScriptClass" {
        ScriptClass ClassClass53 {}

        It "can create a new object using new-scriptobject with the specified type" {
            $className = 'ClassClass7'
            ScriptClass $className {}

            $newInstance = new-scriptobject $className
            $newInstance.PSTypeName | Should BeExactly $className
        }

        It "can create a new object using new-so alias for new-scriptobject with the specified type" {
            ScriptClass ClassClass66 {}

            $newInstance = new-so ClassClass66
            $newInstance.PSTypeName | Should BeExactly ClassClass66
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

Describe "The Get-ScriptClass cmdlet" {
    BeforeAll {
        remove-module $thismodule -force -erroraction silentlycontinue
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction silentlycontinue
    }

    ScriptClass ClassClass59 {
    }

    Context "When getting information about a class" {
        It "should return an object with a 'prototype' property equal to the class's scriptclass property" {
            $newInstance = new-scriptobject ClassClass59
            (Get-ScriptClass ClassClass59) | Should BeExactly $newInstance.scriptclass
        }

        It "should return an object with a null scriptclass" {
            (Get-ScriptClass ClassClass59).scriptclass | Should BeExactly $null
        }

        It "should throw an exception if the class does not exist" {
            { Get-ScriptClass idontexist } | Should Throw
        }
    }
}

Describe 'The $:: collection' {
    BeforeAll {
        remove-module $thismodule -force -erroraction silentlycontinue
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction silentlycontinue
    }

    ScriptClass ClassClass60 {}
    ScriptClass ClassClass60a {}
    ScriptClass ClassClass60b {}

    Context 'When accessing the $:: collection' {
        It "should return a class object when the name of the class is specified on it after '.'" {
            $result1 = $::.ClassClass60
            $result1 | Should BeExactly (Get-ScriptClass ClassClass60)
            $result2 = $::.ClassClass60a
            $result2 | Should BeExactly (Get-ScriptClass ClassClass60a)
            $result3 = $::.ClassClass60b
            $result3 | Should BeExactly (Get-ScriptClass ClassClass60b)
        }

        It "should throw an exception when a non-existent class name is specified after '.' when strict mode is enabled" {
            { set-strictmode -version 2; $::.idontexist } | Should Throw
        }

        It "should return a class object that has a pstypedata property" -pending {
            $::.ClassClass60.pstypedata | Should Not Be $null
        }

        It "should return a class object that has a $null scriptclass property" {
            $::.ClassClass60 | gm scriptclass | Should Not Be $null
            $::.ClassClass60.scriptclass | Should Be $null
        }

        It "should throw an exception on an attempt to access a nonexistent property of the class object when strict mode is enabled" {
            { set-strictmode -version 2; $::.ClassClass60.idontexist } | Should Throw
        }
    }
}

Describe "'withobject' alias for object-based command context" {
    BeforeAll {
        remove-module $thismodule -force -erroraction silentlycontinue
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction silentlycontinue
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
#            $myscript = { $newInstance.outer(10, 20, 30) }
#            withobject $newInstance { $newinstance.InvokeScript( $myScript, @() ) } | Should BeExactly 67
#            withobject $newInstance { $newInstance.InvokeScript($myscript, @()) } | Should BeExactly 67
#            $newInstance.InvokeScript($$myscript, @()) | Should BeExactly 67
#            withobject $newInstance { $this.InvokeMe( $myScript ) } | Should BeExactly 67
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
}

Describe 'The => invocation function' {
    BeforeAll {
        remove-module $thismodule -force -erroraction silentlycontinue
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction silentlycontinue
    }

    Context "When a method is invoked through the => function" {
        $initialValue = 10
        ScriptClass ClassClass43 {
            $sum = 3

            function __initialize($startVal) {
                $this.sum = $startVal
            }

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

            static {
                function staticmethod {
                }
            }
        }

        $newInstance = new-scriptobject ClassClass43 $initialValue
        $newInstance2 = new-scriptobject ClassClass43 $initialValue
        $newInstance3 = new-scriptobject ClassClass43 $initialValue

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
            { => somemethod current } | Should Throw
        }

        It "Should throw an exception if no method is specified" {
            { $newInstance | => } | Should Throw
        }

        It "Should throw an exception if a non-existent method is specified" {
           {$newInstance |=> nonexistent} | Should Throw
        }

        It "Should throw an exception if a static method is specified" {
            {$newInstance |=> staticmethod} | Should Throw
        }

        It "Should invoke static methods when used on an instance's scriptclass property" {
            $newInstance.scriptclass |=> staticmethod 25 31 Should BeExactly 56
        }

        It "Should throw an exception if the method attempts to access the PSCmdlet variable when invoked by a cmdlet attributed with CmdletBinding" {
            ScriptClass ClassUsingPsCmdlet {
                function Get {
                    $PSCmdlet
                }
            }

            function Get-PSCmdlet {
                [cmdletbinding()]
                $myobj = new-so ClassUsingPsCmdlet

                $myobj |=> Get
            }

            { Get-PSCmdlet } | Should Throw
        }
    }
}

Describe 'Static functions' {
    BeforeAll {
        remove-module $thismodule -force -erroraction silentlycontinue
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction silentlycontinue
    }

    ScriptClass ClassClass52 {
        static {
            function staticmethod($arg1, $arg2) {
                $arg1 + $arg2
            }

            function staticmethod2($arg1, $arg2) {
                $this |=> staticmethod $arg1 $arg2
            }
        }

        function instancemethod {}
    }

    Context "When a static method is invoked through ::>" {
        It 'Should accept the name of the class as a string as the class on which to call the method' {
            'ClassClass52' |::> staticmethod 8 5 | Should BeExactly 13
        }

        It "should accept the scriptclass property of an instance as a way to invoke the static method" {
            $newInstance = new-scriptobject ClassClass52
            withobject $newInstance.scriptclass staticmethod 20 50 Should BeExactly 70
        }

        It "should be accessible from within the class initializer" {
            ScriptClass ClassClass74 {
                $mainValue = $null
                static {
                    function InitialVal {
                        7
                    }
                }
                function __initialize {
                    $this.mainValue = ('ClassClass74' |::> InitialVal)
                }
            }

            $newInstance = new-so ClassClass74

            $newInstance.mainValue | Should BeExactly 7
        }

        It "has a `$this variable available to static methods that enables access to other static members in the class" {
            $::.ClassClass52 |=> staticmethod2 13 3 | Should BeExactly 16
        }

        It "should throw an exception if the type piped to ::> is not a string" {
            { $::.ClassClass52 |::> instancemethod } | Should Throw
        }

        It "should throw an exception if the class piped to ::> does not exist" {
            { 'idontexist' |::> instancemethod } | Should Throw
        }

        It "should throw an exception if the method passed to ::> does not exist" {
            { 'ClassClass52' |::> idontexist } | Should Throw
        }


        It "Should throw an exception if the operator is used to call an instance method" {
            { 'ClassClass52' |::> instancemethod } | Should Throw
        }
    }

    Context "When a static method is invoked through invoke-method or with or =>" {
        It 'Should accept the result of Get-ScriptClass as the class on which to call the method for invoke-methodwithcontext' {
            invoke-method (Get-ScriptClass ClassClass52) staticmethod 2 3 | Should BeExactly 5
        }

        It 'Should accept the result of Get-ScriptClass as the class on which to call the method for "with"' {
            withobject (Get-ScriptClass ClassClass52) staticmethod 2 3 | Should BeExactly 5
        }

        It 'Should allow invocation of the static method by supplying "withobject" with a block' {
            withobject (Get-ScriptClass ClassClass52) { staticmethod 10 40 } Should BeExactly 50
        }

        It 'Should allow invocation of the static method by supplying scriptclass method as the object' {
            $newInstance = new-scriptobject ClassClass52
            withobject $newInstance.scriptclass staticmethod 20 50 Should BeExactly 70
        }

        It "Should accept the `$:: variable's property named by the class as the class on which to call the method using =>" {
            $::.ClassClass52 |=> staticmethod 10 4 | Should BeExactly 14
        }

        It 'Should accept the result of Get-ScriptClass as the class on which to call the method using =>' {
            (Get-ScriptClass ClassClass52) |=> staticmethod 2 3 | Should BeExactly 5
        }

        It "Should allow arguments to a static scriptclass method to be passed by name" {
            ScriptClass MethodByNameClass {
                static {
                    function NameMethod($arg1 = 0, $arg2 = 0, $arg3 = 0) {
                        $arg3 + $arg2 * 10 + $arg1 * 100
                    }
                }
            }

            $::.MethodByNameClass |=> NameMethod 6 4 5 | Should Be 645

            $::.MethodByNameClass |=> NameMethod -Arg2 9 | Should Be 90
        }
    }

    Context "When defining static methods" {
        It "Should allow an instance method and a static method to have the same name" {
            {
                ScriptClass ClassClass55 {
                    function bothtypes {}
                    static { function bothtypes {} }
                }
            } | Should Not Throw
        }

        Context "when static and instance methods have the same name and the instance method is defined first" {
            ScriptClass ClassClass56 {
                function bothtypes {
                    7
                }

                static {
                    function bothtypes {
                        5
                    }
                }
            }

            It "Should invoke the static method when the ::> method is used" {
                'ClassClass56' |::> bothtypes | Should BeExactly 5
            }

            It "Should invoke the instance method when the => function is used" {
                $newInstance = new-scriptobject ClassClass56
                $newInstance |=> bothtypes | Should BeExactly 7
            }

            It "Should invoke the static method when the => function is supplied with an instance's scriptclass property" {
                $newInstance = new-scriptobject ClassClass56
                $newInstance.scriptclass |=> bothtypes | Should BeExactly 5
            }
        }

        Context "when static and instance methods have the same name and the static method is defined first" {
            ScriptClass ClassClass57 {
                static {
                    function bothtypes {
                        5
                    }
                }

                function bothtypes {
                    7
                }
            }

            It "Should invoke the static method when the ::> method is used" {
                'ClassClass57' |::> bothtypes | Should BeExactly 5
            }

            It "Should invoke the instance method when the => function is used" {
                $newInstance = new-scriptobject ClassClass57
                $newInstance |=> bothtypes | Should BeExactly 7
            }

            It "Should invoke the static method when the => function is supplied with an instance's scriptclass property" {
                $newInstance = new-scriptobject ClassClass57
                $newInstance.scriptclass |=> bothtypes | Should BeExactly 5
            }
        }

        Context "when the static method is defined twice" {
            ScriptClass ClassClass58 {
                static {
                    function bothtypes {
                        5
                    }
                    function bothtypes {
                        6
                    }
                }

                function bothtypes {
                    7
                }
            }

            It "Should invoke the last static method defined when the ::> method is used" {
                'ClassClass58' |::> bothtypes | Should BeExactly 6
            }

            It "Should invoke the instance method when the => function is used" {
                $newInstance = new-scriptobject ClassClass58
                $newInstance |=> bothtypes | Should BeExactly 7
            }
        }

        It "Does not allow the use of 'static' within a static block" {
            {
                ScriptClass ClassClass80 {
                    static {
                        static {
                            $thisshouldnotwork = $null
                        }
                    }
                }
            } | Should Throw
        }
    }
}

Describe 'Static member variables' {
    BeforeAll {
        remove-module $thismodule -force -erroraction silentlycontinue
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction silentlycontinue
    }

    Context "When declaring a class with static member variables" {
        ScriptClass ClassClass75 {
            static {
                $var1 = $null
                $var2 = 7

                function getvar {
                    $this.var2
                }
            }
        }

        It "should not have variables accessible through the ::> function for the class" {
            {
                'ClassClass75' |::> var2 | Should BeExactly 7
            } | Should Throw
        }

        It 'should have variables accessible through the $:: member for the class' {
            $::.ClassClass75.var1 | Should BeExactly $null
            $::.ClassClass75.var2 | Should BeExactly 7
        }

        It 'should have variables accessible through the scriptclass member of an instance' {
            $newInstance = new-so ClassClass75
            $newInstance.scriptclass.var1 | Should BeExactly $null
            $newInstance.scriptclass.var2 | Should BeExactly 7
        }

        It 'should have static member variables available to static methods through a $this variable' {
            $::.ClassClass75 |=> getvar | Should BeExactly 7
        }

        It "should throw an exception if there is an attempt to access variables through the ::> function for the class" {
            { 'ClassClass75' |::> var2 | out-null } | Should Throw
        }

        It "should throw an exception if a static variable that was not defined is passed to the ::> function" {
            { 'ClassClass75' |::> var3 | out-null } | Should Throw
        }

        It 'should throw an exception if a static variable that was not defined is accessed as a member of $:: when strict-mode is 2 or higher' {
            { set-strictmode -version 2; $::.ClassClass75.var3 | out-null } | Should Throw
        }

        It 'should throw an exception if a static variable that was not defined is accessed as a member of an instance scriptclass member when strict-mode is 2 or higher' {
            $newInstance = new-so ClassClass75
            { set-strictmode -version2; $newInstance.var3 | out-null } | Should Throw
        }

        It 'should update the value of the variable when it is assigned by accessing the class member of $::' {
            ScriptClass ClassClass76 {
                static {
                    $var1 = 4
                }
            }
            $::.ClassClass75.var1 = 10
            $::.ClassClass75.var1 | Should BeExactly 10
        }

        It 'should be accessible for read and write through static and instance methods' {
            ScriptClass ClassClass77 {
                static {
                    $instances = 0
                    function InstanceCount {
                        $this.instances
                    }
                }

                function __initialize {
                    $this.scriptclass.instances++
                }
            }

            $newInstance = new-so ClassClass77
            $::.ClassClass77.instances | Should BeExactly 1
            $::.ClassClass77 |=> InstanceCount | Should BeExactly 1
            $secondInstance = new-so ClassClass77

            $::.ClassClass77 |=> InstanceCount | Should BeExactly 2
            $::.ClassClass77 |=> InstanceCount | Should BeExactly $::.ClassClass77.instances
        }
    }

    Context "When static variables are defined with the same name as a non-static variable" {
        ScriptClass ClassClass78 {
            $bothtypes = 7
            static { $bothtypes = 5 }
        }

        $newInstance = new-so ClassClass78

        It 'should allow static and non-static variables of the same name to be defined' {
            $newInstance.bothtypes | Should BeExactly 7
            $newInstance.scriptclass.bothtypes | Should BeExactly 5
        }
    }

    It "Does not allow the use of 'static' within a static block" {
        {
            ScriptClass ClassClass80 {
                static {
                    static {
                        $thisshouldnotwork = $null
                    }
                }
            }
        } | Should Throw
    }
}

Describe 'Internal ScriptClass State' {
    BeforeAll {
        # This only happens for the first static class defined by scriptclass, simulate
        # by removing the variable
        remove-variable -scope 0 __staticBlockLocalVariablesToRemove -erroraction ignore

        remove-module $thismodule -force -erroraction silentlycontinue
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction silentlycontinue
    }

    Context "When defining static members" {
        It "Should not reproduce a defect where an extra instance property from ScriptClass internals was present when a class is dot-sourced and the static function is used" {
            # Requires the script variable __staticBlockLocalVariablesToRemove to be removed
            # in beforeall
            . {
                ScriptClass DotSourcedClassWithStatic {
                    static {
                    }
                }
            }

            $classInfo = Get-ScriptClass -detailed DotSourcedClassWithStatic
            $classInfo.classDefinition.instanceproperties.count | Should Be 0
        }

        It "Should only have class members ClassName, ScriptClass, Module, and the user specified member variables" {
            $noExtraMemberClass = 'ScriptClassStaticNoExtra'
            ScriptClass $noExtraMemberClass {
                static {
                    $member1 = 2
                    $member2 = 2
                    $member3 = 3
                }
            }

            $expectedMembers = @(
                'ClassName',
                'ScriptClass',
                'Module',
                'member1',
                'member2',
                'member3'
            )

            $NoExtraMembersClassList = ($:: | select -ExpandProperty $noExtraMemberClass |
              gm -membertype noteproperty, scriptproperty | select -expandproperty name | sort) -join ';'
            $expectedMembersList = ($expectedMembers | sort) -join ';'

            $noExtramembersClassList | Should Be $expectedMembersList
        }
    }
}

Describe 'Typed static member variables' {
    BeforeAll {
        remove-module $thismodule -force -erroraction silentlycontinue
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction silentlycontinue
    }

    Context 'When declaring typed static members with strict-val' {
        ScriptClass ClassClass79 {
            static {
                $stuff = strict-val [object]
                $stuffint = strict-val [int32]
                $stufftype = strict-val [Type]
                $stuffintval = strict-val [int] 1
                $stufftypeval = strict-val [Type] ([int])
            }
        }

        It 'should allow the typed static member of type [object] with no initializer to evaluate as $null' {
            $::.ClassClass79.stuff | Should BeExactly $null
        }

        It 'should allow the typed static member of type [object] with no initializer to be assigned a value' {
            $::.ClassClass79.stuff = 512
            $::.ClassClass79.stuff | Should BeExactly 512
        }

        It "should enforce type mismatch errors when defining" {
            { $::.ClassClass79.stuffint = new-object object } | Should Throw
            { $::.ClassClass79.stufftype = ([string]) } | Should Not Throw
            { $::.ClassClass79.stufftype = '2' } | Should Throw
        }

        It "can create a new object that includes additional typed properties set to default values with strict-val" {
            $::.ClassClass79.stuffintval | Should BeExactly 1
            $::.ClassClass79.stufftypeval | Should BeExactly ([int])
        }
    }
}

Describe 'The test-scriptobject cmdlet' {
    BeforeAll {
        remove-module $thismodule -force -erroraction silentlycontinue
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction silentlycontinue
    }

    ScriptClass ClassClass64 {}
    ScriptClass ClassClass65 {}
    $newInstance = new-scriptobject ClassClass64
    It 'Should return $true if only a scriptclass object instance is specified by position' {
        test-scriptobject $newInstance | Should BeExactly $true
    }

    It 'Should return $true if a scriptclass object instance is specified through the pipeline' {
        $newInstance | test-scriptobject | Should BeExactly $true
    }

    It 'Should return $true if a scriptclass object is specified with its script class type name' {
        test-scriptobject $newInstance ClassClass64 | Should BeExactly $true
    }

    It 'Should return $true if a scriptclass object is specified with its scriptclass class object' {
        test-scriptobject $newInstance $::.ClassClass64 | Should BeExactly $true
    }

    It 'Should return $false if a scriptclass object is specified with a valid scriptclass class name of a different scriptclass than the instance' {
        test-scriptobject $newInstance 'ClassClass65' | Should BeExactly $false
    }

    It 'Should return $false if a scriptclass object is specified with a valid scriptclass class object of a different scriptclass than the instance' {
        test-scriptobject $newInstance $::.ClassClass65 | Should BeExactly $false
    }

    It 'Should return $false if only a non-scriptclass object is specified' {
        test-scriptobject [Type] | Should BeExactly $false
        test-scriptobject 3 | Should BeExactly $false
    }

    It 'Should return $false if non-scriptclass object is specified with a scriptclass type name' {
        test-scriptobject ([Type]) ClassClass64 | Should BeExactly $false
        test-scriptobject 3 ClassClass64 | Should BeExactly $false
    }

    It 'Should return false if the scriptclass parameter is a string that is not the name of defined scriptclass' {
        test-scriptobject $newInstance 'idontexist' | Should Be $false
    }

    It 'Should throw an exception if the scriptclass parameter is not a PSCustomObject' {
        { test-scriptobject $newInstance 3 | out-null } | Should Throw
    }

    It 'Should throw an exception if the scriptclass parameter is not a PSCustomObject created with new-scriptobject with a PSTypeName that matches the class' {
        $custom = [PSCustomObject]@{field1=1;field2=2}
        $typedcustom = [PSCustomObject]@{field1=1;field2=2;PSTypeName='notascriptclass'}
        { test-scriptobject $newInstance $custom | out-null } | Should Throw
        { test-scriptobject $newInstance $typedcustom | out-null } | Should Throw
    }
}

Describe "The const cmdlet" {
    BeforeAll {
        remove-module $thismodule -force -erroraction silentlycontinue
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction silentlycontinue
    }

    function clean-variable($name) {
        $existing = $true

        @('Script', 'Local', 1) | foreach {
            $existing = get-variable -name $name -scope $_ -erroraction silentlycontinue

            if ($existing -ne $null) {
                $existing | remove-variable -scope $_ -force
            } else {
                break
            }
        }
    }

    function variable-exists($name) {
        (get-variable -name $name -erroraction silentlycontinue) -ne $null
    }

    BeforeEach {
        clean-variable testvar
        variable-exists testvar | Should Be False
    }

    AfterEach {
        clean-variable testvar
        variable-exists testvar | Should Be False
    }

    Context "when defining constants" {
        ScriptClass ConstTest0 {
            const testConst 159
            const strictConst (strict-val [double] 11)
            function writeConstant($value) {
                $this.testConst = $value
            }
        }
        It "creates a read-only variable with the specified value" {
            $newInstance = new-so ConstTest0
            $newInstance.testConst | Should BeExactly 159
        }

        It "throws an exception if an assignment is made to the constant even if the value is the same as the existing value" {
            { ScriptClass ConstTest1 { const testvar 159; $testvar = 157 } } | Should Throw "Cannot Overwrite"
            { ScriptClass ConstTest2 { const testvar 159; $testvar = 159 } } | Should Throw "Cannot overwrite"
        }

        It "throws an exception if an assignment is made to the constant by consumers of the object" {
            $newInstance = new-so ConstTest0
            { $newInstance.testConst = $newInstance.testConst } | Should Throw "Exception setting"
            { $newInstance.testConst = ( $newInstance.testConst - 1) } | Should Throw "Exception setting"
        }

        It "throws an exception if an assignment is made to the constant by methods of the object" {
            $newInstance = new-so ConstTest0
            { $newInstance |=> writeConstant $newInstance.testConst } | Should Throw "Exception setting"
            { $newInstance |=> writeConstant ( $newInstance.testConst - 1 ) } | Should Throw "Exception setting"
        }

        It "throws an exception if an attempt is made to define it with a different value" {
            { ScriptClass ConstTest3 { const testvar 156; const testvar 157} } | Should Throw "Attempt to redefine"
        }

        It "does not throw an exception if const is used to define the value more than once with the same value" {
            { ScriptClass ConstTest4 { const testvar 159; const testvar 159} } | Should Not Throw
        }

        It "does not conflict with a variable with the same name defined at script scope" {
            ScriptClass ConstTest5 { const testvar 159; function getval { $this.testvar } }
            new-variable testvar -scope script -value 157
            $newInstance = new-so ConstTest5
            $newInstance.testvar | Should BeExactly 159
            $newInstance |=> getval | Should BeExactly 159
            $testvar | Should BeExactly 157
            $script:testvar | Should BeExactly 157
        }

        It "does not conflict with a variable with the same name defined at local scope" {
            ScriptClass ConstTest6 { const testvar 159; function getval { $testvar = 5; $testvar } }
            $newInstance = new-so ConstTest6
            $newInstance.testvar | Should BeExactly 159
            $newInstance |=> getval | Should BeExactly 5
        }

        It "defines strictly typed constants when used with 'strict-val'" {
            $newInstance = new-so ConstTest0
            $newInstance.strictConst.gettype() | Should BeExactly 'double'
            ([int] $newInstance.strictConst) | Should BeExactly 11
        }

    }

    Context "When a ScriptClass instance is serialized or deserialized" {

        It "Does not serialize any method source code" {
            ScriptClass SerializationClass {
                function GetDataFromSource {
                    '__onlyfoundinmethodsource__'
                }
            }

            $newInstance = new-so SerializationClass
            $serializedClass = $newInstance | convertto-json
            $dataFromSource = $newInstance |=> GetDataFromSource
            $serializedClass | sls $dataFromSource | Should Be $null
        }

        It "Throws an exception when a ScriptClass  method of a deserialized class is invoked with . notation" {
            ScriptClass DeserializedFailure {
                function TestMethod {
                }
            }

            $newInstance = new-so DeserializedFailure
            { $newInstance |=> TestMethod } | Should Not Throw
            { $newInstance.TestMethod() } | Should Not Throw
            $job = start-job { param($scriptclassInstance) $scriptclassInstance } -argumentlist $newInstance
            $deserializedInstance = receive-job $job
            { $deserializedInstance.TestMethod() } | Should Throw
        }

        It "Returns the same value using instance state as a non-deserialized class without an exception when a ScriptClass method of a deserialized class is invoked with invoke-method notation" {
            ScriptClass DeserializedSuccess {
                $state = $null
                function __initialize($state) {
                    $this.state = $state
                }
                function GetClassState {
                    $this.state
                }
            }

            $stateValue = 159
            $newInstance = new-so DeserializedSuccess $stateValue
            $newInstance |=> GetClassState | Should Be $stateValue
            $newInstance.GetClassState() | Should Be $stateValue

            $job = start-job { param($scriptclassInstance) $scriptclassInstance } -argumentlist $newInstance
            $deserializedInstance = receive-job $job -wait
            { $deserializedInstance.GetClassState() } | Should Throw
            $deserializedInstance |=> GetClassState | Should Be $stateValue
        }

        It "Restores . method invocation after a method is invoked with invoke-method notation once" {
            ScriptClass DeserializedRestore {
                $state = $null
                function __initialize($state) {
                    $this.state = $state
                }
                function GetClassState {
                    $this.state
                }
            }

            $stateValue = 157
            $newInstance = new-so DeserializedRestore $stateValue
            $newInstance |=> GetClassState | Should Be $stateValue
            $newInstance.GetClassState() | Should Be $stateValue

            $job = start-job { param($scriptclassInstance) $scriptclassInstance } -argumentlist $newInstance
            $deserializedInstance = receive-job $job -wait
            { $deserializedInstance.GetClassState() } | Should Throw
            $deserializedInstance |=> GetClassState | Should Be $stateValue
            $deserializedInstance.GetClassState() | Should Be $stateValue
        }

            It "Does not serialize any instance method source code or internal method references" {
            ScriptClass SerializationClass {
                function GetDataFromSource {
                    '__onlyfoundinmethodsource__'
                }
            }

            $newInstance = new-so SerializationClass
            $serializedClass = $newInstance | convertto-json
            $dataFromSource = $newInstance |=> GetDataFromSource
            $serializedClass | sls $dataFromSource | Should Be $null
        }

        It "Does not serialize any static method source code or method references" {
            ScriptClass SerializationClass {
                static {
                    function GetDataFromSource {
                        '__onlyfoundinmethodsource__'
                    }
                }
            }

            $newInstance = new-so SerializationClass
            $serializedClass = $newInstance | convertto-json
            $dataFromSource = $newInstance.scriptclass |=> GetDataFromSource
            $serializedClass | sls $dataFromSource | Should Be $null
            $serializedClass | sls '__add-member' | Should Be $null
            $serializedClass | sls '__find-class' | Should Be $null
        }
    }
}

Describe "Hash codes for ScriptClass objects" {
    BeforeAll {
        remove-module $thismodule -force -erroraction ignore
        import-module $thismodule -force
    }

    ScriptClass FirstClass {
    }

    ScriptClass SecondClass {
    }

    $Class1Instance1 = new-so FirstClass
    $Class1Instance2 = new-so FirstClass

    $Class2Instance1 = new-so SecondClass
    $Class2Instance2 = new-so SecondClass

    Context "When the GetScriptClassHashCode method is invoked on ScriptClass instance objects" {
        It "Should return an integer hash code" {
            $hashcode = $Class1Instance1.GetScriptObjectHashCode()
            $hashcode -is [int] | Should Be $true
            $hashcode | Should Not Be 0
        }

        It "Should return the same value as the first time when it is invoked more than once on the same instance object" {
            $lastVal = $null

            for ($current = 0; $current -lt 10; $current++ ) {
                $hashcode = $Class1Instance1.GetScriptObjectHashCode()
                if ( $lastVal ) {
                    $hashcode | Should BeExactly $lastVal
                }

                $lastVal = $hashcode
            }
        }

        It "Should have unique hash codes for two ScriptClass instance objects of the same class" {
            $Class1Instance1.GetScriptObjectHashCode() | Should Not Be $class1Instance2.GetScriptObjectHashCode()
        }

        It "Should have unique hash codes for two ScriptClass instance objects of different classes" {
            $Class1Instance1.GetScriptObjectHashCode() | Should Not Be $class2Instance1.GetScriptObjectHashCode()
        }
    }


    Context "When the GetScriptClassHashCode method is invoked on ScriptClass class objects" {
        It "Should return a non-zero integer hash code" {
            $hashcode = $Class1Instance1.scriptclass.GetScriptObjectHashCode()
            $hashcode -is [int] | Should Be $true
            $hashcode | Should Not Be 0
        }

        It "Should return the same value as the first time when it is invoked more than once on the same instance object" {
            $lastVal = $null

            for ($current = 0; $current -lt 10; $current++ ) {
                $hashcode = $Class1Instance1.scriptclass.GetScriptObjectHashCode()
                if ( $lastVal ) {
                    $hashcode | Should BeExactly $lastVal
                }

                $lastVal = $hashcode
            }
        }

        It "Should have the same codes for the ScriptClass property for two ScriptClass instance objects of the same class" {
            $Class1Instance1.scriptclass.GetScriptObjectHashCode() | Should BeExactly $class1Instance2.scriptclass.GetScriptObjectHashCode()
        }

        It "Should have unique hash codes for the ScriptClass property for two ScriptClass instance objects of different classes" {
            $Class1Instance1.scriptclass.GetScriptObjectHashCode() | Should Not Be $class2Instance1.scriptclass.GetScriptObjectHashCode()
        }
    }
}

