#!/bin/bash
#
# Dependency checker and installer for YouTube ELT pipeline
# Usage: bash check_dependencies.sh [--skip-install] [--verbose]
#

# Don't exit on errors - just report them
set +e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Flags
SKIP_INSTALL=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-install)
      SKIP_INSTALL=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Functions
log_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

log_warning() {
  echo -e "${YELLOW}✗ $1${NC}"
}

log_error() {
  echo -e "${RED}✗ $1${NC}"
}

log_info() {
  echo -e "${CYAN}$1${NC}"
}

missing_packages=()
all_good=true

echo ""
log_info "=========================================="
log_info "YouTube ELT - Dependency Checker"
log_info "=========================================="
echo ""

# ============================================
# 1. CHECK PYTHON
# ============================================
log_info "[1/10] Checking Python..."
PYTHON_CMD=""
if command -v python3 &> /dev/null; then
  PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
  PYTHON_CMD="python"
fi

if [ -n "$PYTHON_CMD" ]; then
  python_version=$($PYTHON_CMD --version 2>&1)
  log_success "Python installed: $python_version"
else
  log_error "Python NOT found - Install Python 3.9+"
  all_good=false
fi

# ============================================
# 2. CHECK DOCKER
# ============================================
log_info "[2/10] Checking Docker..."
DOCKER_CMD=""
if command -v docker &> /dev/null; then
  DOCKER_CMD="docker"
elif command -v docker.exe &> /dev/null; then
  DOCKER_CMD="docker.exe"
fi

if [ -n "$DOCKER_CMD" ]; then
  docker_version=$($DOCKER_CMD --version 2>&1)
  log_success "Docker installed: $docker_version"
else
  log_warning "Docker Desktop is installed locally but not exposed in this WSL session. If Docker is already running on Windows, use docker.exe or start Docker Desktop and retry."
  log_info "Continuing without Docker checks for now."
fi

# ============================================
# 3. CHECK DOCKER COMPOSE
# ============================================
log_info "[3/10] Checking Docker Compose..."
if command -v docker-compose &> /dev/null; then
  compose_version=$(docker-compose --version 2>&1)
  log_success "Docker Compose installed: $compose_version"
elif command -v docker-compose.exe &> /dev/null; then
  compose_version=$(docker-compose.exe --version 2>&1)
  log_success "Docker Compose installed: $compose_version"
else
  log_warning "Docker Compose is not available in this WSL session. If Docker Desktop is running locally, start it and retry."
  log_info "Continuing without Docker Compose checks for now."
fi

# ============================================
# 4. CHECK PIP
# ============================================
log_info "[4/10] Checking pip..."
if [ -n "$PYTHON_CMD" ] && $PYTHON_CMD -m pip --version &> /dev/null; then
  pip_version=$($PYTHON_CMD -m pip --version 2>&1)
  log_success "pip installed: $pip_version"
else
  log_error "pip NOT found"
  all_good=false
fi

# ============================================
# 5-19. CHECK PIP PACKAGES
# ============================================

declare -A required_packages=(
  ["apache-airflow"]="2.9.2"
  ["apache-airflow-providers-postgres"]="latest"
  ["apache-airflow-providers-celery"]="latest"
  ["psycopg2-binary"]="latest"
  ["python-dotenv"]="latest"
  ["requests"]="latest"
  ["soda-core"]="latest"
  ["soda-postgres"]="latest"
  ["pytest"]="latest"
  ["dbt-postgres"]="latest"
)

counter=5
installed_count=0
not_installed_count=0

for pkg in "${!required_packages[@]}"; do
  log_info "[$counter/19] Checking $pkg..."
  
  if [ -n "$PYTHON_CMD" ] && $PYTHON_CMD -m pip show "$pkg" &> /dev/null; then
    version=$($PYTHON_CMD -m pip show "$pkg" | grep "Version:" | awk '{print $2}')
    log_success "$pkg (v$version)"
    ((installed_count++))
  else
    log_warning "$pkg (missing)"
    missing_packages+=("$pkg")
    all_good=false
    ((not_installed_count++))
  fi
  ((counter++))
done

# ============================================
# 15. CHECK DOCKER IMAGES
# ============================================
log_info "[15/19] Checking Docker images..."
required_images=(
  "apache/airflow:2.9.2"
  "postgres:13"
  "redis:7.2-bookworm"
)

for img in "${required_images[@]}"; do
  if [ -n "$DOCKER_CMD" ] && $DOCKER_CMD images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${img}$"; then
    log_success "Docker image: $img"
  else
    log_warning "Docker image: $img (will be pulled on docker-compose up)"
  fi
done

# ============================================
# SUMMARY
# ============================================
echo ""
log_info "=========================================="
log_info "SUMMARY"
log_info "=========================================="

if [ "$all_good" = true ] && [ ${#missing_packages[@]} -eq 0 ]; then
  log_success "All dependencies are installed!"
else
  log_warning "Some dependencies are missing:"
  echo ""
  
  if [ ${#missing_packages[@]} -gt 0 ]; then
    log_info "Missing Python packages (${#missing_packages[@]}):"
    for pkg in "${missing_packages[@]}"; do
      echo -e "  ${YELLOW}- $pkg${NC}"
    done
  fi
fi

echo ""
log_info "Installed packages: $installed_count"
log_info "Missing packages: $not_installed_count"
echo ""

# ============================================
# INSTALLATION PROMPT
# ============================================
if [ ${#missing_packages[@]} -gt 0 ] && [ "$SKIP_INSTALL" = false ]; then
  echo ""
  log_warning "Install each missing package individually?"
  for pkg in "${missing_packages[@]}"; do
    echo ""
    log_warning "Install dependency '$pkg'? (Y/n)"
    read -r response

    if [[ "$response" =~ ^[Nn]$ ]]; then
      log_info "Skipped dependency '$pkg'."
      continue
    fi

    log_info "Installing dependency '$pkg'..."
    if [ -n "$PYTHON_CMD" ] && $PYTHON_CMD -m pip install "$pkg"; then
      log_success "Dependency '$pkg' installed successfully."
    else
      log_error "Failed to install dependency '$pkg'."
    fi
  done
else
  log_info "Skipped installation."
fi

# ============================================
# NEXT STEPS
# ============================================
echo ""
log_info "=========================================="
log_info "NEXT STEPS"
log_info "=========================================="
echo ""
log_info "1. Navigate to project:"
log_info "   cd /path/to/Youtube\\ ELT"
echo ""
log_info "2. Start Docker services:"
log_info "   docker-compose up -d"
echo ""
log_info "3. Wait 30 seconds, then check:"
log_info "   docker-compose ps"
echo ""
log_info "4. Access Airflow UI:"
log_info "   http://localhost:8080"
log_info "   User: airflow"
log_info "   Pass: airflow123"
echo ""
log_info "5. Verify all 3 DAGs appear:"
log_info "   - produce_json"
log_info "   - update_db"
log_info "   - data_quality"
echo ""

if [ "$all_good" = true ] && [ ${#missing_packages[@]} -eq 0 ]; then
  log_success "Setup complete! Ready to run docker-compose up -d"
  exit 0
else
  log_warning "Please resolve missing dependencies before proceeding"
  exit 1
fi
