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

# The ScriptClassBuilder implements what is essentially a derived type of the general type. In particular,
# ScriptClassBuilder is where the notion of static methods is implemented for the type, and object structure
# supporting that along a level of reflection capability that distinguishes ScriptClass types is implemented
# here.
class ScriptClassBuilder : ClassBuilder {
    ScriptClassBuilder([string] $className, [ScriptBlock] $classblock) :
    base($className, $classBlock, [ScriptClassSpecification]::Parameters.Language.ConstructorName) {
    }

    ScriptClassBuilder([ClassDefinitionContext] $context) :
    base($context) {
    }

    [ClassInfo] ToClassInfo([object[]] $classArguments) {
        $classMemberParameters = [ScriptClassSpecification]::Parameters.Schema.ClassMember
        $staticTarget = [NativeObjectBuilder]::CopyFrom($this::classMemberPrototype)
        $this.AddSystemProperty($classMemberParameters.Name, $null, $staticTarget)

        foreach ( $methodname in $this::commonMethods.keys ) {
            $this.AddSystemMethod($methodName, $this::commonMethods[$methodName] )
        }

        $classInfo = ([ClassBuilder]$this).ToClassInfo($classArguments)

        $classInfo.classDefinition.CopyPrototype($true, $staticTarget)

        $definitionContext = ([ClassBuilder]$this).definitionContext

        $instanceModule = ([ClassBuilder]$this).definitionContext.module
        $staticModule = if ( $definitionContext ) {
            $definitionContext.staticModule
        }

        $staticTarget.$($classMemberParameters.Structure.ClassNameMemberName) = $this.className
        $staticTarget.$($classMemberParameters.Structure.ModuleMemberName) = $staticModule

        $this::AddStaticCommonMethods($instanceModule, $classInfo.prototype)
        $this::AddStaticCommonMethods($staticModule, $staticTarget)

        $excludedMethodNames = $this::commonMethods.keys
        $filteredClassDefinition = [ClassDefinition]::GetFilteredDefinition($classInfo.classDefinition, $excludedMethodNames, $null)

        return [ClassInfo]::new($filteredClassDefinition, $classInfo.prototype, $classInfo.module)
    }

    static [void] Initialize() {
        $schemaParameters = [ScriptClassSpecification]::Parameters.Schema.ClassMember

        $primitiveClassPropertyNames = @(
            $schemaParameters.Name
            $schemaParameters.Structure.ClassNameMemberName
            $schemaParameters.Structure.ModuleMemberName
        )

        $primitiveClassProperties = $primitiveClasspropertyNames | foreach {
            [Property]::new($_, $null, $false, $false, $false)
        }

        $primitiveClassDefinition = [ClassDefinition]::new(
            $null,
            @(),
            @(),
            $primitiveClassProperties,
            @(),
            $null
        )

        [ScriptClassBuilder]::classMemberPrototype = $primitiveClassDefinition.ToPrototype($false)
    }

    static [string] GetVerbosePreference() {
        return $script:ScriptClassVerbosePreference
    }

    static $classMemberPrototype = $null
    static $commonMethods = @{
        InvokeMethod = {
            param([string] $methodName, $arguments)
            if ( ! $methodName ) {
                throw [ArgumentException]::new("Method name argument was `$null or empty")
            }
            $method = ($this.psobject.methods | where name -eq $methodname)
            if ( ! $method ) {
                throw [System.Management.Automation.MethodInvocationException]::new("The method '$methodName' could not be found on the object")
            }

            $oldVerbosePreference = $VerbosePreference
            $VerbosePreference = [ScriptClassBuilder]::GetVerbosePreference()

            try {
                . $method.script @arguments
            } finally {
                $VerbosePreference = $oldVerbosePreference
            }
        }
        InvokeScript = {
            param([ScriptBlock] $script, $arguments)
            if ( ! $script ) {
                throw [ArgumentException]::new("Scriptblock argument argument was `$null or not specified")
            }
            # An interesting alternative is this, but evaluating a new closure AND getting a new scriptblock
            # seems excessive for a single method call -- perhaps system methods like this can be bound
            # when they are added to the object prototype:
            #
            #    . $script.module.newboundscriptblock($script.GetNewClosure()) @arguments
            #
            $thisVariable = [PSVariable]::new('this', $this)
            $script.InvokeWithContext(@{}, [PSVariable[]] @($thisVariable), $arguments)
        }
        GetScriptObjectHashCode = {
            $this.psobject.members.GetHashCode()
        }
    }

    static [void] AddStaticCommonMethods($module, $staticPrototype) {
        $objectBuilder = [NativeObjectBuilder]::new($null, $staticPrototype, [NativeObjectBuilderMode]::Modify)
        foreach ( $methodname in [ScriptClassBuilder]::commonMethods.keys ) {
            $normalizedMethod = $module.newboundscriptblock([ScriptClassBuilder]::commonMethods[$methodName])
            $objectBuilder.AddMethod($methodName, $normalizedMethod)
        }
    }
}

[ScriptClassBuilder]::Initialize()
