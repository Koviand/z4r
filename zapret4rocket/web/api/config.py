#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Config API - управление конфигурацией
"""

import os
import re
from flask import Blueprint, jsonify, request
from web.utils import shell_exec

bp = Blueprint('config', __name__)

CONFIG_PATH = '/opt/zapret/config'

def get_config_path():
    """Получить путь к конфигурационному файлу"""
    if os.path.exists(CONFIG_PATH):
        return CONFIG_PATH
    # Альтернативные пути
    alt_paths = ['/opt/zapret/config.default']
    for path in alt_paths:
        if os.path.exists(path):
            return path
    return CONFIG_PATH


@bp.route('/get', methods=['GET'])
def get_config():
    """Получить конфигурацию"""
    config_path = get_config_path()
    config_content = shell_exec.read_file_safe(config_path)
    if config_content is None:
        return jsonify({'error': 'Config file not found or too large'}), 404
    
    return jsonify({
        'content': config_content,
        'path': get_config_path()
    })


@bp.route('/update', methods=['POST'])
def update_config():
    """
    Обновить конфигурацию
    Ожидает JSON: {"content": "config file content"}
    """
    data = request.get_json() or {}
    content = data.get('content', '')
    
    if not content:
        return jsonify({'success': False, 'error': 'Content is required'}), 400
    
    # Безопасная запись конфигурации
    try:
        config_path = get_config_path()
        # Создаем бэкап
        backup_path = f'{config_path}.backup'
        if os.path.exists(config_path):
            shell_exec.safe_execute(['cp', config_path, backup_path])
        
        # Записываем новую конфигурацию
        with open(config_path, 'w', encoding='utf-8') as f:
            f.write(content)
        
        return jsonify({
            'success': True,
            'message': 'Config updated successfully'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@bp.route('/toggle/<setting>', methods=['POST'])
def toggle_setting(setting):
    """
    Переключить настройку
    Поддерживаемые: fwtype, bolvan, udp_range
    """
    if setting == 'fwtype':
        # Переключение между iptables и nftables
        current = shell_exec.get_config_value('FWTYPE')
        new_value = 'nftables' if current == 'iptables' else 'iptables'
        
        # Обновляем конфигурацию через sed
        config_path = get_config_path()
        exit_code, stdout, stderr = shell_exec.safe_execute([
            'sed', '-i', f's/^FWTYPE=.*/FWTYPE={new_value}/', config_path
        ])
        
        if exit_code == 0:
            # Перезапускаем zapret
            shell_exec.control_zapret('restart')
            return jsonify({
                'success': True,
                'message': f'FWTYPE switched to {new_value}',
                'value': new_value
            })
        else:
            return jsonify({
                'success': False,
                'error': stderr
            }), 500
    
    elif setting == 'bolvan':
        # Переключение режима bol-van
        udp_ports = shell_exec.get_config_value('NFQWS_PORTS_UDP') or ''
        
        if '443,1400' in udp_ports:
            # Переключаем на скрипты
            config_path = get_config_path()
            shell_exec.safe_execute([
                'sed', '-i', 's/443,1400,3478-3481,5349,50000-50099,19294-19344$/443/', config_path
            ])
            shell_exec.safe_execute([
                'sed', '-i', 's/^--filter-udp=50000/--skip --filter-udp=50000/', config_path
            ])
            shell_exec.control_zapret('restart')
            return jsonify({
                'success': True,
                'message': 'Switched to bol-van scripts mode',
                'mode': 'scripts'
            })
        else:
            # Переключаем на классические стратегии
            config_path = get_config_path()
            shell_exec.safe_execute([
                'sed', '-i', 's/NFQWS_PORTS_UDP=443$/NFQWS_PORTS_UDP=443,1400,3478-3481,5349,50000-50099,19294-19344/', config_path
            ])
            shell_exec.safe_execute([
                'sed', '-i', 's/^--skip --filter-udp=50000/--filter-udp=50000/', config_path
            ])
            shell_exec.control_zapret('restart')
            return jsonify({
                'success': True,
                'message': 'Switched to classic strategies mode',
                'mode': 'classic'
            })
    
    elif setting == 'udp_range':
        # Переключение UDP диапазона
        udp_ports = shell_exec.get_config_value('NFQWS_PORTS_UDP') or ''
        config_path = get_config_path()
        
        if '1026-65531' in udp_ports:
            # Отключаем диапазон
            shell_exec.safe_execute([
                'sed', '-i', 's/NFQWS_PORTS_UDP=1026-65531,443/NFQWS_PORTS_UDP=443/', config_path
            ])
            shell_exec.safe_execute([
                'sed', '-i', 's/^--filter-udp=1026/--skip --filter-udp=1026/', config_path
            ])
            shell_exec.control_zapret('restart')
            return jsonify({
                'success': True,
                'message': 'UDP range disabled',
                'enabled': False
            })
        else:
            # Включаем диапазон
            shell_exec.safe_execute([
                'sed', '-i', 's/NFQWS_PORTS_UDP=443/NFQWS_PORTS_UDP=1026-65531,443/', config_path
            ])
            shell_exec.safe_execute([
                'sed', '-i', 's/^--skip --filter-udp=1026/--filter-udp=1026/', config_path
            ])
            shell_exec.control_zapret('restart')
            return jsonify({
                'success': True,
                'message': 'UDP range enabled',
                'enabled': True
            })
    
    else:
        return jsonify({
            'success': False,
            'error': f'Unknown setting: {setting}'
        }), 400
