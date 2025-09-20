#!/bin/bash

echo "=== Container initialization script ==="
echo "Running as: $(whoami) (UID: $(id -u))"
echo "Home directory: $HOME"

# Определяем, под каким пользователем запущены
if [ "$(id -u)" = "0" ]; then
    echo "[ROOT] Initializing system services..."
    
    # Системные сервисы, которые требуют root
    # Например, настройка сети или системных демонов
    
    # Создание необходимых системных директорий
    mkdir -p /var/run/dbus
    mkdir -p /run/systemd/system
    
    # Запуск D-Bus если нужен для GUI приложений
    if command -v dbus-daemon &> /dev/null && [ ! -f /var/run/dbus/pid ]; then
        echo "Starting D-Bus system daemon..."
        dbus-daemon --system --fork 2>/dev/null || true
    fi
    
    # Меняем владельца смонтированных файлов
    chown -R dev:dev /home/dev
    
    su - dev -c '/init.sh' || true
    
else
    echo "[USER] Initializing user environment..."
    
    # Пользовательская инициализация
    # Создание необходимых директорий
    mkdir -p $HOME/.cache
    mkdir -p $HOME/.config
    mkdir -p $HOME/.local/share
    mkdir -p $HOME/projects
    
    # Настройка git если есть конфиг
    if [ -f "$HOME/.gitconfig.template" ]; then
        cp $HOME/.gitconfig.template $HOME/.gitconfig
    fi
    
    # Инициализация Rust окружения
    if [ -f "$HOME/.cargo/env" ]; then
        . "$HOME/.cargo/env"
        echo "Rust environment loaded"
    fi
    
    # Проверка доступности инструментов
    echo "Checking development tools..."
    command -v rustc &>/dev/null && echo "  ✓ Rust $(rustc --version | cut -d' ' -f2)"
    command -v node &>/dev/null && echo "  ✓ Node.js $(node --version)"
    command -v dotnet &>/dev/null && echo "  ✓ .NET $(dotnet --version)"
    command -v go &>/dev/null && echo "  ✓ Go $(go version | cut -d' ' -f3)"
    command -v podman &>/dev/null && echo "  ✓ Podman $(podman --version | cut -d' ' -f3)"
    
    # Кастомные пользовательские скрипты инициализации
    if [ -d "$HOME/.init.d" ]; then
        for script in $HOME/.init.d/*.sh; do
            if [ -f "$script" ]; then
                echo "Running custom init: $(basename $script)"
                bash "$script"
            fi
        done
    fi
fi

echo "=== Initialization complete ==="

# Держим скрипт активным для фоновых процессов
# Комментируем tail -f если не нужно держать процесс
tail -f /dev/null
