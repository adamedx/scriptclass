<#
4ec1f7ce-b52c-4761-a7e9-8e534e986d18
a57bd9f7-c7a8-495b-8faa-7adf0eee5b0b
07a7f5f4-68bd-4314-9678-128bf67c90e9
18f5263b-7413-4b8f-939f-250a81f21482
6be5f6c4-8ee8-4beb-8aaa-f6ab3af203a4
b0f405ff-2b6b-43a5-92d9-0654b82cec5c

#>

Describe "Cross-module behavior" {
    set-strictmode -version 2

    $testModPath = ";$psscriptroot;" + (join-path $psscriptroot test)
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

        It "Should have a path that ends with test module path" {
             ($env:PSModulePath).EndsWith($testModPath) | Should Be $true
        }

        It "Should successfully load modules with various dependency relationships" {
            {
                $modules | foreach {
                    start-job {param($mod) import-module $mod} -argumentlist $_ | wait-job | receive-job
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
