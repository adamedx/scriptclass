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

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
import-module "$here/../ScriptClass.psd1" -force

ScriptClass Complex {
    const ZERO_COORDINATE 0.0

    $Real = strict-val [double] $ZERO_COORDINATE
    $Imaginary = strict-val [double] $ZERO_COORDINATE

    function __initialize {
        $::.Complex |=> AddInstance
    }

    function Add($real, $imaginary) {
        $result = new-scriptobject Complex

        $result.real = $this.real + $real
        $result.imaginary = $this.imaginary + $imaginary

        $result
    }

    function Magnitude {
        [Math]::sqrt($this.real * $this.real + $this.imaginary * $this.imaginary)
    }

    function AsText {
        "$($this.real) + $($this.imaginary)i"
    }

    static {
        $Instances = strict-val [int] 0

        function AddInstance {
            $this.instances++
        }

        function Compare([PSTypeName('Complex')] $first, [PSTypeName('Complex')] $second) {
            if (($first |=> magnitude) -gt ($second |=> magnitude)) {
                1
            } elseif (($first |=> magnitude) -lt ($second |=> magnitude)) {
                -1
            } else {
                0
            }
        }

        function InstanceCount {
            $this.instances
        }
    }
}

$complex = new-scriptobject Complex
write-host ("Initial value: {0}, Magnitude = {1} " -f ($complex |=> AsText), ($complex |=> Magnitude))

$resultComplex = $complex |=> add 3 0
write-host "`nAdd (3, 0):"
write-host ("`tResult = {0}, Magnitude = {1}" -f ($resultcomplex |=> AsText), ($resultcomplex |=> Magnitude))

$resultComplex2 = $resultcomplex |=> add 0 4
write-host "`nAdd (0, 4):"
write-host ("`tResult = {0}, Magnitude = {1}" -f ($resultcomplex2 |=> AsText), ($resultcomplex2 |=> Magnitude))

write-host "`nWhat's greater?"
write-host ("{0} {2} {1}" -f ($resultcomplex |=> AsText), ($resultcomplex2 |=> AsText), @{-1='<';0='=';1='>'}[($::.Complex |=> Compare $resultComplex $resultComplex2)])

write-host ("`nTotal instances of Complex created: {0}" -f ($::.Complex |=> InstanceCount))

