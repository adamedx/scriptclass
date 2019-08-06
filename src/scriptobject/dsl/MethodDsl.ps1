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

# function =>
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
        $attemptObjectRestore = $false
        $currentObject = $_
        $result = try {
            $script = ($currentObject.psobject.methods | where name -eq $methodName).script
            $invoker = {param($block, $arguments) . $block @arguments}
            $thisvar = [PSVariable]::new('this', $currentObject)
            if ( $script.module ) {
                $script.module.newboundscriptblock($invoker).invokewithcontext(@{}, [PSVariable[]] $thisVar, @($script, $methodArgs))
            } else {
                withobject $currentObject $script @methodArgs
            }
        } catch {
            if ( ! [ClassManager]::Get().IsClassType($currentObject, $null) ) {
                throw
            }

            if ( ( $currentObject.psobject.methods | where name -eq 'InvokeMethod' ) ) {
                throw
            }
            $attemptObjectRestore = $true
        }

        if ( $attemptObjectRestore ) {
            $static = $false
            $classMember = $currentObject.$([ScriptClassSpecification]::Parameters.Schema.ClassMember.Name)
            $classInfo = if ( $classMember ) {
                Get-ScriptClass -detailed -object $currentObject
            } else {
                $static = $true
                Get-ScriptClass -detailed $classMember.([ScriptClassSpecification]::Parameters.Schema.ClassMember.Name).$([ScriptClassSpecification]::Parameters.Schema.ClassMember.Structure.ClassNameMemberName)
            }

            $methodInfo = $classInfo.classDefinition.GetMethod($methodName, $static)

            if ( $methodInfo ) {
                $builder = [NativeObjectBuilder]::new($null, $currentObject, [NativeObjectBuilderMode]::Modify)

                $methods = if ( $static ) {
                    $classInfo.classDefinition.GetStaticMethods()
                } else {
                    $classInfo.classDefinition.GetInstanceMethods()
                }

                $methods | foreach {
                    $builder.AddMethod($_.name, $_.block)
                }

                [ScriptClassBuilder]::commonMethods.GetEnumerator() | foreach {
                    $builder.AddMethod($_.name, $_.value)
                }
            } else {
                throw [System.Management.Automation.MethodInvocationException]::new("The method '$methodName' could not be found on the object")
            }

            $currentObject.InvokeMethod($methodName, $methodArgs)
        }

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
