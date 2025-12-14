FROM alpine:3.23

# Security labels
LABEL org.opencontainers.image.title="Squad GitHub Reporter" \
      org.opencontainers.image.description="Generate reports about GitHub organizations and teams" \
      org.opencontainers.image.vendor="psilore" \
      org.opencontainers.image.source="https://github.com/psilore/squad" \
      org.opencontainers.image.licenses="MIT"

# Install dependencies
RUN apk add --no-cache \
    bash=5.3.3-r1 \
    git=2.52.0-r0 \
    curl=8.17.0-r1 \
    jq=1.8.1-r0 \
    coreutils=9.8-r1 \
    github-cli=2.83.0-r1 \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/*

# Set working directory
WORKDIR /workspace

# Copy scripts 
COPY scripts/squad.sh /usr/local/bin/squad.sh
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh

# Make scripts executable
RUN chmod +x /usr/local/bin/squad.sh /usr/local/bin/entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
