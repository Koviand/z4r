# ---- Validation module ----
# Валидация данных и проверки

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

# Проверка существования файла
validate_file_exists() {
    local file="$1"
    local error_msg="${2:-Файл не найден: $file}"
    
    if [ ! -f "$file" ]; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "$error_msg"
        else
            echo -e "${red}[ERROR] $error_msg${plain}" >&2
        fi
        return 1
    fi
    return 0
}

# Проверка существования директории
validate_dir_exists() {
    local dir="$1"
    local error_msg="${2:-Директория не найдена: $dir}"
    
    if [ ! -d "$dir" ]; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "$error_msg"
        else
            echo -e "${red}[ERROR] $error_msg${plain}" >&2
        fi
        return 1
    fi
    return 0
}

# Проверка пути (файл или директория)
validate_path() {
    local path="$1"
    local error_msg="${2:-Путь не существует: $path}"
    
    if [ ! -e "$path" ]; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "$error_msg"
        else
            echo -e "${red}[ERROR] $error_msg${plain}" >&2
        fi
        return 1
    fi
    return 0
}

# Проверка прав на чтение файла
validate_file_readable() {
    local file="$1"
    
    if ! validate_file_exists "$file"; then
        return 1
    fi
    
    if [ ! -r "$file" ]; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "Нет прав на чтение файла: $file"
        else
            echo -e "${red}[ERROR] Нет прав на чтение файла: $file${plain}" >&2
        fi
        return 1
    fi
    return 0
}

# Проверка прав на запись в файл/директорию
validate_file_writable() {
    local path="$1"
    
    # Проверяем существование родительской директории
    local dir=$(dirname "$path")
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" 2>/dev/null || {
            if [ -f "$LIB_PATH/logging.sh" ]; then
                log_error "Не удалось создать директорию: $dir"
            else
                echo -e "${red}[ERROR] Не удалось создать директорию: $dir${plain}" >&2
            fi
            return 1
        }
    fi
    
    # Проверяем права на запись
    if [ ! -w "$dir" ]; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "Нет прав на запись в директорию: $dir"
        else
            echo -e "${red}[ERROR] Нет прав на запись в директорию: $dir${plain}" >&2
        fi
        return 1
    fi
    
    return 0
}

# Валидация версии zapret
validate_version() {
    local version="$1"
    
    if [ -z "$version" ]; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "Версия не указана"
        fi
        return 1
    fi
    
    # Проверка формата версии (например: 72.6, 72.3)
    if ! echo "$version" | grep -Eq '^[0-9]+\.[0-9]+$'; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "Неверный формат версии: $version (ожидается формат: X.Y)"
        else
            echo -e "${red}[ERROR] Неверный формат версии: $version${plain}" >&2
        fi
        return 1
    fi
    
    # Проверка длины версии (максимум 4 символа как в оригинале)
    if [ ${#version} -gt 4 ]; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "Версия слишком длинная: $version (максимум 4 символа)"
        else
            echo -e "${red}[ERROR] Версия слишком длинная: $version${plain}" >&2
        fi
        return 1
    fi
    
    return 0
}

# Валидация URL
validate_url() {
    local url="$1"
    
    if [ -z "$url" ]; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "URL не указан"
        fi
        return 1
    fi
    
    # Простая проверка формата URL
    if ! echo "$url" | grep -Eq '^https?://'; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "Неверный формат URL: $url"
        else
            echo -e "${red}[ERROR] Неверный формат URL: $url${plain}" >&2
        fi
        return 1
    fi
    
    return 0
}

# Валидация домена
validate_domain() {
    local domain="$1"
    
    if [ -z "$domain" ]; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "Домен не указан"
        fi
        return 1
    fi
    
    # Убираем протокол если есть
    domain=$(echo "$domain" | sed -E 's~https?://~~g' | sed 's~/$~~')
    
    # Убираем путь если есть
    domain=$(echo "$domain" | cut -d'/' -f1)
    
    # Простая проверка формата домена
    if ! echo "$domain" | grep -Eq '^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$'; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_warning "Возможно неверный формат домена: $domain"
        fi
        # Не возвращаем ошибку, так как домен может быть валидным, но не соответствовать regex
    fi
    
    return 0
}

# Проверка размера файла
validate_file_size() {
    local file="$1"
    local min_size="${2:-0}"
    local max_size="${3:-0}"  # 0 означает без ограничения
    
    if ! validate_file_exists "$file"; then
        return 1
    fi
    
    local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
    
    if [ "$file_size" -lt "$min_size" ]; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "Файл слишком мал: $file (размер: $file_size, минимум: $min_size)"
        else
            echo -e "${red}[ERROR] Файл слишком мал: $file${plain}" >&2
        fi
        return 1
    fi
    
    if [ "$max_size" -gt 0 ] && [ "$file_size" -gt "$max_size" ]; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "Файл слишком велик: $file (размер: $file_size, максимум: $max_size)"
        else
            echo -e "${red}[ERROR] Файл слишком велик: $file${plain}" >&2
        fi
        return 1
    fi
    
    return 0
}

# Проверка наличия команды
validate_command() {
    local cmd="$1"
    
    if ! command -v "$cmd" >/dev/null 2>&1; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "Команда не найдена: $cmd"
        else
            echo -e "${red}[ERROR] Команда не найдена: $cmd${plain}" >&2
        fi
        return 1
    fi
    
    return 0
}

# Экранирование специальных символов для sed
escape_sed() {
    local str="$1"
    # Экранируем специальные символы sed: /, &, \, $, *, ., ^, [, ]
    echo "$str" | sed 's/[[\.*^$\/&\\]/\\&/g'
}

# Валидация имени пользователя (для использования в конфигах)
validate_username() {
    local username="$1"
    
    if [ -z "$username" ]; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "Имя пользователя пусто"
        fi
        return 1
    fi
    
    # Проверка формата: только буквы, цифры, дефисы, подчеркивания
    if ! echo "$username" | grep -qE '^[a-zA-Z0-9_-]+$'; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "Недопустимое имя пользователя: $username (разрешены только буквы, цифры, дефисы и подчеркивания)"
        else
            echo -e "${red}[ERROR] Недопустимое имя пользователя: $username${plain}" >&2
        fi
        return 1
    fi
    
    # Проверка длины (обычно имена пользователей не превышают 32 символа)
    if [ ${#username} -gt 32 ]; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "Имя пользователя слишком длинное: $username (максимум 32 символа)"
        else
            echo -e "${red}[ERROR] Имя пользователя слишком длинное${plain}" >&2
        fi
        return 1
    fi
    
    return 0
}

# ---- /Validation module ----
