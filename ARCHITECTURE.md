# Squad Action Architecture

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     GitHub Workflow                          │
│                                                              │
│  on:                                                         │
│    schedule:                                                 │
│      - cron: '0 0 1 * *'                                    │
│                                                              │
│  jobs:                                                       │
│    report:                                                   │
│      - uses: psilore/squad@v1                               │
│        with:                                                 │
│          owner: 'my-org'                                    │
│          github-token: ${{ secrets.GITHUB_TOKEN }}          │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                     action.yml                               │
│                                                              │
│  • Defines inputs (owner, team-slug, etc.)                  │
│  • Defines outputs (total-alerts, etc.)                     │
│  • Specifies Docker runtime                                 │
│  • Maps environment variables                               │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                     Dockerfile                               │
│                                                              │
│  FROM alpine:3.19                                           │
│  # Pinned package versions for security                     │
│  RUN apk add bash=5.2.21-r0 git=2.43.7-r0 jq=1.7.1-r0      │
│             github-cli=2.39.2-r3 curl=8.14.1-r2             │
│  # Non-root user (UID 1000)                                 │
│  RUN addgroup -g 1000 squad && adduser -D -u 1000 -G squad │
│  COPY --chown=squad:squad scripts/ /usr/local/bin/         │
│  USER squad                                                  │
│  ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]               │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                   entrypoint.sh                              │
│                                                              │
│  1. Validate inputs (owner, token)                          │
│  2. Setup GitHub CLI authentication                         │
│  3. Set default dates if not provided                       │
│  4. Initialize git if needed                                │
│  5. Call squad.sh with parameters                           │
│  6. Parse results and set outputs                           │
│  7. Display summary                                         │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    squad.sh                                  │
│                                                              │
│  ┌──────────────────────────────────────────────┐          │
│  │ get_repo_names()                              │          │
│  │ • Fetch repos for org/user/team              │          │
│  │ • Automatic org → user fallback              │          │
│  └──────────┬───────────────────────────────────┘          │
│             ▼                                                │
│  ┌──────────────────────────────────────────────┐          │
│  │ get_repo_data()                               │          │
│  │ • Get repository details                     │          │
│  │ • Detect public repositories                 │          │
│  │ • JSON validation                            │          │
│  └──────────┬───────────────────────────────────┘          │
│             ▼                                                │
│  ┌──────────────────────────────────────────────┐          │
│  │ get_alerts()                                  │          │
│  │ • Scan Dependabot alerts                     │          │
│  │ • Handle 403/404 gracefully                  │          │
│  │ • Skip archived repositories                 │          │
│  │ • Categorize by severity                     │          │
│  └──────────┬───────────────────────────────────┘          │
│             ▼                                                │
│  ┌──────────────────────────────────────────────┐          │
│  │ get_users()                                   │          │
│  │ • Fetch team/org/user members                │          │
│  │ • Get user details with avatars              │          │
│  └──────────┬───────────────────────────────────┘          │
│             ▼                                                │
│  ┌──────────────────────────────────────────────┐          │
│  │ get_pull_requests()                           │          │
│  │ • Track open pull requests                   │          │
│  │ • Include draft status                       │          │
│  │ • Capture author and dates                   │          │
│  └──────────┬───────────────────────────────────┘          │
│             ▼                                                │
│  ┌──────────────────────────────────────────────┐          │
│  │ render_report()                               │          │
│  │ • Generate numbered markdown tables          │          │
│  │ • Include avatars and CVE links              │          │
│  │ • Create comprehensive summary               │          │
│  └──────────┬───────────────────────────────────┘          │
│             ▼                                                │
│  ┌──────────────────────────────────────────────┐          │
│  │ generate_team_data()                          │          │
│  │ • Create team_data.json                      │          │
│  │ • Include all metrics and summaries          │          │
│  └──────────────────────────────────────────────┘          │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                  Generated Files                             │
│                                                              │
│  report/                                                     │
│  ├── report_summary.md      (Main report)                   │
│  ├── alerts.json            (All alerts data)               │
│  ├── critical.json          (Critical alerts only)          │
│  ├── repos.json             (Repository list)               │
│  ├── users.json             (User/member data)              │
│  ├── users_table.md         (Formatted users)               │
│  ├── alerts_table.md        (Formatted alerts)              │
│  ├── repos_table.md         (Formatted repos)               │
│  ├── state.md               (Alert state)                   │
│  └── admin_changes.md       (Admin diff if any)             │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                  Action Outputs                              │
│                                                              │
│  report-path: ./report                                       │
│  total-alerts: 42                                           │
│  critical-alerts: 3                                         │
│  total-repos: 15                                            │
│  total-users: 8                                             │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              Back to Workflow                                │
│                                                              │
│  • Upload artifacts                                          │
│  • Send notifications                                        │
│  • Create issues                                            │
│  • Post PR comments                                         │
│  • Fail on critical alerts                                  │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow Details

### Input Processing
```
GitHub Workflow → action.yml → ENV vars → entrypoint.sh → squad.sh
```

### Authentication Chain
```
secrets.GITHUB_TOKEN → INPUT env var → GH_TOKEN → gh CLI
```

### Report Generation Flow
```
squad.sh:
  1. Fetch repos → active_repos.txt
  2. For each repo:
     - Check if archived (skip)
     - Get Dependabot alerts
     - Aggregate data
  3. Generate JSON files
  4. Render markdown tables
  5. Combine into report_summary.md
```

### Output Flow
```
Report files → Parse with jq → Set GITHUB_OUTPUT → Workflow steps
```

## Component Responsibilities

| Component | Responsibility |
|-----------|---------------|
| **action.yml** | Interface definition, metadata |
| **Dockerfile** | Environment setup, dependencies |
| **entrypoint.sh** | Input validation, orchestration |
| **squad.sh** | Core business logic, API calls |

## Error Handling

```
entrypoint.sh validates:
├── Required inputs present?
├── GitHub token valid?
└── Date formats correct?
    │
    ├── ✅ Continue → squad.sh
    │
    └── ❌ Exit with error → Fail workflow

squad.sh handles:
├── API failures (retry logic possible)
├── Invalid JSON (jq errors)
├── Permission issues (log and skip)
└── File operations (check existence)
```

## Extension Points

### Add New Data Sources
```bash
# In squad.sh, add new function:
get_pull_requests() {
  gh pr list --json number,title > "$REPORT_DIR/prs.json"
}

# Call in main():
get_pull_requests
```

### Add New Outputs
```yaml
# In action.yml:
outputs:
  open-prs:
    description: 'Number of open pull requests'
    value: ${{ steps.generate.outputs.open-prs }}
```

### Add New Inputs
```yaml
# In action.yml:
inputs:
  include-archived:
    description: 'Include archived repositories'
    required: false
    default: 'false'
```

## Performance Considerations

```
Bottlenecks:
├── API rate limits (5000/hour authenticated)
├── Number of repositories (linear scaling)
└── Network latency (GitHub API calls)

Optimizations:
├── Parallel API calls (limited by rate limit)
├── Cache responses (for repeated runs)
└── Pagination (for large datasets)
```

## Security Model

```
Token Flow:
  secrets.GITHUB_TOKEN (secure)
    ↓
  Environment variable (container)
    ↓
  gh CLI configuration (memory)
    ↓
  GitHub API (HTTPS)
    ↓
  Never logged or stored

Report Data:
  • May contain sensitive org info
  • Stored as workflow artifacts
  • Respects repository permissions
  • Can be made private
```
