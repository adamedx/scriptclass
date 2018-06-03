# Copyright 2017, Adam Edwards
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

set-strictmode -version 2

set-alias const new-constant

$__classTable = @{}

if ( ! (test-path variable:stricttypecheckingtypename) ) {
    new-variable -name StrictTypeCheckingTypename -value '__scriptclass_strict_value__' -Option Readonly
}

if ( ! (test-path variable:scriptclasstypename) ) {
    new-variable -name ScriptClassTypeName -value 'ScriptClassType' -option Readonly
}

$:: = [PSCustomObject] @{}

function __clear-typedata($className) {
    $existingTypeData = get-typedata $className

    if ($existingTypeData -ne $null) {
        $existingTypeData | remove-typedata
    }
}

__clear-typedata $scriptClassTypeName

function add-scriptclass {
    param(
        [parameter(mandatory=$true)] [string] $className,
        [scriptblock] $classBlock
    )

    # Note that serializationdepth=2 is more like an enum than an actual depth -
    # According to docs, it means to serialize children and their children. I
    # do hope it is transitive.
    # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/update-typedata?view=powershell-6
    $classData = @{TypeName=$className;MemberType='NoteProperty';DefaultDisplayPropertySet=@('PSTypeName');MemberName='PSTypeName';Value=$className;serializationdepth=2;serializationmethod='SpecificProperties';PropertySerializationSet=@('PSTypeName')}

    try {
        $classDefinition = __new-class $classData $classBlock
        __add-classmember $className $classDefinition
        __define-class $classDefinition | out-null
        __remove-publishedclass $className
        $:: | add-member -name $className -memberType 'ScriptProperty' -value ([ScriptBlock]::Create("get-class '$className'"))
    } catch {
        __remove-publishedclass $className
        __clear-typedata $className
        __remove-class $className
        throw
    }
}

function new-scriptobject {
    [cmdletbinding()]
    param(
        [parameter(mandatory=$true)] [string] $className,
        [parameter(valuefromremainingarguments=$true)] $argumentlist
    )

    $existingClass = __find-existingClass $className

    $newObject = [PSCustomObject] $existingClass.prototype.psobject.copy()
    __invoke-methodwithcontext $newObject '__initialize' @argumentlist | out-null
    $newObject
}

function get-class([string] $className) {
    $existingClass = __find-existingClass $className
    $existingClass.prototype.scriptclass
}

function test-scriptobject {
    [cmdletbinding()]
    param(
        [parameter(valuefrompipeline=$true, mandatory=$true)] $Object,
        $ScriptClass = $null
    )

    $isClass = $false

    if ( $Object -is [PSCustomObject] ) {
        $objectClassName = try {
            $Object.scriptclass.classname
        } catch {
            $null
        }

        # Does the object's scriptclass object specify a valid type name and does its
        # PSTypeName match?
        $isClass = (__find-existingclass $objectClassName) -ne $null -and $Object.psobject.typenames.contains($objectClassName)

        if ($isClass -and $ScriptClass -ne $null) {
            # Now find the target type if it was specified -- map any string to
            # a class object
            $targetClass = if ( $ScriptClass -is [PSCustomObject] ) {
                $ScriptClass
            } elseif ($ScriptClass -is [string]) {
                get-class $ScriptClass
            } else {
                throw "Class must be specified as type [string] or type [PSCustomObject]"
            }

            # Now see if the type of the object's class matches the target class
            $isClass = $Object.psobject.typenames.contains($targetClass.ClassName)
        }
    }

    $isClass
}

function invoke-method($context, $do) {
    $action = $do
    $result = $null

    if ($context -eq $null) {
        throw "Invalid context -- context may not be `$null"
    }

    $object = $context

    if (! ($context -is [PSCustomObject])) {
        $object = [PSCustomObject] $context

        if (! ($context -is [PSCustomObject])) {
            throw "Specified context is not compatible with [PSCustomObject]"
        }
    }

    if ($action -is [string]) {
        $result = __invoke-methodwithcontext $object $action @args
    } elseif ($action -is [ScriptBlock]) {
        $result = __invoke-scriptwithcontext $object $action @args
    } else {
        throw "Invalid action type '$($action.gettype())'. Either a method name of type [string] or a scriptblock of type [ScriptBlock] must be supplied to 'with'"
    }

    $result
}

function =>($method) {
    if ($method -eq $null) {
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
        $results += (with $_ $method @methodargs)
    }

    if ( $results.length -eq 1) {
        $results[0]
    } else {
        $results
    }
}

function ::> {
    param(
        [parameter(valuefrompipeline=$true)] [string] $classSpec,
        [parameter(position=0)] $method,
        [parameter(valuefromremainingarguments=$true)] $remaining
    )
    [cmdletbinding(positionalbinding=$false)]

    $classObject = get-class $classSpec

    $classObject |=> $method @remaining
}

function __new-class([Hashtable]$classData, [ScriptBlock] $classBlock) {
    $className = $classData['Value']

    # remove existing type data
    __clear-typedata $className

    Update-TypeData -force @classData
    $typeSystemData = get-typedata $classname

    $prototype = [PSCustomObject]@{PSTypeName=$className}
    $classDefinition = @{typedata=$typeSystemData;prototype=$prototype;classblock=$classblock}
    $__classTable[$className] = $classDefinition
    $classDefinition
}

function __find-class($className) {
    $__classTable[$className]
}

function __find-existingClass($className) {
   $existingClass = __find-class $className

    if ($existingClass -eq $null) {
        throw "class '$className' not found"
    }

    $existingClass
}

function __remove-publishedclass($className) {
    try {
        $::.psobject.members.remove($className)
    } catch {
    }
}

function __remove-class($className) {
    $__classTable.Remove($className)
}

function __add-classmember($className, $classDefinition) {
    $classMember = [PSCustomObject] @{
        PSTypeName = $ScriptClassTypeName
        ClassName = $className
        InstanceMethods = @{}
        InstanceProperties = @{}
        TypedMembers = @{}
        ScriptClass = $null
    }

    __add-member $classMember PSTypeData ScriptProperty ([ScriptBlock]::Create("(__find-existingclass '$className').typedata"))
    __add-typemember NoteProperty $className 'ScriptClass' $null $classMember -hidden
}

function __restore-deserializedobjectmethods($object) {
    # Deserialization of ScriptClass object, say from start-job or even a remote session,
    # strips off ScriptMethod and ScriptProperty properties. ScriptProperty properties are
    # evaluated and converted to NoteProperty. ScriptMethod properties are simply
    # omitted. Here we restore ScriptMethod properties from the original class definition.
    # Only methods are restored here -- a separate adjustment is required for
    # the missing ScriptProperty properties.
    $existingClass = __find-existingClass $object.scriptclass.className
    $templateObject = [PSCustomObject] $existingClass.prototype.psobject.copy()
    $object.scriptclass = $existingClass.prototype.scriptclass
    $existingClass.prototype | gm -membertype scriptmethod | foreach {
        write-verbose "Restoring method $($_.name) on class $($object.scriptclass.classname)"
        $object | add-member -name $_.name -memberType 'ScriptMethod' -value $templateObject.psobject.methods[$_.name].script
    }
}

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
            if ($object.scriptclass.instancemethods[$method].gettype().fullname -ne 'System.Management.Automation.ScriptBlock') {
                __restore-deserializedobjectmethods $object
                # Now retry the call -- if the method was restored, this will succeed.
                $methodScript = $object.psobject.members[$method].script
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

    try {
        $variables += get-variable pscmdlet 2>$null
    } catch {
    }

    $functions = @{}
    $objectContext.psobject.members | foreach {
        if ( $_.membertype -eq 'ScriptMethod' ) {
            $functions[$_.name] = $_.value.script
        }
    }
    $result = try {
        # Very strange -- an array of cardinality 1 generates an error when used in the method call to InvokeWithContext, so if there's only one element, convert it back to that one element
        if ($variables.length -eq 1 ) {
            $variables = $variables[0]
        }

        $invokeWrapper = {
            try {
                $__results = . $script @args
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

        $invokeWrapper.InvokeWithContext($functions, $variables, $args)
    } catch {
        write-error $_
        get-pscallstack | write-error
        $_
    }

    if ( $result.succeeded ) {
        $result.result
    } else {
        throw $result.result
    }
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

    $classDefinition = __find-class $className

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

function __get-classmembers($classDefinition) {
    $__functions__ = ls function:
    $__variables__ = @{}

    $__classvariables__ = @{}

    function __initialize {}

    $script:__statics__ = @{}
    $script:__staticvars__ = @{}

    $scope = 0
    $scopevariables = @{}
    $aftervariables = @{}

    # Due to some strange behaivor with dot-sourcing, variables
    # from the dot-sourced script are NOT always importing into scope 0.
    # In fact, they have been observed to import to scope 4!!!
    # Due to this, we need to enumerate ALL scopes before and after
    # sourcing the script and compare the results. We run the risk
    # of including scripts at global or script scope though, and may
    # need to do additional checks to avoid this.
    while ($scope -ge 0) {
        try {
            $scopevariables = get-variable -scope $scope
        } catch {
            $scope = -1
        }

        if ($scope -ge 0) {
            $scopevariables | foreach {
                $__variables__[ $scope, $_.name -join ':' ] = $_
            }
            $scope++
        }
    }

    # Note that variables dot sourced here will not necessarily import at
    # scope 0 as one would think, so we'll need to retrieve all visible scopes
    . $classDefinition | out-null

    # Do NOT create new variables after this step to avoid retrieving them
    # and confusing them with new variables from the class. We'll need to filter out
    # the "_" and "PSItem" automatic variables -- those are never valid class member
    # names anyway.

    $scope = 0
    $scopevariables = @{}
    while ($scope -ge 0) {
        try {
            $scopevariables = get-variable -scope $scope
        } catch {
            $scope = -1
        }

        if ($scope -ge 0) {
            $scopevariables | foreach {
                if ($_.name -ne '_' -and $_.name -ne 'psitem' ) {
                    $aftervariables[ $scope, $_.name -join ':' ] = $_
                }
            }
            $scope++
        }
    }

    $addedVariables = @{}
    $aftervariables.getenumerator() | foreach {
        if (! $__variables__.containskey($_.name)) {
            $varname = $_.value.name
            $varscope = [int32] (($_.name -split ':')[0])
            $existingVariable = $addedVariables[$varname]
            if ($addedVariables[$varname] -eq $null -or $varscope -lt $addedVariables[$varname]) {
                $__classvariables__[$varname] = $_.value
                $addedVariables[$varname] = $varscope
            }
        }
    }

    $__classfunctions__ = @{}
    ls function: | foreach { $__classfunctions__[$_.name] = $_ }
    $__functions__ | foreach {
        if ( $_.scriptblock -eq $__classfunctions__[$_.name].scriptblock) {
            $__classfunctions__.remove($_.name)
        }
    }

    @{functions=$__classfunctions__;variables=$__classvariables__}
}

function strict-val {
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

    [PSCustomObject] @{
        PSTypeName = $StrictTypeCheckingTypename;
        type = $propType;
        value = $value
    }
}

function new-constant {
    param(
        [parameter(mandatory=$true)] $name,
        [parameter(mandatory=$true)] $value
    )

    $existingVariable = try {
        get-variable -name $name -scope 1 2> $null
    } catch {
        $null
    }

    if ( $existingVariable -eq $null ) {
        new-variable -name $name -value $value -scope 1 -option readonly *> (out-null)
    } elseif ($existingVariable.value -ne $value) {
        throw "Attempt to redefine constant '$name' from value '$($existingVariable.value) to '$value'"
    }
}

function __get-classproperties($memberData) {
    $classProperties = @{}

    $memberData.__newvariables__.getenumerator() | foreach {
        if ($classProperties.contains($_.name)) {
            throw "Attempted redefinition of property '$_.name'"
        }

        $propType = $null
        $propValSpec = $_.value.value

        $propVal = if ( $propValSpec -is [PSCustomObject] -and $propValSpec.psobject.typenames.contains($StrictTypeCheckingTypename) ) {
            $propType = $_.value.value.type
            $_.value.value.value
        } else {
            $_.value.value
        }

        $classProperties[$_.name] = @{type=$propType;value=$propVal;variable=$_.value}
    }

    $classProperties
}

function static([ScriptBlock] $staticBlock) {
    function static { throw "The 'static' function may not be used from within a static block" }
    $snapshot1 = ls function:
    $varsnapshot1 = get-variable -scope 0
    . $staticBlock
    $snapshot2 = ls function:
    $varsnapshot2 = get-variable -scope 0
    $delta = @{}
    $varDelta = @{}
    $snapshot2 | foreach { $delta[$_.name] = $_ }
    $snapshot1 | foreach {
        # For any function that exists in both snapshots, only remove if the
        # actual scriptblocks are the same. If they aren't, it just means
        # that a static function was defined with the same name as a non-static function,
        # and that's ok, since the static is essentially defined on the class and not the
        # object
        if ($delta[$_.name].scriptblock -eq $_.scriptblock) {
            $delta.remove($_.name)
        }
    }

    $varsnapshot2 | foreach { $varDelta[$_.name] = $_ }
    $varsnapshot1 | foreach {
        if ($varDelta[$_.name].gethashcode() -eq $_.gethashcode()) {
            $varDelta.remove($_.name)
        }
    }

    $delta.getenumerator() | foreach {
        $statics = $script:__statics__
        $statics[$_.name] = $_.value
    }

    $varDelta.getenumerator() | foreach {
        $staticvars = $script:__staticvars__
        $staticvars[$_.name] = $_.value
    }
}

function modulefunc {
    param($functions, $aliases, $className, $_classDefinition)
    set-strictmode -version 2 # necessary because strictmode gets reset when you execute in a new module

    # Add the functions explicitly at script scope to avoid issues with importing into an interactive shell
    $functions | foreach { new-item "function:script:$($_.name)" -value $_.scriptblock }
    $aliases | foreach { set-alias $_.name $_.resolvedcommandname };
    $__exception__ = $null
    $__newfunctions__ = @{}
    $__newvariables__ = @{}

    try {
        $__classmembers__ = __get-classmembers $_classDefinition
        $__newfunctions__ = $__classmembers__.functions
        $__newvariables__ = $__classmembers__.variables
    } catch {
        $__exception__ = $_
    }

    export-modulemember -variable __memberResult, __newfunctions__, __newvariables__, __exception__ -function $__newfunctions__.keys -verbose:$false
}

$__instanceWrapperTemplate = @'
invoke-method $this $this.scriptclass.instancemethods['{0}'] @args
'@

function __define-class($classDefinition) {
    $aliases = @((get-item alias:with), (get-item 'alias:new-so'), (get-item alias:const))
    pushd function:
    $functions = ls invoke-method, '=>', new-scriptobject, new-constant, __invoke-methodwithcontext, __invoke-scriptwithcontext, __get-classmembers, static
    popd

    $memberData = $null
    $classDefinitionException = $null

    try {
        $memberData = new-module -ascustomobject -scriptblock (gi function:modulefunc).scriptblock -argumentlist $functions, $aliases, $classDefinition.typeData.TypeName, $classDefinition.classBlock
        $classDefinitionException = $memberData.__exception__
    } catch {
        $classDefinitionException = $_
    }

    if ($classDefinitionException -ne $null) {
        $badClassData = get-typedata $classDefinition.typeData.TypeName
        $badClassData | remove-typedata
        throw $classDefinitionException
    }

    $classProperties = __get-classproperties $memberData

    $classProperties.getenumerator() | foreach {
        __add-typemember NoteProperty $classDefinition.typeData.TypeName $_.name $_.value.type $_.value.value ($_.value.variable.options -eq 'readonly')
    }

    $nextFunctions = $memberData.__newfunctions__

    $nextFunctions.getenumerator() | foreach {
        if ($nextFunctions[$_.name] -is [System.Management.Automation.FunctionInfo] -and $functions -notcontains $_.name) {
            $methodBlockWrapper = [ScriptBlock]::Create($__instanceWrapperTemplate -f $_.name)
            __add-typemember ScriptMethod $classDefinition.typeData.TypeName $_.name $null $methodBlockWrapper
            $classDefinition.prototype.scriptclass.InstanceMethods[$_.name] = $_.value.scriptblock
        }
    }

    $script:__statics__.getenumerator() | foreach {
        __add-member $classDefinition.prototype.scriptclass $_.name ScriptMethod $_.value.scriptblock
    }

    $script:__staticvars__.getenumerator() | foreach {
        if ( $_.value.value -is [PSCustomObject] -and $_.value.value.psobject.typenames.contains($StrictTypeCheckingTypename) ) {
            __add-scriptpropertytyped $classDefinition.prototype.scriptclass $_.name $_.value.value.type $_.value.value.value
        } else {
            __add-member $classDefinition.prototype.scriptclass $_.name NoteProperty $_.value.value
        }
    }

}


