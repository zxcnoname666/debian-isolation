# url_rewriter.py
from mitmproxy import http
import urllib.parse

PROXY_HOST = "worker-proxy.workers.dev"
PROXY_PREFIX = "----"

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
    
    # Для остальных запросов
    original_scheme = flow.request.scheme
    original_host = flow.request.pretty_host
    original_port = flow.request.port
    original_path = flow.request.path
    
    # Формируем полный URL БЕЗ query (query сохраняется отдельно в mitmproxy)
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
    
    # Query параметры mitmproxy добавит автоматически из flow.request.query
    
    print(f"Proxying: {original_url} -> https://{PROXY_HOST}/{PROXY_PREFIX}{original_url}")

def response(flow: http.HTTPFlow):
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
                
                # Формируем правильный редирект
                new_location = f"https://{PROXY_HOST}/{PROXY_PREFIX}{target_url}"
                flow.response.headers["Location"] = new_location
                print(f"Fixed relative redirect with prefix: {location} -> {new_location}")
                
            # Если это абсолютный URL
            elif location.startswith("http://") or location.startswith("https://"):
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
                        full_redirect = f"{parsed.scheme}://{parsed.netloc}{location}"
                        new_location = f"https://{PROXY_HOST}/{PROXY_PREFIX}{full_redirect}"
                        flow.response.headers["Location"] = new_location
                        print(f"Fixed relative redirect: {location} -> {new_location}")
