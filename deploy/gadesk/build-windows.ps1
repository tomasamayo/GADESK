#Requires -Version 7.3
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
if (-not $IsWindows -or [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'X64') {
    throw 'Build GADESK on Windows x64 with the toolchain from gadesk-windows.yml.'
}

$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$work = Join-Path $repo 'target/gadesk-windows'
$dist = Join-Path $work 'GADESK'
$output = Join-Path $work 'installers'
$version = '1.5.1'
New-Item -ItemType Directory -Force -Path $work, $output | Out-Null
if (Test-Path $dist) {
    throw "Staging directory already exists: $dist. Remove it before rebuilding."
}

Push-Location $repo
try {
    foreach ($file in 'src/bridge_generated.rs', 'src/bridge_generated.io.rs', 'flutter/lib/generated_bridge.dart', 'flutter/lib/generated_bridge.freezed.dart') {
        if (-not (Test-Path $file)) { throw "Missing generated bridge file: $file" }
    }

    python3 ./build.py --portable --flutter --skip-portable-pack --hwcodec --vram
    $release = Join-Path $repo 'flutter/build/windows/x64/runner/Release'
    foreach ($file in 'rustdesk.exe', 'librustdesk.dll', 'flutter_windows.dll', 'dylib_virtual_display.dll', 'data/app.so') {
        if (-not (Test-Path (Join-Path $release $file))) { throw "Build did not produce $file" }
    }
    Copy-Item $release $dist -Recurse
    Rename-Item (Join-Path $dist 'rustdesk.exe') 'GADESK.exe'
    $app = Join-Path $dist 'GADESK.exe'
    $reportedVersion = (& $app --version | Out-String).Trim()
    if ($reportedVersion -cne $version) { throw "Unexpected GADESK version: $reportedVersion" }

    Invoke-WebRequest https://github.com/rustdesk-org/rdev/releases/download/usbmmidd_v2/usbmmidd_v2.zip -OutFile "$work/usbmmidd_v2.zip"
    Expand-Archive "$work/usbmmidd_v2.zip" -DestinationPath $work
    Remove-Item "$work/usbmmidd_v2/Win32" -Recurse
    Remove-Item "$work/usbmmidd_v2/deviceinstaller64.exe", "$work/usbmmidd_v2/deviceinstaller.exe", "$work/usbmmidd_v2/usbmmidd.bat"
    Move-Item "$work/usbmmidd_v2" $dist

    $driverBase = 'https://github.com/rustdesk/hbb_common/releases/download/driver'
    Invoke-WebRequest "$driverBase/sha256sums" -OutFile "$work/driver-sha256sums"
    foreach ($archive in 'rustdesk_printer_driver_v4-1.4.zip', 'printer_driver_adapter.zip') {
        Invoke-WebRequest "$driverBase/$archive" -OutFile "$work/$archive"
        $pattern = '^([a-fA-F0-9]{64}) \*' + [regex]::Escape($archive) + '$'
        $match = Select-String -Path "$work/driver-sha256sums" -Pattern $pattern
        if (-not $match -or (Get-FileHash "$work/$archive" -Algorithm SHA256).Hash -ine $match.Matches.Groups[1].Value) {
            throw "Printer payload checksum mismatch: $archive"
        }
        Expand-Archive "$work/$archive" -DestinationPath $work
    }
    New-Item -ItemType Directory -Path "$dist/drivers" | Out-Null
    Move-Item "$work/rustdesk_printer_driver_v4-1.4" "$dist/drivers/RustDeskPrinterDriver"
    Move-Item "$work/printer_driver_adapter.dll" $dist

    git clone https://github.com/rustdesk-org/RustDeskTempTopMostWindow "$work/RustDeskTempTopMostWindow"
    git -C "$work/RustDeskTempTopMostWindow" checkout ecd8d6a139eee76845ea66423fb739af450fda90
    msbuild "$work/RustDeskTempTopMostWindow/WindowInjection/WindowInjection.vcxproj" -p:Configuration=Release -p:Platform=x64 /p:TargetVersion=Windows10
    Copy-Item "$work/RustDeskTempTopMostWindow/WindowInjection/x64/Release/WindowInjection.dll" $dist

    Push-Location (Join-Path $repo 'libs/portable')
    $manifestPath = Join-Path $repo 'res/manifest.xml'
    $manifest = [System.IO.File]::ReadAllText($manifestPath)
    try {
        [System.IO.File]::WriteAllText($manifestPath, ($manifest -replace '(?m)^.*dpiAware.*\r?\n', ''))
        python3 -m pip install -r requirements.txt
        python3 ./generate.py -f $dist -o . -e $app
    } finally {
        [System.IO.File]::WriteAllText($manifestPath, $manifest)
        Pop-Location
    }
    Copy-Item "$repo/target/release/rustdesk-portable-packer.exe" "$output/GADESK-$version-x86_64-install.exe"

    Push-Location (Join-Path $repo 'res/msi')
    try {
        python3 ./preprocess.py --arp -d $dist --app-name GADESK --manufacturer 'Grupo Amayo'
        nuget restore msi.sln
        msbuild msi.sln -p:Configuration=Release -p:Platform=x64 /p:TargetVersion=Windows10
        $msi = @(Get-ChildItem ./Package/bin/*/Release/en-us/Package.msi)
        if ($msi.Count -ne 1) { throw "Expected one MSI, found $($msi.Count)" }
        Copy-Item $msi[0].FullName "$output/GADESK-$version-x86_64.msi"
    } finally {
        Pop-Location
    }

    $hashes = Get-ChildItem $output -File | Where-Object { $_.Extension -in '.exe', '.msi' } | Sort-Object Name | ForEach-Object {
        '{0}  {1}' -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $_.Name
    }
    $hashes | Set-Content "$output/SHA256SUMS" -Encoding utf8NoBOM
    Get-ChildItem $output
} finally {
    Pop-Location
}
