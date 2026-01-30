#!/bin/bash

set -e

#Переменная содержащая версию на случай невозможности получить информацию о lastest с github
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

#___Переменные окружения для автоматической установки___#
# Z4R_INSTALL_MODE - режим установки (manual/minimal/standard/full)
# Z4R_ZAPRET_VERSION - версия zapret (если не указана, используется последняя)
# Z4R_INSTALL_PANEL - панель туннелирования (3xui/marzban/wg/3proxy, только для VPS)
# Z4R_TTYD_LOGIN - логин для ttyd (пустой = без логина, "0" = отключить ttyd)
INSTALL_MODE="${Z4R_INSTALL_MODE:-}"

#___Проверка на наличие необходимых библиотек___#

#Определяем путь скрипта, подгружаем функции
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

# Проверяем наличие всех нужных lib-файлов, иначе запускаем внешний скрипт
missing_libs=0
# Сначала проверяем структуру репозитория (lib/), затем структуру установки (zapret/z4r_lib/)
LIB_DIR=""
if [ -d "$SCRIPT_DIR/lib" ] && [ -f "$SCRIPT_DIR/lib/ui.sh" ]; then
 LIB_DIR="$SCRIPT_DIR/lib"
elif [ -d "$SCRIPT_DIR/zapret/z4r_lib" ] && [ -f "$SCRIPT_DIR/zapret/z4r_lib/ui.sh" ]; then
 LIB_DIR="$SCRIPT_DIR/zapret/z4r_lib"
else
 missing_libs=1
fi

# Проверяем наличие всех библиотек
if [ "$missing_libs" -eq 0 ]; then
 for lib in ui.sh provider.sh telemetry.sh recommendations.sh netcheck.sh premium.sh strategies.sh submenus.sh actions.sh; do
  if [ ! -f "$LIB_DIR/$lib" ]; then
   missing_libs=1
   break
  fi
 done
fi

if [ "$missing_libs" -ne 0 ]; then
 echo "Не найдены нужные файлы в $SCRIPT_DIR/lib или $SCRIPT_DIR/zapret/z4r_lib. Запускаю внешний z4r..."
 if command -v curl >/dev/null 2>&1; then
 exec sh -c 'curl -fsSL "https://raw.githubusercontent.com/IndeecFOX/z4r/main/z4r" | sh'
 elif command -v wget >/dev/null 2>&1; then
 exec sh -c 'wget -qO- "https://raw.githubusercontent.com/IndeecFOX/z4r/main/z4r" | sh'
 else
 echo "Ошибка: нет curl или wget для загрузки внешнего z4r."
 exit 1
 fi
fi

#___Сначала идут анонсы функций____

# UI helpers (пауза/печать пунктов меню/совместимость старого кода)
# Функции: pause_enter, submenu_item, exit_to_menu
source "$LIB_DIR/ui.sh" 

# Определение провайдера/города + ручная установка/сброс кэша
# Функции: provider_init_once, provider_force_redetect, provider_set_manual_menu
# (внутр.: _detect_api_simple)
source "$LIB_DIR/provider.sh" 

# Телеметрия (вкл/выкл один раз + отправка статистики в Google Forms)
# Функции: init_telemetry, send_stats
source "$LIB_DIR/telemetry.sh" 

# База подсказок по стратегиям (скачивание + вывод подсказки по провайдеру)
# Функции: update_recommendations, show_hint
source "$LIB_DIR/recommendations.sh" 

# Проверка доступности ресурсов/сети (TLS 1.2/1.3) + получение домена кластера youtube (googlevideo)
# Функции: get_yt_cluster_domain, check_access, check_access_list
source "$LIB_DIR/netcheck.sh"

# "Premium" пункты 777/999 и их вспомогательные эффекты (рандом, спиннер, титулы)
# Функции: rand_from_list, spinner_for_seconds, premium_get_or_set_title, zefeer_premium_777, zefeer_space_999
source "$LIB_DIR/premium.sh" 

# Логика стратегий: определение активной стратегии, статус строкой, перебор стратегий, быстрый подбор
# Функции: get_active_strat_num, get_current_strategies_info, try_strategies, Strats_Tryer
source "$LIB_DIR/strategies.sh" 

# Подменю (UI-обвязка над Strats_Tryer + доп. меню управления: FLOWOFFLOAD, TCP443, провайдер)
# Функции: strategies_submenu, flowoffload_submenu, tcp443_submenu, provider_submenu
source "$LIB_DIR/submenus.sh" 

# Действия меню (бэкапы/сбросы/переключатели)
# Функции: backup_strats, menu_action_update_config_reset, menu_action_toggle_bolvan_ports,
# menu_action_toggle_fwtype, menu_action_toggle_udp_range
source "$LIB_DIR/actions.sh" 

change_user() {
 if /opt/zapret/nfq/nfqws --dry-run --user="nobody" 2>&1 | grep -q "queue"; then
 echo "WS_USER=nobody"
 sed -i 's/^#\(WS_USER=nobody\)/\1/' /opt/zapret/config.default
 elif /opt/zapret/nfq/nfqws --dry-run --user="$(head -n1 /etc/passwd | cut -d: -f1)" 2>&1 | grep -q "queue"; then
 echo "WS_USER=$(head -n1 /etc/passwd | cut -d: -f1)"
 sed -i "s/^#WS_USER=nobody$/WS_USER=$(head -n1 /etc/passwd | cut -d: -f1)/" "/opt/zapret/config.default"
 else
 echo -e "${yellow}WS_USER не подошёл. Скорее всего будут проблемы. Если что - пишите в саппорт${plain}"
 fi
}

#Создаём папки и забираем файлы папок lists, fake, extra_strats, копируем конфиг, скрипты для войсов DS, WA, TG
get_repo() {
 mkdir -p /opt/zapret/lists /opt/zapret/extra_strats/TCP/{RKN,User,YT,temp,GV} /opt/zapret/extra_strats/UDP/YT
 for listfile in netrogat.txt russia-discord.txt russia-youtube-rtmps.txt russia-youtube.txt russia-youtubeQ.txt tg_cidr.txt; do curl -L -o /opt/zapret/lists/$listfile https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/lists/$listfile; done
 curl -L "https://github.com/IndeecFOX/zapret4rocket/raw/master/fake_files.tar.gz" | tar -xz -C /opt/zapret/files/fake
 curl -L -o /opt/zapret/extra_strats/UDP/YT/List.txt https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/extra_strats/UDP/YT/List.txt
 curl -L -o /opt/zapret/extra_strats/TCP/RKN/List.txt https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/extra_strats/TCP/RKN/List.txt
 curl -L -o /opt/zapret/extra_strats/TCP/YT/List.txt https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/extra_strats/TCP/YT/List.txt
 touch /opt/zapret/lists/autohostlist.txt /opt/zapret/extra_strats/UDP/YT/{1..8}.txt /opt/zapret/extra_strats/TCP/RKN/{1..17}.txt /opt/zapret/extra_strats/TCP/User/{1..17}.txt /opt/zapret/extra_strats/TCP/YT/{1..17}.txt /opt/zapret/extra_strats/TCP/GV/{1..17}.txt /opt/zapret/extra_strats/TCP/temp/{1..17}.txt
 if [ -d /opt/extra_strats ]; then
 rm -rf /opt/zapret/extra_strats
 mv /opt/extra_strats /opt/zapret/
 echo "Востановление настроек подбора из резерва выполнено."
 fi
 if [ -f "/opt/netrogat.txt" ]; then
 mv -f /opt/netrogat.txt /opt/zapret/lists/netrogat.txt
 echo "Востановление листа исключений выполнено."
 fi
 #Копирование нашего конфига на замену стандартному и скриптов для войсов DS, WA, TG
 curl -L -o /opt/zapret/config.default https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/config.default
 if command -v nft >/dev/null 2>&1; then
 sed -i 's/^FWTYPE=iptables$/FWTYPE=nftables/' "/opt/zapret/config.default"
 fi
 curl -L -o /opt/zapret/init.d/sysv/custom.d/50-stun4all https://raw.githubusercontent.com/bol-van/zapret/master/init.d/custom.d.examples.linux/50-stun4all
 curl -L -o /opt/zapret/init.d/sysv/custom.d/50-discord-media https://raw.githubusercontent.com/bol-van/zapret/master/init.d/custom.d.examples.linux/50-discord-media
 cp -f /opt/zapret/init.d/sysv/custom.d/50-stun4all /opt/zapret/init.d/openwrt/custom.d/50-stun4all
 cp -f /opt/zapret/init.d/sysv/custom.d/50-discord-media /opt/zapret/init.d/openwrt/custom.d/50-discord-media

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
 # Если версия задана через переменную окружения, используем её
 if [ -n "$Z4R_ZAPRET_VERSION" ]; then
  VER="$Z4R_ZAPRET_VERSION"
  echo -e "${green}Версия zapret задана через переменную окружения: $VER${plain}"
  return 0
 fi

 # В автоматическом режиме используем последнюю версию без запроса
 if [ "$INSTALL_MODE" != "manual" ] && [ -n "$INSTALL_MODE" ]; then
  echo -e "${yellow}Автоматический режим: используется последняя версия zapret${plain}"
  VER=""  # Устанавливаем пустую строку для автоматического получения последней версии
 fi

 while true; do
  # В ручном режиме запрашиваем версию
  if [ "$INSTALL_MODE" = "manual" ] || [ -z "$INSTALL_MODE" ]; then
   read -re -p $'\033[0;32mВведите желаемую версию zapret (Enter для новейшей версии): \033[0m' VER
  fi
  # Если пустой ввод — берем значение по умолчанию
  if [ -z "$VER" ]; then
 lastest_release="https://api.github.com/repos/bol-van/zapret/releases/latest"
 # проверяем результаты по порядку
 echo -e "${yellow}Поиск последней версии...${plain}"
 VER1=$(curl -sL $lastest_release | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
 if [ ${#VER1} -ge 2 ]; then
 VER="$VER1"
 echo -e "${green}Выбрано: $VER (метод: sed -E)${plain}"
 else
 VER2=$(curl -sL $lastest_release | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4 | sed 's/^v//')
 if [ ${#VER2} -ge 2 ]; then
 VER="$VER2"
 echo -e "${green}Выбрано: $VER (метод: grep+cut)${plain}"
 else
 VER3=$(curl -sL $lastest_release | grep '"tag_name":' | sed -r 's/.*"v([^"]+)".*/\1/')
 if [ ${#VER3} -ge 2 ]; then
 VER="$VER3"
 echo -e "${green}Выбрано: $VER (метод: sed -r)${plain}"
 else
 VER4=$(curl -sL $lastest_release | grep '"tag_name":' | awk -F'"' '{print $4}' | sed 's/^v//')
 if [ ${#VER4} -ge 2 ]; then
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
 #Считаем длину
 LEN=${#VER}
 #Проверка длины и простая валидация формата (цифры и точки)
 if [ "$LEN" -gt 4 ]; then
 echo "Некорректный ввод. Максимальная длина — 4 символа. Попробуйте снова."
 continue
 elif ! echo "$VER" | grep -Eq '^[0-9]+(\.[0-9]+)*$'; then
 echo "Некорректный формат версии. Пример: 72.3"
 continue
 fi
 echo "Будет использоваться версия: $VER"
 break
 done

 # В автоматическом режиме выходим после первого прохода
 if [ "$INSTALL_MODE" != "manual" ] && [ -n "$INSTALL_MODE" ]; then
  return 0
 fi
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
 local answer_panel=""
 local clean_answer=""

 # В автоматическом режиме "full" для VPS устанавливаем 3x-ui по умолчанию
 if [[ "$INSTALL_MODE" == "full" ]] && [[ "$OSystem" == "VPS" ]]; then
  if [ -n "$Z4R_INSTALL_PANEL" ]; then
   clean_answer=$(echo "$Z4R_INSTALL_PANEL" | tr '[:lower:]' '[:upper:]')
  else
   clean_answer="3XUI"
   echo -e "${green}Автоматический режим: установка панели 3x-ui${plain}"
  fi
 elif [[ "$INSTALL_MODE" != "manual" ]] && [[ -n "$INSTALL_MODE" ]]; then
  echo "Автоматический режим: установка панели туннелирования пропущена"
  return 0
 else
  # Ручной режим - запрашиваем у пользователя
  read -re -p $'\033[33mУстановить ПО для туннелирования?\033[0m \033[32m(3xui, marzban, wg, 3proxy или Enter для пропуска): \033[0m' answer_panel
  # Удаляем лишние символы и пробелы, приводим к верхнему регистру
  clean_answer=$(echo "$answer_panel" | tr '[:lower:]' '[:upper:]')
 fi

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

#webssh ttyd
ttyd_webssh() {
 local ttyd_login=""

 # В автоматическом режиме "standard" или "full" используем пустой логин
 if [[ "$INSTALL_MODE" == "standard" ]] || [[ "$INSTALL_MODE" == "full" ]]; then
  if [ -n "$Z4R_TTYD_LOGIN" ]; then
   ttyd_login="$Z4R_TTYD_LOGIN"
  else
   ttyd_login=""
   echo -e "${green}Автоматический режим: web-SSH без логина${plain}"
  fi
 elif [[ "$INSTALL_MODE" == "minimal" ]]; then
  echo "Автоматический режим минимальный: установка web-SSH пропущена"
  return 0
 else
  # Ручной режим - запрашиваем у пользователя
  echo -e $'\033[33mВведите логин для доступа к zeefeer через браузер (0 - отказ от логина через web в z4r и переход на логин в ssh (может помочь в safari). Enter - пустой логин, \033[31mно не рекомендуется, панель может быть доступна из интернета!)\033[0m'
  read -re -p '' ttyd_login
  echo -e "${yellow}Если вы открыли пункт через браузер - вас выкинет. Используйте SSH для установки${plain}"
 fi

 # Если логин = "0", отключаем ttyd
 if [[ "$ttyd_login" == "0" ]]; then
  echo "Отключение установки web-SSH"
  return 0
 fi
 
 # Формируем параметр для ttyd
 if [[ -z "$ttyd_login" ]]; then
  ttyd_login_have=""
 else
  ttyd_login_have="-c "${ttyd_login}": bash z4r"
 fi
 
 if [[ "$OSystem" == "VPS" ]]; then
 echo -e "${yellow}Установка ttyd for VPS${plain}"
 systemctl stop ttyd 2>/dev/null || true
 curl -L -o /usr/bin/ttyd https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.x86_64
 chmod +x /usr/bin/ttyd
 
 cat > /etc/systemd/system/ttyd.service <<EOF
[Unit]
Description=ttyd
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/ttyd -p 17681 -W ${ttyd_login_have} bash z4r
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
 systemctl daemon-reload
 systemctl enable ttyd
 systemctl start ttyd
 elif [[ "$OSystem" == "WRT" ]]; then
 echo -e "${yellow}Установка ttyd for OpenWRT${plain}"
 /etc/init.d/ttyd stop 2>/dev/null || true
 opkg install ttyd 2>/dev/null || apk add ttyd 2>/dev/null
 uci set ttyd.@ttyd[0].interface=''
 if [[ -n "$ttyd_login_have" ]]; then
  uci set ttyd.@ttyd[0].command="-p 17681 -W -a ${ttyd_login_have}"
 else
  uci set ttyd.@ttyd[0].command="-p 17681 -W"
 fi
 uci commit ttyd
 /etc/init.d/ttyd enable
 /etc/init.d/ttyd start
 elif [[ "$OSystem" == "entware" ]]; then
 echo -e "${yellow}Установка ttyd for Entware${plain}"
 /opt/etc/init.d/S99ttyd stop 2>/dev/null || true
 opkg install ttyd 2>/dev/null || apk add ttyd 2>/dev/null
 
 cat > /opt/etc/init.d/S99ttyd <<EOF
#!/bin/sh
ENABLED=yes
PROCS=ttyd
ARGS="-p 17681 -W ${ttyd_login_have} bash z4r"
PREARGS=""
DESC=\$PROCS
PATH=/opt/sbin:/opt/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

. /opt/etc/init.d/rc.func
EOF
 chmod +x /opt/etc/init.d/S99ttyd
 /opt/etc/init.d/S99ttyd enable
 /opt/etc/init.d/S99ttyd start
 fi
 
 if pidof ttyd >/dev/null; then
 echo -e "Проверка...${green}Служба ttyd запущена.${plain}"
 else
 echo -e "Проверка...${red}Служба ttyd не запущена! Если у вас Entware, то после перезагрузки роутера служба скорее всего заработает!${plain}"
 fi
 if [[ -n "$ttyd_login" ]]; then
  echo -e "${plain}Выполнение установки завершено. ${green}Доступ по ip вашего роутера/VPS в формате ip:17681, например 192.168.1.1:17681 или mydomain.com:17681 ${yellow}логин: ${ttyd_login} пароль - не используется.${plain} Был выполнен выход из скрипта для сохранения состояния."
 else
  echo -e "${plain}Выполнение установки завершено. ${green}Доступ по ip вашего роутера/VPS в формате ip:17681, например 192.168.1.1:17681 или mydomain.com:17681 ${yellow}без логина (не рекомендуется для публичных IP!).${plain} Был выполнен выход из скрипта для сохранения состояния."
 fi
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
13. Активировать доступ в меню через браузер (~3мб места)
14. Провайдер
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
 # подтверждение: выходим из get_menu и уходим в "тело" (переустановка/обновление)
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
 strategies_submenu # strategies_submenu сам в цикле и выходит через return
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
 user_domain="$(echo "$user_domain" | sed 's/[[:space:]]\+/\n/g')"
 if [ "$user_domain" == "0" ] ; then
 echo "Ввод отменён"
 elif [ -n "$user_domain" ]; then
 echo "$user_domain" >> /opt/zapret/lists/netrogat.txt
 echo -e "Домен ${yellow}$user_domain${plain} добавлен в исключения (netrogat.txt)."
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
 flowoffload_submenu # сабменю само в цикле и выходит через return
 ;;

 "12")
 tcp443_submenu # сабменю само в цикле и выходит через return
 ;;

 "13")
 ttyd_webssh
 pause_enter
 ;;

 "14")
 provider_submenu # сабменю само в цикле и выходит через return
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

#Выбор режима установки
select_install_mode() {
 # Если режим уже задан через переменную окружения, используем его
 if [ -n "$INSTALL_MODE" ]; then
  case "$INSTALL_MODE" in
   "manual"|"minimal"|"standard"|"full")
    echo -e "${green}Режим установки задан через переменную окружения: ${INSTALL_MODE}${plain}"
    return 0
    ;;
   *)
    echo -e "${yellow}Неизвестный режим установки: ${INSTALL_MODE}. Используется меню выбора.${plain}"
    INSTALL_MODE=""
    ;;
  esac
 fi

 # Если режим не задан, показываем меню выбора
 if [ -z "$INSTALL_MODE" ]; then
  echo ""
  echo -e "${cyan}=== Выбор режима установки ===${plain}"
  echo -e "${yellow}Выберите режим установки:${plain}"
  echo -e "  ${green}1${plain} - Ручная установка (все запросы интерактивные)"
  echo -e "  ${green}2${plain} - Минимальная автоматическая (только zapret)"
  echo -e "  ${green}3${plain} - Стандартная автоматическая (zapret + web-SSH без логина)"
  echo -e "  ${green}4${plain} - Полная автоматическая (zapret + web-SSH + панель туннелирования)"
  echo ""
  read -re -p "Ваш выбор (1-4, Enter для ручной): " mode_choice
  
  case "$mode_choice" in
   "1"|"")
    INSTALL_MODE="manual"
    ;;
   "2")
    INSTALL_MODE="minimal"
    ;;
   "3")
    INSTALL_MODE="standard"
    ;;
   "4")
    INSTALL_MODE="full"
    ;;
   *)
    echo -e "${yellow}Неверный выбор. Используется ручной режим.${plain}"
    INSTALL_MODE="manual"
    ;;
  esac
 fi

 echo -e "${green}Выбран режим: ${INSTALL_MODE}${plain}"
 echo ""
}

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

#Выбор режима установки (если zapret еще не установлен)
if [ ! -d /opt/zapret/extra_strats ] || [ ! -f "/opt/zapret/config" ]; then
 select_install_mode
fi

#Выполнение общего для всех ОС кода с ответвлениями под ОС
#Запрос на установку 3x-ui или аналогов для VPS
# В автоматическом режиме "full" панель устанавливается автоматически
if [[ "$OSystem" == "VPS" ]] && [ ! $1 ]; then
 if [[ "$INSTALL_MODE" == "full" ]]; then
  get_panel
 elif [[ "$INSTALL_MODE" == "manual" ]] || [ -z "$INSTALL_MODE" ]; then
  get_panel
 fi
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

#Запрос на установку web-ssh
# В автоматическом режиме "standard" или "full" устанавливаем ttyd автоматически
if [[ "$INSTALL_MODE" == "standard" ]] || [[ "$INSTALL_MODE" == "full" ]]; then
 echo -e "${green}Автоматический режим: установка web-SSH${plain}"
 ttyd_webssh
elif [[ "$INSTALL_MODE" == "minimal" ]]; then
 echo "Автоматический режим минимальный: установка web-SSH пропущена"
elif [[ "$INSTALL_MODE" == "manual" ]] || [ -z "$INSTALL_MODE" ]; then
 read -re -p $'\033[33mАктивировать доступ в меню через браузер (~3мб места)? 1 - Да, Enter - нет\033[0m\n' ttyd_answer
 case "$ttyd_answer" in
  "1")
  ttyd_webssh
  ;;
  *)
  echo "Пропуск (пере)установки web-терминала"
  ;;
 esac
fi 
 
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
