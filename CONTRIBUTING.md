# Contributing to Squad

Thank you for your interest in contributing to Squad!

## Development Setup

1. Fork the repository
2. Clone your fork locally
3. Make your changes
4. Test locally using Docker or the bash script
5. Submit a pull request

## Testing Your Changes

### Local Script Testing

```bash
export GITHUB_TOKEN="your_token"
./scripts/squad.sh -o "test-org" -t "test-team"
```

### Docker Testing

```bash
docker build -t squad:test .
docker run --rm \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -e INPUT_OWNER="test-org" \
  -e INPUT_TEAM_SLUG="test-team" \
  -v $(pwd):/github/workspace \
  squad:test
```

## Code Style

- Use shellcheck for bash scripts
- Follow existing code formatting
- Add comments for complex logic
- Keep functions small and focused

## Pull Request Process

1. Update the README.md with details of changes if needed
2. Update the example workflow if you add new features
3. Ensure the Docker image builds successfully
4. Test the action end-to-end

## Reporting Bugs

Please use GitHub Issues to report bugs. Include:

- What you expected to happen
- What actually happened
- Steps to reproduce
- Your environment (OS, Docker version, etc.)
