#!/bin/bash

# === Конфигурация ===
APP_NAME="YandexMusic"
APP_DIR="$HOME/.local/bwrap-apps/YandexMusic"
APP_EXEC="/opt/Яндекс Музыка/yandexmusic"

# Параметры Xephyr
XEPHYR_DISPLAY=":100"
XEPHYR_RESOLUTION="1280x720"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# === Функции ===

# Очистка прокси-переменных с авторизацией
clean_proxy_vars() {
    for var in http_proxy HTTP_PROXY https_proxy HTTPS_PROXY ftp_proxy FTP_PROXY all_proxy ALL_PROXY; do
        if [[ "${!var}" == *"@"* ]]; then
            echo -e "${YELLOW}⚠ Сброс $var (содержит авторизацию)${NC}"
            unset $var
        fi
    done
}

# Проверка зависимостей
check_deps() {
    local missing_deps=()
    
    for cmd in bwrap Xephyr xrdb xsetroot; do
        if ! command -v $cmd &> /dev/null; then
            missing_deps+=($cmd)
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}❌ Отсутствуют зависимости: ${missing_deps[*]}${NC}"
        echo "Установите: sudo apt install bubblewrap xserver-xephyr x11-xserver-utils"
        exit 1
    fi
}

# Запуск Xephyr
start_xephyr() {
    echo -e "${GREEN}🖥 Запуск Xephyr на дисплее $XEPHYR_DISPLAY${NC}"
    
    # Убиваем старый Xephyr если есть
    pkill -f "Xephyr $XEPHYR_DISPLAY" 2>/dev/null
    sleep 0.5
    
    # Запускаем Xephyr
    Xephyr $XEPHYR_DISPLAY \
        -screen $XEPHYR_RESOLUTION \
        -resizeable \
        -ac \
        -br \
        -noreset \
        -title "$APP_NAME - Isolated" &
    
    XEPHYR_PID=$!
    
    # Ждем запуска Xephyr
    local count=0
    while [ ! -S "/tmp/.X11-unix/X${XEPHYR_DISPLAY#:}" ] && [ $count -lt 30 ]; do
        sleep 0.1
        count=$((count + 1))
    done
    
    if [ ! -S "/tmp/.X11-unix/X${XEPHYR_DISPLAY#:}" ]; then
        echo -e "${RED}❌ Не удалось запустить Xephyr${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Xephyr запущен (PID: $XEPHYR_PID)${NC}"
}

# Очистка при выходе
cleanup() {
    echo -e "\n${YELLOW}🧹 Очистка...${NC}"
    if [ ! -z "$XEPHYR_PID" ]; then
        kill $XEPHYR_PID 2>/dev/null
    fi
}

# === Основной скрипт ===

echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${GREEN}🎵 Запуск $APP_NAME в изолированной среде${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

# Проверки
check_deps
clean_proxy_vars

# Проверка наличия приложения
if [ ! -d "$APP_DIR" ]; then
    echo -e "${RED}❌ Директория приложения не найдена: $APP_DIR${NC}"
    exit 1
fi

# Проверка исполняемого файла
FULL_APP_EXEC="$APP_DIR$APP_EXEC"
if [ ! -f "$FULL_APP_EXEC" ]; then
    echo -e "${RED}❌ Исполняемый файл не найден: $FULL_APP_EXEC${NC}"
    echo "Содержимое директории:"
    ls -la "$APP_DIR/opt/Яндекс Музыка/" 2>/dev/null | head -10
    exit 1
fi

echo -e "${GREEN}✓ Найден исполняемый файл: $FULL_APP_EXEC${NC}"

# Настройка trap для очистки
trap cleanup EXIT INT TERM

# Настройка курсоров (автоопределение)
XCURSOR_THEME="${XCURSOR_THEME:-}"
# Попытка получить из gsettings (если установлен)
if [[ -z "$XCURSOR_THEME" ]] && command -v gsettings &>/dev/null; then
    XCURSOR_THEME="$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d \"\'\")"
fi

# Замена Adwaita на более совместимую тему
if [[ "$XCURSOR_THEME" = "Adwaita" ]]; then
    XCURSOR_THEME="cutefish-dark"
fi

# Fallback значения
export XCURSOR_THEME="${XCURSOR_THEME:-DMZ-White}"
export XCURSOR_SIZE="${XCURSOR_SIZE:-24}"
export XCURSOR_PATH="${XCURSOR_PATH:-/usr/share/icons:$HOME/.icons:$HOME/.local/share/icons}"

echo -e "${GREEN}🎨 Тема курсора: $XCURSOR_THEME (размер: $XCURSOR_SIZE)${NC}"

# Запуск Xephyr
start_xephyr

# Небольшая пауза для стабилизации
sleep 1

# Применяем настройки курсора в Xephyr
echo -e "${GREEN}⚙ Применение настроек курсора...${NC}"

# Устанавливаем X ресурсы
cat << EOF | DISPLAY="$XEPHYR_DISPLAY" xrdb -merge
Xcursor.theme: $XCURSOR_THEME
Xcursor.size: $XCURSOR_SIZE
Xcursor.theme_core: true
Xft.dpi: 96
EOF

# Устанавливаем курсор по умолчанию
if [[ -d "/usr/share/icons/$XCURSOR_THEME" ]]; then
    DISPLAY="$XEPHYR_DISPLAY" xsetroot -cursor_name left_ptr 2>/dev/null || true
fi

echo -e "${GREEN}🚀 Запуск приложения в изолированном окружении...${NC}"

# Создаем директории для сохранения настроек приложения
APP_CONFIG_DIR="$HOME/.config/bwrap-$APP_NAME"
APP_CACHE_DIR="$HOME/.cache/bwrap-$APP_NAME"
mkdir -p "$APP_CONFIG_DIR" "$APP_CACHE_DIR"

# Запуск приложения в bwrap
bwrap \
    --ro-bind /usr /usr \
    --ro-bind /lib /lib \
    --ro-bind /lib64 /lib64 \
    --ro-bind /bin /bin \
    --ro-bind /sbin /sbin \
    --ro-bind /etc/resolv.conf /etc/resolv.conf \
    --ro-bind /etc/hosts /etc/hosts \
    --ro-bind /etc/localtime /etc/localtime \
    --ro-bind /etc/machine-id /etc/machine-id \
    --ro-bind-try /etc/pulse /etc/pulse \
    --ro-bind-try /etc/alsa /etc/alsa \
    --ro-bind-try /etc/asound.conf /etc/asound.conf \
    --dir /tmp \
    --dir /var \
    --dir /run \
    --dir /run/user \
    --dir /run/user/$UID \
    --bind-try /run/user/$UID/pulse /run/user/$UID/pulse \
    --dir /home/user \
    --setenv XDG_CONFIG_HOME /home/user/.config \
    --bind "$APP_CONFIG_DIR" /home/user/.config \
    --bind "$APP_CACHE_DIR" /home/user/.cache \
    --dir /home/user/.local \
    --bind-try "$HOME/.config/pulse" /home/user/.config/pulse \
    --ro-bind "$APP_DIR" /app \
    --proc /proc \
    --dev /dev \
    --dev-bind /dev/snd /dev/snd \
    --dev-bind-try /dev/dri /dev/dri \
    --ro-bind /sys /sys \
    --tmpfs /dev/shm \
    --ro-bind /tmp/.X11-unix/X${XEPHYR_DISPLAY#:} /tmp/.X11-unix/X${XEPHYR_DISPLAY#:} \
    --setenv HOME /home/user \
    --setenv USER user \
    --setenv DISPLAY "$XEPHYR_DISPLAY" \
    --setenv XDG_RUNTIME_DIR /run/user/$UID \
    --setenv PULSE_SERVER /run/user/$UID/pulse/native \
    --setenv ALSA_CARD "default" \
    --setenv ELECTRON_DISABLE_SANDBOX 1 \
    --setenv ELECTRON_NO_ASAR 1 \
    --setenv NODE_ENV production \
    --setenv GTK_THEME "Adwaita" \
    --setenv QT_X11_NO_MITSHM 1 \
    --unshare-pid \
    --unshare-ipc \
    --share-net \
    --new-session \
    --die-with-parent \
    --setenv XCURSOR_THEME "$XCURSOR_THEME" \
    --setenv XCURSOR_SIZE "$XCURSOR_SIZE" \
    "/app$APP_EXEC" \
        --no-sandbox \
        --disable-gpu-sandbox \
        --disable-setuid-sandbox \
        --disable-dev-shm-usage \
        --disable-features=VizDisplayCompositor \
        --in-process-gpu

EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo -e "${RED}❌ Приложение завершилось с кодом: $EXIT_CODE${NC}"
    
    # Дополнительная диагностика
    echo -e "\n${YELLOW}📊 Диагностика:${NC}"
    echo "• Проверьте звуковые устройства: ls -la /dev/snd/"
    ls -la /dev/snd/ 2>/dev/null
    echo -e "\n• Проверьте PulseAudio: pactl info"
    pactl info 2>/dev/null | head -5
else
    echo -e "${GREEN}✅ Приложение завершено успешно${NC}"
fi

echo -e "${BLUE}═══════════════════════════════════════${NC}"
