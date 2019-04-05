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

function __IsDesktopEdition {
    $PSVersionTable.PSEdition -eq 'Desktop'
}

function FindAssembly($assemblyRoot, $assemblyName, $platformSpec) {
    write-verbose "Looking for matching assembly for '$assemblyName' under path '$assemblyRoot' with platform '$platformSpec'"
    # For OS compatibility, canonicalize path separators below by replacing '\' with '/'
    $matchingAssemblyPaths = get-childitem -r $assemblyRoot -Filter "$assemblyName.dll" | where {
        $assemblyDirectory = $_.fullname
        $components = $assemblyDirectory.replace("`\", "/") -split "/"

        if ( $components.length -ge 3 ) {
            ($components[$components.length - 2] -eq $platformSpec) -and ($components[$components.length - 3] -eq 'lib')
        }
    }

    if ( $matchingAssemblyPaths -and $matchingAssemblyPaths -is [object[]] -and $matchingAssemblyPaths.length -gt 1 ) {
        throw ("More than one assembly was found to match assembly '$assemblyName' -- update assembly directory to have only one of the following assemblies: {0}" -f (($matchingAssemblyPaths | foreach { "'$($_.fullname)'" }) -join ', '))
    }

    if ($matchingAssemblyPaths) {
        write-verbose "Found possible assembly match for '$assemblyName' in '$($matchingAssemblyPaths[0])'"
        $matchingAssemblyPaths[0].fullname.replace("`\", "/")
    }
}

function LoadAssemblyFromRoot($assemblyRoot, $assemblyName, $platformSpec) {
    $specs = if ( $platformSpec ) {
        , @($platformSpec)
    } elseif ( __IsDesktopEdition ) {
        , @('net45')
    } else {
        @('netstandard1.3', 'netstandard1.1', 'netcoreapp1.0')
    }

    $assemblyPath = $null

    write-verbose ("Looking for assemblies with candidate platforms {0}" -f ( $specs -join ',' ) )

    for ( $specIndex = 0; $specIndex -lt $specs.length; $specIndex++ ) {
        $spec = $specs[$specIndex]
        $assemblyPath = FindAssembly $assemblyRoot $assemblyName $spec
        if ( $assemblyPath ) {
            break
        }

        write-verbose "Assembly '$assemblyName' not found"
    }

    if ( ! $assemblyPath ) {
        throw "Unable to find assembly '$assemblyName' under root directory '$assemblyRoot'. Please re-run the installation command for this application and retry."
    }

    write-verbose "Requested assembly '$assemblyName', loading assembly '$assemblyPath'"
    __LoadAssembly $assemblyPath
}

function __LoadAssembly($assemblyPath) {
    [System.Reflection.Assembly]::LoadFrom($assemblyPath)
}

function Import-Assembly {
    [cmdletbinding()]
    param(
        [parameter(mandatory=$true)]
        [string] $AssemblyName,
        [string] $AssemblyRelativePath = $null,
        [string] $AssemblyRoot = $null,
        [string] $TargetFrameworkMoniker = $null
    )
    $searchRoot = if ( $assemblyRoot ) {
        $assemblyRoot
    } else {
        $callerScriptFile = (get-pscallstack)[1].scriptname
        if ( ! $callerScriptFile ) {
            throw [ArgumentException]::new("Cannot load assembly '$AssemblyName' using the specified relative path '$AssemblyRelativePath' because the script file path of the caller cannot be determined; it may be a dynamic script block. Use the AssemblyRoot parameter to specify an absolute search path instead")
        }
        split-path -parent (get-pscallstack)[1].scriptname
    }
    write-verbose "Using assembly root '$searchRoot'..."

    $assemblyFile = split-path -leaf $assemblyName

    if ( $assemblyFile -ne $assemblyName ) {
        throw "Parameter 'AssemblyName' must be a single name -- the specified value '$AssemblyName' contains path separators and is not valid."
    }

    $searchRootDirectory = if ( $AssemblyRelativePath ) {
        join-path $searchRoot $AssemblyRelativePath
    } else {
        $searchRoot
    }

    $searchRootItem = get-item $searchRootDirectory -erroraction ignore

    if ( $searchRootItem -eq $null ) {
        throw "Unable to find assembly '$assemblyName' because given search directory '$searchRootDirectory' was not accessible"
    }

    $searchRootFullyQualified = $searchRootItem.fullname

    write-verbose "Using fully qualified assembly root '$searchRootFullyQualified' to find assembly '$assemblyFile'..."

    LoadAssemblyFromRoot $searchRootFullyQualified  $assemblyFile $TargetFrameworkMoniker
}


