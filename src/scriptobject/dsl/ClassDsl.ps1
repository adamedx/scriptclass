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

class ClassDefinitionContext {
    ClassDefinitionContext([ClassDefinition] $classDefinition, $module, $staticModule) {
        $this.classDefinition = $classDefinition
        $this.module = $module
        $this.staticModule = $staticModule
    }

    [ClassDefinition] $classDefinition
    [PSModuleInfo] $module
    [PSModuleInfo] $staticModule
}

# This implements the language used to specify the definition of a class. This implementation
# is embedded within the PowerShell language, particularly as it can be executed within a
# PowerShell script block, a form of anonymous function
class ClassDsl {
    ClassDsl([bool] $staticScope, [HashTable] $systemMethodBlocks, [string] $constructorMethodName) {
        $this.staticScope = $staticScope
        $this.systemMethods = @()
        $this.constructorMethodName = $constructorMethodName

        if ( $systemMethodBlocks ) {
            foreach ( $methodName in $systemMethodBlocks.keys ) {
                $method = [Method]::new($methodName, $systemMethodBlocks[$methodName], $false, $true)
                $this.systemMethods += $method
            }
        }
    }

    [ClassDefinitionContext] NewClassDefinitionContext([string] $className, [ScriptBlock] $classBlock, [object[]] $classArguments, [HashTable]  $variablesToInclude) {
        $this.InitializeInspectionState($classBlock)

        $injectedVariables = if ( $variablesToInclude ) {
            $variablesToInclude.GetEnumerator() | foreach {
                [PSVariable]::new($_.name, $_.value)
            }
        }

        $classObject = new-module -AsCustomObject $this::inspectionBlock -argumentlist $this, $classBlock, $classArguments, $this.systemMethods, $injectedVariables

        if ( $this.exception ) {
            throw $this.exception
        }

        if ( ! $classObject ) {
            throw "Internal exception defining class"
        }

        $staticContext = $this.ProcessStaticBlocks()

        $instanceMethodList = $this.GetMethods($classObject, $false)
        $staticMethodList = $this.GetMethods($classObject, $true)

        $instancePropertyList = $this.GetProperties($classObject, $false)
        $staticPropertyList = $this.GetProperties($classObject, $true)

        $classDefinition = [ClassDefinition]::new($className, $instanceMethodList, $staticMethodList, $instancePropertyList, $staticPropertyList, $this.constructorMethodName)

        $staticModule = if ( $staticContext ) {
            $staticContext.module
        }

        return [ClassDefinitionContext]::new($classDefinition, $this.executingInspectionModule, $staticModule)
    }

    hidden [Method[]] GetMethods([PSCustomObject] $classObject, $staticScope) {
        $systemNames = $this.systemMethods.name
        $methods = if ( $staticScope ) {
            $this.staticMethods.values | foreach {
                [Method]::new($_.name, $_.block, $true, $false)
            }
        } else {
            $classObject.psobject.methods |
              where membertype -eq scriptmethod |
              where name -notin $this.excludedFunctions |
              foreach {
                  $isSystemMethod = $_.name -in $systemNames
                  [Method]::new($_.name, $_.script, $false, $isSystemMethod)
              }
        }

        return $methods
    }

    hidden [Property[]] GetProperties([PSCustomObject] $classObject, $staticScope) {
        $properties = if ( $staticScope ) {
            $this.staticProperties.values | foreach {
                $normalizedValue = if ( $_.type ) {
                    [TypedValue]::new($_.type, $_.value)
                } else {
                    $_.value
                }

                [Property]::new($_.name, $normalizedValue, $true, $false, $_.isReadOnly)
            }
        } else {
            $classObject.psobject.properties |
              where membertype -eq noteproperty |
              where name -notin $this.excludedVariables |
              foreach {
                  [Property]::new($_.name, $_.value, $false, $false, ! $_.IsSettable)
              }
        }

        return $properties
    }

    hidden [ClassDefinitionContext] ProcessStaticBlocks() {
        if ( $this.staticScope ) {
            return $null
        }
        $blocks = @({})
        $blocks += $this.staticBlocks

        $methodTable = @{}
        $this.systemMethods | foreach {
            $methodTable.Add($_.name, $_.block)
        }

 #       write-host blocks, $blocks.length
        $combinedBlock = {
            param([ScriptBlock[]] $staticBlocks)
#            write-host inlength, $staticBlocks.length
            $staticBlocks | foreach {
#                write-host -fore cyan processing
#                $_ | out-host
                . {}.module.newboundscriptblock($_)
            }
        }

        $dsl = [ClassDsl]::new($true, $methodTable, $null)
        $staticDefinitionContext = $dsl.NewClassDefinitionContext($null, $combinedBlock, (,$blocks), $this.classBlockParameters)

        $staticDefinitionContext.classDefinition.GetInstanceMethods() | foreach {
  #          write-host addingstaticmethod, $_.name
            $this.staticMethods.Add($_.name, $_)
        }

        $staticDefinitionContext.classDefinition.GetInstanceProperties() |foreach {
#            write-host addingstaticprop, $_.name
            $this.staticProperties.Add($_.name, $_)
        }

        return $staticDefinitionContext
    }

    hidden [void] InitializeInspectionState([ScriptBlock] $classBlock) {
        $this.executingInspectionModule = $null
        $this.staticProcessed = $false
        $this.staticBlocks = @()
        $this.staticMethods = @{}
        $this.staticProperties = @{}
        $this.exception = $null
        $this.classBlockParameters = $null
        $this.classBlockParameterNames = $this.GetClassBlockParameters($classBlock)
        $this.excludedVariables = @()
        $this.excludedVariables += $this.classBlockParameterNames
    }

    hidden [object[]] GetClassBlockParameters([ScriptBlock] $classBlock) {
        $parameterNames = @()
        $blockParameters = if ( $classBlock.ast.paramblock ) {
            $classBlock.ast.paramblock.parameters
        }
        if ( $blockParameters ) {
            $variableNames = $blockParameters.name | foreach {
                $parameterNames  += $_.variablepath.userpath
            }
        }

        return $parameterNames
    }

    [bool] $staticScope = $false
    $constructorMethodName = $null

    [bool] $staticProcessed = $false
    $staticBlocks = $null
    $staticMethods = @{}
    $staticProperties = @{}

    $classBlockParameters = $false
    $classBlockParameterNames = $null

    $systemMethods = $null

    $exception = $null

    $executingInspectionModule = $null

    $languageElements = @{
        [ScriptClassSpecification]::Parameters.Language.StrictTypeKeyword = @{
            Alias = $null
            Script = {
                param(
                    [parameter(mandatory=$true)] $type,
                    $value = $null
                )

                if (! $type -is [string] -and ! $type -is [Type]) {
                    throw "The 'type' argument of type '$($type.gettype())' specified for strict-val must be of type [String] or [Type]"
                }

                $propType = if ( $type -is [Type] ) {
                    $type
                } elseif ( $type.startswith('[') -and $type.endswith(']')) {
                    iex $type
                } else {
                    throw "Specified type '$propTypeName' was not of the form '[typename]'"
                }

                [TypedValue]::new($propType, $value)
            }
        }
        [ScriptClassSpecification]::Parameters.Language.StaticKeyword = @{
            Alias = $null
            Script = {
                param($staticBlock)
                if ( $this.staticScope ) {
                    throw 'Invalid static syntax'
                }

                if ( ! $this.staticProcessed ) {
                    $classBlockParameters = @{}
                    $this.classBlockParameterNames | foreach {
                        $name = $_
                        $value = ((get-pscallstack)[2].getframevariables()['psboundparameters']).value[$name][0]
                        $classBlockParameters.Add($name, $value)
                    }

                    $this.classBlockParameters = $classBlockParameters

                    $methodTable = @{}
                    $this.systemMethods | foreach {
                        $methodTable.Add($_.name, $_.block)
                    }

                    $this.staticProcessed = $true
                }

                $this.staticBlocks += $staticBlock
<#
                $dsl = [ClassDsl]::new($true, $methodTable, $null)
                $staticDefinition = $dsl.NewClassDefinition($null, $staticBlock, $null, $classBlockParameters)

                $staticDefinition.GetInstanceMethods() | foreach {
                    $this.staticMethods.Add($_.name, $_)
                }

                $staticDefinition.GetInstanceProperties() |foreach {
                    $this.staticProperties.Add($_.name, $_)
                }
#>
            }
        }
        [ScriptClassSpecification]::Parameters.Language.ConstantKeyword = @{
            Alias = [ScriptClassSpecification]::Parameters.Language.ConstantAlias
            Script = {
                param(
                    [parameter(mandatory=$true)] $name,
                    [parameter(mandatory=$true)] $value
                )

                $existingVariable = . $this.executingInspectionModule.NewBoundScriptBlock({param($___variableName) get-variable -name $___variableName -scope local -erroraction ignore}) $name $value

                if ( $existingVariable -eq $null ) {
                    . $this.executingInspectionModule.NewBoundScriptBlock({param($___variableName, $___variableValue) new-variable -name $___variableName -scope local -value $___variableValue -option readonly; remove-variable ___variableName, ___variableValue}) $name $value
                } elseif ($existingVariable.value -ne $value) {
                    throw "Attempt to redefine constant '$name' from value '$($existingVariable.value) to '$value'"
                }
            }
        }
    }

    $excludedVariables = $null
    $excludedFunctions = $this.languageElements.keys

    static $inspectionBlock = {
        param($___dsl, $___classBlock, $___classArguments, $___systemMethods, [object[]] $___importedVariables)
        set-strictmode -version 2

        $___dsl.executingInspectionModule = {}.Module

        if ( $___importedVariables ) {
            $___importedVariables | foreach {
                new-variable -name $_.name -value $_.value
                $___dsl.excludedVariables += $_.name
            }
        }

        foreach ( $___elementName in $___dsl.languageElements.keys ) {
            new-item function:/$___elementName -value $___dsl.languageElements[$___elementName].script | out-null
            if ( $___dsl.languageElements[$___elementName].Alias ) {
                set-alias $___dsl.languageElements[$___elementName].Alias $___elementName
            }
        }

        foreach ( $___method in $___systemMethods ) {
            new-item "function:/$($___method.name)" -value {}.Module.NewBoundScriptBlock($___method.block) | out-null
        }

        $___variables = @()

        get-variable | where { $_.name.StartsWith('___') } | foreach {
            $___variables += $_
        }

        try {
            .  {}.module.newboundscriptblock($___classBlock) @___classArguments | out-null
        } catch {
            $___dsl.exception = $_.exception
            throw
        }

        $___dsl.excludedVariables += @('this', 'foreach')

        # TODO: Remove this as it is currently redundant or make parameterized
        $___dsl.excludedFunctions = $___dsl.languageElements.keys

        $___variables | foreach { $_ | remove-variable }

        export-modulemember -function * -variable *
    }
}
