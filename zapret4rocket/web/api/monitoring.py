#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Monitoring API - мониторинг и проверка доступности
"""

import os
from flask import Blueprint, jsonify
from web.utils import shell_exec

bp = Blueprint('monitoring', __name__)


@bp.route('/check', methods=['GET'])
def check_access():
    """
    Проверить доступность сервисов
    Вызывает check_access_list из lib/netcheck.sh
    """
    # Определяем путь к библиотекам
    lib_path = '/opt/zapret/lib'
    if not os.path.exists(lib_path):
        script_dir = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
        lib_path = os.path.join(script_dir, 'lib')
    
    # Создаем команду для проверки доступности
    cmd = f'''
    export LIB_PATH="{lib_path}"
    if [ -f "{lib_path}/netcheck.sh" ]; then
        source "{lib_path}/netcheck.sh" 2>/dev/null || true
        check_access_list 2>&1
    else
        echo "Библиотека netcheck.sh не найдена"
    fi
    '''
    
    exit_code, stdout, stderr = shell_exec.safe_execute(['bash', '-c', cmd])
    
    # Парсим результаты (упрощенный вариант)
    results = {
        'youtube_com': {'status': 'unknown', 'message': ''},
        'youtube_cluster': {'status': 'unknown', 'message': ''},
        'meduza_io': {'status': 'unknown', 'message': ''},
        'instagram_com': {'status': 'unknown', 'message': ''},
    }
    
    # Простой парсинг вывода (можно улучшить)
    if 'Есть ответ' in stdout or 'green' in stdout.lower():
        # Упрощенная логика определения статуса
        pass
    
    return jsonify({
        'success': exit_code == 0,
        'output': stdout,
        'results': results
    })


@bp.route('/logs', methods=['GET'])
def get_logs():
    """Получить логи (если доступны)"""
    # Логи могут быть в разных местах в зависимости от системы
    log_paths = [
        '/var/log/zapret.log',
        '/opt/zapret/logs/zapret.log',
        '/tmp/zapret.log'
    ]
    
    logs = []
    for log_path in log_paths:
        content = shell_exec.read_file_safe(log_path, max_size=100 * 1024)  # 100KB
        if content:
            logs.append({
                'path': log_path,
                'content': content.split('\n')[-100:]  # Последние 100 строк
            })
    
    return jsonify({
        'logs': logs
    })
