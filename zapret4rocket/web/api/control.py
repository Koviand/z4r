#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Control API - управление zapret
"""

from flask import Blueprint, jsonify, request
from web.utils import shell_exec

bp = Blueprint('control', __name__)


@bp.route('/start', methods=['POST'])
def start_zapret():
    """Запустить zapret"""
    result = shell_exec.control_zapret('start')
    return jsonify(result)


@bp.route('/stop', methods=['POST'])
def stop_zapret():
    """Остановить zapret"""
    result = shell_exec.control_zapret('stop')
    return jsonify(result)


@bp.route('/restart', methods=['POST'])
def restart_zapret():
    """Перезапустить zapret"""
    result = shell_exec.control_zapret('restart')
    return jsonify(result)
