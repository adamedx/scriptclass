# import-module (join-path $psscriptroot Shared.psm1)

# $class1Instance = NewShared class1mod

New-ScriptClass2 hiclass10 {
    $fun = 5;
    function myfunc10 {
        $this.fun + 10
    }

    static {
        $funstat = 8
        function mystat10 {
            $this.funstat * $this.funstat
        }
    }
}

$class1Instance = new-scriptobject2 hiclass10

function GetClass1 {
    [PSCustomObject] @{
        count = GetInstances
        inst = $class1Instance
    }
}



export-modulemember -function GetClass1
