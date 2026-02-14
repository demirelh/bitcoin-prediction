#!/usr/bin/env bash
# =============================================================================
# Production Deployment Script for BTC-IBIT Prediction Dashboard
#
# Purpose:
#   1. Pull latest version from Git repository
#   2. Install/update Python dependencies
#   3. Restart the systemd service (btc-predict)
#
# This script is safe to run multiple times (idempotent) and designed for
# production use on Ubuntu/Debian-like systems.
#
# Usage:
#   chmod +x run.sh
#   ./run.sh
#
# Note: This script should be run as the 'pi' user (or the user that owns
# the project directory), NOT as root. It will use sudo for systemctl only.
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

# Project directory (auto-detect based on script location)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${PROJECT_DIR}/.venv"
REQUIREMENTS_FILE="${PROJECT_DIR}/requirements.txt"
SERVICE_NAME="btc-predict"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Logging Functions
# -----------------------------------------------------------------------------

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# -----------------------------------------------------------------------------
# Pre-flight Checks
# -----------------------------------------------------------------------------

log_info "Starting deployment script..."
log_info "Project directory: ${PROJECT_DIR}"

# Check if we're in a Git repository
if [ ! -d "${PROJECT_DIR}/.git" ]; then
    log_error "Not a Git repository: ${PROJECT_DIR}"
    exit 1
fi

# Check if requirements.txt exists
if [ ! -f "${REQUIREMENTS_FILE}" ]; then
    log_error "requirements.txt not found: ${REQUIREMENTS_FILE}"
    exit 1
fi

# Check if running as root (we shouldn't be)
if [ "$EUID" -eq 0 ]; then
    log_error "This script should NOT be run as root."
    log_error "Run as the user that owns the project (e.g., 'pi')."
    exit 1
fi

# -----------------------------------------------------------------------------
# Step 1: Git Pull
# -----------------------------------------------------------------------------

log_info "Step 1/3: Pulling latest changes from Git..."

# Store current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
log_info "Current branch: ${CURRENT_BRANCH}"

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    log_warning "Uncommitted changes detected. Stashing them..."
    git stash push -m "Auto-stash by run.sh at $(date +%Y-%m-%d_%H:%M:%S)"
    STASHED=true
else
    STASHED=false
fi

# Fetch latest changes
if ! git fetch origin; then
    log_error "Failed to fetch from remote repository"
    exit 1
fi

# Check if branch exists on remote
if git rev-parse --verify "origin/${CURRENT_BRANCH}" >/dev/null 2>&1; then
    # Pull changes
    if ! git pull origin "${CURRENT_BRANCH}"; then
        log_error "Failed to pull changes from origin/${CURRENT_BRANCH}"

        # Try to restore stashed changes if we stashed anything
        if [ "$STASHED" = true ]; then
            log_info "Restoring stashed changes..."
            git stash pop
        fi
        exit 1
    fi

    log_success "Successfully pulled latest changes"
else
    log_warning "Branch ${CURRENT_BRANCH} does not exist on remote. Skipping pull."
fi

# Restore stashed changes if we stashed anything
if [ "$STASHED" = true ]; then
    log_info "Restoring stashed changes..."
    if ! git stash pop; then
        log_warning "Could not automatically restore stashed changes. Please resolve manually."
        log_warning "Run: git stash list"
    fi
fi

# -----------------------------------------------------------------------------
# Step 2: Install/Update Dependencies
# -----------------------------------------------------------------------------

log_info "Step 2/3: Installing/updating Python dependencies..."

# Check if virtual environment exists
if [ ! -d "${VENV_DIR}" ]; then
    log_warning "Virtual environment not found. Creating one..."
    python3 -m venv "${VENV_DIR}"
    log_success "Virtual environment created: ${VENV_DIR}"
fi

# Activate virtual environment and install dependencies
log_info "Installing dependencies from ${REQUIREMENTS_FILE}..."

# Use the virtual environment's pip directly
if ! "${VENV_DIR}/bin/pip" install --quiet --upgrade pip; then
    log_error "Failed to upgrade pip"
    exit 1
fi

if ! "${VENV_DIR}/bin/pip" install --quiet -r "${REQUIREMENTS_FILE}"; then
    log_error "Failed to install dependencies"
    exit 1
fi

log_success "Dependencies installed/updated successfully"

# -----------------------------------------------------------------------------
# Step 3: Restart Service
# -----------------------------------------------------------------------------

log_info "Step 3/3: Restarting ${SERVICE_NAME} service..."

# Check if systemd service exists
if ! systemctl list-unit-files "${SERVICE_NAME}.service" >/dev/null 2>&1; then
    log_warning "Service ${SERVICE_NAME}.service not found in systemd"
    log_warning "Skipping service restart. You may need to run deploy/setup.sh first."
else
    # Restart the service
    if ! sudo systemctl restart "${SERVICE_NAME}.service"; then
        log_error "Failed to restart ${SERVICE_NAME}.service"
        log_error "Check logs with: journalctl -u ${SERVICE_NAME} -f"
        exit 1
    fi

    log_success "Service ${SERVICE_NAME} restarted successfully"

    # Wait a moment and check if service is running
    sleep 2

    if systemctl is-active --quiet "${SERVICE_NAME}.service"; then
        log_success "Service ${SERVICE_NAME} is running"
    else
        log_error "Service ${SERVICE_NAME} is not running. Check status:"
        sudo systemctl status "${SERVICE_NAME}.service" --no-pager || true
        exit 1
    fi
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

log_success "Deployment completed successfully!"
log_info ""
log_info "Summary:"
log_info "  ✓ Git repository updated to latest version"
log_info "  ✓ Python dependencies installed/updated"
log_info "  ✓ Service restarted"
log_info ""
log_info "Useful commands:"
log_info "  • Check service status:  sudo systemctl status ${SERVICE_NAME}"
log_info "  • View service logs:     journalctl -u ${SERVICE_NAME} -f"
log_info "  • Restart service:       sudo systemctl restart ${SERVICE_NAME}"
log_info ""
