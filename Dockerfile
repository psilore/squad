FROM alpine:3.23

# Security labels
LABEL org.opencontainers.image.title="Squad GitHub Reporter" \
      org.opencontainers.image.description="Generate reports about GitHub organizations and teams" \
      org.opencontainers.image.vendor="psilore" \
      org.opencontainers.image.source="https://github.com/psilore/squad" \
      org.opencontainers.image.licenses="MIT"

# Install dependencies
RUN apk add --no-cache \
    bash \
    git \
    curl \
    jq \
    coreutils \
    github-cli \
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
