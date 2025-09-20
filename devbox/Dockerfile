FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1

# ==================== ROOT SECTION ====================
# Всё, что требует root привилегий

RUN true && \
    # 1. Настраиваем права
    chmod 755 /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin && \
    chown root:root /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin && \
    
    # 2. Создание базовых директорий для предотвращения ошибок
    mkdir -p /run/systemd/system && \
    mkdir -p /var/run/dbus && \
    mkdir -p /etc/systemd/system && \
    touch /etc/systemd/system/multi-user.target.wants && \
    
    # 3. Настройка apt для работы в контейнере
    echo 'APT::Get::Assume-Yes "true";' >> /etc/apt/apt.conf.d/99disable-recommends && \
    echo 'DPkg::Options "--force-confold";' >> /etc/apt/apt.conf.d/99disable-recommends && \
    echo 'DPkg::Options "--force-confdef";' >> /etc/apt/apt.conf.d/99disable-recommends && \
    
    # 4. Установка базовых пакетов с исправлением состояния
    apt-get update && \
    dpkg --configure -a && \
    apt-get install -f && \
    apt-get install -y \
    # Пакеты для фиксов
    ca-certificates apt-utils \
    
    # GUI
    x11-apps x11-utils x11-xserver-utils \
    dbus-x11 packagekit-gtk3-module \
    libcanberra-gtk3-module nautilus \
    openjdk-25-jdk \
    
    # КРИТИЧНО для JetBrains Toolbox!
    libfuse2 \
    libxi6 libxrender1 libxtst6 \
    libxrandr2 libxcursor1 libxinerama1 \
    libfreetype6 libfontconfig1 \
    libgtk-3-0 libgtk-3-bin libgtk-3-common \
    libgbm1 libdrm2 \
    libnss3 libasound2 libxss1 \
    libatk-bridge2.0-0 libatspi2.0-0 \
    libcups2 libdbus-1-3 libxcomposite1 libxdamage1 \
    libxfixes3 libxkbcommon0 libwayland-client0 \
    # Дополнительно для Electron
    libnotify4 libsecret-1-0 \
    xdg-utils desktop-file-utils \
    
    # Базовая система + GUI зависимости
    curl wget nano tmux git nload \
    sudo build-essential pkg-config cmake ninja-build \
    libxext6 libxrender1 libxtst6 libxi6 libfreetype6 \
    libfontconfig1 libxss1 libnss3 libfuse2 \
    libgbm1 libxkbcommon-x11-0 \
    libdrm2 libxcb1 libxdamage1 libxfixes3 \
    zip unzip tar gzip bzip2 xz-utils \
    gnupg lsb-release \
    procps htop ncdu \
    
    # C++ полный toolchain
    g++ g++-13 gcc gcc-13 \
    clang-17 clang-format-17 clang-tidy-17 clangd-17 \
    lldb-17 gdb valgrind \
    libssl-dev ccache \
    # Установка библиотек boost
    libboost-dev \
    libboost-system-dev \
    libboost-filesystem-dev \
    libboost-thread-dev \
    libboost-chrono-dev \
    libboost-test-dev \
    libboost-program-options-dev \
    libboost-regex-dev \
    libboost-serialization-dev \
    
    # Lua 5.4
    lua5.4 liblua5.4-dev luarocks \
    
    # Podman и инструменты контейнеризации
    podman buildah skopeo \
    fuse-overlayfs slirp4netns \
    uidmap dbus-user-session \
    crun runc \
    containernetworking-plugins \
    iptables \
    
    # Настройка альтернатив для clang
    && update-alternatives --install /usr/bin/clang clang /usr/bin/clang-17 100 \
    && update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-17 100 \
    
    # Очистка кэша apt
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 5. Создание пользователя dev с sudo правами
RUN useradd -m -s /bin/bash -u 1000 dev && \
    echo 'dev ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    usermod -aG sudo dev

# 6. Создание необходимых директорий для dev пользователя
RUN mkdir -p /home/dev/.local/bin \
    /home/dev/.local/share \
    /home/dev/.config/containers \
    /home/dev/.cache && \
    chown -R dev:dev /home/dev

# 7. Настройка Podman для rootless режима
RUN echo "dev:100000:65536" >> /etc/subuid && \
    echo "dev:100000:65536" >> /etc/subgid

# 8. Установка глобальных инструментов Lua под root
RUN luarocks install luacheck && \
    luarocks install busted

# 9. Установка .NET SDK глобально (требует root)
RUN mkdir -p /usr/share/dotnet && \
    curl -SL https://dotnetcli.azureedge.net/dotnet/Sdk/8.0.404/dotnet-sdk-8.0.404-linux-x64.tar.gz | \
    tar -xzC /usr/share/dotnet && \
    ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet

# 10. Установка Go глобально (требует root)
RUN wget -q https://go.dev/dl/go1.21.5.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz && \
    rm go1.21.5.linux-amd64.tar.gz

# ==================== USER SECTION ====================
# Переключаемся на пользователя dev для установки пользовательских инструментов

USER dev
WORKDIR /home/dev

# 1. Rust (устанавливается в домашнюю директорию пользователя)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
    sh -s -- -y --default-toolchain stable --profile complete && \
    . "$HOME/.cargo/env" && \
    rustup component add rust-analyzer rustfmt clippy && \
    rustup toolchain install nightly

# 2. Node.js через Volta (пользовательская установка)
RUN curl https://get.volta.sh | bash && \
    export PATH="$HOME/.volta/bin:$PATH" && \
    volta install node@24 && \
    volta install yarn pnpm && \
    npm install -g typescript ts-node @types/node

# 3. Deno (пользовательская установка)
RUN curl -fsSL https://deno.land/install.sh | sh

# 4. Bun (пользовательская установка)
RUN curl -fsSL https://bun.sh/install | bash

# 5. JetBrains Toolbox и IDE (пользовательская установка)
RUN mkdir -p /home/dev/.local/bin \
    /home/dev/.local/share/JetBrains/Toolbox/.settings \
    /home/dev/.local/share/JetBrains/Toolbox/apps \
    /home/dev/.local/share/JetBrains/Toolbox/scripts && \
    curl -SL https://download.jetbrains.com/toolbox/jetbrains-toolbox-2.1.3.18901.tar.gz | \
        tar -xz --strip-components=1 -C /home/dev/.local/bin jetbrains-toolbox-2.1.3.18901/jetbrains-toolbox && \
    \
    mkdir -p /home/dev/.local/share/JetBrains/Toolbox/apps/clion \
    /home/dev/.local/share/JetBrains/Toolbox/apps/rustrover && \
    \
    curl -SL https://download.jetbrains.com/cpp/CLion-2025.2.tar.gz | \
        tar -xz --strip-components=1 -C /home/dev/.local/share/JetBrains/Toolbox/apps/clion clion-2025.2 && \
    echo '#!/bin/sh\nIDE_BIN_HOME="/home/dev/.local/share/JetBrains/Toolbox/apps/clion/bin"\n nohup "$IDE_BIN_HOME/clion" "$@" >/dev/null 2>&1 &' \
    > /home/dev/.local/share/JetBrains/Toolbox/scripts/clion && \
    chmod +x /home/dev/.local/share/JetBrains/Toolbox/scripts/clion && \
    \
    curl -SL https://download.jetbrains.com/rustrover/RustRover-2025.2.tar.gz | \
        tar -xz --wildcards --strip-components=1 -C /home/dev/.local/share/JetBrains/Toolbox/apps/rustrover RustRover* && \
    echo '#!/bin/sh\nIDE_BIN_HOME="/home/dev/.local/share/JetBrains/Toolbox/apps/rustrover/bin"\n nohup "$IDE_BIN_HOME/rustrover" "$@" >/dev/null 2>&1 &' \
    > /home/dev/.local/share/JetBrains/Toolbox/scripts/rustrover && \
    chmod +x /home/dev/.local/share/JetBrains/Toolbox/scripts/rustrover

# 6. Копирование конфигов (переключаемся обратно на root для копирования)
USER root

# Копируем патч для JetBrains
COPY --chown=dev:dev _pill /home/dev/.jetbrains-patch
RUN sudo -u dev /home/dev/.jetbrains-patch/scripts/install.sh

# Копируем конфигурационные файлы
COPY --chown=dev:dev cfg-build/storage.conf /home/dev/.config/containers/storage.conf
COPY --chown=dev:dev cfg-build/containers.conf /home/dev/.config/containers/containers.conf
COPY --chown=dev:dev cfg-build/toolbox.json /home/dev/.local/share/JetBrains/Toolbox/.settings/toolbox.json
COPY --chown=dev:dev cfg-build/tmux.conf /home/dev/.tmux.conf
COPY --chown=dev:dev cfg-build/clear-ram.sh /home/dev/.local/bin/clear-ram

# Копируем и настраиваем entrypoint скрипты
COPY --chmod=755 cfg-build/init.sh /init.sh
COPY --chmod=755 cfg-build/entrypoint.sh /entrypoint.sh
COPY --chmod=755 cfg-build/entrypoint-dev.sh /entrypoint-dev.sh
COPY --chmod=755 cfg-build/entrypoint-log.sh /entrypoint-log.sh

RUN chmod +x /home/dev/.local/bin/clear-ram && \
    chown -R dev:dev /home/dev

# ==================== ENVIRONMENT VARIABLES ====================
# Переключаемся обратно на пользователя dev
USER dev
WORKDIR /home/dev

# Rust
ENV RUST_ROOT="/home/dev/.cargo/bin"

# .NET
ENV DOTNET_ROOT="/usr/share/dotnet"
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1

# Node.js
ENV VOLTA_HOME="/home/dev/.volta"
ENV VOLTA_ROOT="/home/dev/.volta/bin"

# Deno
ENV DENO_INSTALL="/home/dev/.deno"

# Bun
ENV BUN_INSTALL="/home/dev/.bun"

# Go
ENV GOPATH="/home/dev/go"
ENV GO_ROOT="/usr/local/go/bin"

# Java
ENV JAVA_HOME="/usr/lib/jvm/java-25-openjdk-amd64"

# Полный PATH
ENV PATH="/home/dev/.local/bin:/home/dev/.local/share/JetBrains/Toolbox/scripts:/home/dev/.cargo/bin:/home/dev/go/bin:/usr/share/dotnet:${GO_ROOT}:${BUN_INSTALL}/bin:${DENO_INSTALL}/bin:${VOLTA_ROOT}:${DOTNET_ROOT}:${RUST_ROOT}:${JAVA_HOME}/bin:${PATH}"

# Настройка профиля пользователя
RUN PROFILE=/home/dev/.profile && \
    touch "$PROFILE" && \
    echo 'export PATH="/home/dev/.local/bin:/home/dev/.local/share/JetBrains/Toolbox/scripts:/home/dev/.cargo/bin:/home/dev/go/bin:/usr/share/dotnet:/usr/local/go/bin:/home/dev/.bun/bin:/home/dev/.deno/bin:/home/dev/.volta/bin:/usr/share/dotnet:/home/dev/.cargo/bin:/usr/lib/jvm/java-25-openjdk-amd64/bin:$PATH"' >> "$PROFILE" && \
    echo 'export DOCKER_HOST="unix:///var/run/docker.sock"' >> "$PROFILE" && \
    echo 'export DOTNET_CLI_TELEMETRY_OPTOUT=1' >> "$PROFILE"

# Docker/Podman socket
ENV DOCKER_HOST="unix:///var/run/docker.sock"

# Возвращаемся к root для entrypoint
USER root

# Финальная настройка
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
