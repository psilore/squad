#!/bin/bash

set -e

# Setup colors for logging
FMT_RED=$(printf '\033[31m')
FMT_GREEN=$(printf '\033[32m')
FMT_RESET=$(printf '\033[0m')
FMT_BOLD=$(printf '\033[1m')

log_info() {
  printf "%s[INFO]%s %s\n" "${FMT_BOLD}" "${FMT_RESET}" "$*"
}

log_error() {
  printf '%s[ERROR]%s %s\n' "${FMT_RED}${FMT_BOLD}" "${FMT_RESET}" "$*" >&2
}

log_success() {
  printf '%s[SUCCESS]%s %s\n' "${FMT_GREEN}${FMT_BOLD}" "${FMT_RESET}" "$*"
}

# Get inputs from environment variables (set by GitHub Actions)
OWNER="${INPUT_OWNER}"
TEAM_SLUG="${INPUT_TEAM_SLUG}"
# GITHUB_TOKEN is already set by GitHub Actions
SINCE_DATE="${INPUT_SINCE_DATE}"
UNTIL_DATE="${INPUT_UNTIL_DATE}"
REPORT_PATH="${INPUT_REPORT_PATH:-./report}"
INCLUDE_ALERTS="${INPUT_ALERTS:-true}"
INCLUDE_USERS="${INPUT_USERS:-true}"
INCLUDE_PRS="${INPUT_PRS:-true}"

# Validate required inputs
if [ -z "$OWNER" ]; then
  log_error "Input 'owner' is required"
  exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
  log_error "Input 'github-token' is required"
  exit 1
fi

# Configure GitHub CLI
export GH_TOKEN="$GITHUB_TOKEN"
log_info "Configured GitHub CLI with provided token"

# Set date defaults if not provided
if [ -z "$SINCE_DATE" ]; then
  SINCE_DATE=$(date -d "$(date +%Y-%m-01) -1 month" +%Y-%m-%d)
  log_info "Using default since-date: $SINCE_DATE"
fi

if [ -z "$UNTIL_DATE" ]; then
  UNTIL_DATE=$(date +%Y-%m-%d)
  log_info "Using default until-date: $UNTIL_DATE"
fi

# Export variables for squad.sh
export OWNER
export TEAM_SLUG
export SINCE_DATE
export UNTIL_DATE
export INCLUDE_ALERTS
export INCLUDE_USERS
export INCLUDE_PRS

# Determine workspace directory (GitHub Actions vs local)
WORKSPACE_DIR="${GITHUB_WORKSPACE:-/github/workspace}"

# For local testing, use current directory if /github/workspace doesn't exist
if [ ! -d "$WORKSPACE_DIR" ]; then
  WORKSPACE_DIR="/workspace"
  log_info "Using local workspace directory: $WORKSPACE_DIR"
fi

# Change to workspace directory
cd "$WORKSPACE_DIR" || {
  log_error "Failed to change to workspace directory: $WORKSPACE_DIR"
  exit 1
}

# Convert REPORT_PATH to absolute path relative to workspace
if [[ "$REPORT_PATH" != /* ]]; then
  REPORT_PATH="$WORKSPACE_DIR/$REPORT_PATH"
fi

export REPORT_PATH

# Create report directory
mkdir -p "$REPORT_PATH"

# Initialize git repository if not exists (needed by squad.sh)
if [ ! -d .git ]; then
  log_info "Initializing git repository"
  git init -q -b main
  git config user.email "action@github.com"
  git config user.name "GitHub Action"
fi

log_info "Starting squad report generation..."
log_info "Owner: $OWNER"
if [ -n "$TEAM_SLUG" ]; then
  log_info "Team: $TEAM_SLUG"
fi
log_info "Date Range: $SINCE_DATE to $UNTIL_DATE"

# Run squad.sh with appropriate parameters
SQUAD_ARGS="-o $OWNER"
if [ -n "$TEAM_SLUG" ]; then
  SQUAD_ARGS="$SQUAD_ARGS -t $TEAM_SLUG"
fi

# Execute squad.sh
# shellcheck disable=SC2086
if /usr/local/bin/squad.sh $SQUAD_ARGS; then
  log_success "Squad report generated successfully"
else
  log_error "Failed to generate squad report"
  exit 1
fi

# Set outputs for GitHub Actions
REPORT_SUMMARY="$REPORT_PATH/report_summary.md"

if [ -f "$REPORT_PATH/alerts.json" ]; then
  TOTAL_ALERTS=$(jq 'length' "$REPORT_PATH/alerts.json")
else
  TOTAL_ALERTS=0
fi

if [ -f "$REPORT_PATH/critical.json" ]; then
  CRITICAL_ALERTS=$(jq 'length' "$REPORT_PATH/critical.json")
else
  CRITICAL_ALERTS=0
fi

if [ -f "$REPORT_PATH/repos.json" ]; then
  TOTAL_REPOS=$(jq 'length' "$REPORT_PATH/repos.json")
else
  TOTAL_REPOS=0
fi

if [ -f "$REPORT_PATH/users.json" ]; then
  TOTAL_USERS=$(jq 'length' "$REPORT_PATH/users.json")
else
  TOTAL_USERS=0
fi

# Output to GitHub Actions (if running in GitHub Actions)
if [ -n "$GITHUB_OUTPUT" ]; then
  {
    echo "report-path=$REPORT_PATH"
    echo "total-alerts=$TOTAL_ALERTS"
    echo "critical-alerts=$CRITICAL_ALERTS"
    echo "total-repos=$TOTAL_REPOS"
    echo "total-users=$TOTAL_USERS"
  } >> "$GITHUB_OUTPUT"
  log_info "Outputs written to GITHUB_OUTPUT"
fi

log_success "Report statistics:"
log_info "  Total Alerts: $TOTAL_ALERTS"
log_info "  Critical Alerts: $CRITICAL_ALERTS"
log_info "  Total Repos: $TOTAL_REPOS"
log_info "  Total Users: $TOTAL_USERS"

# Display report summary if exists
if [ -f "$REPORT_SUMMARY" ]; then
  log_info "Report summary:"
  echo ""
  cat "$REPORT_SUMMARY"
fi

log_success "Action completed successfully"
