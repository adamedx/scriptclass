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

param($targetDirectory = $null)

set-strictmode -version 2
$erroractionpreference = 'stop'

$basepath = (get-item (split-path -parent $psscriptroot)).fullname
$packageManifest = join-path $basepath stdposh.nuspec

$outputDirectory = if ( $targetDirectory -ne $null ) {
    $targetDirectory
} else {
    join-path $basepath pkg
}

if ( ! (test-path $outputDirectory) ) {
    mkdir $outputDirectory | out-null
} else {
    ls $outputDirectory *.nupkg | rm
}

write-host "Building nuget package from manifest '$packageManifest'..."
write-host "Output directory = '$outputDirectory'..."

$nugetbuildcmd = "& nuget pack '$packageManifest' -outputdirectory '$outputdirectory'"
write-host "Executing command: ", $nugetbuildcmd

iex $nugetbuildcmd
$buildResult = $lastexitcode

if ( $buildResult -ne 0 ) {
    write-host -f red "Build failed with status code $buildResult."
    throw "Command `"$nugetbuildcmd`" failed with exit status $buildResult"
}

write-host -f green "Build succeeded."
