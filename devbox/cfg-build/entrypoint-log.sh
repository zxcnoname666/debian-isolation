#!/bin/bash

# Проверяем X11 доступ
if [ -n "$DISPLAY" ]; then
    if ! xhost 2>/dev/null | grep -q "LOCAL:" && ! xhost 2>/dev/null | grep -q "$(hostname)"; then
        echo "⚠️  X11 доступ может быть не настроен. Для GUI приложений выполните на хосте:"
        echo "    xhost +local:docker"
    else
        echo "✓ X11 доступ настроен"
    fi
fi

# Определяем пользователя
USER_INFO="$(whoami)"
if [ "$USER_INFO" = "dev" ]; then
    USER_STATUS="👤 User Mode"
    HOME_DIR="/home/dev"
else
    USER_STATUS="⚡ Root Mode"
    HOME_DIR="/root"
fi

# Проверяем Podman
PODMAN_STATUS="❌ Not running"
if pgrep -f "podman system service" > /dev/null; then
    if [ "$(id -u)" = "0" ]; then
        PODMAN_STATUS="✓ Running (root mode)"
    else
        PODMAN_STATUS="✓ Running (rootless)"
    fi
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                  🚀 Dev Fortress Ready! 🚀                    ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║ Status:                                                        ║"
echo "║   $USER_STATUS ($(id -un))                                    "
echo "║   Home: $HOME_DIR                                             "
echo "║   Podman: $PODMAN_STATUS                                      "
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║ Development Tools:                                             ║"
echo "║   IDE:                                                         ║"
echo "║     • jetbrains-toolbox  - JetBrains Toolbox                 ║"
echo "║     • clion             - CLion IDE                          ║"
echo "║     • rustrover         - RustRover IDE                      ║"
echo "║                                                               ║"
echo "║   Languages & Runtimes:                                       ║"
echo "║     • rustc, cargo      - Rust & Cargo                       ║"
echo "║     • dotnet           - .NET SDK 8.0                        ║"
echo "║     • node, npm        - Node.js 24 LTS                      ║"
echo "║     • yarn, pnpm       - Alternative package managers        ║"
echo "║     • deno             - Deno runtime                        ║"
echo "║     • bun              - Bun runtime                         ║"
echo "║     • go               - Go 1.21                             ║"
echo "║     • clang, gcc       - C/C++ compilers                     ║"
echo "║     • lua              - Lua 5.4                             ║"
echo "║                                                               ║"
echo "║   Container Tools:                                            ║"
echo "║     • podman           - Container management                ║"
echo "║     • buildah          - Container building                  ║"
echo "║     • skopeo           - Container operations                ║"
echo "║                                                               ║"
echo "║   Utilities:                                                  ║"
echo "║     • tmux             - Terminal multiplexer                ║"
echo "║     • clear-ram        - Clear RAM cache                     ║"
echo "║     • git              - Version control                     ║"
echo "║     • htop, ncdu       - System monitoring                   ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║ Quick Tips:                                                   ║"
echo "║   • Use 'sudo' for system operations (passwordless)          ║"
echo "║   • Projects directory: ~/projects                           ║"
echo "║   • Run 'tmux' for better terminal management                ║"
echo "║   • Custom init scripts: ~/.init.d/*.sh                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
