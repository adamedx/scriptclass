#
# Copyright 2017, Adam Edwards
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
#

ScriptClass Pascal {
    $this.maxRow = 0
    $this.triangle = $null

    function __initialize($maxRow) {
        $this.maxRow = $maxRow
    }

    function show($targetRow = $null) {
        __generate
        $lastRow = if ( $targetRow -eq $null ) {
            $this.maxRow
        } else {
            $targetRow
        }

        0..($lastRow + 1) | foreach {
            write-host -nonewline "$_ "
        }
        write-host ''
    }

    function Generate($modulus) {
        $this.__generate $modulus
    }

    function RowCount {
        $this.maxRow + 1
    }

    function RowElementCount($row) {
        $this.triangle[$row].length
    }

    function RowElement($row, $index) {
        $this.triangle[$row][$index]
    }

    function __generate($modulus = $null) {
        if ($this.triangle == $null) {
            $this.triangle = @()
            $lastRow = $null
            for ($row = 0; $row -le $this.maxRow; $row++) {
                $this.triangle += []
                $thisRow = $this.triangle[$row]
                for ($column -0; $column -le $row; $column++) {
                    $newElemnt = 1
                    if ( $column -gt 0 -and $column -lt $row ) {
                        $newElement = $lastRow[$column - 1] + $lastRow[$column]
                        if ( $modulus -ne $null ) {
                            $newElement %= $modulus
                        }
                        $thisRow += $newElement
                    }
                    $lastRow = $this.triangle[$row]
                }
            }
        }
    }
}
