FROM debian:stable-slim AS base
LABEL maintainer="Pierre Tachoire <pierre@lightpanda.io>"

RUN apt-get update -yq && \
    apt-get install -yq xz-utils ca-certificates \
        clang make curl git \
        pkg-config libglib2.0-dev \
    --no-install-recommends

FROM base AS zig

ARG ARCH=x86_64
ARG MINISIG=0.12
ARG ZIG_MINISIG=RWSGOq2NVecA2UPNdBUZykf1CCb147pkmdtYxgb3Ti+JO/wCYvhbAb/U
ARG ZIG=0.15.2

# install minisig
RUN curl --fail -L -O https://github.com/jedisct1/minisign/releases/download/${MINISIG}/minisign-${MINISIG}-linux.tar.gz && \
    tar xvzf minisign-${MINISIG}-linux.tar.gz -C /

# install zig
RUN curl --fail -L -O https://ziglang.org/download/${ZIG}/zig-${ARCH}-linux-${ZIG}.tar.xz && \
    curl --fail -L -O https://ziglang.org/download/${ZIG}/zig-${ARCH}-linux-${ZIG}.tar.xz.minisig && \
    /minisign-linux/${ARCH}/minisign -Vm zig-${ARCH}-linux-${ZIG}.tar.xz -P ${ZIG_MINISIG} && \
    tar xvf zig-${ARCH}-linux-${ZIG}.tar.xz && \
    mv zig-${ARCH}-linux-${ZIG} /usr/local/lib && \
    ln -s /usr/local/lib/zig-${ARCH}-linux-${ZIG}/zig /usr/local/bin/zig

FROM zig AS chrome

# Chrome
# Install latest chrome dev package
RUN apt-get update \
    && apt-get install -yq gpg wget \
    --no-install-recommends

RUN set -x \
    && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/googlechrome-linux-keyring.gpg \
    && sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/googlechrome-linux-keyring.gpg] https://dl-ssl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' \
    && apt-get update \
    && apt-get install -y google-chrome-stable \
    --no-install-recommends

FROM chrome AS debug

ARG UID=1000
ARG GID=1000
RUN groupadd -r --gid ${GID} debug && useradd --uid ${UID} -rm -g debug -G audio,video debug
USER debug
WORKDIR /debug

FROM debug AS claude
USER debug

# install claude
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/home/debug/.local/bin:${PATH}"

FROM claude AS browser
USER debug

# Get Rust
RUN curl https://sh.rustup.rs -sSf | sh -s -- --profile minimal -y
ENV PATH="/home/debug/.cargo/bin:${PATH}"

FROM browser AS tools
USER root

RUN apt-get update -yq && \
    apt-get install -yq jq neovim tree python3 sudo nodejs npm \
    --no-install-recommends && \
    echo "debug ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/debug && \
    chmod 0440 /etc/sudoers.d/debug

USER debug

RUN sudo npm install -g js-beautify

FROM tools
USER debug

WORKDIR /debug

ENTRYPOINT ["/bin/bash"]
