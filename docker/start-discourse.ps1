# Quick start script for Discourse using official Docker image (Windows PowerShell)

$ErrorActionPreference = "Stop"

Write-Host "=== Starting SIRA Discourse Community ===" -ForegroundColor Cyan
Write-Host ""

# Check if environment file exists
if (-not (Test-Path "env.discourse.local")) {
    Write-Host "ERROR: env.discourse.local not found!" -ForegroundColor Red
    Write-Host "Please configure env.discourse.local with your settings." -ForegroundColor Yellow
    exit 1
}

# Check if secret key is set
$envContent = Get-Content "env.discourse.local" -Raw
if ($envContent -match "CHANGE_ME") {
    Write-Host "WARNING: Please update CHANGE_ME values in env.discourse.local" -ForegroundColor Yellow
    Write-Host "  - Generate secret key: ruby -e `"require 'securerandom'; puts SecureRandom.hex(64)`"" -ForegroundColor White
    Write-Host "  - Set SIRA_API_KEY" -ForegroundColor White
    Write-Host "  - Configure SMTP settings" -ForegroundColor White
    $response = Read-Host "Continue anyway? (y/N)"
    if ($response -ne "y" -and $response -ne "Y") {
        exit 1
    }
}

# Pull latest images (only downloads if updates available)
Write-Host "Checking for image updates..." -ForegroundColor Cyan
docker compose -f docker-compose.discourse.yml pull

# Start Discourse
Write-Host "Starting Discourse..." -ForegroundColor Green
docker compose -f docker-compose.discourse.yml up -d

Write-Host ""
Write-Host "✓ Discourse is starting..." -ForegroundColor Green
Write-Host "  - Access at: https://local.community.sira.ai:8443" -ForegroundColor White
Write-Host "  - Check logs: docker compose -f docker-compose.discourse.yml logs -f discourse" -ForegroundColor White
Write-Host "  - Stop: docker compose -f docker-compose.discourse.yml down" -ForegroundColor White

