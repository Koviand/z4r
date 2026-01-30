# ---- Error handling module ----
# Система обработки ошибок для z4r

# Определяем SCRIPT_DIR если не определен
[ -z "$SCRIPT_DIR" ] && SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# Загружаем логирование если доступно
[ -f "$LIB_PATH/logging.sh" ] && source "$LIB_PATH/logging.sh" 2>/dev/null || true

# Список временных файлов для очистки
TEMP_FILES=()
TEMP_DIRS=()

# Флаг критической ошибки
CRITICAL_ERROR=0

# Регистрация временного файла для автоматической очистки
register_temp_file() {
    TEMP_FILES+=("$1")
}

# Регистрация временной директории для автоматической очистки
register_temp_dir() {
    TEMP_DIRS+=("$1")
}

# Очистка временных файлов и директорий
cleanup_temp_files() {
    local file
    for file in "${TEMP_FILES[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file" 2>/dev/null || true
            [ -f "$LIB_PATH/logging.sh" ] && log_debug "Удален временный файл: $file" || true
        fi
    done
    
    local dir
    for dir in "${TEMP_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            rm -rf "$dir" 2>/dev/null || true
            [ -f "$LIB_PATH/logging.sh" ] && log_debug "Удалена временная директория: $dir" || true
        fi
    done
    
    TEMP_FILES=()
    TEMP_DIRS=()
}

# Обработчик ошибок
error_handler() {
    local exit_code="${1:-$?}"
    local line_number="${2:-$LINENO}"
    local command="${3:-$BASH_COMMAND}"
    
    # Пропускаем ошибки в условиях (if, while и т.д.)
    if [ "$exit_code" -eq 0 ]; then
        return 0
    fi
    
    # Логируем ошибку
    if [ -f "$LIB_PATH/logging.sh" ]; then
        log_error_with_context "${FUNCNAME[1]:-main}" "$line_number" "Ошибка выполнения команды: $command (код выхода: $exit_code)"
    else
        echo -e "${red}[ERROR] Ошибка в строке $line_number: $command (код: $exit_code)${plain}" >&2
    fi
    
    # Очистка временных файлов
    cleanup_temp_files
    
    # Если критическая ошибка - выходим
    if [ "$CRITICAL_ERROR" -eq 1 ]; then
        exit "$exit_code"
    fi
    
    return "$exit_code"
}

# Установка обработчика ошибок
setup_error_handler() {
    # Trap для ошибок (ERR)
    trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR
    
    # Trap для выхода (EXIT) - очистка временных файлов
    trap 'cleanup_temp_files' EXIT
    
    # Trap для прерывания (INT, TERM)
    trap 'echo -e "\n${yellow}Прервано пользователем${plain}"; cleanup_temp_files; exit 130' INT TERM
}

# Безопасное выполнение команды с обработкой ошибок
# Принимает команду и аргументы как отдельные параметры
safe_exec() {
    if [ $# -eq 0 ]; then
        [ -f "$LIB_PATH/logging.sh" ] && log_error "safe_exec: не указана команда" || true
        return 1
    fi
    
    local cmd="$1"
    shift
    local args=("$@")
    local exit_code=0
    
    # Формируем строку команды для логирования
    local command_str="$cmd"
    for arg in "${args[@]}"; do
        command_str="$command_str '${arg//\'/\'\\\'\'}'"
    done
    
    if [ -f "$LIB_PATH/logging.sh" ]; then
        log_command "$command_str"
    fi
    
    # Временно отключаем set -e если он установлен
    set +e
    # Безопасное выполнение через массив аргументов
    "$cmd" "${args[@]}"
    exit_code=$?
    set -e
    
    if [ -f "$LIB_PATH/logging.sh" ]; then
        log_command_result "$exit_code" "$command_str"
    fi
    
    if [ "$exit_code" -ne 0 ]; then
        error_handler "$exit_code" "$LINENO" "$command_str"
    fi
    
    return "$exit_code"
}

# Альтернативная функция для выполнения строки команды (менее безопасная, но иногда необходима)
# ВНИМАНИЕ: Используйте только для доверенных команд!
safe_exec_string() {
    local command="$1"
    local exit_code=0
    
    # Базовая проверка на опасные паттерны
    if echo "$command" | grep -qE '[;&|`\$\(]'; then
        [ -f "$LIB_PATH/logging.sh" ] && log_error "safe_exec_string: обнаружены потенциально опасные символы в команде" || true
        return 1
    fi
    
    if [ -f "$LIB_PATH/logging.sh" ]; then
        log_command "$command"
    fi
    
    set +e
    # Выполняем через bash -c с явным указанием интерпретатора
    /bin/bash -c "$command"
    exit_code=$?
    set -e
    
    if [ -f "$LIB_PATH/logging.sh" ]; then
        log_command_result "$exit_code" "$command"
    fi
    
    if [ "$exit_code" -ne 0 ]; then
        error_handler "$exit_code" "$LINENO" "$command"
    fi
    
    return "$exit_code"
}

# Проверка успешности выполнения команды
check_success() {
    local exit_code="$?"
    local message="${1:-Команда завершилась с ошибкой}"
    
    if [ "$exit_code" -ne 0 ]; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "$message (код выхода: $exit_code)"
        else
            echo -e "${red}[ERROR] $message (код выхода: $exit_code)${plain}" >&2
        fi
        return "$exit_code"
    fi
    return 0
}

# Установка критической ошибки
set_critical_error() {
    CRITICAL_ERROR=1
    if [ -f "$LIB_PATH/logging.sh" ]; then
        log_error "Критическая ошибка установлена"
    fi
}

# Сброс критической ошибки
reset_critical_error() {
    CRITICAL_ERROR=0
}

# ---- /Error handling module ----
