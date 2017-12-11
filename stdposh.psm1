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

$script:__LibraryBase = $psscriptroot

$moduleFile = $myinvocation.mycommand.name
$moduleName = if ($moduleFile.tolower().endswith('.psm1')) {
    $moduleFile.substring(0, $moduleFile.length - 5)
} else {
    $moduleFile
}

$modulePathComponents = $psscriptroot.replace('/', '\') -split "\\"
$componentIndex = $modulePathComponents.length

while (--$componentIndex -ge 1) {
    if ( $moduleName -eq $modulePathComponents[$componentIndex] ) {
        $foundComponents = @()
        $foundIndex = 0
        while ( $foundIndex -lt $componentIndex ) {
            $foundComponents += $modulePathComponents[$foundIndex++]
        }
        $script:__LibraryBase = if ($foundIndex -ge 1 ) {
            ($foundComponents -join '\')
        } else {
            '\'
        }
        break
    }
}

function get-librarybase {
    $script:__LibraryBase
}

$variables = @('::', 'include')

$functions = @('=>', '::>', 'add-scriptclass',
               'invoke-method', 'test-scriptobject',
               'new-scriptobject', 'import-assembly',
               'import-source', 'get-librarybase')

$aliases = @('new-so', 'ScriptClass', 'with', 'load-assembly', 'const' )

export-modulemember -variable $variables -function $functions # -alias $aliases




