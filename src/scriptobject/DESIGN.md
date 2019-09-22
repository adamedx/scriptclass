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
* Object-orientation should feel idiomatic with respect to PowerShell
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

## High-level approach

ScriptClass employs the following decisions in accordance with the principles:

* Developers define sets of objects by supplying a PowerShell *[ScriptBlock]* that itself defines variables and functions. These variables and functions will define the state and method interface of the function respectively. A domain-specific language is used within the *[ScriptBlock]* to describe the set.
* The runtime representation of objects is the PowerShell *[PSCustomObject]* type
* Method invocation is accomplished through by defining PowerShell functions that serve as a method invocation domain-specific language.
* The module exposes module methods for definiting object setds and managing object lifecycles; since module methods are visible to other modules, definition and lifecycle functionality is accessible to all modules in the PowerShell session.

## User interface

ScriptClass surfaces object definition and lifecycle management through a functional-programming style interface that builds on PowerShell's existing notion of "object."

### Concepts

The ScriptClass framework revolves around the following concepts:

* ScriptClass: A ScriptClass is a user-supplied definition of a set of objects with common methods and properties. Conceptually ScriptClass conforms to the commonly understood notion of a programming language data type, specifically it is the equivalent of a type defined by the *class* keyword found in multiple languages including *PowerShell*, *C++*, *Java*, *C#*, *JavasScript*, *Ruby*, *Python*, and others. It differs from PowerShell's implementation of *class* primarly in its runtime state implementation and method invocation interface.
* ScriptObject: An instance of an object defined by a given ScriptClass. ScriptObjects have properties and methods that can be used to represent arbitrary data types and encapsulate them.

### Language interface

While this design does not technically alter the PowerShell core language in any way, it does introduce new commands and associated data structure conventions that provide the "feel" of language changes such as new keywords, etc.

#### Class definition features

#### Method and property access

#### Examples: Compare with PowerShell class keyword

## Implementation

### Infrastructure

ScriptClass is implemented using a combination of publicly exposed commands and internally utilized .Net classes:



### Components

### Common data flows

## Future improvements

