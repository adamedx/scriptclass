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

$here = split-path -parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

Describe "Stdposh module manifest" {
    $manifestLocation   = Join-Path $here 'stdposh.psd1'
    $manifest = Test-ModuleManifest -Path $manifestlocation -ErrorAction Stop -WarningAction SilentlyContinue

    Context "When loading the manifest" {
        It "should export the exact same set of functions as are in the set of expected functions" {
            $expectedFunctions = @('=>', '::>', 'add-scriptclass', 'invoke-method', 'is-scriptobject', 'new-scriptobject', 'include-source', 'load-assembly')

            $manifest.ExportedFunctions.count | Should BeExactly $expectedFunctions.length

            $verifiedExportsCount = 0
            $expectedFunctions | foreach {
                if ( $manifest.exportedfunctions[$_] -ne $null ) {
                    $verifiedExportsCount++
                }
            }
            $verifiedExportsCount -eq $expectedFunctions.length | Should BeExactly $true
        }

        It "should export the '::' and 'include' variables and only the" {
            $manifest.exportedvariables.count | Should BeExactly 2
            $manifest.exportedvariables.keys -contains '::' | Should BeExactly $true
            $manifest.exportedvariables.keys -contains 'include' | Should BeExactly $true
        }

        It "should export the 'new-so', 'ScriptClass', and 'with' aliases and only those aliases" {
            $manifest.exportedaliases.count | Should BeExactly 3
            $manifest.exportedaliases.keys -contains 'new-so' | Should BeExactly $true
            $manifest.exportedaliases.keys -contains 'ScriptClass' | Should BeExactly $true
            $manifest.exportedaliases.keys -contains 'with' | Should BeExactly $true

        }
    }

    Context "When dot sourcing a script that imports library" {
        $scriptentry = (get-item "$here\test\assets\simpletestclient.ps1").fullname
        It "Should dot source without errors" {
            iex "& powershell -noprofile -command { `$erroractionpreference = 'stop'; . '$scriptentry' }"
            $lastexitcode | Should BeExactly 0
        }

        It "Should dot source without errors and allow the definition of a class" {
            $uniqueReturnValue = 23609
            iex "& powershell -noprofile -command { `$erroractionpreference = 'stop'; . '$scriptentry'; ScriptClass ClassTest { `$data = $uniqueReturnValue; function testfunc() { `$this.data }}; `$obj = new-so ClassTest; exit (`$obj |=> testfunc)}"
            $lastexitcode | Should BeExactly $uniqueReturnValue
        }


        It "Should dot source twice in the same session without errors" {
            iex "& powershell -noprofile -command { `$erroractionpreference = 'stop'; . '$scriptentry'; . '$scriptentry'; }"
            $lastexitcode | Should BeExactly 0
        }
    }
}


