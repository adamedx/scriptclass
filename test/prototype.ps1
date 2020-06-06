set-strictmode -version 2

function New-ScriptClass2 {
    param(
        $Name,
        $ClassDefinitionBlock
    )

    $classObject = GetClassObject $classDefinitionBlock

    $properties = GetProperties $classObject.__module

    $methods = GetMethods $classObject.__module $Name

    $classBlock = GetClassBlock $Name $classObject.__module.name $properties $methods

    $newClass = $classObject.InvokeScript($classBlock, $classObject.__module, $properties)

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

function GetClassBlock($className, $classModuleName, $properties, $methods) {
    $propertyDeclaration = ( GetPropertyDefinitions $properties ) -join "`n"

    $methodDeclaration = ( GetMethodDefinitions $methods ) -join "`n"

    $classInstanceId = $classModuleName -replace '-', '_'

    $classFragment = $classTemplate -f $className, $propertyDeclaration, $methodDeclaration, $classInstanceId

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

function GetMethods($classModule, $className) {
    $methods = @{}

    foreach ( $functionName in $classModule.ExportedFunctions.Keys ) {
        if ( $functionName -in $internalFunctions ) {
            continue
        }

        $method = NewMethod $functionName $classModule.ExportedFunctions[$functionName].scriptblock InstanceMethod
        $methods.Add($method.Name, $method)
    }

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

function NewClassInfo($className, $class, $classObject, $classModule) {
    if ( $classObject -eq $null ) {
        throw 'anger3'
    }

    [PSCustomObject] @{
        Name = $className
        Class = $class
        ClassObject = $classObject
        Module = $classModule
    }
}

function NewMethodDefinition($methodName, $scriptblock) {
    $parameters = if ( $scriptblock.ast.body.paramblock ) {
        $scriptblock.ast.body.paramblock.parameters
    } else {
        $scriptblock.ast.parameters
    }

    $parameterList = GetMethodParameterList $parameters

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
    if ( $classObject -eq $null ) {
        throw 'anger2'
    }
    $classTable[$className] = NewClassInfo $className $classType $classObject $classObject.__module
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

    $nativeObject = $classInfo.class::new($classInfo.module, $args)

    [PSObject]::new($nativeObject)
}

# Even though there is no cmdletbinding, this works with -verbose!
function ==> {
    param(
        [string] $methodName
    )

    foreach ( $object in $input ) {
        $object.InvokeMethod($methodName, $args)
    }
}

$classModuleBlock = {
    param($__classDefinitionBlock)

    set-strictmode -version 2

    function __initialize {}

    . $__classDefinitionBlock

    function InvokeScript([ScriptBlock] $scriptBlock) {
        . {}.module.NewBoundScriptBlock($scriptBlock) @args
    }

    function InvokeMethod($methodName, [object[]] $methodArgs) {
        if ( ! ( $this | gm -membertype method $methodName -erroraction ignore ) ) {
            throw "The method '$methodName' is not defined for this object of type $($this.gettype().fullname)"
        }

        & $methodName @methodArgs
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

$methodTemplate = @'
    [object] {0}({1}) {{
        $thisVariable = [PSVariable]::new('this', $this)
        $methodBlock = (get-item function:{0}).scriptblock
        $__result = $methodBlock.InvokeWithContext(@{{}}, $thisVariable, @({2}))
        return $__result
    }}
'@

$classTemplate = @'
param($module, $properties)

Class BaseModule__{3} {{
    static $Properties = $null
    static $StaticProperties = $null
    static $Module = $null
}}

[BaseModule__{3}]::Properties = $properties.values | where PropertyType -eq 'InstanceProperty'
[BaseModule__{3}]::StaticProperties = $properties.values | where PropertyType -eq 'StaticProperty'
[BaseModule__{3}]::Module = $module

class {0} : BaseModule__{3} {{

    static {0}() {{
        [BaseModule__{3}]::Module | import-module
    }}

    {0}($classModule, [object[]] $constructorArgs) {{
       foreach ( $property in [BaseModule__{3}]::Properties ) {{
           $this.$($property.name) = $property.value.value
       }}
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
