# ---- Logging wrapper module ----
# Обертка для оптимизации проверок существования модуля логирования

# Определяем SCRIPT_DIR если не определен
[ -z "$SCRIPT_DIR" ] && SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# Определяем путь к библиотекам
if [ -z "$LIB_PATH" ]; then
  if [ -d "$SCRIPT_DIR/lib" ]; then
    LIB_PATH="$SCRIPT_DIR/lib"
  else
    LIB_PATH="$SCRIPT_DIR/zapret/z4r_lib"
  fi
fi

# Кэшируем результат проверки наличия модуля логирования
_LOGGING_AVAILABLE=""
_check_logging_available() {
    if [ -z "$_LOGGING_AVAILABLE" ]; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            _LOGGING_AVAILABLE="1"
        else
            _LOGGING_AVAILABLE="0"
        fi
    fi
    [ "$_LOGGING_AVAILABLE" = "1" ]
}

# Оптимизированные функции логирования (проверка выполняется один раз)
log_info_safe() {
    if _check_logging_available; then
        log_info "$@"
    else
        echo -e "${blue}[INFO]${plain} $*" >&2
    fi
}

log_error_safe() {
    if _check_logging_available; then
        log_error "$@"
    else
        echo -e "${red}[ERROR]${plain} $*" >&2
    fi
}

log_warning_safe() {
    if _check_logging_available; then
        log_warning "$@"
    else
        echo -e "${yellow}[WARNING]${plain} $*" >&2
    fi
}

log_debug_safe() {
    if _check_logging_available; then
        log_debug "$@"
    fi
    # Debug не выводится в консоль если логирование недоступно
}

# ---- /Logging wrapper module ----
