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
$thismodule = join-path (split-path -parent $here) '../scriptclass.psd1'

Describe "The Get-ScriptClass cmdlet" {
    BeforeAll {
        remove-module $thismodule -force -erroraction ignore
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction ignore
    }

    ScriptClass ClassClass59 {
    }

    Context "When getting information about a class" {
        It "should return an object with a 'prototype' property equal to the class's scriptclass property" {
            $newInstance = new-scriptobject ClassClass59
            (Get-ScriptClass ClassClass59) | Should BeExactly $newInstance.scriptclass
        }

        It "should return an object with a null scriptclass" {
            (Get-ScriptClass ClassClass59).scriptclass | Should BeExactly $null
        }

        It "should throw an exception if the class does not exist" {
            { Get-ScriptClass idontexist } | Should Throw
        }
    }
}
