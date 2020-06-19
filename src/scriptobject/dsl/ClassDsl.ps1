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
    ClassDsl([bool] $staticScope, [HashTable] $injectedMethodBlocks, [string] $constructorMethodName) {
        $this.staticScope = $staticScope
        $this.constructorMethodName = $constructorMethodName
        $this.excludedFunctions = $this.languageElements.keys

        if ( $injectedMethodBlocks ) {
            foreach ( $methodName in $injectedMethodBlocks.keys ) {
                $method = [Method]::new($methodName, $injectedMethodBlocks[$methodName], $false, $true)
                $this.injectedMethods += $method
            }
        }
    }

    [ClassDefinitionContext] NewClassDefinitionContext([string] $className, [ScriptBlock] $classBlock, [object[]] $classArguments, [HashTable]  $variablesToInclude) {
        $this.InitializeProcessingState($classBlock)

        $injectedVariables = @()

        if ( $variablesToInclude ) {
            $variablesToInclude.GetEnumerator() | foreach {
                $injectedVariables += [PSVariable]::new($_.name, $_.value)
            }
        }

        # Add the class collection variable -- without this, modules that nest this module
        # will not see this variable in static methods...
        $collectionVariableName = [ScriptClassSpecification]::Parameters.Language.ClassCollectionName
        $injectedVariables += [PSVariable]::new($collectionVariableName, (get-variable $collectionVariableName -value))

        $classObject = new-module -AsCustomObject $this::inspectionBlock -argumentlist $this, $classBlock, $classArguments, $this.injectedMethods, $injectedVariables

        if ( $this.definitionProcessingState.exception ) {
            throw $this.definitionProcessingState.exception
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

        return [ClassDefinitionContext]::new($classDefinition, $this.definitionProcessingState.executingInspectionModule, $staticModule)
    }

    hidden [Method[]] GetMethods([PSCustomObject] $classObject, $staticScope) {
        $injectedMethodNames = $this.injectedMethods.name
        $methods = if ( $staticScope ) {
            $this.definitionProcessingState.staticMethods.values | foreach {
                [Method]::new($_.name, $_.block, $true, $false)
            }
        } else {
            $classObject.psobject.methods |
              where membertype -eq scriptmethod |
              where name -notin $this.excludedFunctions |
              foreach {
                  if ( $_.name -notin $injectedMethodNames ) {
                      [Method]::new($_.name, $_.script, $false, $false)
                  }
              }
        }

        return $methods
    }

    hidden [Property[]] GetProperties([PSCustomObject] $classObject, $staticScope) {
        $properties = if ( $staticScope ) {
            $this.definitionProcessingState.staticProperties.values | foreach {
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
              where name -notin $this.definitionProcessingState.excludedVariables |
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
        $blocks += $this.definitionProcessingState.staticBlocks

        $methodTable = @{}

        # This is required to ensure these methods are available
        # for invocation by other static methods in the class
        $this.injectedMethods | foreach {
            $methodTable.Add($_.name, $_.block)
        }

        # Combine all the static blocks into one block to avoid
        # having multiple modules (each block is a module) -- this
        # results in exactly one module for all static methods and properties
        $combinedBlock = {
            param([ScriptBlock[]] $staticBlocks)
            $staticBlocks | foreach {
                . {}.module.newboundscriptblock($_)
            }
        }

        $dsl = [ClassDsl]::new($true, $methodTable, $null)
        $staticDefinitionContext = $dsl.NewClassDefinitionContext($null, $combinedBlock, (,$blocks), $this.definitionProcessingState.classBlockParameters)

        $staticDefinitionContext.classDefinition.GetInstanceMethods() | foreach {
            $this.definitionProcessingState.staticMethods.Add($_.name, $_)
        }

        $staticDefinitionContext.classDefinition.GetInstanceProperties() |foreach {
            $this.definitionProcessingState.staticProperties.Add($_.name, $_)
        }

        return $staticDefinitionContext
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

    hidden [void] InitializeProcessingState($classBlock) {
        $this.definitionProcessingState = @{
            staticProcessed = $false
            staticBlocks = @()
            staticMethods = @{}
            staticProperties = @{}
            classBlockParameters = $null
            classBlockParameterNames = $this.GetClassBlockParameters($classBlock)
            excludedVariables = @()
            exception = $null
            executingInspectionModule = $null
        }

        $this.definitionProcessingState.excludedVariables += $this.definitionProcessingState.classBlockParameterNames
    }

    [bool] $staticScope = $false
    $constructorMethodName = $null
    $excludedFunctions = $null
    $injectedMethods = @()

    $definitionProcessingState = $null

    $languageElements = @{
        [ScriptClassSpecification]::Parameters.Language.StrictTypeKeyword = @{
            Alias = $null
            Script = {
                param(
                    [parameter(mandatory=$true)] $Type,
                    $Value = $null
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
                param($StaticBlock)
                if ( $this.staticScope ) {
                    throw 'Invalid static syntax'
                }

                if ( ! $this.definitionProcessingState.staticProcessed ) {
                    $classBlockParameters = @{}
                    $this.definitionProcessingState.classBlockParameterNames | foreach {
                        $name = $_
                        $value = ((get-pscallstack)[2].getframevariables()['psboundparameters']).value[$name][0]
                        $classBlockParameters.Add($name, $value)
                    }

                    $this.definitionProcessingState.classBlockParameters = $classBlockParameters

                    $methodTable = @{}

                    $this.definitionProcessingState.staticProcessed = $true
                }

                $this.definitionProcessingState.staticBlocks += $staticBlock
            }
        }
        [ScriptClassSpecification]::Parameters.Language.ConstantKeyword = @{
            Alias = [ScriptClassSpecification]::Parameters.Language.ConstantAlias
            Script = {
                param(
                    [parameter(mandatory=$true)] $name,
                    [parameter(mandatory=$true)] $value
                )

                $existingVariable = . $this.definitionProcessingState.executingInspectionModule.NewBoundScriptBlock({param($___variableName) get-variable -name $___variableName -scope local -erroraction ignore}) $name $value

                if ( $existingVariable -eq $null ) {
                    . $this.definitionProcessingState.executingInspectionModule.NewBoundScriptBlock({param($___variableName, $___variableValue) new-variable -name $___variableName -scope local -value $___variableValue -option readonly; remove-variable ___variableName, ___variableValue}) $name $value
                } elseif ($existingVariable.value -ne $value) {
                    throw "Attempt to redefine constant '$name' from value '$($existingVariable.value) to '$value'"
                }
            }
        }
    }

    static $inspectionBlock = {
        param($___dsl, $___classBlock, $___classArguments, $___injectedMethods, [object[]] $___importedVariables)
        set-strictmode -version 2

        $___dsl.definitionProcessingState.executingInspectionModule = {}.Module

        if ( $___importedVariables ) {
            $___importedVariables | foreach {
                new-variable -name $_.name -value $_.value
                $___dsl.definitionProcessingState.excludedVariables += $_.name
            }
        }

        foreach ( $___elementName in $___dsl.languageElements.keys ) {
            new-item function:/$___elementName -value $___dsl.languageElements[$___elementName].script | out-null
            if ( $___dsl.languageElements[$___elementName].Alias ) {
                set-alias $___dsl.languageElements[$___elementName].Alias $___elementName
            }
        }

        foreach ( $___method in $___injectedMethods ) {
            new-item "function:/$($___method.name)" -value {}.Module.NewBoundScriptBlock($___method.block) | out-null
        }

        $___variables = @()

        get-variable | where { $_.name.StartsWith('___') } | foreach {
            $___variables += $_
        }

        try {
            .  {}.module.newboundscriptblock($___classBlock) @___classArguments | out-null
        } catch {
            $___dsl.definitionProcessingState.exception = $_.exception
            throw
        }

        $___dsl.definitionProcessingState.excludedVariables += @('this', 'foreach')

        # TODO: Remove this as it is currently redundant or make parameterized
        $___dsl.definitionProcessingState.excludedFunctions = $___dsl.languageElements.keys

        $___variables | foreach { $_ | remove-variable }

        export-modulemember -function * -variable *
    }
}
