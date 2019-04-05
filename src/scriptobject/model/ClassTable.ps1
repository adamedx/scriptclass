
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

$__ScriptClass__ClassTable = @{}

function global:__ScriptClass__GetClass([string] $className) {
    $existingClass = $__ScriptClass__ClassTable[$className]

    if (! $existingClass ) {
        throw "class '$className' not found"
    }

    $existingClass
}

function global:__ScriptClass__FindClass([string] $className) {
    $__ScriptClass__ClassTable[$className]
}

function global:__ScriptClass__SetClass([string] $className, [object] $classDefinition) {
    $__ScriptClass__ClassTable[$className] = $classDefinition
}

function global:__ScriptClass__RemoveClass([string] $className) {
    $__ScriptClass__ClassTable.Remove($className)
}

function global:__ScriptClass__IsScriptClass($object) {
    if ( $Object -is [PSCustomObject] ) {
        $objectClassName = try {
            $Object.scriptclass.classname
        } catch {
            $null
        }

        # Does the object's scriptclass object specify a valid type name and does its
        # PSTypeName match?
        ($objectClassName -and (__ScriptClass__GetClass $objectClassName) -ne $null) -and $Object.psobject.typenames.contains($objectClassName)
    } else {
        $false
    }
}

