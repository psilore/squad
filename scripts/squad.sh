#!/usr/bin/env bash

# Create a report for all repositories in an organization or team

set -euo pipefail

# Accept OWNER from environment or command line
OWNER="${OWNER:-}"

command_exists() {
  command -v "$@" >/dev/null 2>&1
}

format_error() {
  local date
  date="$(date +"%b %d %H:%M:%S")"
  printf "%s$date %s%s\n" "${FMT_RED}" "$*" "$FMT_RESET" >&2
}

format_log() {
  local date
  date="$(date +"%b %d %H:%M:%S")"
  printf "%s$date %s%s\n" "${FMT_BOLD}" "$*" "$FMT_RESET" >&2
}

setup_colors(){
FMT_RED=$(printf '\033[31m')
FMT_RESET=$(printf '\033[0m')
FMT_BOLD=$(printf '\033[1m')
}

get_repo_names() {
  local URL
  local ACTIVE_REPOS
  local REPO_NAMES

  # Try team repos first if team slug provided
  if [ -n "$TEAM_SLUG" ]; then
    URL="orgs/$OWNER/teams/$TEAM_SLUG/repos"
    format_log "[INFO] Fetching repositories for team: $TEAM_SLUG"
    if ACTIVE_REPOS=$(gh api "$URL" 2>&1); then
      format_log "[INFO] Successfully fetched team repositories"
    else
      format_error "[ERROR] Failed to fetch team repositories"
      echo "$ACTIVE_REPOS" >&2
      exit 1
    fi
  else
    # Try organization repos first
    URL="orgs/$OWNER/repos?per_page=100"
    format_log "[INFO] Fetching repositories for organization: $OWNER"
    if ACTIVE_REPOS=$(gh api "$URL" 2>&1); then
      format_log "[INFO] Successfully fetched organization repositories"
    else
      # If org fails, try user repos
      format_log "[INFO] Organization API failed, trying user account..."
      URL="users/$OWNER/repos?per_page=100"
      if ACTIVE_REPOS=$(gh api "$URL" 2>&1); then
        format_log "[INFO] Successfully fetched user repositories"
      else
        format_error "[ERROR] Failed to fetch repositories from both org and user APIs"
        echo "$ACTIVE_REPOS" >&2
        exit 1
      fi
    fi
  fi

  # Validate JSON response
  if ! echo "$ACTIVE_REPOS" | jq empty 2>/dev/null; then
    format_error "[ERROR] Invalid JSON response from GitHub API:"
    echo "$ACTIVE_REPOS" >&2
    exit 1
  fi

  if ! REPO_NAMES=$(echo "$ACTIVE_REPOS" | jq -r '.[].name' 2>&1); then
    format_error "[ERROR] Failed to parse repository names:"
    echo "$REPO_NAMES" >&2
    exit 1
  fi
  
  touch "$REPO_LIST"
  echo "$REPO_NAMES" > "$REPO_LIST"
  
  local REPO_COUNT
  REPO_COUNT=$(echo "$REPO_NAMES" | grep -c '^')
  format_log "[INFO] Found $REPO_COUNT repositories"
}

get_repo_data(){
  local REPO_URI

  if [ -n "$TEAM_SLUG" ]; then
    REPO_URI="/orgs/$OWNER/teams/$TEAM_SLUG/repos"
    if RESPONSE=$(gh api "$REPO_URI" --jq "[.[] | {name: .name, html_url: .html_url, visibility: (if .private == false then \"PUBLIC\" else \"PRIVATE\" end)}]" 2>&1); then
      format_log "[INFO] Successfully fetched team repository data"
    else
      format_error "[ERROR] Failed to fetch team repository data"
      echo "$RESPONSE" >&2
      exit 1
    fi
  else
    # Try org first
    REPO_URI="/orgs/$OWNER/repos?per_page=100"
    if RESPONSE=$(gh api "$REPO_URI" --jq "[.[] | {name: .name, html_url: .html_url, visibility: (if .private == false then \"PUBLIC\" else \"PRIVATE\" end)}]" 2>&1); then
      format_log "[INFO] Successfully fetched organization repository data"
    else
      # Try user repos if org failed
      format_log "[INFO] Organization repos failed, trying user repos..."
      REPO_URI="/users/$OWNER/repos?per_page=100"
      if RESPONSE=$(gh api "$REPO_URI" --jq "[.[] | {name: .name, html_url: .html_url, visibility: (if .private == false then \"PUBLIC\" else \"PRIVATE\" end)}]" 2>&1); then
        format_log "[INFO] Successfully fetched user repository data"
      else
        format_error "[ERROR] Failed to fetch repository data from both org and user APIs"
        echo "$RESPONSE" >&2
        exit 1
      fi
    fi
  fi

  # Validate JSON
  if ! echo "$RESPONSE" | jq empty 2>/dev/null; then
    format_error "[ERROR] Invalid JSON response:"
    echo "$RESPONSE" >&2
    exit 1
  fi

  echo "$RESPONSE" > "$REPO_DATA"
  format_log "[INFO] Repository data created: $REPO_DATA"

  if jq -e '.[] | select(.visibility == "PUBLIC")' "$REPO_DATA" > /dev/null 2>&1; then
    local PUBLIC_COUNT
    PUBLIC_COUNT=$(jq '[.[] | select(.visibility == "PUBLIC")] | length' "$REPO_DATA")
    format_log "[WARNING] Found $PUBLIC_COUNT public repositories!"
    echo "$RESPONSE" | jq '[.[] | select(.visibility == "PUBLIC")]' > "$SCRIPT_DIR/public_repos.json"
  fi
}
get_alerts() {
  # Skip if alerts disabled
  if [ "${INCLUDE_ALERTS:-true}" != "true" ]; then
    format_log "[INFO] Skipping alerts scan (disabled)"
    return 0
  fi

  # Check if repo list exists
  if [ ! -f "$REPO_LIST" ]; then
    format_log "[WARNING] No repository list found, skipping alerts"
    return 0
  fi

  mapfile -t REPOS < "$REPO_LIST"
  touch "$ALERTS_DATA"
  echo "[]" > "$ALERTS_DATA"
  local CRITICAL_DATA="$SCRIPT_DIR/critical.json"
  echo "[]" > "$CRITICAL_DATA"

  for REPO in "${REPOS[@]}"; do
    # Skip empty lines
    [ -z "$REPO" ] && continue
    
    # Check if repo is archived
    local REPO_URL="/repos/$OWNER/$REPO"
    if REPO_DETAILS=$(gh api "$REPO_URL" --jq '{archived: .archived}' 2>&1); then
      IS_ARCHIVED=$(echo "$REPO_DETAILS" | jq -r '.archived')
      if [ "$IS_ARCHIVED" = "true" ]; then
        format_log "[INFO] Skipping repository: $REPO (archived)"
        continue
      fi
    fi

    # Fetch Dependabot alerts
    local URL="/repos/$OWNER/$REPO/dependabot/alerts"
    if ACTIVE_ALERTS=$(gh api "$URL" --jq "[.[] | select(.state == \"open\") | {repository: \"$REPO\", html_url: .html_url, number: .number, state: .state, security_advisory: .security_advisory.summary, severity: .security_advisory.severity, cve: (.security_advisory.identifiers[] | select(.type == \"CVE\") | .value)}]" 2>&1); then
      # Successfully got alerts
      if [ -n "$ACTIVE_ALERTS" ] && [ "$ACTIVE_ALERTS" != "[]" ]; then
        if jq -s '.[0] + .[1]' "$ALERTS_DATA" <(echo "$ACTIVE_ALERTS") > "$SCRIPT_DIR/tmp.json" 2>/dev/null; then
          mv "$SCRIPT_DIR/tmp.json" "$ALERTS_DATA"
          
          # Extract critical alerts
          if CRITICAL=$(echo "$ACTIVE_ALERTS" | jq '[.[] | select(.severity == "critical")]' 2>/dev/null); then
            if [ -n "$CRITICAL" ] && [ "$CRITICAL" != "[]" ]; then
              if jq -s '.[0] + .[1]' "$CRITICAL_DATA" <(echo "$CRITICAL") > "$SCRIPT_DIR/tmp_crit.json" 2>/dev/null; then
                mv "$SCRIPT_DIR/tmp_crit.json" "$CRITICAL_DATA"
              fi
            fi
          fi
        fi
      fi
    else
      # Handle 403 or permission errors gracefully
      if echo "$ACTIVE_ALERTS" | grep -q -E "(403|404|Dependabot alerts are disabled)"; then
        format_log "[INFO] Skipping alerts for $REPO (no access or disabled)"
      else
        format_log "[WARNING] Could not fetch alerts for $REPO"
      fi
      continue
    fi
  done

  if [ -s "$ALERTS_DATA" ] && jq -e 'length > 0' "$ALERTS_DATA" > /dev/null 2>&1; then
    local ALERT_COUNT
    ALERT_COUNT=$(jq 'length' "$ALERTS_DATA")
    format_log "[WARNING] Found $ALERT_COUNT vulnerabilities!"
    format_log "[INFO] Alerts data created: $ALERTS_DATA"
  else
    format_log "[INFO] No vulnerabilities found"
    rm -f "$ALERTS_DATA"
  fi
  
  # Clean up critical if empty
  if [ ! -s "$CRITICAL_DATA" ] || ! jq -e 'length > 0' "$CRITICAL_DATA" > /dev/null 2>&1; then
    rm -f "$CRITICAL_DATA"
  fi
  
  # Clean up temp files
  rm -f "$SCRIPT_DIR/tmp.json" "$SCRIPT_DIR/tmp_crit.json"
}

get_users() {
  # Skip if users disabled
  if [ "${INCLUDE_USERS:-true}" != "true" ]; then
    format_log "[INFO] Skipping user data collection (disabled)"
    return 0
  fi

  local URL

  if [ -n "$TEAM_SLUG" ]; then
    URL="orgs/$OWNER/teams/$TEAM_SLUG/members"
    format_log "[INFO] Fetching team members for: $TEAM_SLUG"
    
    if USERS=$(gh api "$URL" 2>&1); then
      # Save full user data
      if echo "$USERS" | jq '[.[] | {login: .login, id: .id, avatar_url: .avatar_url, html_url: .html_url}]' > "$USERS_DATA" 2>/dev/null; then
        echo "$USERS" | jq -r '.[].login' > "$MEMBERS_LIST"
        format_log "[INFO] User data created: $USERS_DATA"
      else
        format_log "[WARNING] Could not process user data"
        return 0
      fi
    else
      format_error "[ERROR] Failed to fetch team members from GitHub API:"
      echo "$USERS" >&2
      exit 1
    fi
  else
    # For orgs, try to get members
    URL="orgs/$OWNER/members"
    format_log "[INFO] Fetching organization members"
    
    if USERS=$(gh api "$URL" 2>&1); then
      # Successfully got org members
      if echo "$USERS" | jq '[.[] | {login: .login, id: .id, avatar_url: .avatar_url, html_url: .html_url}]' > "$USERS_DATA" 2>/dev/null; then
        echo "$USERS" | jq -r '.[].login' > "$MEMBERS_LIST"
        format_log "[INFO] User data created: $USERS_DATA"
      else
        format_log "[WARNING] Could not process user data"
        return 0
      fi
    else
      # Try as user account instead
      format_log "[INFO] Org members failed, fetching as user account"
      URL="users/$OWNER"
      
      if USER_DATA=$(gh api "$URL" --jq '[{login: .login, id: .id, avatar_url: .avatar_url, html_url: .html_url}]' 2>&1); then
        echo "$USER_DATA" > "$USERS_DATA"
        echo "$USER_DATA" | jq -r '.[].login' > "$MEMBERS_LIST" 2>/dev/null
        format_log "[INFO] User data created: $USERS_DATA"
      else
        format_log "[WARNING] Could not fetch user data, continuing without user info"
        return 0
      fi
    fi
  fi
}

get_pull_requests() {
  # Skip if disabled
  if [ "${INCLUDE_PRS:-true}" != "true" ]; then
    format_log "[INFO] Skipping pull request tracking (disabled)"
    return 0
  fi

  local PRS_DATA="$SCRIPT_DIR/prs.json"
  echo "[]" > "$PRS_DATA"
  
  format_log "[INFO] Fetching open pull requests"
  
  # Read repos from the list
  while IFS= read -r REPO; do
    [ -z "$REPO" ] && continue
    
    local URL="/repos/$OWNER/$REPO/pulls?state=open"
    if PRS=$(gh api "$URL" --jq "[.[] | {repository: \"$REPO\", number: .number, title: .title, html_url: .html_url, user: .user.login, created_at: .created_at, updated_at: .updated_at, draft: .draft}]" 2>&1); then
      if [ -n "$PRS" ] && [ "$PRS" != "[]" ]; then
        if jq -s '.[0] + .[1]' "$PRS_DATA" <(echo "$PRS") > "$SCRIPT_DIR/tmp_prs.json" 2>/dev/null; then
          mv "$SCRIPT_DIR/tmp_prs.json" "$PRS_DATA"
        fi
      fi
    else
      format_log "[INFO] Could not fetch PRs for $REPO"
    fi
  done < "$REPO_LIST"
  
  if [ -s "$PRS_DATA" ] && jq -e 'length > 0' "$PRS_DATA" > /dev/null 2>&1; then
    local TOTAL_PRS
    TOTAL_PRS=$(jq 'length' "$PRS_DATA")
    format_log "[INFO] Found $TOTAL_PRS open pull request(s)"
  else
    format_log "[INFO] No open pull requests found"
  fi
}

render_report() {
  local DATE
  DATE=$(date --iso-8601=seconds)

cat << HEADER > "$SUMMARY_MD"
# 📋 Report

Owner: $OWNER
HEADER

  if [ -n "$TEAM_SLUG" ]; then
    echo "Team: $TEAM_SLUG" >> "$SUMMARY_MD"
  fi

cat << HEADER2 >> "$SUMMARY_MD"
Date: $DATE
Range: ${SINCE_DATE} - ${UNTIL_DATE}


HEADER2

  # Users section
  if [ -f "$USERS_DATA" ]; then
    local TOTAL_USERS
    TOTAL_USERS=$(jq 'length' "$USERS_DATA")
    {
      echo "## Users"
      echo ""
      echo "|   #   | Name                                                                                                                                     | ID     |"
      echo "| :---: | ---------------------------------------------------------------------------------------------------------------------------------------- | ------ |"
      jq -r '.[] | "| [<img src=\"" + .avatar_url + "\" alt=\"Avatar\" width=\"24\" height=\"24\"> " + .login + "](" + .html_url + ") | " + (.id | tostring) + " |"' "$USERS_DATA" | nl -w 3 -s ' ' | awk '{printf "| %3d %s\n", NR, substr($0, index($0,$2))}'
      echo ""
      echo "### Total: $TOTAL_USERS"
      echo ""
    } >> "$SUMMARY_MD"
  fi

  # Repositories section
  if [ -f "$REPO_DATA" ]; then
    local TOTAL_REPOS
    TOTAL_REPOS=$(jq 'length' "$REPO_DATA")
    local HAS_PUBLIC
    HAS_PUBLIC=$(jq '[.[] | select(.visibility == "PUBLIC")] | length' "$REPO_DATA")
    {
      echo "## Repositories"
      echo ""
      if [ "$HAS_PUBLIC" -gt 0 ]; then
        echo "> [!WARNING]"
        echo "> Public repositories detected"
        echo ""
      fi
      echo "|   #   | Name                    | URL                                                                                   | Visibility | Note  |"
      echo "| :---: | ----------------------- | ------------------------------------------------------------------------------------- | ---------- | :---: |"
      jq -r '.[] | "| " + .name + " | [" + .name + "](" + .html_url + ") | " + .visibility + " | " + (if .visibility == "PUBLIC" then "⚠️" else "" end) + " |"' "$REPO_DATA" | nl -w 3 -s ' ' | awk '{printf "| %3d %s\n", NR, substr($0, index($0,$2))}'
      echo ""
      echo "### Total: $TOTAL_REPOS"
      echo ""
    } >> "$SUMMARY_MD"
  fi

  # Pull Requests section
  if [ -f "$SCRIPT_DIR/prs.json" ]; then
    local TOTAL_PRS
    TOTAL_PRS=$(jq 'length' "$SCRIPT_DIR/prs.json")
    if [ "$TOTAL_PRS" -gt 0 ]; then
      {
        echo "## Open Pull Requests"
        echo ""
        echo "|   #   | Repository | PR | Title | Author | Status | Created |"
        echo "| :---: | ---------- | -- | ----- | ------ | ------ | ------- |"
        jq -r '.[] | "| [" + .repository + "](https://github.com/'"$OWNER"'/" + .repository + ") | [#" + (.number | tostring) + "](" + .html_url + ") | " + .title + " | " + .user + " | " + (if .draft then "🚧 Draft" else "✅ Ready" end) + " | " + (.created_at | split("T")[0]) + " |"' "$SCRIPT_DIR/prs.json" | nl -w 3 -s ' ' | awk '{printf "| %3d %s\n", NR, substr($0, index($0,$2))}'
        echo ""
        echo "### Total: $TOTAL_PRS"
        echo ""
      } >> "$SUMMARY_MD"
    fi
  fi

  # Vulnerabilities section
  if [ -f "$ALERTS_DATA" ]; then
    local TOTAL_ALERTS
    TOTAL_ALERTS=$(jq 'length' "$ALERTS_DATA")
    {
      echo "## Vulnerabilities"
      echo ""
      echo "|   #   | Repository | Severity | CVE | Summary |"
      echo "| :---: | ---------- | -------- | --- | ------- |"
      jq -r '.[] | "| [" + .repository + "](" + .html_url + ") | " + .severity + " | [" + .cve + "](https://nvd.nist.gov/vuln/detail/" + .cve + ") | " + .security_advisory + " |"' "$ALERTS_DATA" | nl -w 3 -s ' ' | awk '{printf "| %3d %s\n", NR, substr($0, index($0,$2))}'
      echo ""
      echo "### Total: $TOTAL_ALERTS"
    } >> "$SUMMARY_MD"
  else
    {
      echo "## Vulnerabilities"
      echo ""
      echo "✨ No vulnerabilities found"
      echo ""
      echo "### Total: 0"
    } >> "$SUMMARY_MD"
  fi
}

generate_team_data() {
  local TEAM_DATA="$SCRIPT_DIR/team_data.json"
  local TIMESTAMP
  TIMESTAMP=$(date +%s)
  
  # Collect all data files
  local members="[]"
  local repositories="[]"
  local vulnerabilities="[]"
  local pull_requests="[]"
  local public_repositories="[]"
  
  if [ -f "$USERS_DATA" ]; then
    members=$(cat "$USERS_DATA")
  fi
  
  if [ -f "$REPO_DATA" ]; then
    repositories=$(cat "$REPO_DATA")
  fi
  
  if [ -f "$ALERTS_DATA" ]; then
    vulnerabilities=$(cat "$ALERTS_DATA")
  fi
  
  if [ -f "$SCRIPT_DIR/prs.json" ]; then
    pull_requests=$(cat "$SCRIPT_DIR/prs.json")
  fi
  
  if [ -f "$SCRIPT_DIR/public_repos.json" ]; then
    public_repositories=$(cat "$SCRIPT_DIR/public_repos.json")
  fi
  
  # Create comprehensive JSON
  jq -n \
    --argjson timestamp "$TIMESTAMP" \
    --arg owner "$OWNER" \
    --arg team_slug "${TEAM_SLUG:-}" \
    --arg since_date "$SINCE_DATE" \
    --arg until_date "$UNTIL_DATE" \
    --argjson members "$members" \
    --argjson repositories "$repositories" \
    --argjson vulnerabilities "$vulnerabilities" \
    --argjson pull_requests "$pull_requests" \
    --argjson public_repositories "$public_repositories" \
    '{
      timestamp: $timestamp,
      owner: $owner,
      team_slug: $team_slug,
      date_range: {
        since: $since_date,
        until: $until_date
      },
      members: $members,
      repositories: $repositories,
      vulnerabilities: $vulnerabilities,
      pull_requests: $pull_requests,
      public_repositories: $public_repositories,
      summary: {
        total_members: ($members | length),
        total_repositories: ($repositories | length),
        total_vulnerabilities: ($vulnerabilities | length),
        total_pull_requests: ($pull_requests | length),
        total_public_repos: ($public_repositories | length)
      }
    }' > "$TEAM_DATA"
  
  format_log "[INFO] Team data created: $TEAM_DATA"
}

usage() {
  printf '%s\n' "Usage: $(basename "$0") [OPTIONS]"
  printf '\n'
  printf '%s\n' "Options:"
  printf '  -o, --owner=OWNER      GitHub organization or user (required)\n'
  printf '  -t, --team=TEAM_SLUG   Optional team slug within organization\n'
  printf '  -h, --help             Show this help message\n'
  printf '\n'
}


setup() {
  setup_colors

  # Use environment variables or defaults
  TEAM_SLUG="${TEAM_SLUG:-}"
  SINCE_DATE="${SINCE_DATE:-$(date -d 'last month' +%Y-%m-01)}"
  UNTIL_DATE="${UNTIL_DATE:-$(date +%Y-%m-%d)}"
  REPORT_PATH="${REPORT_PATH:-./report}"
  SCRIPT_DIR="$REPORT_PATH"
  
  # File paths
  SUMMARY_MD="$SCRIPT_DIR/report_summary.md"
  REPO_LIST="$SCRIPT_DIR/repos.txt"
  MEMBERS_LIST="$SCRIPT_DIR/users.txt"
  REPO_DATA="$SCRIPT_DIR/repos.json"
  ALERTS_DATA="$SCRIPT_DIR/alerts.json"
  USERS_DATA="$SCRIPT_DIR/users.json"

  # Create report directory
  if [ ! -d "$SCRIPT_DIR" ]; then
    mkdir -p "$SCRIPT_DIR"
  fi
  
  # Clean up old reports
  rm -f "$SUMMARY_MD" "$REPO_LIST" "$MEMBERS_LIST" "$REPO_DATA" "$ALERTS_DATA" "$USERS_DATA"
  rm -f "$SCRIPT_DIR/critical.json" "$SCRIPT_DIR/admins.json" "$SCRIPT_DIR/public_repos.json"
  rm -f "$SCRIPT_DIR/prs.json" "$SCRIPT_DIR/team_data.json"
}


main() {
  # Parse command line arguments
  if ! OPTIONS=$(getopt -o ho:t: --long help,owner:,team: -- "$@"); then
    usage
    exit 1
  fi
  eval set -- "$OPTIONS"
  while true; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      -o|--owner)
        OWNER="$2"
        shift 2
        ;;
      -t|--team)
        TEAM_SLUG="$2"
        shift 2
        ;;
      --)
        shift
        break
        ;;
      *)
        usage
        exit 1
        ;;
    esac
  done

  # Validate required parameters
  if [ -z "$OWNER" ]; then
    format_error "[ERROR] Owner is required"
    usage
    exit 1
  fi

  setup
  
  format_log "[INFO] Starting Squad report generation"
  format_log "[INFO] Owner: $OWNER"
  if [ -n "$TEAM_SLUG" ]; then
    format_log "[INFO] Team: $TEAM_SLUG"
  fi
  format_log "[INFO] Date range: $SINCE_DATE to $UNTIL_DATE"
  
  # Fetch data
  get_repo_names
  get_repo_data
  get_alerts
  get_pull_requests
  get_users
  
  # Generate report
  render_report
  generate_team_data
  
  format_log "[INFO] Squad report generated successfully"
  
  format_log "[INFO] Report generated: $SUMMARY_MD"
}

main "$@"