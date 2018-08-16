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

ScriptClass SimpleImage {
    $width = 0
    $height = 0
    $sparse = $false
    $sparse_size = 0
    $defaultColor = 0
    $sparseMap = @{}
    $imageData = $null

    function __initialize($width, $height, $sparse = $false, $defaultColor = 0) {
        $this.width = $width
        $this.height = $height
        $this.sparse_size = 0
        $this.defaultColor= $defaultColor
        $this.sparse = $sparse
        $this.sparseMap = {}
        $this.imageData = if ( $this.sparse ) {
            @()
        } else {
            $pixelCount = $this.width * $this.height
            $pixels = 1..$pixelCount
            while ( $pixelCount -gt 0 ) { $pixelCount --; $pixels[$pixelCount] }
            $pixels
        }
    }

    function GetPixel($x, $y) {
        $pixelIndex = __getPixelIndex($x, $y)
        if ($this.sparse) {
            $existingPixel = $this.__findSparsePixel($pixelIndex)
            if ( $existingPixel -eq $null ) {
                $this.defaultColor
            } else {
                $this.imageData[$existingPixel + 1]
            }
        } else {
            $this.imageData[$pixelIndex]
        }
    }

    function GetSerializableImage {
        @{
            width = $this.width
            height = $this.height
            format = if ($this.sparse) { 1 } { 0 }
            sparseSize = $this.sparse_size
            imageData = $this.imageData
        }
    }

    function __getpixelindex( $x, $y ) {
        if ( $x -lt 0 -or $x -gt $this.width ) {
            throw ("get_pixel: x coordinate value `{0}` not in the range 0 to {1}" -f $x, ($this.width - 1))
        }

        if ( $y -lt 0 -or $y -gt $this.height ) {
            throw ("get_pixel: y coordinate value `{0}` not in the range 0 to {1}" -f $y, ($this.height - 1))
        }

        y * $this.width + x
    }

    function __newSparsePixelOffset {
        $this.sparseSize * 2
    }

    function __addSparsePixel($pixelIndex) {
        $newOffset = __newSparsePixelOffset
        $this.imageData += $pixelIndex
        $this.imageData += $this.defaultColor
        $this.sparseMap[$pixelIndex] = $newOffset
        $this.sparseSize += 1
    }

    function __findSparsePixel($pixelIndex) {
        if ( $this.sparseMap.contains($pixelIndex) ) {
            $this.sparseMap[$pixelIndex]
        } else {
            $null
        }
    }

    function __validateColor($x, $y, $color) {
        $newColor = $this.getPixel($x, $y)
        if ($newColor -ne $color) {
            throw ("At {0},{1} the color should be {2}, but {3} was returned" -f $x, $y, $color, $newcolor)
        }
    }

    function __validateUserColor($red, $green, $blue, $alpha) {
        $color = @{red=$red;blue=$blue;green=$green;alpha=$alpha}
        $color.getenumerator() | foreach {
            if ( $_.value -isnot [int] -or ( $_.value -lt 0 -or $_.value -gt 255)) {
                throw ("Color component {0}='{1}' is not an 8-bit integer" -f component, value)
            }
        }
    }
}
