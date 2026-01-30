#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Status API - получение статуса системы
"""

from flask import Blueprint, jsonify
from web.utils import shell_exec

bp = Blueprint('status', __name__)


@bp.route('/zapret', methods=['GET'])
def get_zapret_status():
    """Получить статус zapret"""
    status = shell_exec.get_zapret_status()
    return jsonify(status)


@bp.route('/strategies', methods=['GET'])
def get_strategies_status():
    """Получить текущие активные стратегии"""
    strategies = shell_exec.get_strategies_info()
    return jsonify(strategies)


@bp.route('/provider', methods=['GET'])
def get_provider_status():
    """Получить информацию о провайдере"""
    provider = shell_exec.get_provider_info()
    return jsonify(provider)


@bp.route('/config', methods=['GET'])
def get_config_status():
    """Получить текущие настройки конфигурации"""
    config_status = {
        'fwtype': shell_exec.get_config_value('FWTYPE') or 'Неизвестно',
        'flowoffload': shell_exec.get_config_value('FLOWOFFLOAD') or 'Неизвестно',
        'udp_ports': shell_exec.get_config_value('NFQWS_PORTS_UDP') or 'Неизвестно',
    }
    
    # Проверка режима bol-van
    udp_ports = config_status['udp_ports']
    if '443,1400,3478-3481,5349,50000-50099,19294-19344' in udp_ports:
        config_status['bolvan_mode'] = 'Классические стратегии'
    elif udp_ports == '443':
        config_status['bolvan_mode'] = 'Скрипты'
    else:
        config_status['bolvan_mode'] = 'Неизвестно'
    
    # Проверка UDP диапазона
    if '1026-65531' in udp_ports:
        config_status['udp_range_enabled'] = True
    else:
        config_status['udp_range_enabled'] = False
    
    return jsonify(config_status)


@bp.route('/all', methods=['GET'])
def get_all_status():
    """Получить весь статус системы"""
    # Получаем полную информацию о конфигурации
    udp_ports = shell_exec.get_config_value('NFQWS_PORTS_UDP') or 'Неизвестно'
    
    # Определяем режим bol-van
    bolvan_mode = 'Неизвестно'
    if '443,1400,3478-3481,5349,50000-50099,19294-19344' in udp_ports:
        bolvan_mode = 'Классические стратегии'
    elif udp_ports == '443':
        bolvan_mode = 'Скрипты'
    
    # Определяем UDP диапазон
    udp_range_enabled = '1026-65531' in udp_ports
    
    return jsonify({
        'zapret': shell_exec.get_zapret_status(),
        'strategies': shell_exec.get_strategies_info(),
        'provider': shell_exec.get_provider_info(),
        'config': {
            'fwtype': shell_exec.get_config_value('FWTYPE') or 'Неизвестно',
            'flowoffload': shell_exec.get_config_value('FLOWOFFLOAD') or 'Неизвестно',
            'udp_ports': udp_ports,
            'bolvan_mode': bolvan_mode,
            'udp_range_enabled': udp_range_enabled,
        }
    })
