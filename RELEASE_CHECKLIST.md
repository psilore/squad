# Release Checklist

Use this checklist when preparing to release your Squad action.

## Pre-Release

- [ ] All tests passing in `.github/workflows/test.yml`
- [ ] Documentation reviewed and updated
- [ ] All commits since the last release follow the Conventional Commits format (e.g., `feat:`, `fix:`, `chore:`)
- [ ] All TODO items completed
- [ ] Security review completed

## Testing

- [ ] Local script test: `./scripts/squad.sh -o <org>`
- [ ] Docker build test: `docker build -t squad:test .`
- [ ] Docker run test with sample organization
- [ ] Test workflow runs successfully
- [ ] Outputs verified (all 5 outputs working)
- [ ] Report artifacts downloadable and readable

## Documentation

- [ ] README.md has usage examples
- [ ] QUICKSTART.md is beginner-friendly
- [ ] action.yml descriptions are clear
- [ ] All inputs documented
- [ ] All outputs documented
- [ ] Contributing guidelines present

## Release Process

We use **release-please** to fully automate our release process, including version bumps, generating `CHANGELOG.md` updates, creating Git tags, and publishing GitHub Releases.

### 1. Merge to `main` with Conventional Commits
All changes merged into `main` must use the [Conventional Commits](https://www.conventionalcommits.org/) standard. When you merge changes:
- `feat:` commits will trigger a **Minor** version bump (e.g., `v1.0.1` to `v1.1.0`).
- `fix:` commits will trigger a **Patch** version bump (e.g., `v1.0.1` to `v1.0.2`).
- Commits containing `BREAKING CHANGE:` in the footer or `!` after the type/scope will trigger a **Major** version bump (e.g., `v1.0.1` to `v2.0.0`).

### 2. Release PR is Created/Updated
Whenever a push to `main` happens, the `release-please-action` runs:
- It scans the commit history since the last release.
- It automatically creates or updates a pending **Release Pull Request** containing the updated `CHANGELOG.md` and the bumped version number.

### 3. Merge the Release PR
To perform a release:
- [ ] Review the open **Release PR** (titled `chore: release main`).
- [ ] Check the generated `CHANGELOG.md` changes.
- [ ] Merge the Release PR.
- Once merged, the action will automatically:
  - Create the corresponding Git tag (e.g., `v1.1.0`).
  - Publish a new GitHub Release with the changelog as release notes.

### 4. Verify Marketplace Listing

- [ ] Action appears in GitHub Marketplace
- [ ] Icon and color correct
- [ ] Description accurate
- [ ] Categories appropriate
- [ ] Usage instructions visible

### 5. Test Published Action

Create test repository and verify:

```yaml
- uses: psilore/squad@v1.0.0
  with:
    owner: test-org
    github-token: ${{ secrets.GITHUB_TOKEN }}
```

- [ ] Action runs successfully
- [ ] Outputs are correct
- [ ] Report generated properly

## Post-Release

- [ ] Announce in GitHub Discussions
- [ ] Share on social media (optional)
- [ ] Monitor issues for bug reports
- [ ] Update project board/roadmap
- [ ] Thank contributors

## Rollback Plan

If issues discovered after release:

1. Create hotfix branch from tag
2. Fix critical issue
3. Create patch release (v1.0.1)
4. Update major version tag:
   ```bash
   git tag -f v1 v1.0.1
   git push -f origin v1
   ```

## Version Strategy

- **Patch (v1.0.x)**: Bug fixes, documentation
- **Minor (v1.x.0)**: New features, backward compatible
- **Major (vx.0.0)**: Breaking changes

## Sample Release Notes Template

```markdown
## 🎉 Squad v1.0.0

### Features
- ✨ Docker-based GitHub Action
- 📊 Comprehensive reporting
- 🔒 Security vulnerability scanning
- 👥 Team and user tracking

### Inputs
- `owner` - Organization name (required)
- `team-slug` - Team identifier (optional)
- `github-token` - Authentication token (required)
- `since-date` - Report start date (optional)
- `until-date` - Report end date (optional)
- `report-path` - Output directory (optional)

### Outputs
- `total-alerts` - Dependabot alert count
- `critical-alerts` - Critical severity count
- `total-repos` - Repository count
- `total-users` - User count
- `report-path` - Output location

### Usage

\`\`\`yaml
- uses: psilore/squad@v1
  with:
    owner: 'your-organization'
    github-token: ${{ secrets.GITHUB_TOKEN }}
\`\`\`

### Full Changelog
See [CHANGELOG.md](CHANGELOG.md)
```

## Maintenance Schedule

- **Weekly**: Monitor issues and discussions
- **Monthly**: Review and merge dependency updates
- **Quarterly**: Review roadmap and plan features
- **Yearly**: Major version planning

## Support Channels

- **Issues**: Bug reports and feature requests
- **Discussions**: Questions and community support
- **Security**: security@yourdomain.com (if applicable)

---

**Ready to Release?** Make sure all checkboxes are complete! ✅
