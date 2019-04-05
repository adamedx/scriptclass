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
        $this.classBlock = $classBlock
        $this.systemMethodBlocks = @{}
        $this.systemProperties = @{}
        $this.constructorName = $constructorName

        $this.AddSystemProperty([NativeObjectBuilder]::NativeTypeMemberName, $null, $className)
    }

    [ClassInfo] ToClassInfo([object[]] $classArguments) {
        $dsl = [ClassDsl]::new($false, $this.systemMethodBlocks, $this.constructorName)
        $classDefinition = $dsl.NewClassDefinition($this.className, $this.classBlock, $classArguments, $null)

        $basePrototype = $classDefinition.ToPrototype($false)
        $prototype = $this.GetPrototypeObject($basePrototype)
 #       $prototype = $this.GetPrototypeObject()
        $systemNames = $this.systemMethodBlocks.keys

        $classInfo = [ClassInfo]::new($classDefinition, $prototype)
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
}
