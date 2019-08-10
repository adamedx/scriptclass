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

# function => {
new-item -path "function:/$([ScriptClassSpecification]::Parameters.Language.MethodCallOperator)" -value {
    param ($methodName)
    if ($methodName -eq $null) {
        throw "A method must be specified"
    }

    $objects = @()

    $input | foreach {
        $objects += $_
    }

    if ( $objects.length -lt 1) {
        throw "Pipeline must have at least 1 object for $($myinvocation.mycommand.name)"
    }

    $methodargs = $args
    $results = @()
    $objects | foreach {
        if ( $_ -eq $null ) {
            throw [ArgumentException]::new("A `$null value was specified as the target for operator '$([ScriptClassSpecification]::Parameters.Language.MethodCallOperator)' for method '$methodName'")
        }
        $result = InvokeMethodOnTarget $_ $methodName $methodArgs
        $results += $result
    }

    if ( $results.length -eq 1) {
        $results[0]
    } else {
        $results
    }
} | out-null

new-item -path "function:/$([ScriptClassSpecification]::Parameters.Language.StaticMethodCallOperator)" -value {
    [cmdletbinding(positionalbinding=$false)]
    param(
        [parameter(valuefrompipeline=$true)] $target,
        [parameter(position=0)] $method,
        [parameter(valuefromremainingarguments=$true)] $arguments
    )

    if ( ! $target ) {
        throw [ArgumentException]::new("The target of the '$([ScriptClassSpecification]::Parameters.Language.StaticMethodCallOperator)' operator for method '$method' was `$null or not specified")
    }

    $classMember = [ScriptClassSpecification]::Parameters.Schema.ClassMember.Name

    $classObject = if ( $target -is [string] ) {
        [ClassManager]::Get().GetClassInfo($target).prototype.$classMember
    } elseif ( $target | gm $classMember -erroraction ignore ) {
        $target.$classMember
    } else {
        throw [ArgumentException]::new("The specified object is not a valid ScriptClass object")
    }

    if ( ! $classObject ) {
        throw [ArgumentException]::new("The specified object does not support ScriptClass static methods")
    }

    $classObject |=> $method @arguments
} | out-null

function InvokeMethodOnTarget($target, [string] $methodName, $methodArgs) {
    $methodInfo = ($target.psobject.methods | where name -eq $methodName)
    $useScriptInvocation = $true
    $script = if ( $methodInfo | gm script -erroraction ignore ) {
        $useScriptInvocation = $false
        $methodInfo.script
    } else {
        if ( ! [ClassManager]::Get().IsClassType($target, $null) ) {
            throw
        }

        if ( ( $target.psobject.methods | where name -eq 'InvokeMethod' ) ) {
            throw
        }

        $static = $false
        $classMember = $target.$([ScriptClassSpecification]::Parameters.Schema.ClassMember.Name)
        $classInfo = if ( ! $classMember ) {
            $static = $true
            Get-ScriptClass -detailed $classMember.([ScriptClassSpecification]::Parameters.Schema.ClassMember.Name).$([ScriptClassSpecification]::Parameters.Schema.ClassMember.Structure.ClassNameMemberName)
        } else {
            Get-ScriptClass -detailed -object $target
        }

        if ( $classInfo.classDefinition.GetMethod($methodName, $static) ) {
            [ClassManager]::RestoreMissingObjectMethods($classInfo, $target, $static)
        } else {
            throw [System.Management.Automation.MethodInvocationException]::new("The method '$methodName' could not be found on the object")
        }

        ($target.psobject.methods | where name -eq $methodname).script
    }

    if ( ! $useScriptInvocation -and $script.module ) {
        $target.InvokeMethod($methodName, $methodArgs)
    } else {
        withobject $target $script @methodArgs
    }
}
