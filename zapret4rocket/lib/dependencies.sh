# ---- Dependencies check module ----
# Проверка наличия необходимых команд и зависимостей

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

# Загружаем логирование и валидацию если доступно
[ -f "$LIB_PATH/logging.sh" ] && source "$LIB_PATH/logging.sh" 2>/dev/null || true
[ -f "$LIB_PATH/validation.sh" ] && source "$LIB_PATH/validation.sh" 2>/dev/null || true

# Список критичных команд
CRITICAL_COMMANDS=("curl" "grep" "sed" "cut" "head" "tail" "mkdir" "rm" "cp" "mv" "tar")

# Список опциональных команд
OPTIONAL_COMMANDS=("wget" "nano" "nft" "ipset" "iptables")

# Проверка наличия команды с предложением установки
check_command_with_install() {
    local cmd="$1"
    local package="${2:-$cmd}"  # Имя пакета для установки (по умолчанию = имя команды)
    local os_type="${3:-}"  # Тип ОС (VPS, WRT, entware)
    
    if command -v "$cmd" >/dev/null 2>&1; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_debug "Команда найдена: $cmd"
        fi
        return 0
    fi
    
    if [ -f "$LIB_PATH/logging.sh" ]; then
        log_warning "Команда не найдена: $cmd"
    else
        echo -e "${yellow}[WARNING] Команда не найдена: $cmd${plain}" >&2
    fi
    
    # Если ОС не определена, просто сообщаем об ошибке
    if [ -z "$os_type" ]; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "Не удалось определить ОС для установки $cmd"
        else
            echo -e "${red}[ERROR] Не удалось определить ОС для установки $cmd${plain}" >&2
        fi
        return 1
    fi
    
    # Предложение установки
    echo -e "${yellow}Команда $cmd не найдена. Попытаться установить? (y/n): ${plain}"
    read -r answer
    
    case "$answer" in
        [Yy]*)
            case "$os_type" in
                VPS)
                    if command -v apt >/dev/null 2>&1; then
                        echo "Установка $package через apt..."
                        apt update && apt install -y "$package" || {
                            if [ -f "$LIB_PATH/logging.sh" ]; then
                                log_error "Не удалось установить $package"
                            fi
                            return 1
                        }
                    elif command -v yum >/dev/null 2>&1; then
                        echo "Установка $package через yum..."
                        yum install -y "$package" || {
                            if [ -f "$LIB_PATH/logging.sh" ]; then
                                log_error "Не удалось установить $package"
                            fi
                            return 1
                        }
                    else
                        if [ -f "$LIB_PATH/logging.sh" ]; then
                            log_error "Менеджер пакетов не найден для VPS"
                        fi
                        return 1
                    fi
                    ;;
                WRT|entware)
                    if command -v opkg >/dev/null 2>&1; then
                        echo "Установка $package через opkg..."
                        opkg update && opkg install "$package" || {
                            if [ -f "$LIB_PATH/logging.sh" ]; then
                                log_error "Не удалось установить $package"
                            fi
                            return 1
                        }
                    elif command -v apk >/dev/null 2>&1; then
                        echo "Установка $package через apk..."
                        apk update && apk add "$package" || {
                            if [ -f "$LIB_PATH/logging.sh" ]; then
                                log_error "Не удалось установить $package"
                            fi
                            return 1
                        }
                    else
                        if [ -f "$LIB_PATH/logging.sh" ]; then
                            log_error "Менеджер пакетов не найден для WRT/entware"
                        fi
                        return 1
                    fi
                    ;;
                *)
                    if [ -f "$LIB_PATH/logging.sh" ]; then
                        log_error "Неизвестный тип ОС: $os_type"
                    fi
                    return 1
                    ;;
            esac
            
            # Проверяем установку
            if command -v "$cmd" >/dev/null 2>&1; then
                if [ -f "$LIB_PATH/logging.sh" ]; then
                    log_info "Команда $cmd успешно установлена"
                else
                    echo -e "${green}Команда $cmd успешно установлена${plain}"
                fi
                return 0
            else
                if [ -f "$LIB_PATH/logging.sh" ]; then
                    log_error "Команда $cmd не найдена после установки"
                else
                    echo -e "${red}[ERROR] Команда $cmd не найдена после установки${plain}" >&2
                fi
                return 1
            fi
            ;;
        *)
            if [ -f "$LIB_PATH/logging.sh" ]; then
                log_warning "Установка $cmd пропущена пользователем"
            fi
            return 1
            ;;
    esac
}

# Проверка всех критичных команд
check_dependencies() {
    local os_type="${1:-}"
    local missing_critical=0
    local missing_optional=0
    
    if [ -f "$LIB_PATH/logging.sh" ]; then
        log_info "Проверка зависимостей..."
    else
        echo -e "${blue}Проверка зависимостей...${plain}"
    fi
    
    # Проверка критичных команд
    for cmd in "${CRITICAL_COMMANDS[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_critical=$((missing_critical + 1))
            if [ -f "$LIB_PATH/logging.sh" ]; then
                log_error "Критичная команда не найдена: $cmd"
            else
                echo -e "${red}[ERROR] Критичная команда не найдена: $cmd${plain}" >&2
            fi
            
            # Пытаемся установить если ОС определена
            if [ -n "$os_type" ]; then
                check_command_with_install "$cmd" "$cmd" "$os_type" || {
                    if [ -f "$LIB_PATH/logging.sh" ]; then
                        log_error "Не удалось установить критичную команду: $cmd"
                    fi
                }
            fi
        fi
    done
    
    # Проверка опциональных команд
    for cmd in "${OPTIONAL_COMMANDS[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_optional=$((missing_optional + 1))
            if [ -f "$LIB_PATH/logging.sh" ]; then
                log_debug "Опциональная команда не найдена: $cmd"
            fi
        fi
    done
    
    # Результат проверки
    if [ "$missing_critical" -eq 0 ]; then
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_info "Все критичные зависимости найдены"
        else
            echo -e "${green}Все критичные зависимости найдены${plain}"
        fi
        
        if [ "$missing_optional" -gt 0 ]; then
            if [ -f "$LIB_PATH/logging.sh" ]; then
                log_info "Отсутствует $missing_optional опциональных команд (не критично)"
            else
                echo -e "${yellow}Отсутствует $missing_optional опциональных команд (не критично)${plain}"
            fi
        fi
        
        return 0
    else
        if [ -f "$LIB_PATH/logging.sh" ]; then
            log_error "Отсутствует $missing_critical критичных команд"
        else
            echo -e "${red}[ERROR] Отсутствует $missing_critical критичных команд${plain}" >&2
        fi
        return 1
    fi
}

# Проверка версии критичных утилит
check_command_versions() {
    local cmd="$1"
    local min_version="${2:-}"
    
    if ! command -v "$cmd" >/dev/null 2>&1; then
        return 1
    fi
    
    # Для некоторых команд можно проверить версию
    case "$cmd" in
        curl)
            local version=$(curl --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
            if [ -n "$version" ] && [ -n "$min_version" ]; then
                # Простое сравнение версий (базовое)
                if [ -f "$LIB_PATH/logging.sh" ]; then
                    log_debug "Версия $cmd: $version"
                fi
            fi
            ;;
        *)
            # Для других команд просто проверяем наличие
            ;;
    esac
    
    return 0
}

# ---- /Dependencies check module ----
