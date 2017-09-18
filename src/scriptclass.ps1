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

$__classTable = @{}

set-alias ScriptClass add-scriptclass
set-alias with invoke-withcontext

function add-scriptclass {
    param(
        [parameter(mandatory=$true)] [string] $className,
        [scriptblock] $classBlock
    )

    $classData = @{TypeName=$className;MemberType='NoteProperty';DefaultDisplayPropertySet=@('PSTypeName');MemberName='PSTypeName';Value=$className}

    try {
        $classDefinition = __new-class $classData
        __add-typemember NoteProperty $className ScriptBlock $null $classBlock
        __define-class $classDefinition | out-null
    } catch {
        __clear-typedata $className
        __remove-class $className

        throw $_
    }
}

function new-scriptobject {
    param(
        [string] $className
    )

    $existingClass = __find-existingClass $className

    $newObject = $existingClass.prototype.psobject.copy()

    __invoke-methodwithcontext $newObject '__initialize' @args | out-null
    $newObject
}

function get-scriptclasstypedata {
    param(
        [parameter(mandatory=$true)] [string] $className
    )

    $existingClass = __find-existingClass $className

    $existingClass.typeData
}

function invoke-withcontext($context = $null, $do) {
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

new-variable -name StrictTypeCheckingTypename -value '__scriptclass_strict_value__' -Option Constant

function __new-class([Hashtable]$classData) {
    $className = $classData['Value']

    # remove existing type data
    __clear-typedata $className

    Update-TypeData -force @classData
    $typeSystemData = get-typedata $classname

    $prototype = [PSCustomObject]@{PSTypeName=$className}
    $classDefinition = @{typedata=$typeSystemData;initialized=$false;prototype=$prototype}
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

function __remove-class($className) {
    $__classTable.Remove($className)
}

function __invoke-methodwithcontext($object, $method) {
    $methodScript = try {
        $object.psobject.members[$method].script
    } catch {
        throw $_
    }
    __invoke-scriptwithcontext $object $methodScript @args
}

function __clear-typedata($className) {
    $existingTypeData = get-typedata $className

    if ($existingTypeData -ne $null) {
        $existingTypeData | remove-typedata
    }
}

function __invoke-scriptwithcontext($objectContext, $script) {
    $thisVariable = [PSVariable]::new('this', $objectContext)
    $functions = @{}
    $objectContext.psobject.members | foreach {
        if ( $_.membertype -eq 'ScriptMethod' ) {
            $functions[$_.name] = $_.value.script
        }
    }
    $script.invokeWithContext($functions, $thisVariable, $args)
}

function __add-member($prototype, $memberName, $psMemberType, $memberValue, $memberType = $null, $memberSecondValue = $null, $force = $false) {
    $arguments = @{name=$memberName;memberType=$psMemberType;value=$memberValue}
    if ($memberType -ne $null) {
        $arguments['typeName'] = $memberType
    }

    if ($memberSecondValue -ne $null) {
        $arguments['secondValue'] = $memberSecondValue
    }

    $newMember = ($prototype | add-member -passthru @arguments)
}

function __add-typemember($memberType, $className, $memberName, $typeName, $initialValue) {
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

    $defaultDisplay = @(0..$classDefinition.typedata.members.keys.count)

    $defaultDisplay[$classDefinition.typedata.members.keys.count - 1] = $memberName
    $aliasName = "__$($memberName)"
    $realName = $memberName
    if ($typeName -ne $null) {
        $realName = $aliasName
        $aliasName = $memberName
    }

    $nameTypeData = @{TypeName=$className;MemberType=$memberType;MemberName=$realName;Value=$initialValue;defaultdisplaypropertyset=$defaultdisplay}

    __add-member $classDefinition.prototype $realName $memberType $initialValue $typeName
    Update-TypeData -force @nameTypeData

    if ($typeName -ne $null) {
        # Check to make sure any initializer is compatible with the declared type
        if ($initialValue -ne $null) {

            $evalString = "param(`[$typeName] `$value)"
            $evalBlock = [ScriptBlock]::Create($evalString)
            (. $evalBlock $initialValue) | out-null
        }
        $getBlock = [ScriptBlock]::Create("[$typeName] `$this.$realName")
        $setBlock = [Scriptblock]::Create("param(`$val) `$this.$realName = [$typeName] `$val")
        $aliasTypeData = @{TypeName=$className;MemberType='ScriptProperty';MemberName=$aliasName;Value=$getBlock;SecondValue=$setBlock}
        Update-TypeData -force @aliasTypeData
    }

    $typeSystemData = get-typedata $className

    $classDefinition.typeData = $typeSystemData
}

function __get-classmembers($classDefinition) {
    $__functions__ = ls function:
    $__variables__ = get-variable -scope 0 # must restrict to this scope or we see variables outside the module
    $__classvariables__ = @{}

    function __initialize {}

    . $classDefinition | out-null

    get-variable -scope 0 | foreach { $__classvariables__[$_.name] = $_ }
    $__variables__ | foreach { $__classvariables__.remove($_.name) }

    $__classfunctions__ = @{}
    ls function: | foreach { $__classfunctions__[$_.name] = $_ }
    $__functions__ | foreach { $__classfunctions__.remove($_.name) }

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

        $classProperties[$_.name] = @{type=$propType;value=$propVal}
    }

    $classProperties
}

function modulefunc {
    param($functions, $aliases, $className, $_classDefinition)
    set-strictmode -version 2 # necessary because strictmode gets reset when you execute in a new module
    $functions | foreach { new-item "function:$($_.name)" -value $_.scriptblock }
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

    export-modulemember -variable __memberResult, __newfunctions__, __newvariables__, __exception__ -function $__newfunctions__.keys
}

function __define-class($classDefinition) {
    $aliases = @(get-item alias:with)
    pushd function:
    $functions = ls invoke-withcontext, '=>', __invoke-methodwithcontext, __invoke-scriptwithcontext, __get-classmembers
    popd

    $memberData = $null
    $classDefinitionException = $null

    try {
        $memberData = new-module -ascustomobject -scriptblock (gi function:modulefunc).scriptblock -argumentlist $functions, $aliases, $classDefinition.typeData.TypeName, $classDefinition.typedata.members.ScriptBlock.value
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
        __add-typemember NoteProperty $classDefinition.typeData.TypeName $_.name $_.value.type $_.value.value
    }

    $nextFunctions = $memberData.__newfunctions__

    $nextFunctions.getenumerator() | foreach {
        if ($nextFunctions[$_.name] -is [System.Management.Automation.FunctionInfo] -and $functions -notcontains $_.name) {
            __add-typemember ScriptMethod $classDefinition.typeData.TypeName $_.name $null $_.value.scriptblock
        }
    }
}


