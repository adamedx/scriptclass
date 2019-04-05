set-strictmode -version 5.1

$scriptvar = 10

class MyClass {
    $myblock = { $scriptvar }
    [int] MyMethod() {
        # This fails -- scriptvar is not defined, this method closure does not capture, i.e. it is not a scriptblock
        # return $scriptvar

        # Ah, but this works! If you define a scriptblock in the class, it can capture variables!
        return . $this.myblock
    }
}

$myobj = [MyClass]::new()

$myobj.MyMethod()

