ScriptClass Extension for PowerShell
=================================================
This Enhanced Standard Library (stdlib) provides code re-use capabilities and syntactic affordances for PowerShell similar to comparable dynamic languages such as PowerShell. The overall aim is to facilitate the development of PowerShell-based applications rather than just scripts or utilities that comprise the typical PowerShell use case.

## Features
The library features the following enhancements for PowerShell applications

* The `include-source` cmdlet that allows the use of code (i.e. functions, classes, variables, etc.) from external PowerShell files within the calling PowerShell file. It is similar in function to the Ruby `require` method or Python's `import` keyword.
* An additional `$ApplicationRoot` "automatic" variable indicating the directory in which the script that launched the application resides.
* Automatic enforcement of PowerShell `strict mode 2`.
* An experimental implementation of object classes on top of `PSCustomObject`. The implementation provides a class definition syntax, method invocation mechanism, and runtime object and type discovery.

### Using the library's *class* feature

**DISCLAIMER: THIS SECTION IS HIGHLY EXPERIMENTAL**

The ability to define classes of objects is a very useful one across a spectrum of languages including C++, C#, Java, Ruby, Python, and many others. Even without strict conformance to object-oriented rigor, there are cognitive benefits to developers in abstracting detailed state into higher level concepts and explicitly defining the allowed operations upon those concepts. Classes enhance code readability and foster understanding of code and an easier ability to reason about it and how to change it safely.

With PowerShell 5.0, this object-oriented notion of a *class* was introduced into the PowerShell language with the intention of enabling PowerShell users to create objects for consumption by .Net Code. While conceptually these classes are analogs of the same classes delivered through the `class` keyword in the aforementioned OO languages, the key scenario for PowerShell classes was to enable the development of PowerShell DSC resources. Given this, it's understandable that the user experience of PowerShell's class feature is closer to that of PowerShell's pre-existing .Net interoperability, particularly with the syntax of method invocation, rather than providing an exerience for classes more in line with PowerShell's command-line / pipeline-focused approach.

Here's an example of usage of a `class` in PowerShell -- note that it requires the use of .Net calling and procedure definition syntax -- parentheses required, commas between parameters, explicit `return` statement for non-`void` methods, and explicit return type declaration for non-`void` methods:

```powershell
class ShellInfo {
    $username
    $computername
    ShellInfo($username, $computername) {
        $this.username = $username
        $this.computername = $computername
    }
    [string] GetCustomShellPrompt($prefix, $promptseparator) {
        return "$prefix $($this.username)@$($this.computername) $promptseparator"
    }
}

function prompt {
    $shellInfo = [ShellInfo]::new("user1", "computer0")
    $shellInfo.GetCustomShellPrompt("%", "-> ")
}

```

As opposed to this, which uses the normal PowerShell calling and declaration syntax: no parentheses needed to pass parameters to a function, no punctuation just spaces between parameters, implicit return via simply expressing a value, and no need to specify a return type for a method, regardless whether it does or does not end up returning a value:

```powershell
function NewShellInfo($username, $computername) {
    @{username=$username;computername=$computername}
}

function GetCustomShellPrompt($shellinfo, $prefix, $promptseparator) {
    $username = $shellInfo['username']
    $computername = $shellInfo['computername']
    "$prefix $($username)@$($computername) $promptseparator"
}

function prompt {
    $shellInfo = NewShellInfo "user1" "computer0"
    GetCustomShellPrompt $shellInfo "%" "-> "
}
```
With the addition of `class`, PowerShell scripts may not include *both* of these styles of code. This has drawbacks:

* Most scripts will be forced to "mix" both styles, which results in some confusion when reading the scripts ("why is this function being called with parentheses and this one not -- ah, it's a class method, not a function")
* The mixing can cause errors during development such as accidentally using parentheses with PowerShell functions after defining several class methods. This results in errors known quite well to PowerShell users where your function behaves strangely, you debug it to realize it's getting passed an array even though you are passing a different type, and after looking at the call site for a long time and debugging other parts of the code to determine what parameters you are actually passing, you realize you need to remove the parentheses and commas and pass parameters the way PowerShell expects.
* When you use class methods, you forego useful and productive PowerShell capabilities like passing parameters by name or through the pipeline

In short, any PowerShell code that incorporates classes as presented by the language reference will be a mash of programming paradigms. The question arises: what would PowerShell's `class` feature look like if it were compatible with the existing PowerShell function call model? Is there a way to make classes, or something like them, support a more `function`-like model?

#### Making `class` safe for PowerShell

Here are a few ideas around what a more `function`-y `class` would look like:

1. You could define methods, including constructors, using PowerShell function declaration syntax and calling conventions
2. You could invoke methods, including those used to instantiate new class instances, using all Powershell calling conventions and associated syntax
3. Return value type specification would be completely optional for class methods -- methods could return an object of any type, or none at all, regardless whether a return type is specified, just as with PowerShell functions
4. Class methods could specify return values just like functions, i.e. without using the `return` keyword or equivalent.
5. You could define public class fields (i.e. data members) and default values as easily as they are declared in PowerShell's `class` syntax, i.e. simply by listing the field names and optionally assigning a default value
6. You could access public class fields with a simple `.` operator as in most object-based languages including PowerShell's own implementation of `class`.
7. Class methods could refer to their own fields using something like a `this` object as in many object-based languages to distinguish between the object's own state vs. other variables
8. Association of methods with a class could be done without relying on naming conventions and would actually be enforced by PowerShell
9. Method calls on an object could be invoked with a `.` syntax between the object and method just as with data field access

*...More to come...*

## Contributing/Development
The project is not yet ready for contributors, but suggestions on features or other advice is welcome while I establish a baseline.

License and Authors
-------------------
Copyright:: Copyright (c) 2017 Adam Edwards

License:: Apache License, Version 2.0

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

