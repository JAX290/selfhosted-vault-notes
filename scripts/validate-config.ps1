$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

foreach ($area in @('vps', 'nas')) {
    $directory = Join-Path $root $area
    $environmentFile = Join-Path $directory '.env'
    if (-not (Test-Path $environmentFile)) {
        throw "Missing $environmentFile. Copy .env.example to .env and fill it first."
    }
    docker compose --project-directory $directory --env-file $environmentFile config --quiet
}

Write-Host 'Both Compose configurations are valid.'

