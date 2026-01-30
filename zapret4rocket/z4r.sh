#!/bin/bash

set -e

#Переменная содержащая версию на случай невозможности получить информацию о lastest с github
DEFAULT_VER="72.6"

# Репозиторий для загрузки zapret4rocket (raw и API)
Z4R_REPO_RAW="https://raw.githubusercontent.com/Koviand/z4r_web/4/zapret4rocket"
Z4R_REPO_API="https://api.github.com/repos/Koviand/z4r_web/contents/zapret4rocket"

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

# Неинтерактивный режим: -y / --yes / --non-interactive
Z4R_NONINTERACTIVE=0
Z4R_ARGS=()
for arg in "$@"; do
  case "$arg" in
    -y|--yes|--non-interactive) Z4R_NONINTERACTIVE=1 ;;
    *) Z4R_ARGS+=("$arg") ;;
  esac
done
[ "$Z4R_NONINTERACTIVE" = "1" ] && export Z4R_NONINTERACTIVE
set -- "${Z4R_ARGS[@]}"

# Проверяем наличие всех нужных lib-файлов, иначе запускаем внешний скрипт
missing_libs=0
LIB_DIR="$SCRIPT_DIR/zapret/z4r_lib"
for lib in ui.sh provider.sh telemetry.sh recommendations.sh netcheck.sh premium.sh strategies.sh submenus.sh actions.sh; do
  if [ ! -f "$LIB_DIR/$lib" ]; then
    missing_libs=1
    break
  fi
done

if [ "$missing_libs" -ne 0 ]; then
  echo "Не найдены нужные файлы в $LIB_DIR. Запускаю внешний z4r..."
  if command -v curl >/dev/null 2>&1; then
    exec sh -c 'curl -fsSL "https://raw.githubusercontent.com/Koviand/z4r_web/4/z4r/z4r" | sh'
  elif command -v wget >/dev/null 2>&1; then
    exec sh -c 'wget -qO- "https://raw.githubusercontent.com/Koviand/z4r_web/4/z4r/z4r" | sh'
  else
    echo "Ошибка: нет curl или wget для загрузки внешнего z4r."
    exit 1
  fi
fi

#___Сначала идут анонсы функций____

# UI helpers (пауза/печать пунктов меню/совместимость старого кода)
# Функции: pause_enter, submenu_item, exit_to_menu
source "$SCRIPT_DIR/zapret/z4r_lib/ui.sh" 

# Определение провайдера/города + ручная установка/сброс кэша
# Функции: provider_init_once, provider_force_redetect, provider_set_manual_menu
# (внутр.: _detect_api_simple)
source "$SCRIPT_DIR/zapret/z4r_lib/provider.sh" 

# Телеметрия (вкл/выкл один раз + отправка статистики в Google Forms)
# Функции: init_telemetry, send_stats
source "$SCRIPT_DIR/zapret/z4r_lib/telemetry.sh" 

# База подсказок по стратегиям (скачивание + вывод подсказки по провайдеру)
# Функции: update_recommendations, show_hint
source "$SCRIPT_DIR/zapret/z4r_lib/recommendations.sh" 

# Проверка доступности ресурсов/сети (TLS 1.2/1.3) + получение домена кластера youtube (googlevideo)
# Функции: get_yt_cluster_domain, check_access, check_access_list
source "$SCRIPT_DIR/zapret/z4r_lib/netcheck.sh"

# “Premium” пункты 777/999 и их вспомогательные эффекты (рандом, спиннер, титулы)
# Функции: rand_from_list, spinner_for_seconds, premium_get_or_set_title, zefeer_premium_777, zefeer_space_999
source "$SCRIPT_DIR/zapret/z4r_lib/premium.sh" 

# Логика стратегий: определение активной стратегии, статус строкой, перебор стратегий, быстрый подбор
# Функции: get_active_strat_num, get_current_strategies_info, try_strategies, Strats_Tryer
source "$SCRIPT_DIR/zapret/z4r_lib/strategies.sh" 

# Подменю (UI-обвязка над Strats_Tryer + доп. меню управления: FLOWOFFLOAD, TCP443, провайдер)
# Функции: strategies_submenu, flowoffload_submenu, tcp443_submenu, provider_submenu
source "$SCRIPT_DIR/zapret/z4r_lib/submenus.sh" 

# Действия меню (бэкапы/сбросы/переключатели)
# Функции: backup_strats, menu_action_update_config_reset, menu_action_toggle_bolvan_ports,
#          menu_action_toggle_fwtype, menu_action_toggle_udp_range
source "$SCRIPT_DIR/zapret/z4r_lib/actions.sh" 

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
 for listfile in netrogat.txt russia-discord.txt russia-youtube-rtmps.txt russia-youtube.txt russia-youtubeQ.txt tg_cidr.txt; do curl -L -o /opt/zapret/lists/$listfile "$Z4R_REPO_RAW/lists/$listfile"; done
 curl -L "$Z4R_REPO_RAW/fake_files.tar.gz" | tar -xz -C /opt/zapret/files/fake
 curl -L -o /opt/zapret/extra_strats/UDP/YT/List.txt "$Z4R_REPO_RAW/extra_strats/UDP/YT/List.txt"
 curl -L -o /opt/zapret/extra_strats/TCP/RKN/List.txt "$Z4R_REPO_RAW/extra_strats/TCP/RKN/List.txt"
 curl -L -o /opt/zapret/extra_strats/TCP/YT/List.txt "$Z4R_REPO_RAW/extra_strats/TCP/YT/List.txt"
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
 curl -L -o /opt/zapret/config.default "$Z4R_REPO_RAW/config.default"
 if command -v nft >/dev/null 2>&1; then
  sed -i 's/^FWTYPE=iptables$/FWTYPE=nftables/' "/opt/zapret/config.default"
 fi
 curl -L -o /opt/zapret/init.d/sysv/custom.d/50-stun4all https://raw.githubusercontent.com/bol-van/zapret/master/init.d/custom.d.examples.linux/50-stun4all
 curl -L -o /opt/zapret/init.d/sysv/custom.d/50-discord-media https://raw.githubusercontent.com/bol-van/zapret/master/init.d/custom.d.examples.linux/50-discord-media
 cp -f /opt/zapret/init.d/sysv/custom.d/50-stun4all /opt/zapret/init.d/openwrt/custom.d/50-stun4all
 cp -f /opt/zapret/init.d/sysv/custom.d/50-discord-media /opt/zapret/init.d/openwrt/custom.d/50-discord-media

# cache
mkdir -p /opt/zapret/extra_strats/cache

# Веб-панель: доставка www (локальная копия или скачивание)
mkdir -p /opt/zapret/www /opt/zapret/www/cgi-bin
Z4R_RAW_URL="$Z4R_REPO_RAW"
if [ -d "$SCRIPT_DIR/www" ] && [ -f "$SCRIPT_DIR/www/index.html" ]; then
  cp -r "$SCRIPT_DIR/www"/* /opt/zapret/www/
else
  curl -sL -o /opt/zapret/www/index.html "$Z4R_RAW_URL/www/index.html"
  curl -sL -o /opt/zapret/www/cgi-bin/status.sh "$Z4R_RAW_URL/www/cgi-bin/status.sh"
  curl -sL -o /opt/zapret/www/cgi-bin/action.sh "$Z4R_RAW_URL/www/cgi-bin/action.sh"
fi
chmod +x /opt/zapret/www/cgi-bin/*.sh 2>/dev/null || true

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
   if [ "$Z4R_NONINTERACTIVE" = "1" ]; then
	VER=""
	lastest_release="https://api.github.com/repos/bol-van/zapret/releases/latest"
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
	return
   fi
   while true; do
	read -re -p $'\033[0;32mВведите желаемую версию zapret (Enter для новейшей версии): \033[0m' VER
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
 if [ "$Z4R_NONINTERACTIVE" = "1" ] && [ -f /opt/zapret/common/installer.sh ]; then
  sed -i 's/if \[ -n "\$1" \] || ask_yes_no N "do you want to continue";/if true;/' /opt/zapret/common/installer.sh
 fi
 if [ "$Z4R_NONINTERACTIVE" = "1" ]; then
  # Пустой stdin — каждый read получает Enter, везде используются дефолты (firewall type, фильтр, списки и т.д.)
  ( while true; do echo; done ) | sh -i /opt/zapret/install_easy.sh
 else
  sh -i /opt/zapret/install_easy.sh
 fi
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
  curl -L -o /opt/zapret/init.d/sysv/zapret "$Z4R_REPO_RAW/Entware/zapret"
  chmod +x /opt/zapret/init.d/sysv/zapret
  echo "Права выданы /opt/zapret/init.d/sysv/zapret"
  curl -L -o /opt/etc/ndm/netfilter.d/000-zapret.sh "$Z4R_REPO_RAW/Entware/000-zapret.sh"
  chmod +x /opt/etc/ndm/netfilter.d/000-zapret.sh
  echo "Права выданы /opt/etc/ndm/netfilter.d/000-zapret.sh"
  curl -L -o /opt/etc/init.d/S00fix "$Z4R_REPO_RAW/Entware/S00fix"
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
 clean_answer=$(echo "$answer_panel" | tr '[:lower:]' '[:upper:]')
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
    curl -L -o /etc/3proxy/.proxyauth "$Z4R_REPO_RAW/docs/del.proxyauth"
    curl -L -o /etc/3proxy/3proxy.cfg "$Z4R_REPO_RAW/docs/3proxy.cfg"
 elif [[ "$clean_answer" == "MARZBAN" ]]; then
     echo "Установка Marzban"
     bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install
 else
     echo "Пропуск установки ПО туннелирования."
 fi
}

# Веб-панель: развернуть www (если ещё нет) и запустить сервер на порту 17681
install_web_ui() {
 if [ ! -f /opt/zapret/www/index.html ]; then
  mkdir -p /opt/zapret/www /opt/zapret/www/cgi-bin
  Z4R_RAW_URL="${Z4R_RAW_URL:-$Z4R_REPO_RAW}"
  if [ -d "$SCRIPT_DIR/www" ] && [ -f "$SCRIPT_DIR/www/index.html" ]; then
   cp -r "$SCRIPT_DIR/www"/* /opt/zapret/www/
  else
   curl -sL -o /opt/zapret/www/index.html "$Z4R_RAW_URL/www/index.html"
   curl -sL -o /opt/zapret/www/cgi-bin/status.sh "$Z4R_RAW_URL/www/cgi-bin/status.sh"
   curl -sL -o /opt/zapret/www/cgi-bin/action.sh "$Z4R_RAW_URL/www/cgi-bin/action.sh"
  fi
  chmod +x /opt/zapret/www/cgi-bin/*.sh 2>/dev/null || true
 fi

 if [[ "$OSystem" == "VPS" ]]; then
  echo -e "${yellow}Настройка веб-панели для VPS${plain}"
  systemctl stop z4r-web 2>/dev/null || true
  HTTPD_CMD=""
  for cmd in busybox /usr/bin/busybox /opt/bin/busybox; do
   if command -v "$cmd" >/dev/null 2>&1 && $cmd httpd --help 2>&1 | grep -q '\-p'; then
    HTTPD_CMD="$cmd httpd -p 17681 -h /opt/zapret/www -c /cgi-bin"
    break
   fi
  done
  if [ -z "$HTTPD_CMD" ]; then
   echo -e "${yellow}busybox httpd не найден. Установите busybox-static или настройте nginx/apache с CGI для /opt/zapret/www.${plain}"
   return 0
  fi
  cat > /etc/systemd/system/z4r-web.service <<'SVC'
[Unit]
Description=z4r Web Panel
After=network.target

[Service]
ExecStart=/bin/sh -c 'B=$(command -v busybox 2>/dev/null || command -v /usr/bin/busybox 2>/dev/null || command -v /opt/bin/busybox 2>/dev/null); exec $B httpd -p 17681 -h /opt/zapret/www -c /cgi-bin'
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVC
  systemctl daemon-reload
  systemctl enable z4r-web
  systemctl start z4r-web
  echo -e "${green}Веб-панель: http://IP:17681${plain}"

 elif [[ "$OSystem" == "WRT" ]]; then
  echo -e "${yellow}Настройка веб-панели для OpenWrt (uhttpd)${plain}"
  if ! command -v uci >/dev/null 2>&1; then
   echo -e "${yellow}uhttpd/uci не найдены. Установите uhttpd и настройте вручную.${plain}"
   return 0
  fi
  uci add uhttpd uhttpd 2>/dev/null || true
  uci set uhttpd.@uhttpd[-1].listen_http='17681'
  uci set uhttpd.@uhttpd[-1].home='/opt/zapret/www'
  uci set uhttpd.@uhttpd[-1].cgi_prefix='/cgi-bin'
  uci commit uhttpd 2>/dev/null || true
  /etc/init.d/uhttpd restart 2>/dev/null || true
  echo -e "${green}Веб-панель: http://IP:17681${plain}"

 elif [[ "$OSystem" == "entware" ]]; then
  echo -e "${yellow}Настройка веб-панели для Entware${plain}"
  HTTPD_CMD=""
  for cmd in /opt/bin/busybox busybox; do
   if command -v "$cmd" >/dev/null 2>&1 && $cmd httpd --help 2>&1 | grep -q '\-p'; then
    HTTPD_CMD="$cmd httpd -p 17681 -h /opt/zapret/www -c /cgi-bin"
    break
   fi
  done
  if [ -z "$HTTPD_CMD" ]; then
   echo -e "${yellow}busybox httpd не найден. opkg install busybox.${plain}"
   return 0
  fi
  cat > /opt/etc/init.d/S99z4r-web <<'INIT'
#!/bin/sh
START=99
case "$1" in
  start)
    for b in /opt/bin/busybox busybox; do
      [ -x "$b" ] && $b httpd -p 17681 -h /opt/zapret/www -c /cgi-bin & break
    done
    ;;
  stop)
    pkill -f "httpd -p 17681" 2>/dev/null || killall httpd 2>/dev/null || true
    ;;
  restart) $0 stop; sleep 1; $0 start ;;
  *) echo "Usage: $0 {start|stop|restart}"; exit 1 ;;
esac
INIT
  chmod +x /opt/etc/init.d/S99z4r-web
  /opt/etc/init.d/S99z4r-web start
  echo -e "${green}Веб-панель: http://IP:17681${plain}"
 fi

 echo -e "${plain}Доступ: ${green}http://<IP_роутера_или_VPS>:17681${plain}"
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
13. Включить веб-панель (порт 17681)
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
    flowoffload_submenu   # сабменю само в цикле и выходит через return
    ;;

  "12")
    tcp443_submenu        # сабменю само в цикле и выходит через return
    ;;

  "13")
    install_web_ui
    pause_enter
    ;;

  "14")
    provider_submenu      # сабменю само в цикле и выходит через return
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
	if [ "$Z4R_NONINTERACTIVE" = "1" ]; then
		echo "Неизвестная ОС в неинтерактивном режиме. Продолжаем как OpenWRT."
		OSystem="WRT"
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
fi

#Инфа о времени обновления скрпта
commit_date=$(curl -s --max-time 30 "https://api.github.com/repos/Koviand/z4r_web/commits?path=zapret4rocket/z4r.sh&per_page=1" | grep '"date"' | head -n1 | cut -d'"' -f4)
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
			echo -e "${yellow}zeefeer обновлен (UTC +0): $(curl -s --max-time 10 "https://api.github.com/repos/Koviand/z4r_web/commits?path=zapret4rocket/z4r.sh&per_page=1" | grep '"date"' | head -n1 | cut -d'"' -f4) ${plain}"
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
if [[ "$OSystem" == "VPS" ]] && [ ! $1 ] && [ "$Z4R_NONINTERACTIVE" != "1" ]; then
 get_panel
fi

#Меню и быстрый запуск подбора стратегии
 if [ -d /opt/zapret/extra_strats ] && [ -f "/opt/zapret/config" ]; then
	if [ "$Z4R_NONINTERACTIVE" = "1" ]; then
		echo "Установка уже выполнена. Для меню запустите z4r без -y"
		exit 0
	fi
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
echo -e "${yellow}Конфиг обновлен (UTC +0): $(curl -s "https://api.github.com/repos/Koviand/z4r_web/commits?path=zapret4rocket/config.default&per_page=1" | grep '"date"' | head -n1 | cut -d'"' -f4) ${plain}"
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

#Запрос на установку веб-панели (после get_repo, чтобы www уже в /opt/zapret)
if [ "$Z4R_NONINTERACTIVE" = "1" ]; then
	web_ui_answer=""
else
	read -re -p $'\033[33mВключить веб-панель (порт 17681)? 1 - Да, Enter - нет\033[0m\n' web_ui_answer
fi
case "$web_ui_answer" in
	"1")
		install_web_ui
	;;
	*)
		echo "Пропуск установки веб-панели"
	;;
esac
