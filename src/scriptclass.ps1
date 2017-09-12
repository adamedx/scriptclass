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

function invoke-methodwithcontext($method) {
    $methodScript = $method.object.psobject.members[$method.methodName].script
    invoke-scriptwithcontext $methodScript $method.object @args
}

function invoke-scriptwithcontext($script, $objectContext) {
    $thisVariable = [PSVariable]::new('this', $objectContext)
    $functions = @{}
    $objectContext.psobject.members | foreach {
        if ( $_.membertype -eq 'ScriptMethod' ) {
            $functions[$_.name] = $_.value.script
        }
    }
    $script.invokeWithContext($functions, $thisVariable, $args)
}

function add-scriptclass {
    param(
        [parameter(mandatory=$true)] [string] $className,
        [scriptblock] $classBlock
    )

    $classData = @{TypeName=$className;MemberType='NoteProperty';DefaultDisplayPropertySet=@('PSTypeName');MemberName='PSTypeName';Value=$className}
    try {
        $classInfo = __new-class $classData
        __add-typemember NoteProperty $className ScriptBlock $null $classBlock
        __define-class $classInfo | out-null
    } catch {
        $typeData = get-typeData $className

        if ($typeData -ne $null) {
            $typeData | remove-typedata
        }

        __remove-class $className

        throw $_.exception
    }
}

function get-scriptclass {
   param(
       [parameter(mandatory=$true)] [string] $className
   )

    $existingClass = __find-existingClass $className

    $existingClass.typeData
}

function new-scriptclassinstance {
    param(
        [string] $className)

    $existingClass = __find-existingClass $className

    $existingTypeData = get-typedata $className

    $newObject = $existingClass.prototype.psobject.copy()

    (invoke-methodwithcontext @{object=$newObject;methodName='__initialize'} @args) | out-null
    $newObject
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

function __new-class([Hashtable]$classData) {
    $className = $classData['Value']

    if ((__find-class $className) -ne $null) {

        throw "class '$className' already has a definition"
    }

    # remove existing type data
    $typeData = get-typedata $className

    if ($typeData -ne $null) {
        $typeData | remove-typedata
    }

    Update-TypeData -force @classData
    $typeSystemData = get-typedata $classname

    $prototype = [PSCustomObject]@{PSTypeName=$className}
    $classInfo = @{typedata=$typeSystemData;initialized=$false;prototype=$prototype}
    $__classTable[$className] = $classInfo
    $classInfo
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

    $classData = __find-class $className

    $memberExists = $classData.typedata.members.keys -contains $memberName

    if ($memberName -eq $null ) {
        throw 'A $null member name was specified'
    }

    if ($memberExists) {
        throw "Member '$memberName' already exists for type '$className'"
    }

    $defaultDisplay = @(0..$classData.typedata.members.keys.count)

    $defaultDisplay[$classData.typedata.members.keys.count - 1] = $memberName
    $aliasName = "__$($memberName)"
    $realName = $memberName
    if ($typeName -ne $null) {
        $realName = $aliasName
        $aliasName = $memberName
    }

    $nameTypeData = @{TypeName=$className;MemberType=$memberType;MemberName=$realName;Value=$initialValue;defaultdisplaypropertyset=$defaultdisplay}

    __add-member $classData.prototype $realName $memberType $initialValue $typeName
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

    $classData.typeData = $typeSystemData
}

set-alias ScriptClass add-scriptclass

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

function __define-class($classData) {
    $typeName = $classData.typedata.TypeName

    if ($classData.initialized) {
        throw "Attempt to redefine class '$typeName'"
    }

    function __property ($arg1, $arg2 = $null) {
        $propertyType = $null
        $propertySpec = $arg2
        $propertyName = $null
        if ( $arg2 -eq $null ) {
            $propertySpec = $arg1
        } elseif ( $arg1 -match '\[\w+\]') {
            $propertyType = iex $arg1
        } else {
            throw "Specified type '$arg1' was not of the form '[typename]'"
        }

        $propertyValue = $null
        if ($propertySpec -is [Array]) {
            if ($propertySpec.length -gt 2) {
                throw "Specified property initializer for property '$($propertySpec[0])' was given $($ppropertySpec.length) values when only one is allowed"
            }
            $propertyName = $propertySpec[0]
            if ($propertySpec.length -gt 1) {
                $propertyValue = $propertySpec[1]
            }
        } else {
            $propertyName = $propertySpec
        }

        __add-typemember NoteProperty $classData.typeData.TypeName $propertyName $propertyType $propertyValue
    }

    $classData.initialized = $true
    function __initialize {}
    $initialFunctions = ls function:*
    try {
        . $classData.typedata.members.ScriptBlock.value | out-null
    } catch {
        $badClassData = get-typedata $typeName
        $badClassData | remove-typedata
        throw $_.Exception
    }

    $nextFunctions = ls function:*

    $additionalFunctions = @()

    $allowedInternalFunctions = @('__initialize')
    $nextFunctions | foreach {
        if ( $allowedInternalFunctions -contains $_ -or $initialFunctions -notcontains $_) {
            __add-typemember ScriptMethod $classData.typeData.TypeName $_.Name $null $_.scriptblock
        }
    }
}

function with($context = $null, $do) {
    $action = $do
    $result = $null

    if ($context -eq $null) {
        throw "Invalid context -- context may not be $null"
    }

    $object = $context

    if (! ($context -is [PSCustomObject])) {
        $object = [PSCustomObject] $context

        if (! ($context -is [PSCustomObject])) {
            throw "Specified context is not compatible with [PSCustomObject]"
        }
    }

    if ($action -is [string]) {
        $result = __invoke-method $object $action @args
    } elseif ($action -is [ScriptBlock]) {
        $result = invoke-scriptwithcontext $action $object @args
    } else {
        throw "Invalid action type '$($action.gettype())'. Either a method name of type [string] or a scriptblock of type [ScriptBlock] must be supplied to 'with'"
    }

    $result
}

function __invoke-method($object, $method) {
    invoke-methodwithcontext @{object=$object;methodName=$method} @args
}
