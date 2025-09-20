#!/bin/bash

echo "🧹 Clearing RAM cache..."

# Проверяем, есть ли права на очистку кэша
if [ "$(id -u)" != "0" ]; then
    echo "📝 Need sudo privileges to clear system cache"
    echo "Running with sudo..."
    exec sudo "$0" "$@"
fi

# Показываем текущее использование памяти
echo "📊 Memory usage before clearing:"
free -h

# Синхронизируем файловую систему
echo "💾 Syncing filesystems..."
sync

# Очищаем различные кэши
echo "🗑️  Clearing caches..."

# Page cache
echo 1 > /proc/sys/vm/drop_caches

# Dentries and inodes
echo 2 > /proc/sys/vm/drop_caches

# Page cache, dentries and inodes
echo 3 > /proc/sys/vm/drop_caches

# Очищаем swap если используется
if [ $(swapon -s | wc -l) -gt 1 ]; then
    echo "🔄 Clearing swap..."
    swapoff -a && swapon -a
fi

# Показываем результат
echo ""
echo "✅ RAM cache cleared!"
echo ""
echo "📊 Memory usage after clearing:"
free -h

# Опционально: очистка пользовательских кэшей
if [ "$1" != "--system-only" ]; then
    echo ""
    echo "🏠 Clearing user caches..."
    
    # Переключаемся на пользователя dev для очистки его кэшей
    if [ "$(whoami)" = "root" ]; then
        sudo -u dev bash << 'EOF'
        # Cargo cache (оставляем registry, чистим только target)
        find /home/dev -type d -name target -path "*/projects/*" -exec rm -rf {} + 2>/dev/null || true
        
        # npm cache
        npm cache clean --force 2>/dev/null || true
        
        # Временные файлы
        rm -rf /home/dev/.cache/tmp/* 2>/dev/null || true
        
        echo "✅ User caches cleared"
EOF
    fi
fi

echo ""
echo "🎉 All done!"
