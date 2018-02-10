ScriptClass Extension for PowerShell
====================================
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

PS> $complexNumber = new-so Complex
PS> $complexNumber |=> Add 3 4
PS> $complexNumber |=> Magnitude
5
```


## Installation

ScriptClass designed to work on PowerShell 5.0 and Windows 10 / Windows Server 2016. To install it to your user profile from [PowerShell Gallery](https://www.powershellgallery.com/), just run the following command:

```powershell
    Install-Module ScriptClass
```

After this, all of the ScriptClass cmdlets will be availble to PowerShell code, enabling you to define classes as you would in object-oriented languages.

## Features
The library features the following enhancements for PowerShell applications and complex libraries:

* The `ScriptClass` alias / `add-scriptclass` cmdlet: This let you define types using a syntax very similar to that of other languages that feature a `class` keyword. Types defined by `ScriptClass` are actually `[PSCustomObject]` objects and so integrate well with PowerShell's native type system and object-manipulation cmdlets.
* The `new-so` alias / `new-scriptobject` cmdlet: Instantiate a type defined by `ScriptClass`.
* The `=>`, `::>` and `with` aliases / `invoke-method` cmdlet: Convenient ways to invoke methods on a `ScriptClass` object using PowerShell syntax (no parentheses or punctuation needed to call methods)
* The `import-script` cmdlet that allows the use of code (i.e. functions, classes, variables, etc.) from external PowerShell files within the calling PowerShell file. It is similar in function to the Ruby `require` method or Python's `import` keyword.
* Automatic enforcement of PowerShell `strict mode 2`.
* Additional helper functions and objects to make it easy to use classes

## Contributing / Development
The project is not yet ready for contributors, but suggestions on features or other advice is welcome while we establish a baseline.

### Testing

Tests are implemented using Pester. To ensure you have the latest version of Pester on our developer system, visit the [Pester site](https://github.com/pester/Pester) for instructions on installing Pester.

To test, execute the PowerShell command below from the root of the repository

```powershell
invoke-pester
```

This will run all tests and list any errors that must be corrected prior to mergig any changes you've made to the repository.

### Building the module

To build ScriptClass, run the following PowerShell commands

```powershell
git clone https://github.com/adamedx/scriptclass
cd scriptclass

# Download dependencies -- this only needs to be done once
.\build\install.ps1

# Actually build
.\build\build-package.ps1
```

### Installing the build

Once you've executed `build-package.ps1`, you can copy it to a directory in `$env:psmodulepath` so that you can import it:

```powershell
cp -r .\pkg\modules\scriptclass ~/Documents/WindowsPowerShell/Modules
import scriptclass
```

License and Authors
-------------------
Copyright:: Copyright (c) 2018 Adam Edwards

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

