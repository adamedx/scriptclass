# ROADMAP for ScriptClass

## To-do items -- prioritized

### To-do
* Mocking!
  * Method mocking
  * Object mocking
* Remove superfluous verbose output from export-module
* Remove some usage of script scope variables
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

