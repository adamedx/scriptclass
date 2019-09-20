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
$thismodule = join-path (split-path -parent $here) '../ScriptClass.psd1'

Describe 'The test-scriptobject cmdlet' {
    BeforeAll {
        remove-module $thismodule -force -erroraction ignore
        import-module $thismodule -force
    }

    AfterAll {
        remove-module $thismodule -force -erroraction ignore
    }

    ScriptClass ClassClass64 {}
    ScriptClass ClassClass65 {}
    $newInstance = new-scriptobject ClassClass64
    It 'Should return $true if only a scriptclass object instance is specified by position' {
        test-scriptobject $newInstance | Should BeExactly $true
    }

    It 'Should return $true if a scriptclass object instance is specified through the pipeline' {
        $newInstance | test-scriptobject | Should BeExactly $true
    }

    It 'Should return $true if a scriptclass object is specified with its script class type name' {
        test-scriptobject $newInstance ClassClass64 | Should BeExactly $true
    }

    It 'Should return $true if a scriptclass object is specified with its scriptclass class object' {
        test-scriptobject $newInstance $::.ClassClass64 | Should BeExactly $true
    }

    It 'Should return $false if a scriptclass object is specified with a valid scriptclass class name of a different scriptclass than the instance' {
        test-scriptobject $newInstance 'ClassClass65' | Should BeExactly $false
    }

    It 'Should return $false if a scriptclass object is specified with a valid scriptclass class object of a different scriptclass than the instance' {
        test-scriptobject $newInstance $::.ClassClass65 | Should BeExactly $false
    }

    It 'Should return $false if only a non-scriptclass object is specified' {
        test-scriptobject [Type] | Should BeExactly $false
        test-scriptobject 3 | Should BeExactly $false
    }

    It 'Should return $false if non-scriptclass object is specified with a scriptclass type name' {
        test-scriptobject ([Type]) ClassClass64 | Should BeExactly $false
        test-scriptobject 3 ClassClass64 | Should BeExactly $false
    }

    It 'Should return false if the scriptclass parameter is a string that is not the name of defined scriptclass' {
        test-scriptobject $newInstance 'idontexist' | Should Be $false
    }

    It 'Should throw an exception if the scriptclass parameter is not a PSCustomObject' {
        { test-scriptobject $newInstance 3 | out-null } | Should Throw
    }

    It 'Should throw an exception if the scriptclass parameter is not a PSCustomObject created with new-scriptobject with a PSTypeName that matches the class' {
        $custom = [PSCustomObject]@{field1=1;field2=2}
        $typedcustom = [PSCustomObject]@{field1=1;field2=2;PSTypeName='notascriptclass'}
        { test-scriptobject $newInstance $custom | out-null } | Should Throw
        { test-scriptobject $newInstance $typedcustom | out-null } | Should Throw
    }
}
