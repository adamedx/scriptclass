ScriptClass Design
==================

This document provides a high-level description of the component design of the ScriptClass
extensions to PowerShell.

## Motivation

The overall goal for the ScriptClass module as a whole can be stated as follows:

> The ScriptClass module is intended to facilitate the development of PowerShell-based applications rather than just scripts or utilities that comprise the typical PowerShell use case.

Why does PowerShell need ScriptClass to enable serious application development? The [Overview document](https://github.com/adamedx/scriptclass/blob/master/docs/Overview.md) document goes into this in detail: PowerShell, even as of versions 5 and 6 provides at best awkward support for object-based methodologies for code factoring and reuse. Most large-scale application development requires some consistent organizational principle to allow developers to reason over and maintain larger codebases; object-oriented approaches such as those in C++, Java, C#, Python, Ruby, Javascript, and many others have done this successfully enough for developers to work on large codebases and more importantly to deliver complex but reliable systems with the work of hundreds or even thousans of developers.

ScriptClass attempts to fill this gap in PowerShell by extending PowerShell's typical imperative / functional hybrid syntax to support types (i.e. classes) and objects, and to so without the "bolted on" feel of PowerShell's class keyword.

## Design principles

In bringing object orientation to PowerShell, the following principles are a guide:

* Favor the use of existing PowerShell concepts and features over implementing and introducing new concepts and features
* Derive inspiration for user experience from object-based dynamic languages like Python, Ruby, and Javascript
* Object-orientation should feel idiomatic with respect to PowerShell
* The initial implementation should be PowerShell-based -- a native implementation in the PowerShell language itself should wait until this approach has wider community feedback and validation



## Language interface

While this design does not technically alter the PowerShell core language in any way, it does introduce new commands and associated data structure conventions that provide the "feel" of language changes such as new keywords, etc.

### Class definition features

