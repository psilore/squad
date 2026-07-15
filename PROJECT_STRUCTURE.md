# Project Structure Overview

This document explains the GitHub Action implementation for Squad.

## 📁 File Structure

```
squad/
├── .github/
│   ├── workflows/
│   │   ├── example.yml          # Example usage workflow
│   │   ├── tests.yml            # Comprehensive CI/CD tests
│   │   ├── report.yml           # Automated report generation
│   │   └── source-protection.yml # Commitlint & yamllint
│   ├── .yamllintrc.yml          # YAML linting configuration
│   └── dependabot.yaml          # Dependabot configuration
├── scripts/
│   ├── squad.sh                  # Main bash script (enhanced)
│   └── entrypoint.sh             # Action entrypoint wrapper
├── Dockerfile                    # Container with security hardening
├── action.yml                    # Action metadata and interface
├── Makefile                      # Development commands
├── README.md                     # Full documentation
├── QUICKSTART.md                 # Quick start guide
├── PROJECT_STRUCTURE.md          # This file
├── ARCHITECTURE.md               # Architecture diagrams
├── GETTING_STARTED.md            # Setup guide
├── CONTRIBUTING.md               # Contribution guidelines
├── CHANGELOG.md                  # Version history
├── RELEASE_CHECKLIST.md          # Release process
└── .gitignore                    # Git ignore rules
```

## 🔑 Key Components

### 1. **action.yml** - Action Interface
- Defines inputs (owner, team-slug, github-token, etc.)
- Defines outputs (total-alerts, critical-alerts, etc.)
- Specifies Docker as the runtime
- Sets branding and metadata

### 2. **Dockerfile** - Container Setup
- Based on Alpine Linux 3.19 (lightweight)
- Pinned package versions for security:
  * bash=5.2.21-r0
  * git=2.43.7-r0
  * curl=8.14.1-r2
  * jq=1.7.1-r0
  * github-cli=2.39.2-r3
- Non-root user (squad:squad, UID/GID 1000)
- OCI labels for metadata
- Security best practices applied
- ~100MB final image size

### 3. **scripts/entrypoint.sh** - Action Wrapper
- Bridges GitHub Actions → squad.sh
- Handles input validation
- Configures GitHub CLI authentication
- Sets outputs for workflow integration
- Provides colored logging
- ShellCheck compliant (SC2086 disabled for SQUAD_ARGS)
- Efficient output redirection with grouped commands

### 4. **scripts/squad.sh** - Core Script
- Supports environment variables for GitHub Actions
- Configurable report path
- Org → user → team fallback logic
- Pull request tracking with draft status
- Alert scanning with graceful error handling (403/404)
- Public repository detection and warnings
- Archived repository skipping
- Comprehensive team_data.json generation
- ShellCheck compliant (zero warnings)
- Works standalone or in action

## 🔄 Data Flow

```
GitHub Workflow
    ↓
action.yml (defines interface)
    ↓
Dockerfile (builds container)
    ↓
entrypoint.sh (validates & prepares)
    ↓
squad.sh (generates report)
    ↓
Output files + Action outputs
    ↓
Back to workflow (artifacts, next steps)
```

## 📊 Inputs & Outputs

### Inputs
| Name | Required | Default | Description |
|------|----------|---------|-------------|
| owner | ✅ | - | GitHub org/owner |
| team-slug | ❌ | '' | Team identifier |
| github-token | ✅ | - | Auth token |
| since-date | ❌ | Last month | Report start |
| until-date | ❌ | Today | Report end |
| report-path | ❌ | ./report | Output dir |

### Outputs
- `report-path`: Where report was saved
- `total-alerts`: All Dependabot alerts
- `critical-alerts`: Critical severity only
- `total-repos`: Repository count
- `total-users`: User/member count

## 🧪 Testing & Quality Assurance

### CI/CD Pipeline (tests.yml)

1. **source-protection** - Commitlint and yamllint
2. **docker-lint** - Hadolint with warning threshold
3. **shellcheck** - All scripts in scripts/ directory
4. **docker-build** - Buildx with GitHub Actions cache
5. **test-action** - End-to-end validation with artifact upload

### Local Testing with Make

```bash
# Run all linters
make lint

# Individual linters
make lint-docker   # Hadolint
make lint-yaml     # Yamllint
make lint-shell    # ShellCheck

# Run tests
make test

# Build and run
make run OWNER=your-org GITHUB_TOKEN=ghp_...
```

### Manual Testing Commands

```bash
# Hadolint
docker run --rm -i hadolint/hadolint < Dockerfile

# Yamllint
docker run --rm -v "$(pwd):/data" cytopia/yamllint -c .github/.yamllintrc.yml .

# ShellCheck
docker run --rm -v "$(pwd):/mnt" koalaman/shellcheck:stable scripts/*.sh
```

## 🎯 Usage Patterns

### Pattern 1: Scheduled Reports
```yaml
on:
  schedule:
    - cron: '0 0 1 * *'
```

### Pattern 2: Manual Trigger
```yaml
on:
  workflow_dispatch:
    inputs:
      owner:
        description: 'Organization'
        required: true
```

### Pattern 3: PR Comments
```yaml
- uses: psilore/squad@v1
  id: squad
- uses: actions/github-script@v7
  # Post report as PR comment
```

### Pattern 4: CI/CD Gates
```yaml
- uses: psilore/squad@v1
  id: squad
- name: Fail on critical
  if: steps.squad.outputs.critical-alerts > 0
  run: exit 1
```

## 🧪 Testing Strategy

### Local Testing
```bash
# Direct script
./scripts/squad.sh -o "org" -t "team"

# Docker
docker build -t squad:test .
docker run --rm -e GITHUB_TOKEN="..." squad:test
```

### CI Testing
- Workflow: `.github/workflows/test.yml`
- Runs on: push, PR, manual
- Validates: report generation, outputs

## 🚀 Automated Publishing with Release Please

We use **release-please** to automate our versioning, changelog generation, tagging, and GitHub Releases.

### How It Works:

1. **Write Conventional Commits**: When making changes, use prefixes like `feat: ...`, `fix: ...`, or `chore: ...`.
2. **Release PR**: The `.github/workflows/release-please.yml` workflow automatically maintains an open Release Pull Request that tracks all unreleased changes on `main`.
3. **Automated Publishing**: Merging the Release PR automatically creates the Git tag (e.g., `v1.0.2`), generates the release notes, and publishes the new release to GitHub.
4. **Marketplace Listing**: The action is instantly available in the GitHub Marketplace under the new version tag.

### Version Tags
- `v1.0.0` - Specific semantic version (created automatically)
- `v1` - Major version tracking (points to the latest minor/patch release of v1)
- `main` - Latest development version

## 🔐 Security Considerations

### Token Permissions
- Use least-privilege tokens
- `GITHUB_TOKEN` has workflow scope
- PAT needed for org-wide access

### Sensitive Data
- Never log tokens
- Reports may contain org info
- Use private artifact storage

## 🎨 Customization Ideas

### Add More Outputs
```yaml
outputs:
  public-repos:
    description: 'Count of public repos'
```

### Add Configuration File
Support `.squad.yml` for defaults:
```yaml
owner: my-org
team-slug: platform
alerts-only: true
```

### Add Report Formats
- JSON output
- HTML reports
- PDF generation
- CSV exports

## 📦 Dependencies

### Runtime
- bash
- git
- jq (JSON processing)
- github-cli (gh)
- coreutils (date, etc.)

### Development
- Docker
- GitHub Actions
- shellcheck (optional, for linting)

## 🐛 Common Issues

### Issue: Permission Denied
**Solution**: Token needs org access

### Issue: No Repositories Found
**Solution**: Check owner name spelling

### Issue: Docker Build Fails
**Solution**: Ensure all files copied in Dockerfile

### Issue: Report Empty
**Solution**: Verify token scopes and team access

## 📈 Future Enhancements

- [ ] Add pull request metrics
- [ ] Support GitHub Enterprise
- [ ] Add caching for faster runs
- [ ] Support multiple output formats
- [ ] Add trend analysis
- [ ] Integration with issue tracking
- [ ] Custom alert thresholds
- [ ] Email notifications
- [ ] Dashboard generation

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Development setup
- Testing procedures
- Code style guide
- PR process

## 📞 Support

- **Documentation**: README.md
- **Quick Start**: QUICKSTART.md
- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions
