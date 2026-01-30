# ---- Logging module ----
# Система логирования для z4r

# Настройки логирования
LOG_DIR="/opt/zapret/logs"
LOG_FILE="$LOG_DIR/z4r.log"
LOG_MAX_SIZE=10485760  # 10MB
LOG_MAX_FILES=5
LOG_LEVEL="${Z4R_LOG_LEVEL:-INFO}"  # DEBUG, INFO, WARNING, ERROR

# Уровни логирования (числовые для сравнения)
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARNING=2
LOG_LEVEL_ERROR=3

# Инициализация системы логирования
init_logging() {
    mkdir -p "$LOG_DIR"
    
    # Определяем числовой уровень логирования
    case "$LOG_LEVEL" in
        DEBUG)   CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
        INFO)    CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO ;;
        WARNING) CURRENT_LOG_LEVEL=$LOG_LEVEL_WARNING ;;
        ERROR)   CURRENT_LOG_LEVEL=$LOG_LEVEL_ERROR ;;
        *)       CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO ;;
    esac
    
    # Ротация логов при необходимости
    rotate_logs_if_needed
}

# Ротация логов
rotate_logs_if_needed() {
    if [ -f "$LOG_FILE" ]; then
        local file_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        if [ "$file_size" -gt "$LOG_MAX_SIZE" ]; then
    # Ротация: удаляем самый старый, сдвигаем остальные
    local i
    for i in $(seq $((LOG_MAX_FILES - 1)) -1 1); do
        if [ -f "${LOG_FILE}.$i" ]; then
            mv "${LOG_FILE}.$i" "${LOG_FILE}.$((i + 1))" 2>/dev/null || true
        fi
    done
    mv "$LOG_FILE" "${LOG_FILE}.1" 2>/dev/null || true
        fi
    fi
}

# Внутренняя функция записи в лог
_log_write() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Проверяем уровень логирования
    local level_num
    case "$level" in
        DEBUG)   level_num=$LOG_LEVEL_DEBUG ;;
        INFO)    level_num=$LOG_LEVEL_INFO ;;
        WARNING) level_num=$LOG_LEVEL_WARNING ;;
        ERROR)   level_num=$LOG_LEVEL_ERROR ;;
        *)       level_num=$LOG_LEVEL_INFO ;;
    esac
    
    if [ "$level_num" -ge "$CURRENT_LOG_LEVEL" ]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# Функции логирования
log_debug() {
    _log_write "DEBUG" "$*"
}

log_info() {
    _log_write "INFO" "$*"
    echo -e "${blue}[INFO]${plain} $*" >&2
}

log_warning() {
    _log_write "WARNING" "$*"
    echo -e "${yellow}[WARNING]${plain} $*" >&2
}

log_error() {
    _log_write "ERROR" "$*"
    echo -e "${red}[ERROR]${plain} $*" >&2
}

# Логирование с контекстом (функция, строка)
log_error_with_context() {
    local func="$1"
    local line="$2"
    local message="$3"
    log_error "[$func:$line] $message"
}

# Логирование команды перед выполнением
log_command() {
    if [ "$CURRENT_LOG_LEVEL" -le "$LOG_LEVEL_DEBUG" ]; then
        log_debug "Выполнение команды: $*"
    fi
}

# Логирование результата команды
log_command_result() {
    local exit_code="$1"
    local command="$2"
    if [ "$exit_code" -eq 0 ]; then
        log_debug "Команда успешна: $command"
    else
        log_error "Команда завершилась с ошибкой (код $exit_code): $command"
    fi
}

# Инициализация при загрузке модуля
init_logging

# ---- /Logging module ----
