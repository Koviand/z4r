#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Безопасное выполнение shell команд для веб-интерфейса z4r
"""

import subprocess
import os
import re
import json
import logging
from typing import Dict, List, Optional, Tuple

# Настройка логирования
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Пути к скриптам (определяются динамически при первом использовании)
def _get_zapret_paths():
    """Определяет пути к файлам zapret"""
    # Пробуем стандартные пути
    paths = {
        'z4r_script': '/opt/zapret/z4r.sh',
        'zapret_init': '/opt/zapret/init.d/sysv/zapret',
        'zapret_config': '/opt/zapret/config',
        'zapret_lists': '/opt/zapret/lists',
        'zapret_strats': '/opt/zapret/extra_strats',
    }
    
    # Проверяем существование и корректируем при необходимости
    if not os.path.exists(paths['zapret_init']):
        # Альтернативные пути
        alt_init = '/opt/zapret/init.d/openwrt/zapret'
        if os.path.exists(alt_init):
            paths['zapret_init'] = alt_init
    
    return paths

# Инициализация путей (ленивая загрузка)
_ZAPRET_PATHS_CACHE = None

def _get_path(key):
    """Получить путь к файлу zapret"""
    global _ZAPRET_PATHS_CACHE
    if _ZAPRET_PATHS_CACHE is None:
        _ZAPRET_PATHS_CACHE = _get_zapret_paths()
    return _ZAPRET_PATHS_CACHE.get(key, '')

# Константы для обратной совместимости
Z4R_SCRIPT = '/opt/zapret/z4r.sh'
ZAPRET_INIT = '/opt/zapret/init.d/sysv/zapret'
ZAPRET_CONFIG = '/opt/zapret/config'
ZAPRET_LISTS_DIR = '/opt/zapret/lists'
ZAPRET_STRATS_DIR = '/opt/zapret/extra_strats'

# Безопасные команды (whitelist)
SAFE_COMMANDS = {
    'pidof': ['pidof'],
    'grep': ['grep'],
    'cat': ['cat'],
    'sed': ['sed'],
    'head': ['head'],
    'tail': ['tail'],
    'wc': ['wc'],
    'ls': ['ls'],
    'test': ['test'],
    'stat': ['stat'],
}


def sanitize_input(text: str, max_length: int = 1000) -> str:
    """
    Санитизация пользовательского ввода
    """
    if not isinstance(text, str):
        return ""
    
    # Ограничение длины
    text = text[:max_length]
    
    # Удаление опасных символов
    text = re.sub(r'[;&|`$(){}[\]<>]', '', text)
    
    return text.strip()


def validate_domain(domain: str) -> bool:
    """
    Валидация доменного имени
    """
    if not domain or len(domain) > 255:
        return False
    
    # Простая валидация домена
    pattern = r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$'
    return bool(re.match(pattern, domain))


def safe_execute(command: List[str], cwd: Optional[str] = None, 
                 timeout: int = 30, shell: bool = False) -> Tuple[int, str, str]:
    """
    Безопасное выполнение команды
    
    Returns:
        (exit_code, stdout, stderr)
    """
    try:
        # Валидация команды
        if not command or not isinstance(command, list):
            return (1, "", "Invalid command")
        
        # Проверка на опасные команды (базовая валидация)
        # Для безопасности мы разрешаем только определенные команды
        # Но для гибкости проверяем только критичные случаи
        cmd_name = command[0] if command else ""
        
        # Блокируем опасные команды
        dangerous_commands = ['rm', 'dd', 'mkfs', 'fdisk', 'shutdown', 'reboot', 'halt']
        if cmd_name in dangerous_commands:
            logger.warning(f"Blocked dangerous command: {cmd_name}")
            return (1, "", f"Dangerous command blocked: {cmd_name}")
        
        result = subprocess.run(
            command,
            cwd=cwd,
            timeout=timeout,
            shell=shell,
            capture_output=True,
            text=True,
            encoding='utf-8',
            errors='replace'
        )
        
        return (result.returncode, result.stdout, result.stderr)
    
    except subprocess.TimeoutExpired:
        logger.error(f"Command timeout: {' '.join(command)}")
        return (1, "", "Command timeout")
    except Exception as e:
        logger.error(f"Error executing command: {e}")
        return (1, "", str(e))


def source_shell_function(script_path: str, function_name: str, *args) -> Tuple[int, str]:
    """
    Вызов функции из shell скрипта через bash -c
    
    Args:
        script_path: путь к shell скрипту
        function_name: имя функции
        *args: аргументы функции
    
    Returns:
        (exit_code, output)
    """
    # Санитизация аргументов
    safe_args = [sanitize_input(str(arg)) for arg in args]
    
    # Создание команды для вызова функции
    cmd = f'source "{script_path}" && {function_name} {" ".join(safe_args)}'
    
    result = subprocess.run(
        ['bash', '-c', cmd],
        capture_output=True,
        text=True,
        timeout=60,
        encoding='utf-8',
        errors='replace'
    )
    
    return (result.returncode, result.stdout)


def get_zapret_status() -> Dict:
    """
    Получить статус zapret (запущен/остановлен)
    """
    exit_code, stdout, stderr = safe_execute(['pidof', 'nfqws'])
    is_running = exit_code == 0 and stdout.strip() != ""
    
    return {
        'running': is_running,
        'pid': stdout.strip() if is_running else None
    }


def get_strategies_info() -> Dict:
    """
    Получить информацию о текущих стратегиях
    Вызывает get_current_strategies_info из lib/strategies.sh
    """
    # Определяем пути к библиотекам
    script_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    lib_path = os.path.join(script_dir, 'lib')
    
    # Альтернативный путь
    if not os.path.exists(lib_path):
        lib_path = '/opt/zapret/lib'
    
    # Проверяем наличие файлов стратегий напрямую
    strategies = {
        'yt_udp': 'Def',
        'yt_tcp': 'Def',
        'yt_gv': 'Def',
        'rkn': 'Def'
    }
    
    # Проверяем UDP/YT стратегии (1-8)
    udp_path = '/opt/zapret/extra_strats/UDP/YT'
    if os.path.exists(udp_path):
        for i in range(1, 9):
            strat_file = os.path.join(udp_path, f'{i}.txt')
            if os.path.exists(strat_file) and os.path.getsize(strat_file) > 0:
                strategies['yt_udp'] = str(i)
                break
    
    # Проверяем TCP/YT стратегии (1-17)
    tcp_yt_path = '/opt/zapret/extra_strats/TCP/YT'
    if os.path.exists(tcp_yt_path):
        for i in range(1, 18):
            strat_file = os.path.join(tcp_yt_path, f'{i}.txt')
            if os.path.exists(strat_file) and os.path.getsize(strat_file) > 0:
                strategies['yt_tcp'] = str(i)
                break
    
    # Проверяем TCP/GV стратегии (1-17)
    tcp_gv_path = '/opt/zapret/extra_strats/TCP/GV'
    if os.path.exists(tcp_gv_path):
        for i in range(1, 18):
            strat_file = os.path.join(tcp_gv_path, f'{i}.txt')
            if os.path.exists(strat_file) and os.path.getsize(strat_file) > 0:
                strategies['yt_gv'] = str(i)
                break
    
    # Проверяем TCP/RKN стратегии (1-17)
    tcp_rkn_path = '/opt/zapret/extra_strats/TCP/RKN'
    if os.path.exists(tcp_rkn_path):
        for i in range(1, 18):
            strat_file = os.path.join(tcp_rkn_path, f'{i}.txt')
            if os.path.exists(strat_file) and os.path.getsize(strat_file) > 0:
                strategies['rkn'] = str(i)
                break
    
    return strategies


def get_provider_info() -> Dict:
    """
    Получить информацию о провайдере
    """
    cache_file = "/opt/zapret/extra_strats/cache/provider.txt"
    provider_info = {
        'provider': 'Не определён',
        'city': '',
        'full': 'Не определён'
    }
    
    if os.path.exists(cache_file):
        try:
            with open(cache_file, 'r', encoding='utf-8') as f:
                content = f.read().strip()
                if content:
                    provider_info['full'] = content
                    # Парсим формат "Provider - City"
                    parts = content.split(' - ', 1)
                    if len(parts) == 2:
                        provider_info['provider'] = parts[0]
                        provider_info['city'] = parts[1]
                    else:
                        provider_info['provider'] = content
        except Exception as e:
            logger.error(f"Error reading provider cache: {e}")
    
    return provider_info


def control_zapret(action: str) -> Dict:
    """
    Управление zapret (start/stop/restart)
    
    Args:
        action: 'start', 'stop', 'restart'
    """
    if action not in ['start', 'stop', 'restart']:
        return {'success': False, 'error': 'Invalid action'}
    
    # Определяем путь к init скрипту
    init_script = _get_path('zapret_init')
    if not init_script or not os.path.exists(init_script):
        # Пробуем альтернативные пути
        alt_paths = [
            '/opt/zapret/init.d/sysv/zapret',
            '/opt/zapret/init.d/openwrt/zapret',
        ]
        init_script = None
        for path in alt_paths:
            if os.path.exists(path):
                init_script = path
                break
        
        if not init_script:
            return {'success': False, 'error': 'Zapret init script not found'}
    
    exit_code, stdout, stderr = safe_execute([init_script, action], timeout=30)
    
    return {
        'success': exit_code == 0,
        'output': stdout,
        'error': stderr if exit_code != 0 else None
    }


def get_config_value(key: str) -> Optional[str]:
    """
    Получить значение из конфигурации
    """
    config_path = _get_path('zapret_config') or ZAPRET_CONFIG
    if not os.path.exists(config_path):
        return None
    
    exit_code, stdout, stderr = safe_execute(
        ['grep', f'^{key}=', config_path]
    )
    
    if exit_code == 0 and stdout:
        # Извлекаем значение после =
        match = re.search(r'=(.+)$', stdout.strip())
        if match:
            return match.group(1).strip()
    
    return None


def read_file_safe(file_path: str, max_size: int = 1024 * 1024) -> Optional[str]:
    """
    Безопасное чтение файла
    """
    if not os.path.exists(file_path):
        return None
    
    # Проверка размера файла
    try:
        size = os.path.getsize(file_path)
        if size > max_size:
            return None
    except:
        return None
    
    try:
        with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
            return f.read()
    except Exception as e:
        logger.error(f"Error reading file {file_path}: {e}")
        return None
