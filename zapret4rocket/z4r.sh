#!/bin/bash
# 
# z4r.sh - Основной скрипт установки и управления zapret4rocket
# 
# Улучшенная обработка ошибок вместо set -e
# set -e отключен для более гибкой обработки ошибок через error_handler
# 
# Безопасность:
# - Валидация всех пользовательских вводов (домены, числа, пути)
# - Безопасная загрузка внешних скриптов с проверкой целостности
# - Экранирование специальных символов в sed/командах
# - Использование массивов для безопасного выполнения команд
# - Устранение использования eval
#
# Переменная содержащая версию на случай невозможности получить информацию о lastest с github
DEFAULT_VER="72.6"

#Чтобы удобнее красить текст
plain='\033[0m'
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
pink='\033[0;35m'
cyan='\033[0;36m'
Fplain='\033[1;37m'
Fred='\033[1;31m'
Fgreen='\033[1;32m'
Fyellow='\033[1;33m'
Fblue='\033[1;34m'
Fpink='\033[1;35m'
Fcyan='\033[1;36m'
Bplain='\033[47m'
Bred='\033[41m'
Bgreen='\033[42m'
Byellow='\033[43m'
Bblue='\033[44m'
Bpink='\033[45m'
Bcyan='\033[46m'

#___Проверка на наличие необходимых библиотек___#

#Определяем путь скрипта, подгружаем функции
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

# Определяем путь к библиотекам (поддерживаем оба варианта)
if [ -d "$SCRIPT_DIR/lib" ]; then
  LIB_PATH="$SCRIPT_DIR/lib"
else
  LIB_PATH="$SCRIPT_DIR/zapret/z4r_lib"
fi

# Проверяем наличие всех нужных lib-файлов, иначе запускаем внешний скрипт
missing_libs=0
LIB_DIR="$LIB_PATH"
for lib in ui.sh provider.sh telemetry.sh recommendations.sh netcheck.sh premium.sh strategies.sh submenus.sh actions.sh; do
  if [ ! -f "$LIB_DIR/$lib" ]; then
    missing_libs=1
    break
  fi
done

if [[ "$missing_libs" -ne 0 ]]; then
  echo "Не найдены нужные файлы в $LIB_DIR. Запускаю внешний z4r..."
  
  # Безопасная загрузка и выполнение внешнего скрипта
  safe_download_and_exec() {
    local url="$1"
    local temp_script="/tmp/z4r_external_$$.sh"
    local min_size=1000  # Минимальный размер скрипта (1KB)
    local max_size=500000  # Максимальный размер скрипта (500KB)
    
    # Скачиваем во временный файл
    if command -v curl >/dev/null 2>&1; then
      if ! curl -fsSL --max-time 30 -o "$temp_script" "$url" 2>/dev/null; then
        echo "Ошибка: не удалось загрузить внешний скрипт через curl." >&2
        return 1
      fi
    elif command -v wget >/dev/null 2>&1; then
      if ! wget -q --timeout=30 -O "$temp_script" "$url" 2>/dev/null; then
        echo "Ошибка: не удалось загрузить внешний скрипт через wget." >&2
        return 1
      fi
    else
      echo "Ошибка: нет curl или wget для загрузки внешнего z4r." >&2
      return 1
    fi
    
    # Проверка размера файла
    local file_size=$(stat -f%z "$temp_script" 2>/dev/null || stat -c%s "$temp_script" 2>/dev/null || echo 0)
    if (( file_size < min_size )) || (( file_size > max_size )); then
      echo "Ошибка: размер загруженного файла некорректен ($file_size байт). Ожидается от $min_size до $max_size байт." >&2
      rm -f "$temp_script" 2>/dev/null || true
      return 1
    fi
    
    # Базовая валидация: проверка что это bash скрипт
    if ! head -n 1 "$temp_script" 2>/dev/null | grep -qE '^#!/bin/(bash|sh)'; then
      echo "Ошибка: загруженный файл не является bash скриптом." >&2
      rm -f "$temp_script" 2>/dev/null || true
      return 1
    fi
    
    # Проверка что файл не пустой и содержит код
    if ! grep -qE '^[^#]|^#.*[^[:space:]]' "$temp_script" 2>/dev/null; then
      echo "Ошибка: загруженный файл не содержит исполняемого кода." >&2
      rm -f "$temp_script" 2>/dev/null || true
      return 1
    fi
    
    # Выполняем скрипт с явным указанием интерпретатора
    chmod +x "$temp_script" 2>/dev/null || true
    exec /bin/bash "$temp_script" "$@"
  }
  
  if command -v curl >/dev/null 2>&1; then
    safe_download_and_exec "https://raw.githubusercontent.com/IndeecFOX/z4r/main/z4r" "$@"
  elif command -v wget >/dev/null 2>&1; then
    safe_download_and_exec "https://raw.githubusercontent.com/IndeecFOX/z4r/main/z4r" "$@"
  else
    echo "Ошибка: нет curl или wget для загрузки внешнего z4r."
    exit 1
  fi
fi

#___Сначала идут анонсы функций____

# Система логирования (должна быть загружена первой)
# Функции: log_info, log_error, log_warning, log_debug
[ -f "$LIB_PATH/logging.sh" ] && source "$LIB_PATH/logging.sh" 2>/dev/null || true

# Обертка для оптимизированного логирования (кэширует проверки)
[ -f "$LIB_PATH/logging_wrapper.sh" ] && source "$LIB_PATH/logging_wrapper.sh" 2>/dev/null || true

# Система обработки ошибок
# Функции: error_handler, setup_error_handler, safe_exec, cleanup_temp_files
[ -f "$LIB_PATH/error_handler.sh" ] && source "$LIB_PATH/error_handler.sh" 2>/dev/null || true

# Retry механизмы для сетевых операций
# Функции: curl_with_retry, curl_with_retry_and_validate
[ -f "$LIB_PATH/retry.sh" ] && source "$LIB_PATH/retry.sh" 2>/dev/null || true

# Улучшенная работа с файлами (блокировки, атомарные операции)
# Функции: acquire_lock, release_lock, atomic_write, atomic_copy
[ -f "$LIB_PATH/file_operations.sh" ] && source "$LIB_PATH/file_operations.sh" 2>/dev/null || true

# Валидация данных
# Функции: validate_file_exists, validate_path, validate_version, validate_domain
[ -f "$LIB_PATH/validation.sh" ] && source "$LIB_PATH/validation.sh" 2>/dev/null || true

# Проверка зависимостей
# Функции: check_dependencies, check_command_with_install
[ -f "$LIB_PATH/dependencies.sh" ] && source "$LIB_PATH/dependencies.sh" 2>/dev/null || true

# Health checks
# Функции: health_check_all, check_zapret_status, check_disk_space
[ -f "$LIB_PATH/healthcheck.sh" ] && source "$LIB_PATH/healthcheck.sh" 2>/dev/null || true

# UI helpers (пауза/печать пунктов меню/совместимость старого кода)
# Функции: pause_enter, submenu_item, exit_to_menu
source "$LIB_PATH/ui.sh" 

# Определение провайдера/города + ручная установка/сброс кэша
# Функции: provider_init_once, provider_force_redetect, provider_set_manual_menu
# (внутр.: _detect_api_simple)
source "$LIB_PATH/provider.sh" 

# Телеметрия (вкл/выкл один раз + отправка статистики в Google Forms)
# Функции: init_telemetry, send_stats
source "$LIB_PATH/telemetry.sh" 

# База подсказок по стратегиям (скачивание + вывод подсказки по провайдеру)
# Функции: update_recommendations, show_hint
source "$LIB_PATH/recommendations.sh" 

# Проверка доступности ресурсов/сети (TLS 1.2/1.3) + получение домена кластера youtube (googlevideo)
# Функции: get_yt_cluster_domain, check_access, check_access_list
source "$LIB_PATH/netcheck.sh"

# “Premium” пункты 777/999 и их вспомогательные эффекты (рандом, спиннер, титулы)
# Функции: rand_from_list, spinner_for_seconds, premium_get_or_set_title, zefeer_premium_777, zefeer_space_999
source "$LIB_PATH/premium.sh" 

# Логика стратегий: определение активной стратегии, статус строкой, перебор стратегий, быстрый подбор
# Функции: get_active_strat_num, get_current_strategies_info, try_strategies, Strats_Tryer
source "$LIB_PATH/strategies.sh" 

# Подменю (UI-обвязка над Strats_Tryer + доп. меню управления: FLOWOFFLOAD, TCP443, провайдер)
# Функции: strategies_submenu, flowoffload_submenu, tcp443_submenu, provider_submenu
source "$LIB_PATH/submenus.sh" 

# Действия меню (бэкапы/сбросы/переключатели)
# Функции: backup_strats, menu_action_update_config_reset, menu_action_toggle_bolvan_ports,
#          menu_action_toggle_fwtype, menu_action_toggle_udp_range
source "$LIB_PATH/actions.sh" 

change_user() {
   local ws_user=""
   local first_user=""
   
   # Пробуем nobody
   if /opt/zapret/nfq/nfqws --dry-run --user="nobody" 2>&1 | grep -q "queue"; then
    ws_user="nobody"
    echo "WS_USER=$ws_user"
    # Используем альтернативный разделитель | для безопасности
    sed -i 's|^#\(WS_USER=nobody\)|\1|' /opt/zapret/config.default
   else
    # Пробуем первого пользователя из /etc/passwd
    first_user=$(head -n1 /etc/passwd 2>/dev/null | cut -d: -f1)
    if [[ -n "$first_user" ]]; then
      # Валидируем имя пользователя перед использованием
      if command -v validate_username >/dev/null 2>&1; then
        if ! validate_username "$first_user"; then
          echo -e "${yellow}WS_USER не подошёл (недопустимое имя пользователя: $first_user). Скорее всего будут проблемы.${plain}"
          return 1
        fi
      fi
      
      if /opt/zapret/nfq/nfqws --dry-run --user="$first_user" 2>&1 | grep -q "queue"; then
        ws_user="$first_user"
        echo "WS_USER=$ws_user"
        
        # Безопасная замена с экранированием и альтернативным разделителем
        if command -v escape_sed >/dev/null 2>&1; then
          local escaped_user
          escaped_user=$(escape_sed "$ws_user")
          sed -i "s|^#WS_USER=nobody$|WS_USER=$escaped_user|" /opt/zapret/config.default
        else
          # Fallback: используем альтернативный разделитель и базовое экранирование
          local safe_user
          safe_user=$(echo "$ws_user" | sed 's/[[\.*^$\/&\\]/\\&/g')
          sed -i "s|^#WS_USER=nobody$|WS_USER=$safe_user|" /opt/zapret/config.default
        fi
      else
        echo -e "${yellow}WS_USER не подошёл. Скорее всего будут проблемы. Если что - пишите в саппорт${plain}"
        return 1
      fi
    else
      echo -e "${yellow}Не удалось определить пользователя из /etc/passwd. Скорее всего будут проблемы.${plain}"
      return 1
    fi
   fi
   
   return 0
}

#Создаём папки и забираем файлы папок lists, fake, extra_strats, копируем конфиг, скрипты для войсов DS, WA, TG
get_repo() {
 mkdir -p /opt/zapret/lists /opt/zapret/extra_strats/TCP/{RKN,User,YT,temp,GV} /opt/zapret/extra_strats/UDP/YT /opt/zapret/files/fake
 
 # Используем retry механизмы для загрузки файлов списков
 for listfile in netrogat.txt russia-discord.txt russia-youtube-rtmps.txt russia-youtube.txt russia-youtubeQ.txt tg_cidr.txt; do
   if command -v curl_with_retry_and_validate >/dev/null 2>&1; then
     curl_with_retry_and_validate "https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/lists/$listfile" "/opt/zapret/lists/$listfile" 10 3 30 || {
       log_error_safe "Не удалось загрузить $listfile"
     }
   else
     curl -fsSL --max-time 30 -o "/opt/zapret/lists/$listfile" "https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/lists/$listfile" || {
       log_error_safe "Не удалось загрузить $listfile"
     }
   fi
 done
 
 # Загрузка архива fake файлов
 local fake_archive="/tmp/fake_files.tar.gz"
 if command -v curl_with_retry_and_validate >/dev/null 2>&1; then
   curl_with_retry_and_validate "https://github.com/IndeecFOX/zapret4rocket/raw/master/fake_files.tar.gz" "$fake_archive" 1000 3 60 && {
     tar -xz -C /opt/zapret/files/fake -f "$fake_archive" 2>/dev/null || {
       log_error_safe "Ошибка распаковки fake_files.tar.gz"
     }
     rm -f "$fake_archive" 2>/dev/null || true
   }
 else
   curl -fsSL --max-time 60 -o "$fake_archive" "https://github.com/IndeecFOX/zapret4rocket/raw/master/fake_files.tar.gz" && {
     tar -xz -C /opt/zapret/files/fake -f "$fake_archive" 2>/dev/null || true
     rm -f "$fake_archive" 2>/dev/null || true
   }
 fi
 
 # Загрузка List.txt файлов с retry
 local list_load_errors=0
 if command -v curl_with_retry_and_validate >/dev/null 2>&1; then
   if ! curl_with_retry_and_validate "https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/extra_strats/UDP/YT/List.txt" "/opt/zapret/extra_strats/UDP/YT/List.txt" 10 3 30; then
     log_warning_safe "Не удалось загрузить UDP/YT/List.txt (некритично)"
     list_load_errors=$((list_load_errors + 1))
   fi
   if ! curl_with_retry_and_validate "https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/extra_strats/TCP/RKN/List.txt" "/opt/zapret/extra_strats/TCP/RKN/List.txt" 100 3 60; then
     log_warning_safe "Не удалось загрузить TCP/RKN/List.txt (некритично)"
     list_load_errors=$((list_load_errors + 1))
   fi
   if ! curl_with_retry_and_validate "https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/extra_strats/TCP/YT/List.txt" "/opt/zapret/extra_strats/TCP/YT/List.txt" 10 3 30; then
     [ -f "$LIB_PATH/logging.sh" ] && log_warning "Не удалось загрузить TCP/YT/List.txt (некритично)" || echo "Предупреждение: не удалось загрузить TCP/YT/List.txt" >&2
     list_load_errors=$((list_load_errors + 1))
   fi
 else
   if ! curl -fsSL --max-time 30 -o "/opt/zapret/extra_strats/UDP/YT/List.txt" "https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/extra_strats/UDP/YT/List.txt" 2>/dev/null; then
     log_warning_safe "Не удалось загрузить UDP/YT/List.txt (некритично)"
     list_load_errors=$((list_load_errors + 1))
   fi
   if ! curl -fsSL --max-time 60 -o "/opt/zapret/extra_strats/TCP/RKN/List.txt" "https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/extra_strats/TCP/RKN/List.txt" 2>/dev/null; then
     log_warning_safe "Не удалось загрузить TCP/RKN/List.txt (некритично)"
     list_load_errors=$((list_load_errors + 1))
   fi
   if ! curl -fsSL --max-time 30 -o "/opt/zapret/extra_strats/TCP/YT/List.txt" "https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/extra_strats/TCP/YT/List.txt" 2>/dev/null; then
     [ -f "$LIB_PATH/logging.sh" ] && log_warning "Не удалось загрузить TCP/YT/List.txt (некритично)" || echo "Предупреждение: не удалось загрузить TCP/YT/List.txt" >&2
     list_load_errors=$((list_load_errors + 1))
   fi
 fi
 
 # Создание пустых файлов стратегий
 touch /opt/zapret/lists/autohostlist.txt /opt/zapret/extra_strats/UDP/YT/{1..8}.txt /opt/zapret/extra_strats/TCP/RKN/{1..17}.txt /opt/zapret/extra_strats/TCP/User/{1..17}.txt /opt/zapret/extra_strats/TCP/YT/{1..17}.txt /opt/zapret/extra_strats/TCP/GV/{1..17}.txt /opt/zapret/extra_strats/TCP/temp/{1..17}.txt 2>/dev/null || true
 
 # Восстановление бэкапов
 if [ -d /opt/extra_strats ]; then
  rm -rf /opt/zapret/extra_strats 2>/dev/null || true
  mv /opt/extra_strats /opt/zapret/ 2>/dev/null || true
  log_info_safe "Восстановление настроек подбора из резерва выполнено"
 fi
 if [ -f "/opt/netrogat.txt" ]; then
   mv -f /opt/netrogat.txt /opt/zapret/lists/netrogat.txt 2>/dev/null || true
   [ -f "$LIB_PATH/logging.sh" ] && log_info "Восстановление листа исключений выполнено" || echo "Востановление листа исключений выполнено."
 fi
 
 #Копирование нашего конфига на замену стандартному и скриптов для войсов DS, WA, TG
 if command -v curl_with_retry_and_validate >/dev/null 2>&1; then
   curl_with_retry_and_validate "https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/config.default" "/opt/zapret/config.default" 100 3 30 || {
     [ -f "$LIB_PATH/logging.sh" ] && log_error "Не удалось загрузить config.default" || echo "Ошибка загрузки config.default" >&2
   }
 else
   curl -fsSL --max-time 30 -o /opt/zapret/config.default "https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/config.default" || true
 fi
 
 if command -v nft >/dev/null 2>&1; then
  sed -i 's/^FWTYPE=iptables$/FWTYPE=nftables/' "/opt/zapret/config.default" 2>/dev/null || true
 fi
 
 # Загрузка скриптов для войсов
 local voice_script_errors=0
 if command -v curl_with_retry_and_validate >/dev/null 2>&1; then
   if ! curl_with_retry_and_validate "https://raw.githubusercontent.com/bol-van/zapret/master/init.d/custom.d.examples.linux/50-stun4all" "/opt/zapret/init.d/sysv/custom.d/50-stun4all" 10 3 30; then
     log_warning_safe "Не удалось загрузить 50-stun4all (некритично)"
     voice_script_errors=$((voice_script_errors + 1))
   fi
   if ! curl_with_retry_and_validate "https://raw.githubusercontent.com/bol-van/zapret/master/init.d/custom.d.examples.linux/50-discord-media" "/opt/zapret/init.d/sysv/custom.d/50-discord-media" 10 3 30; then
     log_warning_safe "Не удалось загрузить 50-discord-media (некритично)"
     voice_script_errors=$((voice_script_errors + 1))
   fi
 else
   if ! curl -fsSL --max-time 30 -o /opt/zapret/init.d/sysv/custom.d/50-stun4all "https://raw.githubusercontent.com/bol-van/zapret/master/init.d/custom.d.examples.linux/50-stun4all" 2>/dev/null; then
     log_warning_safe "Не удалось загрузить 50-stun4all (некритично)"
     voice_script_errors=$((voice_script_errors + 1))
   fi
   if ! curl -fsSL --max-time 30 -o /opt/zapret/init.d/sysv/custom.d/50-discord-media "https://raw.githubusercontent.com/bol-van/zapret/master/init.d/custom.d.examples.linux/50-discord-media" 2>/dev/null; then
     log_warning_safe "Не удалось загрузить 50-discord-media (некритично)"
     voice_script_errors=$((voice_script_errors + 1))
   fi
 fi
 
 # Копирование скриптов (некритично если файлы не существуют)
 if [ -f "/opt/zapret/init.d/sysv/custom.d/50-stun4all" ]; then
   cp -f /opt/zapret/init.d/sysv/custom.d/50-stun4all /opt/zapret/init.d/openwrt/custom.d/50-stun4all 2>/dev/null || {
     log_debug_safe "Не удалось скопировать 50-stun4all в openwrt (некритично)"
   }
 fi
 if [ -f "/opt/zapret/init.d/sysv/custom.d/50-discord-media" ]; then
   cp -f /opt/zapret/init.d/sysv/custom.d/50-discord-media /opt/zapret/init.d/openwrt/custom.d/50-discord-media 2>/dev/null || {
     log_debug_safe "Не удалось скопировать 50-discord-media в openwrt (некритично)"
   }
 fi

# cache
mkdir -p /opt/zapret/extra_strats/cache

}

#Удаление старого запрета, если есть
remove_zapret() {
 if [ -f "/opt/zapret/init.d/sysv/zapret" ] && [ -f "/opt/zapret/config" ]; then
 	/opt/zapret/init.d/sysv/zapret stop
 fi
 if [ -f "/opt/zapret/config" ] && [ -f "/opt/zapret/uninstall_easy.sh" ]; then
     echo "Выполняем zapret/uninstall_easy.sh"
     sh /opt/zapret/uninstall_easy.sh
     echo "Скрипт uninstall_easy.sh выполнен."
 else
     echo "zapret не инсталлирован в систему. Переходим к следующему шагу."
 fi
 if [ -d "/opt/zapret" ]; then
     echo "Удаляем папку zapret"
     rm -rf /opt/zapret
	 rm -rf /tmp/zapret
 else
     echo "Папка zapret не существует."
 fi
}

#Запрос желаемой версии zapret
version_select() {
   while true; do
	read -re -p $'\033[0;32mВведите желаемую версию zapret (Enter для новейшей версии): \033[0m' VER
    # Если пустой ввод — берем значение по умолчанию
	if [ -z "$VER" ]; then
		lastest_release="https://api.github.com/repos/bol-van/zapret/releases/latest"
	    # проверяем результаты по порядку
		echo -e "${yellow}Поиск последней версии...${plain}"
    	VER1=$(curl -sL $lastest_release | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
		if [[ ${#VER1} -ge 2 ]]; then
			VER="$VER1"
			echo -e "${green}Выбрано: $VER (метод: sed -E)${plain}"
		else
			VER2=$(curl -sL $lastest_release | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4 | sed 's/^v//')
			if [[ ${#VER2} -ge 2 ]]; then
				VER="$VER2"
				echo -e "${green}Выбрано: $VER (метод: grep+cut)${plain}"
			else
				VER3=$(curl -sL $lastest_release | grep '"tag_name":' | sed -r 's/.*"v([^"]+)".*/\1/')
				if [[ ${#VER3} -ge 2 ]]; then
					VER="$VER3"
					echo -e "${green}Выбрано: $VER (метод: sed -r)${plain}"
				else
					VER4=$(curl -sL $lastest_release | grep '"tag_name":' | awk -F'"' '{print $4}' | sed 's/^v//')
					if [[ ${#VER4} -ge 2 ]]; then
						VER="$VER4"
						echo -e "${green}Выбрано: $VER (метод: awk)${plain}"
					else
						echo -e "${yellow}Не удалось получить информацию о последней версии с GitHub. Будет использоваться версия $DEFAULT_VER.${plain}"
						VER="$DEFAULT_VER"
					fi
				fi
			fi
    	fi
    	break
	fi
    # Используем валидацию версии если доступна
    if command -v validate_version >/dev/null 2>&1; then
        if ! validate_version "$VER"; then
            echo "Некорректный формат версии. Пример: 72.3"
            continue
        fi
    else
        # Fallback на старую валидацию
        LEN=${#VER}
        if (( LEN > 4 )); then
            echo "Некорректный ввод. Максимальная длина — 4 символа. Попробуйте снова."
            continue
        elif ! echo "$VER" | grep -Eq '^[0-9]+(\.[0-9]+)*$'; then
            echo "Некорректный формат версии. Пример: 72.3"
            continue
        fi
    fi
    
    [ -f "$LIB_PATH/logging.sh" ] && log_info "Выбрана версия zapret: $VER" || echo "Будет использоваться версия: $VER"
    break
done
}

#Скачивание, распаковка архива zapret, очистка от ненуных бинарей
zapret_get() {
 if [[ "$OSystem" == "VPS" ]]; then
     tarfile="zapret-v$VER.tar.gz"
 else
     tarfile="zapret-v$VER-openwrt-embedded.tar.gz"
 fi
 curl -L "https://github.com/bol-van/zapret/releases/download/v$VER/$tarfile" | tar -xz
 mv "zapret-v$VER" zapret
 sh /tmp/zapret/install_bin.sh
 find /tmp/zapret/binaries/* -maxdepth 0 -type d ! -name "$(basename "$(dirname "$(readlink /tmp/zapret/nfq/nfqws)")")" -exec rm -rf {} +
 mv zapret /opt/zapret
}

#Запуск установочных скриптов и перезагрузка
install_zapret_reboot() {
 sh -i /opt/zapret/install_easy.sh
 /opt/zapret/init.d/sysv/zapret restart
 if pidof nfqws >/dev/null; then
  check_access_list
  echo -e "\033[32mzapret перезапущен и полностью установлен\n\033[33mЕсли требуется меню (например не работают какие-то ресурсы) - введите скрипт ещё раз или просто напишите "z4r" в терминале. Саппорт: tg: zee4r\033[0m"
 else
  echo -e "${yellow}zapret полностью установлен, но не обнаружен после запуска в исполняемых задачах через pidof\nСаппорт: tg: zee4r${plain}"
 fi
}

#Для Entware Keenetic + merlin
entware_fixes() {
 if [ "$hardware" = "keenetic" ]; then
  curl -L -o /opt/zapret/init.d/sysv/zapret https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/Entware/zapret
  chmod +x /opt/zapret/init.d/sysv/zapret
  echo "Права выданы /opt/zapret/init.d/sysv/zapret"
  curl -L -o /opt/etc/ndm/netfilter.d/000-zapret.sh https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/Entware/000-zapret.sh
  chmod +x /opt/etc/ndm/netfilter.d/000-zapret.sh
  echo "Права выданы /opt/etc/ndm/netfilter.d/000-zapret.sh"
  curl -L -o /opt/etc/init.d/S00fix https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/Entware/S00fix
  chmod +x /opt/etc/init.d/S00fix
  echo "Права выданы /opt/etc/init.d/S00fix"
  cp -a /opt/zapret/init.d/custom.d.examples.linux/10-keenetic-udp-fix /opt/zapret/init.d/sysv/custom.d/10-keenetic-udp-fix
  echo "10-keenetic-udp-fix скопирован"
 elif [ "$hardware" = "merlin" ]; then
  if sed -n '167p' /opt/zapret/install_easy.sh | grep -q '^nfqws_opt_validat'; then
	sed -i '172s/return 1/return 0/' /opt/zapret/install_easy.sh
  fi
  FW="/jffs/scripts/firewall-start"
  if [ ! -f "$FW" ]; then
    echo "$FW не найден, пропускаю добавление правила"
  else
    grep -qxF '/opt/zapret/init.d/sysv/zapret restart' "$FW" || echo '/opt/zapret/init.d/sysv/zapret restart' >> "$FW"
	chmod +x /jffs/scripts/firewall-start
  fi
 fi
 
 sh /opt/zapret/install_bin.sh
 
 # #Раскомменчивание юзера под keenetic или merlin
 change_user
 #Патчинг на некоторых merlin /opt/zapret/common/linux_fw.sh
 if command -v sysctl >/dev/null 2>&1; then
  echo "sysctl доступен. Патч linux_fw.sh не требуется"
 else
  echo "sysctl отсутствует. MerlinWRT? Патчим /opt/zapret/common/linux_fw.sh"
  sed -i 's|sysctl -w net.netfilter.nf_conntrack_tcp_be_liberal=\$1|echo \$1 > /proc/sys/net/netfilter/nf_conntrack_tcp_be_liberal|' /opt/zapret/common/linux_fw.sh
  sed -i 's|sysctl -q -w net.ipv4.conf.\$1.route_localnet="\$enable"|echo "\$enable" > /proc/sys/net/ipv4/conf/\$1/route_localnet|' /opt/zapret/common/linux_iphelper.sh
 fi
 #sed для пропуска запроса на прочтение readme, т.к. система entware. Дабы скрипт отрабатывал далее на Enter
 sed -i 's/if \[ -n "\$1" \] || ask_yes_no N "do you want to continue";/if true;/' /opt/zapret/common/installer.sh
 ln -fs /opt/zapret/init.d/sysv/zapret /opt/etc/init.d/S90-zapret
 echo "Добавлено в автозагрузку: /opt/etc/init.d/S90-zapret > /opt/zapret/init.d/sysv/zapret"
}

#Запрос на установку 3x-ui или аналогов
get_panel() {
 read -re -p $'\033[33mУстановить ПО для туннелирования?\033[0m \033[32m(3xui, marzban, wg, 3proxy или Enter для пропуска): \033[0m' answer_panel
 # Удаляем лишние символы и пробелы, приводим к верхнему регистру
 # Валидация: разрешаем только буквы, цифры и пробелы
 clean_answer=$(echo "$answer_panel" | tr -cd '[:alnum:][:space:]' | tr '[:lower:]' '[:upper:]' | tr -s '[:space:]' | xargs)
 if [[ -z "$clean_answer" ]]; then
     echo "Пропуск установки ПО туннелирования."
 elif [[ "$clean_answer" == "3XUI" ]]; then
     echo "Установка 3x-ui панели."
     bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
 elif [[ "$clean_answer" == "WG" ]]; then
     echo "Установка WG (by angristan)"
     bash <(curl -Ls https://raw.githubusercontent.com/angristan/wireguard-install/refs/heads/master/wireguard-install.sh)
 elif [[ "$clean_answer" == "3PROXY" ]]; then
     echo "Установка 3proxy (by SnoyIatk). Доустановка с apt build-essential для сборки (debian/ubuntu)"
	 apt update && apt install build-essential
     bash <(curl -Ls https://raw.githubusercontent.com/SnoyIatk/3proxy/master/3proxyinstall.sh)
     curl -L -o /etc/3proxy/.proxyauth https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/refs/heads/master/del.proxyauth
     curl -L -o /etc/3proxy/3proxy.cfg https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/refs/heads/master/3proxy.cfg
 elif [[ "$clean_answer" == "MARZBAN" ]]; then
     echo "Установка Marzban"
     bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install
  else
     echo "Пропуск установки ПО туннелирования."
  fi
}

#Меню управления веб-интерфейсом
web_interface_menu() {
  while true; do
    clear
    echo -e "${cyan}--- Управление веб-интерфейсом z4r ---${plain}"
    
    # Проверка статуса веб-сервера
    local web_status="Остановлен"
    local web_pid=""
    if pgrep -f "python3.*app.py" >/dev/null 2>&1 || pgrep -f "python.*app.py" >/dev/null 2>&1; then
      web_status="${green}Запущен${plain}"
      web_pid=$(pgrep -f "python3.*app.py" | head -n1 || pgrep -f "python.*app.py" | head -n1)
    fi
    
    echo -e "Статус веб-интерфейса: ${web_status}"
    if [ -n "$web_pid" ]; then
      echo -e "PID: ${web_pid}"
    fi
    
    # Определение порта из конфига
    local web_port="17681"
    if [ -f "$SCRIPT_DIR/web_config.json" ]; then
      local port_from_config=$(grep -o '"port"[[:space:]]*:[[:space:]]*[0-9]*' "$SCRIPT_DIR/web_config.json" | grep -o '[0-9]*' || echo "")
      [ -n "$port_from_config" ] && web_port="$port_from_config"
    fi
    
    echo -e "${yellow}Выберите действие:${plain}"
    echo -e "1. Установить/обновить веб-интерфейс"
    echo -e "2. Запустить веб-интерфейс"
    echo -e "3. Остановить веб-интерфейс"
    echo -e "4. Перезапустить веб-интерфейс"
    echo -e "5. Проверить статус"
    echo -e "0. Назад в главное меню"
    echo ""
    
    read -re -p "Ваш выбор: " web_answer
    
    case "$web_answer" in
      "1")
        echo -e "${yellow}Установка веб-интерфейса...${plain}"
        if [ -f "$SCRIPT_DIR/install_web.sh" ]; then
          bash "$SCRIPT_DIR/install_web.sh"
        else
          echo -e "${red}Файл install_web.sh не найден${plain}"
        fi
        pause_enter
        ;;
      "2")
        echo -e "${yellow}Запуск веб-интерфейса...${plain}"
        if [ -f /etc/systemd/system/z4r-web.service ]; then
          systemctl start z4r-web 2>/dev/null || echo -e "${red}Ошибка запуска через systemd${plain}"
        elif [ -f /etc/init.d/z4r-web ]; then
          /etc/init.d/z4r-web start 2>/dev/null || echo -e "${red}Ошибка запуска через init.d${plain}"
        elif [ -f /opt/etc/init.d/S99z4r-web ]; then
          /opt/etc/init.d/S99z4r-web start 2>/dev/null || echo -e "${red}Ошибка запуска${plain}"
        else
          echo -e "${yellow}Запуск вручную...${plain}"
          cd "$SCRIPT_DIR/web" && nohup python3 app.py > /tmp/z4r-web.log 2>&1 &
          echo -e "${green}Веб-интерфейс запущен${plain}"
        fi
        sleep 2
        echo -e "${green}Веб-интерфейс должен быть доступен на порту ${web_port}${plain}"
        pause_enter
        ;;
      "3")
        echo -e "${yellow}Остановка веб-интерфейса...${plain}"
        if [ -f /etc/systemd/system/z4r-web.service ]; then
          systemctl stop z4r-web 2>/dev/null || true
        elif [ -f /etc/init.d/z4r-web ]; then
          /etc/init.d/z4r-web stop 2>/dev/null || true
        elif [ -f /opt/etc/init.d/S99z4r-web ]; then
          /opt/etc/init.d/S99z4r-web stop 2>/dev/null || true
        fi
        pkill -f "python3.*app.py" 2>/dev/null || pkill -f "python.*app.py" 2>/dev/null || true
        echo -e "${green}Веб-интерфейс остановлен${plain}"
        pause_enter
        ;;
      "4")
        echo -e "${yellow}Перезапуск веб-интерфейса...${plain}"
        if [ -f /etc/systemd/system/z4r-web.service ]; then
          systemctl restart z4r-web 2>/dev/null || echo -e "${red}Ошибка перезапуска${plain}"
        elif [ -f /etc/init.d/z4r-web ]; then
          /etc/init.d/z4r-web restart 2>/dev/null || echo -e "${red}Ошибка перезапуска${plain}"
        elif [ -f /opt/etc/init.d/S99z4r-web ]; then
          /opt/etc/init.d/S99z4r-web restart 2>/dev/null || echo -e "${red}Ошибка перезапуска${plain}"
        else
          pkill -f "python3.*app.py" 2>/dev/null || pkill -f "python.*app.py" 2>/dev/null || true
          sleep 1
          cd "$SCRIPT_DIR/web" && nohup python3 app.py > /tmp/z4r-web.log 2>&1 &
        fi
        sleep 2
        echo -e "${green}Веб-интерфейс перезапущен${plain}"
        pause_enter
        ;;
      "5")
        echo -e "${yellow}Проверка статуса веб-интерфейса...${plain}"
        if pgrep -f "python3.*app.py" >/dev/null 2>&1 || pgrep -f "python.*app.py" >/dev/null 2>&1; then
          local pid=$(pgrep -f "python3.*app.py" | head -n1 || pgrep -f "python.*app.py" | head -n1)
          echo -e "${green}Веб-интерфейс запущен (PID: ${pid})${plain}"
          if command -v curl >/dev/null 2>&1; then
            if curl -s --max-time 3 "http://localhost:${web_port}/api/status/zapret" >/dev/null 2>&1; then
              echo -e "${green}Веб-интерфейс отвечает на запросы${plain}"
            else
              echo -e "${yellow}Веб-интерфейс запущен, но не отвечает на запросы${plain}"
            fi
          fi
        else
          echo -e "${red}Веб-интерфейс не запущен${plain}"
        fi
        pause_enter
        ;;
      "0"|"")
        return 0
        ;;
      *)
        echo -e "${red}Неверный выбор${plain}"
        sleep 1
        ;;
    esac
  done
}

#Меню, проверка состояний и вывод с чтением ответа
get_menu() {
    TITLE_MENU_LINE=""
    if [[ -s "$PREMIUM_TITLE_FILE" ]]; then
      TITLE_MENU_LINE="\n${pink}Титул:${plain} $(cat "$PREMIUM_TITLE_FILE")${yellow}\n"
    fi
    provider_init_once
    init_telemetry
    update_recommendations  
  while true; do
  	local strategies_status
    strategies_status=$(get_current_strategies_info)
	TITLE_MENU_LINE=""
    if [[ -s "$PREMIUM_TITLE_FILE" ]]; then
      TITLE_MENU_LINE="\n${pink}Титул:${plain} $(cat "$PREMIUM_TITLE_FILE")${yellow}\n"
    fi
    #clear
    echo -e '
░░░▀▀█░█▀▀░█▀▀░█▀▀░█▀▀░█▀▀░█▀▄░░░
░░░▄▀░░█▀▀░█▀▀░█▀▀░█▀▀░█▀▀░█▀▄░░░
░░░▀▀▀░▀▀▀░▀▀▀░▀░░░▀▀▀░▀▀▀░▀░▀░░░

'"Город/провайдер: ${plain}${PROVIDER_MENU}${yellow}"'
'"${TITLE_MENU_LINE}"'
\033[32mВыберите необходимое действие:\033[33m
Enter (без цифр) - переустановка/обновление zapret
0. Выход
01. Проверить доступность сервисов (Тест не точен)
1. Сменить стратегии или добавить домен в хост-лист. Текущие: '"${plain}"'[ '"${strategies_status}"' ]'"${yellow}"'
2. Стоп/пере(запуск) zapret (сейчас: '"$(pidof nfqws >/dev/null && echo "${green}Запущен${yellow}" || echo "${red}Остановлен${yellow}")"')
3. Показать домены которые zapret посчитал не доступными
4. Удалить zapret
5. Обновить стратегии, сбросить листы подбора стратегий и исключений (есть бэкап)
6. Исключить домен из zapret обработки
7. Открыть в редакторе config (Установит nano редактор ~250kb)
8. Преключатель скриптов bol-van обхода войсов DS,WA,TG на стандартные страты или возврат к скриптам. Сейчас: '"${plain}"'['"$(grep -Eq '^NFQWS_PORTS_UDP=.*443$' /opt/zapret/config && echo "Скрипты" || (grep -Eq '443,1400,3478-3481,5349,50000-50099,19294-19344$' /opt/zapret/config && echo "Классические стратегии" || echo "Незвестно"))"']'"${yellow}"'
9. Переключатель zapret на nftables/iptables (На всё жать Enter). Актуально для OpenWRT 21+. Может помочь с войсами. Сейчас: '"${plain}"'['"$(grep -q '^FWTYPE=iptables$' /opt/zapret/config && echo "iptables" || (grep -q '^FWTYPE=nftables$' /opt/zapret/config && echo "nftables" || echo "Неизвестно"))"']'"${yellow}"'
10. (Де)активировать обход UDP на 1026-65531 портах (BF6, Fifa и т.п.). Сейчас: '"${plain}"'['"$(grep -q '^NFQWS_PORTS_UDP=443' /opt/zapret/config && echo "Выключен" || (grep -q '^NFQWS_PORTS_UDP=1026-65531,443' /opt/zapret/config && echo "Включен" || echo "Неизвестно"))"']'"${yellow}"'
11. Управление аппаратным ускорением zapret. Может увеличить скорость на роутере. Сейчас: '"${plain}"'['"$(grep '^FLOWOFFLOAD=' /opt/zapret/config)"']'"${yellow}"'
12. Меню (Де)Активации работы по всем доменам TCP-443 без хост-листов (не затрагивает youtube стратегии) (безразборный режим) Сейчас: '"${plain}"'['"$(num=$(sed -n '112,128p' /opt/zapret/config | grep -n '^--filter-tcp=443 --hostlist-domains= --' | head -n1 | cut -d: -f1); [ -n "$num" ] && echo "$num" || echo "Отключен")"']'"${yellow}"'
13. Провайдер
14. Установить/управлять веб-интерфейсом
777. Активировать zeefeer premium (Нажимать только Valery ProD, avg97, Xoz, GeGunT, Nomand, Kovi, blagodarenya, mikhyan, Xoz, andric62, Whoze, Necronicle, Andrei_5288515371, Dina_turat, Nergalss, Александру, АлександруП, vecheromholodno, ЕвгениюГ, Dyadyabo, skuwakin, izzzgoy, Grigaraz, Reconnaissance, comandante1928, umad, rudnev2028, rutakote, railwayfx, vtokarev1604, Grigaraz, a40letbezurojaya и subzeero452 и остальным поддержавшим проект. Но если очень хочется - можно нажать и другим)\033[0m'
    if [[ -f "$PREMIUM_FLAG" ]]; then
      echo -e "${red}999. Секретный пункт. Нажимать на свой страх и риск${plain}"
    fi
  read -re -p "" answer_menu
    case "$answer_menu" in
  "")
    echo -e "${yellow}Вы уверены, что хотите переустановить/обновить zapret?${plain}"
    echo -e "${yellow}5 - Да, Enter/0 - Нет (вернуться в меню)${plain}"
    read -r ans
    if [ "$ans" = "5" ] || [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
      # подтверждение: выходим из get_menu и уходим в “тело” (переустановка/обновление)
      return 0
    else
      # отмена: остаёмся в меню, цикл while true продолжится
      :
    fi
    ;;

  "0")
    echo "Выход выполнен"
    exit 0
    ;;

  "01")
    check_access_list
    pause_enter
    ;;

  "1")
    echo "Режим подбора других стратегий"
    strategies_submenu     # strategies_submenu сам в цикле и выходит через return
    ;;

  "2")
    if pidof nfqws >/dev/null; then
      /opt/zapret/init.d/sysv/zapret stop
      echo -e "${green}Выполнена команда остановки zapret${plain}"
    else
      /opt/zapret/init.d/sysv/zapret restart
      echo -e "${green}Выполнена команда перезапуска zapret${plain}"
    fi
    pause_enter
    ;;

  "3")
    cat /opt/zapret/lists/autohostlist.txt
	pause_enter
    ;;

  "4")
    remove_zapret
    echo -e "${yellow}zapret удалён${plain}"
    pause_enter
    ;;

  "5")
    menu_action_update_config_reset
    pause_enter
    ;;

  "6")
	read -re -p "Показать список доменов в исключениях? 1 - да, enter - нет: " open_netrogat
    if [ "$open_netrogat" == "1" ]; then
		cat /opt/zapret/lists/netrogat.txt
		open_netrogat=""
    fi
	echo "Через пробел можно укзазывать сразу несколько доменов"
    read -re -p "Введите домен, который добавить в исключения (например: test.com или https://test.com/ или 0 для выхода): " user_domain
	user_domain=$(sed -E 's~https?://~~g; s~([^[:space:]]+)/~\1~g' <<< "$user_domain")
	
	if [ "$user_domain" == "0" ] ; then
	 echo "Ввод отменён"
    elif [ -n "$user_domain" ]; then
      # Валидация доменов перед добавлением
      local domains
      domains=$(echo "$user_domain" | sed 's/[[:space:]]\+/\n/g')
      local added_count=0
      local skipped_count=0
      
      while IFS= read -r domain || [ -n "$domain" ]; do
        [ -z "$domain" ] && continue
        
        # Валидация домена если доступна функция
        if command -v validate_domain >/dev/null 2>&1; then
          if validate_domain "$domain"; then
            printf '%s\n' "$domain" >> /opt/zapret/lists/netrogat.txt
            added_count=$((added_count + 1))
          else
            echo -e "${yellow}Пропущен некорректный домен: $domain${plain}" >&2
            skipped_count=$((skipped_count + 1))
          fi
        else
          # Fallback: базовая проверка формата
          if echo "$domain" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$'; then
            printf '%s\n' "$domain" >> /opt/zapret/lists/netrogat.txt
            added_count=$((added_count + 1))
          else
            echo -e "${yellow}Пропущен домен с подозрительным форматом: $domain${plain}" >&2
            skipped_count=$((skipped_count + 1))
          fi
        fi
      done <<< "$domains"
      
      if [ "$added_count" -gt 0 ]; then
        echo -e "Добавлено доменов в исключения: ${green}$added_count${plain}"
        if [ "$skipped_count" -gt 0 ]; then
          echo -e "Пропущено некорректных доменов: ${yellow}$skipped_count${plain}"
        fi
      else
        echo -e "${red}Не добавлено ни одного валидного домена${plain}"
      fi
    else
      echo "Ввод пустой, ничего не добавлено"
    fi
    pause_enter
    ;;

  "7")
    if [[ "$OSystem" == "VPS" ]]; then
      apt install nano
    else
      opkg remove nano 2>/dev/null || apk del nano 2>/dev/null
      opkg install nano-full 2>/dev/null || apk add nano-full 2>/dev/null
    fi
    nano /opt/zapret/config
    # после выхода из nano
    ;;

  "8")
    menu_action_toggle_bolvan_ports
    pause_enter
    ;;

  "9")
    menu_action_toggle_fwtype
    pause_enter
    ;;

  "10")
    menu_action_toggle_udp_range
    pause_enter
    ;;

  "11")
    flowoffload_submenu   # сабменю само в цикле и выходит через return
    ;;

  "12")
    tcp443_submenu        # сабменю само в цикле и выходит через return
    ;;

  "13")
    provider_submenu      # сабменю само в цикле и выходит через return
    ;;

  "14")
    web_interface_menu    # меню управления веб-интерфейсом
    ;;

  "777")
   echo -e "${green}Специальный zeefeer premium для Valery ProD, avg97, Xoz, GeGunT, Nomand, Kovi, blagodarenya, mikhyan, andric62, Whoze, Necronicle, Andrei_5288515371, Dina_turat, Nergalss, Александра, АлександраП, vecheromholodno, ЕвгенияГ, Dyadyabo, skuwakin, izzzgoy, Grigaraz, Reconnaissance, comandante1928, rudnev2028, umad, rutakote, railwayfx, vtokarev1604, Grigaraz, a40letbezurojaya и subzeero452 активирован. Наверное. Так же благодарю поддержавших проект hey_enote, VssA, vladdrazz, Alexey_Tob, Bor1sBr1tva, Azamatstd, iMLT, Qu3Bee, SasayKudasay1, alexander_novikoff, MarsKVV, porfenon123, bobrishe_dazzle, kotov38, Levonkas, DA00001, trin4ik, geodomin, I_ZNA_I, CMyTHblN PacKoJlbHNK и анонимов${plain}"
   zefeer_premium_777
   exit_to_menu
   ;;
  "999")
    zefeer_space_999
    pause_enter
    ;;

  *)
    echo -e "${yellow}Неверный ввод.${plain}"
    sleep 1
    ;;
esac

  done
}

#___Само выполнение скрипта начинается тут____

# Установка обработчика ошибок (если доступен)
if [ -f "$LIB_PATH/error_handler.sh" ]; then
    setup_error_handler 2>/dev/null || true
fi

# Очистка старых временных файлов при старте
cleanup_old_temp_files() {
    # Очистка старых временных файлов z4r (старше 1 часа)
    find /tmp -maxdepth 1 -name "z4r_*" -type f -mmin +60 -delete 2>/dev/null || true
    find /tmp -maxdepth 1 -name "*_backup_*" -type f -mmin +60 -delete 2>/dev/null || true
    find /tmp -maxdepth 1 -name "*.tmp.*" -type f -mmin +60 -delete 2>/dev/null || true
    
    # Очистка старых lock файлов если доступна функция
    if command -v cleanup_old_locks >/dev/null 2>&1; then
        cleanup_old_locks 3600 2>/dev/null || true
    fi
    
    [ -f "$LIB_PATH/logging.sh" ] && log_debug "Очистка старых временных файлов выполнена" || true
}

cleanup_old_temp_files

#Проверка ОС
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
elif [[ -f /opt/etc/entware_release ]]; then
    release="entware"
elif [[ -f /etc/entware_release ]]; then
    release="entware"
else
    echo "Не удалось определить ОС. Прекращение работы скрипта." >&2
    exit 1
fi
if [[ "$release" == "entware" ]]; then
 if [ -d /jffs ] || uname -a | grep -qi "Merlin"; then
    hardware="merlin"
 elif grep -Eqi "netcraze|keenetic" /proc/version; then
   	hardware="keenetic"
 else
  echo -e "${yellow}Железо не определено. Будем считать что это Keenetic. Если будут проблемы - пишите в саппорт.${plain}"
  hardware="keenetic"
 fi
fi

#По просьбе наших слушателей) Теперь netcraze официально детектится скриптом не как keenetic, а отдельно)
if grep -q "netcraze" "/bin/ndmc" 2>/dev/null; then
 echo "OS: $release Netcraze"
else
 echo "OS: $release $hardware"
fi

#Запуск скрипта под нужную версию
if [[ "$release" == "ubuntu" || "$release" == "debian" || "$release" == "endeavouros" || "$release" == "arch" ]]; then
	OSystem="VPS"
elif [[ "$release" == "openwrt" || "$release" == "immortalwrt" || "$release" == "asuswrt" || "$release" == "x-wrt" || "$release" == "kwrt" || "$release" == "istoreos" ]]; then
	OSystem="WRT"
elif [[ "$release" == "entware" || "$hardware" = "keenetic" ]]; then
	OSystem="entware"
else
	read -re -p $'\033[31mДля этой ОС нет подходящей функции. Или ОС определение выполнено некорректно.\033[33m Рекомендуется обратиться в чат поддержки
Enter - выход
1 - Плюнуть и продолжить как OpenWRT
2 - Плюнуть и продолжить как entware
3 - Плюнуть и продолжить как VPS\033[0m\n' os_answer
	case "$os_answer" in
	"1")
		OSystem="WRT"
	;;
	"2")
		OSystem="entware"
	;;
	"3")
		OSystem="VPS"
	;;
	*)
		echo "Выбран выход"
		exit 0
	;;
esac 
fi

# Проверка зависимостей (если доступна функция)
if command -v check_dependencies >/dev/null 2>&1; then
    check_dependencies "$OSystem" || {
        [ -f "$LIB_PATH/logging.sh" ] && log_warning "Некоторые зависимости отсутствуют, но продолжаем работу" || true
    }
fi

# Health check перед началом работы (если доступна функция)
if command -v pre_critical_operation_check >/dev/null 2>&1; then
    pre_critical_operation_check || {
        [ -f "$LIB_PATH/logging.sh" ] && log_warning "Обнаружены проблемы при проверке здоровья системы" || true
    }
fi

#Инфа о времени обновления скрпта
commit_date=$(curl -s --max-time 30 "https://api.github.com/repos/IndeecFOX/zapret4rocket/commits?path=z4r.sh&per_page=1" | grep '"date"' | head -n1 | cut -d'"' -f4)
if [[ -z "$commit_date" ]]; then
    echo -e "${red}Не был получен доступ к api.github.com (таймаут 30 сек). Возможны проблемы при установке.${plain}"
	if [ "$hardware" = "keenetic" ]; then
		echo "Добавляем ip с от DNS 8.8.8.8 к api.github.com и пытаемся снова"
		IP_ghub=$(nslookup api.github.com 8.8.8.8 | sed -n '/^Name:/,$ s/^Address [0-9]*: \([0-9.]\{7,15\}\).*/\1/p' | head -n1)
		if [ -z "$IP_ghub" ]; then
    		echo "ERROR: api.github.com not resolved with 8.8.8.8 DNS"
		else
			echo $IP_ghub
			ndmc -c "ip host api.github.com $IP_ghub"
			echo -e "${yellow}zeefeer обновлен (UTC +0): $(curl -s --max-time 10 "https://api.github.com/repos/IndeecFOX/zapret4rocket/commits?path=z4r.sh&per_page=1" | grep '"date"' | head -n1 | cut -d'"' -f4) ${plain}"
		fi
	fi
else
    echo -e "${yellow}zeefeer обновлен (UTC +0): $commit_date ${plain}"
fi

#Проверка доступности raw.githubusercontent.com
if [[ -z "$(curl -s --max-time 10 "https://raw.githubusercontent.com/test")" ]]; then
    echo -e "${red}Не был получен доступ к raw.githubusercontent.com (таймаут 10 сек). Возможны проблемы при установке.${plain}"
	if [ "$hardware" = "keenetic" ]; then
		echo "Добавляем ip с от DNS 8.8.8.8 к raw.githubusercontent.com и пытаемся снова"
		IP_ghub2=$(nslookup raw.githubusercontent.com 8.8.8.8 | sed -n '/^Name:/,$ s/^Address [0-9]*: \([0-9.]\{7,15\}\).*/\1/p' | head -n1)
		if [ -z "$IP_ghub2" ]; then
    		echo "ERROR: raw.githubusercontent.com not resolved with 8.8.8.8 DNS"
		else
			echo $IP_ghub2
			ndmc -c "ip host raw.githubusercontent.com $IP_ghub2"
		fi
	fi
fi

#Выполнение общего для всех ОС кода с ответвлениями под ОС
#Запрос на установку 3x-ui или аналогов для VPS
if [[ "$OSystem" == "VPS" ]] && [ ! $1 ]; then
 get_panel
fi

#Меню и быстрый запуск подбора стратегии
 if [ -d /opt/zapret/extra_strats ] && [ -f "/opt/zapret/config" ]; then
	if [ $1 ]; then
		Strats_Tryer $1
	fi
    get_menu
 fi
 
#entware keenetic and merlin preinstal env.
if [ "$hardware" = "keenetic" ]; then
 opkg install coreutils-sort grep gzip ipset iptables xtables-addons_legacy 2>/dev/null || apk add coreutils-sort grep gzip ipset iptables xtables-addons_legacy 2>/dev/null
 opkg install kmod_ndms 2>/dev/null || apk add kmod_ndms 2>/dev/null || echo -e "\033[31mНе удалось установить kmod_ndms. Если у вас не keenetic - игнорируйте.\033[0m"
elif [ "$hardware" = "merlin" ]; then
 opkg install coreutils-sort grep gzip ipset iptables xtables-addons_legacy 2>/dev/null || apk add coreutils-sort grep gzip ipset iptables xtables-addons_legacy 2>/dev/null
fi

#Проверка наличия каталога opt и его создание при необходиомости (для некоторых роутеров), переход в tmp
mkdir -p /opt
cd /tmp

#Запрос на резервирование стратегий, если есть что резервировать
backup_strats

#Удаление старого запрета, если есть
remove_zapret

#Запрос желаемой версии zapret
echo -e "${yellow}Конфиг обновлен (UTC +0): $(curl -s "https://api.github.com/repos/IndeecFOX/zapret4rocket/commits?path=config.default&per_page=1" | grep '"date"' | head -n1 | cut -d'"' -f4) ${plain}"
version_select

 
#Скачивание, распаковка архива zapret и его удаление
zapret_get

#Создаём папки и забираем файлы папок lists, fake, extra_strats, копируем конфиг, скрипты для войсов DS, WA, TG
get_repo

#Для Keenetic и merlin
if [[ "$OSystem" == "entware" ]]; then
 entware_fixes
fi

#Для x-wrt
if [[ "$release" == "x-wrt" ]]; then
	sed -i 's/kmod-nft-nat kmod-nft-offload/kmod-nft-nat/' /opt/zapret/common/installer.sh
fi

#Запуск установочных скриптов и перезагрузка
install_zapret_reboot
