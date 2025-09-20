#!/bin/bash
set -e

# Функция для запуска Podman под правильным пользователем
start_podman_service() {
    if [ "${ENABLE_PODMAN}" != "false" ]; then
        echo "Starting Podman service..."
        
        # Настройка XDG_RUNTIME_DIR для rootless podman
        if [ -z "$XDG_RUNTIME_DIR" ]; then
            export XDG_RUNTIME_DIR="/run/user/$(id -u)"
            
            # Если запущены под root, создаем директорию для dev
            if [ "$(id -u)" = "0" ]; then
                mkdir -p "/run/user/1000"
                chown dev:dev "/run/user/1000"
                chmod 700 "/run/user/1000"
                export XDG_RUNTIME_DIR="/run/user/1000"
            else
                mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true
            fi
        fi
        
        # Запускаем Podman socket
        if [ "$(id -u)" = "0" ]; then
            # Если мы root, запускаем обычный podman
            mkdir -p /run/podman
            podman system service --time=0 unix:///run/podman/podman.sock &
        else
            # Если мы dev, запускаем rootless podman
            mkdir -p $HOME/.local/share/containers/storage 2>/dev/null || true
            podman system service --time=0 unix://$XDG_RUNTIME_DIR/podman/podman.sock &
        fi
        
        echo "Podman started ($(id -un) mode)"
    fi
}

# Если запущены под root, переключаемся на dev для интерактивных команд
if [ "$(id -u)" = "0" ]; then
    echo "Running as root, setting up environment..."
    
    # Запускаем Podman под root если нужно
    start_podman_service
    
    # Запускаем init.sh под root для системных сервисов
    if [ -f "/init.sh" ]; then
        /init.sh &
    fi
    
    # Настраиваем окружение для dev
    export HOME=/home/dev
    export USER=dev
    export XDG_RUNTIME_DIR="/run/user/1000"
    export DISPLAY="$DISPLAY"
    
    # Для интерактивных команд переключаемся на dev
    if [ $# -eq 0 ] || [ "$1" = "bash" ] || [ "$1" = "sh" ] || [ "$1" = "tmux" ]; then
        echo "Switching to dev user for interactive session..."
        exec sudo -E -u dev /entrypoint-dev.sh "$@"
    else
        # Для других команд выполняем под dev
        exec sudo -E -u dev "$@"
    fi
else
    # Если уже запущены под dev
    export HOME=/home/dev
    cd $HOME
    
    # Запускаем Podman под dev
    start_podman_service
    
    # Запускаем init.sh под dev
    if [ -f "$HOME/init.sh" ]; then
        $HOME/init.sh &
    fi
    
    # Показываем приветствие
    /entrypoint-log.sh
    
    # Если передана команда - выполняем её
    if [ $# -gt 0 ]; then
        echo "Executing: $@"
        exec "$@" || true
    fi
    
    # По умолчанию запускаем bash
    exec /bin/bash
fi
