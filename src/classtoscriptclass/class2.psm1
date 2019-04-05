# import-module (join-path $psscriptroot Shared.psm1)

$class2Instance = NewShared class2mod

New-ScriptClass2 CanClassDefReferenceOtherModuleFuncs {
    $fun = GetClass1
    function getfun {
        $this.fun
    }

    static {
        $mystat = 10
        function mystat {
            $this.mystate
        }
    }
}

function GetClass2 {
    [PSCustomObject] @{
        count = GetInstances
        inst = GetClass1
    }
}


export-modulemember -function GetClass2, GetClass1, GetClass3


