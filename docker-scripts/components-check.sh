#!/bin/bash
# Детальный анализатор компонентов Docker

show_usage() {
    echo "Использование: $0 [КОМАНДА]"
    echo ""
    echo "КОМАНДЫ:"
    echo "  images     - Анализ образов"
    echo "  containers - Анализ контейнеров"
    echo "  volumes    - Анализ volumes"
    echo "  cache      - Анализ build cache"
    echo "  logs       - Анализ логов"
    echo "  networks   - Анализ сетей"
    echo "  all        - Полный анализ"
    echo ""
    echo "Примеры:"
    echo "  $0 images"
    echo "  $0 containers"
    echo "  $0 all"
}

analyze_images() {
    echo "🖼️  ДЕТАЛЬНЫЙ АНАЛИЗ ОБРАЗОВ"
    echo "==========================="
    
    total_images=$(docker images -q | wc -l)
    dangling_images=$(docker images -f "dangling=true" -q | wc -l)
    
    echo "📊 Статистика:"
    echo "Всего образов: $total_images"
    echo "Неиспользуемых (dangling): $dangling_images"
    echo ""
    
    if [ "$total_images" -gt 0 ]; then
        echo "📋 Топ-10 самых больших образов:"
        echo "Repository:Tag                                    Size      Created"
        echo "------------------------------------------------ --------- ----------------"
        docker images --format "{{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | \
            sort -k2 -hr | head -10 | \
            awk '{printf "%-48s %-9s %s\n", $1, $2, $3}'
        
        echo ""
        echo "🏷️  Образы по репозиториям:"
        docker images --format "{{.Repository}}" | sort | uniq -c | sort -nr | head -10 | \
            awk '{printf "%-30s %s образов\n", $2, $1}'
        
        echo ""
        echo "📅 Образы по возрасту:"
        echo "Сегодня: $(docker images --filter "since=$(date -d '1 day ago' +%Y-%m-%d)" -q | wc -l)"
        echo "Эта неделя: $(docker images --filter "since=$(date -d '1 week ago' +%Y-%m-%d)" -q | wc -l)"
        echo "Этот месяц: $(docker images --filter "since=$(date -d '1 month ago' +%Y-%m-%d)" -q | wc -l)"
        
        if [ "$dangling_images" -gt 0 ]; then
            echo ""
            echo "🗑️  Неиспользуемые образы (можно удалить):"
            docker images -f "dangling=true" --format "{{.ID}}\t{{.Size}}\t{{.CreatedAt}}"
            echo ""
            echo "💡 Команда для очистки: docker image prune -f"
        fi
    fi
}

analyze_containers() {
    echo "📦 ДЕТАЛЬНЫЙ АНАЛИЗ КОНТЕЙНЕРОВ"
    echo "=============================="
    
    total_containers=$(docker ps -a -q | wc -l)
    running_containers=$(docker ps -q | wc -l)
    stopped_containers=$((total_containers - running_containers))
    
    echo "📊 Статистика:"
    echo "Всего контейнеров: $total_containers"
    echo "Запущено: $running_containers"
    echo "Остановлено: $stopped_containers"
    echo ""
    
    if [ "$total_containers" -gt 0 ]; then
        echo "📋 Контейнеры с размерами:"
        echo "Name                          Image                    Status         Size"
        echo "----------------------------- ------------------------ -------------- --------"
        docker ps -a --format "{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Size}}" | \
            head -15 | \
            awk '{printf "%-29s %-24s %-14s %s\n", $1, $2, $3, $4}'
        
        echo ""
        echo "🔥 Использование ресурсов (запущенные):"
        if [ "$running_containers" -gt 0 ]; then
            echo "Name                     CPU%    Memory Usage/Limit     Memory%"
            echo "------------------------ ------- ---------------------- -------"
            docker stats --no-stream --format "{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" | \
                head -10 | \
                awk '{printf "%-24s %-7s %-22s %s\n", $1, $2, $3, $4}'
        else
            echo "Нет запущенных контейнеров"
        fi
        
        echo ""
        echo "📁 Анализ файловых систем контейнеров:"
        docker ps --format "{{.Names}}" | head -5 | while read container; do
            echo "--- $container ---"
            docker exec "$container" df -h 2>/dev/null | head -5 || echo "Недоступен"
        done
        
        if [ "$stopped_containers" -gt 0 ]; then
            echo ""
            echo "🗑️  Остановленные контейнеры (можно удалить):"
            docker ps -a -f "status=exited" --format "{{.Names}}\t{{.Image}}\t{{.Status}}" | head -10
            echo ""
            echo "💡 Команда для очистки: docker container prune -f"
        fi
    fi
}

analyze_volumes() {
    echo "💿 ДЕТАЛЬНЫЙ АНАЛИЗ VOLUMES"
    echo "=========================="
    
    total_volumes=$(docker volume ls -q | wc -l)
    
    echo "📊 Статистика:"
    echo "Всего volumes: $total_volumes"
    echo ""
    
    if [ "$total_volumes" -gt 0 ]; then
        echo "📋 Volumes с размерами и использованием:"
        echo "Volume Name                              Size     Used By"
        echo "---------------------------------------- -------- --------------------------------"
        
        docker volume ls --format "{{.Name}}" | while read volume; do
            volume_path="/var/lib/docker/volumes/$volume/_data"
            if [ -d "$volume_path" ]; then
                size=$(sudo du -sh "$volume_path" 2>/dev/null | cut -f1)
                # Найти контейнеры, использующие этот volume
                users=$(docker ps -a --filter "volume=$volume" --format "{{.Names}}" | tr '\n' ',' | sed 's/,$//')
                [ -z "$users" ] && users="не используется"
                printf "%-40s %-8s %s\n" "$volume" "${size:-?}" "$users"
            fi
        done
        
        echo ""
        echo "🗑️  Неиспользуемые volumes:"
        unused_volumes=$(docker volume ls -f dangling=true -q)
        if [ -n "$unused_volumes" ]; then
            echo "$unused_volumes" | while read volume; do
                volume_path="/var/lib/docker/volumes/$volume/_data"
                size=$(sudo du -sh "$volume_path" 2>/dev/null | cut -f1)
                printf "%-40s %s\n" "$volume" "${size:-?}"
            done
            echo ""
            echo "💡 Команда для очистки: docker volume prune -f"
        else
            echo "Все volumes используются"
        fi
    fi
}

analyze_cache() {
    echo "🏗️  ДЕТАЛЬНЫЙ АНАЛИЗ BUILD CACHE"
    echo "==============================="
    
    if command -v docker buildx >/dev/null 2>&1; then
        echo "📊 BuildX Cache статистика:"
        docker builder du 2>/dev/null || {
            echo "BuildX cache недоступен"
            return
        }
        
        echo ""
        echo "📋 Детальная информация о cache:"
        docker builder inspect --bootstrap >/dev/null 2>&1
        
        echo ""
        echo "🗑️  Очистка cache:"
        echo "💡 Команды для очистки:"
        echo "  docker builder prune -f           # Очистить неиспользуемый cache"
        echo "  docker builder prune -a -f        # Очистить весь cache"
        echo "  docker buildx prune -a -f         # Полная очистка BuildX cache"
    else
        echo "❌ BuildX недоступен"
        echo ""
        echo "📊 Стандартный build cache:"
        docker system df | grep -i cache || echo "Информация недоступна"
    fi
}

analyze_logs() {
    echo "📝 ДЕТАЛЬНЫЙ АНАЛИЗ ЛОГОВ"
    echo "========================"
    
    total_containers=$(docker ps -a -q | wc -l)
    
    if [ "$total_containers" -gt 0 ]; then
        echo "📊 Размеры логов контейнеров:"
        echo "Container Name                   Log Size    Log Path"
        echo "-------------------------------- ----------- ----------------------------------------"
        
        docker ps -a --format "{{.Names}}" | while read container; do
            log_path=$(docker inspect "$container" --format='{{.LogPath}}' 2>/dev/null)
            if [ -f "$log_path" ]; then
                log_size=$(du -sh "$log_path" 2>/dev/null | cut -f1)
                printf "%-32s %-11s %s\n" "$container" "${log_size:-0B}" "$log_path"
            fi
        done | sort -k2 -hr | head -10
        
        echo ""
        echo "📈 Общий размер всех логов:"
        total_log_size=$(find /var/lib/docker/containers -name "*.log" -exec du -ch {} + 2>/dev/null | tail -1 | cut -f1)
        echo "Общий размер: ${total_log_size:-неизвестно}"
        
        echo ""
        echo "🗑️  Очистка логов:"
        echo "💡 Команды для очистки:"
        echo "  # Очистить логи всех контейнеров:"
        echo "  sudo truncate -s 0 /var/lib/docker/containers/*/*-json.log"
        echo ""
        echo "  # Очистить логи конкретного контейнера:"
        echo "  docker logs --tail 0 -f CONTAINER_NAME >/dev/null &"
        echo "  docker exec CONTAINER_NAME sh -c 'echo > /proc/1/fd/1'"
    fi
}

analyze_networks() {
    echo "🌐 ДЕТАЛЬНЫЙ АНАЛИЗ СЕТЕЙ"
    echo "========================"
    
    total_networks=$(docker network ls -q | wc -l)
    
    echo "📊 Статистика:"
    echo "Всего сетей: $total_networks"
    echo ""
    
    if [ "$total_networks" -gt 0 ]; then
        echo "📋 Список сетей:"
        echo "Name                     Driver    Scope     Connected Containers"
        echo "------------------------ --------- --------- --------------------"
        
        docker network ls --format "{{.Name}}\t{{.Driver}}\t{{.Scope}}" | while read name driver scope; do
            # Подсчитать подключенные контейнеры
            containers=$(docker network inspect "$name" --format='{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null | wc -w)
            printf "%-24s %-9s %-9s %s\n" "$name" "$driver" "$scope" "$containers"
        done
        
        echo ""
        echo "🔍 Детальная информация о пользовательских сетях:"
        docker network ls --filter type=custom --format "{{.Name}}" | while read network; do
            if [ "$network" != "bridge" ] && [ "$network" != "host" ] && [ "$network" != "none" ]; then
                echo "--- $network ---"
                docker network inspect "$network" --format='Subnet: {{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null
                docker network inspect "$network" --format='Gateway: {{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null
                echo "Контейнеры: $(docker network inspect "$network" --format='{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null)"
                echo ""
            fi
        done
        
        echo "🗑️  Неиспользуемые сети:"
        unused_networks=$(docker network ls --filter type=custom -q | xargs -I {} sh -c 'if [ -z "$(docker network inspect {} --format="{{.Containers}}" 2>/dev/null)" ]; then echo {}; fi' | wc -l)
        echo "Количество: $unused_networks"
        echo ""
        echo "💡 Команда для очистки: docker network prune -f"
    fi
}

# Основная логика
case "${1:-all}" in
    images)
        analyze_images
        ;;
    containers)
        analyze_containers
        ;;
    volumes)
        analyze_volumes
        ;;
    cache)
        analyze_cache
        ;;
    logs)
        analyze_logs
        ;;
    networks)
        analyze_networks
        ;;
    all)
        analyze_images
        echo ""
        analyze_containers
        echo ""
        analyze_volumes
        echo ""
        analyze_cache
        echo ""
        analyze_logs
        echo ""
        analyze_networks
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        echo "❌ Неизвестная команда: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac
