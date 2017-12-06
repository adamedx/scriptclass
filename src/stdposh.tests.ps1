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
            $expectedFunctions = @('=>', '::>', 'add-scriptclass', 'invoke-method', 'test-scriptobject', 'new-scriptobject', 'import-source', 'import-assembly', 'get-librarybase')

            $manifest.ExportedFunctions.count | Should BeExactly $expectedFunctions.length

            $verifiedExportsCount = 0
            $expectedFunctions | foreach {
                if ( $manifest.exportedfunctions[$_] -ne $null ) {
                    $verifiedExportsCount++
                }
            }
            $verifiedExportsCount -eq $expectedFunctions.length | Should BeExactly $true
        }

        It "should export the '::' and 'include' variables and only those variables" {
            $manifest.exportedvariables.count | Should BeExactly 2
            $manifest.exportedvariables.keys -contains '::' | Should BeExactly $true
            $manifest.exportedvariables.keys -contains 'include' | Should BeExactly $true
        }

        It "should export the 'new-so', 'ScriptClass', 'include-source', 'load-assembly', and 'with' aliases and only those aliases" {
            $manifest.exportedaliases.count | Should BeExactly 5
            $manifest.exportedaliases.keys -contains 'new-so' | Should BeExactly $true
            $manifest.exportedaliases.keys -contains 'ScriptClass' | Should BeExactly $true
            $manifest.exportedaliases.keys -contains 'with' | Should BeExactly $true
            $manifest.exportedaliases.keys -contains 'include-source' | Should BeExactly $true
            $manifest.exportedaliases.keys -contains 'load-assembly' | Should BeExactly $true

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

Describe 'The get-librarybase function' {
    Context "When the module is imported" {
        It "The function should return the parent directory of the directory in which the module is installed" {
            $scriptParent = split-path -parent $psscriptroot
            $scriptParentParent = split-path -parent $scriptParent

            # The module file may be in a source directory, or it may be an installed package
            # using the path convention `modulename\version\modulename.psm1`, look for the name
            # that way
            $moduleLocation = if ( (split-path -leaf $scriptParent) -eq 'stdposh' ) {
                $scriptParent
            } else {
                $scriptParentParent
            }

            test-path $moduleLocation | Should BeExactly $true
            $moduleParent = split-path -parent $moduleLocation
            $libraryBaseOutputCommand = "`$erroractionpreference = 'stop';import-module '$moduleLocation';get-LibraryBase"
            $libraryBaseOutput = iex "powershell -noprofile -command { $libraryBaseOutputCommand }"
            $libraryBaseOutput | Should Be $moduleParent
        }
    }
}

