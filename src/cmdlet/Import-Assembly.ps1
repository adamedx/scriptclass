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
