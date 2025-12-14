# Release Checklist

Use this checklist when preparing to release your Squad action.

## Pre-Release

- [ ] All tests passing in `.github/workflows/test.yml`
- [ ] Documentation reviewed and updated
- [ ] CHANGELOG.md updated with changes
- [ ] Version number decided (semver: MAJOR.MINOR.PATCH)
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

### 1. Update Version References

Update version in documentation:
- [ ] README.md examples use new version
- [ ] QUICKSTART.md examples use new version

### 2. Create Git Tag

```bash
# Create annotated tag
git tag -a v1.0.0 -m "Release v1.0.0: Initial GitHub Action release"

# Push tag
git push origin v1.0.0

# Create major version tag (for users who want latest v1.x)
git tag -f v1
git push -f origin v1
```

### 3. Create GitHub Release

- [ ] Go to repository → Releases → New Release
- [ ] Choose tag: v1.0.0
- [ ] Release title: "v1.0.0 - Initial Release"
- [ ] Description from CHANGELOG.md
- [ ] Add highlights and breaking changes
- [ ] Mark as latest release
- [ ] Publish release

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
