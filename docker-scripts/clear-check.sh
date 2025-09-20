#!/bin/bash
# Комплексный мониторинг размеров Docker

echo "📊 АНАЛИЗ РАЗМЕРОВ DOCKER"
echo "========================="

# Функция для конвертации размеров в читаемый формат
human_readable() {
    local size=$1
    if [ "$size" -ge 1073741824 ]; then
        echo "$(echo "scale=2; $size/1073741824" | bc)GB"
    elif [ "$size" -ge 1048576 ]; then
        echo "$(echo "scale=2; $size/1048576" | bc)MB"
    elif [ "$size" -ge 1024 ]; then
        echo "$(echo "scale=2; $size/1024" | bc)KB"
    else
        echo "${size}B"
    fi
}

# Проверяем доступность Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker не найден"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "❌ Docker не запущен или нет прав доступа"
    exit 1
fi

echo "🔍 Системная информация Docker:"
echo "================================"
docker version --format "Версия: {{.Server.Version}}"
echo "Корневая директория: $(docker info --format '{{.DockerRootDir}}')"

# Общее использование места
echo ""
echo "📈 ОБЩЕЕ ИСПОЛЬЗОВАНИЕ МЕСТА"
echo "============================"
docker system df
echo ""
docker system df -v | head -20

# Детальный анализ директории Docker
echo ""
echo "💾 РАЗМЕР ДИРЕКТОРИИ DOCKER"
echo "==========================="
docker_root=$(docker info --format '{{.DockerRootDir}}')
if [ -d "$docker_root" ]; then
    echo "Анализируем: $docker_root"
    sudo du -sh "$docker_root" 2>/dev/null || echo "Нет прав для анализа"
    echo ""
    echo "Подкаталоги:"
    sudo du -sh "$docker_root"/* 2>/dev/null | sort -hr | head -10 || echo "Нет прав для детального анализа"
else
    echo "Директория $docker_root не найдена"
fi

# Анализ образов
echo ""
echo "🖼️  АНАЛИЗ ОБРАЗОВ"
echo "=================="
image_count=$(docker images -q | wc -l)
echo "Всего образов: $image_count"

if [ "$image_count" -gt 0 ]; then
    echo ""
    echo "📋 Топ-10 самых больших образов:"
    echo "Repository:Tag                          Size"
    echo "---------------------------------------- --------"
    docker images --format "{{.Repository}}:{{.Tag}}\t{{.Size}}" | \
        sort -k2 -hr | head -10 | \
        awk '{printf "%-40s %s\n", $1, $2}'
    
    echo ""
    echo "🏷️  Образы без тегов (dangling):"
    dangling_count=$(docker images -f "dangling=true" -q | wc -l)
    echo "Количество: $dangling_count"
    if [ "$dangling_count" -gt 0 ]; then
        docker images -f "dangling=true" --format "{{.ID}}\t{{.Size}}"
    fi
fi

# Анализ контейнеров
echo ""
echo "📦 АНАЛИЗ КОНТЕЙНЕРОВ"
echo "===================="
container_count=$(docker ps -a -q | wc -l)
running_count=$(docker ps -q | wc -l)
stopped_count=$((container_count - running_count))

echo "Всего контейнеров: $container_count"
echo "Запущенных: $running_count"
echo "Остановленных: $stopped_count"

if [ "$container_count" -gt 0 ]; then
    echo ""
    echo "📋 Контейнеры с размерами:"
    echo "Name                     Image                    Status    Size     VirtSize"
    echo "------------------------ ------------------------ --------- -------- --------"
    docker ps -a --format "{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Size}}" | \
        head -15 | \
        awk '{printf "%-24s %-24s %-9s %s\n", $1, $2, $3, $4}'
    
    if [ "$container_count" -gt 15 ]; then
        echo "... и ещё $((container_count - 15)) контейнеров"
    fi
    
    echo ""
    echo "🔍 Самые большие контейнеры:"
    docker ps -a -s --format "{{.Names}}\t{{.Size}}" | \
        sort -k2 -hr | head -5 | \
        awk '{printf "%-30s %s\n", $1, $2}'
fi

# Анализ volumes
echo ""
echo "💿 АНАЛИЗ VOLUMES"
echo "================="
volume_count=$(docker volume ls -q | wc -l)
echo "Всего volumes: $volume_count"

if [ "$volume_count" -gt 0 ]; then
    echo ""
    echo "📋 Volumes с размерами:"
    echo "Volume Name                      Size"
    echo "-------------------------------- --------"
    
    docker volume ls --format "{{.Name}}" | while read volume; do
        volume_path="/var/lib/docker/volumes/$volume/_data"
        if [ -d "$volume_path" ]; then
            size=$(sudo du -sh "$volume_path" 2>/dev/null | cut -f1)
            printf "%-32s %s\n" "$volume" "${size:-неизвестно}"
        fi
    done | head -10
    
    echo ""
    echo "🗑️  Неиспользуемые volumes:"
    unused_volumes=$(docker volume ls -f dangling=true -q | wc -l)
    echo "Количество: $unused_volumes"
fi

# Анализ сетей
echo ""
echo "🌐 АНАЛИЗ СЕТЕЙ"
echo "==============="
network_count=$(docker network ls -q | wc -l)
echo "Всего сетей: $network_count"

if [ "$network_count" -gt 0 ]; then
    echo ""
    echo "📋 Список сетей:"
    docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
fi

# Анализ кэша сборки
echo ""
echo "🏗️  АНАЛИЗ BUILD CACHE"
echo "======================"
if command -v docker &> /dev/null && docker buildx version &> /dev/null; then
    echo "BuildKit cache:"
    docker system df --format "table {{.Type}}\t{{.Total}}\t{{.Active}}\t{{.Size}}\t{{.Reclaimable}}" | grep -i cache
    
    echo ""
    echo "Детальная информация о cache:"
    docker builder du 2>/dev/null || echo "BuildKit cache недоступен"
else
    echo "BuildKit недоступен"
fi

# Анализ логов
echo ""
echo "📝 АНАЛИЗ ЛОГОВ КОНТЕЙНЕРОВ"
echo "==========================="
if [ "$container_count" -gt 0 ]; then
    echo "Размеры логов топ-5 контейнеров:"
    docker ps -a --format "{{.Names}}" | head -5 | while read container; do
        log_file=$(docker inspect "$container" --format='{{.LogPath}}' 2>/dev/null)
        if [ -f "$log_file" ]; then
            log_size=$(du -sh "$log_file" 2>/dev/null | cut -f1)
            printf "%-30s %s\n" "$container" "${log_size:-0B}"
        fi
    done
fi

# Рекомендации по очистке
echo ""
echo "🧹 РЕКОМЕНДАЦИИ ПО ОЧИСТКЕ"
echo "=========================="

total_reclaimable=$(docker system df --format "{{.Reclaimable}}" | tail -n +2 | sed 's/[^0-9.]//g' | awk '{sum+=$1} END {print sum}')

if [ "$dangling_count" -gt 0 ]; then
    echo "• Удалить неиспользуемые образы: docker image prune -f"
fi

if [ "$stopped_count" -gt 0 ]; then
    echo "• Удалить остановленные контейнеры: docker container prune -f"
fi

if [ "$unused_volumes" -gt 0 ]; then
    echo "• Удалить неиспользуемые volumes: docker volume prune -f"
fi

echo "• Полная очистка неиспользуемых данных: docker system prune -a -f --volumes"

echo ""
echo "💾 ИТОГОВАЯ СТАТИСТИКА"
echo "======================"
echo "Всего образов: $image_count"
echo "Всего контейнеров: $container_count (запущено: $running_count)"
echo "Всего volumes: $volume_count"
echo "Всего сетей: $network_count"

# Подсчет общего места на диске
if [ -d "$docker_root" ]; then
    total_size=$(sudo du -sb "$docker_root" 2>/dev/null | cut -f1)
    if [ -n "$total_size" ]; then
        echo "Общий размер Docker: $(human_readable $total_size)"
    fi
fi

echo ""
echo "🔄 Обновлено: $(date)"
echo "============================================"
