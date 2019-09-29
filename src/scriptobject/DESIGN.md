ScriptClass Design
==================

This document provides a high-level description of the component design of the ScriptClass
extensions to PowerShell.

## Motivation

The overall goal for the ScriptClass module as a whole can be stated as follows:

> The ScriptClass module is intended to facilitate the development of PowerShell-based applications rather than just scripts or utilities that comprise the typical PowerShell use case.

Why does PowerShell need ScriptClass to enable serious application development? The [Overview document](https://github.com/adamedx/scriptclass/blob/master/docs/Overview.md) document goes into this in detail: PowerShell, even as of versions 5 and 6 provides at best awkward support for object-based methodologies for code factoring and reuse. Most large-scale application development requires some consistent organizational principle to allow developers to reason over and maintain larger codebases; object-oriented approaches such as those in C++, Java, C#, Python, Ruby, Javascript, and many others have done this successfully enough for developers to work on large codebases and more importantly to deliver complex but reliable systems with the work of hundreds or even thousans of developers.

ScriptClass attempts to fill this gap in PowerShell by extending owerShell's typical imperative / functional hybrid syntax to support types (i.e. classes) and objects, and to so without the "bolted on" feel of PowerShell's class keyword.

## Design principles

In bringing object orientation to PowerShell, the following principles are a guide:

* Favor the use of existing PowerShell concepts and features over implementing and introducing new concepts and features
* Derive inspiration for user experience from object-based dynamic languages like Python, Ruby, and Javascript
* Object-orientation should feel idiomatic and intuitive with respect to PowerShell
* Prefer building on existing PowerShell concepts and syntax where possible rather than replacing them
* The initial implementation should be PowerShell-based -- a native implementation in the PowerShell language itself should wait until this approach has wider community feedback and validation

## Requirements

ScriptClass must provide the following capabilities to developers through PowerShell:

* The functinoality of the library must be exposed as a module to consumers
* Ability to define a set of objects by the methods they expose and the structure of their internal state
* The library must represent and manage the runtime state of the objects
* The library must provde a way to invoke methods on the objects
* The library's internal state must not be accessible outside the boundary of its module -- users must interact with objects
  and object definitions strictly through public interfaces explicitly exposed by the module
* Access to objects and sets of objects must be possible across module boundaries within a PowerShell session.
* Must support PowerShell on all platforms in which it is released, specifically PowerShell 5.1 (Desktop), and Powershell 6 and higher on Windows, Linux, and MacOS operating systems

## Architecture

ScriptClass employs the following decisions in accordance with the principles:

* Developers define sets of objects by supplying a PowerShell *[ScriptBlock]* that itself defines variables and functions. These variables and functions will define the state and method interface of the function respectively. A domain-specific language is used within the *[ScriptBlock]* to describe the set.
* The runtime representation of objects is the PowerShell *[PSCustomObject]* type
* Method invocation is accomplished by defining PowerShell functions that serve as a method invocation domain-specific language.
* The module exposes module methods for defining object sets and managing object lifecycles; since module methods are visible to other modules, definition and lifecycle functionality is accessible to all modules in the PowerShell session.

## User interface

ScriptClass surfaces object definition and lifecycle management through a functional-programming style interface that builds on PowerShell's existing notion of "object."

### Concepts

The ScriptClass framework revolves around the following concepts:

* ScriptClass: A ScriptClass is a user-supplied definition of a set of objects with common methods and properties. Conceptually ScriptClass conforms to the commonly understood notion of a programming language data type, specifically it is the equivalent of a type defined by the *class* keyword found in multiple languages including *PowerShell*, *C++*, *Java*, *C#*, *JavasScript*, *Ruby*, *Python*, and others. It differs from PowerShell's implementation of *class* primarly in its runtime state implementation and method invocation interface.
* ScriptObject: An instance of an object defined by a given ScriptClass. ScriptObjects have properties and methods that can be used to represent arbitrary data types and encapsulate them.
* Methods
* Properties
* Static vs. object scope:

### Language interface

While this design does not technically alter the PowerShell core language in any way, it does introduce new commands and associated data structure conventions that provide the "feel" of language changes such as new keywords, etc. The key interface elements are as follows:

* **Class (type) management:** Class management involves the definition of sets of objects in terms of their state and allowed operations, typically termed properties and members respectively. Introspection on these definitions is also included in this role. Class management is typically considered to be the responsibility of the type system in object-oriented languages like those being emulated with ScriptClass.
* **Object management:** Objects are runtime state with a defined set of operations; the object management interface provides the ability to create (and for many languages to destroy) objects, to serialize and deserialize them, to compare them, etc.
* **Method and property access:** Objects are not useful without the ablity to inspect them, modify them, and ask them to perform actions against other objects or state. Method and property access enable objects to represent concepts that change over time or according to events such as external input from users, objects, or other systems. Methods allow objects to provide an interface contract for concepts that they abstract, whether the concept is solely represented by the object's state or is actually state external to the object but managed by it.
* **Code management:** The type and object capabilities exposed by ScriptClass facilitate reuse. Code management enables that reusability to cross organizational artifact and component boundaries so that types may be defined once and reused across those boundaries. Specifically in the case of PowerShell, this means providing the ability to reuse types across script (`.ps1`) files in a PowerShell module and even across modules.
* **Unit testing support**: ScriptClass provides capabilties to enable unit testing of classes and objects managed by ScriptClass, namely the ability to mock classes and methods.

#### Class management features

Class management is provided by the following features:

* `New-ScriptClass` command: The `New-ScriptClass` command allows developers to define classes (i.e. types) of objects. This class definition models the state (i.e. properties or fields) of an object. This command is the analog of the `class` keyword in PowerShell. The command takes the name of the class as a required parameter, as well as a *[ScriptBlock]* type. The result is a class definition syntax for `ScriptClass` that looks very much like the syntax for `class` in PowerShell. Class definitions defined by `New-SCriptClass` exist in a runtme state available for the entire PowerShell session; classes defined by ScriptClass are visible to the entire session, i.e. they are global in scope.
  * `scriptclass` alias: Use of the `scriptclass` alias rather than `New-ScriptClass` is preferred as it makes class definitions align stylistically to the `class` keyword in many object-based languages including PowerShell's own `class` keyword.
* `#::` automatic variable: The `$::` automatic variable that has properties named for each defined class. The latter can be used to accessing methods or properties of defined at the class rather than instance scope (i.e. 'static' methods or properties). This variable is visible to the scope in which the ScriptClass module was imported.
* `Get-ScriptCass`: The `Get-ScriptClass` command provides information about classes that have been defined by `New-ScriptClass`.

Note that just as PowerShell allows for the redefinition of functions, `New-ScriptClass` allows for the redefinition of classes. This is actually also true of PowerShell's native `class` keyword. Most object-based languages do not allow for this and such an attempt would typically result in a compilation or runtime error depending on the language; an example where redefinition is allowed would be *Ruby*. As in the case where PowerShell allows for function redefinition, care must be taken with ScriptClass class redefinition to avoid non-deterministic behavior and other undesirable functionality defects.

##### Class definition syntax

`New-ScriptClass` requires the arguments `ClassName` and `ClassBlock`. The former is the name of the class, i.e. the unique name of the type that can subsequently be used to refer to the type, including at the point of object creation.

The latter `ClassBlock` parameter defines the structure of objects in the class, i.e. what it means to be a member of the class beyond just possessing some state with the name of the type. ScriptClass evaluates the block to define the class in the following way:

* Any functions defined within the block usig PowerShell's `function` keyword are treated as methods of the class.
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

Let *O* be a ScriptClass object returned by `New-ScriptClass` of class *C* that has a set of Methods *M* and set of properties *P* where *M* and *P* correspond to the methods and properties of *C* as described in the earlier section on class defiition syntax. For all *O*, the following are true:

  * *O* is of type `[PSCustomObject]`, a [documented core type](https://docs.microsoft.com/en-us/dotnet/api/system.management.automation.pscustomobject?view=pscore-6.2.0) of the PowerShell standard.
  * For each non-static method in *M* there is a `ScriptMethod` member of *O*
  * For each non-static property in *P* there is either a `NoteProperty` or `ScriptProperty` member of *O*
  * There is a `NoteProperty` member named `ScriptClass` referred to here as *S*
    * The property *S* is itself a ScriptClass object with the following configuration:
      * Its `ScriptClass` property is `$null`
      * There is a `ClassName` property that is a `[string]` set to the name of the class to which *O* belongs
      * It has a `Module` property of type `[PSModuleInfo]` that is the PowerShell module managed by `New-ScirptClass` in which the methods of *O* are bound
      * For each static method in *M* there is a `ScriptMethod` member of *S*
      * For each static property in *P* there is either a `NoteProperty` or `ScriptProperty` member of *S*

Because the schema above requires that all ScriptClass objects are `[PSCustomObject]` types, ScriptClass objects follow the same behaviors for serialization, deserialization, formatting, method invocation, property access, and any other object behaviors common to `[PSCustomObject]` instances.

#### Method and property access

Code consumes and manipulates objects by accessing their methods and properties:

* Because ScriptClass objects are all `[PSCustomObject]` instances, and all properties and methods of ScriptClass objects correspond directly to a particular `[PSCustomObject]` property or method, the same syntax used to access `[PSCustomObject]` methods and properties *MAY* be used on ScriptClass objects. The syntax is similar to that used in many languages including C#, C++, Java , Javscript, Python, etc.
  * For properties, this approach uses a `.` to denote the refernce of a property. The syntax looks like `$object.property` and `$object.property = expression` to read and write a property respectively.
  * To invoke a method, the `.` is also used, but a pair of matched parentheses are required and the list of arguments to the method, if any, must be contained within the parentheses as a comma-separated list. The syntax again resembles that of other languages based on objects: `$object.method(<argument-expression1>, <argument-expression2>, ..., <argument-expressionN>)`. However, this syntax for method invocation is discouraged as the use of parentheses and commas between arguments diverges from PowerShell's pipeline syntax that omits this punctuation when invoking functions; ScriptClass provides a syntax closer to that of PowerShell command and function invocation.
* `=>` and `::>` functions: These functions invoke methods on ScriptClass objects and they *SHOULD* be used in place of invoking methods using the standard `[PSCustomObject]` syntax for method invocation.
  * To invoke a method on a given object, the `=>` PowerShell function is provided. To invoke a method on an object's *static* (i.e. class-level) methods, the `::>` function is used.
  * To make these idiomatic, the object on which the method is piped to the `=>` or `::>` function, and the method name is provided as the first argument, followed by the arguments to the method.
  * Examples of the syntax include `$object |=> method <method-arg1> <method-arg2>` for a non-static function and `$object |::> staticmethod <method-arg1>` for a static function.
*`Invoke-Method [-Context] <Object> [-Action] <Object> [[-Arguments] <Object[]>]  [<CommonParameters>]`: This command invokes methods on both ScriptClass objects and non-ScriptClass objects. The method specified in the `Action` parameter is invoked on the object designed by the `Object` parameter, and the arguments from `Arguments` are passed to the method.
  * The `Action` parameter may also be a PowerShell ScriptBlock. When a ScriptBlock is provided, it is executed within the current PowerShell scope, and at execution time code in the ScriptBlock may reference a variable `$this` which is set to the value in the `$Object` parameter.

#### Code management features

In order to re-use objects packaged by different script files or .NET assemblies, some manner of referencing the packaging is required. ScriptClass provides the following commands to enable this re-use:

* `Import-Assembly [-AssemblyName] <string> [[-AssemblyRelativePath] <string>] [[-AssemblyRoot] <string>]`: This command is not strictly necessary for ScriptClass to fulfill its mission, but it helps generalize the access of types from .NET assemblies by allowing a convenient way to load a .NET assembly into the calling PoewrShell session. To load a given assembly, use the `$AssemblyName` or `$AssemblyRelativePath` parameter to specify either a name or a known path to an assembly.
* `Import-Script [-Path] <Object> [[-Parent] <Object>] [-AnyExtension]  [<CommonParameters>]`: The `Import-Script` command returns a ScriptBlock that can dot-source the script file referred to in the `$Path` parameter into the current scope. If the file has already been imported, an empty ScriptBlock is returned. This facilitates the commonly accepted model of packaging exactly one definition of the language's *class* consept into a single file. Code in files that must consume a particular class can simply refer to it with this command using this kind of syntax: `. (Import-Script display/Table)`.
  * The `Path` parameter is not truly a path as by default the `.ps1` extension of the file must be omitted.
* Module visibility: Classes defined by `New-ScriptClass` are visible to all code within and below the scope at which the ScriptClass module was imported. ScriptClass classes share the visiblity of the ScriptClass module. This means ScriptClass classes can be shared across modules.
  * A class *X* is *visible* to module *M* if the `$::` operator when accessed by *M* has a member with the name of class *X* and the `New-ScriptObject` command when invoked by *M* successfully returns a ScriptClass object of class *X*
  * If three modules *A*, *B*, and *C* are imported into a session, and class *X* is defined in module *A*, it is *visible* in *B* and *C*.
  * The previous statement istrue even if *A* is a nested module of *B* or *C*
  * It is also true if *A* is a nested module of *B* and *B* is a nested module of *C*

#### Unit testing features

Unit testing capabilities for ScriptClass are based on [Pester](https://github.com/pester/Pester), PowerShell's standard unit testing framework. While Pester provides robust support for mocking PowerShell functions, it does not have support for mocking object methods on .NET or `[PSCustomObject]` types specifically. ScriptClass objects, which are `[PSCustomObjects]` defined as types within ScriptClass's own extended type system, are therefore not mockable strictly using functionality avaialable from Pester.

ScriptClass provides the following commands below which abstract details about the implementation of ScriptClass so that a reliable public interface for mocking is available to users. The commands below allow for mocking of methods defined by `New-ScriptClass` so that they may be used within Pester `It` block test cases.

* `Add-ScriptClassMock [-MockTarget] <Object> [-MethodName] <string> [[-MockWith] <scriptblock>] [[-ParameterFilter] <scriptblock>] [-MockContext <Object>] [-Static] [-Verifiable]  [<CommonParameters>]`: This command allows the caller to replace a specified method of a class or object with a caller-defined method implementation. If the `MockTarget` parameter is a string, this target of the mock is interpreted to be the class with the name specified by `MockTarget` and all objects of that class will have the method mocked. If `MockTarget` is a ScriptClass object, then only the method on that specific object will be mocked. The command supports both static and non-static methods via the `Static` parameter. The `ParameterFilter` and `Verifiable` parameters have the same semantics as in pester's [`Mock` function](https://github.com/pester/Pester/wiki/Mock).
* `Add-MockInScriptClassScope [-ClassName] <string> [-CommandName] <string> [-MockWith] <scriptblock> [-MockContext <Object>] [-ParameterFilter <scriptblock>] [-Verifiable]  [<CommonParameters>]`: This command allows PowerShell functions to be mocked when invoked from ScriptClass methods. Pester's `Mock` function is not able to affect ScriptClass methods. This command enables the functionality of `Mock` within the context of the specific class specified by the `ClassName` parameter.
* `New-ScriptObjectMock [-ClassName] <Object> [-MethodMocks <hashtable>] [-PropertyValues <hashtable>] [-ModuleName <string>] [<CommonParameters>]`: This command creates a mock object of the given class; this object has the same set of properties and methods as an object of that class created by `New-ScriptObject`. The key difference is that the class's constructor is not invoked for this object, and the command allows the object's property values be specified arbitrarily rather than limited by the original implementation's dictates. An array of mocked methods may also be supplied. This is useful for creating synthetic objects with custom implementations rather than creating a real version of the object and individually overriding each method with mock functions.
* `Remove-ScriptClassMock [-MockTarget] <Object> [[-MethodName] <string>] [[-Static]]  [<CommonParameters>]`: The `Remove-ScriptClasMock` command undoes the effect of `Add-ScriptClassMock`. It is generally not required for normal testing, but could be useful for building more advanced ScriptClass unit-testing capabilities.

#### Examples: Compare with PowerShell class keyword

## Implementation

### Infrastructure

ScriptClass is implemented using a combination of publicly exposed commands and internally utilized .Net classes:

* ScriptClass is written purely in PowerShell, though due to PowerShell's poor threading support, there may be some use of Add-Type for a small amount of C#
* Ironically, PowerShell's native `class` keyword is the basis of componentization in ScriptClass despite the fact that its shortcomings are precisely what insired ScriptClass. The usability challenges associated with `class`, while often adding friction and sometimes causing subtle bugs are not enough to render it *unusable*, just less usable (and therefore less beneficial for productivity). Despite the awkward syntax and its difference from the rest of PowerShell, `class` still provides a reliable method for code organization.

### Components

### Common data flows

## Future improvements

* Private methods
* Single inheritance
* Interface inheritance
* Namespaces
* Private module visiblity
* Using `.` instead of `=>` and `::>` for method invocation

### Improving *class* itself
