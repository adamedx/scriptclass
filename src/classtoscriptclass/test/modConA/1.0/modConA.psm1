
New-ScriptClass2 ModCInstance {
    $value = 11
    function sum($arg1, $arg2) {
        $this.value + $arg1 + $arg2
    }
}

function Get-ModCInstance {
    new-scriptobject2 ModCInstance
}

export-modulemember -function GetModCInstance
