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

function global:__ScriptClass__NewMethodBlock($scriptblock) {
    [ScriptBlock]::Create($scriptblock.tostring())
}

$nonModuleClasses = new-module {}
$nonModuleClasses | import-module
function global:__ScriptClass__NewBoundScriptBlock($scriptblock) {
    $nonModuleClasses.NewBoundScriptBlock($scriptblock)
}

<#
. (join-path $psscriptroot mock/PatchedObject.ps1)
. (join-path $psscriptroot mock/PatchedClassMethod.ps1)
. (join-path $psscriptroot mock/MethodPatcher.ps1)
. (join-path $psscriptroot mock/MethodMocker.ps1)
. (join-path $psscriptroot Initialize-ScriptClassTest.ps1)
. (join-path $psscriptroot Mock-ScriptClassMethod.ps1)
. (join-path $psscriptroot New-ScriptObjectMock.ps1)
. (join-path $psscriptroot Unmock-ScriptClassMethod.ps1)
#>
<#
. (join-path scriptobject/model/ClassTable.ps1)
. (join-path $psscriptroot scriptobject/model/ClassTable.ps1)
. (join-path $psscriptroot scriptobject/dsl/ClassDsl.ps1)
. (join-path $psscriptroot scriptobject/model/ClassDefinition.ps1)
. (join-path $psscriptroot scriptobject/model/MethodInvocation.ps1)
#>
