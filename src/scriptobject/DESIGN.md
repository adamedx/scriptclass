ScriptClass Design
==================

This document provides a high-level description of the component design of the ScriptClass
extensions to PowerShell.

## Motivation

The overall goal for the ScriptClass module can be stated as follows:

> The ScriptClass module is intended to facilitate the development of PowerShell-based applications rather than just scripts or utilities that comprise the typical PowerShell use case.

Why does PowerShell need ScriptClass to enable serious application development? The [Overview document](https://github.com/adamedx/scriptclass/blob/main/docs/Overview.md) document goes into this in detail: PowerShell, even as of versions 5 and 6 provides at best awkward support for object-based methodologies for code factoring and reuse. Most large-scale application development requires some consistent organizational principle to allow developers to reason over and maintain larger codebases; object-oriented approaches such as those in C++, Java, C#, Python, Ruby, JavaScript, and many others have done this successfully enough for developers to work on large codebases and more importantly to deliver complex but reliable systems with the work of hundreds or even thousands of developers.

ScriptClass attempts to fill this gap in PowerShell by extending PowerShell's typical imperative / functional hybrid syntax to support types (i.e. classes) and objects, and to so without the "bolted on" feel of PowerShell's `class` keyword.

## Design principles

In bringing object orientation to PowerShell, the following principles are a guide:

* Favor the use of existing PowerShell concepts and features over implementing and introducing new concepts and features
* Derive inspiration for user experience from object-based dynamic languages like Python, Ruby, and JavaScript
* Object-orientation should feel idiomatic and intuitive with respect to PowerShell
* Prefer building on existing PowerShell concepts and syntax where possible rather than replacing them
* The initial implementation should be PowerShell-based -- a native implementation in the PowerShell language itself should wait until this approach has wider community feedback and validation

## Requirements

ScriptClass must provide the following capabilities to developers through PowerShell:

* The functionality of the library must be exposed as a module to consumers
* Ability to define a set of objects by the methods they expose and the structure of their internal state
* The library must represent and manage the runtime state of the objects
* The library must provide a way to invoke methods on the objects
* The library's internal state must not be accessible outside the boundary of its module -- users must interact with objects
  and object definitions strictly through public interfaces explicitly exposed by the module
* Access to objects and sets of objects must be possible across module boundaries within a PowerShell session.
* Must support PowerShell on all platforms in which it is released, specifically PowerShell 5.1 (Desktop), and Powershell 6 and higher on Windows, Linux, and MacOS operating systems

## Architecture

ScriptClass employs the following features in accordance with the principles:

* Developers define sets of objects by supplying a PowerShell *[ScriptBlock]* that itself defines variables and functions. These variables and functions will define the state and method interface of the function respectively. A domain-specific language is used within the *[ScriptBlock]* to describe the set.
* The runtime representation of objects is the PowerShell *[PSCustomObject]* type
* Method invocation is accomplished by defining PowerShell functions that serve as a method invocation domain-specific language.
* The module exposes module methods for defining object sets and managing object lifecycles; since module methods are visible to other modules, definition and lifecycle functionality is accessible to all modules in the PowerShell session.

## User interface

ScriptClass surfaces object definition and lifecycle management through a functional programming style interface that builds on PowerShell's existing notion of "object."

### Concepts

The ScriptClass framework revolves around the following concepts:

* ScriptClass: A ScriptClass type is a user-supplied definition of a set of objects with common methods and properties. Conceptually ScriptClass conforms to the commonly understood notion of a programming language data type, specifically it is the equivalent of a type defined by the *class* keyword found in multiple languages including *PowerShell*, *C++*, *Java*, *C#*, *JavaScript*, *Ruby*, *Python*, and others. It differs from PowerShell's implementation of *class* primarily in its runtime state implementation and method invocation interface.
* ScriptObject: An instance of an object defined by a given ScriptClass. ScriptObjects have properties and methods that can be used to represent arbitrary data types and encapsulate them.
* Methods: ScriptClass methods conform to the standard concept of "method" in the object-oriented paradigm. A method is a parameterized computation specification that has access to the state of ScriptObject.
* Properties: Properties are the state of a ScriptObject, i.e. the data that represents an object. A property is itself an instance of a data type, and in the case of ScriptClass it can be an object of any data type supported by PowerShell (i.e. any .NET type), including those objects defined as ScriptClass types.
* Static vs. object (or instance) scope: Both properties and methods can be "bound" to either the entire set of objects of a type, or to a specific instance of a type. The former scope corresponds to the commonly understood concept of *static* in many OO language, and the latter maps to object or instance scope. Static methods are useful for encoding state or computation that is shared across all instances of a type.

### Language interface

While this design does not technically alter the PowerShell core language in any way, it does introduce new commands and associated data structure conventions that provide the "feel" of language changes such as new keywords, etc. The key interface elements are as follows:

* **Class (type) management:** Class management involves the definition of sets of objects in terms of their state and allowed operations, i.e. their properties and methods. Introspection on these definitions is also included in this role. Class management is typically considered to be the responsibility of the type system in object-oriented languages like those being emulated with ScriptClass.
* **Object management:** Objects are runtime state with a defined set of operations; the object management interface provides the ability to create (and for many languages to destroy) objects, to serialize and deserialize them, to compare them, etc.
* **Method and property access:** Objects are not useful without the ability to inspect them, modify them, and ask them to perform actions against other objects or state. Method and property access enable objects to represent concepts that change over time or according to events such as external input from users, objects, or other systems. Methods allow objects to provide an interface contract for concepts that they abstract, whether the concept is solely represented by the object's state or is actually state external to the object but managed by it.
* **Code management:** The type and object capabilities exposed by ScriptClass facilitate reuse. Code management enables that reusability to cross organizational artifact and component boundaries so that types may be defined once and reused across those boundaries. Specifically in the case of PowerShell, this means providing the ability to reuse types across script (`.ps1`) files in a PowerShell module and even across modules.
* **Unit testing support**: ScriptClass provides capabilities to enable unit testing of classes and objects managed by ScriptClass, namely the ability to mock classes and methods.

#### Class management features

Class management is provided by the following features:

* `New-ScriptClass [-ClassName] <string> [[-ClassBlock] <scriptblock>] [[-ArgumentList] <Object>] [<CommonParameters>]` command: The `New-ScriptClass` command allows developers to define classes (i.e. types) of objects. This class definition models the state (i.e. properties or fields) of an object. This command is the analog of the `class` keyword in PowerShell. The command takes the name of the class as a required parameter, as well as a *[ScriptBlock]* type. The result is a class definition syntax for `ScriptClass` that looks very much like the syntax for `class` in PowerShell. Class definitions defined by `New-SriptClass` exist in a runtime state available for the entire PowerShell session; classes defined by ScriptClass are visible to the entire session, i.e. they are global in scope.
  * `scriptclass` alias: Use of the `scriptclass` alias rather than `New-ScriptClass` is preferred as it makes class definitions align stylistically to the `class` keyword in many object-based languages including PowerShell's own `class` keyword.
* `#::` automatic variable: The `$::` automatic variable that has properties named for each defined class. The latter can be used to accessing methods or properties of defined at the class rather than instance scope (i.e. 'static' methods or properties). This variable is visible to the scope in which the ScriptClass module was imported.
* `New-ScriptClass [-ClassName] <string> [[-ClassBlock] <scriptblock>] [[-ArgumentList] <Object>] [<CommonParameters>]`: The `Get-ScriptClass` command provides information about classes that have been defined by `New-ScriptClass`.

Note that just as PowerShell allows for the redefinition of functions, `New-ScriptClass` allows for the redefinition of classes. This is actually also true of PowerShell's native `class` keyword. Most object-based languages do not allow for this and such an attempt would typically result in a compilation or runtime error depending on the language; an example where redefinition is allowed would be *Ruby*. As in the case where PowerShell allows for function redefinition, care must be taken with ScriptClass class redefinition to avoid non-deterministic behavior and other undesirable functionality defects.

##### Class definition syntax

`New-ScriptClass` requires the arguments `ClassName` and `ClassBlock`. The former is the name of the class, i.e. the unique name of the type that can subsequently be used to refer to the type, including at the point of object creation.

The latter `ClassBlock` parameter defines the structure of objects in the class, i.e. what it means to be a member of the class beyond just possessing some state with the name of the type. ScriptClass evaluates the block to define the class in the following way:

* Any functions defined within the block using PowerShell's `function` keyword are treated as methods of the class.
* Any variables defined within the block are treated as properties of the class with the same type and value
  as if they were defined in a function or script.
* The keywords `strict-val`, `static`, and `const` may appear in the block outside of any of the block's functions

The aforementioned keywords have syntax and semantics below:

* `<variable> = strict-val [-Type] <Object> [[-value] <Object>]  [<CommonParameters>]`: The `strict-val` keyword defines a property with the name of the variable specified by `<variable>` and the type specified by the `Type` parameter. An optional initial assignment to the property of the evaluated PowerShell expression may be specified by the `Value` parameter. The `Type` parameter must be specified using the syntax for PowerShell types, e.g. using brackets as in `[int]` for the .NET `int` type.
* `static [[-StaticBlock] <Object>]`: The `static` keyword takes the parameter `StaticBlock` as an argument which is interpreted in nearly the same way as the block supplied to `New-ScriptClass` to define methods and properties, but these methods and properties are associated not with objects of the class, but with the class itself. This provides a capability very similar to static methods in C++, C#+, and other languages.
* `New-Constant [-Name] <Object> [-Value] <Object>  [<CommonParameters>]`: The `const` keyword creates a constant property with the name specified by the `Name` parameter and assigns it the value `Value`. Such properties cannot be assigned to at runtime.
* `function`: The `function` keyword defines methods for the class with the same syntax as PowerShell functions defined by the `function` keyword. Such functions may invoke methods defined by the `function` keyword within the scriptblock in which they are located simply by calling them is if they were functions defined in the same PowerShell script. Code in the method blocks supplied to `function` may refer to a variable `$this` which for non-static methods refers to the object on which the method is executing, and for static methods refers to the class itself. Methods and properties of an object or class, including the `$this` object, are accessed according to the [method and property access](#Method-and-object-access) language interface.
* If a function named `__initialize` is defined in the block, this method is classified as the class's *constructor* method. This method is invoked after the object is created and before it is available for access by other code. The code for the `__initialize` method can use the `$this` variable just as any other method can, and in this context can use `$this` to set the initial state of the object's properties along with any other necessary actions. The `__initialize` method may take an arbitrary number of parameters like any PowerShell function; these parameters are specified by the code that invokes the creation of an object of the class. The `__initialize` method is an optional method of the `ClassBlock` parameter, so if it is not specified, no such method will be invoked upon object creation.

#### Object management features

The core object management features of ScriptClass are provided by the following commands:

* `New-ScriptObject [-ClassName] <string> [[-ArgumentList] <Object>]  [<CommonParameters>]`: This command creates and outputs a new object of the class named by the `ClassName` parameter. The array of objects specified to the `ArgumentList` parameter are passed to the `__initialize` method of the newly created object upon invocation of that method prior to `New-ScriptClass` returning it to the caller. This allows callers to perform parameterized initialization of objects. The objects returned by `New-ScriptObject` conform to the [ScriptClass Object Schema](#ScriptClass-Object-Schema).
  * `new-so` alias: The `new-so` alias is a more concise usage of `New-ScriptObject` and is preferred over the actual command. This brings the experience of instantiating new classes closer to that of other languages which typically use a `new` keyword or method to create a new object.
* `Test-ScriptObject [-Object] <Object> [[-Class] <Object>]  [<CommonParameters>]`: The `Test-ScriptObject` command returns information about the object specified by the `Object` parameter. It returns `$false` whenever the object is not a ScriptClass object, i.e. it does not conform to the [ScriptClass Object Schema). If the optional `Class` parameter is specified, it will also return `$false` if the object is a ScriptClass object, but is not an object of the class specified by the `Class` parameter.

##### ScriptClass Object Schema

Objects returned by `New-ScriptClass` are ScriptClass objects. They **MUST** conform to the schema that follows:

Let *O* be a ScriptClass object returned by `New-ScriptClass` of class *C* that has a set of Methods *M* and set of properties *P* where *M* and *P* correspond to the methods and properties of *C* as described in the earlier section on class definition syntax. For all *O*, the following are true:

  * *O* is of type `[PSCustomObject]`, a [documented core type](https://docs.microsoft.com/en-us/dotnet/api/system.management.automation.pscustomobject?view=pscore-6.2.0) of the PowerShell standard.
  * For each non-static method in *M* there is a `ScriptMethod` member of *O*
  * For each non-static property in *P* there is either a `NoteProperty` or `ScriptProperty` member of *O*
  * There is a `NoteProperty` member named `ScriptClass` referred to here as *S*
    * The property *S* is itself a ScriptClass object with the following configuration:
      * Its `ScriptClass` property is `$null`
      * There is a `ClassName` property that is a `[string]` set to the name of the class to which *O* belongs
      * It has a `Module` property of type `[PSModuleInfo]` that is the PowerShell module managed by `New-ScriptClass` in which the methods of *O* are bound
      * For each static method in *M* there is a `ScriptMethod` member of *S*
      * For each static property in *P* there is either a `NoteProperty` or `ScriptProperty` member of *S*

Because the schema above requires that all ScriptClass objects are `[PSCustomObject]` types, ScriptClass objects follow the same behaviors for serialization, deserialization, formatting, method invocation, property access, and any other object behaviors common to `[PSCustomObject]` instances.

#### Method and property access

Code consumes and manipulates objects by accessing their methods and properties:

* Because ScriptClass objects are all `[PSCustomObject]` instances, and all properties and methods of ScriptClass objects correspond directly to a particular `[PSCustomObject]` property or method, the same syntax used to access `[PSCustomObject]` methods and properties *MAY* be used on ScriptClass objects. The syntax is similar to that used in many languages including C#, C++, Java , JavaScript, Python, etc.
  * For properties, this approach uses a `.` to denote the reference of a property. The syntax looks like `$object.property` and `$object.property = expression` to read and write a property respectively.
  * To invoke a method, the `.` is also used, but a pair of matched parentheses are required and the list of arguments to the method, if any, must be contained within the parentheses as a comma-separated list. The syntax again resembles that of other languages based on objects: `$object.method(<argument-expression1>, <argument-expression2>, ..., <argument-expressionN>)`. However, this syntax for method invocation is discouraged as the use of parentheses and commas between arguments diverges from PowerShell's pipeline syntax that omits this punctuation when invoking functions; ScriptClass provides a syntax closer to that of PowerShell command and function invocation.
* `=>` and `::>` functions: These functions invoke methods on ScriptClass objects and they *SHOULD* be used in place of invoking methods using the standard `[PSCustomObject]` syntax for method invocation.
  * To invoke a method on a given object, the `=>` PowerShell function is provided. To invoke a method on an object's *static* (i.e. class-level) methods, the `::>` function is used.
  * To make these idiomatic, the object on which the method is piped to the `=>` or `::>` function, and the method name is provided as the first argument, followed by the arguments to the method.
  * Examples of the syntax include `$object |=> method <method-arg1> <method-arg2>` for a non-static function and `$object |::> staticmethod <method-arg1>` for a static function.
*`Invoke-Method [-Context] <Object> [-Action] <Object> [[-Arguments] <Object[]>]  [<CommonParameters>]`: This command invokes methods on both ScriptClass objects and non-ScriptClass objects. The method specified in the `Action` parameter is invoked on the object designed by the `Object` parameter, and the arguments from `Arguments` are passed to the method.
  * The `Action` parameter may also be a PowerShell ScriptBlock. When a ScriptBlock is provided, it is executed within the current PowerShell scope, and at execution time code in the ScriptBlock may reference a variable `$this` which is set to the value in the `$Object` parameter.

#### Code management features

In order to re-use objects packaged by different script files or .NET assemblies, some manner of referencing the packaging is required. ScriptClass provides the following commands to enable this re-use:

* `Import-Assembly [-AssemblyName] <string> [[-AssemblyRelativePath] <string>] [[-AssemblyRoot] <string>]`: This command is not strictly necessary for ScriptClass to fulfill its mission, but it helps generalize the access of types from .NET assemblies by allowing a convenient way to load a .NET assembly into the calling PowerShell session. To load a given assembly, use the `$AssemblyName` or `$AssemblyRelativePath` parameter to specify either a name or a known path to an assembly.
* `Import-Script [-Path] <Object> [[-Parent] <Object>] [-AnyExtension]  [<CommonParameters>]`: The `Import-Script` command returns a ScriptBlock that can dot-source the script file referred to in the `$Path` parameter into the current scope. If the file has already been imported, an empty ScriptBlock is returned. This facilitates the commonly accepted model of packaging exactly one definition of the language's *class* concept into a single file. Code in files that must consume a particular class can simply refer to it with this command using this kind of syntax: `. (Import-Script display/Table)`.
  * The `Path` parameter is not truly a path as by default the `.ps1` extension of the file must be omitted.
* Module visibility: Classes defined by `New-ScriptClass` are visible to all code within and below the scope at which the ScriptClass module was imported. ScriptClass classes share the visibility of the ScriptClass module. This means ScriptClass classes can be shared across modules.
  * A class *X* is *visible* to module *M* if the `$::` operator when accessed by *M* has a member with the name of class *X* and the `New-ScriptObject` command when invoked by *M* successfully returns a ScriptClass object of class *X*
  * If three modules *A*, *B*, and *C* are imported into a session, and class *X* is defined in module *A*, it is *visible* in *B* and *C*.
  * The previous statement is true even if *A* is a nested module of *B* or *C*
  * It is also true if *A* is a nested module of *B* and *B* is a nested module of *C*

#### Unit testing features

Unit testing capabilities for ScriptClass are based on [Pester](https://github.com/pester/Pester), PowerShell's standard unit testing framework. While Pester provides robust support for mocking PowerShell functions, it does not have support for mocking object methods on .NET or `[PSCustomObject]` types specifically. ScriptClass objects, which are `[PSCustomObjects]` defined as types within ScriptClass's own extended type system, are therefore not mockable strictly using functionality available from Pester.

ScriptClass provides the following commands below which abstract details about the implementation of ScriptClass so that a reliable public interface for mocking is available to users. The commands below allow for mocking of methods defined by `New-ScriptClass` so that they may be used within Pester `It` block test cases.

* `Add-ScriptClassMock [-MockTarget] <Object> [-MethodName] <string> [[-MockWith] <scriptblock>] [[-ParameterFilter] <scriptblock>] [-MockContext <Object>] [-Static] [-Verifiable]  [<CommonParameters>]`: This command allows the caller to replace a specified method of a class or object with a caller-defined method implementation. If the `MockTarget` parameter is a string, this target of the mock is interpreted to be the class with the name specified by `MockTarget` and all objects of that class will have the method mocked. If `MockTarget` is a ScriptClass object, then only the method on that specific object will be mocked. The command supports both static and non-static methods via the `Static` parameter. The `ParameterFilter` and `Verifiable` parameters have the same semantics as in Pester's [`Mock` function](https://github.com/pester/Pester/wiki/Mock).
* `Add-MockInScriptClassScope [-ClassName] <string> [-CommandName] <string> [-MockWith] <scriptblock> [-MockContext <Object>] [-ParameterFilter <scriptblock>] [-Verifiable]  [<CommonParameters>]`: This command allows PowerShell functions to be mocked when invoked from ScriptClass methods. Pester's `Mock` function is not able to affect ScriptClass methods. This command enables the functionality of `Mock` within the context of the specific class specified by the `ClassName` parameter.
* `New-ScriptObjectMock [-ClassName] <Object> [-MethodMocks <hashtable>] [-PropertyValues <hashtable>] [-ModuleName <string>] [<CommonParameters>]`: This command creates a mock object of the given class; this object has the same set of properties and methods as an object of that class created by `New-ScriptObject`. The key difference is that the class's constructor is not invoked for this object, and the command allows the object's property values be specified arbitrarily rather than limited by the original implementation's dictates. An array of mocked methods may also be supplied. This is useful for creating synthetic objects with custom implementations rather than creating a real version of the object and individually overriding each method with mock functions.
* `Remove-ScriptClassMock [-MockTarget] <Object> [[-MethodName] <string>] [[-Static]]  [<CommonParameters>]`: The `Remove-ScriptClassMock` command undoes the effect of `Add-ScriptClassMock`. It is generally not required for normal testing, but could be useful for building more advanced ScriptClass unit-testing capabilities.

#### Examples: Compare ScriptClass with the PowerShell class keyword

Below is a set of examples that gives a side-by-side view of comparable object-oriented scenarios. In most cases, the differences between the two are minimal, and in general the mapping between them in either direction is deterministic.

##### Simple class declaration, creation, and usage

<table>
    <tr><td>PowerShell class</td><td>ScriptClass</td><tr>
    <tr>
<td>

```powershell
class Person {
    $Id
    $Name
}

$person = [Person]::new()

$person.Id = new-guid
$person.Name = 'George Carver'
```
</td>
<td>

```powershell
scriptclass Person {
    $Id = $null
    $Name = $null
}

$person = new-so Person

$person.Id = new-guid
$person.Name = 'George Carver'
```
</td>
    </tr>
</table>

##### Creating instances with parameterized constructors

<table>
    <tr><td>PowerShell class</td><td>ScriptClass</td><tr>
    <tr>
<td>

```powershell
class Person {
    $Id = $null
    $Name = $null

    Person([Guid] $id, [String] $name) {
        $this.Id = $id
        $this.Name = $name
    }
}

$person = [Person]::new('7b03e505-6784-44ef-b314-34fc98809082', 'George Carver')

```
</td>
<td>

```powershell
scriptclass Person {
    $Id = $null
    $Name = $null

    function __initialize([Guid] $id, [String] $name) {
        $this.Id = $id
        $this.Name = $name
    }
}

$person = new-so Person 7b03e505-6784-44ef-b314-34fc98809082 'George Carver'
```
</td>
    </tr>
</table>

##### Declaring and using instance methods

<table>
    <tr><td>PowerShell class</td><td>ScriptClass</td><tr>
    <tr>
<td>

```powershell
class Complex {
    $Real = 0
    $Imaginary = 0

    Complex($real, $imaginary) {
        $this.Real = $real
        $this.Imaginary = $imaginary
    }

    [double] GetMagnitude() {
        return [Math]::Sqrt($this.Real * $this.Real + $this.Imaginary * $this.Imaginary)
    }

    [void] AddTo($other) {
        $this.Real += $other.Real
        $this.Imaginary += $other.Imaginary
    }
}

$first = [Complex]::new(3,4)
$first.GetMagnitude()

$second = [Complex]::new(2,8)
$first.AddTo($second)

$first.GetMagnitude()
```
</td>
<td>

```powershell
scriptclass Complex {
    $Real = 0
    $Imaginary = 0

    function __initialize($real, $imaginary) {
        $this.Real = $real
        $this.Imaginary = $imaginary
    }

    function GetMagnitude {
        [Math]::Sqrt($this.Real * $this.Real + $this.Imaginary * $this.Imaginary)
    }

    function AddTo($other) {
        $this.Real += $other.Real
        $this.Imaginary += $other.Imaginary
    }
}

$first = new-so Complex 3 4
$first |=> GetMagnitude

$second = new-so Complex 2 8
$first |=> AddTo $second

$first |=> GetMagnitude
```
</td>
    </tr>
</table>

##### Referencing methods from within methods
<table>
    <tr><td>PowerShell class</td><td>ScriptClass</td><tr>
    <tr>
<td>

```powershell
class Converter {
    [ValidateRange(2, 36)] $radix

    Converter($radix) {
        $this.radix = $radix
    }

    [int] Convert($number) {
        $placeValue = 1
        $result = 0
        for ( $index = $number.length - 1; $index -ge 0; $index-- ) {
            $value = $this.GetValue($number[$index])
            $result += $value * $placeValue
            $placeValue *= $this.radix
        }
        return $result
    }

    [int] GetValue($digit) {
        $normalized = [char]::ToLowerInvariant($digit)

        $value = if ( $normalized -lt 'a' ) {
            [int] $normalized - [byte][char]'0'
        } else {
            [int] ([byte][char] $normalized - [byte][char]'a' + 10)
        }
        return $value
    }
}

$converter = [Converter]::new(16)
$converter.Convert('A1')
```
</td>
<td>

```powershell
scriptclass Converter {
    $radix = $null

    function __initialize([ValidateRange(2,36)] $radix) {
        $this.radix = $radix
    }

    function Convert($number) {
        $placeValue = 1
        $result = 0
        for ( $index = $number.length - 1; $index -ge 0; $index-- ) {
            $value = GetValue $number[$index]
            $result += $value *$placeValue
            $placeValue *= $this.radix
        }
        $result
    }

    function GetValue($digit) {
        $normalized = [char]::ToLowerInvariant($digit)

        $value = if ( $normalized -lt 'a' ) {
            [int] $normalized - [byte][char]'0'
        } else {
            [int] ([byte][char] $normalized - [byte][char]'a' + 10)
        }
        $value
    }
}

$converter = new-so Converter 16
$converter |=> Convert A1
```
</td>
    </tr>
</table>



##### Static members
<table>
    <tr><td>PowerShell class</td><td>ScriptClass</td><tr>
    <tr>
<td>

```powershell
class SchemaManager {
    static $singleton = $null

    static [SchemaManager] Get() {
        if ( ! [SchemaManager]::singleton ) {
            [SchemaManager]::singleton = [SchemaManager]::new()
        }
        return [SchemaManager]::singleton
    }

    $schemas

    SchemaManager() {
        if ( $this::singleton ) {
            throw 'Instance already exists'
        }
        $this.schemas = @{}
    }

    [void] AddSchema($schemaName, $schema) {
        $this.schemas.Add($schemaName, $schema)
    }

    [object] GetSchema($schemaName) {
        return $this.schemas[$schemaName]
    }
}

$manager = [SchemaManager]::Get()

$manager.AddSchema('v1.0', $v1Schema)
$manager.AddSchema('beta', $betaSchema)
$manager.GetSchema('v1.0')



```
</td>
<td>

```powershell
scriptclass SchemaManager {
    static {
        $singleton = $null

        function Get {
            if ( ! $this.singleton ) {
                $this.singleton = new-so SchemaManager
            }
            $this.singleton
        }
    }

    $schemas = $null

    function __initialize {
        if ( $this.scriptclass.singleton ) {
            throw 'Instance already exists'
        }
        $this.schemas = @{}
    }

    function AddSchema($schemaName, $schema) {
        $this.schemas.Add($schemaName, $schema)
    }

    function GetSchema($schemaName) {
        $this.schemas[$schemaName]
    }
}

$manager = $::.SchemaManager |=> Get

$manager |=> AddSchema v1.0 $v1Schema
$manager |=> AddSchema beta $betaSchema
$manager |=> GetSchema v1.0
```
</td>
    </tr>
</table>

##### Strong typing
<table>
    <tr><td>PowerShell class</td><td>ScriptClass</td><tr>
    <tr>
<td>

```powershell
class Complex {
    [double] $Real
    [double] $Imaginary

    Complex([double] $real, [double] $imaginary) {
        $this.Real = $real
        $this.Imaginary = $imaginary
    }

    [double] GetMagnitude() {
        return [Math]::Sqrt($this.Real * $this.Real + $this.Imaginary * $this.Imaginary)
    }

    [void] AddTo([Complex] $other) {
        $this.Real += $other.Real
        $this.Imaginary += $other.Imaginary
    }
}

[Complex]::new(3, 'A')

# Cannot convert argument "imaginary", with value: "A", for ".ctor" to type
# "System.Double": "Cannot convert value "A" to type "System.Double". Error:
# "Input string was not in a correct format.""


```
</td>
<td>

```powershell
scriptclass Complex {
    $Real = strict-val [double]
    $Imaginary = strict-val [double]

    function __initialize([double] $real, [double] $imaginary) {
        $this.Real = $real
        $this.Imaginary = $imaginary
    }

    function GetMagnitude {
        [Math]::Sqrt($this.Real * $this.Real + $this.Imaginary * $this.Imaginary)
    }

    function AddTo($other) {
        $this.Real += $other.Real
        $this.Imaginary += $other.Imaginary
    }
}

new-so Complex 3 A

# new-so : Exception calling "InvokeScript" with "2" argument(s): "Exception
# calling "InvokeWithContext" with "3" argument(s): "Cannot convert value "A"
# to type "System.Double". Error: "Input string was not in a correct format."""
```
</td>
    </tr>
</table>

##### Constants
<table>
    <tr><td>PowerShell class</td><td>ScriptClass</td><tr>
    <tr>
<td>

```powershell
class Logger {
    static $LOG_TEMPLATE = "{0} PID={1} {2}"

    $entries = @()

    [void] Log($message) {
        $this.entries += [PSCustomObject] ($this::LOG_TEMPLATE -f [DateTimeOffset]::Now, $global:PID, $message)
    }

    [PSCustomObject[]] GetEntries() {
        return $this.entries
    }
}

$logger = [Logger]::new()

$logger.Log('First entry')
$logger.Log('Second entry')

$logger.GetEntries()





```
</td>
<td>

```powershell
scriptclass Logger {
    static {
        const LOG_TEMPLATE "{0} PID={1} {2}"
    }

    $entries = $null

    function __initialize() { $this.entries = @() }

    function Log($message) {
        $this.entries += [PSCustomObject] ($this.scriptclass.LOG_TEMPLATE -f [DateTimeOffset]::Now, $PID, $message)
    }

    function GetEntries() {
        $this.entries
    }
}

$logger = new-so Logger

$logger |=> Log 'First entry'
$logger |=> Log 'Second entry'

$logger |=> GetEntries

```
</td>
    </tr>
</table>

##### Accessing script variables
<table>
    <tr><td>PowerShell class</td><td>ScriptClass</td><tr>
    <tr>
<td>

```powershell
class ProcessFormatter {
    static $PreferenceVariable = $null

    $purpose = $null

    ProcessFormatter($processPurpose) {
       $this.purpose = $processPurpose
    }
    [string] Format() {
        $format = if ( $this::PreferenceVariable -and $this::PreferenceVariable.Name -eq 'ProcessFormatterPreference') {
            $this::PreferenceVariable.value
        } else {
            '{1}: PID={0:x}'
        }
        return $format -f $this.purpose, $global:PID
    }
}

$formatter = [ProcessFormatter]::new()
$formatter.Format()

$ProcessFormatterPreference = '({1}: 0x{0:x}'
[ProcessFormatter]::PreferenceVariable = Get-Variable ProcessFormatterPreference

$formatter.Format()





```
</td>
<td>

```powershell
$ProcessFormatterPreference = '[{1}] 0x{0:x}'

scriptclass ProcessFormatter -ArgumentList (Get-Variable ProcessFormatterPreference) {
    param($preferenceVariableParameter)

    static {
        $PreferenceVariable = $preferenceVariableParameter
    }

    $purpose = $null

    function __initialize($processPurpose) {
       $this.purpose = $processPurpose
    }

    function Format {
        $format = if ( $this.scriptclass.PreferenceVariable -and $this.scriptclass.PreferenceVariable.Name -eq 'ProcessFormatterPreference') {
            $this.scriptclass.PreferenceVariable.value
        } else {
            '{1}: PID={0:x}'
        }
        $format -f $PID, $this.purpose
    }
}

$formatter = new-so ProcessFormatter Testing2
$formatter |=> Format

$ProcessFormatterPreference = '{1} - 0x{0:x}'
$formatter |=> Format
```
</td>
    </tr>
</table>

## Implementation

### Dependencies and platform support

ScriptClass has few dependencies and thus may be used for just about any application of PowerShell; this also minimizes maintenance requirements for applications using ScriptClass:

* Build (developer scenarios): Building ScriptClass requires the Windows or Linux platform, PowerShell 5.1 and higher (6.0 and higher required on Linux), the [Pester](https://gitub.com/pester/Pester) PowerShell module, and [NuGet](https://nuget.org) command line tool.
* Runtime language dependency: ScriptClass is implemented exclusively in PowerShell (e.g. no C#), no additional runtimes or languages are required at runtime.
* PowerShell version: ScriptClass requires PowerShell 5.1 and higher
* Platforms: ScriptClass supports Windows, Linux, and MacOS platforms. Theoretically, it can execute on any platform where PowerShell is supported.

### Source organization

Functionality in ScriptClass is expressed using two main styles of organization:

* PowerShell classes: Most of the code in ScriptClass is componentized as PowerShell classes expressed through the `class` keyword. This provides a well-defined, if somewhat awkward, mechanism for organization and reuse. Each class resides in exactly one source file, and the source file should have the same name as the class.
* PowerShell advanced function commands: Advanced functions (i.e. functions that are decorated with attributes such as [cmdletbinding()]) are used in ScriptClass to provide user interface, i.e. for commands. Commands cannot be easily expressed as classes, but can be concisely and intuitively implemented as advanced functions. In most cases, these advanced functions are simply thin wrappers around the core functionality provided in the class-organized code. Each advanced function / command exists in a file named after the command.

In general, no code exists outside of the contexts above, e.g. PowerShell functions that are not commands exposed by the ScriptClass module should be exist; such functions should be (possibly static) methods in some PowerShell class instead. An exception would be declarations of variables that are exported from the module, or functions required as part of an interface to PowerShell functionality being used by ScriptClass.

The irony of ScriptClass, the putative replacement for the inadequate PowerShell `class` implementation, being built upon `class` is not lost. However, the concerns about `class` were not that it could not be used to build applications, just that it could not be used to do so intuitively. The reality is that with enough persistence and focus, `class` is quite suitable for building a complex application, just as long as one is willing to do this using a PowerShell-like language rather than actual idiomatic PowerShell.

### Components

This section describes the components that implement the ScriptClass class definition, object management, and mock functionality. The code sharing capabilities implemented by `Import-Script` and `Import-Assembly` are sufficiently straightforward and somewhat less central to the primary utility of ScriptClass that they are not covered here.

The diagram below shows the directory structure of the `scriptobject` directory of the ScriptClass source; the files within this directory, shown here without their `.ps1` extensions, contains PowerShell classes with the same name as the file:

    scriptobject
    │   ClassManager
    ├───common
    │       ClassDefinition
    │       NativeObjectBuilder
    │       ScriptClassSpecification
    ├───dsl
    │       ClassDsl
    │       MethodDsl
    ├───type
    │       ClassBuilder
    │       ScriptClassBuilder
    ├───mock
            MethodMocker
            MethodPatcher
            PatchedClassMethod
            PatchedObject

The responsibilities and capabilities of each of the classes is given in the following sections.

#### ClassManager

The `ClassManager` class exists as a singleton and contains methods for the following types of operations:

* Get method: a static method that gets the singleton
* Class definition
* Object creation

The classes and objects created by this class are available to the entire PowerShell session regardless
of PowerShell scope or module boundaries, though the class itself is only visible within the *ScriptClass* module.

#### Common directory

This directories contains classes used throughout the implementation of script objects.

#### Common/ClassDefinition

The `ClassDefinition` class of objects model a given class definition managed by *ScriptClass*. It is abstracted
from any implementation of class or object -- it is intended to be used to reflect on classes or objects or
to translate to some concrete implementation. There are additional classes defined largely as part of the interface
for `ClassDefinition`.

`ClassDefinition` presents the following interface:

* Constructor: takes in the name of the class to define, static methods and properties via instances of the `Method` and `Property` types respectively, non-static methods and properties using those same types, and the name of the method used as the constructor of the object.
* The name of the class
* Properties, both static and non-static, of a class of objects, including their types (from initialization)
* Methods, both static and non-static, of a class of objects (from initialization)

The additional classes used for more detailed modeling classes follow:

* `Property`: This class models static or non-static properties of *ScriptObject*.
* `Method`: The `Method` class models static or non-static methods of a *ScriptObject*.
* `TypedValue`: Models an initial (possibly `$null`) value assigned to a property and explicitly declares its data type
* `ClassInfo`: Encapsulates both the abstract model of the class through a `ClassDefinition` along with a concrete prototype object that can be used as a template for creating new objects of the class. It also includes a module as a `PSModuleInfo` in which the class's properties and methods reside.

#### Common/NativeObjectBuilder

The `NativeObjectBuilder` class models an object that constructs objects with a particular implementation. For
`NativeObjectBuilder`, the native implementation is simply PowerShell's `PSCustomObject` type. By calling sequences of
methods to add methods and properties, a `PSCustomObject` object can be built to whatever configuration is required.
Objects of this class contain the following methods:

* Constructor: Takes in an optional type name, an optional prototype to start with, and a mode for create or modify actions
* AddMethod -- adds a method to the target object being built
* AddProperty -- adds a property to the target
* AddMember -- adds a generic member (essentially an member type that can be added to a `PSCustomObject`) to the target object
* RemoveMember -- removes a member
* CopyFrom -- sets the state of the target object to mirror the properties and methods of an existing source object
* GetObject -- gets the target object as currently built
* RegisterClassType -- registers the target object as a type in PowerShell's formatting and type system to control how it is displayed and serialized.

Additional behavior notes:

* An instance of this class can be initialized to construct a new object, with or without an associated type that will be included as one of the type names for the resulting `PSCustomObject`.
* The prototype argument of the constructor allows construction to start the target result object with a set of properties from an existing object rather than empty sets.
* The constructor's mode argument allows either modification of a pre-existing object, or creation of a completely new object.

#### Common/ScriptClassSpecification

`ScriptClassSpecification` is a singleton that defines the names of core language features of *ScriptClass*, including the
names of operators used to invoke methods, common properties, *ScriptClass* class definition DSL keywords, the name
of the constructor method of a class, etc.

It is used throughout *ScriptClass* whenever these definitions are required. This provides one location of in-source documentation
for key aspects of the language and also makes it easy to experiment with new UX by hanging the definitions centrally.

#### Dsl directory

This directory contains classes that interpret and execute the *ScriptClass* domain-specific language (DSL) for defining classes and manipulating objects.

#### Dsl/ClassDsl

The `ClassDsl` class interprets a PowerShell `ScriptBlock` supplied as the definition of a class. Certain code fragments of the `ScriptBlock` define methods on the class, others define properties, and certain keywords augment those properties and methods. `ClassDsl` has the following public interface:

##### ClassDefinitionContext
An associated class `ClassDefinitionContext` provides objects with a structure used when interacting with `ClassDsl`. This can be thought of as an intermediate representation of the class defined by `ClassDsl` -- it has a `ClassDefinition` that is the abstract definition of the class, but also binds the definition to PowerShell modules represented by `PSModuleInfo` structures.

This binding is required because the properties, methods, and other runtime state associated with *ScriptClass* class definitions are concretely implemented as formal PowerShell lexical elements. All such PowerShell runtime state can be scoped to a dynamic PowerShell module. *ScriptClass* scopes the concrete PowerShell aspects of the class definition to a module in order to ensure that definitions are completely isolated from each other.

`ClassDefinitionContext` has the following interface:

* Constructor: Takes in the remaining properties in this list
* The abstract `ClassDefinition` structure for the class
* A `PSModuleInfo` that hosts properties and methods for objects of the class
* A `PSModuleInfo` that hosts static properties and methods of the class

#### Dsl/MethodDsl

The functions defined in this file are direct components of the *ScriptClass* UX:

* The `=>` function: This is the function that invokes a method of an object through the syntax `object |=> method`.
* The `::>` function: This is the function that invokes static methods when supplied with an object or the name of a class, e.g. `object |::> staticmethod`  `'classname' |::> staticmethod`.

#### Type directory

These subdirectories contain classes related to the modeling of classes defined by *ScriptClass*.

#### Type/ClassBuilder

The `ClassBuilder` class provides common functionality for building a representation of a class objects. It is used as a base class for the `ScriptClassBuilder` class. It takes a dependency on `NativeObjectBuilder` to build the representation as a `PSCustomObject` -- the idea here is to represent classes in a way that the native runtime, i.e. PowerShell, already understands. The resulting class represented as a `PSCustomObject` can then take advantage of PowerShell's overall ability to manipulate such objects.

The interface of `ClassBuilder` is omitted here as its sole purpose currently is to provide functionality for use by `ScriptBuilder`, the class utilized by other parts of the *ScriptClass* object framework.

#### Type/ScriptClassBuilder

The `ScriptClassBuilder` class is used to build a generic class through a series of method calls for adding system properties and system methods to the class being built. It contains the following methods:

* Constructor: Takes in the name of the class to be defined, and a `ScriptBlock` utilizing the ScriptClass DSL to define the class.
* ToClassInfo: After initialization of an object, this method can be used to obtain a `ClassInfo` object that contains the abstract model of the class along with other class metadata.

#### Mock directory

The functions in this directory enable mocking of *ScriptClass* objects and methods. Mocking in this context is enabled through Pester and the mock-related commands exposed through *ScriptClass* must be used within the context of a Pester script in the same way as Pester's own mock commands.

See the help / documentation for the commands themselves for details on how to use them from within a Pester script.

Note that unlike other aspects of the ScriptObject implementation, PowerShell classes are not used to implement mock support. Instead, source is organized into "logical classes" using functions. The functions follow a naming convention where each function is prefixed with the name of the file that contains them; this prefix denotes the logical "class" to which the function is associated. Thus the functions themselves are "methods" of the associated logical class.

#### Mock/MethodMocker

The `MethodMocker` logical class provides the core support for mocking a method. Methods can be mocked for individual objects, and also for an entire class of objects. `MethodMocker` is a singleton, and it supports the following logical methods:

* Get: Gets the singleton instance of `MethodMocker`
* Mock: Given an object or class as a target, mocks a specified method of the target with replacement `ScriptBlock`. After `Mock` is invoked, when the method of the target is invoked, the replacement `ScriptBlock` will be invoked instead of the `ScriptBlock` of the original method.
* Unmock: Removes a mock configured by Mock

`MethodMocker` uses `MethodPatcher` to configure the replacement `ScriptBlock` for a method.

#### MethodPatcher

The `MethodPatcher` class "patches" a class or object with replacement methods that can invoke the original method or a new replacement method. Patching a method does not change the behavior of that method on an object or class, it merely makes it "mockable" by Pester. `MethodPatcher` has the following interface:

* Get: Gets the singleton instance of `MethodPatcher`
* PatchMethod: replaces the `ScriptBlock` for the specified method with an intermediate function that calls the original method. This `ScriptBlock` calls into a PowerShell function that itself invokes the original `ScriptBlock` associated with the method. Since the function is just a normal PowerShell function, it can be mocked by Pester like any function.
* UnpatchMethod: removes the intermediate method and restores the original state of the class or object.
* GetPatchedMethods: gets all the methods that have been patched for the entire PowerShell session
* QueryPatchedMethods: returns all the patched methods based on search criteria such as an object or class name.

#### PatchedClassMethod

The `PatchedClassMethod` class models the methods patched by `MethodPatcher`. For each method of a given class, there is one `PatchedClassMethod` instance. It contains methods that return information about the method including the mock code that should be invoked in place of the real method. The scope of the mock is also modeled here, i.e. whether it is for all instances of the *ScriptClass* object or specific instances.

The methods of this class are very much tied to the integration between *ScriptClass* and Pester that allows Pester to be used for mocking -- the interface of this class is likely to undergo significant changes as the integration improves and more mocking scenarios are added or fixed.

When a specific object's method is patched, instances of `PatchedClassMethod` will reference an instance of `PatchedObject`. All instances of a class with a particular method mocked will have exactly one associated `PatchedClassMethod` instance tracking all the objects with that method patched.

#### PatchedObject

The `PatchedObject` class describes an actual *ScriptClass* object that has been patched so that it can be mocked. Instances of this class are actually referenced by `PatchedClassMethod` which tracks all the instance objects of a given class that have had a particular method patched.

The object-specific mock code for the method is part of this object's state, as is the actual object on which the method was patched.

### Common data flows

TODO. This section will describe the relationships between the classes described above.

## Future improvements

* Private methods -- *class* supports this via the `hidden` keyword
* Single inheritance -- supported by *class*
* Interface inheritance -- also supported by *class*
* Namespaces
* Private module visibility -- supported by *class* via `using module`
* Using `.` instead of `=>` and `::>` for method invocation

### Improving *class* itself

What can be learned from ScriptClass and its use compared to *class*`? Based on using *scriptclass* in production projects, my assessment is that the value lies in the following:

> *ScriptClass* classes allow you to retain familiar PowerShell syntax when defining and consuming classes.

This is captured by the following features of ScriptClass that stand in contrast to *class*:

* Ability to define methods using familiar *function* syntax rather than the more rigid C# style syntax: ScriptClass lets you omit the return statement, declared return type, and parentheses for parameter-less methods
* Methods can use the pipeline to emit results
* Method invocation syntax is PowerShell command-style, including both positional and named parameters. You don't need to use parentheses and commas -- standard PowerShell syntax continues to apply at method invocation
* Intra-class method references do not require the use of `$this` -- the method may simply be treated like any other PowerShell function

## History

Here is the timeline of key milestones in the development of this module:

* September 2017: First *stdposh* module proof of concept to define types of [PSCustomObject] instances using a functional flavor of the syntax for *class*. This was achieved after experimentation with various features of the PowerShell language that might provide this capability including nested functions and decoration via attributes
* December 2017: Use of nested modules rather than `ScriptsToProcess` for some module isolation
* January 2018: Moved instance methods from per-object to per-class for better efficiency
* February 2018: Renamed *stdposh* to *ScriptClass*!
* December 2018: Added mocking support built on *Pester*
* February 2019: PowerShell core and Linux support
* September 2019: Refactor 2.0 -- significant rewrite from ad-hoc for complete isolation of *ScriptClass* module internals that were previously leaked to module consumers; more intentional and modular factoring of components and source code
