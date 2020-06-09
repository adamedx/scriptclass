. (join-path $psscriptroot prototype.ps1)

Describe "ScriptClass prototype" {
    scriptclass2 staticclass {
        $nonstat = 3

        function getlocal {
            $this.nonstat
        }

        static {
            function mystaticfunc {
                4
            }

            $mystaticprop = 10
        }
    }
}
