#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Dependency checker and installer for YouTube ELT pipeline
.DESCRIPTION
    Verifies required dependencies for the Airflow + Postgres + Redis + Soda setup.
    Prompts individually before installing any missing Python packages.
.AUTHOR
    YouTube ELT Setup
#>

param(
    [switch]$SkipInstall = $false,
    [switch]$Verbose = $false
)

function Write-Success { param([string]$Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Warning { param([string]$Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Error { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Info { param([string]$Message) Write-Host $Message -ForegroundColor Cyan }

Write-Info "=========================================="
Write-Info "YouTube ELT - Dependency Checker"
Write-Info "=========================================="
Write-Info ""

$missingPackages = @()
$allGood = $true

# --------------------------------------------
# 1. CHECK PYTHON
# --------------------------------------------
Write-Info "[1/10] Checking Python..."
$PythonCmd = $null
if (Get-Command python -ErrorAction SilentlyContinue) {
    $PythonCmd = "python"
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
    $PythonCmd = "py"
}

if ($PythonCmd) {
    $pythonVersion = & $PythonCmd --version 2>&1
    Write-Success "Python installed: $pythonVersion"
} else {
    Write-Error "Python NOT found. Install Python 3.9+ first."
    $allGood = $false
}

# --------------------------------------------
# 2. CHECK DOCKER
# --------------------------------------------
Write-Info "[2/10] Checking Docker..."
$DockerCmd = $null
if (Get-Command docker -ErrorAction SilentlyContinue) {
    $DockerCmd = "docker"
} elseif (Get-Command docker.exe -ErrorAction SilentlyContinue) {
    $DockerCmd = "docker.exe"
}

if ($DockerCmd) {
    $dockerVersion = & $DockerCmd --version 2>&1
    Write-Success "Docker installed: $dockerVersion"
} else {
    Write-Warning "Docker is not available in this shell. If Docker Desktop is already installed locally, start it and retry."
}

# --------------------------------------------
# 3. CHECK DOCKER COMPOSE
# --------------------------------------------
Write-Info "[3/10] Checking Docker Compose..."
$ComposeCmd = $null
if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
    $ComposeCmd = "docker-compose"
} elseif (Get-Command docker-compose.exe -ErrorAction SilentlyContinue) {
    $ComposeCmd = "docker-compose.exe"
}

if ($ComposeCmd) {
    $composeVersion = & $ComposeCmd --version 2>&1
    Write-Success "Docker Compose installed: $composeVersion"
} else {
    Write-Warning "Docker Compose is not available in this shell. If Docker Desktop is running locally, retry after it starts."
}

# --------------------------------------------
# 4. CHECK PIP
# --------------------------------------------
Write-Info "[4/10] Checking pip..."
if ($PythonCmd) {
    try {
        $pipVersion = & $PythonCmd -m pip --version 2>&1
        Write-Success "pip installed: $pipVersion"
    } catch {
        Write-Error "pip NOT found"
        $allGood = $false
    }
} else {
    Write-Error "pip NOT found"
    $allGood = $false
}

# --------------------------------------------
# 5-19. CHECK PYTHON PACKAGES
# --------------------------------------------
$requiredPackages = @(
    "apache-airflow",
    "apache-airflow-providers-postgres",
    "apache-airflow-providers-celery",
    "psycopg2-binary",
    "python-dotenv",
    "requests",
    "soda-core",
    "soda-postgres",
    "pytest",
    "dbt-postgres"
)

$counter = 5
$installedCount = 0

foreach ($pkg in $requiredPackages) {
    Write-Info "[$counter/19] Checking $pkg..."

    if ($PythonCmd) {
        $result = & $PythonCmd -m pip show $pkg 2>&1
        if ($LASTEXITCODE -eq 0 -and ($result -match "Name:")) {
            $versionLine = ($result | Select-String "Version:")
            $version = $versionLine.Line.Split(":", 2)[1].Trim()
            Write-Success "$pkg (v$version)"
            $installedCount++
        } else {
            Write-Warning "$pkg (missing)"
            $missingPackages += $pkg
            $allGood = $false
        }
    } else {
        Write-Warning "$pkg (missing)"
        $missingPackages += $pkg
        $allGood = $false
    }

    $counter++
}

# --------------------------------------------
# 15. CHECK DOCKER IMAGES
# --------------------------------------------
Write-Info "[15/19] Checking Docker images..."
$requiredImages = @(
    "apache/airflow:2.9.2",
    "postgres:13",
    "redis:7.2-bookworm"
)

foreach ($img in $requiredImages) {
    if ($DockerCmd) {
        $exists = & $DockerCmd images --format "{{.Repository}}:{{.Tag}}" 2>$null | Select-String -Pattern ([regex]::Escape($img))
        if ($exists) {
            Write-Success "Docker image: $img"
        } else {
            Write-Warning "Docker image: $img (will be pulled on docker-compose up)"
        }
    } else {
        Write-Warning "Docker image: $img (will be pulled on docker-compose up)"
    }
}

# --------------------------------------------
# SUMMARY
# --------------------------------------------
Write-Info ""
Write-Info "=========================================="
Write-Info "SUMMARY"
Write-Info "=========================================="

if ($allGood) {
    Write-Success "All dependencies are installed!"
} else {
    Write-Warning "Some dependencies are missing:"
    Write-Info ""
    if ($missingPackages.Count -gt 0) {
        Write-Info "Missing Python packages ($($missingPackages.Count)):" 
        foreach ($pkg in $missingPackages) {
            Write-Host "  - $pkg" -ForegroundColor Yellow
        }
    }
}

Write-Info ""
Write-Info "Installed packages: $installedCount"
Write-Info "Missing packages: $($missingPackages.Count)"
Write-Info ""

# --------------------------------------------
# INSTALL MISSING PACKAGES ONE BY ONE
# --------------------------------------------
if (($missingPackages.Count -gt 0) -and (-not $SkipInstall)) {
    Write-Warning "Install each missing package individually?"

    foreach ($pkg in $missingPackages) {
        Write-Warning "Install dependency '$pkg'? (Y/n)"
        $response = Read-Host

        if (($response -match '^[Nn]$')) {
            Write-Info "Skipped dependency '$pkg'."
            continue
        }

        Write-Info "Installing dependency '$pkg'..."
        if ($PythonCmd) {
            & $PythonCmd -m pip install $pkg
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Dependency '$pkg' installed successfully."
            } else {
                Write-Error "Failed to install dependency '$pkg'."
            }
        } else {
            Write-Error "Cannot install dependency '$pkg' because Python is unavailable."
        }
    }
} else {
    Write-Info "Skipped installation."
}

# --------------------------------------------
# NEXT STEPS
# --------------------------------------------
Write-Info ""
Write-Info "=========================================="
Write-Info "NEXT STEPS"
Write-Info "=========================================="
Write-Info ""
Write-Info "1. Navigate to project:"
Write-Info '   Set-Location "c:\Users\rajas\DE learning\Youtube ELT"'
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

if (($allGood -and ($missingPackages.Count -eq 0))) {
    Write-Success "Setup complete! Ready to run docker-compose up -d"
    exit 0
} else {
    Write-Warning "Please resolve missing dependencies before proceeding"
    exit 1
}
