# Squad Action Quick Start Guide

## 🚀 Quick Start

### Local Development

If you're developing or testing locally:

```bash
# Build and run with Make
export GITHUB_TOKEN="ghp_yourtoken"
make run OWNER=your-org

# Or view all commands
make help
```

### 1. Add to Your Workflow

Create `.github/workflows/squad-report.yml`:

```yaml
name: Squad Report
on:
  schedule:
    - cron: '0 0 1 * *'  # Monthly
  workflow_dispatch:

jobs:
  report:
    runs-on: ubuntu-latest
    steps:
      - uses: psilore/squad@v1
        with:
          owner: 'your-organization'
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

### 2. Required Permissions

Update your workflow or create a PAT with these permissions:

- `repo` access
- `read:org`
- `read:user`

### 3. Run Your First Report

- Go to Actions tab
- Select "Squad Report" workflow
- Click "Run workflow"
- Check artifacts for the generated report

## 📝 Common Use Cases

### Monthly Security Reports

```yaml
on:
  schedule:
    - cron: '0 9 1 * *'  # 9 AM on 1st of month
```

### Team-Specific Reports

```yaml
with:
  owner: 'my-org'
  team-slug: 'platform-team'
```

### Fail on Critical Alerts

```yaml
- uses: psilore/squad@v1
  id: squad
  with:
    owner: 'my-org'
    github-token: ${{ secrets.GITHUB_TOKEN }}

- name: Check Critical
  if: steps.squad.outputs.critical-alerts > 0
  run: exit 1
```

### Send Slack Notification

```yaml
- uses: psilore/squad@v1
  id: squad
  # ... other config

- name: Slack Notification
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "Squad Report: ${{ steps.squad.outputs.total-alerts }} alerts found"
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

## 🔧 Troubleshooting

### Authentication Issues

- Ensure your token has correct permissions
- For org reports, use a PAT instead of `GITHUB_TOKEN`

### No Data in Report

- Check that the owner name is correct
- Verify token has access to the organization
- Check team-slug spelling if specified

### Docker Build Fails

- Ensure Dockerfile is in repository root
- Check that all scripts are properly copied

## 📚 More Information

- [Full Documentation](README.md)
- [Examples](.github/workflows/example.yml)
- [Contributing](CONTRIBUTING.md)
