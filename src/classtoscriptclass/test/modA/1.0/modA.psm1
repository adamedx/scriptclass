
New-ScriptClass2 ModAInstance {
    $value = 9
    function sum($arg1, $arg2) {
        $this.value + $arg1 + $arg2
    }
}

function Get-ModAInstance {
    new-scriptobject2 ModAInstance
}

export-modulemember -function GetModAInstance
