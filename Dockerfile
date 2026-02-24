FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# ── Install tools ─────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    ca-certificates \
    clamav \
    clamav-daemon \
    yara \
    binutils \
    file \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# ── Setup User & Dirs ─────────────────────────────────────────────
RUN groupadd -g 10001 sandboxgroup && \
    useradd -u 10001 -g sandboxgroup -s /bin/bash -m sandboxuser

# Add /var/log/clamav to the list of folders we own to allow updater to work
RUN mkdir -p /sandbox /rules /output /var/lib/clamav /var/log/clamav /run/clamav && \
    chown -R sandboxuser:sandboxgroup /sandbox /rules /output /var/lib/clamav /var/log/clamav /run/clamav && \
    chmod 755 /var/log/clamav

# ── Copy Script ───────────────────────────────────────────────────
COPY --chown=sandboxuser:sandboxgroup scan.sh /scan.sh
RUN chmod +x /scan.sh

USER sandboxuser
WORKDIR /sandbox

ENTRYPOINT ["/scan.sh"]
