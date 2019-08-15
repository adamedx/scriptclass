# ROADMAP for ScriptClass

## To-do items -- prioritized
* Post-refactor clean-up and polish
* Add documentation to cmdlets
* General README update
* Build tools documentation
* Design documentation
* Rebase the refactor!
* Do we need typedobjectbuilder to be factored out of classmanager? Should it be scriptobjectbuilder?
* Should classmanager be typemanager? ClassInfo be typeinfo? ClassDefinition be typedefinition? classbuilder be typebuilder?
* Add namespacing to actual types (e.g. a type declared as ComplexNumber becomes ScriptClass.ComplexNumber, or even has a module, e.g. ScriptClass.Module.Complex#).


### To-do
* Fix issue with test-scriptobject and psremoting jobs from start-job
* Private member variables (e.g. wrap methods such that the push the this parameter on a stack, and pop it off when they leave, then you can peek at the top when entering private methods)
* Inheritance
* Method overrides
* Protected methods

### Done
* Remove extraneous variables from scriptblock snapshot:
  args                        NoteProperty   Object[] args=System.Object[]
  MyInvocation                NoteProperty   InvocationInfo MyInvocation=System.Management.Automation.Invoca...
  PSBoundParameters           NoteProperty   PSBoundParametersDictionary PSBoundParameters=System.Management...
  PSCommandPath               NoteProperty   string PSCommandPath=C:\Users\adamed\src\poshgraph\.devmodule\s...
  PSScriptRoot                NoteProperty   string PSScriptRoot=C:\Users\adamed\src\poshgraph\.devmodule\sc...
  snapshot2                   NoteProperty   Object[] snapshot2=System.Object[]
  varsnapshot1                Note
* Mocking!
  * Method mocking - Mock-ScriptClassMethod
  * Object mocking
* Remove superfluous verbose output from export-module
* Remove some usage of script scope variables
* Complete refactor!
* Complete module isolation -- no variables / private functions leak outside of the module!
* Move process of adding common methods to static members out of dsl processing into ScriptClassBuilder
* Fix pstypename double add
* Use erroractionpreference stop throughout module
* Fix methoddsl not checking for missing method
* Make method restoration its own method
* Clean up dsl processing to separate out execution state (possibly use a new class altogether)
* Better errors in include (seems like this already works?)
* Fix parameter names in exposed cmdlets
* Remove error stream noise
* Clean up methoddsl
* Remove commented-out code
* Code-reuse opportunities in mock code
* Remove module argument from mock command
* Change classdata in mock functions to classinfo
* Don't rely on pstypename for type checking
* Add ability to include any file extension or use full path in import-script
* Remove use of underscores!
* File location rationalization and move
* break apart scriptclass tests
* Consistent use of commas vs. newlines in collections in module files
* Run in CI pipeline
* Make pstypename not part of class? May affect deserialization.
* change module tests to not require .devmodule

### New file layout

    scriptclass.psd1
    scriptclass.psm1
    \\build
    \\test
    \\src
        scriptclass.ps1
        cmdlets.ps1
        \\cmdlets
        \\codeshare
            \\assembly
            \\script
        \\scriptobject
            \\common
            \\psobject
            \\dsl
            \\mock
            \\type


#### Test breakout

