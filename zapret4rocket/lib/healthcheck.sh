# ---- Health check module ----
# Проверка состояния системы и сервисов

# Определяем SCRIPT_DIR если не определен
[ -z "$SCRIPT_DIR" ] && SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# Загружаем логирование если доступно
[ -f "$LIB_PATH/logging.sh" ] && source "$LIB_PATH/logging.sh" 2>/dev/null || true
[ -f "$LIB_PATH/validation.sh" ] && source "$LIB_PATH/validation.sh" 2>/dev/null || true

# Проверка состояния zapret
check_zapret_status() {
    if command -v pidof >/dev/null 2>&1; then
        if pidof nfqws >/dev/null 2>&1; then
            if [ -f "$LIB_PATH/logging.sh" ]; then
                log_debug "Zapret запущен (PID: $(pidof nfqws))"
            fi
            return 0
        else
            if [ -f "$LIB_PATH/logging.sh" ]; then
                log_warning "Zapret не запущен"
            fi
            return 1
        fi
    else
        # Альтернативная проверка через ps
        if ps aux 2>/dev/null | grep -q "[n]fqws"; then
            if [ -f "$LIB_PATH/logging.sh" ]; then
                log_debug "Zapret запущен (проверка через ps)"
            fi
            return 0
        else
            if [ -f "$LIB_PATH/logging.sh" ]; then
                log_warning "Zapret не запущен"
            fi
            return 1
        fi
    fi
}

# Проверка доступности необходимых сервисов
check_services() {
    local services=("github.com" "raw.githubusercontent.com")
    local all_ok=0
    
    for service in "${services[@]}"; do
        if curl -s --max-time 5 "https://$service" >/dev/null 2>&1; then
            if [ -f "$LIB_PATH/logging.sh" ]; then
                log_debug "Сервис доступен: $service"
            fi
        else
            all_ok=1
            if [ -f "$LIB_PATH/logging.sh" ]; then
                log_warning "Сервис недоступен: $service"
            else
                echo -e "${yellow}[WARNING] Сервис недоступен: $service${plain}" >&2
            fi
        fi
    done
    
    return "$all_ok"
}

# Проверка дискового пространства
check_disk_space() {
    local path="${1:-/opt}"
    local min_free_mb="${2:-100}"  # Минимум 100MB свободного места
    
    if ! validate_path "$path"; then
        return 1
    fi
    
    # Получаем свободное место в MB
    local free_space=0
    if command -v df >/dev/null 2>&1; then
        free_space=$(df -m "$path" 2>/dev/null | tail -n1 | awk '{print $4}')
    fi
    
    if [ -z "$free_space" ] || [ "$free_space" -lt "$min_free_mb" ]; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "Недостаточно дискового пространства: $path (свободно: ${free_space}MB, требуется: ${min_free_mb}MB)"
        else
            echo -e "${red}[ERROR] Недостаточно дискового пространства: $path${plain}" >&2
        fi
        return 1
    fi
    
    if [ -f "$LIB_PATH/logging.sh" ]; then
        log_debug "Достаточно дискового пространства: $path (свободно: ${free_space}MB)"
    fi
    return 0
}

# Проверка памяти
check_memory() {
    local min_free_mb="${1:-50}"  # Минимум 50MB свободной памяти
    
    local free_mem=0
    if [ -f /proc/meminfo ]; then
        free_mem=$(grep "^MemAvailable:" /proc/meminfo 2>/dev/null | awk '{print $2}' | awk '{print int($1/1024)}')
    fi
    
    if [ -z "$free_mem" ] || [ "$free_mem" -lt "$min_free_mb" ]; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_warning "Мало свободной памяти (свободно: ${free_mem}MB, рекомендуется: ${min_free_mb}MB)"
        else
            echo -e "${yellow}[WARNING] Мало свободной памяти${plain}" >&2
        fi
        return 1
    fi
    
    if [ -f "$LIB_PATH/logging.sh" ]; then
        log_debug "Достаточно свободной памяти: ${free_mem}MB"
    fi
    return 0
}

# Проверка конфигурационного файла zapret
check_zapret_config() {
    local config_file="/opt/zapret/config"
    
    if ! validate_file_exists "$config_file" "Конфигурационный файл zapret не найден"; then
        return 1
    fi
    
    if ! validate_file_readable "$config_file"; then
        return 1
    fi
    
    # Проверка основных параметров в конфиге
    if ! grep -q "^FWTYPE=" "$config_file"; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_warning "В конфиге отсутствует параметр FWTYPE"
        fi
    fi
    
    if [ -f "$LIB_PATH/logging.sh" ]; then
        log_debug "Конфигурационный файл zapret валиден"
    fi
    return 0
}

# Комплексная проверка здоровья системы
health_check_all() {
    local errors=0
    
    if [ -f "$LIB_PATH/logging.sh" ]; then
        log_info "Выполнение комплексной проверки здоровья системы..."
    else
        echo -e "${blue}Проверка здоровья системы...${plain}"
    fi
    
    # Проверка zapret
    if ! check_zapret_status; then
        errors=$((errors + 1))
    fi
    
    # Проверка дискового пространства
    if ! check_disk_space "/opt" 100; then
        errors=$((errors + 1))
    fi
    
    # Проверка памяти
    if ! check_memory 50; then
        errors=$((errors + 1))
    fi
    
    # Проверка конфига
    if [ -f "/opt/zapret/config" ]; then
        if ! check_zapret_config; then
            errors=$((errors + 1))
        fi
    fi
    
    # Проверка сервисов (не критично, только предупреждение)
    check_services || true
    
    if [ "$errors" -eq 0 ]; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_info "Все проверки здоровья пройдены успешно"
        else
            echo -e "${green}Все проверки здоровья пройдены успешно${plain}"
        fi
        return 0
    else
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_warning "Обнаружено $errors проблем при проверке здоровья"
        else
            echo -e "${yellow}[WARNING] Обнаружено $errors проблем при проверке здоровья${plain}" >&2
        fi
        return 1
    fi
}

# Проверка перед критичными операциями
pre_critical_operation_check() {
    # Проверка дискового пространства
    if ! check_disk_space "/opt" 200; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "Недостаточно места для критичной операции"
        fi
        return 1
    fi
    
    # Проверка памяти
    if ! check_memory 100; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_warning "Мало памяти для критичной операции"
        fi
    fi
    
    return 0
}

# ---- /Health check module ----
