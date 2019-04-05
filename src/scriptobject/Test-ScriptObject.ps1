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

function Test-ScriptObject {
    [cmdletbinding()]
    param(
        [parameter(valuefrompipeline=$true, mandatory=$true)] $Object,
        $Class = $null
    )
    $classMemberInfo = [ScriptClassSpecification]::Parameters.Schema.ClassMember

    $className = $null

    if ( $Class ) {
        $className = if ( $Class -is [string] ) {
            $Class
        } elseif ( $Class | gm $classMemberInfo.Name -erroraction ignore ) {
            $Class.$($classMemberInfo.Structure.ClassNameMemberName)
        }

        if ( ! $className ) {
            throw "'Class' argument must be of type [string] or it must be a scriptclass class instance"
        }
    }

    return [ClassManager]::Get().IsClassType($Object, $className)
}

