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

function invoke-method($method) {
    $thisVariable = [PSVariable]::new('this', $method.object)
    $methodScript = $method.object.psobject.members[$method.methodName].script
    $methodScript.invokeWithContext(@{}, $thisVariable, $args)
}

set-alias call invoke-method

function add-class {
    param(
        [parameter(mandatory=$true)] [string] $className,
        [scriptblock] $classBlock
    )

    $classData = @{TypeName=$className;MemberType='NoteProperty';DefaultDisplayPropertySet=@('PSTypeName');MemberName='PSTypeName';Value=$className}
    try {
        __add-class $classData
        __add-typemember NoteProperty $className ScriptBlock $null $classBlock
        $classInformation = __find-class $className
        __add-classDefinitionFunction $classInformation $classBlock
    } catch {
        $typeData = get-typeData $className

        if ($typeData -ne $null) {
            $typeData | remove-typedata
        }

        throw $_.exception
    }
}

function get-class {
   param(
       [parameter(mandatory=$true)] [string] $className
   )

    $existingClass = __find-existingClass $className

    $existingClass.typeData
}

function new-instance {
    param(
        [string] $className)

    $existingClass = __find-existingClass $className

    $existingTypeData = get-typedata $className

    $newObject = $existingClass.prototype.psobject.copy()
    (invoke-method @{object=$newObject;methodName='__initialize'} @args) | out-null
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

function __add-class([Hashtable]$classData) {
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
    $__classTable[$className] = @{members=@{PSTypeName=$className};typedata=$typeSystemData;initialized=$false;prototype=$prototype}
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

    $memberExists = $classData.members.keys -contains $memberName

    if ($memberName -eq $null ) {
        throw 'A $null member name was specified'
    }

    if ($memberExists) {
        throw "Member '$memberName' already exists for type '$className'"
    }

    $defaultDisplay = @(0..$classData.members.keys.count)
    $classData.members.keys.copyto($defaultDisplay, 0)

    $defaultDisplay[$classData.members.keys.count] = $memberName
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

    $classData.members[$realName] = $initialValue
    $classData.typeData = $typeSystemData
}

function __create-newclass([string] $className, [scriptblock] $scriptBlock) {
    add-class $className $scriptBlock
    $classData = __find-class $className
    (. $classData['classDefinitionFunction'].scriptblock) | out-null
}

set-alias __class __create-newclass

function __add-classDefinitionFunction($classData) {
    if ( $classData['classDefinitionFunction'] -ne $null ) {
        throw "Attempt to set a class function for class '$($classData.TypeData.TypeName)' which already has a class function"
    }

    $classData['classDefinitionFunction'] = new-item "function:script:$($classData.TypeData.TypeName)" -value (__classDefinitionFunctionBlock $classData.TypeData)
}

function __classDefinitionFunctionBlock($classData) {
    $__typeName = $classData.TypeName
    $outputblock = {

        $__this =$null
        $method = $null

        $__thisClass = __find-class $__typeName
        $methodPresent = ($method -ne $null) -and ($method.length -gt 0)

        if ($__this -eq $null -and ! $methodpresent) {

            if ($__thisClass.initialized) {
                throw "Attempt to redefine class '$__typeName'"
            }
        } else {
            throw "Not yet implemented"
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

            __add-typemember NoteProperty $__thisClass.typeData.TypeName $propertyName $propertyType $propertyValue
        }
        function __initialize {}

        $__thisClass.initialized = $true

        $initialFunctions = ls function:*
        $result = try {
            . $__thisClass.typedata.members.ScriptBlock.value
        } catch {
            $badClassData = get-typedata $__typeName
            $badClassData | remove-typedata
            throw $_.Exception
        }
        $nextFunctions = ls function:*

        $additionalFunctions = @()
        $allowedInternalFunctions = @('__initialize')
        $nextFunctions | foreach {

            if ($allowedInternalFunctions -contains $_) {
                __add-typemember ScriptMethod $__thisClass.typeData.TypeName $_.Name $null $_.scriptblock
            } elseif ($initialFunctions -notcontains $_) {
                $additionalFunctions += $_
            }
        }

        $additionalFunctions | foreach {
            $realMethod = "_$($_.Name)"
            __add-typemember ScriptMethod $__thisClass.typeData.TypeName $realMethod $null $_.scriptblock
            __add-typemember ScriptProperty $__thisClass.typeData.TypeName $_.Name $null ([ScriptBlock]::Create("@{object=`$this;methodName='$realMethod'}"))

        }

        $result
    }

    $blockString = $outputblock.tostring()
    $newstring = $blockstring.replace('$__typeName',$__typeName)
    [ScriptBlock]::Create($newString)
}

