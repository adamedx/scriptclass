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

function Invoke-Method {
    [cmdletbinding()]
    param(
        [Parameter(mandatory=$true)]
        $Context,
        [Parameter(mandatory=$true)]
        $Action,
        [Parameter(valuefromremainingarguments=$true)]
        [object[]] $Arguments
    )
    if ( $Context -eq $null ) {
        throw "Invalid Context -- Context may not be `$null"
    }

    if ( $Action -eq $null ) {
        throw "Invalid Action argument -- Action may not be `$null"
    }

    if ( $Action -isnot [string] -and $Action -isnot [ScriptBlock] ) {
        throw [ArgumentException]::new("The specified Action argument of type '$($Action.GetType())' must be of type [String] or type [ScriptBlock]")
    }

    $isExtendedClass = Test-ScriptObject $Context

    if ( $isExtendedClass ) {
        $invocationMethods = [ScriptClassSpecification]::Parameters.Schema
        if ( $Action -is [string] ) {
            $Context.$($invocationMethods.InvokeMethodMethodName)($Action, $arguments)
        } else {
            # TODO: Should this rebinding be an optional capability for InvokeScriptMethod?
            $boundScript = ($Context.psobject.methods | where name -eq $invocationMethods.InvokeScriptMethodName).script.module.newboundscriptblock($Action)

            $Context.$($invocationMethods.InvokeScriptMethodName)($boundScript, $arguments)
        }
    } else {
        if ( $Action -is [string] ) {
            throw [ArgumentException]::new("Object is not a '$([ScriptClassSpecification]::Parameters.TypeSystemName)' extended type system object")
        }

        $objectMethodsAsfunctions = @{}
        $Context.psobject.members | foreach {
            if ( $_.membertype -eq 'ScriptMethod' ) {
                $objectMethodsAsfunctions[$_.name] = $_.value.script
            }
        }

        $thisVariable = [PSVariable]::new('this', $Context)
        $Action.InvokeWithContext($objectMethodsAsFunctions, $thisVariable, $arguments)
    }
}
