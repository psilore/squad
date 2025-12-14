#!/bin/bash

# Test script for Squad action
# Usage: ./local.sh [owner] [team-slug]

set -e

OWNER="${1:-psilore}"
TEAM_SLUG="${2:-}"

echo "🧪 Testing Squad Action Locally"
echo "================================"
echo "Owner: $OWNER"
if [ -n "$TEAM_SLUG" ]; then
  echo "Team: $TEAM_SLUG"
fi
echo ""

# Check if GITHUB_TOKEN is set
if [ -z "$GITHUB_TOKEN" ]; then
  echo "❌ Error: GITHUB_TOKEN environment variable is not set"
  echo ""
  echo "Please set it first:"
  echo "  export GITHUB_TOKEN=\"your_token_here\""
  exit 1
fi

# Build the image
echo "🔨 Building Docker image..."
docker build -t squad:test . -q
echo "✅ Build complete"
echo ""

# Create output directory
mkdir -p test-output
rm -rf test-output/*
chmod 777 test-output  # Allow container user to write

# Run the container
echo "🚀 Running Squad action..."
echo ""

docker run --rm \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -e INPUT_OWNER="$OWNER" \
  -e INPUT_TEAM_SLUG="$TEAM_SLUG" \
  -e INPUT_REPORT_PATH="test-output" \
  -v "$(pwd)/test-output:/workspace/test-output" \
  squad:test

EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ Action completed successfully!"
  echo ""
  echo "📊 Report files generated:"
  ls -lh test-output/
  echo ""
  
  if [ -f test-output/report_summary.md ]; then
    echo "📄 Report Summary:"
    echo "=================="
    cat test-output/report_summary.md
  fi
else
  echo "❌ Action failed with exit code: $EXIT_CODE"
fi

exit $EXIT_CODE
