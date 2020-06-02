function New-ScriptClass2 {
    param(
        $Name,
        $ClassDefinitionBlock
    )

    $classObject = GetClassObject $classDefinitionBlock

    $properties = GetProperties $classObject.__module

    $methods = GetMethods $classObject.__module

    $classBlock = GetClassBlock $Name $properties $methods

    $newClass = $classObject.InvokeScript($classBlock)

    AddClassType $Name $newClass $classObject
}

enum MethodType {
    Constructor
    StaticConstructor
    InstanceMethod
    StaticMethod
}

enum PropertyType {
    InstanceProperty
    StaticProperty
}

function GetClassObject($classDefinitionBlock) {
    new-module -ascustomobject $classModuleBlock -argumentlist $classDefinitionBlock
}

function GetClassBlock($className, $properties, $methods) {
    $propertyDeclaration = ( GetPropertyDefinitions $properties ) -join "`n"

    $methodDeclaration = ( GetMethodDefinitions $methods ) -join "`n"

    $classFragment = $classTemplate -f $className, $propertyDeclaration, $methodDeclaration

    $global:myfrag = $classFragment
    [ScriptBlock]::Create($classFragment)
}

function NewMethod($methodName, $scriptBlock, [MethodType] $methodType) {
    [PSCustomObject] @{
        Name = $methodName
        ScriptBlock = $scriptblock
        MethodType = $methodType
    }
}

function NewProperty($propertyName, $type, $value, [PropertyType] $propertyType) {
    [PSCustomObject] @{
        Name = $propertyName
        Type = $type
        Value = $value
        PropertyType = $propertyType
    }
}

function GetMethods($classModule) {
    $methods = @{}

    foreach ( $functionName in $classModule.ExportedFunctions.Keys ) {
        if ( $functionName -in $internalFunctions ) {
            continue
        }

        $method = NewMethod $functionName $classModule.ExportedFunctions[$functionName].scriptblock InstanceMethod
        $methods.Add($method.Name, $method)
    }

    $className = $classModule.Class.Name

    $constructor = $methods[(GetConstructorMethodName $className)]

    if ( $constructor ) {
       $constructor.MethodType = [MethodType]::Constructor
    }

    $methods
}

function GetConstructorMethodName($className) {
    '__initialize'
}

function GetProperties($classmodule) {
    $properties = @{}

    foreach ( $propertyName in $classModule.ExportedVariables.Keys ) {
        if ( $propertyName -in $internalProperties ) {
            continue
        }

        $propertyValue = $classModule.ExportedVariables[$propertyName]
        $type = if ( $propertyValue -ne $null ) {
            $propertyValue.value.GetType()
        }

        $property = NewProperty $propertyName $type $propertyValue InstanceProperty
        $properties.Add($propertyName, $property)
    }

    $properties
}

function GetMethodParameters($scriptBlock) {
    $scriptBlock.ast.Parameters
}

function GetMethodParameterList($parameters) {
    if ( $parameters ) {
        ( $parameters | foreach { $_.name.tostring() } )  -join ','
    } else {
        @()
    }
}

function GetMethodFunctionInvocationArguments($parameters) {
    if ( $parameters ) {
        ( $parameters | foreach { $_.name.tostring() } )  -join ' '
    } else {
        @()
    }
}

function NewClassInfo($className, $class, $classObject, $classModule) {
    [PSCustomObject] @{
        Name = $className
        Class = $class
        ClassObject = $classObject
        Module = $classModule
    }
}

function NewMethodDefinition($methodName, $scriptblock) {
    $parameterList = GetMethodParameterList $scriptblock.ast.parameters
    $argumentList = GetMethodFunctionInvocationArguments $scriptblock.ast.parameters

#    $methodTemplate -f $methodname, $parameterList, $argumentList
    $methodTemplate -f $methodname, $parameterList, $parameterList
}

function GetMethodDefinitions($methods) {
    foreach ( $method in $methods.values ) {
        NewMethodDefinition $method.Name $method.scriptblock
    }
}

function NewPropertyDefinition($propertyName, $type, $value, [PropertyType] $propertyType) {
    $staticElement = if ( $propertyType -eq [PropertyType]::StaticProperty ) {
        'static'
    } else {
        ''
    }

    $typeElement = if ( $type ) {
        "[$type]"
    } else {
        ''
    }

    $propertyTemplate -f $propertyName, $typeElement, $staticElement
}

function GetPropertyDefinitions($properties) {
    $global:myprops = $properties
    foreach ( $property in $properties.values ) {
        NewPropertyDefinition $property.name $property.type $property.value $property.propertyType
    }
}

function AddClassType($className, $classType, $classObject) {
    $classTable[$className] = NewClassInfo $className $classType $classOject $classObject.__module
}

function Get-ScriptClass2 {
    [cmdletbinding()]
    param($className)

    $class = $classTable[$className]

    if ( ! $class ) {
        throw [ArgumentException]::new("The specified class '$ClassName' could not be found.")
    }

    $class
}

function New-ScriptObject2 {
    [cmdletbinding()]
    param($ClassName)

    $classInfo = Get-ScriptClass2 $ClassName

    $classInfo.class::new($classInfo.module, $args)
}

$classModuleBlock = {
    param($__classDefinitionBlock)

    set-strictmode -version 2

    function __initialize {}

    . $__classDefinitionBlock

    function InvokeScript([ScriptBlock] $scriptBlock) {
        . {}.module.NewBoundScriptBlock($scriptBlock)
    }

    $__module = {}.module
    . $__module.newboundscriptblock($__classDefinitionBlock)

    export-modulemember -variable * -function *
}

$internalFunctions = '__initialize'
$internalProperties = '__module', '__classDefinitionBlock'

$propertyTemplate = @'
    {2} {1} ${0} = $null
'@
<#
$methodTemplate = @'
    [object] {0}({1}) {{
        $__result = ({0} {2})
        return $__result
    }}
'@
#>

$methodTemplate = @'
    [object] {0}({1}) {{
        $thisVariable = [PSVariable]::new('this', $this)
#        $thisList = [System.Collections.Generic.List[psvariable]]::new()
#        $thisList.Add($thisVariable)
        $methodBlock = (get-item function:{0}).scriptblock
        $__result = $methodBlock.InvokeWithContext(@{{}}, $thisVariable, @({2}))
        return $__result
    }}
'@


$classTemplate = @'
class {0} {{

    {0}($classModule, [object[]] $constructorArgs) {{
       $classModule | import-module
        __initialize @constructorArgs
    }}

    {1}

    {2}
}}

[{0}]
'@


$classTable = @{}

<#
# Wow, this works!
new-scriptclass2 Fun1 {$stuff = 2; function multme($arg1, $arg2) { $arg1 * $argnew-scriptclass2 Fun1 {$stuff = 2; function multme($arg1, $arg2) { $arg1 * $argnew-scriptclass2 Fun1 {$stuff = 2; function multme($arg1, $arg2) { $arg1 * $arg2}; function saveme($myval) { $this.stuff = $myval}; function getme { $this.stuff}; function addtome($argn) {multme $this.stuff $argn};function MultSave($argadd) { $res = multme $this.stuff $argadd; saveme $res}}

$fun = New-ScriptObject2 fun1

#>

# This actually works pretty well too!
<#
new-scriptclass2 Thrower {
    $shouldthrow = $false

    function level1($throwme) {
        $this.shouldthrow = $throwme
        level2
    }

    function level2 {
        if ( $this.shouldthrow ) {
            throw 'me'
        }
    }
}
                                                                                                                                               #>

# Errors are something like that below -- error[0] looks useless,
# but $error[1] has everything -- no need to explore $error after this
<#
PS> $error[0].scriptstacktrace
at level1, <No file>: line 15
at <ScriptBlock>, <No file>: line 1
PS> $error[1].scriptstacktrace
at level2, C:\Users\adamedx\OneDrive\scripts\classmod3.ps1: line 286
at level1, C:\Users\adamedx\OneDrive\scripts\classmod3.ps1: line 281
at level1, <No file>: line 15
at <ScriptBlock>, <No file>: line 1
#>
