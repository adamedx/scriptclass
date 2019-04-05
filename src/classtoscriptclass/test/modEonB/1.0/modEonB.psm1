
New-ScriptClass2 ModEInstance {
    $value = 13
    function sum($arg1, $arg2) {
        $this.value + $arg1 + $arg2
    }
}

function Get-ModEInstance {
    new-scriptobject2 ModEInstance
}

export-modulemember -function GetModEInstance
