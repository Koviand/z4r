# Локальный архив установки z4r (zeefeer)

Копия всех файлов, необходимых для установки z4r по цепочке:
**bootstrap (branch 4) → installer (main) → zapret4rocket (master)**.

Оригинальная структура репозиториев сохранена.

## Структура проекта

```
z2r_mod/
├── z4r/                    # IndeecFOX/z4r
│   ├── bootstrap-z4r        # Скрипт с branch 4 (однострочник по ссылке)
│   └── z4r                 # Установщик с main
│
├── zapret4rocket/           # IndeecFOX/zapret4rocket (master)
│   ├── z4r.sh
│   ├── config.default
│   ├── lib/                # 9 .sh библиотек
│   ├── lists/              # 6 .txt листов
│   ├── extra_strats/       # UDP/YT, TCP/RKN, TCP/YT List.txt
│   ├── fake_files.tar.gz
│   ├── init.d/
│   │   ├── sysv/custom.d/      # 50-stun4all, 50-discord-media (bol-van/zapret)
│   │   ├── openwrt/custom.d/  # копии тех же
│   │   └── custom.d.examples.linux/  # 10-keenetic-udp-fix (bol-van/zapret)
│   ├── Entware/            # zapret, 000-zapret.sh, S00fix
│   └── docs/               # del.proxyauth, 3proxy.cfg (для установки 3proxy)
│
└── README.md
```

## Источники

| Компонент | Репозиторий / ветка |
|-----------|----------------------|
| bootstrap-z4r | IndeecFOX/z4r, branch 4 |
| z4r (installer) | IndeecFOX/z4r, main |
| z4r.sh, config.default, lib/, lists/, extra_strats/, Entware/ | IndeecFOX/zapret4rocket, master |
| fake_files.tar.gz | IndeecFOX/zapret4rocket, master |
| 50-stun4all, 50-discord-media | bol-van/zapret, master |
| 10-keenetic-udp-fix | bol-van/zapret, master |
| del.proxyauth, 3proxy.cfg | IndeecFOX/zapret4rocket, master (docs/) |

## Использование

Скрипты рассчитаны на Linux/OpenWrt (opkg, apt, apk, bash, пути `/opt`).  
Эта папка — архив для установки; запуск `sh z4r` выполняется на целевом устройстве (роутер, VPS, WSL и т.п.).

При необходимости можно доработать установщик для развёртывания из локальной копии вместо загрузки из интернета.
