# ROADMAP for ScriptClass

## To-do items -- prioritized

* Remove extraneous variables from scriptblock snapshot:
  args                        NoteProperty   Object[] args=System.Object[]
  MyInvocation                NoteProperty   InvocationInfo MyInvocation=System.Management.Automation.Invoca...
  PSBoundParameters           NoteProperty   PSBoundParametersDictionary PSBoundParameters=System.Management...
  PSCommandPath               NoteProperty   string PSCommandPath=C:\Users\adamed\src\poshgraph\.devmodule\s...
  PSScriptRoot                NoteProperty   string PSScriptRoot=C:\Users\adamed\src\poshgraph\.devmodule\sc...
  snapshot2                   NoteProperty   Object[] snapshot2=System.Object[]
  varsnapshot1                Note
* Remove superfluous verbose output from export-module
* Remove some usage of script scope variables
* Fix issue with test-scriptobject and psremoting jobs from start-job

