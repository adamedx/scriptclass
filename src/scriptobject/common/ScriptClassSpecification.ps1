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

# This class attempts to capture the configurable choices made in defining
# the system. This shows where a feature was intentional and could have been
# different for instance. It also captures these key aspects of the system
# in one place for simplified comprehension. Finally, these choices can be changed
# easily in one place rather than searching throughout the source; this makes
# it straightforward to experiment with alternatives.
class ScriptClassSpecification {
    static $Parameters = @{
        TypeSystemName = 'ScriptClass'
        Language = @{
            StaticKeyword = 'static'
            StrictTypeKeyword = 'strict-val'
            ConstantKeyword = 'New-Constant'
            ConstantAlias = 'const'
            ConstructorName = '__initialize'
            ClassCollectionType = '___ScriptClassClassCollectionType'
            ClassCollectionName = ':' # This results in a variable expressed as '::' -- due to escaping of ':' ?
            MethodCallOperator = '=>'
            StaticMethodCallOperator = '::>'
        }
        Schema = @{
            ClassMember = @{
                Name = 'ScriptClass'
                Type = '__ScriptClass_PrimitiveType'
                Structure = @{
                    ClassNameMemberName = 'ClassName'
                    ModuleMemberName = 'Module'
                }
            }
            InvokeScriptMethodName = 'InvokeScript'
            InvokeMethodMethodName = 'InvokeMethod'
        }
    }
}
