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

[cmdletbinding()]
param([switch] $Force)

. "$psscriptroot/common-build-functions.ps1"

$destinationPath = join-path (split-path -parent $psscriptroot) bin

if ( ! ( test-path $destinationPath ) ) {
    write-verbose "Destination directory '$destinationPath' does not exist, creating it..."
    new-directory -name $destinationPath | out-null
}

if ( $PSVersionTable.PSEdition -eq 'Desktop' ) {
    $actionRequired = $true
    if ( $Force.IsPresent ) {
        write-verbose "Force specified, removing existing bin directory..."
        Clean-Tools
    }

    $nugetPath = join-path $destinationPath nuget.exe

    $nugetPresent = try {
        Validate-NugetPresent
        $hasCorrectNuget = (get-command nuget).source -eq $nugetPath
        write-verbose ("Nuget is present at '$nugetPath' -- IsNugetLocationValid = {0}" -f $hasCorrectNuget)
        if ( ! $hasCorrectNuget ) {
            write-verbose "The detected nuget is invalid, will update configuration to fix."
        }
        $hasCorrectNuget
    } catch {
        $false
    }

    if ( ! $nugetPresent -or $Force.IsPresent ) {
        write-verbose "Tool configuration update required or Force was specified, updating tools..."

        if ( ! ( test-path $nugetPath ) ) {
            write-verbose "Downloading nuget executable to '$nugetPath'..."
            Invoke-WebRequest -usebasicparsing https://dist.nuget.org/win-x86-commandline/latest/nuget.exe -outfile $nugetPath
        }

        if ( ! ($env:path).tolower().startswith($destinationPath.tolower()) ) {
            write-verbose 'Environment is missing local bin directory -- updating PATH environment variable...'
            si env:PATH "$destinationPath;$($env:path)"
        } else {
            write-verbose 'Environment already contains local bin directory, skipping PATH environment variable update'
        }

        Validate-NugetPresent
        $detectedNuget = (get-command nuget).source
        $hasCorrectNuget = $detectedNuget -eq $nugetPath

        if ( ! $hasCorrectNuget ) {
            throw "Installed nuget to '$nugetPath', but environment is using a different nuget at path '$detectedNuget'"
        }
    } else {
        $actionRequired = $false
        write-verbose "Tool configuration validated successfully, no action necessary."
    }

    $changeDisplay = if ( $actionRequired ) {
        'Changes'
    } else {
        'No changes'
    }

    write-host -fore green ("Tools successfully configured in directory '$destinationPath'. {0} were required." -f $changeDisplay)
} elseif ( $PSVersionTable.Platform -ne 'Win32NT' ) {
    write-verbose "Not running on Windows, explicitly checking for required 'dotnet' tool for .net runtime..."

    $dotNetToolPath = & which dotnet

    # TODO: distinguish between dotnet sdk vs runtime only -- we need dotnet sdk.
    # We assume if dotnet is present it is the SDK, but it could just be the runtime.
    # An additional check for successful execution of 'dotnet cli' is one way to
    # determine this, but it's not clear how to remediate if dotnet runtime is installed
    # and SDK isn't. Failing on detection of that case may be the most deterministic option.
    if ( ! $dotNetToolPath ) {
        write-verbose "Required 'dotnet' tool not detected, updating PATH to look under home directory and retrying..."
        set-item env:PATH ($env:PATH + ":" + ("/home/$($env:USER)/.dotnet"))
    }

    $dotNetToolPathUpdated = & which dotnet

    if ( ! $dotNetToolPathUpdated ) {
        write-verbose "Executable 'dotnet' not found after PATH update, will install .net runtime in default location..."
        $dotNetInstallerFile = 'dotnet-install.sh'
        $dotNetInstallerPath = join-path $destinationPath $dotNetInstallerFile

        if ( ! ( test-path $dotNetInstallerPath ) ) {
            write-verbose "Downloading .net installer script to '$dotNetInstallerPath'..."
            Invoke-WebRequest -usebasicparsing 'https://dot.net/v1/dotnet-install.sh' -OutFile $dotNetInstallerPath
            & chmod +x $dotNetInstallerPath
        }

        # Installs runtime and SDK
        & $dotNetInstallerPath

        $dotNetToolFinalVerification = & which dotnet

        if ( ! $dotNetToolFinalVerification ) {
            throw "Unable to install or detect required .net runtime tool 'dotnet'"
        }
    }

    if ( ! ( get-command invoke-pester -erroraction ignore ) ) {
        write-verbose "Test tool 'pester' not found, installing the Pester Module..."
        install-module -scope currentuser Pester -verbose
    }
}
