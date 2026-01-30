#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Flask веб-приложение для управления z4r
"""

import os
import json
from flask import Flask, jsonify, request, send_from_directory, render_template_string
from flask_cors import CORS

# Импорт утилит
import sys

# Добавляем текущую директорию в путь для импортов
current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.insert(0, current_dir)

from web.utils import shell_exec

# Определяем путь к статическим файлам
base_dir = os.path.dirname(os.path.abspath(__file__))
static_folder_path = os.path.join(base_dir, 'static')

app = Flask(__name__, 
            static_folder=static_folder_path,
            static_url_path='/static',
            template_folder=static_folder_path)
CORS(app)  # Разрешаем CORS для локального использования

# Конфигурация
app.config['JSON_AS_ASCII'] = False
app.config['JSONIFY_PRETTYPRINT_REGULAR'] = True

# Загрузка конфигурации веб-сервера
WEB_CONFIG_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'web_config.json')
WEB_CONFIG = {
    'port': 17681,
    'host': '0.0.0.0',
    'debug': False
}

if os.path.exists(WEB_CONFIG_PATH):
    try:
        with open(WEB_CONFIG_PATH, 'r', encoding='utf-8') as f:
            user_config = json.load(f)
            WEB_CONFIG.update(user_config)
    except Exception as e:
        print(f"Warning: Could not load web_config.json: {e}")


# Регистрация API роутов
try:
    from web.api import status, control, strategies, config, domains, monitoring
    
    app.register_blueprint(status.bp, url_prefix='/api/status')
    app.register_blueprint(control.bp, url_prefix='/api/control')
    app.register_blueprint(strategies.bp, url_prefix='/api/strategies')
    app.register_blueprint(config.bp, url_prefix='/api/config')
    app.register_blueprint(domains.bp, url_prefix='/api/domains')
    app.register_blueprint(monitoring.bp, url_prefix='/api/monitoring')
except ImportError as e:
    print(f"Warning: Could not import API modules: {e}")


@app.route('/')
def index():
    """Главная страница"""
    # Используем абсолютный путь к статическим файлам
    if app.static_folder and os.path.exists(app.static_folder):
        html_path = os.path.join(app.static_folder, 'index.html')
        if os.path.exists(html_path):
            with open(html_path, 'r', encoding='utf-8') as f:
                return f.read()
    return render_template_string('''
    <!DOCTYPE html>
    <html>
    <head>
        <title>z4r Web Interface</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
    </head>
    <body>
        <h1>z4r Web Interface</h1>
        <p>Веб-интерфейс загружается...</p>
        <script>
            window.location.reload();
        </script>
    </body>
    </html>
    ''')


@app.errorhandler(404)
def not_found(error):
    """Обработка 404 ошибок"""
    return jsonify({'error': 'Not found'}), 404


@app.errorhandler(500)
def internal_error(error):
    """Обработка 500 ошибок"""
    return jsonify({'error': 'Internal server error'}), 500


if __name__ == '__main__':
    app.run(
        host=WEB_CONFIG.get('host', '0.0.0.0'),
        port=WEB_CONFIG.get('port', 17681),
        debug=WEB_CONFIG.get('debug', False)
    )
