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

. (join-path $psscriptroot cmdlet/Add-MockInScriptClassScope.ps1)
. (join-path $psscriptroot cmdlet/Add-ScriptClassMock.ps1)
. (join-path $psscriptroot cmdlet/Enable-ScriptClassVerbosePreference.ps1)
. (join-path $psscriptroot cmdlet/Import-Assembly.ps1)
. (join-path $psscriptroot cmdlet/Import-Script.ps1)
. (join-path $psscriptroot cmdlet/Invoke-Method.ps1)
. (join-path $psscriptroot cmdlet/Get-ScriptClass.ps1)
. (join-path $psscriptroot cmdlet/New-ScriptClass.ps1)
. (join-path $psscriptroot cmdlet/New-ScriptObject.ps1)
. (join-path $psscriptroot cmdlet/New-ScriptObjectMock.ps1)
. (join-path $psscriptroot cmdlet/Remove-ScriptClassMock.ps1)
. (join-path $psscriptroot cmdlet/Test-ScriptObject.ps1)
