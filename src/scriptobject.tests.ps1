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
$thismodule = join-path (split-path -parent $here) 'scriptclass.psd1'

Describe 'The $:: collection' {
    BeforeAll {
        remove-module $thismodule -force -erroraction ignore
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction ignore
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

