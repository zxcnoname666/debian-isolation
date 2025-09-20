#!/bin/bash
set -e

# Скрипт выполняется под пользователем dev
export HOME=/home/dev
cd $HOME

# Загружаем профиль пользователя
if [ -f "$HOME/.profile" ]; then
    . "$HOME/.profile"
fi

# Загружаем cargo env для Rust
if [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
fi

# Загружаем Volta
if [ -f "$HOME/.volta/bin/volta" ]; then
    export VOLTA_HOME="$HOME/.volta"
    export PATH="$HOME/.volta/bin:$PATH"
fi

# Настройка DISPLAY для GUI приложений
if [ -z "$DISPLAY" ]; then
    export DISPLAY=:0
fi

# Запуск Podman в rootless режиме для dev (если еще не запущен)
if [ "${ENABLE_PODMAN}" != "false" ] && ! pgrep -f "podman system service" > /dev/null; then
    echo "Starting rootless Podman for dev user..."
    
    # Настройка XDG_RUNTIME_DIR
    if [ -z "$XDG_RUNTIME_DIR" ]; then
        export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    fi
    
    mkdir -p $XDG_RUNTIME_DIR/podman 2>/dev/null || true
    mkdir -p $HOME/.local/share/containers/storage 2>/dev/null || true
    
    # Запускаем rootless podman
    podman system service --time=0 unix://$XDG_RUNTIME_DIR/podman/podman.sock &
    sleep 1
    
    echo "Rootless Podman started for dev"
    export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"
fi

# Запускаем пользовательский init если есть
if [ -f "$HOME/init.sh" ] && [ ! -f "/tmp/user-init-done" ]; then
    echo "Running user init script..."
    bash $HOME/init.sh &
    touch /tmp/user-init-done
fi

export GIT_CONFIG_GLOBAL=/home/dev/configs/.gitconfig

# Показываем приветствие
/entrypoint-log.sh

# Обработка команд
case "$1" in
    bash|sh|"")
        exec /bin/bash
        ;;
    tmux)
        exec tmux new-session -s main || tmux attach -t main
        ;;
    jetbrains-toolbox|toolbox)
        echo "Starting JetBrains Toolbox..."
        exec $HOME/.local/bin/jetbrains-toolbox
        ;;
    clion)
        echo "Starting CLion..."
        exec $HOME/.local/share/JetBrains/Toolbox/scripts/clion
        ;;
    rustrover)
        echo "Starting RustRover..."
        exec $HOME/.local/share/JetBrains/Toolbox/scripts/rustrover
        ;;
    *)
        # Выполняем переданную команду
        exec "$@"
        ;;
esac
