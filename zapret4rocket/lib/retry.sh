# ---- Retry mechanisms module ----
# Механизмы повторных попыток для сетевых операций

# Определяем SCRIPT_DIR если не определен
[ -z "$SCRIPT_DIR" ] && SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# Загружаем логирование если доступно
[ -f "$LIB_PATH/logging.sh" ] && source "$LIB_PATH/logging.sh" 2>/dev/null || true

# curl с повторными попытками
# Параметры: URL, max_retries (по умолчанию 3), timeout (по умолчанию 30), output_file (опционально)
curl_with_retry() {
    local url="$1"
    local max_retries="${2:-3}"
    local timeout="${3:-30}"
    local output_file="${4:-}"
    local retry_count=0
    local exit_code=1
    local delay=1
    
    if [ -z "$url" ]; then
        [ -f "$LIB_PATH/logging.sh" ] && log_error "curl_with_retry: URL не указан" || echo "Ошибка: URL не указан" >&2
        return 1
    fi
    
    while [ "$retry_count" -lt "$max_retries" ]; do
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_debug "Попытка $((retry_count + 1))/$max_retries: загрузка $url"
        fi
        
        # Формируем команду curl как массив для безопасного выполнения
        local curl_cmd=(curl -fsSL --max-time "$timeout")
        
        if [ -n "$output_file" ]; then
            # Загрузка в файл
            if "${curl_cmd[@]}" -o "$output_file" "$url" 2>/dev/null; then
                exit_code=0
                break
            fi
        else
            # Загрузка в stdout
            if "${curl_cmd[@]}" "$url" >/dev/null 2>&1; then
                exit_code=0
                break
            fi
        fi
        
        retry_count=$((retry_count + 1))
        
        if [ "$retry_count" -lt "$max_retries" ]; then
            # Экспоненциальная задержка: 1, 2, 4, 8 секунд...
            sleep "$delay"
            delay=$((delay * 2))
            
            if [ -f "$LIB_PATH/logging.sh" ]; then
                log_warning "Попытка $retry_count не удалась, повтор через $delay сек..."
            fi
        fi
    done
    
    if [ "$exit_code" -eq 0 ]; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_info "Успешно загружено: $url"
        fi
        return 0
    else
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "Не удалось загрузить после $max_retries попыток: $url"
        else
            echo -e "${red}Ошибка: не удалось загрузить $url после $max_retries попыток${plain}" >&2
        fi
        return 1
    fi
}

# curl с retry и сохранением в файл с валидацией
curl_with_retry_and_validate() {
    local url="$1"
    local output_file="$2"
    local min_size="${3:-100}"  # Минимальный размер файла в байтах
    local max_retries="${4:-3}"
    local timeout="${5:-30}"
    
    if [ -z "$url" ] || [ -z "$output_file" ]; then
        [ -f "$LIB_PATH/logging.sh" ] && log_error "curl_with_retry_and_validate: не указаны URL или файл вывода" || true
        return 1
    fi
    
    # Создаем директорию для файла если нужно
    local dir=$(dirname "$output_file")
    [ -n "$dir" ] && mkdir -p "$dir" 2>/dev/null || true
    
    # Загружаем с retry
    if curl_with_retry "$url" "$max_retries" "$timeout" "$output_file"; then
        # Валидация размера файла
        if [ -f "$output_file" ]; then
            local file_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo 0)
            if [ "$file_size" -lt "$min_size" ]; then
                [ -f "$LIB_PATH/logging.sh" ] && log_error "Файл слишком мал: $output_file (размер: $file_size, ожидается минимум: $min_size)" || true
                rm -f "$output_file" 2>/dev/null || true
                return 1
            fi
            
            if [ -f "$LIB_PATH/logging.sh" ]; then
                log_debug "Файл валиден: $output_file (размер: $file_size байт)"
            fi
            return 0
        else
            [ -f "$LIB_PATH/logging.sh" ] && log_error "Файл не был создан: $output_file" || true
            return 1
        fi
    else
        return 1
    fi
}

# Загрузка нескольких файлов параллельно с retry
curl_parallel_with_retry() {
    local urls_file="$1"  # Файл со списком URL (по одному на строку)
    local output_dir="$2"
    local max_retries="${3:-3}"
    local timeout="${4:-30}"
    local max_parallel="${5:-5}"  # Максимум параллельных загрузок
    
    if [ ! -f "$urls_file" ]; then
        [ -f "$LIB_PATH/logging.sh" ] && log_error "curl_parallel_with_retry: файл со списком URL не найден: $urls_file" || true
        return 1
    fi
    
    mkdir -p "$output_dir" 2>/dev/null || true
    
    local pids=()
    local count=0
    
    while IFS= read -r url || [ -n "$url" ]; do
        # Пропускаем пустые строки
        [ -z "$url" ] && continue
        
        # Ждем если достигнут лимит параллельных загрузок
        while [ ${#pids[@]} -ge "$max_parallel" ]; do
            # Правильное удаление завершившихся процессов из массива
            local new_pids=()
            for pid in "${pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    # Процесс еще работает, оставляем в списке
                    new_pids+=("$pid")
                fi
                # Завершившиеся процессы просто не добавляются в new_pids
            done
            pids=("${new_pids[@]}")
            
            # Если все процессы завершились, выходим из цикла ожидания
            if [ ${#pids[@]} -lt "$max_parallel" ]; then
                break
            fi
            sleep 0.5
        done
        
        # Извлекаем имя файла из URL
        local filename=$(basename "$url" | sed 's/[?&].*//')
        [ -z "$filename" ] && filename="file_$count"
        local output_file="$output_dir/$filename"
        
        # Запускаем загрузку в фоне
        (
            curl_with_retry_and_validate "$url" "$output_file" 100 "$max_retries" "$timeout"
        ) &
        
        pids+=($!)
        count=$((count + 1))
    done < "$urls_file"
    
    # Ждем завершения всех процессов
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done
    
    if [ -f "$LIB_PATH/logging.sh" ]; then
        log_info "Параллельная загрузка завершена: обработано $count файлов"
    fi
}

# ---- /Retry mechanisms module ----
