#Requires -Version 7.0
<#
.SYNOPSIS
  Idempotent Garage bootstrap: layout + bucket + S3 key.
  PowerShell twin of garage-init.sh (Windows, macOS, Linux).
.DESCRIPTION
  Run after `docker compose up -d postgres garage` from lakes/local-pg-s3/.
  No .env needed: every value falls back to the hardcoded dev defaults
  (same as compose.yaml / seed.sql). A `.env` file (see .env.example) or
  environment variables only override those defaults.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot '..')

# Optional overrides first (ignores blanks and # comments) ...
if (Test-Path '.env') {
    Get-Content '.env' | Where-Object { $_ -match '^\s*[^#\s][^=]*=' } | ForEach-Object {
        $k, $v = $_ -split '=', 2
        Set-Item "env:$($k.Trim())" $v.Trim()
    }
}
# ... then hardcoded dev defaults.
if (-not $env:S3_BUCKET) { $env:S3_BUCKET = 'ducklake-data' }
if (-not $env:S3_KEY_ID) { $env:S3_KEY_ID = 'GK0123456789abcdef01234567' }
if (-not $env:S3_SECRET_KEY) { $env:S3_SECRET_KEY = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' }

function Invoke-Garage {
    $out = docker compose exec -T garage /garage @args 2>&1
    return @{ Output = ($out -join "`n"); Exit = $LASTEXITCODE }
}

Write-Host '==> waiting for garage daemon...'
do {
    $st = Invoke-Garage 'status'
    if ($st.Exit -ne 0) { Start-Sleep 1 }
} until ($st.Exit -eq 0)
Write-Host $st.Output

$nodeOut = Invoke-Garage 'node', 'id'
$nodeId = ([regex]::Matches($nodeOut.Output, '[0-9a-f]{32,}') | Select-Object -First 1).Value
if (-not $nodeId) {
    $nodeId = ($st.Output -split "`n" | Where-Object { $_ -match '^[0-9a-f]{4,}' } | Select-Object -First 1) -split '\s+' | Select-Object -First 1
}
Write-Host "==> node id: $nodeId"
$short = $nodeId.Substring(0, 16)
Write-Host "==> short id: $short"

$layout = Invoke-Garage 'layout', 'show'
if ($layout.Output -match [regex]::Escape($short)) {
    Write-Host '==> layout already assigned, skipping assign'
} else {
    Write-Host '==> assigning layout (zone dc1, capacity 1G)...'
    Invoke-Garage 'layout', 'assign', '-z', 'dc1', '-c', '1G', $short | Out-Null
}

$layout = Invoke-Garage 'layout', 'show'
if ($layout.Output -match '(?i)no staged|nothing to commit|current version.*1|version: 1') {
    Write-Host '==> layout version already applied (or nothing staged)'
} else {
    Write-Host '==> applying layout...'
    $applied = Invoke-Garage 'layout', 'apply', '--version', '1'
    if ($applied.Exit -ne 0) { Invoke-Garage 'layout', 'apply' | Out-Null }
}
Write-Host (Invoke-Garage 'layout', 'show').Output

Write-Host "==> ensuring bucket '$env:S3_BUCKET'..."
$bucket = Invoke-Garage 'bucket', 'create', $env:S3_BUCKET
if ($bucket.Exit -ne 0) { Write-Host '(bucket exists, continuing)' }

Write-Host "==> ensuring key '$env:S3_KEY_ID'..."
$key = Invoke-Garage 'key', 'info', $env:S3_KEY_ID
if ($key.Exit -eq 0) {
    Write-Host '(key exists, continuing)'
} else {
    # deterministic credentials so seed scripts can read them without parsing
    Invoke-Garage 'key', 'import', '--yes', '-n', 'ducklake-local', $env:S3_KEY_ID, $env:S3_SECRET_KEY | Out-Null
}

Write-Host '==> granting read+write on bucket to key...'
Invoke-Garage 'bucket', 'allow', '--read', '--write', $env:S3_BUCKET, '--key', $env:S3_KEY_ID | Out-Null

Write-Host '==> bucket info:'
Write-Host (Invoke-Garage 'bucket', 'info', $env:S3_BUCKET).Output
Write-Host ''
$port = if ($env:GARAGE_S3_PORT) { $env:GARAGE_S3_PORT } else { '3900' }
$region = if ($env:GARAGE_REGION) { $env:GARAGE_REGION } else { 'garage' }
Write-Host "done. S3 endpoint: http://127.0.0.1:$port  region: $region"
