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

function __invoke-methodwithcontext($object, $method) {
    $methodNotFoundException = $null
    $methodScript = try {
        $object.psobject.members[$method].script
    } catch {
        $methodNotFoundException = $_.exception
    }

    try {
        # The missing method may be due to a caller specifying the wrong method, but
        # if the object was deserialized, deserialization may have stripped off
        # the ScriptMethod property altogether. We check for a suggestive evidence
        # of that here, and if so, we invoke a just-in-time fixup and retry.
        if (! $methodScript -and ( $object | gm scriptclass)) {
            $existingClass = __ScriptClass__GetClass $object.scriptclass.classname
            write-verbose "Missing method '$method' on class $($existingClass.prototype.pstypename)"
            if ($existingClass.instancemethods[$method]) {
                __restore-deserializedobjectmethods $existingClass $object
                # Now retry the call -- if the method was restored, this will succeed.
                $methodScript = $object.psobject.members[$method].script
            } else {
                write-verbose "Method '$method' not found"
            }
        }
    } catch {
    }

    if ( ! $methodScript ) {
        throw [Exception]::new("Failed to invoke method '$method' on object of type $($object.gettype()) -- the method was not found", $methodNotFoundException)
    }
    __invoke-scriptwithcontext $object $methodScript @args
}

function __invoke-scriptwithcontext($objectContext, $script) {
    $variables = [PSVariable[]]@()
    $thisVariable = [PSVariable]::new('this', $objectContext)

    $variables += $thisVariable

    $pscmdletVariable = get-variable pscmdlet -erroraction ignore

    if ( $pscmdletVariable ) {
        $variables += $pscmdletVariable
    }

    $functions = @{}
    $objectContext.psobject.members | foreach {
        if ( $_.membertype -eq 'ScriptMethod' ) {
#            write-host -fore magenta $_.value.name, $_.value.script.module
            $functions[$_.name] = $_.value.script
        }
    }
    $result = try {
        # Very strange -- an array of cardinality 1 generates an error when used in the method call to InvokeWithContext, so if there's only one element, convert it back to that one element
        if ($variables.length -eq 1 ) {
            $variables = $variables[0]
        }
        $invokeWrapperSimple = {
            param($myscript, $myargs, $instance)
            try {
                $__results = if ( ! $instance ) {
                     . $myscript @myargs
                } else {
                    $instance.InvokeScript($myscript, $myargs)
                }
                @{
                    result = $__results
                    succeeded = $true
                }
            } catch {
                @{
                    result = $_
                    succeeded = $false
                }
            }
        }

        if ( $objectContext | gm ScriptClass -erroraction ignore ) {
            $targetModule = $script.Module
            $instance = if ( $objectContext.ScriptClass ) {
                $objectContext
            } else {
                $objectContext
            }
            $invokeWrapper =  if ($targetModule) {
                $script.module.newboundScriptBlock($invokeWrapperSimple)
            } else {
                $invokeWrapperSimple
            }

            $invokeWrapper.InvokeWithContext($functions, $variables, $script, $args, $instance)
        } else {
            try {
                $__results = $script.InvokeWithContext($functions, $variables, $args)
                @{
                    result = $__results
                    succeeded = $true
                }
            } catch {
                @{
                    result = $_
                    succeeded = $false
                }
            }
        }

<#
        try {
            $__results = $script.InvokeWithContext($functions, $variables, $args)
            @{
                result = $__results
                succeeded = $true
            }
        } catch {
            @{
                result = $_
                succeeded = $false
            }
        }
#>
    } catch {
        write-error $_
        get-psscallstack | write-error
        $_
    }

    if ( $result.succeeded ) {
        $result.result
    } else {
        throw $result.result
    }
}


