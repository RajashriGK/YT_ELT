#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Dependency checker and installer for YouTube ELT pipeline
.DESCRIPTION
    Verifies all required dependencies for Airflow + PostgreSQL + Redis + Soda setup
    If any are missing, installs them automatically
.AUTHOR
    YouTube ELT Setup
#>

param(
    [switch]$SkipInstall = $false,
    [switch]$Verbose = $false
)

# Color output
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }
function Write-Error { Write-Host $args -ForegroundColor Red }
function Write-Info { Write-Host $args -ForegroundColor Cyan }

Write-Info "=========================================="
Write-Info "YouTube ELT - Dependency Checker"
Write-Info "=========================================="
Write-Info ""

$missingPackages = @()
$missingBinaries = @()
$allGood = $true

# ============================================
# 1. CHECK PYTHON
# ============================================
Write-Info "[1/10] Checking Python..."
try {
    $pythonVersion = python --version 2>&1
    Write-Success "✓ Python installed: $pythonVersion"
} catch {
    Write-Error "✗ Python NOT found"
    $allGood = $false
}

# ============================================
# 2. CHECK DOCKER
# ============================================
Write-Info "[2/10] Checking Docker..."
try {
    $dockerVersion = docker --version 2>&1
    Write-Success "✓ Docker installed: $dockerVersion"
} catch {
    Write-Error "✗ Docker NOT found - Please install from https://www.docker.com/products/docker-desktop"
    $allGood = $false
}

# ============================================
# 3. CHECK DOCKER COMPOSE
# ============================================
Write-Info "[3/10] Checking Docker Compose..."
try {
    $composeVersion = docker-compose --version 2>&1
    Write-Success "✓ Docker Compose installed: $composeVersion"
} catch {
    Write-Error "✗ Docker Compose NOT found"
    $allGood = $false
}

# ============================================
# 4. CHECK PIP
# ============================================
Write-Info "[4/10] Checking pip..."
try {
    $pipVersion = pip --version 2>&1
    Write-Success "✓ pip installed: $pipVersion"
} catch {
    Write-Error "✗ pip NOT found"
    $allGood = $false
    exit 1
}

# ============================================
# 5-14. CHECK PIP PACKAGES
# ============================================

$requiredPackages = @{
    "apache-airflow"                          = "2.9.2"
    "apache-airflow-providers-postgres"       = "latest"
    "apache-airflow-providers-celery"         = "latest"
    "redis"                                   = "latest"
    "psycopg2-binary"                         = "latest"
    "python-dotenv"                           = "latest"
    "google-api-python-client"                = "latest"
    "google-auth-oauthlib"                    = "latest"
    "google-auth-httplib2"                    = "latest"
    "soda-core"                               = "latest"
    "soda-postgres"                           = "latest"
    "pytest"                                  = "latest"
    "requests"                                = "latest"
    "dbt-postgres"                            = "latest (optional)"
}

$counter = 5
$installed = @()
$notInstalled = @()

foreach ($pkg in $requiredPackages.Keys) {
    Write-Info "[$counter/19] Checking $pkg..."
    
    $result = pip show $pkg 2>&1
    
    if ($result -match "Name:") {
        $version = ($result | Select-String "Version:").ToString().Split(":")[1].Trim()
        Write-Success "✓ $pkg (v$version)"
        $installed += $pkg
    } else {
        Write-Warning "✗ $pkg (missing)"
        $notInstalled += $pkg
        $missingPackages += $pkg
        $allGood = $false
    }
    $counter++
}

# ============================================
# 15. CHECK DOCKER IMAGES
# ============================================
Write-Info "[15/19] Checking Docker images..."
$requiredImages = @(
    "apache/airflow:2.9.2"
    "postgres:13"
    "redis:7.2-bookworm"
)

foreach ($img in $requiredImages) {
    $exists = docker images --format "{{.Repository}}:{{.Tag}}" | Select-String -Pattern ([regex]::Escape($img))
    if ($exists) {
        Write-Success "✓ Docker image: $img"
    } else {
        Write-Warning "⚠ Docker image: $img (will be pulled on docker-compose up)"
    }
}

# ============================================
# SUMMARY
# ============================================
Write-Info ""
Write-Info "=========================================="
Write-Info "SUMMARY"
Write-Info "=========================================="

if ($allGood) {
    Write-Success "✓ All dependencies are installed!"
} else {
    Write-Warning "⚠ Some dependencies are missing:"
    Write-Info ""
    
    if ($missingPackages.Count -gt 0) {
        Write-Info "Missing Python packages ($($missingPackages.Count)):"
        $missingPackages | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    }
    
    if ($missingBinaries.Count -gt 0) {
        Write-Error "Missing system binaries ($($missingBinaries.Count)):"
        $missingBinaries | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    }
}

Write-Info ""
Write-Info "Installed packages: $($installed.Count)"
Write-Info "Missing packages: $($missingPackages.Count)"
Write-Info ""

# ============================================
# INSTALLATION PROMPT
# ============================================
if ($missingPackages.Count -gt 0 -and -not $SkipInstall) {
    Write-Warning ""
    Write-Warning "Do you want to install missing packages? (Y/n)"
    $response = Read-Host
    
    if ($response -ne "n" -and $response -ne "N") {
        Write-Info ""
        Write-Info "Installing missing packages..."
        Write-Info ""
        
        $installCmd = "pip install " + ($missingPackages -join " ")
        
        if ($Verbose) {
            Write-Info "Command: $installCmd"
        }
        
        Invoke-Expression $installCmd
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ All packages installed successfully!"
        } else {
            Write-Error "✗ Installation failed. Please check the errors above."
            exit 1
        }
    } else {
        Write-Info "Skipped installation."
    }
}

# ============================================
# NEXT STEPS
# ============================================
Write-Info ""
Write-Info "=========================================="
Write-Info "NEXT STEPS"
Write-Info "=========================================="
Write-Info ""
Write-Info "1. Navigate to project:"
Write-Info "   Set-Location `"c:\Users\rajas\DE learning\Youtube ELT`""
Write-Info ""
Write-Info "2. Start Docker services:"
Write-Info "   docker-compose up -d"
Write-Info ""
Write-Info "3. Wait 30 seconds, then check:"
Write-Info "   docker-compose ps"
Write-Info ""
Write-Info "4. Access Airflow UI:"
Write-Info "   http://localhost:8080"
Write-Info "   User: airflow"
Write-Info "   Pass: airflow123"
Write-Info ""
Write-Info "5. Verify all 3 DAGs appear:"
Write-Info "   - produce_json"
Write-Info "   - update_db"
Write-Info "   - data_quality"
Write-Info ""

if ($allGood -and $missingPackages.Count -eq 0) {
    Write-Success "✓ Setup complete! Ready to run docker-compose up -d"
    exit 0
} else {
    Write-Warning "⚠ Please resolve missing dependencies before proceeding"
    exit 1
}
