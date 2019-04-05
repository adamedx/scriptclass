set-strictmode -version 5.1

add-type -ignorewarnings @'
public class ScriptClassBase2
{
    public virtual System.Type GetClassType() { return this.GetType(); }
}
'@

$stuff = [ScriptClassBase2]::new()

$stuff.GetClasstype() | out-host

# [ScriptClassBase2] | fl * | out-host
class ScriptClass2 {
    $thisType = $null
    ScriptClass2() {
        $this.thisType = $this.gettype()
    }

    [Type] GetClassType() {
        return $this.thisType
    }

    [object] InvokeClassMethod([string] $methodName, [object[]] $methodArguments) {
#        $this.thisType | fl * | out-host
        return $this.thisType.InvokeMember($methodName, [System.Reflection.BindingFlags]::InvokeMethod, $null, $this, $methodArguments)
    }
}

$myobj = [ScriptClass2]::new()

write-host 'type', $myObj.GetClassType()
write-host 'type2', $myobj.invokeclassmethod('GetClassType', @())

class Derived : ScriptClass2 {
}

$myobj2 = [Derived]::new()

write-host 'derived', $myobj2.invokeclassmethod('GetClassType', @())

function =>($__method__) {
    if ($__method__ -eq $null) {
        throw "A method must be specified"
    }

    $objects = @()

    $input | foreach {
        $objects += $_
    }

    if ( $objects.length -lt 1) {
        throw "Pipeline must have at least 1 object for $($myinvocation.mycommand.name)"
    }

    $methodargs = $args
    $results = @()
    $objects | foreach {
#        $results += return $_.GetType().InvokeMember($__method__, [System.Reflection.BindingFlags]::InvokeMethod, $null, $_, $methodArgs)
        $results += return $_.InvokeClassMethod($__method__, $methodArgs)
    }

    if ( $results.length -eq 1) {
        $results[0]
    } else {
        $results
    }
}

$myobj2 |=> GetClassType

class MySum : ScriptClass2 {
    [int32] sum($val1, $val2) {
        return $val1 + $val2
    }
}

$myobj3 = [MySum]::new()

$myobj3 |=> sum 5 9

class MyModule {
    $mod = $null
    $modstate = 27
    MyModule([ScriptBlock] $modscript) {
        $this.mod = new-module $modscript -ascustomobject
    }

    [object] InvokeScriptMethod([string] $methodName, [object[]] $methodArguments) {
        $this.mod | out-host
        write-host 'found'
        # $this.mod.psobject.methods | where membertype -eq scriptmethod | out-host #  | where name -eq $methodName | out-host
#        $result = new-variable this $this
#        $result = get-variable this
        return (. ($this.mod.psobject.methods | where membertype -eq scriptmethod | where name -eq $methodName).Script.getnewclosure() @methodArguments)
    }
}

$mymod = [MyModule]::New({function heythere { 57 } function sumfun($arg1, $arg2) {$arg1 + $arg2} function modadd($argval) {$this.modstate` + $argval}} )

$mymod.invokescriptmethod('heythere', @())
$mymod.invokescriptmethod('sumfun', @(8,3))
$mymod.invokescriptmethod('modadd', @(10)) # hmm, this appears to not be defined

$scriptvar = 31

$mymod2 = [MyModule]::New({function mycap { $scriptvar } })

$mymod2.invokescriptmethod('mycap', @()) # hmm, its not capturing -- maybe this is ok

class MyCustom : System.Management.Automation.PSCustomObject {
}
