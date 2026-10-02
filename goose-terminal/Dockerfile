ARG BUILD_FROM
FROM ${BUILD_FROM}

# All runtime packages are baked into the image so startup never depends on
# the network (ttyd/tmux/jq were previously apk-installed on every boot).
# libstdc++ and libgcc are required by the Goose binary; bzip2 unpacks the
# release tarball.
RUN apk add --no-cache \
    bash \
    bzip2 \
    curl \
    git \
    jq \
    libgcc \
    libstdc++ \
    nano \
    py3-pip \
    python3 \
    tar \
    tmux \
    tree \
    ttyd \
    vim \
    wget \
    xz \
    yq

# Keep caches out of persistent storage so they never land in HA backups
ENV npm_config_cache=/tmp/npm-cache

# The HA base image already runs ash with pipefail; restate it so hadolint
# (which only sees this file) knows the curl|tar pipe below is guarded.
SHELL ["/bin/ash", "-o", "pipefail", "-c"]

# Bundled Goose CLI. This copy is frozen at image build time; when
# goose_auto_update is enabled, run.sh refreshes a persistent install in /data
# that takes precedence and keeps itself current.
# Alpine is musl, so the GNU (-gnu) release will not run — use the portable
# musl build. Download the versioned asset for the current architecture
# straight from the GitHub "stable" release.
RUN case "$(apk --print-arch)" in \
        x86_64)  goose_asset="goose-x86_64-unknown-linux-musl.tar.bz2" ;; \
        aarch64) goose_asset="goose-aarch64-unknown-linux-musl.tar.bz2" ;; \
        *) echo "Unsupported architecture: $(apk --print-arch)" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/block/goose/releases/download/stable/${goose_asset}" \
        -o /tmp/goose.tar.bz2 \
    && tar -xjf /tmp/goose.tar.bz2 -C /usr/local/bin \
    && rm -f /tmp/goose.tar.bz2 \
    && chmod +x /usr/local/bin/goose \
    && /usr/local/bin/goose --version

WORKDIR /config

COPY run.sh /run.sh
COPY scripts/ /opt/scripts/
RUN chmod +x /run.sh /opt/scripts/*.sh

# Use exec form for better signal handling
CMD ["/run.sh"]
