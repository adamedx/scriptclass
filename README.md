ScriptClass Extension for PowerShell
====================================

[![Build Status](https://adamedx.visualstudio.com/AutoGraphPS/_apis/build/status/adamedx.scriptclass?branchName=main)](https://adamedx.visualstudio.com/AutoGraphPS/_build/latest?definitionId=2&branchName=main)

The ScriptClass extension module provides code re-use and syntactic affordances for PowerShell similar to comparable dynamic languages such as Python and Ruby. The overall aim is to facilitate the development of PowerShell-based applications and libraries rather than just scripts or utilities that comprise the typical PowerShell use case.

```powershell
# Define classes just as you would in C#, Python, Java, Ruby, etc.
# without giving up PowerShell cmdlet syntax!
scriptclass Complex {
    const ZERO_COORDINATE 0.0

    $Real = strict-val [double] $ZERO_COORDINATE
    $Imaginary = strict-val [double] $ZERO_COORDINATE

    function __initialize {
        $::.Complex |=> AddInstance
    }

    function Add($real, $imaginary) {
        $result = New-ScriptObject Complex
        $result.real = $this.real + $real
        $result.imaginary = $this.imaginary + $imaginary
        $result
    }

    function Magnitude {
        [Math]::sqrt($this.real * $this.real + $this.imaginary * $this.imaginary)
    }

    static {
        $Instances = 0

        function AddInstance {
            $this.instances++
        }

        function InstanceCount {
            $this.instances
        }
    }
}

PS> $origin = new-so Complex
PS> $translation = $origin |=> Add 3 4
PS> $translation |=> Magnitude
5
```

## System requirements

On the Windows operating system, PowerShell 5.1 and higher are supported. On Linux and MacOS, PowerShell 6.1.2 and higher are supported.

## Features
The library features the following enhancements for PowerShell applications and complex libraries:

* The `ScriptClass` alias / `New-ScriptClass` cmdlet: Lets you define types using a syntax very similar to that of other languages that feature a `class` keyword. These types ultimately describe sets of `[PSCustomObject]` objects.
* The `new-so` alias / `New-ScriptObject` cmdlet: Instantiate a type defined by `ScriptClass`. The resulting object is a `[PSCustomObject]` instance, so the returned objects integrate well with PowerShell's native type system and object-manipulation cmdlets.
* The `=>`, `::>` and `withobject` aliases / `Invoke-Method` cmdlet: Convenient ways to invoke methods on a `ScriptClass` object using PowerShell syntax (no parentheses or punctuation needed to call methods)
* The `Import-Script` cmdlet that allows the sharing of code (i.e. functions, classes, variables, etc.) across script files. It is similar in function to the Ruby `require` method or Python's `import` keyword, allowing code in one file to access any functions, types, or variables defined in another file.
* The `Import-Assembly` cmdlet provides a simpler PowerShell-oriented wrapper around the .Net Framework's assembly loading methods.
* Automatic enforcement of PowerShell `Set-StrictMode 2` within `ScriptClass` methods to facilitate the robustness and determinism typically expected of object-based environments.

## Installation

ScriptClass is designed to work on PowerShell 5.1 and Windows 10 / Windows Server 2016 and Linux distributions such as Ubuntu 16 and later. To install it to your user profile from [PowerShell Gallery](http://powershellgallery.com/packages/scriptclass), just run the following command:

```powershell
    Install-Module ScriptClass -scope currentuser
```

After this, all of the ScriptClass cmdlets will be availble to PowerShell code, enabling you to define classes and create objects in your scripts as you would in any object-oriented language.

You may also reference ScriptClass from PowerShell modules as you would any other module dependency and consume its features from all of the code within that module.

## Usage
ScriptClass can be used in both scripts and modules, and also interactively. The interactive case is mostly useful for debugging scripts or modules based on ScriptClass as you can define classes and instantiate instances of them from the command line just as you would in scripts and modules themselves.

### Using ScriptClass from your scripts
If you maintain a local set of Scripts where you'd like to make use of ScriptClass, simply install the ScriptClass module as described earlier to your system. You can then include any of its commands in your scripts; PowerShell will take care of loading the ScriptClass module for you at runtime and your scripts will be able to consume classes and instances.

### Building modules and applications with ScriptClass
The most powerful use case for ScriptClass is in building non-trival applications that are beyond the scope of a single script. Such applications are typically packaged as PowerShell modules. The simplest way to use ScriptClass in your PowerShell module is to reference it from the `NestedModules` element of your module's manifest (`.psd1`) file:

```powershell
# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
NestedModules = @(
    @{ModuleName='ScriptClass';Guid='9b0f5599-0498-459c-9a47-125787b1af19'} # ModuleVersion optional
)
```

Specifying this entry in your module manifest this way is the recommended way to use ScriptClass from a module -- it ensures that when your module is installed from a PowerShell module repository such as PowerShell Gallery through the `Install-Module` command, `ScriptClass` is installed right along with it.

Note that the `ModuleName` and `Guid` fields must be specified exactly as given here -- they uniquely identify ScriptClass. If you use different values you won't be referencing ScriptClass. It is recommanded that you also specify the exact version of ScriptClass you're using (typically the latest version you can find at [PowerShell Gallery](http://powershellgallery.com/packages/scriptclass). This can insulate you from breaking changes that occur in newer versions of ScriptClass that your code has not been tested against. In that case, the entry for ScriptClass given above would be modified to

```powershell
    @{ModuleName='ScriptClass';ModuleVersion='0.20.0';Guid='9b0f5599-0498-459c-9a47-125787b1af19'} # ModuleVersion optional
```

By specifying `ModuleVersion`, you're ensuring that the `Install-Module` command gets exactly that version, presumably one you tested with your module, when the module is installed and you can have high confidence that it will then function correctly as it did in your test environment.

#### Module usage without a manifest
If you are not using a PowerShell repository to install your module or you are otherwise managing module dependencies and availability without using the `Install-Module` command, you'll need to ensure that `ScriptClass` is installed to a relevant module path specified in the `PSModulePath` environment variable. You can then import the module from your module file or any of its dot-sourced scripts through the `Import-Module` command:

```powershell
# Use this inside your .psm1 file or dot-sourced script files
# This assumes you have already installed ScriptClass!
Import-Module ScriptClass
```

## Contributing / Development
We're open for contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for policies around contributing code.

### Design documentation

Please review the design documentation in [DESIGN.md](src/scriptobject/DESIGN.md) for detail on the implementation and design philosophy  of `ScriptClass` before submitting contributions.

### Testing

Tests are implemented using Pester. To ensure you have the latest version of Pester on your developer system, visit the [Pester site](https://github.com/pester/Pester) for instructions on installing Pester.

To test, execute the PowerShell command below from the root of the repository

```powershell
Invoke-Pester
```

This will run all tests and list any errors that must be corrected prior to merging any changes you've made to the repository.

### Building the module

To build ScriptClass, run the following PowerShell commands

```powershell
git clone https://github.com/adamedx/scriptclass
cd scriptclass

# Download dependencies -- this only needs to be done once
./build/install.ps1

# Actually build
./build/build-package.ps1
```

### Installing the build

Once you've executed `build-package.ps1`, you can copy it to a directory in `$env:psmodulepath` so that you can import it:

```powershell
cp -r ./pkg/modules/scriptclass ~/Documents/WindowsPowerShell/Modules
import scriptclass
```

License and Authors
-------------------
Copyright:: Copyright (c) 2019 Adam Edwards

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

