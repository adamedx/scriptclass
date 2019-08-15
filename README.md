ScriptClass Extension for PowerShell
====================================

[![Build Status](https://adamedx.visualstudio.com/AutoGraphPS/_apis/build/status/adamedx.scriptclass?branchName=master)](https://adamedx.visualstudio.com/AutoGraphPS/_build/latest?definitionId=2&branchName=master)

The ScriptClass extension module provides code re-use and syntactic affordances for PowerShell similar to comparable dynamic languages such as Python and Ruby. The overall aim is to facilitate the development of PowerShell-based applications and libraries rather than just scripts or utilities that comprise the typical PowerShell use case.

```powershell
# Define classes just as you would in C#, Python, Java, Ruby, etc.
# without giving up PowerShell cmdlet syntax!
ScriptClass Complex {
    const ZERO_COORDINATE 0.0

    $Real = strict-val [double] $ZERO_COORDINATE
    $Imaginary = strict-val [double] $ZERO_COORDINATE

    function __initialize {
        $::.Complex |=> AddInstance
    }

    function Add($real, $imaginary) {
        $result = new-scriptobject Complex
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

On the Windows operating system, PowerShell 5.1 and higher are supported. On Linux, PowerShell 6.1.2 and higher are at a pre-release support level. MacOS has not been tested, but may work with PowerShell 6.1.2 and higher.

## Installation

ScriptClass is designed to work on PowerShell 5.1 and Windows 10 / Windows Server 2016. To install it to your user profile from [PowerShell Gallery](https://www.powershellgallery.com/), just run the following command:

```powershell
    Install-Module ScriptClass -scope currentuser
```

After this, all of the ScriptClass cmdlets will be availble to PowerShell code, enabling you to define classes and create objects as you would in any object-oriented language.

## Features
The library features the following enhancements for PowerShell applications and complex libraries:

* The `ScriptClass` alias / `New-ScriptClass` cmdlet: Lets you define types using a syntax very similar to that of other languages that feature a `class` keyword. These types ultimately describe sets of `[PSCustomObject]` objects.
* The `new-so` alias / `New-ScriptObject` cmdlet: Instantiate a type defined by `ScriptClass`. The resulting object is a `[PSCustomObject]` instance, so the returned objects integrate well with PowerShell's native type system and object-manipulation cmdlets.
* The `=>`, `::>` and `withobject` aliases / `Invoke-Method` cmdlet: Convenient ways to invoke methods on a `ScriptClass` object using PowerShell syntax (no parentheses or punctuation needed to call methods)
* The `Import-Script` cmdlet that allows the sharing of code (i.e. functions, classes, variables, etc.) across script files. It is similar in function to the Ruby `require` method or Python's `import` keyword, allowing code in one file to access any functions, types, or variables defined in another file.
* The `Import-Assembly` cmdlet provides a simpler PowerShell-oriented wrapper around the .Net Framework's assembly loading methods.
* Automatic enforcement of PowerShell `Set-StrictMode 2` within `ScriptClass` methods to facilitate the robustness and determinism typically expected of object-based environments.

## Contributing / Development
We're open for contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for policies around contributing code.

### Testing

Tests are implemented using Pester. To ensure you have the latest version of Pester on your developer system, visit the [Pester site](https://github.com/pester/Pester) for instructions on installing Pester.

To test, execute the PowerShell command below from the root of the repository

```powershell
invoke-pester
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

