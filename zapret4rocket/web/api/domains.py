#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Domains API - управление доменами в исключениях
"""

import os
from flask import Blueprint, jsonify, request
from web.utils import shell_exec

bp = Blueprint('domains', __name__)

EXCLUSIONS_FILE = '/opt/zapret/lists/netrogat.txt'


@bp.route('/exclusions', methods=['GET'])
def get_exclusions():
    """Получить список доменов в исключениях"""
    content = shell_exec.read_file_safe(EXCLUSIONS_FILE, max_size=1024 * 1024)
    
    if content is None:
        return jsonify({'domains': []})
    
    # Парсим домены (по одному на строку)
    domains = [line.strip() for line in content.split('\n') if line.strip()]
    
    return jsonify({
        'domains': domains,
        'count': len(domains)
    })


@bp.route('/exclusions/add', methods=['POST'])
def add_exclusion():
    """
    Добавить домен в исключения
    Ожидает JSON: {"domain": "example.com"} или {"domains": ["example.com", "test.com"]}
    """
    data = request.get_json() or {}
    
    # Поддерживаем как один домен, так и список доменов
    domains = []
    if 'domain' in data:
        domains = [data['domain']]
    elif 'domains' in data:
        domains = data['domains']
    else:
        return jsonify({'success': False, 'error': 'Domain or domains required'}), 400
    
    # Валидация и добавление доменов
    added = []
    skipped = []
    
    for domain in domains:
        # Санитизация домена
        domain = shell_exec.sanitize_input(domain, max_length=255)
        
        # Удаляем протокол если есть
        domain = domain.replace('https://', '').replace('http://', '').rstrip('/')
        
        # Валидация
        if not shell_exec.validate_domain(domain):
            skipped.append(domain)
            continue
        
        # Проверяем, не добавлен ли уже
        if os.path.exists(EXCLUSIONS_FILE):
            with open(EXCLUSIONS_FILE, 'r', encoding='utf-8') as f:
                existing = f.read()
                if domain in existing:
                    skipped.append(domain)
                    continue
        
        # Добавляем домен
        try:
            with open(EXCLUSIONS_FILE, 'a', encoding='utf-8') as f:
                f.write(f'{domain}\n')
            added.append(domain)
        except Exception as e:
            skipped.append(f'{domain} (error: {str(e)})')
    
    return jsonify({
        'success': len(added) > 0,
        'added': added,
        'skipped': skipped,
        'added_count': len(added),
        'skipped_count': len(skipped)
    })


@bp.route('/exclusions/<domain>', methods=['DELETE'])
def delete_exclusion(domain):
    """Удалить домен из исключений"""
    if not os.path.exists(EXCLUSIONS_FILE):
        return jsonify({'success': False, 'error': 'Exclusions file not found'}), 404
    
    # Санитизация домена
    domain = shell_exec.sanitize_input(domain, max_length=255)
    
    # Читаем файл, удаляем домен, записываем обратно
    try:
        with open(EXCLUSIONS_FILE, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        # Удаляем строки с этим доменом
        filtered_lines = [line for line in lines if line.strip() != domain]
        
        if len(filtered_lines) == len(lines):
            return jsonify({
                'success': False,
                'error': 'Domain not found in exclusions'
            }), 404
        
        # Записываем обратно
        with open(EXCLUSIONS_FILE, 'w', encoding='utf-8') as f:
            f.writelines(filtered_lines)
        
        return jsonify({
            'success': True,
            'message': f'Domain {domain} removed from exclusions'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500
