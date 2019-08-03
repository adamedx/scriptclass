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

function global:__ScriptClass__NewMethodBlock($scriptblock) {
    [ScriptBlock]::Create($scriptblock.tostring())
}

$nonModuleClasses = new-module {}
$nonModuleClasses | import-module
function global:__ScriptClass__NewBoundScriptBlock($scriptblock) {
    $nonModuleClasses.NewBoundScriptBlock($scriptblock)
}

. (join-path $psscriptroot ../std.ps1)

