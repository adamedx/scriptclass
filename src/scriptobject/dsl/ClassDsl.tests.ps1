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
$thismodule = join-path (split-path -parent $here) '..\..\ScriptClass.psd1'

Describe 'ScriptClass DSL static method definition' {
    BeforeAll {
        remove-module $thismodule -force -erroraction ignore
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction ignore
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

Describe 'ScriptClass DSL static member variables' {
    BeforeAll {
        remove-module $thismodule -force -erroraction ignore
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction ignore
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

Describe 'ScriptClass DSL internal ScriptClass State' {
    BeforeAll {
        # This only happens for the first static class defined by scriptclass, simulate
        # by removing the variable
        remove-variable -scope 0 __staticBlockLocalVariablesToRemove -erroraction ignore

        remove-module $thismodule -force -erroraction ignore
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction ignore
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

Describe 'Typed static member variables DSL' {
    BeforeAll {
        remove-module $thismodule -force -erroraction ignore
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction ignore
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

Describe "The const dsl function" {
    BeforeAll {
        remove-module $thismodule -force -erroraction ignore
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction ignore
    }

    function clean-variable($name) {
        $existing = $true

        @('Script', 'Local', 1) | foreach {
            $existing = get-variable -name $name -scope $_ -erroraction ignore

            if ($existing -ne $null) {
                $existing | remove-variable -scope $_ -force
            } else {
                break
            }
        }
    }

    function variable-exists($name) {
        (get-variable -name $name -erroraction ignore) -ne $null
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
