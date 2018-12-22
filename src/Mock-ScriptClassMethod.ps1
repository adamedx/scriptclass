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
        [String] $ClassName,

        [parameter(position=1, mandatory=$true)]
        [String] $MethodName,

        [parameter(position=2, mandatory=$true)]
        [ScriptBlock] $MockWith,

        [parameter(position=3)]
        [ScriptBlock] $ParameterFilter,

        [parameter(parametersetname='object')]
        [PSCustomObject] $ScriptObject,

        [parameter(parametersetname='static', mandatory=$true)]
        [Switch] $Static,

        [Switch] $Verifiable
    )

    $frameworkArguments = @{
        MockWith = $MockWith
        Verifiable = $Verifiable
    }

    if ( $ParameterFilter ) {
        $frameworkArguments['ParameterFilter'] = $ParameterFilter
    }

    $methodFunctionToMock = __GetPatchedMethodFunction $ClassName $MethodName $frameworkArguments $Static.IsPresent $ScriptObject

    __MockMethodFunction $methodFunctionToMock $frameworkArguments
}

$__MockedScriptClassMethods = @{}

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

function __MockMethodFunction($methodFunctionName, $frameworkArguments) {
    Mock $methodFunctionName @frameworkArguments
}

function __PatchStaticMethod($mockFunctionInfo) {
#    $classObject = $__classTable['GraphContext'].prototype.scriptclass.psobject.methods[$mockFunctionInfo.className]
#    $classObject = $__classTable['GraphContext'].prototype.scriptclass
    $mockFunctionInfo.classData.prototype.scriptclass | add-member -name $mockFunctionInfo.methodname -membertype scriptmethod -value $mockFunctionInfo.ReplacementScriptblock -force
 #   $classObject | add-member -name $mockFunctionInfo.methodname -membertype scriptmethod -value $mockFunctionInfo.ReplacementScriptblock -force
#    throw [NotImplementedException]("Static method mocking is not yet implemented")
}

function __PatchAllInstancesMethod($mockFunctionInfo) {
    $mockFunctionInfo.classData.instanceMethods[$mockFunctionInfo.methodName] = $mockFunctionInfo.ReplacementScriptBlock
}

function __PatchSingleInstanceMethod($mockFunctionInfo) {
        throw [NotImplementedException]("Specific object method mocking is not yet implemented")
}

function __GetMockableMethodName(
    $className,
    $methodName,
    $isStatic,
    $object
) {
    $methodType = if ( $isStatic ) {
        'static'
    } elseif ( ! $Object )  {
        'allinstances'
    } else {
        "object_$($object.getscriptobjecthashcode())"
    }

    "___MockScriptClassMethod_$($methodType)_$($classname)_$($methodName)__"
}

$__mockInstanceMethodTemplate = @'
{0} $this {1} @args
'@

function __GetMockableMethodFunction(
    $className,
    $methodName,
    $isStatic,
    $object
) {
    $functionName = __GetMockableMethodName $className $methodName $isStatic $object

    $existingPatchMethod = $__MockedScriptClassMethods[$functionName]

    if ( $existingPatchMethod ) {
        $existingPatchMethod
    } else {
        get-class $className | out-null

        $originalMethodBlock = __GetClassMethod $className $methodName $isStatic $object

        $replacementMethodBlock = [ScriptBlock]::Create($__mockInstanceMethodTemplate -f ($functionName, $methodName))

        new-item "function:script:$($functionName)" -value $originalMethodBlock -force | out-null

        $mockRecord = @{
            FunctionName = $functionName
            ClassName = $className
            MethodName = $methodName
            IsStatic = $isStatic
            ClassData = $__classTable[$className]
            MockedObject = $object
            OriginalScriptBlock = $originalMethodBlock
            ReplacementScriptBlock = $replacementMethodBlock
        }

        $__MockedScriptClassMethods[$functionName] = $mockRecord
        $mockRecord
    }
}

function __GetClassMethod($className, $methodName, $isStatic, $object) {
    $methodBlock = if ( $isStatic ) {
        $__classTable[$className].prototype.scriptclass.psobject.methods[$methodName].script
#        ($:: | select -expandproperty $className).psobject.methods[$methodName].script
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
        [string] $MethodName,

        [parameter(parametersetname='class')]
        [switch] $Static,

        [parameter(parametersetname='all', mandatory=$true)]
        [switch] $All
    )

    $targetMethods = if ( $All.IsPresent ) {
        $__MockedScriptClassMethods.values | foreach { $_ }
    } else {
        __GetPatchedMethods $ClassName $MethodName $Static $Object
    }

    $targetMethods | foreach {
        __RemoveMockedMethod $_
        gi "function:$($_.functionname)" | rm
        $__MockedScriptClassMethods.Remove($_.functionname)
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
            $object.scriptclass
        }

        $methodClass = $classData.prototype.pstypename

        if ( $staticMethods ) {
            $__classTable[$className].prototype.scriptclass.psobject.methods | select -expandproperty name
#            ($:: | select -expandproperty $methodClass).psobject.methods | select -expandproperty name
#            $classData.prototype.scriptclass | gm -membertype scriptmethod |select -expandproperty name
        } else {
            $classData.instancemethods.keys
        }
    }

    $mockRecords = $methodNames | foreach {
        __GetMockableMethodFunction $methodClass $_ $staticMethods $object
    }

    $mockRecords
}

function __RemoveMockedMethod($mockedFunctionInfo) {
    if ( $mockedFunctionInfo.MockedObject ) {
        __UnpatchSingleInstanceMethod $mockedFunctionInfo
    } elseif ( $mockedFunctionInfo.IsStatic ) {
        __UnpatchStaticMethod $mockedFunctionInfo
    } else {
        __UnpatchAllInstancesMethod $mockedFunctionInfo
    }
}

function __UnpatchAllInstancesMethod($mockedFunctionInfo) {
    $mockedFunctionInfo.classData.instanceMethods[$mockedFunctionInfo.methodName] = $mockedFunctionInfo.OriginalScriptBlock
}

function __UnpatchSingleInstanceMethod($mockedFunction) {
    throw [NotImplementedException]::new("Object mock removal not implemented")
}

function __UnpatchStaticMethod($mockedFunction) {
    $mockedFunction.classData.prototype.scriptclass | add-member -name $mockedFunctionInfo.methodname -membertype scriptmethod -value $mockedFunctionInfo.originalScriptblock -force
}
