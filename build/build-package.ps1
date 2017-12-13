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

$basedirectory = get-item (split-path -parent $psscriptroot)
$basepath = $basedirectory.fullname
$moduleName = $basedirectory.name
$packageManifest = join-path $basepath "$moduleName.nuspec"
$moduleManifestPath = join-path $basepath "$moduleName.psd1"

$moduleVersion = (test-modulemanifest $moduleManifestPath).version

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

$nugetbuildcmd = "& nuget pack '$packageManifest' -outputdirectory '$outputdirectory' -nopackageanalysis -version '$moduleVersion'"
write-host "Executing command: ", $nugetbuildcmd

iex $nugetbuildcmd
$buildResult = $lastexitcode

if ( $buildResult -ne 0 ) {
    write-host -f red "Build failed with status code $buildResult."
    throw "Command `"$nugetbuildcmd`" failed with exit status $buildResult"
}

$packagePath = ((ls $outputdirectory -filter *.nupkg) | select -first 1).fullname

write-host "Package successfully built at '$packagePath'"
write-host -f green "Build succeeded."
