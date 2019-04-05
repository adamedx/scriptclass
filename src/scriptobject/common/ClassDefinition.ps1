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

# This provides a system-indepent definition of what defines a class
# of objects for use in a type system. In theory types defined this
# way are not tied to a particular implementation in terms of how
# objects of the class are instantiated and execute at runtime.
class Method {
    [string] $name
    [ScriptBlock] $block
    [bool] $isStatic
    [bool] $isSystem
    Method([string] $name, [ScriptBlock] $methodBlock, $isStatic, $isSystem) {
        $this.name = $name
        $this.block = $methodBlock
        $this.isStatic = $isStatic
        $this.isSystem = $isSystem
    }
}

class Property {
    [string] $name = $null
    [type] $type = $null
    [object] $value = $null
    [bool] $isStatic
    [bool] $isSystem
    [bool] $isReadOnly

    Property([string] $name, $value, [bool] $isStatic, [bool] $isSystem, [bool] $isReadOnly) {
        $this.isStatic = $isStatic
        $this.isSystem = $isSystem
        $this.isReadOnly = $isReadOnly
        $this.name = $name

        if ( $value -is [TypedValue] ) {
            $this.type = $value.type
            $this.value = $value.value
        } else {
            $this.type = $null
            $this.value = $value
        }
    }
}

class TypedValue {
    [type] $type = $null
    [object] $value = $null

    TypedValue($type, $value) {
        $this.type = $type
        $this.value = $value
    }
}

class ClassInfo {
    ClassInfo([ClassDefinition] $classDefinition, $prototype) {
        $this.classDefinition = $classDefinition
        $this.prototype = $prototype
    }
    [ClassDefinition] $classDefinition
    $prototype
}

class ClassDefinition {
    ClassDefinition([string] $name, [Method[]] $instanceMethods, [Method[]] $staticMethods, [Property[]] $instanceProperties, [Property[]] $staticProperties, $constructorMethodName) {
        $this.name = $name

        foreach ( $instanceMethod in $instanceMethods ) {
            if ( $constructorMethodName -and $instanceMethod.Name -eq $constructorMethodName ) {
                $this.constructor = $instanceMethod.block
            } else {
                $this.instanceMethods[$instanceMethod.name] = $instanceMethod
            }
        }

        foreach ( $instanceProperty in $instanceProperties ) {
            $this.instanceProperties[$instanceProperty.name] = $instanceProperty
        }

        foreach ( $staticMethod in $staticMethods ) {
            $this.staticMethods[$staticMethod.name] = $staticMethod
        }

        foreach ( $staticProperty in $staticProperties ) {
            $this.staticProperties[$staticProperty.name] = $staticProperty
        }
    }

    static [ClassDefinition] GetFilteredDefinition([ClassDefinition] $classDefinition, [string[]] $excludedMethods, [string[]] $excludedProperties) {
        $newDefinition = [ClassDefinition]::new(
            $classDefinition.name,
            $null,
            $null,
            $null,
            $null,
            $null
        )

        $newDefinition.instanceMethods = [ClassDefinition]::GetFilteredTable($classDefinition.instanceMethods, $excludedMethods)
        $newDefinition.staticMethods = [ClassDefinition]::GetFilteredTable($classDefinition.staticMethods, $excludedMethods)
        $newDefinition.instanceProperties = [ClassDefinition]::GetFilteredTable($classDefinition.instanceProperties, $excludedProperties)
        $newDefinition.staticProperties = [ClassDefinition]::GetFilteredTable($classDefinition.staticProperties, $excludedProperties)
        $newDefinition.constructor = $classDefinition.constructor

        return $newDefinition
    }

    [void] CopyPrototype([bool] $staticContext, $existingObject) {
        $builder = [NativeObjectBuilder]::new($null, $existingObject, [NativeObjectBuilderMode]::Modify)
        $this.WritePrototype($builder, $staticContext)
    }

    [object] ToPrototype([bool] $staticContext) {
        $builder = [NativeObjectBuilder]::new($this.name, $null, [NativeObjectBuilderMode]::Create)

        $this.WritePrototype($builder, $staticContext)

        return $builder.GetObject()
    }

    [Method] GetMethod($methodName, [bool] $static) {
        $methodTable = if ( $static ) {
            $this.staticMethods
        } else {
            $this.instanceMethods
        }

        return $methodTable[$methodName]
    }

    [Method[]] GetInstanceMethods() {
        return $this.instanceMethods.values
    }

    [Property[]] GetInstanceProperties() {
        return $this.instanceProperties.values
    }

    [Method[]] GetStaticMethods() {
        return $this.staticMethods.values
    }

    [Property[]] GetStaticProperties() {
        return $this.staticProperties.values
    }

    hidden [void] WritePrototype([NativeObjectBuilder] $builder, [bool] $staticContext) {
        $methods = if ( $staticContext ) {
            $this.staticMethods.values
        } else {
            $this.instanceMethods.values
        }

        $properties = if ( $staticContext ) {
            $this.staticProperties.values
        } else {
            $this.instanceProperties.values
        }

        $methods | foreach {
            $builder.AddMethod($_.name, $_.block)
        }

        $properties | foreach {
            $builder.AddProperty($_.name, $_.type, $_.value, $_.isReadOnly)
        }
    }

    hidden static [HashTable] GetFilteredTable([HashTable] $source, [string[]] $keyFilter) {
        $result = @{}

        if ( $source ) {
            $source.GetEnumerator() |
              where name -notin $keyFilter |
              foreach {
                  $result.Add($_.name, $_.value)
              }
        }

        return $result
    }

    [string] $name = $null
    [ScriptBlock] $constructor = $null
    [HashTable] $instanceMethods = @{}
    [HashTable] $instanceproperties = @{}
    [HashTable] $staticMethods = @{}
    [HashTable] $staticProperties = @{}
}
