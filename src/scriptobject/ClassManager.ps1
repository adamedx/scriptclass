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

# Define the class member variable used to emulate the native PowerShell class behavior with [ClassName]::StaticMethodName.
# This may be required by other classes in the system implementation that rely on it, so those may need to be defined later.
remove-variable -erroraction ignore ([ScriptClassSpecification]::Parameters.Language.ClassCollectionName) -force
new-variable ([ScriptClassSpecification]::Parameters.Language.ClassCollectionName) -value ([PSCustomObject] @{([NativeObjectBuilder]::NativeTypeMemberName)=([ScriptClassSpecification]::Parameters.Language.ClassCollectionType)}) -option readonly -passthru

function GetModuleClassCollectionVariable {
    get-variable ([ScriptClassSpecification]::Parameters.Language.ClassCollectionName)
}

$methodBlock = {
    param($object, $methodName)
    $block = (get-scriptclass -Detailed $object.scriptclass.classname).classdefinition.instancemethods[$methodName].block
#    $this = $object
    try {
        . $block @args
    } catch {
        write-error $_
        get-pscallstack | write-error
        throw
    }
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
        $this.GeneralizeInstanceMethods($classInfo)
 #       $classInfo.prototype | fl * | out-host

        $this.AddClass($classInfo)

#        write-host -fore yellow afteradd

  #      $this.classes[$className].prototype | fl * | out-host

        $visibleProperties = $classInfo.classDefinition.GetInstanceProperties() |
          where isSystem -eq $false |
          select -expandproperty name

#        $classInfo.prototype | fl * | out-host
#        $classInfo.prototype.scriptclass | fl * | out-host
        [NativeObjectBuilder]::RegisterClassType($className, $visibleProperties, $classInfo.prototype)

   #     $classInfo.prototype | fl * | out-host

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

    [void] SetClass([ClassInfo] $classInfo) {
        $this.GetClassInfo($classInfo.classDefinition.Name) | out-null
        $this.AddClass($classInfo)
#        $this.classes[$classInfo.classDefinition.name] = $classInfo
    }

    hidden [void] AddClass([ClassInfo] $classInfo) {
        $className = $classInfo.classDefinition.Name
        $this.classes[$className] = $classInfo
        if ( $this.classCollectionBuilder ) {
            $classMemberName = [ScriptClassSpecification]::Parameters.Schema.ClassMember.Name
            $this.classCollectionBuilder.RemoveMember($className, 'ScriptProperty', $true)
            $this.classCollectionBuilder.AddMember($className, 'ScriptProperty', [ScriptBlock]::Create("[ClassManager]::Get().classes['$className'].prototype.$classMemberName"), $null)
        }
    }

    static [ClassManager] Get() {
        return [ClassManager]::singleton
    }

    static [void] Initialize([PSmoduleInfo] $targetModule) {
        [ClassManager]::singleton = [ClassManager]::new($targetModule)
        [NativeObjectBuilder]::RegisterClassType([ScriptClassSpecification]::Parameters.Language.ClassCollectionType, @(), $null)
    }

    hidden [void] InitializeObject($object, $constructorBlock, [object[]] $constructorArguments) {
        if ( $constructorBlock ) {
            $object.InvokeScript($constructorBlock, $constructorArguments) | out-null
        }
    }

    hidden [void] GeneralizeInstanceMethods([ClassInfo] $classInfo) {
        $builder = [NativeObjectBuilder]::New($null, $classInfo.prototype, [NativeObjectBuilderMode]::Modify)
        $classInfo.classDefinition.GetInstanceMethods() | foreach {
            $generalizedBlock = $this.GetGeneralizedMethodBlock($_)
            $builder.RemoveMember($_.name, 'ScriptMethod', $false)
            $builder.AddMethod($_.name, $generalizedBlock)
        }
    }

    hidden [ScriptBlock] GetGeneralizedMethodBlock([Method] $method) {
        $block = [ScriptBlock]::Create($this::GeneralizedMethodTemplate -f $method.name)
#        return $method.block.module.newboundscriptblock($script:methodBlock)
        return $method.block.module.newboundscriptblock($block)
    }

    static [ClassManager] $singleton = $null

    hidden static [string] $GeneralizedMethodTemplate = @'
$block =  (get-scriptclass -Detailed $this.scriptclass.classname).classdefinition.instancemethods['{0}'].block
. $block @args
'@

<#
    hidden static [string] $GeneralizedMethodTemplate = @'
$block =  (get-scriptclass -Detailed $this.scriptclass.classname).classdefinition.instancemethods['{0}'].block
$this.InvokeScript($block, $args)
'@
#>

    $targetModule = $null

    $classCollectionVariable = $null
    $classCollectionBuilder = $null
    $allowRedefinition = $true
    $classes = @{}
}

[ClassManager]::Initialize({}.Module)

$mymanager = [ClassManager]::Get()

