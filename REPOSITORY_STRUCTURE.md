# Структура оригинального репозитория

## Репозиторий: IndeecFOX/z4r
**Ветка:** `4` (начальный скрипт) и `main` (основной скрипт)

### Файлы в корне репозитория z4r:

```
z4r/                          # Репозиторий z4r
├── z4r                       # Начальный bootstrap скрипт (ветка 4)
└── z4r.sh                    # Основной скрипт (ветка main)
```

---

## Репозиторий: IndeecFOX/zapret4rocket
**Ветка:** `master`

### Структура репозитория zapret4rocket:

```
zapret4rocket/
├── z4r.sh                    # Основной скрипт установки и управления
├── config.default             # Конфигурационный файл по умолчанию
├── recommendations.txt        # База рекомендаций по стратегиям
│
├── lib/                       # Библиотеки функций
│   ├── ui.sh                  # UI хелперы (pause_enter, submenu_item, exit_to_menu)
│   ├── provider.sh            # Определение провайдера/города
│   ├── telemetry.sh           # Анонимная статистика (Google Forms)
│   ├── recommendations.sh     # Обновление и показ рекомендаций
│   ├── netcheck.sh            # Проверка доступности сети
│   ├── premium.sh             # Premium функции (777/999)
│   ├── strategies.sh          # Логика работы со стратегиями
│   ├── submenus.sh            # Подменю (стратегии, FLOWOFFLOAD, TCP443, провайдер)
│   └── actions.sh             # Действия меню (бэкапы, переключатели)
│
├── lists/                     # Списки доменов и IP
│   ├── netrogat.txt           # Исключения из фильтрации
│   ├── russia-discord.txt     # Домены Discord
│   ├── russia-youtube.txt     # Домены YouTube (TCP)
│   ├── russia-youtubeQ.txt    # Домены YouTube (UDP QUIC)
│   ├── russia-youtube-rtmps.txt # IP-адреса YouTube RTMP(S)
│   └── tg_cidr.txt            # CIDR блоки Telegram
│
├── extra_strats/              # Дополнительные стратегии обхода
│   ├── UDP/
│   │   └── YT/
│   │       └── List.txt        # Список доменов для UDP QUIC YouTube
│   └── TCP/
│       ├── RKN/
│       │   └── List.txt       # Список доменов заблокированных сайтов (RKN)
│       └── YT/
│           └── List.txt       # Список доменов YouTube TCP
│
├── Entware/                   # Скрипты для Entware (Keenetic/Merlin)
│   ├── zapret                 # Init скрипт для zapret
│   ├── 000-zapret.sh          # Netfilter hook скрипт
│   └── S00fix                 # Исправление sysctl для nf_conntrack_checksum
│
└── fake_files.tar.gz          # Архив с fake файлами для обхода DPI
    └── files/fake/             # После распаковки
        ├── quic_*.bin          # Fake QUIC пакеты
        ├── tls_clienthello_*.bin # Fake TLS ClientHello
        ├── syn_packet.bin      # Fake SYN пакет
        └── http_fake_MS.bin    # Fake HTTP пакет
```

---

## URL структуры для скачивания

### Репозиторий z4r:
- Начальный скрипт: `https://raw.githubusercontent.com/IndeecFOX/z4r/4/z4r`
- Основной скрипт: `https://raw.githubusercontent.com/IndeecFOX/z4r/main/z4r`

### Репозиторий zapret4rocket:
- Основной скрипт: `https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/z4r.sh`
- Конфиг: `https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/config.default`
- Рекомендации: `https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/recommendations.txt`
- Списки доменов: `https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/lists/{filename}`
- Стратегии: `https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/extra_strats/{path}/List.txt`
- Fake файлы: `https://github.com/IndeecFOX/zapret4rocket/raw/master/fake_files.tar.gz`
- Entware скрипты: `https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/Entware/{filename}`

---

## Структура установки на целевом устройстве

После установки структура на устройстве:

```
/opt/
├── z4r.sh                     # Основной скрипт (временно, затем удаляется)
└── zapret/                     # Основная директория zapret
    ├── config                  # Активный конфиг (копия config.default)
    ├── config.default          # Конфиг по умолчанию
    │
    ├── lists/                  # Списки доменов
    │   ├── netrogat.txt
    │   ├── russia-discord.txt
    │   ├── russia-youtube.txt
    │   ├── russia-youtubeQ.txt
    │   ├── russia-youtube-rtmps.txt
    │   ├── tg_cidr.txt
    │   └── autohostlist.txt    # Автоматически генерируемый список
    │
    ├── extra_strats/           # Стратегии обхода
    │   ├── cache/              # Кэш файлы
    │   │   ├── provider.txt    # Кэш провайдера
    │   │   ├── recommendations.txt # Кэш рекомендаций
    │   │   ├── telemetry.config # Конфиг телеметрии
    │   │   ├── premium.enabled # Флаг premium
    │   │   └── premium.title   # Титул premium
    │   │
    │   ├── UDP/
    │   │   └── YT/
    │   │       ├── List.txt    # Исходный список
    │   │       └── {1..8}.txt  # Файлы активных стратегий
    │   │
    │   └── TCP/
    │       ├── RKN/
    │       │   ├── List.txt
    │       │   └── {1..17}.txt
    │       ├── YT/
    │       │   ├── List.txt
    │       │   └── {1..17}.txt
    │       ├── GV/
    │       │   └── {1..17}.txt # Стратегии для googlevideo.com
    │       ├── User/
    │       │   └── {1..17}.txt # Пользовательские домены
    │       └── temp/
    │           └── {1..17}.txt # Временные стратегии
    │
    ├── files/
    │   └── fake/               # Fake файлы для обхода DPI
    │       ├── quic_*.bin
    │       ├── tls_clienthello_*.bin
    │       ├── syn_packet.bin
    │       └── http_fake_MS.bin
    │
    ├── init.d/                 # Init скрипты
    │   ├── sysv/               # System V init
    │   │   ├── zapret          # Основной init скрипт
    │   │   └── custom.d/       # Кастомные скрипты
    │   │       ├── 50-stun4all
    │   │       └── 50-discord-media
    │   └── openwrt/            # OpenWRT init
    │       └── custom.d/
    │           ├── 50-stun4all
    │           └── 50-discord-media
    │
    └── [другие файлы zapret]   # Бинарники, скрипты установки и т.д.
```

### Для Entware (Keenetic/Merlin):

```
/opt/etc/
├── init.d/
│   ├── S90-zapret             # Симлинк на /opt/zapret/init.d/sysv/zapret
│   └── S99ttyd                # Web-SSH (если установлен)
└── ndm/
    └── netfilter.d/
        └── 000-zapret.sh      # Netfilter hook
```

---

## Примечания

1. **Ветки репозиториев:**
   - `z4r`: ветка `4` содержит начальный скрипт, ветка `main` содержит основной скрипт
   - `zapret4rocket`: ветка `master` содержит все файлы проекта

2. **Динамические файлы:**
   - Файлы `{1..8}.txt` и `{1..17}.txt` создаются динамически при подборе стратегий
   - `autohostlist.txt` генерируется автоматически при обнаружении недоступных доменов

3. **Кэш файлы:**
   - Все кэш файлы хранятся в `/opt/zapret/extra_strats/cache/`
   - `recommendations.txt` обновляется раз в 24 часа

4. **Бэкапы:**
   - Стратегии могут быть сохранены в `/opt/extra_strats` (вне zapret)
   - Исключения могут быть сохранены в `/opt/netrogat.txt`
