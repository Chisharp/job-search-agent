<#
.SYNOPSIS
    First-time setup for the Job Search Agent.
    Run this once on any new system before using the agent.
#>

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Job Search Agent - First Time Setup"
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check if Python is available (for .py version)
$pythonAvailable = $false
try {
    $pyVersion = python --version 2>&1
    if ($pyVersion -match "Python \d") {
        Write-Host "[OK] Python found: $pyVersion" -ForegroundColor Green
        $pythonAvailable = $true
    }
} catch {}

if (-not $pythonAvailable) {
    Write-Host "[INFO] Python not found. You can use the PowerShell version (job_search_agent.ps1) on Windows." -ForegroundColor Yellow
    Write-Host "       To install Python: https://www.python.org/downloads/" -ForegroundColor Yellow
}

# Install Python dependencies if Python is available
if ($pythonAvailable) {
    Write-Host ""
    Write-Host "Installing Python dependencies..." -ForegroundColor Yellow
    pip install -r requirements.txt
    Write-Host "[OK] Python dependencies installed." -ForegroundColor Green
}

# Verify SerpAPI key
Write-Host ""
Write-Host "Verifying SerpAPI key..." -ForegroundColor Yellow
try {
    $key = if ($env:SERPAPI_KEY) { $env:SERPAPI_KEY } else { Read-Host "Enter your SerpAPI key" }
    $response = Invoke-RestMethod -Uri "https://serpapi.com/account?api_key=$key" -TimeoutSec 10
    Write-Host "[OK] SerpAPI key is valid. Plan: $($response.plan_name), Searches remaining: $($response.total_searches_left)" -ForegroundColor Green
} catch {
    Write-Host "[WARNING] SerpAPI key verification failed. Update the key in the script files." -ForegroundColor Red
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To run the job search:"
Write-Host "  Windows (PowerShell): .\job_search_agent.ps1"
Write-Host "  Any OS (Python):      python job_search_agent.py"
Write-Host ""
Write-Host "To schedule daily runs (Windows):"
Write-Host "  Right-click setup_schedule.bat -> Run as Administrator"
Write-Host ""
