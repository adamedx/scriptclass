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

new-variable -name __ScriptClass__StrictTypeCheckingTypename -value '__scriptclass_strict_value__' -Option Readonly -scope global -erroraction ignore
new-variable -name __ScriptClass__ScriptClassTypeName -value '__ScriptClassType__' -option Readonly -scope global -erroraction ignore

$:: = ([PSCustomObject] @{})

function __restore-deserializedobjectmethods($existingClass, $object) {
    # Deserialization of ScriptClass object, say from start-job or even a remote session,
    # strips off ScriptMethod and ScriptProperty properties. ScriptProperty properties are
    # evaluated and converted to NoteProperty. ScriptMethod properties are simply
    # omitted. Here we restore ScriptMethod properties from the original class definition.
    # Only methods are restored here -- a separate adjustment is required for
    # the missing ScriptProperty properties.
    $templateObject = [PSCustomObject] $existingClass.prototype.psobject.copy()
    $object.scriptclass = $existingClass.prototype.scriptclass
    $existingClass.prototype | gm -membertype scriptmethod | foreach {
        write-verbose "Restoring method $($_.name) on class $($object.scriptclass.classname)"
        $object | add-member -name $_.name -memberType 'ScriptMethod' -value $templateObject.psobject.methods[$_.name].script
    }
}

function __add-classmember($className, $classDefinition) {
    $classMember = [PSCustomObject] @{
        PSTypeName = $__ScriptClass__ScriptClassTypeName
        ClassName = $className
        InstanceProperties = @{}
        TypedMembers = @{}
        Module = $classDefinition.parentModule
        ScriptClass = $null
    }

    # Add common methods to the class itself
    __add-member $classMember PSTypeData ScriptProperty ([ScriptBlock]::Create("(__ScriptClass__GetClass '$className').typedata"))
    __add-member $classMember GetScriptObjectHashCode ScriptMethod { $this.psobject.members.GetHashCode() }
    __add-member $classMember InvokeScript ScriptMethod $classInvoker

    # Add common methods for each instance
    __add-typemember NoteProperty $className 'ScriptClass' $null $classMember -hidden
    __add-typemember ScriptMethod $className GetScriptObjectHashCode $null { $this.psobject.members.GetHashCode() }
}

function __add-scriptpropertytyped($object, $memberName, $memberType, $initialValue = $null) {
    if ($initialValue -ne $null) {
        $evalString = "param(`[$memberType] `$value)"
        $evalBlock = [ScriptBlock]::Create($evalString)
        (. $evalBlock $initialValue) | out-null
    }

    $getBlock = [ScriptBlock]::Create("[$memberType] `$this.TypedMembers['$memberName']")
    $setBlock = [Scriptblock]::Create("param(`$val) `$this.TypedMembers['$memberName'] = [$memberType] `$val")

    __add-member $object $memberName 'ScriptProperty' $getBlock $null $setBlock
    $object.TypedMembers[$memberName] = $initialValue
}

function __add-member($prototype, $memberName, $psMemberType, $memberValue, $memberType = $null, $memberSecondValue = $null, $force = $false) {
    $arguments = @{name=$memberName;memberType=$psMemberType;value=$memberValue}

    if ($memberSecondValue -ne $null) {
        $arguments['secondValue'] = $memberSecondValue
    }

    $newMember = ($prototype | add-member -passthru @arguments)
}

function __add-typemember($memberType, $className, $memberName, $typeName, $initialValue, $constant = $false, [switch] $hiddenMember) {
    if ($typeName -ne $null -and -not $typeName -is [Type]) {
        throw "Invalid argument passed for type -- the argument must be of type [Type]"
    }

    $classDefinition = __ScriptClass__FindClass $className

    $memberExists = $classDefinition.typedata.members.keys -contains $memberName

    if ($memberName -eq $null ) {
        throw 'A $null member name was specified'
    }

    if ($memberExists) {
        throw "Member '$memberName' already exists for type '$className'"
    }

    $defaultDisplay = @()
    $propertySerializationSet = @()

    if ( $classDefinition.typedata.defaultdisplaypropertyset | gm referencedProperties ) {
        $classDefinition.typedata.defaultdisplaypropertyset.referencedproperties | foreach {
            $defaultDisplay += $_
        }
    }

    $classDefinition.typedata.propertyserializationset.referencedproperties | foreach {
        $propertyserializationset += $_
    }

    if (! $hiddenMember.ispresent) {
        $defaultDisplay += $memberName
        if ($memberType -eq 'NoteProperty' -or $memberType -eq 'ScriptProperty') {
            $classDefinition.prototype.scriptclass.instanceproperties[$memberName] = $typeName
        }
    }

    $propertyserializationset += $memberName

    $aliasName = "__$($memberName)"
    $realName = $memberName
    if ($typeName -ne $null -or $constant) {
        $realName = $aliasName
        $aliasName = $memberName
    }

    # For serializationdepth parameter, see
    # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/update-typedata?view=powershell-6
    # It does not seem to be the actual depth.
    $nameTypeData = @{TypeName=$className;MemberType=$memberType;MemberName=$realName;Value=$initialValue;defaultdisplaypropertyset=$defaultdisplay;serializationdepth=2;serializationmethod='SpecificProperties';propertyserializationset=$propertyserializationset}
    __add-member $classDefinition.prototype $realName $memberType $initialValue $typeName
    Update-TypeData -force @nameTypeData

    if ($typeName -ne $null) {
        # Check to make sure any initializer is compatible with the declared type
        if ($initialValue -ne $null) {

            $evalString = "param(`[$typeName] `$value)"
            $evalBlock = [ScriptBlock]::Create($evalString)
            (. $evalBlock $initialValue) | out-null
        }
    }

    if ($typeName -ne $null -or $constant) {
        $typeCoercion = if ( $typeName -ne $null ) {
            "[$typeName]"
        } else {
            ''
        }
        $getBlock = [ScriptBlock]::Create("$typeCoercion `$this.$realName")
        $setBlock = if (! $constant) {
            [Scriptblock]::Create("param(`$val) `$this.$realName = $typeCoercion `$val")
        } else {
            [Scriptblock]::Create("param(`$val) throw `"member '$aliasName' cannot be overwritten because it is read-only`"")
        }
        $aliasTypeData = @{TypeName=$className;MemberType='ScriptProperty';MemberName=$aliasName;Value=$getBlock;SecondValue=$setBlock}
        Update-TypeData -force @aliasTypeData
    }

    $typeSystemData = get-typedata $className

    $classDefinition.typeData = $typeSystemData
}

function __clear-typedata($className) {
    $existingTypeData = get-typedata $className

    if ($existingTypeData -ne $null) {
        $existingTypeData | remove-typedata
    }
}

function __new-class([Hashtable]$classData, [ScriptBlock] $classBlock) {
    $className = $classData['Value']

    # remove existing type data
    __clear-typedata $className

    Update-TypeData -force @classData
    $typeSystemData = get-typedata $classname

    $prototype = [PSCustomObject]@{PSTypeName=$className}
    $classDefinition = @{typedata=$typeSystemData;prototype=$prototype;classblock=$classblock;instancemethods=@{};parentModule=$classBlock.module}

    __ScriptClass__SetClass $className $classDefinition
    $classDefinition
}

function __remove-publishedclass($className) {
    try {
        $::.psobject.members.remove($className)
    } catch {
    }
}

$__instanceWrapperTemplate = @'
$existingClass = __ScriptClass__GetClass $this.scriptclass.className
invoke-method $this $existingClass.instancemethods['{0}'] @args
'@

function __define-class($classDefinition, $ArgumentList) {
    __ClearStatics
    $memberData = $null
    $classDefinitionException = $null

    $memberData = $null

    $excludedVariables = @()

    $afterFunctions = $null
    $beforeFunctions = $null
    $classModule = $null

    try {
        $classModule = new-module -scriptblock $classDslBlock
        invoke-command $classModule.NewBoundScriptBlock($classDefinition.Classblock) -nonewscope -ArgumentList $ArgumentList | out-null
        $afterFunctions = invoke-command $classModule.NewBoundScriptBlock($classExportBlock) -nonewscope
        $memberData = $classModule.AsCustomObject()
    } catch {
        $classDefinitionException = $_
    }

    if ($classDefinitionException -ne $null) {
        $badClassData = get-typedata $classDefinition.typeData.TypeName
        $badClassData | remove-typedata
        throw $classDefinitionException
    }

    $afterFunctions | foreach {
        if ( $memberData.__exportedFunctions[$_.scriptblock.gethashcode()] ) {
#            write-host 'removing', $_.name
            $memberData.__exportedFunctions.Remove($_.scriptblock.gethashcode())
        } else {
            $memberData.__exportedFunctions.Add($_.scriptblock.gethashcode(), $_)
        }
    }

#    $exportedFunctions.values | out-host

 #   $memberData | fl * | out-host
    $memberData.psobject.properties | where MemberType -eq 'NoteProperty' | foreach {
        if ( $_.name -ne '__classException' -and $excludedVariables -notcontains $_.name -and $_.name -ne '__exportedFunctions') {
#            write-host 'var', $_.name
            $isSettable = $true
            $memberName = $_.name
            $memberTypeName = $null
            $memberVariable = $_
            $memberValue = if ( $memberVariable.value -is [PSCustomObject] -and $memberVariable.value.psobject.typenames.contains($__ScriptClass__StrictTypeCheckingTypename) ) {
                $memberTypeName = $memberVariable.value.type
                $isSettable = $memberVariable.value.psobject.properties | where name -eq value | select -expandproperty issettable
                $memberVariable.value.value
            } else {
#                $memberVariable | gm | out-host
                $isSettable = $memberVariable.IsSettable # $memberVariable.options -ne 'readonly'
                $memberVariable.value
            }
            __add-typemember NoteProperty $classDefinition.typeData.TypeName $membername $memberTypeName $memberValue (! $isSettable)
        }
    }

#    $nextFunctions = $memberData.psobject.methods | where MemberType -eq ScriptMethod
    $nextFunctions = $memberData.__exportedFunctions.Values

    $hasInitialize = $false

    $nextFunctions | foreach {
        $methodBlock = $_.ScriptBlock
        $nonModuleMethodBlockWrapper = if ( $_.name -ne 'InvokeScript' ) {
            $methodBlock.module.newboundscriptblock([ScriptBlock]::Create($__instanceWrapperTemplate -f $_.name))
        }
        else {
            $_.ScriptBlock
        }

        $targetModule = $classDefinition.parentModule

        $methodBlockWrapper = if ( $targetModule ) {
#            $methodBlock = $targetModule.NewBoundScriptBlock($_.ScriptBlock)
            #$targetModule.NewBoundScriptBlock($nonModuleMethodBlockWrapper)
#            $targetModule.NewBoundScriptBlock($nonModuleMethodBlockWrapper)
            $nonModuleMethodBlockWrapper
        } else {
            $nonModuleMethodBlockWrapper
#            $methodBlock.Module.NewBoundScriptBlock($nonModuleMethodBlockWrapper)
        }

         # [ScriptBlock]::Create($__instanceWrapperTemplate -f $_.name)

#        $methodBlockWrapper = $_.ScriptBlock
        __add-typemember ScriptMethod $classDefinition.typeData.TypeName $_.name $null $methodBlockWrapper
        $classDefinition.instancemethods[$_.name] = $methodBlock
        if ( $_.name -eq '__initialize' ) {
            $hasInitialize = $true
        }
    }

    if ( ! $hasInitialize ) {
        __add-typemember ScriptMethod $classDefinition.typeData.TypeName __initialize $null {}
    }

    (__ScriptClass__GetStaticFunctions).getenumerator() | foreach {
        __add-member $classDefinition.prototype.scriptclass $_.name ScriptMethod $_.value.scriptblock
    }

    (__ScriptClass__GetStaticVariables).getenumerator() | foreach {
        if ( $_.value.value -is [PSCustomObject] -and $_.value.value.psobject.typenames.contains($__ScriptClass__StrictTypeCheckingTypename) ) {
            __add-scriptpropertytyped $classDefinition.prototype.scriptclass $_.name $_.value.value.type $_.value.value.value
        } else {
            __add-member $classDefinition.prototype.scriptclass $_.name NoteProperty $_.value.value
        }
    }

    $classDefinition.Add('classModule', $classModule)
}

__clear-typedata $__ScriptClass__scriptClassTypeName
