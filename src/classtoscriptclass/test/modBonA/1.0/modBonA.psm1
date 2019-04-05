
New-ScriptClass2 ModBInstance {
    $value = 10
    function sum($arg1, $arg2) {
        $this.value + $arg1 + $arg2
    }
}

function Get-ModBInstance {
    new-scriptobject2 ModBInstance
}

export-modulemember -function GetModBInstance
