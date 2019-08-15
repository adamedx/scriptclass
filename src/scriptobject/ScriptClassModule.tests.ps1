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

Describe "Cross-module behavior" {
    set-strictmode -version 2

    $elementSeparator = if ( $PSVersionTable.PSEdition -ne 'Desktop' -and $PSVersionTable.Platform -ne 'Win32NT' ) {
        ':'
    } else {
        ';'
    }

    $sourceModuleDirectory = (get-item (join-path $psscriptroot ../..)).fullname
    $testModuleDirectory = (get-item (join-path $psscriptroot ../../test/assets/ModuleTests)).fullname
    $testModPath = $elementSeparator + $sourceModuleDirectory + $elementSeparator + $testModuleDirectory
    $modules = @(
        'modA'
        'modBonA'
        'modConA'
        'modDonAB'
        'modEonB'
        'modFonBC'
    )

    Context "Access ScriptClass types and objects across modules" {
        BeforeAll {
            if ( ! ($env:PSModulePath).EndsWith($testModPath) ) {
                si env:PSModulePath (($env:PSModulePath) + $testModPath)
            }
        }

        It "Should be able to access the directory '$sourceModuleDirectory', the root of the repository, in order to run these tests" {
            test-path $sourceModuleDirectory | Should Be $true
        }

        It "Should have a path that ends with test module path" {
             ($env:PSModulePath).EndsWith($testModPath) | Should Be $true
        }

        It "Should have paths that exist so that the test is valid" {
            {
                $modules | foreach {
                    $modPath = join-path $testModuleDirectory $_
                    get-item $modPath | out-null
                }
            } | Should Not Throw
        }


        It "Should successfully load modules with various dependency relationships" {
            {
                # Need to use ErrorAction 'stop' in receive-job otherwise module load failures are ignored
                $modules | foreach {
                    start-job {param($mod) import-module $mod} -argumentlist $_ | wait-job | receive-job -erroraction 'stop'
                }
            } | should not throw
        }

        AfterAll {
            if ( ($env:PSModulePath).EndsWith($testModPath) ) {
                si env:PSModulePath ($env:PSModulePath).substring(0, $env:PSModulePath.length - $testModPath.length)
            }
        }
    }
}
