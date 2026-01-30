#!/bin/bash
# Скрипт установки веб-интерфейса для z4r

# Используем set -e для строгой проверки ошибок, но обрабатываем ошибки установки pip отдельно
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
WEB_DIR="$SCRIPT_DIR/web"
SERVICE_NAME="z4r-web"

# Цвета для вывода
green='\033[0;32m'
yellow='\033[0;33m'
red='\033[0;31m'
plain='\033[0m'

echo -e "${green}=== Установка веб-интерфейса z4r ===${plain}"

# Проверка Python 3
if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${red}Ошибка: Python 3 не найден. Установите Python 3 и повторите попытку.${plain}"
    exit 1
fi

PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
echo -e "${yellow}Найден Python ${PYTHON_VERSION}${plain}"

# Проверка pip
if ! command -v pip3 >/dev/null 2>&1 && ! command -v pip >/dev/null 2>&1; then
    echo -e "${yellow}pip не найден. Устанавливаю pip...${plain}"
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y python3-pip
    elif command -v opkg >/dev/null 2>&1; then
        opkg install python3-pip
    elif command -v apk >/dev/null 2>&1; then
        apk add python3 py3-pip
    else
        echo -e "${red}Не удалось установить pip автоматически. Установите pip вручную.${plain}"
        exit 1
    fi
fi

# Определение команды pip
PIP_CMD="pip3"
if ! command -v pip3 >/dev/null 2>&1; then
    PIP_CMD="pip"
fi

# Установка зависимостей
echo -e "${yellow}Установка зависимостей Python...${plain}"
set +e  # Временно отключаем set -e для установки pip
$PIP_CMD install --upgrade pip || true
if ! $PIP_CMD install flask flask-cors; then
    echo -e "${red}Ошибка установки зависимостей. Попробуйте установить вручную:${plain}"
    echo -e "${yellow}$PIP_CMD install flask flask-cors${plain}"
    exit 1
fi
set -e  # Включаем обратно set -e

# Проверка наличия веб-директории
if [ ! -d "$WEB_DIR" ]; then
    echo -e "${red}Ошибка: директория web/ не найдена в $SCRIPT_DIR${plain}"
    exit 1
fi

# Создание конфигурационного файла
WEB_CONFIG="$SCRIPT_DIR/web_config.json"
if [ ! -f "$WEB_CONFIG" ]; then
    echo -e "${yellow}Создание конфигурационного файла...${plain}"
    cat > "$WEB_CONFIG" <<EOF
{
    "port": 17681,
    "host": "0.0.0.0",
    "debug": false
}
EOF
    echo -e "${green}Конфигурационный файл создан: $WEB_CONFIG${plain}"
fi

# Определение типа системы
if [ -f /etc/systemd/system/z4r.service ] || systemctl list-units | grep -q z4r; then
    SYSTEM_TYPE="systemd"
elif [ -f /etc/init.d/z4r ] || [ -d /etc/init.d ]; then
    SYSTEM_TYPE="initd"
elif command -v opkg >/dev/null 2>&1; then
    SYSTEM_TYPE="openwrt"
else
    SYSTEM_TYPE="unknown"
fi

echo -e "${yellow}Тип системы: $SYSTEM_TYPE${plain}"

# Создание systemd сервиса
if [ "$SYSTEM_TYPE" = "systemd" ]; then
    echo -e "${yellow}Создание systemd сервиса...${plain}"
    
    cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=z4r Web Interface
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$WEB_DIR
ExecStart=$(which python3) $WEB_DIR/app.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME}
    echo -e "${green}Systemd сервис создан и включен${plain}"

# Создание init.d скрипта
elif [ "$SYSTEM_TYPE" = "initd" ] || [ "$SYSTEM_TYPE" = "openwrt" ]; then
    echo -e "${yellow}Создание init.d скрипта...${plain}"
    
    INIT_SCRIPT="/etc/init.d/${SERVICE_NAME}"
    if [ "$SYSTEM_TYPE" = "openwrt" ] && [ -d /opt/etc/init.d ]; then
        INIT_SCRIPT="/opt/etc/init.d/S99${SERVICE_NAME}"
    fi
    
    cat > "$INIT_SCRIPT" <<EOF
#!/bin/sh /etc/rc.common
# z4r Web Interface

START=99

start_service() {
    cd $WEB_DIR
    $(which python3) $WEB_DIR/app.py > /tmp/${SERVICE_NAME}.log 2>&1 &
    echo \$! > /var/run/${SERVICE_NAME}.pid
}

stop_service() {
    if [ -f /var/run/${SERVICE_NAME}.pid ]; then
        kill \$(cat /var/run/${SERVICE_NAME}.pid) 2>/dev/null || true
        rm -f /var/run/${SERVICE_NAME}.pid
    else
        pkill -f "python3.*app.py" || true
    fi
}

restart() {
    stop_service
    sleep 1
    start_service
}
EOF

    chmod +x "$INIT_SCRIPT"
    
    if [ "$SYSTEM_TYPE" = "openwrt" ]; then
        $INIT_SCRIPT enable || true
    fi
    
    echo -e "${green}Init.d скрипт создан: $INIT_SCRIPT${plain}"
else
    echo -e "${yellow}Не удалось определить тип системы. Запуск вручную:${plain}"
    echo -e "${yellow}cd $WEB_DIR && python3 app.py${plain}"
fi

# Проверка порта
PORT=$(grep -o '"port"[[:space:]]*:[[:space:]]*[0-9]*' "$WEB_CONFIG" | grep -o '[0-9]*' || echo "17681")
echo -e "${yellow}Веб-интерфейс будет доступен на порту: $PORT${plain}"

# Запуск сервиса
if [ "$SYSTEM_TYPE" = "systemd" ]; then
    echo -e "${yellow}Запуск сервиса...${plain}"
    systemctl start ${SERVICE_NAME} || {
        echo -e "${red}Ошибка запуска сервиса. Проверьте логи: journalctl -u ${SERVICE_NAME}${plain}"
        exit 1
    }
    sleep 2
    
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        echo -e "${green}Сервис успешно запущен${plain}"
    else
        echo -e "${red}Сервис не запущен. Проверьте логи: journalctl -u ${SERVICE_NAME}${plain}"
        exit 1
    fi
elif [ -f "$INIT_SCRIPT" ]; then
    echo -e "${yellow}Запуск сервиса...${plain}"
    $INIT_SCRIPT start || {
        echo -e "${yellow}Попробуйте запустить вручную: $INIT_SCRIPT start${plain}"
    }
fi

# Проверка доступности
sleep 2
if command -v curl >/dev/null 2>&1; then
    if curl -s --max-time 3 "http://localhost:$PORT/api/status/zapret" >/dev/null 2>&1; then
        echo -e "${green}Веб-интерфейс доступен на http://localhost:$PORT${plain}"
    else
        echo -e "${yellow}Веб-интерфейс может быть недоступен. Проверьте вручную.${plain}"
    fi
fi

echo -e "${green}=== Установка завершена ===${plain}"
echo -e "${yellow}Веб-интерфейс доступен по адресу: http://<ваш_ip>:$PORT${plain}"
