#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Strategies API - управление стратегиями
"""

import os
from flask import Blueprint, jsonify, request
from web.utils import shell_exec

bp = Blueprint('strategies', __name__)

STRATS_BASE = '/opt/zapret/extra_strats'


@bp.route('/list', methods=['GET'])
def list_strategies():
    """Получить список доступных стратегий"""
    strategies = {
        'udp_yt': {'count': 8, 'path': f'{STRATS_BASE}/UDP/YT'},
        'tcp_yt': {'count': 17, 'path': f'{STRATS_BASE}/TCP/YT'},
        'tcp_gv': {'count': 17, 'path': f'{STRATS_BASE}/TCP/GV'},
        'tcp_rkn': {'count': 17, 'path': f'{STRATS_BASE}/TCP/RKN'},
    }
    
    # Проверяем наличие файлов стратегий
    for key, info in strategies.items():
        active = []
        for i in range(1, info['count'] + 1):
            file_path = f"{info['path']}/{i}.txt"
            if os.path.exists(file_path) and os.path.getsize(file_path) > 0:
                active.append(i)
        strategies[key]['active'] = active
    
    return jsonify(strategies)


@bp.route('/current', methods=['GET'])
def get_current_strategies():
    """Получить текущие активные стратегии"""
    strategies = shell_exec.get_strategies_info()
    return jsonify(strategies)


@bp.route('/try', methods=['POST'])
def try_strategy():
    """
    Подобрать стратегию
    Ожидает JSON: {"type": "udp_yt|tcp_yt|tcp_gv|tcp_rkn|custom", "domain": "optional"}
    """
    data = request.get_json() or {}
    strategy_type = data.get('type', '')
    domain = data.get('domain', '')
    
    # Валидация
    valid_types = ['udp_yt', 'tcp_yt', 'tcp_gv', 'tcp_rkn', 'custom']
    if strategy_type not in valid_types:
        return jsonify({'success': False, 'error': 'Invalid strategy type'}), 400
    
    if strategy_type == 'custom' and not domain:
        return jsonify({'success': False, 'error': 'Domain required for custom strategy'}), 400
    
    # Вызов функции подбора стратегий через shell
    # Это требует интеграции с Strats_Tryer из lib/strategies.sh
    # Пока возвращаем заглушку
    return jsonify({
        'success': True,
        'message': 'Strategy selection initiated',
        'type': strategy_type,
        'domain': domain
    })


@bp.route('/set', methods=['POST'])
def set_strategy():
    """
    Установить стратегию
    Ожидает JSON: {"type": "udp_yt|tcp_yt|tcp_gv|tcp_rkn", "number": 1-17}
    """
    data = request.get_json() or {}
    strategy_type = data.get('type', '')
    number = data.get('number', 0)
    
    # Валидация
    type_map = {
        'udp_yt': ('UDP/YT', 8),
        'tcp_yt': ('TCP/YT', 17),
        'tcp_gv': ('TCP/GV', 17),
        'tcp_rkn': ('TCP/RKN', 17),
    }
    
    if strategy_type not in type_map:
        return jsonify({'success': False, 'error': 'Invalid strategy type'}), 400
    
    max_num = type_map[strategy_type][1]
    if not isinstance(number, int) or number < 1 or number > max_num:
        return jsonify({'success': False, 'error': f'Number must be between 1 and {max_num}'}), 400
    
    # Здесь должна быть логика установки стратегии
    # Пока возвращаем заглушку
    return jsonify({
        'success': True,
        'message': f'Strategy {strategy_type} set to {number}'
    })
