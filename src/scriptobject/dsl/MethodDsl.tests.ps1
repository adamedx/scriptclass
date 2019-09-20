# Copyright 2019, Adam Edwards
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set-strictmode -version 2

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$thismodule = join-path (split-path -parent $here) '..\..\ScriptClass.psd1'

Describe 'The => DSL invocation function' {
    BeforeAll {
        remove-module $thismodule -force -erroraction ignore
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction ignore
    }

    Context "When a method is invoked through the => function" {
        $initialValue = 10
        ScriptClass ClassClass43 {
            $sum = 3

            function __initialize($startVal) {
                $this.sum = $startVal
            }

            function add($first, $second) {
                $first + $second
            }

            function addto($firstarg) {
                $this.sum += $firstarg
                current
            }

            function current() {
                $this.sum
            }

            static {
                function staticmethod {
                }
            }
        }

        $newInstance = new-scriptobject ClassClass43 $initialValue
        $newInstance2 = new-scriptobject ClassClass43 $initialValue
        $newInstance3 = new-scriptobject ClassClass43 $initialValue

        It "Should execute a method with no arguments" {
            $newInstance | => current | Should BeExactly $initialValue
        }

        It "Should execute a method with two arguments" {
            $newInstance | => add 1 3 | Should BeExactly 4
        }

        It "Should execute a method that takes an argument and incorporates object state" {
            $newInstance | => addto 2 | Should BeExactly 12
        }

        It "Should execute the same method on two different objects" {
            $newInstance2 |=> addto 3 | out-null
            $results = $newInstance2, $newInstance3 |=> addto 4

            $results[0] | Should BeExactly 17
            $results[1] | Should BeExactly 14
        }

        It "Should throw an exception if nothing is piped to it" {
            { => somemethod current } | Should Throw
        }

        It "Should throw an exception if no method is specified" {
            { $newInstance | => } | Should Throw
        }

        It "Should throw an exception if a non-existent method is specified" {
           {$newInstance |=> nonexistent} | Should Throw
        }

        It "Should throw an exception if a static method is specified" {
            {$newInstance |=> staticmethod} | Should Throw
        }

        It "Should invoke static methods when used on an instance's scriptclass property" {
            $newInstance.scriptclass |=> staticmethod 25 31 Should BeExactly 56
        }

        It "Should throw an exception if the method attempts to access the PSCmdlet variable when invoked by a cmdlet attributed with CmdletBinding" {
            ScriptClass ClassUsingPsCmdlet {
                function Get {
                    $PSCmdlet
                }
            }

            function Get-PSCmdlet {
                [cmdletbinding()]
                $myobj = new-so ClassUsingPsCmdlet

                $myobj |=> Get
            }

            { Get-PSCmdlet } | Should Throw
        }

        It "should successfully invoke a method added to a class instance with add-memeber after the class was instantiated with new-scriptobject" {
            ScriptClass PostClass {
                function firstMethod($arg1, $arg2) {
                    $arg1 + $arg2
                }
            }

            $instance = new-so PostClass

            $instance | add-member -membertype ScriptMethod -name secondMethod -value {param($firstArg, $secondArg) $firstArg + $secondArg}

            $instance |=> firstMethod 3 4 | Should Be 7
            $instance |=> secondMethod 4 5 | Should be 9
        }
    }
}


Describe 'Static method invocation' {
    BeforeAll {
        remove-module $thismodule -force -erroraction ignore
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction ignore
    }

    ScriptClass ClassClass52 {
        static {
            function staticmethod($arg1, $arg2) {
                $arg1 + $arg2
            }

            function staticmethod2($arg1, $arg2) {
                $this |=> staticmethod $arg1 $arg2
            }
        }

        function instancemethod {}
    }

    Context "When a static method is invoked through ::>" {
        It 'Should accept the name of the class as a string as the class on which to call the method' {
            'ClassClass52' |::> staticmethod 8 5 | Should BeExactly 13
        }

        It "should accept the scriptclass property of an instance as a way to invoke the static method" {
            $newInstance = new-scriptobject ClassClass52
            withobject $newInstance.scriptclass staticmethod 20 50 Should BeExactly 70
        }

        It "should be accessible from within the class initializer" {
            ScriptClass ClassClass74 {
                $mainValue = $null
                static {
                    function InitialVal {
                        7
                    }
                }
                function __initialize {
                    $this.mainValue = ('ClassClass74' |::> InitialVal)
                }
            }

            $newInstance = new-so ClassClass74

            $newInstance.mainValue | Should BeExactly 7
        }

        It "has a `$this variable available to static methods that enables access to other static members in the class" {
            $::.ClassClass52 |=> staticmethod2 13 3 | Should BeExactly 16
        }

        It "should throw an exception if the type piped to ::> is not a string" {
            { $::.ClassClass52 |::> instancemethod } | Should Throw
        }

        It "should throw an exception if the class piped to ::> does not exist" {
            { 'idontexist' |::> instancemethod } | Should Throw
        }

        It "should throw an exception if the method passed to ::> does not exist" {
            { 'ClassClass52' |::> idontexist } | Should Throw
        }


        It "Should throw an exception if the operator is used to call an instance method" {
            { 'ClassClass52' |::> instancemethod } | Should Throw
        }
    }

    Context "When a static method is invoked through invoke-method or with or =>" {
        It 'Should accept the result of Get-ScriptClass as the class on which to call the method for invoke-methodwithcontext' {
            invoke-method (Get-ScriptClass ClassClass52) staticmethod 2 3 | Should BeExactly 5
        }

        It 'Should accept the result of Get-ScriptClass as the class on which to call the method for "with"' {
            withobject (Get-ScriptClass ClassClass52) staticmethod 2 3 | Should BeExactly 5
        }

        It 'Should allow invocation of the static method by supplying "withobject" with a block' {
            withobject (Get-ScriptClass ClassClass52) { staticmethod 10 40 } Should BeExactly 50
        }

        It 'Should allow invocation of the static method by supplying scriptclass method as the object' {
            $newInstance = new-scriptobject ClassClass52
            withobject $newInstance.scriptclass staticmethod 20 50 Should BeExactly 70
        }

        It "Should accept the `$:: variable's property named by the class as the class on which to call the method using =>" {
            $::.ClassClass52 |=> staticmethod 10 4 | Should BeExactly 14
        }

        It 'Should accept the result of Get-ScriptClass as the class on which to call the method using =>' {
            (Get-ScriptClass ClassClass52) |=> staticmethod 2 3 | Should BeExactly 5
        }

        It "Should allow arguments to a static scriptclass method to be passed by name" {
            ScriptClass MethodByNameClass {
                static {
                    function NameMethod($arg1 = 0, $arg2 = 0, $arg3 = 0) {
                        $arg3 + $arg2 * 10 + $arg1 * 100
                    }
                }
            }

            $::.MethodByNameClass |=> NameMethod 6 4 5 | Should Be 645

            $::.MethodByNameClass |=> NameMethod -Arg2 9 | Should Be 90
        }
    }
}

Describe "Context for common parameters" {
    BeforeAll {
        remove-module $thismodule -force -erroraction ignore
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction ignore
    }

    Context 'when the verbose common parameter is specified for the calling cmdlet' {
        ScriptClass VerboseClass {
            static {
                function StaticVerbose($data) {
                    write-verbose ('STATIC: ' + $data)
                }
            }

            function InstanceVerbose($data) {
                write-verbose $data
            }
        }

        function CallVerbose {
            [cmdletbinding()]
            param(
                $dataToWrite,
                [Switch] $Static
            )

            Enable-ScriptClassVerbosePreference

            if ( $Static.IsPresent ) {
                $::.VerboseClass |=> StaticVerbose $dataToWrite
            } else {
                $instance = new-so VerboseClass
                $instance |=> InstanceVerbose $dataToWrite
            }
        }

        $requestedOutput = 'this is verbose'
        $expectedInstanceVerboseOutput = $requestedOutput
        $expectedStaticVerboseOutput = 'STATIC: ' + $requestedOutput

        It "Should emit no verbose output when a static method is invoked from the calling function and verbose is not specified" {
            CallVerbose $requestedOutput -Static 4>&1 | Should Be $null
        }

        It "Should emit no verbose output when an instance method is invoked from the calling function and verbose is not specified" {
            CallVerbose $requestedOutput 4>&1 | Should Be $null
        }

        It "Should emit verbose output when a static method is invoked from the calling function and verbose is specified" {
            CallVerbose $requestedOutput -verbose -Static 4>&1 | Should Be $expectedStaticVerboseOutput
        }

        It "Should emit verbose output when an instance method is invoked from the calling function and verbose is specified" {
            CallVerbose $requestedOutput -verbose 4>&1 | Should Be $expectedInstanceVerboseOutput
        }
    }
}
