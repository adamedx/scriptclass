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

set-strictmode -version 2

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "The include-source cmdlet" {
    $importCommand = "import-module -force " + (join-path $here "..\stdposh.psd1")
    $simpleClientScriptPath = "TestDrive:\simplesclientcript.ps1"
    $parameterizedClientScriptFile = "parameterizedclientscript.ps1"
    $parameterizedClientScriptPath = join-path "TestDrive:" $parameterizedClientScriptFile
    $simpleScriptFile = "simplescript.ps1"
    $simpleScriptPath = join-path TestDrive: $simpleScriptFile
    $errorscriptFile = "errorscript.ps1"
    $errorScriptPath = join-path TestDrive: $errorscriptfile
    $includeOnceFile = 'includeonce.ps1'
    $includeOncePath = join-path "TestDrive:" $includeoncefile
    $indirectFile = "indirect.ps1"
    $indirectPath = join-path TestDrive: $indirectFile
    $subdirfile = join-path (mkdir "TestDrive:\subdir").fullname subdirfile.ps1
    $subdirfile2 = join-path (mkdir -f "TestDrive:\subdir2\subdir2a").fullname subdirfile.ps1
    $appfile = "TestDrive:\appfile.ps1"
    $app2dir = mkdir "TestDrive:\appdir" | select -expandproperty fullname

    $moduledir = (mkdir "TestDrive:\moduledir").fullname
    $modulefile = 'modulefile.psm1'
    $modulePath = join-path $moduledir $modulefile
    $modulescriptdir1name = 'src/dir1'
    $modulescriptdir1path = (mkdir (join-path $moduledir src/dir1)).fullname
    $modulescriptfile1 = 'file1cmdlets.ps1'
    $modulescriptpath1 = join-path $modulescriptdir1path $modulescriptfile1
    $modulescriptdir2name = 'src/dir2'
    $modulescriptdirpath2 = (mkdir (join-path $moduledir src/dir2)).fullname
    $modulescriptfile2 = 'file2common.ps1'
    $modulescriptpath2 = join-path $modulescriptdirpath2 $modulescriptfile2
    $moduleclientdir = (mkdir "TestDrive:\moduleclientdir").fullname
    $moduleclientFile = 'moduleclientapp.ps1'
    $moduleclientPath = join-path $moduleclientdir $moduleclientfile
    $importmodulepathtestcommand = "import-module -force '$modulePath'"

    function remove-ext ([string] $path) {
        $ext = $path.substring($path.length - 4, 4)
        if ($ext -ne '.ps1') {
            throw "Invalid path specified to remove-ext -- missing '.ps1' extension in path '$path'"
        }

        $path.substring(0, $path.length - 4)
    }

    function run-command([string] $command) {
        powershell -noprofile -command "`$erroractionpreference = 'stop'; exit (iex '$command')" | out-null
        $lastexitcode
    }

    set-content $errorScriptPath -value @"
function incomplete {
 echo hi
"@

    set-content $simpleclientscriptpath -value @"
$importCommand
. `$include $(remove-ext $simplescriptfile)
"@

    set-content $parameterizedClientScriptPath -value @"
param([string] `$fileToInclude, [string] `$exprtoeval = '0')
$importCommand
. `$include `$(remove-ext `$fileToInclude)
iex `$exprtoeval
"@
    set-content $simpleScriptPath -value @"
`$simplescriptvar = 2371
function simplescriptfunc { `$simplescriptvar }
set-alias set-aliassimple simplescriptfunc
"@

    set-content $includeOncePath -value @"
`$alreadyDefined = try {
    get-variable includeonce >* out-null
    `$true
} catch {
    `$false
}
if (`$alreadyDefined) {
   throw `"Already defined!`"
}
"@

    set-content $indirectPath -value @"
$importCommand
. `$include `$(remove-ext `$includeonceFile)
. '$parameterizedClientScriptPath' '$includeOnceFile'
"@

    set-content $modulePath -value @"
$importCommand
`$modfile = (join-path '$modulescriptdir1name' '$(remove-ext $modulescriptfile1)')
. (join-path `$psscriptroot `$modfile)
"@

    set-content $modulescriptpath1 -value @"
. `$include (join-path '../dir2' $(remove-ext $modulescriptfile2))
function testvalue(`$arg1, `$arg2) {
    (constantval) + `$arg1 * `$arg2
}
"@

    set-content $modulescriptpath2 -value @"
function constantval { 37 }
"@

    set-content $moduleclientpath -value @"
param(`$arg1, `$arg2)
$importmodulepathtestcommand
testvalue `$arg1 `$arg2
"@

    Context 'When loading source into a script' {
        It 'should load the valid script file without throwing an exception' {
            { iex $simpleclientscriptpath | out-null } | Should Not Throw
            run-command ("& " + (gi $simpleclientscriptpath).fullname) | Should BeExactly 0
        }

        It 'should throw an exception when loading a script file with an error' {
            { run-command ". `$include $(remove-ext $errorscriptfile)" } | Should Not Throw
            run-command ". `$include $(remove-ext $errorscriptfile)" | Should Not Be 0
        }

        It 'should process the file only once even if it is included in a script more than once' {
            { iex "& '$parameterizedClientScriptPath' '$includeOnceFile'" } | Should Not Throw
        }

        It 'should process the file only once even if it is included in a script more than once through an indirect inclusion' {
            { iex "& '$parameterizedClientScriptPath' '$indirectFile'" } | Should Not Throw
        }

        It 'should treat include paths as relative to the calling module' {
            run-command "& $moduleClientPath 5 3 " | Should Be (5 * 3 + 37)
        }

        It 'should throw an exception if the include path starts with a pathsep' {
            { iex "& '$parameterizedClientScriptPath' '/$includeOnceFile'" } | Should Throw "Path specified to include-source '/$(remove-ext $includeOnceFile)' started with a path separator which is not allowed -- only relative paths may be specified"
            { iex "& '$parameterizedClientScriptPath' '\$includeOnceFile'" } | Should Throw "Path specified to include-source '\$(remove-ext $includeOnceFile)' started with a path separator which is not allowed -- only relative paths may be specified"
        }
    }
}
