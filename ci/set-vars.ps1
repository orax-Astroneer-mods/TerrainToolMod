[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$github_ref_name,

    [Parameter(Mandatory)]
    [string]$github_repository
)

Set-StrictMode -Version Latest

Push-Location (Join-Path $PSScriptRoot "..") -Verbose

Write-Host "🏷️ github_ref_name: $github_ref_name"
Write-Host "📦 github_repository: $github_repository"

$projectRootDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$version = $github_ref_name -replace '^v(?=\d+\.\d+\.\d+)', ''
$repoOwner, $repoName = $github_repository -split '/'

$tempDir = ".TEMP"
$releaseDir = ".RELEASE"
$resourcesDir = "resources"
$targetDir = Join-Path $releaseDir $repoName
     
$releaseFilename = "$repoName.zip"
$releaseRelPath = Join-Path $releaseDir $releaseFilename

# Read the mod metadata in the mod.json file.
$jsonPath = Join-Path $projectRootDir "mod.json"
$jsonRawContent = Get-Content -Path $jsonPath -Raw -Encoding utf8
$schemaPath = Join-Path "resources" "schema.json"
if (-not ($jsonRawContent | Test-Json)) {
    throw "❌ Malformed JSON (syntax error). JSON path: $jsonPath"
}
if (-not ($jsonRawContent | Test-Json -SchemaFile $schemaPath)) {
    throw "❌ JSON is valid but does not conform to the schema rules. JSON path: $jsonPath"
}
$modMetadata = $jsonRawContent | ConvertFrom-Json

$description = ""
if ($modMetadata.description -is [Array]) {
    $description = $modMetadata.description -join '\n'
}
else {
    $description = $modMetadata.description
}

@{
    PROJECT_ROOT_DIR   = $projectRootDir

    VERSION            = $version
    REPO_OWNER         = $repoOwner
    REPO_NAME          = $repoName
    MOD_AUTHOR         = $modMetadata.author
    MOD_DESCRIPTION    = $description
    MOD_HOMEPAGE       = $modMetadata.homepage
    MOD_NAME           = $modMetadata.name

    $GITHUB_REPOSITORY = $github_repository

    RESOURCES_DIR      = $resourcesDir
    TEMP_DIR           = $tempDir
    RELEASE_DIR        = $releaseDir
    TARGET_DIR         = $targetDir

    RELEASE_FILENAME   = $releaseFilename
    RELEASE_REL_PATH   = $releaseRelPath
}.GetEnumerator() | ForEach-Object {
    if ($env:GITHUB_ENV) {
        # Export for next GitHub Actions steps
        "$($_.Key)=$($_.Value)" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8
    }
    else {
        # Make variable available in the current script (useful when script is run locally)
        Set-Item -Path "env:$($_.Key)" -Value $_.Value
    }
}

# List of directories to create
$dirs = @($resourcesDir, $tempDir, $releaseDir)

# Create each directory if it doesn't exist
foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        Write-Output "📁 Create directory: $dir"
        New-Item -Path $dir -ItemType Directory | Out-Null
    }
}

Pop-Location
