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
$includes = @{}
$included = @{}

function CallerScriptRoot {
    $callstack = get-pscallstack
    $caller = $null
    $thisScript = $callstack[0].scriptname
    for ($current = 1; $current -lt $callstack.length; $current++) {
        $currentScriptRoot = $callstack[$current].scriptname
        if ( $currentScriptRoot -ne $null -and $currentScriptRoot.length -gt 0 ) {
            if ( $currentScriptRoot -ne $thisScript ) {
                $caller = $currentScriptRoot
                break
            }
        }
    }

    if ( $caller -eq $null ) {
        throw "Unable to determine calling script's directory"
    }

    split-path $caller
}

function ValidateIncludePath($includePath) {
    if ( $includePath.StartsWith("/") -or $includePath.StartsWith("\") ) {
        throw "Path specified to include-source '$includePath' started with a path separator which is not allowed -- only relative paths may be specified"
    }
}

function Import-Script {
    [cmdletbinding()]
    param (
        [parameter(mandatory=$true)]
        $Path,
        $Parent = $null
    )
    $root = if ( $Parent -eq $null ) {
        CallerScriptRoot
    } else {
        $Parent
    }

    ValidateIncludePath($Path)
    $relativePath = "$($Path).ps1"
    $relativeNormal = $relativePath.ToLower()
    $fullPath = (join-path ($root) $relativePath | get-item).Fullname
    $canonical = $fullPath.ToLower()
    if ( $included[$canonical] -eq $null ) {
        $included[$canonical] = @($root, $relativeNormal)
        $includes[$canonical] = $false
        $fullPath
    } else {
        {}
    }
}



