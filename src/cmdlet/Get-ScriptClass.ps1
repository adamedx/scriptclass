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

function Get-ScriptClass {
    [cmdletbinding(defaultparametersetname='ClassName', positionalbinding=$false)]
    param (
        [parameter(position=0, parametersetname='ClassName', mandatory=$true)]
        [string] $ClassName,

        [parameter(position=0, parametersetname='Object', mandatory=$true)] $Object,
        [switch] $Detailed
    )

    $schema = [ScriptClassSpecification]::Parameters.Schema

    $targetClass = if ( $Object ) {
        $Object.$($schema.ClassMember.Name).$($schema.ClassMember.Structure.ClassNameMemberName)
    } else {
        $ClassName
    }
    $classInfo = [ClassManager]::Get().GetClassInfo($targetClass)

    if ( $Detailed.IsPresent ) {
        $classInfo
    } else {
        $prototype = [ClassManager]::Get().GetClassInfo($targetClass).prototype
        $prototype.$($Schema.ClassMember.Name)
    }
}
