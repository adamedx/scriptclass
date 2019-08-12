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

. (join-path $psscriptroot src/scriptclass.ps1)

$functionsToAliases = @{
    'Get-ScriptClass' = $null
    'Invoke-Method' = 'withobject'
    'New-ScriptClass' = 'scriptclass'
    'New-ScriptObject' = 'new-so'
    'Test-ScriptObject' = $null
    [ScriptClassSpecification]::Parameters.Language.MethodCallOperator = $null
    [ScriptClassSpecification]::Parameters.Language.StaticMethodCallOperator = $null
}

$functions = @()

$aliases = foreach ( $functionName in $functionsToAliases.keys ) {
    $functions += $functionName
    $alias = $functionsToAliases[$functionName]
    if ( $alias ) {
        set-alias $alias $functionName
        $alias
    }
}

$variables = @([ScriptClassSpecification]::Parameters.Language.ClassCollectionName)

$functions += @(
    'Add-MockInScriptClassScope'
    'Add-ScriptClassMock'
    'Import-Assembly'
    'Import-Script'
    'Initialize-ScriptClassTest'
    'New-ScriptObjectMock'
    'Remove-ScriptClassMock')

$aliases += @('Mock-ScriptClassMethod', 'Unmock-ScriptClassMethod' )

export-modulemember -variable $variables -function $functions -alias $aliases

