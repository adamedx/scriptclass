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

function __PatchedObject_New($object) {
    @{
        Object = $object
        MockScriptBlock = $null
        ParameterFilter = $null
    }
}

function __PatchedObject_Mock($patchedObject, $mockScriptBlock, $parameterFilter) {
    $patchedObject.MockScriptBlock = $mockScriptBlock

    # TODO: Add additional filtering to the parameter filter so it only applies
    # to this object so that even after this module's tracking of this as a mocked
    # object is removed, the mock still applies only to this object
    $patchedObject.Parameterfilter = $parameterFilter
}

function __PatchedObject_IsPatched($object) {
    $objectId = try {
        $object.__ScriptClassMockedObjectId()
    } catch {
    }

    $objectId -ne $null
}

function __PatchedObject_AllocateUniqueId {
    $patchState = try {
        $script:__patchedObjectState
    } catch {
        $script:__patchedObjectState = [PSCustomObject] @{
            SerialStart = $null
            SerialCurrent = $null
        }
        $script:__patchedObjectState
    }

    if ( $patchState.SerialCurrent -eq $null ) {
        $random = [Random]::new()
        # The next method returns a positive signed [int32]
        $idStart = [uint64] $random.next()
        $idStart += [uint64] $random.next()
        $idStart *= [uint64] ([int32]::MaxValue)
        $idStart += [uint64] $random.next()
        $idStart += [uint64] $random.next()

        $patchState.SerialStart = $idStart
        $patchState.SerialCurrent = $idStart
    } elseif ( $patchState.SerialCurrent -eq $patchState.SerialStart ) {
        throw 'Maximum mock object count exceeded'
    }

    $nextId = if ( $patchState.SerialCurrent -eq [uint64]::MaxValue ) {
        0
    } else {
        $patchState.SerialCurrent + [uint64] 1
    }

    $patchState.SerialCurrent = $nextId
    $nextId
}

function __PatchedObject_GetUniqueId([PSCustomObject] $object) {
    if ( ! $object ) {
        throw 'The specified object was $null'
    }

    if ( ! ( __ScriptClass__IsScriptClass $object ) ) {
        throw 'The specified object was not a ScriptClass object'
    }

    $objectUniqueId = if ( $object | gm -membertype scriptmethod __ScriptClassMockedObjectId -erroraction ignore) {
        $object.__ScriptClassMockedObjectId()
    }

    if ( ! $objectUniqueId ) {
        $objectUniqueId = __PatchedObject_AllocateUniqueId

        $object | add-member -name __ScriptClassMockedObjectId -membertype scriptmethod -value ([ScriptBlock]::Create("[uint64] $($objectUniqueId.tostring())")) -force
    }

    $objectUniqueId
}
