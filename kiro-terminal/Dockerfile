ARG BUILD_FROM
FROM ${BUILD_FROM}

# All runtime packages are baked into the image so startup never depends on
# the network (ttyd/tmux/jq were previously apk-installed on every boot).
# unzip extracts the Kiro CLI release; libstdc++/libgcc back the binary.
RUN apk add --no-cache \
    bash \
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
    unzip \
    vim \
    wget \
    yq

# Keep caches out of persistent storage so they never land in HA backups
ENV npm_config_cache=/tmp/npm-cache

# The HA base image already runs ash with pipefail; restate it so hadolint
# (which only sees this file) knows the curl pipe below is guarded.
SHELL ["/bin/ash", "-o", "pipefail", "-c"]

# Bundled Kiro CLI. This copy is frozen at image build time; when
# kiro_auto_update is enabled, run.sh maintains a persistent install in /data
# that takes precedence and keeps itself current.
# Alpine is musl, so use the musl zip (no external libc dependency). The zip
# contains kirocli/install.sh, which drops kiro-cli (+ kiro-cli-chat) into
# $HOME/.local/bin. KIRO_CLI_SKIP_SETUP=1 keeps it non-interactive (no shell
# edits, no auth prompt). Relocate both binaries into /usr/local/bin as the
# frozen bundled copy.
RUN case "$(apk --print-arch)" in \
        x86_64)  kiro_zip="kirocli-x86_64-linux-musl.zip" ;; \
        aarch64) kiro_zip="kirocli-aarch64-linux-musl.zip" ;; \
        *) echo "Unsupported architecture: $(apk --print-arch)" >&2; exit 1 ;; \
    esac \
    && curl --proto '=https' --tlsv1.2 -fsSL \
        "https://prod.download.cli.kiro.dev/stable/latest/${kiro_zip}" \
        -o /tmp/kirocli.zip \
    && unzip -q /tmp/kirocli.zip -d /tmp/kirocli-pkg \
    && chmod +x /tmp/kirocli-pkg/kirocli/install.sh \
    && HOME=/tmp/kiro-install KIRO_CLI_SKIP_SETUP=1 \
        bash /tmp/kirocli-pkg/kirocli/install.sh \
    && install -m 0755 /tmp/kiro-install/.local/bin/kiro-cli /usr/local/bin/kiro-cli \
    && if [ -f /tmp/kiro-install/.local/bin/kiro-cli-chat ]; then \
           install -m 0755 /tmp/kiro-install/.local/bin/kiro-cli-chat /usr/local/bin/kiro-cli-chat; \
       fi \
    && rm -rf /tmp/kirocli.zip /tmp/kirocli-pkg /tmp/kiro-install \
    && /usr/local/bin/kiro-cli --version

WORKDIR /config

COPY run.sh /run.sh
COPY scripts/ /opt/scripts/
RUN chmod +x /run.sh /opt/scripts/*.sh

# Use exec form for better signal handling
CMD ["/run.sh"]
