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

# The NativeObjectBuilder allows the consumer to construct objects in an object format
# "native" to another runtime, in this case the PowerShell runtime. As much as possible
# runtime-specific, i.e. PowerShell-specific object behaviors are centralized in this
# class.
enum NativeObjectBuilderMode {
    Create
    Modify
}

class NativeObjectBuilder {
    static $NativeTypeMemberName = 'PSTypeName'
    NativeObjectBuilder([string] $typeName, [PSCustomObject] $prototype, [NativeObjectBuilderMode] $mode) {
        $this.mode = $mode
        $this.object = if ( $mode -eq [NativeObjectBuilderMode]::Modify ) {
            if ( ! $prototype ) {
                throw [ArgumentException]::New("'Modify' mode was specified for ObjectBuilder, but no existing object was specified to modify")
            }

            if ( $typeName ) {
                throw [ArgumentException]::new("Type name may not be specified for ObjectBuilder 'Modify' mode -- an object's type is immutable")
            }

            $prototype
        } else {
            $objectState = @{}
            if ( $typeName ) {
                $this::UnregisterClassType($typeName)
                $objectState[$this::NativeTypeMemberName] = $typeName
            }
            if ( $prototype ) {
                $prototype.psobject.properties | foreach {
                    if ( $_.membertype -ne 'NoteProperty' ) {
                        throw [ArgumentException]::new("Property '$($_.name)' of member type '$($_.memberType)' is not of valid member type 'NoteProperty'")
                    }

                    $objectState[$_.name] = $_.value
                }
            }

            [PSCustomObject] $objectState
        }
    }

    [PSCustomObject] GetObject() {
        return $this.object
    }

    [void] AddMember($name, $memberType, $value, $secondValue) {
        $secondValueParameter = if ( $secondValue ) {
            @{SecondValue=$secondValue}
        } else {
            @{}
        }

        $this.object | add-member -MemberType $memberType -name $name -value $value @secondValueParameter
    }

    [void] AddProperty($name, $type, $value, $isConstant) {
        $backingPropertyName = if ( ! $type -and ! $isConstant) {
            $name
        } else {
            # Check to make sure any initializer is compatible with the declared type
            if ($type -and ($value -ne $null)) {
                $evalString = "param(`[$type] `$value)"
                $evalBlock = [ScriptBlock]::Create($evalString)
                (. $evalBlock $value) | out-null
            }
            "___$($name)"
        }

        $this.AddMember($backingPropertyname, 'NoteProperty', $value, $null)

        if ( $type -or $isConstant ) {
            $typeCoercion = if ( $type ) {
                "[$type]"
            } else {
                ''
            }
            $readBlock = [ScriptBlock]::Create("$typeCoercion `$this.$backingPropertyName")
            $writeBlock = if ( ! $isConstant ) {
                [Scriptblock]::Create("param(`$val) `$this.$backingPropertyName = $typeCoercion `$val")
            } else {
                [Scriptblock]::Create("param(`$val) throw `"member '$name' cannot be overwritten because it is read-only`"")
            }
            $this.AddMember($name, 'ScriptProperty', $readBlock, $writeBlock)
        }
    }

    [void] AddMethod($name, $methodBlock) {
        $this.AddMember($name, 'ScriptMethod', $methodBlock, $null)
    }

    [void] RemoveMember([string] $name, [string] $type, [bool] $force) {
        if ( ! $force ) {
            if (! ( $this.object | gm -name $name -membertype $type -erroraction ignore ) ) {
                throw "Member '$name' cannot be removed because the object has no such member."
            }
        }
        $this.object.psobject.members.remove($name)
    }

    static [object] CopyFrom($sourceObject) {
        return $sourceObject.psobject.copy()
    }

    hidden static [void] UnregisterClassType([string] $typeName) {
        remove-typedata $typename -erroraction ignore
    }

    static [void] RegisterClassType([string] $typeName, [string[]] $visiblePropertyNames, $prototype) {
        if ( $visiblePropertyNames -contains ([NativeObjectBuilder]::NativeTypeMemberName) ) {
            throw "Property name ([NativeObjectBuilder]::NativeTypeMemberName) is prohibited"
        }

        $typeArguments = [NativeObjectBuilder]::basicTypeData.clone()
        $typeArguments.TypeName = $typeName

        $displayProperties = @{}
        $typeArguments['DefaultDisplayPropertySet'] |
          where { $_ -ne $null -and $_ -ne ([NativeObjectBuilder]::NativeTypeMemberName) } |
          foreach {
              $displayProperties.Add($_, $null)
          }

        if ( $visiblePropertyNames ) {
            $visiblePropertyNames | foreach {
                $displayProperties.Add($_, $null)
            }
        }

        if ( $displayProperties.count -gt 0 ) {
            $typeArguments['DefaultDisplayPropertySet'] = [string[]] $displayProperties.keys
        }

        if ( $prototype ) {
            $typeArguments['PropertySerializationSet'] = $prototype.psobject.properties | where name -ne ([NativeObjectBuilder]::NativeTypeMemberName) | select -expandproperty name
        }

        Update-TypeData -force @typeArguments
    }

    static $basicTypeData = @{
        TypeName = $null
        Serializationmethod = 'SpecificProperties'
        Serializationdepth = 2
    }

    [PSCustomObject] $object = $null
    [NativeObjectBuilderMode] $mode
}
