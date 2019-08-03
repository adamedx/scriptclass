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

# The ClassBuilder translates a system-indepenent class definition into a type
# that can be used to create objects of that type in the type system.
class ClassBuilder {
    ClassBuilder([string] $className, [ScriptBlock] $classblock, [string] $constructorName) {
        $this.className = $className
        if ( ! $this.className ) {
            throw 'anger4'
        }
        $this.classBlock = $classBlock
        $this.systemMethodBlocks = @{}
        $this.systemProperties = @{}
        $this.constructorName = $constructorName

        $this.AddSystemProperty([NativeObjectBuilder]::NativeTypeMemberName, $null, $className)
    }

    ClassBuilder([ClassDefinitionContext] $context) {
        $this.definitionContext = $context
        if ( $context.module -eq $null ) {
            throw 'anger2'
        }
        $this.className = $context.classDefinition.name
        if ( ! $this.className ) {
            throw 'anger'
        }
        $this.classBlock = $null
        $this.systemMethodBlocks = @{}
        $this.systemProperties = @{}
        $this.constructorName = $context.classDefinition.constructorMethodName

        $this.AddSystemProperty([NativeObjectBuilder]::NativeTypeMemberName, $null, $this.className)
    }


    [ClassInfo] ToClassInfo([object[]] $classArguments) {
        $context = if ( $this.definitionContext ) {
            if ( $classArguments ) {
                throw 'Class arguments may not be specified when generating class information from an existing definition'
            }
            $this.definitionContext
        } else {
            $dsl = [ClassDsl]::new($false, $this.systemMethodBlocks, $this.constructorName)
            $this.definitionContext = $dsl.NewClassDefinitionContext($this.className, $this.classBlock, $classArguments, $null)
            $this.definitionContext
        }

        $basePrototype = $context.classDefinition.ToPrototype($false)
        $prototype = $this.GetPrototypeObject($basePrototype)
 #       $prototype = $this.GetPrototypeObject()

        $classInfo = [ClassInfo]::new($context.classDefinition, $prototype, $context.module)
        return $classInfo
    }

    [void] AddSystemMethod([string] $methodName, [ScriptBlock] $methodBlock ) {
        $this.systemMethodBlocks.Add($methodName, $methodBlock)
    }

    [void] AddSystemProperty([string] $propertyName, $type, $value) {
        $this.systemProperties.Add($propertyName, @{name=$propertyName; type=$type; value=$value})
    }

    hidden [object] GetPrototypeObject($basePrototype) {
        $builder = [NativeObjectBuilder]::new($null, $basePrototype, [NativeObjectBuilderMode]::Modify)
#        $builder = [NativeObjectBuilder]::new($null, $null, [NativeObjectBuilderMode]::Create)
        if ( $this.systemProperties ) {
            $this.systemProperties.values | foreach {
                $builder.AddProperty($_.name, $_.type, $_.value, $_.isReadOnly)
            }
        }

        return $builder.GetObject()
    }

    [string] $className = $null
    [string] $constructorName = $null
    [ScriptBlock] $classBlock = $null
    [HashTable] $systemMethodBlocks = $null
    [HashTable] $systemProperties = $null
    [ClassDefinitionContext] $definitionContext = $null
}
