# -- ScriptClass.ps1

set-strictmode -version 2

# -- ScriptClassSpecification.ps1

# This class attempts to capture the configurable choices made in defining
# the system. This shows where a feature was intentional and could have been
# different for instance. It also captures these key aspects of the system
# in one place for simplified comprehension. Finally, these choices can be changed
# easily in one place rather than searching throughout the source; this makes
# it straightforward to experiment with alternatives.
class ScriptClassSpecification {
    static $Parameters = @{
        TypeSystemName = 'ScriptClass'
        Language = @{
            StaticKeyword = 'static'
            StrictTypeKeyword = 'strict-val'
            ConstantKeyword = 'New-Constant'
            ConstantAlias = 'const'
            ConstructorName = '__initialize'
            ClassCollectionType = '___ScriptClassClassCollectionType'
            ClassCollectionName = ':' # This results in a variable expressed as '::' -- due to escaping of ':' ?
            MethodCallOperator = '=>'
            StaticMethodCallOperator = '::>'
        }
        Schema = @{
            ClassMember = @{
                Name = 'ScriptClass'
                Type = '__ScriptClass_PrimitiveType'
                Structure = @{
                    ClassNameMemberName = 'ClassName'
                    ModuleMemberName = 'Module'
                }
            }
            InvokeScriptMethodName = 'InvokeScript'
            InvokeMethodMethodName = 'InvokeMethod'
        }
    }
}

# -- ClassDefinition.ps1

# This provides a system-indepent definition of what defines a class
# of objects for use in a type system. In theory types defined this
# way are not tied to a particular implementation in terms of how
# objects of the class are instantiated and execute at runtime.
class Method {
    [string] $name
    [ScriptBlock] $block
    [bool] $isStatic
    [bool] $isSystem
    Method([string] $name, [ScriptBlock] $methodBlock, $isStatic, $isSystem) {
        $this.name = $name
        $this.block = $methodBlock
        $this.isStatic = $isStatic
        $this.isSystem = $isSystem
    }
}

class Property {
    [string] $name = $null
    [type] $type = $null
    [object] $value = $null
    [bool] $isStatic
    [bool] $isSystem
    [bool] $isReadOnly

    Property([string] $name, $value, [bool] $isStatic, [bool] $isSystem, [bool] $isReadOnly) {
        $this.isStatic = $isStatic
        $this.isSystem = $isSystem
        $this.isReadOnly = $isReadOnly
        $this.name = $name

        if ( $value -is [TypedValue] ) {
            $this.type = $value.type
            $this.value = $value.value
        } else {
            $this.type = $null
            $this.value = $value
        }
    }
}

class TypedValue {
    [type] $type = $null
    [object] $value = $null

    TypedValue($type, $value) {
        $this.type = $type
        $this.value = $value
    }
}

class ClassDefinition {
    ClassDefinition([string] $name, [Method[]] $instanceMethods, [Method[]] $staticMethods, [Property[]] $instanceProperties, [Property[]] $staticProperties, $constructorMethodName) {
        $this.name = $name

        foreach ( $instanceMethod in $instanceMethods ) {
            if ( $constructorMethodName -and $instanceMethod.Name -eq $constructorMethodName ) {
                $this.constructor = $instanceMethod.block
            } else {
                $this.instanceMethods[$instanceMethod.name] = $instanceMethod
            }
        }

        foreach ( $instanceProperty in $instanceProperties ) {
            $this.instanceProperties[$instanceProperty.name] = $instanceProperty
        }

        foreach ( $staticMethod in $staticMethods ) {
            $this.staticMethods[$staticMethod.name] = $staticMethod
        }

        foreach ( $staticProperty in $staticProperties ) {
            $this.staticProperties[$staticProperty.name] = $staticProperty
        }
    }

    [void] CopyPrototype([bool] $staticContext, $existingObject) {
        $builder = [NativeObjectBuilder]::new($null, $existingObject, [NativeObjectBuilderMode]::Modify)
        $this.WritePrototype($builder, $staticContext)
    }

    [object] ToPrototype([bool] $staticContext) {
        $builder = [NativeObjectBuilder]::new($this.name, $null, [NativeObjectBuilderMode]::Create)

        $this.WritePrototype($builder, $staticContext)

        return $builder.GetObject()
    }

    [Method[]] GetInstanceMethods() {
        return $this.instanceMethods.values
    }

    [Property[]] GetInstanceProperties() {
        return $this.instanceProperties.values
    }

    [Method[]] GetStaticMethods() {
        return $this.staticMethods.values
    }

    [Property[]] GetStaticProperties() {
        return $this.staticProperties.values
    }

    hidden [void] WritePrototype([NativeObjectBuilder] $builder, [bool] $staticContext) {
        $methods = if ( $staticContext ) {
            $this.staticMethods.values
        } else {
            $this.instanceMethods.values
        }

        $properties = if ( $staticContext ) {
            $this.staticProperties.values
        } else {
            $this.instanceProperties.values
        }

        $methods | foreach {
            $builder.AddMethod($_.name, $_.block)
        }

        $properties | foreach {
            $builder.AddProperty($_.name, $_.type, $_.value, $_.isReadOnly)
        }
    }

    [string] $name = $null
    [ScriptBlock] $constructor = $null
    [HashTable] $instanceMethods = @{}
    [HashTable] $instanceproperties = @{}
    [HashTable] $staticMethods = @{}
    [HashTable] $staticProperties = @{}
}

# -- ClassDsl.ps1

# This implements the language used to specify the definition of a class. This implementation
# is embedded within the PowerShell language, particularly as it can be executed within a
# PowerShell script block, a form of anonymous function
class ClassDsl {
    ClassDsl([bool] $staticScope, [HashTable] $systemMethodBlocks, [string] $constructorMethodName) {
        $this.staticScope = $staticScope
        $this.systemMethods = @()
        $this.constructorMethodName = $constructorMethodName

        if ( $systemMethodBlocks ) {
            foreach ( $methodName in $systemMethodBlocks.keys ) {
                $method = [Method]::new($methodName, $systemMethodBlocks[$methodName], $false, $true)
                $this.systemMethods += $method
            }
        }
    }

    [ClassDefinition] NewClassDefinition([string] $className, [ScriptBlock] $classBlock, [object[]] $classArguments) {
        $classObject = new-module -AsCustomObject $this::inspectionBlock -argumentlist $this, $classBlock, $classArguments, $this.systemMethods

        if ( $this.exception ) {
            throw $this.exception
        }

        if ( ! $classObject ) {
            throw "Internal exception defining class"
        }

        $instanceMethodList = $this.GetMethods($classObject, $false)
        $staticMethodList = $this.GetMethods($classObject, $true)

        $instancePropertyList = $this.GetProperties($classObject, $false)
        $staticPropertyList = $this.GetProperties($classObject, $true)

        $classDefinition = [ClassDefinition]::new($className, $instanceMethodList, $staticMethodList, $instancePropertyList, $staticPropertyList, $this.constructorMethodName)

        return $classDefinition
    }

    hidden [Method[]] GetMethods([PSCustomObject] $classObject, $staticScope) {
        $methods = if ( $staticScope ) {
            $this.staticMethods.values | foreach {
                [Method]::new($_.name, $_.block, $true, $false)
            }
        } else {
            $classObject.psobject.methods |
              where membertype -eq scriptmethod |
              where name -notin $this.excludedFunctions |
              foreach {
                  [Method]::new($_.name, $_.script, $false, $false)
              }
        }

        return $methods
    }

    hidden [Property[]] GetProperties([PSCustomObject] $classObject, $staticScope) {
        $properties = if ( $staticScope ) {
            $this.staticProperties.values | foreach {
                [Property]::new($_.name, $_.value, $true, $false, $_.isReadOnly)
            }
        } else {
            $classObject.psobject.properties |
              where membertype -eq noteproperty |
              where name -notin $this.excludedVariables |
              foreach {
                  [Property]::new($_.name, $_.value, $false, $false, ! $_.IsSettable)
              }
        }

        return $properties
    }

    [bool] $staticScope = $false
    $constructorMethodName = $null

    $staticMethods = @{}
    $staticProperties = @{}

    $systemMethods = $null

    $exception = $null

    $executingInspectionModule = $null

    $languageElements = @{
        [ScriptClassSpecification]::Parameters.Language.StrictTypeKeyword = @{
            Alias = $null
            Script = {
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

                [TypedValue]::new($propType, $value)
            }
        }
        [ScriptClassSpecification]::Parameters.Language.StaticKeyword = @{
            Alias = $null
            Script = {
                param($staticBlock)
                if ( $this.staticScope ) {
                    throw 'Invalid static syntax'
                }

                $dsl = [ClassDsl]::new($true, $null, $null)
                $staticDefinition = $dsl.NewClassDefinition($null, $staticBlock, $null)

                $staticDefinition.GetInstanceMethods() | foreach {
                    $this.staticMethods.Add($_.name, $_)
                }

                $staticDefinition.GetInstanceProperties() |foreach {
                    $this.staticProperties.Add($_.name, $_)
                }
            }
        }
        [ScriptClassSpecification]::Parameters.Language.ConstantKeyword = @{
            Alias = [ScriptClassSpecification]::Parameters.Language.ConstantAlias
            Script = {
                param(
                    [parameter(mandatory=$true)] $name,
                    [parameter(mandatory=$true)] $value
                )

                $existingVariable = . $this.executingInspectionModule.NewBoundScriptBlock({param($___variableName) get-variable -name $___variableName -scope 1 -erroraction ignore}) $name $value

                if ( $existingVariable -eq $null ) {
                    . $this.executingInspectionModule.NewBoundScriptBlock({param($___variableName, $___variableValue) new-variable -name $___variableName -value $___variableValue -option readonly; remove-variable ___variableName, ___variableValue}) $name $value
                } elseif ($existingVariable.value -ne $value) {
                    throw "Attempt to redefine constant '$name' from value '$($existingVariable.value) to '$value'"
                }
            }
        }
    }

    $excludedVariables = $null
    $excludedFunctions = $this.languageElements.keys

    static $inspectionBlock = {
        param($___dsl, $___classBlock, $___classArguments, $___systemMethods)
        set-strictmode -version 2

        $___dsl.executingInspectionModule = {}.Module

        foreach ( $___elementName in $___dsl.languageElements.keys ) {
            new-item function:/$___elementName -value $___dsl.languageElements[$___elementName].script | out-null
            if ( $___dsl.languageElements[$___elementName].Alias ) {
                set-alias $___dsl.languageElements[$___elementName].Alias $___elementName
            }
        }

        foreach ( $___method in $___systemMethods ) {
            new-item "function:/$($___method.name)" -value {}.Module.NewBoundScriptBlock($___method.block) | out-null
        }

        $___variables = @()

        get-variable | where { $_.name.StartsWith('___') } | foreach {
            $___variables += $_
        }

        try {
            .  {}.module.newboundscriptblock($___classBlock) $___classArguments | out-null
        } catch {
            $___dsl.exception = $_.exception
            throw
        }

        $___dsl.excludedVariables = @('this', 'foreach')
        $___dsl.excludedFunctions = $___dsl.languageElements.keys

        $___variables | foreach { $_ | remove-variable }

        export-modulemember -function * -variable *
    }
}

# -- NativeObjectBuilder

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
        $this.TypeName = $typeName

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
            if ( $prototype ) {
                $prototype.psobject.properties | foreach {
                    if ( $_.membertype -ne 'NoteProperty' ) {
                        throw [ArgumentException]::new("Property '$($_.name)' of member type '$($_.memberType)' is not of valid member type 'NoteProperty'")
                    }

                    $objectState[$_.name] = $_.value
                }
            }

            if ( $typeName ) {
                $objectState[([NativeObjectBuilder]::NativeTypeMemberName)] = $typeName
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
            if (! ( $this.object | gm name -membertype $type -erroraction ignore ) ) {
                throw "Member '$name' cannot be removed because the object has no such member."
            }
        }
        $this.object.psobject.members.remove($name)
    }

    static [object] CopyFrom($sourceObject) {
        return $sourceObject.psobject.copy()
    }

    static [void] RegisterClassType([string] $typeName, [string[]] $visiblePropertyNames, $prototype) {
        if ( $visiblePropertyNames -contains ([NativeObjectBuilder]::NativeTypeMemberName) ) {
            throw "Property name ([NativeObjectBuilder]::NativeTypeMemberName) is prohibited"
        }

        $typeArguments = [NativeObjectBuilder]::basicTypeData.clone()
        $typeArguments.TypeName = $typeName

        $displayProperties = @{}
        $typeArguments.DefaultDisplayPropertySet |
          where { $_ -ne ([NativeObjectBuilder]::NativeTypeMemberName) } |
          foreach {
            $displayProperties.Add($_, $null)
        }

        $visiblePropertyNames | foreach {
            $displayProperties.Add($_, $null)
        }

        if ( $displayProperties.count -eq 0 ) {
            $displayProperties.Add([NativeObjectBuilder]::NativeTypeMemberName, $null)
        }

        $typeArguments.DefaultDisplayPropertySet = [object[]] $displayProperties.keys

        if ( $prototype ) {
            $typeArguments.PropertySerializationSet += $prototype.psobject.properties | where name -ne ([NativeObjectBuilder]::NativeTypeMemberName) | select -expandproperty name
        }

        $existingTypeData = Get-TypeData $typeName

        if ( $existingTypeData ) {
            $existingTypeData | remove-typedata
        }

        Update-TypeData -force @typeArguments
    }

    static $basicTypeData = @{
        TypeName = ([ScriptClassSpecification]::Parameters.Schema.ClassMember.Type)
        MemberName = ([NativeObjectBuilder]::NativeTypeMemberName)
        Value = $null
        MemberType = 'noteproperty'
        DefaultDisplayPropertySet = @(([NativeObjectBuilder]::NativeTypeMemberName))
        PropertySerializationSet = @(([NativeObjectBuilder]::NativeTypeMemberName))
        Serializationmethod = 'SpecificProperties'
        Serializationdepth = 2
    }

    $typeName = $null
    [PSCustomObject] $object = $null
}

# -- ClassBuilder.ps1

# The ClassBuilder translates a system-indepenent class definition into a type
# that can be used to create objects of that type in the type system.
class ClassInfo {
    ClassInfo([ClassDefinition] $classDefinition, $prototype) {
        $this.classDefinition = $classDefinition
        $this.prototype = $prototype
    }
    [ClassDefinition] $classDefinition
    $prototype
}

class ClassBuilder {
    ClassBuilder([string] $className, [ScriptBlock] $classblock, [string] $constructorName) {
        $this.className = $className
        $this.classBlock = $classBlock
        $this.systemMethodBlocks = @{}
        $this.systemProperties = @{}
        $this.constructorName = $constructorName
    }

    [ClassInfo] ToClassInfo([object[]] $classArguments) {
        $dsl = [ClassDsl]::new($false, $this.systemMethodBlocks, $this.constructorName)
        $classDefinition = $dsl.NewClassDefinition($this.className, $this.classBlock, $classArguments)
        $basePrototype = $classDefinition.ToPrototype($false)
        $prototype = $this.GetPrototypeObject($basePrototype)
        $classInfo = [ClassInfo]::new($classDefinition, $prototype)
        return $classInfo
    }

    [void] AddSystemMethod([string] $methodName, [ScriptBlock] $methodBlock ) {
        $this.systemMethodBlocks.Add($methodName, $methodBlock)
    }

    [void] AddSystemProperty([string] $propertyName, $type, $value) {
        $this.systemProperties.Add($propertyName, @{name=$propertyName; type=$type; value=$value})
    }

    hidden [object] GetPrototypeObject($basePrototype) {
        $builder = [NativeObjectBuilder]::new($null, $basePrototype, [NativeObjectBuilderMode]::Modify)
        if ( $this.systemProperties ) {
            $this.systemProperties.values | foreach {
                $builder.AddProperty($_.name, $_.type, $_.value, $_.isReadOnly)
            }
        }

        return $builder.GetObject()
    }

    [string] $className = $null
    [string] $constructorName = $null
    [ScriptBlock] $classBlock = $null
    [HashTable] $systemMethodBlocks = $null
    [HashTable] $systemProperties = $null
}

# -- ScriptClassBuilder.ps1

# The ScriptClassBuilder implements what is essentially a derived type of the general type. In particular,
# ScriptClassBuilder is where the notion of static methods is implemented for the type, and object structure
# supporting that along a level of reflection capability that distinguishes ScriptClass types is implemented
# here.
class ScriptClassBuilder : ClassBuilder {
    ScriptClassBuilder([string] $className, [ScriptBlock] $classblock) :
    base($className, $classBlock, [ScriptClassSpecification]::Parameters.Language.ConstructorName) {
    }

    [ClassInfo] ToClassInfo([object[]] $classArguments) {
        $classMemberParameters = [ScriptClassSpecification]::Parameters.Schema.ClassMember
        $this.staticTarget = [NativeObjectBuilder]::CopyFrom($this::classMemberPrototype)
        $this.AddSystemProperty($classMemberParameters.Name, $null, $this.staticTarget)

        foreach ( $methodname in $this::commonMethods.keys ) {
            $this.AddSystemMethod($methodName, $this::commonMethods[$methodName] )
        }

        $classInfo = ([ClassBuilder]$this).ToClassInfo($classArguments)

        $classInfo.classDefinition.CopyPrototype($true, $this.staticTarget)

        $classMemberBuilder = [NativeObjectBuilder]::new($null, $this.staticTarget, [NativeObjectBuilderMode]::Modify)
        foreach ( $methodname in $this::commonMethods.keys ) {
            $methodScript = ($classInfo.prototype.psobject.methods | where name -eq $methodName).script
            $classMemberBuilder.AddMethod($methodName, $methodScript)
        }

        $this.staticTarget.$($classMemberParameters.Structure.ClassNameMemberName) = $this.className
        $this.staticTarget.$($classMemberParameters.Structure.ModuleMemberName) = $this.classBlock.Module

        return $classInfo
    }

    static [void] Initialize() {
        $schemaParameters = [ScriptClassSpecification]::Parameters.Schema.ClassMember

        $primitiveClassPropertyNames = @(
            $schemaParameters.Name
            $schemaParameters.Structure.ClassNameMemberName
            $schemaParameters.Structure.ModuleMemberName
        )

        $primitiveClassProperties = $primitiveClasspropertyNames | foreach {
            [Property]::new($_, $null, $false, $false, $false)
        }

        $primitiveClassDefinition = [ClassDefinition]::new(
            $null,
            @(),
            @(),
            $primitiveClassProperties,
            @(),
            $null
        )

        [ScriptClassBuilder]::classMemberPrototype = $primitiveClassDefinition.ToPrototype($false)
    }

    static $classMemberPrototype = $null
    static $commonMethods = @{
        InvokeMethod = {
            param([string] $methodName, $arguments)
            if ( ! $methodName ) {
                throw [ArgumentException]::new("Method name argument was `$null or empty")
            }
            $method = ($this.psobject.methods | where name -eq $methodname)
            if ( ! $method ) {
                throw [System.Management.Automation.MethodInvocationException]::new("The method '$methodName' could not be found on the object")
            }
            $this.InvokeScript($method.script, $arguments)
        }
        InvokeScript = {
            param([ScriptBlock] $script, $arguments)
            if ( ! $script ) {
                throw [ArgumentException]::new("Scriptblock argument argument was `$null or not specified")
            }
            # An interesting alternative is this, but evaluating a new closure AND getting a new scriptblock
            # seems excessive for a single method call -- perhaps system methods like this can be bound
            # when they are added to the object prototype:
            #
            #    . $script.module.newboundscriptblock($script.GetNewClosure()) @arguments
            #
            $thisVariable = [PSVariable]::new('this', $this)
            $script.InvokeWithContext(@{}, [PSVariable[]] @($thisVariable), $arguments)
        }
    }

    $staticTarget = $null
}

[ScriptClassBuilder]::Initialize()

# -- ClassManager.ps1

# Define the class member variable used to emulate the native PowerShell class behavior with [ClassName]::StaticMethodName.
# This may be required by other classes in the system implementation that rely on it, so those may need to be defined later.
remove-variable -erroraction ignore ([ScriptClassSpecification]::Parameters.Language.ClassCollectionName) -force
new-variable ([ScriptClassSpecification]::Parameters.Language.ClassCollectionName) -value ([PSCustomObject] @{([NativeObjectBuilder]::NativeTypeMemberName)=([ScriptClassSpecification]::Parameters.Language.ClassCollectionType)}) -option readonly -passthru

function GetModuleClassCollectionVariable {
    get-variable ([ScriptClassSpecification]::Parameters.Language.ClassCollectionName)
}

# This class implements the type system as a whole, storing state about defined types and providing access to information
# about them and the ability to instantiate instances of defined types. It is accessed as a singleton, though future
# implementations could allow for multiple instances to exist; perhaps that could be used to model module-scoped
# classes at some point.
class ClassManager {
    ClassManager([PSModuleInfo] $targetModule) {
        $this.targetModule = $targetModule
        $this.classCollectionVariable = if ( $targetModule ) {
            . $targetModule.NewBoundScriptBlock({GetModuleClassCollectionVariable})
        }
        if ( $this.classCollectionVariable ) {
            $this.classCollectionBuilder = [NativeObjectBuilder]::new($null, $this.classCollectionVariable.value, [NativeObjectBuilderMode]::Modify)
        }
    }

    [ClassDefinition] DefineClass([string] $className, [ScriptBlock] $classBlock, [object[]] $classArguments) {
        $existingClass = $this.FindClassInfo($className)

        if ( $existingClass ) {
            if ( ! $this.allowRedefinition ) {
                throw "Class '$className' is already defined"
            }
            write-verbose "Class '$className' already exists, will attempt to redefine it."
        }

        $classBuilder = [ScriptClassBuilder]::new($className, $classBlock)
        $classInfo = $classBuilder.ToClassInfo($classArguments)

        $this.AddClass($classInfo)

        $visibleProperties = $classInfo.classDefinition.GetInstanceProperties() |
          where isSystem -eq $false |
          select -expandproperty name

        [NativeObjectBuilder]::RegisterClassType($className, $visibleProperties, $classInfo.prototype)

        return $classInfo.classDefinition
    }

    [object] CreateObject([string] $className, [object[]] $constructorArguments) {
        $classInfo = $this.GetClassInfo($className)
        $object = [NativeObjectBuilder]::CopyFrom($classInfo.prototype)
        $this.InitializeObject($object, $classInfo.classDefinition.constructor, $constructorArguments)

        return $object
    }

    [ClassInfo] GetClassInfo($className) {
        $classInfo = $this.FindClassInfo($className)
        if ( ! $classInfo ) {
            throw "class '$className' does not exist"
        }

        return $classInfo
    }

    [ClassInfo] FindClassInfo($className) {
        return $this.classes[$className]
    }

    [bool] IsClassType($object, [string] $classType) {
        $isOfType = $object -is [PSCustomObject]

        # Check for the native object type
        if ( $isOfType ) {
            # This is only a valid class if it has the required class member
            $isOfType = ($object | gm ([ScriptClassSpecification]::Parameters.Schema.ClassMember.Name) -erroraction ignore)
            # If it does have the member, validate it
            if ( $isOfType ) {
                $classMember = $object.$([ScriptClassSpecification]::Parameters.Schema.ClassMember.Name)
                $classMemberClassName = if ( $classMember ) {
                    $classMember.$([ScriptClassSpecification]::Parameters.Schema.ClassMember.Structure.ClassNameMemberName)
                }
                # A null member is just a primitve type, but if it's
                # non-null it MUST be an actually defined class
                $isOfType = ($classMemberClassName -eq $null) -or $this.FindClassInfo($classMemberClassName) -ne $null
                # If the caller specified a type to validate against,
                # see if this object's typename matches the type
                # specified by the caller
                if ( $isOfType -and $classType ) {
                    $objectTypeName = if ( $classMemberClassName ) {
                        $classMemberClassName
                    } else {
                        # This is the type name for an object with
                        # a null class member
                        [ScriptClassSpecification]::Parameters.Schema.ClassMember.Type
                    }
                    $isOfType = $classType -eq $objectTypeName
                }
            }
        }

        return $isOfType
    }

    hidden [void] AddClass([ClassInfo] $classInfo) {
        $className = $classInfo.classDefinition.Name
        $firstClass = $this.classes.Count -eq 0
        $this.classes[$className] = $classInfo
        if ( $this.classCollectionBuilder ) {
            $classMemberName = [ScriptClassSpecification]::Parameters.Schema.ClassMember.Name
            $this.classCollectionBuilder.RemoveMember($className, 'ScriptProperty', $true)
            $this.classCollectionBuilder.AddMember($className, 'ScriptProperty', [ScriptBlock]::Create("[ClassManager]::Get().classes['$className'].prototype.$classMemberName"), $null)
            if ( $firstClass ) {
                [NativeObjectBuilder]::RegisterClassType([ScriptClassSpecification]::Parameters.Language.ClassCollectionType, @(), $null)
            }
        }
    }

    static [ClassManager] Get() {
        return [ClassManager]::singleton
    }

    static [void] Initialize([PSmoduleInfo] $targetModule) {
        [ClassManager]::singleton = [ClassManager]::new($targetModule)
    }

    hidden [void] InitializeObject($object, $constructorBlock, [object[]] $constructorArguments) {
        if ( $constructorBlock ) {
            $object.InvokeScript($constructorBlock, $constructorArguments) | out-null
        }
    }

    static [ClassManager] $singleton = $null

    $targetModule = $null

    $classCollectionVariable = $null
    $classCollectionBuilder = $null
    $allowRedefinition = $true
    $classes = @{}
}

[ClassManager]::Initialize({}.Module)

# -- Commands

function New-ScriptClass2 {
    [cmdletbinding()]
    param(
        [parameter(mandatory=$true)] [string] $className,
        [scriptblock] $classBlock,
        $ArgumentList
    )

    try {
        [ClassManager]::Get().DefineClass($className, $classBlock, $ArgumentList) | out-null
    } catch {
        throw
    }
}

function New-ScriptObject2 {
    [cmdletbinding()]
    param(
        [parameter(mandatory=$true)] [string] $ClassName,
        [parameter(valuefromremainingarguments=$true)] $ArgumentList
    )
    $classManager = [ClassManager]::Get()
    $classManager.CreateObject($className, [object[]] $argumentList)
}

# -- MethodDsl.ps1

# function =>
new-item -path "function:/$([ScriptClassSpecification]::Parameters.Language.MethodCallOperator)" -value {
    param ($methodName)
    if ($methodName -eq $null) {
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
        if ( $_ -eq $null ) {
            throw [ArgumentException]::new("A `$null value was specified as the target for operator '$([ScriptClassSpecification]::Parameters.Language.MethodCallOperator)' for method '$methodName'")
        }
        $results += $_.InvokeMethod($methodName, $methodArgs)
    }

    if ( $results.length -eq 1) {
        $results[0]
    } else {
        $results
    }
} | out-null

new-item -path "function:/$([ScriptClassSpecification]::Parameters.Language.StaticMethodCallOperator)" -value {
    [cmdletbinding(positionalbinding=$false)]
    param(
        [parameter(valuefrompipeline=$true)] $target,
        [parameter(position=0)] $method,
        [parameter(valuefromremainingarguments=$true)] $arguments
    )

    if ( ! $target ) {
        throw [ArgumentException]::new("The target of the '$([ScriptClassSpecification]::Parameters.Language.StaticMethodCallOperator)' operator for method '$method' was `$null or not specified")
    }

    $classMember = [ScriptClassSpecification]::Parameters.Schema.ClassMember.Name

    $classObject = if ( $target -is [string] ) {
        [ClassManager]::Get().GetClassInfo($target).prototype.$classMember
    } elseif ( $target | gm $classMember -erroraction ignore ) {
        $target.$classMember
    } else {
        throw [ArgumentException]::new("The specified object is not a valid ScriptClass object")
    }

    if ( ! $classObject ) {
        throw [ArgumentException]::new("The specified object does not support ScriptClass static methods")
    }

    $classObject |=> $method @arguments
} | out-null


function Test-ScriptObject2 {
    [cmdletbinding()]
    param(
        [parameter(valuefrompipeline=$true, mandatory=$true)] $Object,
        [string] $ClassName = $null
    )

    return [ClassManager]::Get().IsClassType($Object, $ClassName)
}

function Invoke-Method2 {
    [cmdletbinding()]
    param(
        [Parameter(mandatory=$true)]
        $Context,
        [Parameter(mandatory=$true)]
        $Action,
        [Parameter(valuefromremainingarguments=$true)]
        [object[]] $Arguments
    )
    if ( $Context -eq $null ) {
        throw "Invalid Context -- Context may not be `$null"
    }

    if ( $Action -eq $null ) {
        throw "Invalid Action argument -- Action may not be `$null"
    }

    if ( $Action -isnot [string] -and $Action -isnot [ScriptBlock] ) {
        throw [ArgumentException]::new("The specified Action argument of type '$($Action.GetType())' must be of type [String] or type [ScriptBlock]")
    }

    $isExtendedClass = Test-ScriptObject2 $Context

    if ( $isExtendedClass ) {
        $invocationMethods = [ScriptClassSpecification]::Parameters.Schema
        if ( $Action -is [string] ) {
            $Context.$($invocationMethods.InvokeMethodMethodName)($Action, $arguments)
        } else {
            $Context.$($invocationMethods.InvokeScriptMethodName)($Action, $arguments)
        }
    } else {
        if ( $Action -is [string] ) {
            throw [ArgumentException]::new("Object is not a '$([ScriptClassSpecification]::Parameters.TypeSystemName)' extended type system object")
        }

        $thisVariable = [PSVariable]::new('this', $Context)
        $Action.InvokeWithContext(@{}, $thisVariable, $arguments)
    }
}

function Get-ScriptClass2 {
    [cmdletbinding()]
    param (
        [parameter(mandatory=$true)] [string] $ClassName
    )

    return [ClassManager]::Get().GetClassInfo($ClassName)
}

$mymanager = [ClassManager]::Get()

# -- ScriptClass.psm1

$functionsToAliases = @{
    'Get-ScriptClass2' = $null
    'Invoke-Method2' = 'withobject'
    'New-ScriptClass2' = 'scriptclass'
    'New-ScriptObject2' = 'new-so'
    'Test-ScriptObject2' = $null
    [ScriptClassSpecification]::Parameters.Language.MethodCallOperator = $null
    [ScriptClassSpecification]::Parameters.Language.StaticMethodCallOperator = $null
}

$functions = @()

$aliases = foreach ( $functionName in $functionsToAliases.keys ) {
    $functions += $functionName
    $alias = $functionsToAliases[$functionName]
    if ( $alias ) {
        set-alias $functionName $functionsToAliases[$functionName]
        $alias
    }
}

$exportArguments = @{
    function = $functions
    alias = $aliases
    variable = 'mymanager', ([ScriptClassSpecification]::Parameters.Language.ClassCollectionName)
}

export-modulemember @exportArguments

