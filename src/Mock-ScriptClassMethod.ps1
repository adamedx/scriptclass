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

function Mock-ScriptClassMethod {
    [cmdletbinding(positionalbinding=$false)]
    param(
        [parameter(position=0, mandatory=$true)]
        $MockTarget,

        [parameter(position=1, mandatory=$true)]
        [String] $MethodName,

        [parameter(position=2)]
        [ScriptBlock] $MockWith = {},

        [parameter(position=3)]
        [ScriptBlock] $ParameterFilter,

        [parameter(parametersetname='static')]
        [Switch] $Static,

        [Switch] $Verifiable
    )

    $ScriptObject = $null
    $ClassName = $MockTarget

    if ( $MockTarget -is [PSCustomObject] ) {
        if ( $Static.IsPresent ) {
            throw [ArgumentException]::new("Argument 'Static' may not be specified when the type of argument 'MockTarget' is [PSCustomObject]. Specify a ScriptClass class name of type [String] for 'MockTarget' to use 'Static'")
        }

        $ScriptObject = $MockTarget
        $ClassName = $MockTarget.PSTypeName
    } elseif ( $MockTarget -isnot [String] ) {
        throw [ArgumentException]::new("Argument 'MockTarget' of type '$($MockTarget.gettype())' is not of valid type [String] or [PSCustomObject]")
    }

    $normalizedParameterFilter = if ( $ParameterFilter ) {
        $ParameterFilter
    } else {
        { $true }
    }

    $frameworkArguments = @{
        MockWith = $MockWith
        ParameterFilter = $normalizedParameterFilter
        Verifiable = $Verifiable
    }

    $methodFunctionToMock = __GetPatchedMethodFunction $ClassName $MethodName $frameworkArguments $Static.IsPresent $ScriptObject

    __MockMethodFunction $methodFunctionToMock $frameworkArguments $ScriptObject $MethodName ($ParameterFilter -ne $null)
}

$__MockedScriptClassMethods = @{}
$__MockedObjectMethods = @{}

function __GetPatchedMethodFunction(
    $className,
    $methodName,
    $frameworkArguments,
    $isStatic,
    $object
) {
    $mockableFunction = __GetMockableMethodFunction $className $methodName $isStatic $object

    if ( $object ) {
        __PatchSingleInstanceMethod $mockableFunction
    } elseif ( $isStatic ) {
        __PatchStaticMethod $mockableFunction
    } else {
        __PatchAllInstancesMethod $mockableFunction
    }

    $mockableFunction.FunctionName
}

$__mockedObjectSerialStart = $null
$__mockedObjectSerial = $null

function __AllocateUniqueId {
    if ( $script:__mockedObjectSerial -eq $null ) {
        $random = [Random]::new()
        # The next method returns a positive signed [int32]
        $idStart = [uint64] $random.next()
        $idStart += [uint64] $random.next()
        $idStart *= [uint64] ([int32]::MaxValue)
        $idStart += [uint64] $random.next()
        $idStart += [uint64] $random.next()

        $script:__mockedObjectSerialStart = $idStart
        $script:__mockedObjectSerial = $idStart
    } elseif ( $script:__mockedObjectSerial -eq $script:__mockedobjectSerialStart ) {
        throw 'Maximum mock object count exceeded'
    }

    $nextId = if ( $script:__mockedObjectSerial -eq [uint64]::MaxValue ) {
        0
    } else {
        $script:__mockedObjectSerial + [uint64] 1
    }

    $script:__mockedObjectSerial = $nextId
    $nextId
}

function __GetMockedObjectUniqueId([PSCustomObject] $object) {
    if ( ! $object ) {
        throw 'The specified object was $null'
    }

    if ( ! ( test-scriptobject $object ) ) {
        throw 'The specified object was not a ScriptClass object'
    }

    $objectUniqueId = if ( $object | gm -membertype scriptmethod __ScriptClassMockedObjectId -erroraction ignore) {
        $object.__ScriptClassMockedObjectId()
    }

    if ( ! $objectUniqueId ) {
        $objectUniqueId = __AllocateUniqueId

        $object | add-member -name __ScriptClassMockedObjectId -membertype scriptmethod -value ([ScriptBlock]::Create("[uint64] $($objectUniqueId.tostring())")) -force
    }

    $objectUniqueId
}

function __MockMethodFunction($methodFunctionName, $frameworkArguments, $object, $methodName, $hasParameterFilter) {
    if ( $object ) {
        $objectId = __GetMockedObjectUniqueId $object

        $objectEntry = if ( ! $script:__MockedObjectMethods[$objectId] ) {
            $newEntry = @{
                Object=$object
                MockWith = $frameworkArguments.MockWith
                FunctionName = $methodFunctionName
            }
            $script:__MockedObjectMethods.Add($objectId, $newEntry)
            $newEntry
        }

        $methodInfo = $script:__MockedScriptClassMethods[$methodFunctionName]
        $methodInfo.MockedObjects[$objectId] = $objectEntry
    }

    Mock $methodFunctionName @frameworkArguments
}

function __PatchStaticMethod($mockFunctionInfo) {
    __SetObjectMethod $mockFunctionInfo.classData.prototype.scriptclass $mockFunctionInfo.methodname $mockFunctionInfo.ReplacementScriptblock
}

function __PatchAllInstancesMethod($mockFunctionInfo) {
    $mockFunctionInfo.classData.instanceMethods[$mockFunctionInfo.methodName] = $mockFunctionInfo.ReplacementScriptBlock
}

function __PatchSingleInstanceMethod($mockFunctionInfo) {
    __PatchAllInstancesMethod $mockFunctionInfo
}

function __SetObjectMethod($object, $methodname, $originalScriptBlock) {
    $object | add-member -name $methodname -membertype scriptmethod -value $originalScriptblock -force
}

function __GetMockableMethodName(
    $className,
    $methodName,
    $isStatic,
    $object
) {
    $methodType = if ( $isStatic ) {
        'static'
    } else {
        'allinstances'
    }

    "___MockScriptClassMethod_$($methodType)_$($classname)_$($methodName)__"
}

$__mockInstanceMethodTemplate = @'
set-strictmode -version 2
write-host 'called stub method'
$__filterpass = $null
$__objectMockScriptBlock = if ( $this | gm __ScriptClassMockedObjectId -erroraction ignore ) {{
    $__objectFilterId = $this.__ScriptClassMockedObjectId()
    $__filterpass = $__objectFilterId
    if ( $__objectFilterId ) {{
        $script:__MockedObjectMethods[$__objectFilterId].MockWith
    }}
}}

if ( $__objectMockScriptBlock ) {{
write-host -fore yellow 'Found matching object', $__filterpass
    $__result = . $__objectMockScriptBlock @args
    return $__result
}} else {{
    $__MethodInfo = $script:__MockedScriptClassMethods['{0}']
    if ( ! $__MethodInfo -or ! $__MethodInfo.AllInstances ) {{
        write-host 'calling original method'
        $__result = . $__MethodInfo.OriginalScriptBlock @args
        return $__result
    }}
}}
write-host -fore yellow 'calling base method'
{0} @args
'@

$__mockStaticMethodTemplate = @'
{0} @args
'@

function __GetMockableMethodFunction(
    $className,
    $methodName,
    $isStatic,
    $object
) {
    $functionName = __GetMockableMethodName $className $methodName $isStatic $object

    $existingPatchMethod = $script:__MockedScriptClassMethods[$functionName]

    if ( $existingPatchMethod ) {
        $existingPatchMethod
    } else {
        get-class $className | out-null

        $originalMethodBlock = __GetClassMethod $className $methodName $isStatic $object

        $replacementMethodBlock = if ( $isStatic ) {
            [ScriptBlock]::Create($script:__mockStaticMethodTemplate -f $functionName)
        } else {
            [ScriptBlock]::Create($script:__mockInstanceMethodTemplate -f $functionName)
        }

        new-item "function:script:$($functionName)" -value $originalMethodBlock -force | out-null

        if ( $isStatic -and $object ) {
            throw 'what'
        }
        $mockRecord = @{
            FunctionName = $functionName
            ClassName = $className
            MethodName = $methodName
            IsStatic = $isStatic
            ClassData = $__classTable[$className]
            AllInstances = ($object -eq $null)
            MockedObjects = @{}
            OriginalScriptBlock = $originalMethodBlock
            ReplacementScriptBlock = $replacementMethodBlock
        }

        $script:__MockedScriptClassMethods[$functionName] = $mockRecord
        $mockRecord
    }
}

function __GetClassMethod($className, $methodName, $isStatic, $object) {
    $methodBlock = if ( $isStatic ) {
        $__classTable[$className].prototype.scriptclass.psobject.methods[$methodName].script
    } else {
        $__classTable[$className].instancemethods[$methodName]
    }

    if ( ! $methodBlock ) {
        throw "Method '$methodName', static='$isStatic', was not found for class '$className'"
    }

    $methodBlock
}

function Remove-ScriptClassMethodMock {
    [cmdletbinding(positionalbinding=$false)]
    param(
        [parameter(parametersetname='object', mandatory=$true)]
        [PSCustomObject] $Object,

        [parameter(parametersetname='class', position=0, mandatory=$true)]
        [string] $ClassName,

        [parameter(parametersetname='class', position=1)]
        [parameter(parametersetname='object', position=0)]
        [string] $MethodName,

        [parameter(parametersetname='class')]
        [switch] $Static,

        [parameter(parametersetname='all', mandatory=$true)]
        [switch] $All
    )
    write-host -fore cyan "remove", $classname, $methodname, ($object -ne $null), $static

    $targetMethods = if ( $All.IsPresent ) {
        $script:__MockedScriptClassMethods.values | foreach { $_ }
    } else {
        __GetPatchedMethods $ClassName $MethodName $Static $Object
    }

    $targetMethods | foreach {
        __RemoveMockedMethod $_ $Object
        if ( ! $_.AllInstances -and $_.MockedObjects.Count -eq 0 ) {
            write-host -fore cyan 'removing all instances'
            gi "function:$($_.functionname)" | rm
            $script:__MockedScriptClassMethods.Remove($_.functionname)
        } else {
            write-host -fore cyan 'Skipping remove', $_.AllInstances, $_.MockedObjects.Count
        }
    }
}

function __GetPatchedMethods($className, $method, $staticMethods, $object) {
    $methodClass = $className
    $methodNames = if ( $method ) {
        @($method)
    } else {
        $classData = if ( $ClassName ) {
            $__classTable[$className]
        } else {
            $__classTable[$object.scriptclass.classname]
        }

        $methodClass = $classData.prototype.pstypename

        if ( $staticMethods ) {
            $__classTable[$className].prototype.scriptclass.psobject.methods | select -expandproperty name
        } else {
            $classData.instancemethods.keys
        }
    }

    if ( $object ) {
        $methodClass = $object.scriptclass.classname
    }

    $mockRecords = $methodNames | foreach {
        __GetMockableMethodFunction $methodClass $_ $staticMethods $object
    }

    $mockRecords
}

function __RemoveMockedMethod($mockedFunctionInfo, $object) {
    if ( $object ) {
        __UnpatchSingleInstanceMethod $mockedFunctionInfo $object
    } elseif ( $mockedFunctionInfo.IsStatic ) {
        __UnpatchStaticMethod $mockedFunctionInfo
    } else {
        __UnpatchAllInstancesMethod $mockedFunctionInfo
    }
}

function __UnpatchAllInstancesMethod($mockedFunctionInfo) {
    $mockedFunctionInfo.AllInstances = $false
    if ( $mockedFunctionInfo.MockedObjects.count -eq 0 ) {
        $mockedFunctionInfo.classData.instanceMethods[$mockedFunctionInfo.methodName] = $mockedFunctionInfo.OriginalScriptBlock
    }
}

function __UnpatchSingleInstanceMethod($mockedFunctionInfo, $object) {
    $objectId = try {
        $object.__ScriptClassMockedObjectId()
    } catch {
    }

    if ( ! $objectId ) {
        throw [ArgumentException]::new("The specified object was never mocked")
    }

    $currentlyObject = $script:__mockedObjectMethods[$objectId]

    if ( ! $currentlyObject ) {
        throw [ArgumentException]::new("The specified object is not currently mocked")
    }

    if ( $mockedFunctionInfo.MockedObjects.Count -eq 0 ) {
        throw [ArgumentException]::new("There are no mocked objects for the method '$($mockedFunctionInfo.methodName)'")
    }

    write-host "Reducing instance from", $mockedFunctionInfo.MockedObjects.Count
    $mockedFunctionInfo.MockedObjects.Remove($objectId)
    if ( ! $mockedFunctionInfo.AllInstances -and $mockedFunctionInfo.MockedObjects.Count -eq 0 ) {
        $mockedFunctionInfo.classData.instanceMethods[$mockedFunctionInfo.methodName] = $mockedFunctionInfo.OriginalScriptBlock
    }

    write-host -fore magenta 'fixing up object', $objectId
    $script:__mockedObjectMethods.Remove($objectId)
    $object | add-member -name __ScriptClassMockedObjectId -membertype scriptmethod -value {} -force
    $myval = $object.__ScriptClassMockedObjectId()
    write-host -fore cyan $myval, ($myval -eq $null)
}

function __UnpatchStaticMethod($mockedFunction) {
    __SetObjectMethod $mockedFunction.classData.prototype.scriptclass $mockedFunctionInfo.methodname $mockedFunctionInfo.originalScriptblock
}
