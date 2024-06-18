[Reflection.Assembly]::LoadFrom("$((Get-Location).Path)\Newtonsoft.Json.dll")

$terribuild_min_config_version = 2

# EXE metadata configuration

$version_string = "1.1.0"
$tool_icon = "CoZIcon.ico"
$game_icon = "LauncherIcon.ico"
$publisher = "Committee of Zero"
$product_name = "ROBOTICS;NOTES ELITE Improvement Patch (Steam)"

# Game LB build configuration

# Proxy DLL used for this game (dinput8, winmm)
# TODO: single source of truth
# for now, must also be changed in installer/userdata/product.json
$languagebarrier_proxy_dll = "dinput8"

# Config

try {
    . ".\config.ps1"
}
catch {
    throw "Please put a config.ps1 from the provided config.ps1.sample in the repository root, and run this script from there."
}

if (-not (Test-Path "variable:terribuild_config_version") -or ($terribuild_config_version -lt $terribuild_min_config_version)) {
    throw "Your config.ps1 is outdated. See what's new in config.ps1.sample, change your local config and bump its version number."
}

# Code

function SetInstallerExeMetadata {
    param ([string]$exePath)
    $originalFilename = (Get-Item $exePath).Name
    .\rcedit-x86.exe $exePath `
        --set-icon "$tool_icon" `
        --set-file-version "$version_string" `
        --set-product-version "$version_string" `
        --set-version-string "CompanyName" "$publisher" `
        --set-version-string "FileDescription" "$product_name Installer (v$version_string)" `
        --set-version-string "FileVersion" "$version_string" `
        --set-version-string "InternalName" "Installer.exe" `
        --set-version-string "LegalCopyright" "$publisher" `
        --set-version-string "OriginalFilename" "$originalFilename" `
        --set-version-string "ProductName" "$product_name Installer" `
        --set-version-string "ProductVersion" "$version_string"
}
function SetUninstallerExeMetadata {
    param ([string]$exePath)
    $originalFilename = (Get-Item $exePath).Name
    .\rcedit-x86.exe $exePath `
        --set-icon "$tool_icon" `
        --set-file-version "$version_string" `
        --set-product-version "$version_string" `
        --set-version-string "CompanyName" "$publisher" `
        --set-version-string "FileDescription" "$product_name Uninstaller (v$version_string)" `
        --set-version-string "FileVersion" "$version_string" `
        --set-version-string "InternalName" "nguninstall.exe" `
        --set-version-string "LegalCopyright" "$publisher" `
        --set-version-string "OriginalFilename" "$originalFilename" `
        --set-version-string "ProductName" "$product_name Uninstaller" `
        --set-version-string "ProductVersion" "$version_string"
}

function SetRealbootExeMetadata {
    param ([string]$exePath)
    $originalFilename = (Get-Item $exePath).Name
    .\rcedit-x86.exe $exePath `
        --set-icon "$game_icon" `
        --set-file-version "$version_string" `
        --set-product-version "$version_string" `
        --set-version-string "CompanyName" "$publisher" `
        --set-version-string "FileDescription" "$product_name Launcher (v$version_string)" `
        --set-version-string "FileVersion" "$version_string" `
        --set-version-string "InternalName" "realboot.exe" `
        --set-version-string "LegalCopyright" "$publisher" `
        --set-version-string "OriginalFilename" "$originalFilename" `
        --set-version-string "ProductName" "$product_name Launcher" `
        --set-version-string "ProductVersion" "$version_string"
}

function GenerateEnscriptToc {
    param ([string]$tocPath, [string]$scriptsPath)
    $inToc = Import-CSV .\script_toc.csv -header Id, FilenameOnDisk, FilenameInArchive
    $jw = New-Object Newtonsoft.Json.JsonTextWriter(New-Object System.IO.StreamWriter($tocPath))
    $jw.Formatting = [Newtonsoft.Json.Formatting]::Indented
    $jw.Indentation = 2
    $jw.IndentChar = ' '
    $jw.WriteStartArray();
    foreach ($entry in $inToc) {
        $jw.WriteStartObject();
        $jw.WritePropertyName("id");
        $jw.WriteValue([int]$entry.Id);
        $jw.WritePropertyName("filename");
        $jw.WriteValue($entry.FilenameInArchive);
        $jw.WritePropertyName('size');
        $jw.WriteValue((Get-Item "$scriptsPath\$($entry.FilenameInArchive)").Length);
        $jw.WriteEndObject();
    }
    $jw.WriteEndArray();
    $jw.Flush()
    $jw.Close()
}

# END CONFIG

function PrintSection {
    param ([string]$desc)
    $line = "------------------------------------------------------------------------"
    $len = (($line.length, $desc.legnth) | Measure -Max).Maximum
    
    Write-Host ""
    Write-Host $line.PadRight($len) -BackgroundColor DarkBlue -ForegroundColor Cyan
    Write-Host ("      >> " + $desc).PadRight($len) -BackgroundColor DarkBlue -ForegroundColor Cyan
    Write-Host $line.PadRight($len) -BackgroundColor DarkBlue -ForegroundColor Cyan
    Write-Host ""
}

Write-Output "                          ＴＥＲＲＩＢＵＩＬＤ"
Write-Output "Rated World's #1 Build Script By Leading Game Industry Officials"
Write-Output ""
Write-Output "------------------------------------------------------------------------"
Write-Output ""

PrintSection "Creating new DIST and temp"
Remove-Item -Force -Recurse -ErrorAction SilentlyContinue .\DIST
New-Item -ItemType directory -Path .\DIST | Out-Null
Remove-Item -Force -Recurse -ErrorAction SilentlyContinue .\temp
New-Item -ItemType directory -Path .\temp | Out-Null
Remove-Item -Force -Recurse -ErrorAction SilentlyContinue .\symbols
New-Item -ItemType directory -Path .\symbols | Out-Null

PrintSection "Building LanguageBarrier as $languagebarrier_configuration"
& "$msbuild" "$languagebarrier_dir\LanguageBarrier\LanguageBarrier.vcxproj" "/p:Configuration=$languagebarrier_configuration"

PrintSection "Copying LanguageBarrier to DIST"
Copy-Item $languagebarrier_dir\languagebarrier\$languagebarrier_configuration\*.dll .\DIST
Copy-Item $languagebarrier_dir\languagebarrier\$languagebarrier_configuration\*.pdb .\symbols
Copy-Item -Recurse $languagebarrier_dir\languagebarrier\$languagebarrier_configuration\languagebarrier .\DIST
New-Item -ItemType directory -Path .\"DIST\NOTES ELITE" | Out-Null
Move-Item .\DIST\*.dll .\DIST\"NOTES ELITE"\
# Reported necessary for some users, otherwise:
# "Procedure entry point csri_renderer_default could not be located in ...\NOTES ELITE\DINPUT8.dll"
Copy-Item .\DIST\"NOTES ELITE"\VSFilter.dll .\DIST\

PrintSection "Building sc3tools"
cd sc3tools
cargo build --release --bin=sc3tools --package=sc3tools
cd ..

PrintSection "Patching scripts"
New-Item -ItemType directory -Path .\temp\patched_script_archive | Out-Null
copy script_archive_steam\*.msb temp\patched_script_archive
#$scripts = gci temp\patched_script_archive
#foreach ($script in $scripts)
#{
#    $patches = gci .\rne-script-patches\$($script.Name).*.vcdiff | Sort
#    foreach ($patch in $patches)
#    {
#        $scriptPath = $script.FullName
#        .\xdelta3.exe -d -s "$scriptPath" "$($patch.FullName)" "$scriptPath.tmp"
#        Remove-Item $scriptPath
#        Move-Item -Path "$scriptPath.tmp" -Destination "$scriptPath"
#    }
#}

# cd .\rne-scripts-git
cd .\rne-scripts
git pull
cd ..
# Get-ChildItem rne-scripts-git -filter *.txt -Recurse | Copy -Destination rne-scripts
.\sc3tools\target\release\sc3tools.exe replace-text temp\patched_script_archive\*.msb rne-scripts\*.txt rn
New-Item -ItemType directory -Path .\temp\merged_patches | Out-Null
New-Item -ItemType directory -Path .\DIST\languagebarrier\enscript | Out-Null
Copy-Item -Recurse -Force .\temp\patched_script_archive\* .\DIST\languagebarrier\enscript\

# LanguageBarrier currently needs this file to be present even if no string redirections are configured
echo $null > .\DIST\languagebarrier\stringReplacementTable.bin

PrintSection "Copying content to DIST"

Copy-Item -Recurse -Force .\content\* .\DIST
# DXVK
Move-Item .\DIST\d3d9 ".\DIST\NOTES ELITE"
Move-Item .\DIST\d3d10 ".\DIST\NOTES ELITE"
Move-Item .\DIST\d3d10_1 ".\DIST\NOTES ELITE"
Move-Item .\DIST\d3d10core ".\DIST\NOTES ELITE"
Move-Item .\DIST\d3d11 ".\DIST\NOTES ELITE"
Move-Item .\DIST\dxgi ".\DIST\NOTES ELITE"

PrintSection "Copying content to c0data"

New-Item -ItemType directory -Path .\DIST\languagebarrier\c0data | Out-Null
Copy-Item -Force .\c0data.cls .\DIST\languagebarrier
Get-ChildItem .\rne-edited-images\*.* -Recurse | Copy -Destination .\DIST\languagebarrier\c0data
Get-ChildItem .\models\*.* -Recurse | Copy -Destination .\DIST\languagebarrier\c0data

PrintSection "Building and copying realboot"
cd launcher
& .\realboot_build.bat
cd ..
SetRealbootExeMetadata .\launcher\deploy\LauncherC0.exe
Copy-Item -Recurse -Force .\launcher\deploy\* .\DIST
Copy-Item -Recurse -Force .\launcher\build\release\*.pdb .\symbols

PrintSection "Building noidget"
cd installer
& .\noidget_build.bat
cd ..
SetInstallerExeMetadata .\installer\deploy\noidget.exe
SetUninstallerExeMetadata .\installer\deployUninstaller\noidget.exe
Copy-Item -Recurse -Force .\installer\build\release\*.pdb .\symbols

PrintSection "Packing uninstaller"
cd installer\deployUninstaller
7z a -mx=0 ..\..\temp\sfxbaseUninstaller.7z .\*
cd ..\..
copy .\7zS2.sfx .\temp\UninstallerExtractor.exe
SetUninstallerExeMetadata -exePath .\temp\UninstallerExtractor.exe
cmd /c copy /b .\temp\UninstallerExtractor.exe + .\temp\sfxbaseUninstaller.7z DIST\nguninstall.exe

# Only change to switch to SFX installer: Uncomment section below, comment out section after that one
<#
PrintSection "Packing installer"
7z a -mx=0 .\temp\sfxbase.7z DIST
cd temp
7z a -mx=0 .\sfxbase.7z merged_patches
7z a -mx=0 .\sfxbase.7z merged_patches_c
cd ..
cd installer\deploy
7z a -mx=0 ..\..\temp\sfxbase.7z .\*
cd ..\..
copy .\7zS2.sfx .\temp\InstallerExtractor.exe
SetInstallerExeMetadata -exePath .\temp\InstallerExtractor.exe
cmd /c copy /b .\temp\InstallerExtractor.exe + .\temp\sfxbase.7z DIST\Installer.exe
#>

PrintSection "Packing installer"
cd temp
$patchFolderName = "RNEPatch-v$version_string-Setup"
New-Item -ItemType directory -Path $patchFolderName | Out-Null
cd $patchFolderName
New-Item -ItemType directory -Path DIST | Out-Null
Move-Item -Force ..\..\DIST\* .\DIST
#Move-Item -Force ..\merged_patches .
#Move-Item -Force ..\merged_patches_c .
Move-Item -Force ..\..\installer\deploy\* .
Move-Item -Force .\noidget.exe .\RNEPatch-Installer.exe
cd ..\..\DIST
7z a -mx=5 "$patchFolderName.zip" "..\temp\$patchFolderName"
cd ..

PrintSection "Removing temp"
Remove-Item -Force -Recurse .\temp