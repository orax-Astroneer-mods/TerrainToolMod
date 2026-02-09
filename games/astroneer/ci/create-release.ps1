Push-Location (Join-Path $PSScriptRoot "../../..") -Verbose

#
# Create "AstroModLoader Classic" PAK archive
#

$astroneer_pakDirName = "000-$env:REPO_NAME-${env:VERSION}_P"
$astroneer_pakFileName = "$astroneer_pakDirName.pak"
$astroneer_resourcesDir = $env:RESOURCES_DIR

$releaseDir = $env:RELEASE_DIR
$astroneer_pakDir = Join-Path $releaseDir $astroneer_pakDirName

# Create the directory for AstroModLoader Classic
if (Test-Path $astroneer_pakDir) {
    Remove-Item -Path $astroneer_pakDir -Recurse -Force
}
New-Item -Path $astroneer_pakDir -ItemType Directory | Out-Null

# Create the UE4SS directory
$UE4SSDir = Join-Path $astroneer_pakDir "UE4SS"
New-Item -Path $UE4SSDir -ItemType Directory | Out-Null

# Delete enabled.txt because AstroModLoader Classic uses mods.txt to enable mods
Remove-Item -Path (Join-Path $env:TARGET_DIR "enabled.txt")

# Move existing TargetDir content into UE4SS
Get-ChildItem -Path $env:TARGET_DIR | Move-Item -Destination $UE4SSDir

#
# Write metadata.json
#

$metadataFile = "metadata.json"
$SourceMetadata = Join-Path -Path $PSScriptRoot -ChildPath ".." -AdditionalChildPath $astroneer_resourcesDir, $metadataFile
$TargetMetadata = Join-Path -Path $astroneer_pakDir $metadataFile

# Read file content
$Content = Get-Content $SourceMetadata -Raw

# Replace placeholders
$Content = $Content -replace '\{MOD_AUTHOR\}', $env:MOD_AUTHOR
$Content = $Content -replace '\{MOD_DESCRIPTION\}', $env:MOD_DESCRIPTION
$Content = $Content -replace '\{MOD_ID\}', $env:REPO_NAME
$Content = $Content -replace '\{MOD_HOMEPAGE\}', $env:MOD_HOMEPAGE
$Content = $Content -replace '\{MOD_NAME\}', $env:MOD_NAME
$Content = $Content -replace '\{GITHUB_REPOSITORY\}', $env:GITHUB_REPOSITORY
$Content = $Content -replace '\{VERSION\}', $env:VERSION

Set-Content -Path $TargetMetadata -Value $Content -Encoding utf8

#
# Create the PAK file
# https://astroneermodding.readthedocs.io/en/latest/guides/basicSetup.html#setting-up-repak
# https://github.com/trumank/repak
#

$RepakExe = Join-Path $env:RESOURCES_DIR "repak_cli-x86_64-pc-windows-msvc/repak.exe"

if (-not (Test-Path $astroneer_pakDir)) {
    throw "PAK directory does not exist: $astroneer_pakDir"
}

$CmdArgs = @("pack", "--version", "V4", $astroneer_pakDir)
Write-Output "Run command: $RepakExe $($CmdArgs -join ' ')"
& $RepakExe @CmdArgs

$PakFilePath = Join-Path $releaseDir $astroneer_pakFileName

if ($LASTEXITCODE -ne 0) {
    throw "PAK build failed: $RepakExe returned exit code $LASTEXITCODE."
}

if (-not (Test-Path $PakFilePath)) {
    throw "PAK build failed: File not found at expected location -> $PakFilePath"
}

Pop-Location
