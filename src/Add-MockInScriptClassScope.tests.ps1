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
# limitations under the License

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$thismodule = join-path (split-path -parent $here) 'ScriptClass.psd1'

Describe "AddMockInScriptClassScope cmdlet" {
    BeforeAll {
        remove-module $thismodule -force -erroraction silentlycontinue
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction silentlycontinue
    }

    Context "When mocking a command called from within a scriptclass method" {
        ScriptClass CommandClass {
            static {
                function GetProcesses {
                    get-process
                }
            }

            function InstanceGetProcess {
                get-process
            }

            function GetFileShareData {
                Get-FileShare
            }

            function GetComputerData {
                Get-ComputerInfo
            }
        }

        ScriptClass CommandClass2 {
            static {
                function GetProcesses {
                    get-process
                }
            }

            function InstanceGetProcess {
                get-process
            }
        }

        Add-MockInScriptClassScope CommandClass get-process { 5 }

        It 'Should return the original value instead of the mocked value when the mocked command is called outside the scope of any ScriptClass' {
            Get-Process | Should Not Be 5
        }

        It 'Should return the original value instead of the mocked value when the mocked command is called from the scope of a static method of different class than the one named by the ClassName parameter' {
            $::.CommandClass2 |=> GetProcesses | Should Not Be 5
        }

        It 'Should return the original value instead of the mocked value when the mocked command is called from the scope of an instance method of different class than the one named by the ClassName parameter' {
            $instance = new-so CommandClass2

            $instance |=> InstanceGetProcess | Should Not Be 5
        }

        It 'Should return the mocked value for the command when it is called from a static method of the class' {
            $::.CommandClass |=> GetProcesses | Should Be 5
        }

        It 'Should return the mocked value for the command when it is called from an instance method of the class' {
            $instance = new-so CommandClass

            $instance |=> InstanceGetProcess | Should Be 5
        }

        It 'Should return the mocked value for the command using parameters passed through the Contect parameter' {
            Add-MockInScriptClassScope CommandClass get-fileshare { $MockContext.value } -MockContext @{value=10}
            $instance = new-so CommandClass

            $instance |=> GetFileShareData | Should Be 10
        }

        It 'Should throw an exception if the mock scriptblock attempts to access a variable defined in the scope that called the cmdlet' {
            $computerData = 9
            Add-MockInScriptClassScope CommandClass get-computerinfo { $computerData }
            $instance = new-so CommandClass

            { $instance |=> GetComputerData } | Should Throw
        }
    }
}
