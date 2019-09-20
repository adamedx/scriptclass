
New-ScriptClass ModAInstance {
    $value = 9
    function sum($arg1, $arg2) {
        $this.value + $arg1 + $arg2
    }
}

function Get-ModAInstance {
    new-scriptobject ModAInstance
}

export-modulemember -function GetModAInstance
