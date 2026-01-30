// API Base URL
const API_BASE = '/api';

// State
let currentStatus = {};
let updateInterval = null;

// Initialize
document.addEventListener('DOMContentLoaded', function() {
    initTabs();
    loadStatus();
    loadDomains();
    
    // Auto-refresh every 5 seconds
    updateInterval = setInterval(loadStatus, 5000);
});

// Tab Management
function initTabs() {
    const tabButtons = document.querySelectorAll('.tab-btn');
    const tabContents = document.querySelectorAll('.tab-content');
    
    tabButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            const tabName = btn.dataset.tab;
            
            // Remove active class from all
            tabButtons.forEach(b => b.classList.remove('active'));
            tabContents.forEach(c => c.classList.remove('active'));
            
            // Add active class to selected
            btn.classList.add('active');
            document.getElementById(tabName).classList.add('active');
            
            // Load tab-specific data
            if (tabName === 'domains') {
                loadDomains();
            } else if (tabName === 'config') {
                loadConfig();
            }
        });
    });
}

// API Calls
async function apiCall(endpoint, method = 'GET', data = null) {
    try {
        const options = {
            method: method,
            headers: {
                'Content-Type': 'application/json',
            }
        };
        
        if (data) {
            options.body = JSON.stringify(data);
        }
        
        const response = await fetch(`${API_BASE}${endpoint}`, options);
        const result = await response.json();
        
        if (!response.ok) {
            throw new Error(result.error || 'API Error');
        }
        
        return result;
    } catch (error) {
        console.error('API Error:', error);
        showNotification(error.message, 'error');
        throw error;
    }
}

// Status Loading
async function loadStatus() {
    try {
        const status = await apiCall('/status/all');
        currentStatus = status;
        
        updateZapretStatus(status.zapret);
        updateStrategies(status.strategies);
        updateProvider(status.provider);
        updateConfig(status.config);
    } catch (error) {
        console.error('Failed to load status:', error);
    }
}

function updateZapretStatus(zapret) {
    const statusEl = document.getElementById('zapret-status');
    const dot = statusEl.querySelector('.status-dot');
    const text = statusEl.querySelector('.status-text');
    
    if (zapret.running) {
        dot.classList.add('running');
        dot.classList.remove('stopped');
        text.textContent = 'Запущен';
    } else {
        dot.classList.add('stopped');
        dot.classList.remove('running');
        text.textContent = 'Остановлен';
    }
}

function updateStrategies(strategies) {
    document.getElementById('strat-udp').textContent = strategies.yt_udp || 'Def';
    document.getElementById('strat-tcp').textContent = strategies.yt_tcp || 'Def';
    document.getElementById('strat-gv').textContent = strategies.yt_gv || 'Def';
    document.getElementById('strat-rkn').textContent = strategies.rkn || 'Def';
}

function updateProvider(provider) {
    const providerEl = document.getElementById('provider-info');
    providerEl.textContent = provider.full || 'Не определён';
}

function updateConfig(config) {
    document.getElementById('config-fwtype').textContent = config.fwtype || 'Неизвестно';
    document.getElementById('config-flowoffload').textContent = config.flowoffload || 'Неизвестно';
    
    // Update bolvan mode
    const bolvanEl = document.getElementById('config-bolvan');
    if (config.bolvan_mode) {
        bolvanEl.textContent = config.bolvan_mode;
    }
}

// Control Zapret
async function controlZapret(action) {
    try {
        showNotification(`Выполняется ${action}...`, 'info');
        const result = await apiCall(`/control/${action}`, 'POST');
        
        if (result.success) {
            showNotification(`Zapret ${action} выполнен успешно`, 'success');
            setTimeout(loadStatus, 1000);
        } else {
            showNotification(result.error || 'Ошибка выполнения команды', 'error');
        }
    } catch (error) {
        showNotification('Ошибка при выполнении команды', 'error');
    }
}

// Domains Management
async function loadDomains() {
    try {
        const result = await apiCall('/domains/exclusions');
        displayDomains(result.domains || []);
    } catch (error) {
        document.getElementById('domains-list').innerHTML = '<p>Ошибка загрузки списка доменов</p>';
    }
}

function displayDomains(domains) {
    const listEl = document.getElementById('domains-list');
    
    if (domains.length === 0) {
        listEl.innerHTML = '<p>Нет доменов в исключениях</p>';
        return;
    }
    
    listEl.innerHTML = domains.map(domain => `
        <div class="domain-item">
            <span class="domain-name">${escapeHtml(domain)}</span>
            <button class="btn btn-danger" onclick="deleteDomain('${escapeHtml(domain)}')">Удалить</button>
        </div>
    `).join('');
}

async function addDomain() {
    const input = document.getElementById('domain-input');
    const domain = input.value.trim();
    
    if (!domain) {
        showNotification('Введите домен', 'error');
        return;
    }
    
    try {
        const result = await apiCall('/domains/exclusions/add', 'POST', { domain });
        
        if (result.success) {
            showNotification(`Добавлено доменов: ${result.added_count}`, 'success');
            input.value = '';
            loadDomains();
        } else {
            showNotification('Ошибка добавления домена', 'error');
        }
    } catch (error) {
        showNotification('Ошибка при добавлении домена', 'error');
    }
}

async function deleteDomain(domain) {
    if (!confirm(`Удалить домен ${domain} из исключений?`)) {
        return;
    }
    
    try {
        const result = await apiCall(`/domains/exclusions/${encodeURIComponent(domain)}`, 'DELETE');
        
        if (result.success) {
            showNotification('Домен удален', 'success');
            loadDomains();
        } else {
            showNotification(result.error || 'Ошибка удаления домена', 'error');
        }
    } catch (error) {
        showNotification('Ошибка при удалении домена', 'error');
    }
}

// Config Management
async function loadConfig() {
    try {
        const result = await apiCall('/config/get');
        document.getElementById('config-editor').value = result.content || '';
    } catch (error) {
        showNotification('Ошибка загрузки конфигурации', 'error');
    }
}

async function saveConfig() {
    const content = document.getElementById('config-editor').value;
    
    if (!confirm('Сохранить изменения в конфигурации? Это может повлиять на работу zapret.')) {
        return;
    }
    
    try {
        const result = await apiCall('/config/update', 'POST', { content });
        
        if (result.success) {
            showNotification('Конфигурация сохранена', 'success');
        } else {
            showNotification(result.error || 'Ошибка сохранения конфигурации', 'error');
        }
    } catch (error) {
        showNotification('Ошибка при сохранении конфигурации', 'error');
    }
}

async function toggleConfig(setting) {
    try {
        const result = await apiCall(`/config/toggle/${setting}`, 'POST');
        
        if (result.success) {
            showNotification(result.message || 'Настройка изменена', 'success');
            setTimeout(loadStatus, 1000);
        } else {
            showNotification(result.error || 'Ошибка изменения настройки', 'error');
        }
    } catch (error) {
        showNotification('Ошибка при изменении настройки', 'error');
    }
}

// Monitoring
async function checkAccess() {
    const resultsEl = document.getElementById('monitoring-results');
    resultsEl.innerHTML = '<p>Проверка доступности...</p>';
    
    try {
        const result = await apiCall('/monitoring/check');
        resultsEl.innerHTML = `
            <div class="monitoring-item ${result.success ? 'success' : 'error'}">
                <pre>${escapeHtml(result.output || 'Нет данных')}</pre>
            </div>
        `;
    } catch (error) {
        resultsEl.innerHTML = '<p>Ошибка проверки доступности</p>';
    }
}

// Strategy Modals
function openStrategyModal(type) {
    const modalContent = document.getElementById('modal-content');
    const typeNames = {
        'udp_yt': 'YouTube UDP QUIC',
        'tcp_yt': 'YouTube TCP',
        'tcp_gv': 'YouTube GV',
        'tcp_rkn': 'RKN'
    };
    
    modalContent.innerHTML = `
        <h2>Подбор стратегии: ${typeNames[type] || type}</h2>
        <p>Функция подбора стратегий будет реализована в следующей версии.</p>
        <button class="btn btn-primary" onclick="closeModal()">Закрыть</button>
    `;
    
    document.getElementById('modal-overlay').classList.add('active');
}

function openCustomDomainModal() {
    const modalContent = document.getElementById('modal-content');
    
    modalContent.innerHTML = `
        <h2>Подбор стратегии для кастомного домена</h2>
        <input type="text" id="custom-domain-input" placeholder="Введите домен" style="width: 100%; padding: 10px; margin: 10px 0;">
        <button class="btn btn-primary" onclick="tryCustomDomain()">Подобрать</button>
        <button class="btn btn-secondary" onclick="closeModal()">Отмена</button>
    `;
    
    document.getElementById('modal-overlay').classList.add('active');
}

async function tryCustomDomain() {
    const input = document.getElementById('custom-domain-input');
    const domain = input.value.trim();
    
    if (!domain) {
        showNotification('Введите домен', 'error');
        return;
    }
    
    try {
        const result = await apiCall('/strategies/try', 'POST', {
            type: 'custom',
            domain: domain
        });
        
        if (result.success) {
            showNotification('Подбор стратегии запущен', 'success');
            closeModal();
        }
    } catch (error) {
        showNotification('Ошибка при подборе стратегии', 'error');
    }
}

// Modal Management
function closeModal() {
    document.getElementById('modal-overlay').classList.remove('active');
}

// Notifications
function showNotification(message, type = 'info') {
    const notification = document.getElementById('notification');
    notification.textContent = message;
    notification.className = `notification ${type} active`;
    
    setTimeout(() => {
        notification.classList.remove('active');
    }, 3000);
}

// Utility
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}
