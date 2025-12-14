# squad

[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow.svg)](https://conventionalcommits.org)
[![semantic-release](https://img.shields.io/badge/semantic-release-e10079?logo=semantic-release)](https://github.com/semantic-release/semantic-release)
[![Main](https://github.com/psilore/squad/actions/workflows/main.yml/badge.svg?branch=main)](https://github.com/psilore/squad/actions/workflows/main.yml)

A GitHub Action that generates comprehensive reports about GitHub organizations and teams, including repositories, Dependabot alerts, pull requests, and team members.

## Features

- 📊 **Repository Overview** - List all repositories with visibility status and public repo warnings
- 🔒 **Security Scanning** - Analyze Dependabot alerts with CVE links and severity tracking
- 🔀 **Pull Request Tracking** - Monitor open pull requests with draft status and author info
- 👥 **Team Management** - Track team members and organization users
- 📈 **Detailed Reports** - Generate markdown reports with comprehensive statistics
- 🎯 **Flexible Targeting** - Report on entire organizations, specific teams, or individual users
- 📦 **JSON Exports** - Comprehensive team_data.json with all collected metrics

## Usage

### Basic Example

```yaml
name: Monthly Security Report

on:
  schedule:
    - cron: '0 0 1 * *'  # First day of every month
  workflow_dispatch:

jobs:
  generate-report:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Generate Report
        uses: psilore/squad@v1
        with:
          owner: 'your-organization'
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

### Advanced Example with Team

```yaml
- name: Generate Team Report
  id: squad-report
  uses: psilore/squad@v1
  with:
    owner: 'your-organization'
    team-slug: 'engineering-team'
    github-token: ${{ secrets.PAT_TOKEN }}
    since-date: '2024-01-01'
    until-date: '2024-12-31'
    report-path: './reports'
    alerts: 'true'
    users: 'true'
    pull-requests: 'true'

- name: Upload Report
  uses: actions/upload-artifact@v4
  with:
    name: squad-report
    path: ./reports/
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `owner` | GitHub organization or owner name | ✅ Yes | - |
| `team-slug` | Team slug within the organization | ❌ No | `''` (entire org) |
| `github-token` | GitHub token with appropriate permissions | ✅ Yes | - |
| `since-date` | Start date for report range (YYYY-MM-DD) | ❌ No | First day of previous month |
| `until-date` | End date for report range (YYYY-MM-DD) | ❌ No | Today |
| `report-path` | Path where report will be saved | ❌ No | `./report` |
| `alerts` | Include Dependabot alerts scanning | ❌ No | `true` |
| `users` | Include user/member data collection | ❌ No | `true` |
| `pull-requests` | Include open pull requests tracking | ❌ No | `true` |

## Outputs

| Output | Description |
|--------|-------------|
| `report-path` | Path to the generated report directory |
| `total-alerts` | Total number of Dependabot alerts found |
| `critical-alerts` | Number of critical severity alerts |
| `total-repos` | Total number of repositories analyzed |
| `total-users` | Total number of users/members |

## Permissions

The GitHub token needs the following permissions:

```yaml
permissions:
  contents: read
  issues: read
  pull-requests: read
  repository-projects: read
```

For organization-level reporting, you may need a Personal Access Token (PAT) with:

- `repo` - Full control of private repositories
- `read:org` - Read org and team membership
- `read:user` - Read user profile data

## Report Contents

The generated report includes:

### Markdown Report (report_summary.md)

1. **Users Table** - Team members with avatars and GitHub profiles
2. **Repositories Table** - All repos with visibility status and public repo warnings
3. **Open Pull Requests Table** - Active PRs with status, author, and dates
4. **Vulnerabilities Table** - Dependabot alerts with CVE links and severity levels

### JSON Exports

- **team_data.json** - Comprehensive data with all metrics and summaries
- **repos.json** - Repository details with visibility information
- **users.json** - User/member data with avatars and profiles
- **prs.json** - Open pull request details
- **alerts.json** - Dependabot vulnerability data
- **public_repos.json** - List of public repositories (if any detected)

## Example Workflow with Notifications

```yaml
- name: Generate Report
  id: squad
  uses: psilore/squad@v1
  with:
    owner: 'your-org'
    github-token: ${{ secrets.GITHUB_TOKEN }}

- name: Check Critical Alerts
  if: steps.squad.outputs.critical-alerts > 0
  run: |
    echo "::warning::Found ${{ steps.squad.outputs.critical-alerts }} critical alerts!"
    
- name: Create Issue on Critical Alerts
  if: steps.squad.outputs.critical-alerts > 0
  uses: actions/github-script@v7
  with:
    script: |
      github.rest.issues.create({
        owner: context.repo.owner,
        repo: context.repo.repo,
        title: '🚨 Critical Security Alerts Detected',
        body: `Found ${{ steps.squad.outputs.critical-alerts }} critical alerts.\n\nSee the full report in the workflow artifacts.`,
        labels: ['security', 'critical']
      });
```

## Local Development

### Using Make (Recommended)

The project includes a Makefile for easy development:

```bash
# View all available commands
make help

# Run all linters (Docker, YAML, Shell)
make lint

# Build the Docker image
make build

# Build and run
make run OWNER=your-org GITHUB_TOKEN=ghp_...

# Quick run without rebuilding
make quick-run OWNER=your-org GITHUB_TOKEN=ghp_...

# Run tests
make test

# Clean up
make clean
```

### Manual Commands

#### Running the Script Directly

```bash
# Set required environment variables
export OWNER="your-organization"
export TEAM_SLUG="your-team"  # Optional
export GITHUB_TOKEN="ghp_yourtoken"

# Run the script
./scripts/squad.sh -o "$OWNER" -t "$TEAM_SLUG"
```

#### Building the Docker Image

```bash
docker build -t squad:latest .
```

#### Testing the Action Locally

```bash
# Method 1: Using the built image
docker run --rm \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -e INPUT_OWNER="your-org" \
  squad:test

# Method 2: Generate report in a specific directory
mkdir -p output && chmod 777 output
docker run --rm \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -e INPUT_OWNER="your-org" \
  -v $(pwd)/output:/workspace/report \
  squad:test
```

### Quality Assurance

```bash
# Lint Dockerfile
make lint-docker

# Lint YAML files
make lint-yaml

# Lint shell scripts
make lint-shell

# Verify all dependencies
make verify-deps
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details

## Support

If you encounter any issues or have questions, please file an issue in the GitHub repository.
