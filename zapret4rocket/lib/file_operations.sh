# ---- File operations module ----
# Улучшенная работа с файлами: блокировки, атомарные операции

# Определяем SCRIPT_DIR если не определен
[ -z "$SCRIPT_DIR" ] && SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# Определяем путь к библиотекам
if [ -z "$LIB_PATH" ]; then
  if [ -d "$LIB_PATH" ]; then
    LIB_PATH="$LIB_PATH"
  else
    LIB_PATH="$SCRIPT_DIR/zapret/z4r_lib"
  fi
fi

# Загружаем логирование если доступно
[ -f "$LIB_PATH/logging.sh" ] && source "$LIB_PATH/logging.sh" 2>/dev/null || true

# Директория для lock файлов
LOCK_DIR="/tmp/z4r_locks"
mkdir -p "$LOCK_DIR" 2>/dev/null || true

# Получение блокировки для файла
acquire_lock() {
    local lock_file="$LOCK_DIR/$(echo "$1" | tr '/' '_' | tr ' ' '_').lock"
    local timeout="${2:-30}"  # Таймаут в секундах
    local elapsed=0
    
    while [ "$elapsed" -lt "$timeout" ]; do
        if (set -C; echo $$ > "$lock_file") 2>/dev/null; then
            # Блокировка получена
            echo "$lock_file"
            if [ -f "$LIB_PATH/logging.sh" ]; then
                log_debug "Блокировка получена: $lock_file"
            fi
            return 0
        fi
        
        # Проверяем, не завис ли процесс-владелец блокировки
        if [ -f "$lock_file" ]; then
            local lock_pid=$(cat "$lock_file" 2>/dev/null)
            if [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; then
                # Процесс не существует, удаляем старую блокировку
                rm -f "$lock_file" 2>/dev/null || true
                if [ -f "$LIB_PATH/logging.sh" ]; then
                    log_debug "Удалена зависшая блокировка: $lock_file"
                fi
                continue
            fi
        fi
        
        sleep 1
        elapsed=$((elapsed + 1))
    done
    
    if [ -f "$LIB_PATH/logging.sh" ]; then
        log_error "Не удалось получить блокировку для: $1 (таймаут: $timeout сек)"
    else
        echo -e "${red}[ERROR] Не удалось получить блокировку для: $1${plain}" >&2
    fi
    return 1
}

# Освобождение блокировки
release_lock() {
    local lock_file="$1"
    if [ -f "$lock_file" ]; then
        rm -f "$lock_file" 2>/dev/null || true
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_debug "Блокировка освобождена: $lock_file"
        fi
    fi
}

# Атомарная запись в файл через временный файл
atomic_write() {
    local target_file="$1"
    local content="$2"
    local lock_file=""
    
    # Получаем блокировку
    lock_file=$(acquire_lock "$target_file" 10)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Создаем временный файл
    local temp_file="${target_file}.tmp.$$"
    echo "$content" > "$temp_file" 2>/dev/null || {
        release_lock "$lock_file"
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "Не удалось записать во временный файл: $temp_file"
        fi
        return 1
    }
    
    # Атомарное перемещение
    mv -f "$temp_file" "$target_file" 2>/dev/null || {
        release_lock "$lock_file"
        rm -f "$temp_file" 2>/dev/null || true
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "Не удалось переместить временный файл: $temp_file -> $target_file"
        fi
        return 1
    }
    
    # Освобождаем блокировку
    release_lock "$lock_file"
    
    if [ -f "$LIB_PATH/logging.sh" ]; then
        log_debug "Атомарная запись выполнена: $target_file"
    fi
    return 0
}

# Атомарное копирование файла
atomic_copy() {
    local source_file="$1"
    local target_file="$2"
    local lock_file=""
    
    if [ ! -f "$source_file" ]; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "Исходный файл не найден: $source_file"
        fi
        return 1
    fi
    
    # Получаем блокировку для целевого файла
    lock_file=$(acquire_lock "$target_file" 10)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Создаем временный файл
    local temp_file="${target_file}.tmp.$$"
    cp -f "$source_file" "$temp_file" 2>/dev/null || {
        release_lock "$lock_file"
        rm -f "$temp_file" 2>/dev/null || true
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "Не удалось скопировать во временный файл: $temp_file"
        fi
        return 1
    }
    
    # Атомарное перемещение
    mv -f "$temp_file" "$target_file" 2>/dev/null || {
        release_lock "$lock_file"
        rm -f "$temp_file" 2>/dev/null || true
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "Не удалось переместить временный файл: $temp_file -> $target_file"
        fi
        return 1
    }
    
    # Освобождаем блокировку
    release_lock "$lock_file"
    
    if [ -f "$LIB_PATH/logging.sh" ]; then
        log_debug "Атомарное копирование выполнено: $source_file -> $target_file"
    fi
    return 0
}

# Безопасное добавление строки в файл
safe_append() {
    local target_file="$1"
    local content="$2"
    local lock_file=""
    
    # Получаем блокировку
    lock_file=$(acquire_lock "$target_file" 10)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Добавляем строку
    echo "$content" >> "$target_file" 2>/dev/null || {
        release_lock "$lock_file"
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "Не удалось добавить строку в файл: $target_file"
        fi
        return 1
    }
    
    # Освобождаем блокировку
    release_lock "$lock_file"
    
    return 0
}

# Проверка целостности файла (базовая проверка)
check_file_integrity() {
    local file="$1"
    local min_size="${2:-0}"
    
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    # Проверка размера
    if [ "$min_size" -gt 0 ]; then
        local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
        if [ "$file_size" -lt "$min_size" ]; then
            if [ -f "$LIB_PATH/logging.sh" ]; then
                log_warning "Файл слишком мал для проверки целостности: $file (размер: $file_size)"
            fi
            return 1
        fi
    fi
    
    # Проверка прав доступа
    if [ ! -r "$file" ]; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_warning "Нет прав на чтение файла: $file"
        fi
        return 1
    fi
    
    return 0
}

# Очистка старых lock файлов
cleanup_old_locks() {
    local max_age="${1:-3600}"  # Максимальный возраст в секундах (по умолчанию 1 час)
    
    if [ ! -d "$LOCK_DIR" ]; then
        return 0
    fi
    
    find "$LOCK_DIR" -name "*.lock" -type f -mtime +$((max_age / 86400)) 2>/dev/null | while read -r lock_file; do
        # Проверяем, не активен ли процесс
        local lock_pid=$(cat "$lock_file" 2>/dev/null)
        if [ -z "$lock_pid" ] || ! kill -0 "$lock_pid" 2>/dev/null; then
            rm -f "$lock_file" 2>/dev/null || true
            if [ -f "$LIB_PATH/logging.sh" ]; then
                log_debug "Удален старый lock файл: $lock_file"
            fi
        fi
    done
}

# Инициализация: очистка старых блокировок при старте
cleanup_old_locks 3600

# ---- /File operations module ----
