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

$assemblyRoot = $null
$assemblyWithAllCommonPlatform = 'Assembly1AllCommonPlatforms'
$assemblyWithNonCommonPlatform = 'Assembly5WithUAP'
$assemblyWithNonCommonPlatformOnly = 'Assembly5WithMac'

$assemblyNamesAndVersions = @(
    @{Name=$assemblyWithAllCommonPlatform;Version='2.3.4';Platforms=@('net45', 'netcoreapp1.0', 'netstandard1.1', 'netstandard1.3')}
    @{Name='Assembly2Net45Only';Version='4.5.6';Platforms=@('net45')}
    @{Name='Assembly3NetCoreOnly';Version='7.8.9';Platforms=@('netcoreapp1.0')}
    @{Name='Assembly4NetStandard';Version='10.11.12';Platforms=@('netstandard1.1', 'netstandard1.3')}
    @{Name=$assemblyWithNonCommonPlatform;Version='13.14.15';Platforms=@('netcoreapp1.0', 'uap10.0')}
    @{Name=$assemblyWithNonCommonPlatformOnly;Version='15.16.17';Platforms=@('xamarinmac20')}
)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

. (join-path $here ../codeshare/assembly.ps1)
. (join-path $here $sut)

Describe "Assembly helper cmdlets" {
    BeforeAll {
        $assemblyRoot = psmd TestDrive:\Assemblies
        $assemblyDirectories = . {
            $assemblyNamesAndVersions | foreach {
                $AssemblyDirectory = $_.Name, $_.Version -join '.'
                @{Directory=(psmd -path $assemblyRoot -name $AssemblyDirectory);AssemblyName = $_.Name;Platforms=$_.Platforms}
            }
        }

        $allPlatforms = @(
            'net45',
            'netcoreapp1.0',
            'netstandard1.1',
            'netstandard1.3',
            'uap10.0',
            'xamarinios10',
            'xamarinmac20',
            'monoandroid81')

        $assemblyDirectories | foreach {
            $assemblyDirectory = $_
            $assemblyName = $assemblyDirectory.Directory.name
            $libParent = psmd -path $assemblyDirectory.Directory.FullName -name lib
            $allPlatforms | foreach {
                $assemblyParent = psmd -path $libParent.fullname -name $_
                $assemblyPath = join-path $assemblyParent.fullname $assemblyDirectory.AssemblyName
                if ( $assemblyDirectory.Platforms -contains $_ ) {
                    set-content "$assemblyPath.dll" -value $_
                }
            }
        }
    }

    Mock LoadAssembly {
        param($assemblyPath)
        if ( test-path $assemblyPath ) {
            [PSCustomObject]@{Location=$assemblyPath}
        } else {
            throw "Assembly '$assemblyPath' not found"
        }
    }

    Context "When running on any PowerShell edition" {
        BeforeAll {
            $assemblyData = $assemblyDirectories | where AssemblyName -eq $assemblyWithNonCommonPlatform
            $targetAssemblyDirPath = $assemblyData.Directory.fullname
            $targetAssemblyLibPath = join-path $targetAssemblyDirPath lib
            $newRefDirectory = psmd -path $targetAssemblyDirPath -name ref
            copy-item -r $targetAssemblyLibPath $newRefDirectory.fullname
        }

        It "Should throw an exception if more than one assembly matches for a given platform" {
            { Import-Assembly $assemblyData.AssemblyName $null $assemblyRoot -TargetFrameworkMoniker $assemblyData.Platforms[0] } | Should Throw "More than one"
        }

        It "Should preserve the case of a mixed case assembly path when it attempts to load an assembly" {
            $assemblyWithMixedCase = $assemblyDirectories | where AssemblyName -eq $assemblyWithAllCommonPlatform
            $assemblyWithVersion = $assemblyNamesAndVersions | where Name -eq $assemblyWithAllCommonPlatform
            $assemblyVersion = $assemblyWithVersion.Version
            $assemblyWithMixedCase.Directory.fullname.tolower() | Should Not BeExactly $assemblyWithMixedCase.Directory.fullname
            $assemblyWithMixedCase.AssemblyName.tolower() | Should Not BeExactly $assemblyWithMixedCase.AssemblyName
            $targetPlatform = $assemblyWithMixedCase.Platforms[0]

            $importedAssembly = Import-Assembly $assemblyWithMixedCase.AssemblyName $null $assemblyRoot -TargetFrameworkMoniker $targetPlatform
            $importedAssembly.Location | Should BeExactly "$assemblyRoot/$($assemblyWithMixedCase.AssemblyName).$($assemblyVersion)/lib/$targetPlatform/$assemblyWithAllCommonPlatform.dll".replace("`\", '/')
        }
    }

    Context "When running on PowerShell Desktop edition" {
        Mock IsDesktopEdition { $true }

        It "Should throw an exception if an attempt is made to load an assembly that does not exist " {
            { Import-Assembly idontexist $null $assemblyRoot } | Should Throw "Unable to find assembly"
        }

        It "Should throw an exception if an attempt is made to load a platform that does not exist" {
            $assemblyNamesAndVersions | foreach {
                { Import-Assembly $_.Name $null $assemblyRoot -TargetFrameworkMoniker notavalidplatform } | Should Throw "Unable to find assembly"
            }
        }

        It "Should throw an exception if an attempt is made to load a platform that does not support net45 or a common core platform" {
            { Import-Assembly $assemblyWithNonCommonPlatformOnly $null $assemblyRoot } | Should Throw "Unable to find assembly"
        }

        It "Should load assemblies that support 'net45' when no TargetFrameworkMoniker is specified" {
            $importedAssembly = $null
            $assemblyNamesAndVersions | foreach {
                if ( $_.Platforms -contains 'net45' ) {
                    $importedAssembly = Import-Assembly $_.Name $null $assemblyRoot
                    $importedAssembly.Location | Should BeExactly "$assemblyRoot/$($_.Name).$($_.Version)/lib/net45/$($_.Name).dll".replace("`\", '/')
                    $content = (get-content $importedAssembly.Location | out-string).trimend()
                    $content | Should Be 'net45'
                }
            }

            $importedAssembly | Should Not Be $null
        }

        It "Should attempt to load a netcoreapp1.0 assembly on desktop if the assembly supports netcoreapp1.0 if TargetFrameworkMoniker is set to netcoreapp1.0" {
            $importedAssembly = $null
            $assemblyNamesAndVersions | foreach {
                if ( $_.Platforms -contains 'netcoreapp1.0' ) {
                    $importedAssembly = Import-Assembly $_.Name $null $assemblyRoot -TargetFrameworkMoniker 'netcoreapp1.0'
                    $importedAssembly.Location | Should BeExactly "$assemblyRoot/$($_.Name).$($_.Version)/lib/netcoreapp1.0/$($_.Name).dll".replace("`\", '/')
                    $content = (get-content $importedAssembly.Location | out-string).trimend()
                    $content | Should Be 'netcoreapp1.0'
                }
            }

            $importedAssembly | Should Not Be $null
        }


        It "Should not load assemblies that do not support 'net45' when no TargetFrameworkMoniker is specified" {
            $importedAssembly = $null
            $assemblyNamesAndVersions | foreach {
                if ( $_.Platforms -notcontains 'net45' ) {
                    { $importedAssemblyResult = Import-Assembly $_.Name $null $assemblyRoot; set-variable -scope 1 importedAssembly -value $importedAssemblyResult } | Should Throw "Unable to find assembly"
                }
            }

            $importedAssembly | Should Be $null
        }
    }

    Context "When running on PowerShell Core edition" {
        Mock IsDesktopEdition { $false }

        It "Should throw an exception if an attempt is made to load an assembly that does not exist " {
            { Import-Assembly idontexist $null $assemblyRoot } | Should Throw "Unable to find assembly"
        }

        It "Should throw an exception if an attempt is made to load a platform that does not exist" {
            $assemblyNamesAndVersions | foreach {
                { Import-Assembly $_.Name $null $assemblyRoot -TargetFrameworkMoniker notavalidplatform } | Should Throw "Unable to find assembly"
            }
        }

        It "Should throw an exception if an attempt is made to load a platform that does not support net45 or a common core platform" {
            { Import-Assembly $assemblyWithNonCommonPlatformOnly $null $assemblyRoot } | Should Throw "Unable to find assembly"
        }

        function __GetCorePlatform($supportedPlatforms) {
            $platformPrecedence = @('netstandard1.3', 'netstandard1.1', 'netcoreapp1.0')

            $chosenPlatform = $null

            for ( $platformIndex = 0; $platformIndex -lt $platformPrecedence.length; $platformIndex++ ) {
                $currentPlatform = $platformPrecedence[$platformIndex]
                if ( $supportedPlatforms -contains $currentPlatform ) {
                    $chosenPlatform = $currentPlatform
                    break
                }
            }

            $chosenPlatform
        }

        It "Should not load assemblies that only support 'net45' when no TargetFrameworkMoniker is specified" {
            $importedAssembly = $null
            $assemblyNamesAndVersions | foreach {
                if ( $_.Platforms.length -eq 1 -and $_.Platforms[0] -eq 'net45' ) {
                    { $importedAssemblyResult = Import-Assembly $_.Name $null $assemblyRoot ;set-variable -scope 1 importedAssembly -value $importedAssemblyResult } | Should Throw "Unable to find assembly"
                }
            }

            $importedAssembly | Should Be $null
        }

        It "Should attempt to load a net45 assembly on core if the assembly supports net45 if TargetFrameworkMoniker is set to net45" {
            $importedAssembly = $null
            $assemblyNamesAndVersions | foreach {
                if ( $_.Platforms -contains 'net45' ) {
                    $importedAssembly = Import-Assembly $_.Name $null $assemblyRoot -TargetFrameworkMoniker net45
                    $importedAssembly.Location | Should BeExactly "$assemblyRoot/$($_.Name).$($_.Version)/lib/net45/$($_.Name).dll".replace("`\", '/')
                    $content = (get-content $importedAssembly.Location | out-string).trimend()
                    $content | Should Be 'net45'
                }
            }

            $importedAssembly | Should Not Be $null
        }

        It "Should load core assemblies of the correct platform according to precedence when a valid core assembly is available" {
            $importedAssembly = $null
            $assemblyNamesAndVersions | foreach {
                $corePlatform = __GetCorePlatform $_.Platforms
                if ( $corePlatform ) {
                    $importedAssembly = Import-Assembly $_.Name $null $assemblyRoot
                    $importedAssembly.Location | Should BeExactly "$assemblyRoot/$($_.Name).$($_.Version)/lib/$corePlatform/$($_.Name).dll".replace("`\", '/')
                    $content = (get-content $importedAssembly.Location | out-string).trimend()
                    $content | Should Be $corePlatform
                }
            }

            $importedAssembly | Should Not Be $null
        }
    }
}
