backup_strats() {
  # Бэкап папки стратегий
  if [ -d /opt/zapret/extra_strats ]; then
    echo -e "${yellow}Сделать бэкап /opt/zapret/extra_strats ?${plain}"
    echo -e "${yellow}5 - Да, Enter - Нет, 0 - отмена${plain}"
    read -r ans
    if [ "$ans" = "0" ]; then
        get_menu # сигнал “отмена/в меню”
    fi
    if [ "$ans" = "5" ] || [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
      # Используем атомарное копирование если доступно
      local backup_dir="/opt/extra_strats"
      local temp_backup="/tmp/extra_strats_backup_$$"
      
      # Копируем во временную директорию
      if cp -rf /opt/zapret/extra_strats "$temp_backup" 2>/dev/null; then
        # Атомарное перемещение
        rm -rf "$backup_dir" 2>/dev/null || true
        mv -f "$temp_backup" "$backup_dir" 2>/dev/null || {
          rm -rf "$temp_backup" 2>/dev/null || true
          [ -f "$LIB_PATH/logging.sh" ] && log_error "Не удалось создать бэкап extra_strats" || true
          echo -e "${red}Ошибка создания бэкапа${plain}"
          return 1
        }
        
        # Проверка успешности бэкапа
        if [ -d "$backup_dir" ] && [ "$(ls -A "$backup_dir" 2>/dev/null | wc -l)" -gt 0 ]; then
          [ -f "$LIB_PATH/logging.sh" ] && log_info "Бэкап extra_strats сохранён в $backup_dir" || true
          echo -e "${green}Бэкап extra_strats сохранён в /opt/extra_strats${plain}"
        else
          [ -f "$LIB_PATH/logging.sh" ] && log_error "Бэкап extra_strats пуст или повреждён" || true
          echo -e "${red}Ошибка: бэкап пуст или повреждён${plain}"
          return 1
        fi
      else
        [ -f "$LIB_PATH/logging.sh" ] && log_error "Не удалось скопировать extra_strats для бэкапа" || true
        echo -e "${red}Ошибка создания бэкапа${plain}"
        return 1
      fi
    fi
  fi

  # Бэкап листа исключений
  if [ -f /opt/zapret/lists/netrogat.txt ]; then
    echo -e "${yellow}Сделать бэкап /opt/zapret/lists/netrogat.txt ?${plain}"
    echo -e "${yellow}5 - Да, Enter - Нет, 0 - отмена и выход в меню${plain}"
    read -r ans2
    if [ "$ans2" = "0" ]; then
      get_menu
    fi
    if [ "$ans2" = "5" ] || [ "$ans2" = "y" ] || [ "$ans2" = "Y" ]; then
      local backup_file="/opt/netrogat.txt"
      
      # Используем атомарное копирование если доступно
      if command -v atomic_copy >/dev/null 2>&1; then
        if atomic_copy "/opt/zapret/lists/netrogat.txt" "$backup_file"; then
          # Проверка успешности
          if [ -f "$backup_file" ] && [ -s "$backup_file" ]; then
            [ -f "$LIB_PATH/logging.sh" ] && log_info "Бэкап netrogat.txt сохранён в $backup_file" || true
            echo -e "${green}Бэкап netrogat.txt сохранён в /opt/netrogat.txt${plain}"
          else
            [ -f "$LIB_PATH/logging.sh" ] && log_error "Бэкап netrogat.txt пуст или повреждён" || true
            echo -e "${red}Ошибка: бэкап пуст или повреждён${plain}"
            return 1
          fi
        else
          [ -f "$LIB_PATH/logging.sh" ] && log_error "Не удалось создать бэкап netrogat.txt" || true
          echo -e "${red}Ошибка создания бэкапа${plain}"
          return 1
        fi
      else
        # Fallback на обычное копирование
        local temp_backup="/tmp/netrogat_backup_$$.txt"
        if cp -f /opt/zapret/lists/netrogat.txt "$temp_backup" 2>/dev/null && [ -f "$temp_backup" ]; then
          mv -f "$temp_backup" "$backup_file" 2>/dev/null || {
            rm -f "$temp_backup" 2>/dev/null || true
            [ -f "$LIB_PATH/logging.sh" ] && log_error "Не удалось переместить бэкап netrogat.txt" || true
            return 1
          }
          if [ -f "$backup_file" ] && [ -s "$backup_file" ]; then
            echo -e "${green}Бэкап netrogat.txt сохранён в /opt/netrogat.txt${plain}"
          else
            echo -e "${red}Ошибка: бэкап пуст или повреждён${plain}"
            return 1
          fi
        else
          [ -f "$LIB_PATH/logging.sh" ] && log_error "Не удалось скопировать netrogat.txt для бэкапа" || true
          return 1
        fi
      fi
    fi
  fi

  # Ротация старых бэкапов (оставляем только последние 5)
  local backup_base="/opt"
  if [ -f "$backup_base/netrogat.txt" ]; then
    # Ротация файлов бэкапов (netrogat.txt.1, netrogat.txt.2 и т.д.)
    for i in $(seq 4 -1 1); do
      if [ -f "$backup_base/netrogat.txt.$i" ]; then
        mv -f "$backup_base/netrogat.txt.$i" "$backup_base/netrogat.txt.$((i + 1))" 2>/dev/null || true
      fi
    done
    if [ -f "$backup_base/netrogat.txt" ]; then
      cp -f "$backup_base/netrogat.txt" "$backup_base/netrogat.txt.1" 2>/dev/null || true
    fi
    # Удаляем старые бэкапы (старше 5)
    rm -f "$backup_base/netrogat.txt".{6..10} 2>/dev/null || true
  fi

  return 0
}


menu_action_update_config_reset() {
  echo -e "${yellow}Конфиг обновлен (UTC +0): $(curl -s "https://api.github.com/repos/IndeecFOX/zapret4rocket/commits?path=config.default&per_page=1" | grep '"date"' | head -n1 | cut -d'"' -f4) ${plain}"

  backup_strats

  /opt/zapret/init.d/sysv/zapret stop

  rm -rf /opt/zapret/lists /opt/zapret/extra_strats

  rm -f /opt/zapret/files/fake/http_fake_MS.bin \
        /opt/zapret/files/fake/quic_{1..7}.bin \
        /opt/zapret/files/fake/syn_packet.bin \
        /opt/zapret/files/fake/tls_clienthello_{1..18}.bin \
        /opt/zapret/files/fake/tls_clienthello_2n.bin \
        /opt/zapret/files/fake/tls_clienthello_6a.bin \
        /opt/zapret/files/fake/tls_clienthello_4pda_to.bin

  get_repo

  # Раскомменчивание юзера под keenetic или merlin
  change_user

  cp -f /opt/zapret/config.default /opt/zapret/config

  /opt/zapret/init.d/sysv/zapret start

  # ВАЖНО: check_access_list — это по сути интерактивный тест (он сам печатает и может ждать Enter),
  # поэтому лучше вызывать его из get_menu отдельным пунктом ("01"), а не тут.
  # check_access_list

  echo -e "${green}Config файл обновлён. Листы подбора стратегий и исключений сброшены в дефолт, если не просили сохранить. Фейк файлы обновлены.${plain}"
  return 0
}

menu_action_toggle_bolvan_ports() {
  if grep -Eq '^NFQWS_PORTS_UDP=.*443$' "/opt/zapret/config"; then
    sed -i '76s/443$/443,1400,3478-3481,5349,50000-50099,19294-19344/' /opt/zapret/config
    sed -i 's/^--skip --filter-udp=50000/--filter-udp=50000/' "/opt/zapret/config"

    rm -f /opt/zapret/init.d/sysv/custom.d/50-discord-media \
          /opt/zapret/init.d/sysv/custom.d/50-stun4all \
          /opt/zapret/init.d/openwrt/custom.d/50-stun4all \
          /opt/zapret/init.d/openwrt/custom.d/50-discord-media

    echo -e "${green}Уход от скриптов bol-van. Выделены порты 50000-50099,1400,3478-3481,5349 и раскомментированы стратегии DS, WA, TG${plain}"

  elif grep -q '443,1400,3478-3481,5349,50000-50099,19294-19344$' "/opt/zapret/config"; then
    sed -i 's/443,1400,3478-3481,5349,50000-50099,19294-19344$/443/' /opt/zapret/config
    sed -i 's/^--filter-udp=50000/--skip --filter-udp=50000/' "/opt/zapret/config"

    curl -L -o /opt/zapret/init.d/sysv/custom.d/50-stun4all \
      https://raw.githubusercontent.com/bol-van/zapret/master/init.d/custom.d.examples.linux/50-stun4all
    curl -L -o /opt/zapret/init.d/sysv/custom.d/50-discord-media \
      https://raw.githubusercontent.com/bol-van/zapret/master/init.d/custom.d.examples.linux/50-discord-media

    cp -f /opt/zapret/init.d/sysv/custom.d/50-stun4all /opt/zapret/init.d/openwrt/custom.d/50-stun4all
    cp -f /opt/zapret/init.d/sysv/custom.d/50-discord-media /opt/zapret/init.d/openwrt/custom.d/50-discord-media

    echo -e "${green}Работа от скриптов bol-van. Вернули строку к виду NFQWS_PORTS_UDP=443 и добавили \"--skip \" в начале строк стратегии войса${plain}"
  else
    echo -e "${yellow}Неизвестное состояние строки NFQWS_PORTS_UDP. Проверь конфиг вручную.${plain}"
    return 0
  fi

  /opt/zapret/init.d/sysv/zapret restart
  echo -e "${green}Выполнение переключений завершено.${plain}"
  return 0
}

menu_action_toggle_fwtype() {
  if grep -q '^FWTYPE=iptables$' "/opt/zapret/config"; then
    sed -i 's/^FWTYPE=iptables$/FWTYPE=nftables/' "/opt/zapret/config"
    /opt/zapret/install_prereq.sh
    /opt/zapret/init.d/sysv/zapret restart
    echo -e "${green}Zapret moode: nftables.${plain}"

  elif grep -q '^FWTYPE=nftables$' "/opt/zapret/config"; then
    sed -i 's/^FWTYPE=nftables$/FWTYPE=iptables/' "/opt/zapret/config"
    /opt/zapret/install_prereq.sh
    /opt/zapret/init.d/sysv/zapret restart
    echo -e "${green}Zapret moode: iptables.${plain}"

  else
    echo -e "${yellow}Неизвестное состояние строки FWTYPE. Проверь конфиг вручную.${plain}"
  fi

  return 0
}

menu_action_toggle_udp_range() {
  if grep -q '^NFQWS_PORTS_UDP=443' "/opt/zapret/config"; then
    sed -i 's/^NFQWS_PORTS_UDP=443/NFQWS_PORTS_UDP=1026-65531,443/' "/opt/zapret/config"
    sed -i 's/^--skip --filter-udp=1026/--filter-udp=1026/' "/opt/zapret/config"
    echo -e "${green}Стратегия UDP обхода активирована. Выделены порты 1026-65531${plain}"

  elif grep -q '^NFQWS_PORTS_UDP=1026-65531,443' "/opt/zapret/config"; then
    sed -i 's/^NFQWS_PORTS_UDP=1026-65531,443/NFQWS_PORTS_UDP=443/' "/opt/zapret/config"
    sed -i 's/^--filter-udp=1026/--skip --filter-udp=1026/' "/opt/zapret/config"
    echo -e "${green}Стратегия UDP обхода ДЕактивирована. Выделенные порты 1026-65531 убраны${plain}"

  else
    echo -e "${yellow}Неизвестное состояние строки NFQWS_PORTS_UDP. Проверь конфиг вручную.${plain}"
    return 0
  fi

  /opt/zapret/init.d/sysv/zapret restart
  echo -e "${green}Выполнение переключений завершено.${plain}"
  return 0
}
