
New-ScriptClass2 ModFInstance {
    $value = 13
    function sum($arg1, $arg2) {
        $this.value + $arg1 + $arg2
    }
}

function Get-ModFInstance {
    new-scriptobject2 ModFInstance
}

export-modulemember -function GetModFInstance
