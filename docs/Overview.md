# ScriptClass Overview

## Motivation
The ScriptClass module is intended to facilitate the development of PowerShell-based applications rather than just scripts or utilities that comprise the typical PowerShell use case.

**DISCLAIMER: THIS SECTION IS HIGHLY EXPERIMENTAL**

The ability to define classes of objects is a very useful one across a spectrum of languages including C++, C#, Java, Ruby, Python, and many others. Even without strict conformance to object-oriented rigor, there are cognitive benefits to developers in abstracting detailed state into higher level concepts and explicitly defining the allowed operations upon those concepts. Classes enhance code readability and foster understanding of code and an easier ability to reason about it and how to change it safely.

With PowerShell 5.0, this object-oriented notion of a *class* was introduced into the PowerShell language with the intention of enabling PowerShell users to create objects for consumption by .Net Code. While conceptually these classes are analogs of the same classes delivered through the `class` keyword in the aforementioned OO languages, the key scenario for PowerShell classes was to enable the development of PowerShell DSC resources. Given this, it's understandable that the user experience of PowerShell's class feature is closer to that of PowerShell's pre-existing .Net interoperability, particularly with the syntax of method invocation, rather than providing an exerience for classes more in line with PowerShell's command-line / pipeline-focused approach.

Here's an example of usage of a `class` in PowerShell -- note that it requires the use of .Net calling and procedure definition syntax -- parentheses required, commas between parameters, explicit `return` statement for non-`void` methods, and explicit return type declaration for non-`void` methods:

```powershell
class ShellInfo {

    # Class members
    $username
    $computername

    # Constructor
    ShellInfo($username, $computername) {
        $this.username = $username
        $this.computername = $computername
    }

    # An instance method
    [string] GetCustomShellPrompt($prefix, $promptseparator) {
        return "$prefix $($this.username)@$($this.computername) $promptseparator"
    }
}

function prompt {

    # Instantiating and using the class
    $shellInfo = [ShellInfo]::new("user1", "computer0")
    $shellInfo.GetCustomShellPrompt("%", "-> ")
}

```

What is the equivalent of the usage above without `class`? The normal PowerShell calling and declaration syntax requires no parentheses or punctuation to delimit parameters to a function (just spaces). It allows return value specification in a function via simply expressing a value, and no need to specify a return type for a method, regardless whether it does or does not end up returning a value. And such returned values are part of the PowerShell object pipeline, where .NET methods are unable to produce objects in the pipeline.

To get the benefits of encapsulation and conceptual modeling that `class` brings to application developers, a disciplined PowerShell developer might adopt a convention for expressing classes, instantiating them, and using them based on PowerShell hash tables or the `PSCustomObject` core PowerShell type which can be constructed via hash tables:

```powershell

# "Constructor" for a conceptual ShellInfo object
function NewShellInfo($username, $computername) {
    # The class members are defined by the keys of this hash table
    @{username=$username;computername=$computername}
}

# A class method -- its first argument should be a hash table
# returned by the constructor function above
function GetCustomShellPrompt($shellinfo, $prefix, $promptseparator) {
    $username = $shellInfo['username']
    $computername = $shellInfo['computername']
    # Return the value by adding to the pipeline -- no need to use return keyword
    "$prefix $($username)@$($computername) $promptseparator"
}

function prompt {
    # Instantiate by calling the constructor
    $shellInfo = NewShellInfo "user1" "computer0"
    # Call the method using powershell function / cmdlet syntax
    GetCustomShellPrompt $shellInfo "%" "-> "
}
```
With the addition of `class`, PowerShell scripts may not include *both* of these styles of code. This has drawbacks:

* Most scripts will be forced to "mix" both styles, which results in some confusion when reading the scripts ("why is this function being called with parentheses and this one not -- ah, it's a class method, not a function")
* The mixing can cause errors during development such as accidentally using parentheses with PowerShell functions after defining several class methods. This results in errors known quite well to PowerShell users where your function behaves strangely, you debug it to realize it's getting passed an array even though you are passing a different type, and after looking at the call site for a long time and debugging other parts of the code to determine what parameters you are actually passing, you realize you need to remove the parentheses and commas and pass parameters the way PowerShell expects.
* When you use class methods, you forego useful and productive PowerShell capabilities like passing parameters by name or through the pipeline

In short, any PowerShell code that incorporates classes as presented by the language reference will be a mash of programming paradigms. The question arises: what would PowerShell's `class` feature look like if it were compatible with the existing PowerShell function call model? Is there a way to make classes, or something like them, support a more `function`-like model?

### Further limitations with `class` in PowerShell

The `class` feature in PowerShell has functional drawbacks in addition to the usability issues mentioned earlier:

* The types defined by `class` do not obey PowerShell lexical scoping rules (e.g. *local*, *script*, *global* scopes). Regardless the PowerShell scope in which the type is defined, it is as if it were defined at PowerShell's `global` scope and is thus visible everywhere. This is by design -- these types are just .NET classes that can be consumed by PowerShell (or .NET libraries and applications) exactly as any .NET is consumed by PowerShell. Because .NET classes are visible to an entire process, any .NET class, including those defined by `class` is visible to the entier process. When used with PowerShell, this causes the kinds of complications that PowerShell's scopes were designed to avoid, such as name colisions when different scripts or modules define a class with the same name. Such errors can be very difficult to identify, debug, or work around.
* Another behavior observed with `class` is that types can be redefined, i.e. a script can change the type definition of a type previously defined by `class`. There are ways this can be a helpful feature used intentionally, but is most often an error. Additionally, if a script defines the class more than once but uses the same definition (e.g. say the script is dot-sourced multiple times in a PowerShell session), the underlying type id of the class is different. For example:

```powershell
class TheOneAndOnly{};$result = [TheOneAndOnly]::new(); $result2 = [TheOneAndOnly]::new();
class TheOneAndOnly{};$result2 = [TheOneAndOnly]::new()
$result.gettype().typehandle, $result2.gettype().typehandle
$result2.gettype() -eq $result.gettype()
```

This compares the type handles and does an explicit equality comparison between the types -- you'll get output like that below, indicating that the types are different:
```
          Value
          -----
140710258725128
140710258790664

False
```

Contrast that with types that have not been redefined:
```powershell
class TheOneAndOnly{};$result = [TheOneAndOnly]::new(); $result2 = [TheOneAndOnly]::new();
$result.gettype().typehandle, $result2.gettype().typehandle
$result = [DateTime]::new(0);$result2 = [DateTime]::new(0)
$result.gettype().typehandle, $result2.gettype().typehandle
```

The resulting output in that case shows that objects with the same type that hasn't been redefined will have the same `typehandle` for the type, and a direct comparison of the types indicates they are the same (the `True` output):

```
          Value
          -----
14071025885620
140710258856200

          Value
          -----
140711817284904
140711817284904

True
```

Beyond the unexpected and difficult to debug issue of type comparisons returning a difference for types that appear to be the same in terms of name, structure etc., there may be other side effects of this behavior, including leaked type definitions after each redefinition, type mismatches in other contexts (e.g. passing the instaces of redefined types as strongly-typed parameter to .NET methods), etc.

Ultimately the use case of `class` in PowerShell is purely one of interoperability with .NET. The original release of PowerShell introduced the ability to consume .NET classes from within PowerShell scripts, a novel feature that greatly enhanced the utility of the language. With `class`, PowerShell 5.0 adds the ability to produce, and not just consume, .NET classes from PowerShell to support models such as callbacks from asynchronous .NET programming models and general interop with systems such as PowerShell Desired State Configuration. Application development was **not** a goal of the `class` feature, despite such a capability of its analogs in other languages.

### Making `class` safe for PowerShell

So `class` isn't really useful outside of the context of integratig with specific .NET interfaces. But what if it could be made to be a general-purpose type definition facility aimed at developing full-blown PowerShell applications? And what if it hewed more closely to the PowerShell programming style and syntax? Here are a few ideas around what a more `function`-y `class` would look like:

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
