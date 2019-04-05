
New-ScriptClass2 ModDInstance {
    $value = 12
    function sum($arg1, $arg2) {
        $this.value + $arg1 + $arg2
    }
}

function Get-ModDInstance {
    new-scriptobject2 ModDInstance
}

export-modulemember -function GetModDInstance
