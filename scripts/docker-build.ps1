#Requires -Version 5.1
param(
    [string]$ImageTag = 'marefati110/n8n-ent:2.27.3-ce.2'
)

$ErrorActionPreference = 'Stop'

$SourceRoot = Split-Path -Parent $PSScriptRoot
$BuildRoot = Join-Path $env:TEMP 'n8n-docker-build'

function Test-DockerPathAccess {
    param([string]$Path)
    try {
        docker build -f "$Path/Dockerfile" -t n8n-path-test "$Path" 2>&1 | Out-Null
        return $LASTEXITCODE -eq 0 -or (docker build -f "$Path/Dockerfile" -t n8n-path-test "$Path" 2>&1 | Select-String 'transferring dockerfile: 2B') -eq $null
    } catch {
        return $false
    }
}

Write-Host "Source: $SourceRoot"
Write-Host "If Docker Desktop cannot access drive E:, enable it in:"
Write-Host "  Docker Desktop -> Settings -> Resources -> File sharing -> add E:"
Write-Host ""

Write-Host "Syncing source to $BuildRoot ..."
if (Test-Path $BuildRoot) {
    Remove-Item $BuildRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $BuildRoot | Out-Null

$robocopyArgs = @(
    $SourceRoot,
    $BuildRoot,
    '/E',
    '/XD', 'node_modules', '.git', '.turbo', 'compiled', 'dist', '.agent-setup',
    '/XF', 'build.log',
    '/NFL', '/NDL', '/NJH', '/NJS', '/NC', '/NS'
)
& robocopy @robocopyArgs | Out-Null
if ($LASTEXITCODE -ge 8) {
    throw "robocopy failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path (Join-Path $BuildRoot 'Dockerfile'))) {
    throw "Dockerfile missing in $BuildRoot after sync"
}

Write-Host "Building $ImageTag (this can take 30-60 minutes) ..."
docker build -t $ImageTag $BuildRoot
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host ''
Write-Host 'Build finished. Quick check:'
docker run --rm $ImageTag n8n --version
