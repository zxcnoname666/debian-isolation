# url_rewriter.py
from mitmproxy import http
import urllib.parse
import re
import os

PROXY_HOST = "worker-proxy.workers.dev"
PROXY_PREFIX = "----"

def load_allowed_domains():
    """Загружает список разрешенных доменов из файла"""
    domains = []
    config_file = os.path.join(os.path.dirname(__file__), "allowed_domains.txt")
    
    if os.path.exists(config_file):
        with open(config_file, "r") as f:
            for line in f:
                line = line.strip()
                # Пропускаем пустые строки и комментарии
                if line and not line.startswith("#"):
                    domains.append(line)
        print(f"Loaded {len(domains)} allowed domains from {config_file}")
    else:
        print(f"Config file not found: {config_file}, using default domains")
        domains = [
            "download.jetbrains.com",
            "download-cdn.jetbrains.com",
            "*.jetbrains.com",
        ]
    
    return domains

# Список разрешенных доменов для проксирования
ALLOWED_DOMAINS = load_allowed_domains()

def is_domain_allowed(domain):
    """Проверяет, разрешен ли домен для проксирования"""
    domain = domain.lower()
    
    for pattern in ALLOWED_DOMAINS:
        # Если это регулярное выражение
        if pattern.startswith("^"):
            if re.match(pattern, domain):
                return True
        # Если это wildcard паттерн
        elif "*" in pattern:
            # Преобразуем wildcard в regex
            regex_pattern = pattern.replace(".", r"\.").replace("*", ".*")
            if re.match(f"^{regex_pattern}$", domain):
                return True
        # Точное совпадение
        elif domain == pattern.lower():
            return True
    
    return False

def extract_target_url(url):
    """Извлекает целевой URL из проксированного URL"""
    # Убираем начальный слэш если есть
    if url.startswith('/'):
        url = url[1:]
    
    if PROXY_PREFIX in url:
        # Разбиваем по префиксу и берем последнюю часть
        parts = url.split(PROXY_PREFIX)
        if len(parts) > 1:
            # Берем последний элемент
            target = parts[-1]
            # Убираем начальный слэш если есть
            if target.startswith('/'):
                target = target[1:]
            return target
    return url

def request(flow: http.HTTPFlow):
    # Если это запрос к нашему прокси-серверу - пропускаем
    if flow.request.pretty_host == PROXY_HOST:
        # Проверяем на задвоенный префикс в пути
        path = flow.request.path
        if path.count(PROXY_PREFIX) > 1:
            # Извлекаем финальный URL
            target_url = extract_target_url(path)
            # Сохраняем query отдельно
            query_part = ""
            if '?' in target_url:
                target_url, query_part = target_url.split('?', 1)
            
            # Перезаписываем путь с одним префиксом
            new_path = f"/{PROXY_PREFIX}{target_url}"
            if query_part:
                new_path += f"?{query_part}"
            
            flow.request.path = new_path
            print(f"Fixed double prefix: {path} -> {new_path}")
        return
    
    # Проверяем, разрешен ли домен
    if not is_domain_allowed(flow.request.pretty_host):
        print(f"Domain not allowed, passing through: {flow.request.pretty_host}")
        return  # Пропускаем запрос без изменений
    
    # Для разрешенных доменов выполняем проксирование
    original_scheme = flow.request.scheme
    original_host = flow.request.pretty_host
    original_port = flow.request.port
    original_path = flow.request.path
    
    # Формируем полный URL БЕЗ query
    if (original_port == 80 and original_scheme == "http") or \
       (original_port == 443 and original_scheme == "https"):
        original_url = f"{original_scheme}://{original_host}{original_path}"
    else:
        original_url = f"{original_scheme}://{original_host}:{original_port}{original_path}"
    
    # Перенаправляем на прокси-сервер
    flow.request.host = PROXY_HOST
    flow.request.port = 443
    flow.request.scheme = "https"
    
    # Формируем новый путь БЕЗ query
    flow.request.path = f"/{PROXY_PREFIX}{original_url}"
    
    print(f"Proxying allowed domain: {original_url} -> https://{PROXY_HOST}/{PROXY_PREFIX}{original_url}")

def response(flow: http.HTTPFlow):
    # Обрабатываем редиректы только для проксированных запросов
    if flow.request.pretty_host != PROXY_HOST:
        return  # Не трогаем ответы от не-проксированных доменов
    
    # Обрабатываем редиректы
    if flow.response.status_code in [301, 302, 303, 307, 308]:
        location = flow.response.headers.get("Location")
        
        if location:
            print(f"Original redirect: {location}")
            
            # Если это относительный путь с префиксом
            if location.startswith(f"/{PROXY_PREFIX}"):
                # Извлекаем целевой URL
                target_url = extract_target_url(location)
                
                # Проверяем, не потеряли ли мы query параметры
                if '?' in location and '?' not in target_url:
                    # Восстанавливаем query из оригинального location
                    _, query = location.split('?', 1)
                    target_url += f"?{query}"
                
                # Проверяем, разрешен ли домен в редиректе
                if target_url.startswith("http"):
                    parsed = urllib.parse.urlparse(target_url)
                    if not is_domain_allowed(parsed.netloc):
                        print(f"Redirect to non-allowed domain, keeping original: {parsed.netloc}")
                        flow.response.headers["Location"] = target_url
                        return
                
                # Формируем правильный редирект
                new_location = f"https://{PROXY_HOST}/{PROXY_PREFIX}{target_url}"
                flow.response.headers["Location"] = new_location
                print(f"Fixed relative redirect with prefix: {location} -> {new_location}")
                
            # Если это абсолютный URL
            elif location.startswith("http://") or location.startswith("https://"):
                parsed = urllib.parse.urlparse(location)
                
                # Проверяем, разрешен ли домен
                if not is_domain_allowed(parsed.netloc):
                    print(f"Redirect to non-allowed domain, keeping original: {parsed.netloc}")
                    return  # Оставляем редирект как есть
                
                # Проверяем, не содержит ли уже префикс
                if PROXY_PREFIX in location:
                    target_url = extract_target_url(location)
                    new_location = f"https://{PROXY_HOST}/{PROXY_PREFIX}{target_url}"
                else:
                    new_location = f"https://{PROXY_HOST}/{PROXY_PREFIX}{location}"
                
                flow.response.headers["Location"] = new_location
                print(f"Proxied absolute redirect: {location} -> {new_location}")
                
            # Обычный относительный редирект без префикса
            elif location.startswith("/"):
                # Нужно восстановить оригинальный хост из запроса
                request_path = flow.request.path
                if PROXY_PREFIX in request_path:
                    original_url = extract_target_url(request_path)
                    if original_url.startswith("http"):
                        parsed = urllib.parse.urlparse(original_url)
                        
                        # Проверяем, разрешен ли домен
                        if not is_domain_allowed(parsed.netloc):
                            print(f"Relative redirect for non-allowed domain, keeping original: {parsed.netloc}")
                            return
                        
                        full_redirect = f"{parsed.scheme}://{parsed.netloc}{location}"
                        new_location = f"https://{PROXY_HOST}/{PROXY_PREFIX}{full_redirect}"
                        flow.response.headers["Location"] = new_location
                        print(f"Fixed relative redirect: {location} -> {new_location}")
