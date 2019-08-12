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

$here = $psscriptroot
$thismodule = join-path $here ../../ScriptClass.psd1
$thisshell = if ( $PSEdition -eq 'Desktop' ) {
    'powershell'
} else {
    'pwsh'
}

function new-directory {
    param(
        [Parameter(mandatory=$true)]
        $Name,
        $Path)
    $fullPath = if ( $Path ) {
        join-path $Path $Name
    } else {
        $Name
    }

    new-item -ItemType Directory $fullPath
}

set-alias psmd new-directory -erroraction ignore

Describe "The import-script cmdlet" {
    remove-module $thismodule -force -erroraction ignore
    import-module $thismodule -force

    BeforeAll {
        remove-module $thismodule -force -erroraction ignore
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction ignore
    }

    $importCommand = "import-module -force '" + $thismodule + "'"
    $simpleClientScriptPath = "TestDrive:\simplesclientcript.ps1"
    $simpleClientScriptNonPs1File = "simplesclientcriptNonStandardExtension.txt"
    $simpleClientScriptNonPs1Path = join-path (get-item "TestDrive:").fullname $simpleClientScriptNonPs1File
    $parameterizedClientScriptFile = "parameterizedclientscript.ps1"
    $parameterizedClientScriptPath = join-path "TestDrive:" $parameterizedClientScriptFile
    $simpleScriptFile = "simplescript.ps1"
    $simpleScriptPath = join-path (get-item TestDrive:).fullname $simpleScriptFile
    $errorscriptFile = "errorscript.ps1"
    $errorScriptPath = join-path (get-item TestDrive:).fullname  $errorscriptfile
    $errorScriptLoadFile = 'errorscriptLoadfile.ps1'
    $errorScriptLoadPath = join-path (split-path -parent $errorScriptPath) $errorScriptLoadFile

    $includeOnceFile = 'includeonce.ps1'
    $includeOncePath = join-path "TestDrive:" $includeoncefile
    $includeUsingNonPs1File = "includeNonPs1.ps1"
    $includeUsingNonPs1Path = join-path (get-item "TestDrive:").fullname $includeUsingNonPs1File
    $includeUsingNonPs1AnyExtensionFile = "includeNonPs1AnyExtension.ps1"
    $includeUsingNonPs1AnyExtensionPath = join-path (get-item "TestDrive:").fullname $includeUsingNonPs1AnyExtensionFile
    $indirectFile = "indirect.ps1"
    $indirectPath = join-path TestDrive: $indirectFile
    $subdirfile = join-path (new-item -Type Directory "TestDrive:\subdir").fullname subdirfile.ps1
    $subdirfile2 = join-path (new-item -Type Directory -f "TestDrive:\subdir2\subdir2a").fullname subdirfile.ps1
    $appfile = "TestDrive:\appfile.ps1"
    $app2dir = new-item -Type Directory "TestDrive:\appdir" | select -expandproperty fullname

    $moduledir = (new-item -Type Directory "TestDrive:\moduledir").fullname
    $modulefile = 'modulefile.psm1'
    $modulefileinclude = 'moduleincludefile.psm1'
    $modulePath = join-path $moduledir $modulefile
    $modulePathinclude = join-path $moduledir $modulefileinclude
    $modulescriptdir1name = 'src/dir1'
    $modulescriptdir1path = (new-item -Type Directory (join-path $moduledir src/dir1)).fullname
    $modulescriptfile1 = 'file1cmdlets.ps1'
    $modulescriptfile1include = 'file1cmdletsincludevar.ps1'
    $modulescriptpath1 = join-path $modulescriptdir1path $modulescriptfile1
    $modulescriptpath1include = join-path $modulescriptdir1path $modulescriptfile1include
    $modulescriptdir2name = 'src/dir2'
    $modulescriptdirpath2 = (new-item -Type Directory (join-path $moduledir src/dir2)).fullname
    $modulescriptfile2 = 'file2common.ps1'
    $modulescriptfile2include = 'file2commoninclude.ps1'
    $modulescriptpath2 = join-path $modulescriptdirpath2 $modulescriptfile2
    $modulescriptpath2include = join-path $modulescriptdirpath2 $modulescriptfile2include
    $moduleclientdir = (new-item -Type Directory "TestDrive:\moduleclientdir").fullname
    $moduleclientFile = 'moduleclientapp.ps1'
    $moduleclientFileinclude = 'moduleclientincludeapp.ps1'
    $moduleclientPath = join-path $moduleclientdir $moduleclientfile
    $moduleclientPathinclude = join-path $moduleclientdir $moduleclientfileinclude
    $importmodulepathtestcommand = "import-module -force '$modulePath'"
    $importmodulepathincludetestcommand = "import-module -force '$modulePathinclude'"

    function remove-ext ([string] $path) {
        $ext = $path.substring($path.length - 4, 4)
        if ($ext -ne '.ps1') {
            throw "Invalid path specified to remove-ext -- missing '.ps1' extension in path '$path'"
        }

        $path.substring(0, $path.length - 4)
    }

    function run-command([string] $command) {
        $result = (& $thisshell -noprofile -command "`$erroractionpreference = 'stop'; exit (iex '$command' 2>&1)")
        if ( ! $? ) {
            write-host '*****************CAUGHT--------'
            $global:lastCommandExceptionOutput = ($result | out-string)
            if ( $result -eq $null ) {
                write-host '----------null'
            } else {
                write-host '----type:', $result.gettype()
            }
            write-host '****' $global:lastCommandExceptionOutput
            write-host '+++++'
            $result | out-host
            throw "Command failed: " + $result
        } else {
            0
        }
    }
    set-content $errorScriptPath -value @"
function incomplete {
 echo hi
"@

    set-content $errorScriptLoadPath -value @"
$importCommand
. (import-script $($errorScriptFile.split('.')[0]))
"@

    set-content $simpleclientscriptpath -value @"
$importCommand
`$scriptname = '$simplescriptfile'.split('.')[0]
. (import-script `$scriptname)
"@

    set-content $includeUsingNonPs1Path -value @"
    $importCommand
    . (import-script $($simpleclientscriptnonPs1File.split('.')[0]))
"@

    set-content $includeUsingNonPs1AnyExtensionPath -value @"
    $importCommand
    # Don't dot source this -- because it's not a ps1,
    # the file is actually executed -- maybe this feature
    # is not so useful...
    import-script -AnyExtension $simpleclientscriptnonPs1File | out-null
"@

    get-content $simpleclientscriptpath |
      set-content $simpleClientScriptNonPs1Path

    set-content $parameterizedClientScriptPath -value @"
param([string] `$fileToInclude, [string] `$exprtoeval = '0')
$importCommand
`$filename = `$filetoinclude.split('.')[0]
. (import-script `$filename)
iex `$exprtoeval
"@
    set-content $simpleScriptPath -value @"
$importCommand
`$simplescriptvar = 2371
function simplescriptfunc { `$simplescriptvar }
set-alias set-aliassimple simplescriptfunc
"@

    set-content $includeOncePath -value @"
$importCommand
`$alreadyDefined = try {
    get-variable includeonce >* $null
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
. (import-script $(remove-ext $includeonceFile))
. '$parameterizedClientScriptPath' '$includeOnceFile'
"@

    set-content $modulePath -value @"
$importCommand
`$modfile = (join-path '$modulescriptdir1name' '$(remove-ext $modulescriptfile1)')
. (join-path `$psscriptroot `$modfile)
"@

    set-content $modulePathinclude -value @"
$importCommand
`$modfile = (join-path '$modulescriptdir1name' '$(remove-ext $modulescriptfile1include)')
. (join-path `$psscriptroot `$modfile)
"@


    set-content $modulescriptpath1 -value @"
$importCommand
. (import-script (join-path '../dir2' $(remove-ext $modulescriptfile2)))
function testvalue(`$arg1, `$arg2) {
    (constantval) + `$arg1 * `$arg2
}
"@

set-content $modulescriptpath1include -value @"
$importCommand
`$scriptval = 'hi2'
`$scriptval = '$(join-path ../dir2 (remove-ext $modulescriptfile2include))'

# The use of `$include fails for unknown reasons in the context of this
# test, possibly due to scope issues in the way the script block is
# invoked. A workaround is to use import-script, which is validated
# in a separate test. Any tests using this capability must be marked
# pending until the issue is investigated and fixed.

# . `$include `$scriptval
# The equivalent workaround below works just fine in place of the above line
. (import-script `$scriptval)
function testvalue(`$arg1, `$arg2) {
    (constantval) + `$arg1 * `$arg2
}
"@

    set-content $modulescriptpath2 -value @"
$importCommand
function constantval {37 }
"@

    set-content $modulescriptpath2include -value @"
$importCommand
function constantval {37 }
"@

    set-content $moduleclientpath -value @"
param(`$arg1, `$arg2)
$importCommand
$importmodulepathtestcommand
testvalue `$arg1 `$arg2
"@

    set-content $moduleclientpathinclude -value @"
param(`$arg1, `$arg2)
$importCommand
$importmodulepathincludetestcommand
testvalue `$arg1 `$arg2
"@


    Context 'When loading source into a script' {
        BeforeEach {
            $global:lastCommandExceptionOutput = $null
        }
        It 'should load the valid script file without throwing an exception' {
            { iex $simpleclientscriptpath | out-null } | Should Not Throw
            run-command ("& " + (gi $simpleclientscriptpath).fullname) | Should BeExactly 0
        }

        It 'should throw an exception if the include path does not exist' {
            { import-script 'thisdoesnotexist.io' 2>&1 | out-null } | Should Throw
        }

        It 'should throw an exception if the AnyExtension parameter is omitted when trying to load a file that does not end in ps1' {
            { run-command "& $includeUsingNonPs1Path" } | Should Throw
            $global:lastCommandExceptionOutput | should BeLike "*$($simpleClientScriptNonPs1Path.split('.')[0])*"
        }

        It 'should not throw an exception if the AnyExtension parameter is used to load a file that does not end in ps1' {
            { run-command "& $includeUsingNonPs1AnyExtensionPath | out-null" } | Should Not Throw
        }

        It 'should throw an exception when loading a script file with an error' {
            { run-command "& $errorScriptLoadPath" } | Should Throw
            $global:lastCommandExceptionOutput | should BeLike '*function incomplete*'
        }

        It 'should process the file only once even if it is included in a script more than once' {
            { iex "& '$parameterizedClientScriptPath' '$includeOnceFile'" } | Should Not Throw
        }

        It 'should process the file only once even if it is included in a script more than once through an indirect inclusion' {
            { iex "& '$parameterizedClientScriptPath' '$indirectFile'" } | Should Not Throw
        }

        It 'should throw an exception if the include path starts with a pathsep' {
            { iex "& '$parameterizedClientScriptPath' '/$includeOnceFile'" } | Should Throw "Path specified to include-source '/$(remove-ext $includeOnceFile)' started with a path separator which is not allowed -- only relative paths may be specified"
            { iex "& '$parameterizedClientScriptPath' '\$includeOnceFile'" } | Should Throw "Path specified to include-source '\$(remove-ext $includeOnceFile)' started with a path separator which is not allowed -- only relative paths may be specified"
        }
    }

    Context "When finding scripts in the file system" {
        BeforeAll {
            $scriptDir = psmd -path TestDrive:\ -name 'ScriptParent'
            $scriptNextDir = psmd -path $scriptDir.fullname -name 'ThisDirHasMixedCase'
            $scriptFileBaseName = 'tHisScriptFileHasMixedCase'
            $scriptFileContainingFile = join-path $scriptNextDir.fullname "Containing.ps1"
            $scriptFilePath = join-path $scriptNextDir.fullname "$scriptFileBaseName.ps1"
            set-content -path $scriptFilePath -value 'echo hello'
            set-content -path $scriptFileContainingFile -value 'import-script $scriptFileBaseName'
        }

        It "Should preserve the case of all characters in the script file path" {
            $scriptFilePath.tolower() | Should Not BeExactly $scriptFilePath
            $scriptPathToLoad = iex "& '$scriptFileContainingFile'"
            $scriptPathToLoad.tolower() | Should Not BeExactly $scriptPathToLoad
            $scriptPathToLoad | Should BeExactly $scriptFilePath
        }
    }
}

