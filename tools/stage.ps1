#Requires -Version 5.0
$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot
$AddonName = "BetterEventReminders"
$TocFile = Join-Path $RootDir "$AddonName.toc"
$ReleaseDir = Join-Path $RootDir ".release"
$StageDir = Join-Path -Path (Join-Path $ReleaseDir "stage") -ChildPath $AddonName

$versionMatch = Get-Content $TocFile | Select-String -Pattern '^## Version:\s*(.*)$' | Select-Object -First 1
if (-not $versionMatch) {
    Write-Error "Could not read version from $TocFile"
}
$Version = $versionMatch.Matches.Groups[1].Value.Trim()

$Output = Join-Path $ReleaseDir "$AddonName-$Version.zip"

if (Test-Path $ReleaseDir) {
    Remove-Item -Recurse -Force $ReleaseDir
}
New-Item -ItemType Directory -Path $StageDir -Force | Out-Null

Copy-Item -Path (Join-Path $RootDir "*.lua") -Destination $StageDir
Copy-Item -Path $TocFile -Destination $StageDir
Copy-Item -Path (Join-Path $RootDir "LICENSE") -Destination $StageDir

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null

$archive = [System.IO.Compression.ZipFile]::Open($Output, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in Get-ChildItem -Path $StageDir -Recurse -File) {
        $relativePath = $file.FullName.Substring($StageDir.Length + 1).Replace('\', '/')
        $zipPath = "$AddonName/$relativePath"
        $entry = $archive.CreateEntry($zipPath)
        $entry.LastWriteTime = $file.LastWriteTime

        $sourceStream = [System.IO.File]::OpenRead($file.FullName)
        $targetStream = $entry.Open()
        try {
            $sourceStream.CopyTo($targetStream)
        } finally {
            $targetStream.Dispose()
            $sourceStream.Dispose()
        }
    }
} finally {
    $archive.Dispose()
}

$archiveInfo = Get-Item $Output

Write-Output "Successfully staged $AddonName v$Version"
Write-Output "Archive: $Output"
Write-Output "Size: $([math]::Round($archiveInfo.Length / 1KB, 2)) KB"
Write-Output "Contents:"

Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
$archive = [System.IO.Compression.ZipFile]::OpenRead($Output)
try {
    foreach ($entry in $archive.Entries | Select-Object -First 20) {
        Write-Output "  $($entry.FullName)"
    }
} finally {
    $archive.Dispose()
}
