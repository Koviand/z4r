# zeefeer (z4r) — веб-панель и установка

Репозиторий **Koviand/z4r_web** (ветка **4**) для установки одной командой:

```bash
curl -o z4r https://raw.githubusercontent.com/Koviand/z4r_web/4/z4r/bootstrap-z4r && sh z4r
```

## Структура проекта (для репозитория z4r_web, ветка 4)

```
z4r_web/
├── z4r/
│   ├── bootstrap-z4r        # Однострочник: curl загружает этот файл как «z4r», затем sh z4r
│   └── z4r                  # Установщик: ставит команду z4r и качает zapret4rocket
│
├── zapret4rocket/
│   ├── z4r.sh
│   ├── config.default
│   ├── lib/                # 9 .sh библиотек
│   ├── web/                # Веб-панель (дашборд + API)
│   │   ├── index.html      # Интерактивная панель управления
│   │   ├── api.sh          # API: статус, старт/стоп/перезапуск
│   │   └── server.py       # Минимальный HTTP-сервер (порт 17682)
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

Все компоненты (z4r, zapret4rocket, веб-панель) загружаются из **Koviand/z4r_web** (ветка 4). Скрипты 50-stun4all, 50-discord-media — из bol-van/zapret; бинарники zapret — с GitHub releases.

## Использование

Скрипты рассчитаны на Linux/OpenWrt (opkg, apt, apk, bash, пути `/opt`).  
Эта папка — архив для установки; запуск `sh z4r` выполняется на целевом устройстве (роутер, VPS, WSL и т.п.).

При необходимости можно доработать установщик для развёртывания из локальной копии вместо загрузки из интернета.

### Веб-интерфейс

После установки в меню z4r пункт **13** включает:
- **Веб-панель** (порт 17682) — интерактивный дашборд: статус zapret, стратегии, провайдер, кнопки «Старт / Стоп / Перезапуск», ссылка на терминал.
- **Терминал в браузере (ttyd)** (порт 17681) — доступ к меню z4r через браузер.

Требуется **python3** для работы панели; без него будет доступен только ttyd на порту 17681.

## Синхронизация с репозиторием Git (z4r_web)

Чтобы выложить проект в **Koviand/z4r_web** и запускать установку указанной командой:

1. Инициализация и привязка к репозиторию (если ещё не сделано):
   ```bash
   git init
   git remote add origin https://github.com/Koviand/z4r_web.git
   ```
2. Ветка **4** должна содержать структуру: `z4r/bootstrap-z4r`, `z4r/z4r`, `zapret4rocket/` (z4r.sh, lib/, web/, lists/, config.default, Entware/, docs/, init.d/, extra_strats/), `zapret4rocket/fake_files.tar.gz`.
3. Публикация ветки 4:
   ```bash
   git checkout -b 4
   git add z4r/ zapret4rocket/ README.md
   git commit -m "feat: sync z4r_web for one-line install"
   git push -u origin 4
   ```

После этого установка выполняется командой:
```bash
curl -o z4r https://raw.githubusercontent.com/Koviand/z4r_web/4/z4r/bootstrap-z4r && sh z4r
```

## Команда автоматической установки

Установка полностью автоматическая, без запросов ввода (последняя версия zapret, без панели, без ttyd). Запуск выполняется на целевом устройстве (роутер, VPS, WSL и т.п.):

```bash
curl -o z4r https://raw.githubusercontent.com/Koviand/z4r_web/4/z4r/bootstrap-z4r && sh z4r
```

Или (если на ветке 4 в корне репозитория лежит файл `z4r` с bootstrap):

```bash
curl -O https://raw.githubusercontent.com/Koviand/z4r_web/4/z4r/z4r && sh z4r
```

Вариант без сохранения файла (прямой запуск):

```bash
curl -sSL https://raw.githubusercontent.com/Koviand/z4r_web/4/z4r/bootstrap-z4r | sh
```
