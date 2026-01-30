# z4r (zeefeer) — архив для Koviand/z4r_web

Все файлы для установки по цепочке:
**bootstrap (branch 4) → z4r (installer) → zapret4rocket** из репозитория **Koviand/z4r_web**, ветка **4**.

## Структура проекта

```
z2r_mod/
├── z4r/
│   ├── bootstrap-z4r   # Однострочник: скачивает z4r и запускает
│   └── z4r             # Установщик (качает zapret4rocket, запускает z4r.sh)
│
├── zapret4rocket/
│   ├── z4r.sh
│   ├── config.default
│   ├── lib/            # 9 .sh библиотек
│   ├── lists/          # 6 .txt листов
│   ├── extra_strats/   # UDP/YT, TCP/RKN, TCP/YT List.txt
│   ├── www/            # Веб-панель (index.html, cgi-bin/status.sh, action.sh)
│   ├── fake_files.tar.gz
│   ├── init.d/
│   │   ├── sysv/custom.d/
│   │   ├── openwrt/custom.d/
│   │   └── custom.d.examples.linux/
│   ├── Entware/
│   └── docs/
│
└── README.md
```

## Команда установки

На целевом устройстве (роутер, VPS, WSL):

```bash
curl -o z4r https://raw.githubusercontent.com/Koviand/z4r_web/4/z4r/bootstrap-z4r && sh z4r
```

Прямой запуск без сохранения файла:

```bash
curl -sSL https://raw.githubusercontent.com/Koviand/z4r_web/4/z4r/bootstrap-z4r | sh
```

## Использование

Скрипты рассчитаны на Linux/OpenWrt (opkg, apt, apk, bash, пути `/opt`).  
После пуша в **Koviand/z4r_web** (ветка **4**) команда выше тянет bootstrap → z4r → zapret4rocket и веб-панель из этого репозитория.
