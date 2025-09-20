// Cloudflare Worker для проксирования запросов

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // Логирование для отладки
    console.log('Incoming request:', request.method, url.pathname);

    // Извлекаем целевой URL после "----"
    const pathParts = url.pathname.split('/----');
    if (pathParts.length !== 2) {
      return new Response(
        JSON.stringify({ error: 'Invalid proxy URL format. Expected: /----https://target-url.com' }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' }
        }
      );
    }

    let targetUrl = pathParts[1];

    // Добавляем протокол если его нет
    if (!targetUrl.startsWith('http://') && !targetUrl.startsWith('https://')) {
      targetUrl = 'https://' + targetUrl;
    }

    // Добавляем путь и query параметры если есть
    const targetUrlParsed = new URL(targetUrl);

    // Если в оригинальном URL есть дополнительный путь после целевого URL
    const additionalPath = pathParts[0].substring(1); // Убираем начальный /
    if (additionalPath) {
      targetUrlParsed.pathname = additionalPath + targetUrlParsed.pathname;
    }

    // Добавляем query параметры
    if (url.search) {
      // Объединяем query параметры
      const urlParams = new URLSearchParams(url.search);
      const targetParams = new URLSearchParams(targetUrlParsed.search);

      for (const [key, value] of urlParams) {
        targetParams.append(key, value);
      }

      targetUrlParsed.search = targetParams.toString();
    }

    targetUrl = targetUrlParsed.toString();
    console.log('Proxying to:', targetUrl);

    try {
      // Копируем заголовки из оригинального запроса
      const headers = new Headers(request.headers);

      // Удаляем заголовки Cloudflare и прокси
      const headersToRemove = [
        'cf-connecting-ip',
        'cf-ipcountry',
        'cf-ray',
        'cf-visitor',
        'x-forwarded-for',
        'x-forwarded-proto',
        'x-real-ip'
      ];

      headersToRemove.forEach(header => headers.delete(header));

      // Устанавливаем правильный Host заголовок
      headers.set('Host', targetUrlParsed.host);

      // Опционально: добавляем заголовок для идентификации прокси
      headers.set('X-Proxied-By', 'Cloudflare-Worker');

      // Создаем новый запрос
      const modifiedRequest = new Request(targetUrl, {
        method: request.method,
        headers: headers,
        body: request.body,
        redirect: 'manual' // Обрабатываем редиректы вручную
      });

      // Выполняем запрос
      const response = await fetch(modifiedRequest);

      // Обработка редиректов
      if ([301, 302, 303, 307, 308].includes(response.status)) {
        const location = response.headers.get('Location');
        if (location) {
          // Преобразуем location для прохождения через прокси
          let newLocation = location;
          if (location.startsWith('http://') || location.startsWith('https://')) {
            // Абсолютный URL - проксируем через воркер
            newLocation = `/----${location}`;
          } else if (location.startsWith('/')) {
            // Относительный путь - добавляем базовый URL
            const baseUrl = `${targetUrlParsed.protocol}//${targetUrlParsed.host}`;
            newLocation = `/----${baseUrl}${location}`;
          }

          const responseHeaders = new Headers(response.headers);
          responseHeaders.set('Location', newLocation);

          return new Response(response.body, {
            status: response.status,
            statusText: response.statusText,
            headers: responseHeaders
          });
        }
      }

      // Создаем новый ответ
      const responseHeaders = new Headers(response.headers);

      // Добавляем CORS заголовки для разработки
      // В продакшене настройте более строгую политику
      responseHeaders.set('Access-Control-Allow-Origin', '*');
      responseHeaders.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
      responseHeaders.set('Access-Control-Allow-Headers', '*');

      // Удаляем заголовки безопасности которые могут помешать
      responseHeaders.delete('Content-Security-Policy');
      responseHeaders.delete('X-Frame-Options');

      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: responseHeaders
      });

    } catch (error) {
      console.error('Proxy error:', error);

      return new Response(
        JSON.stringify({
          error: 'Proxy error',
          message: error.message,
          targetUrl: targetUrl
        }),
        {
          status: 500,
          headers: { 'Content-Type': 'application/json' }
        }
      );
    }
  },

  // Обработка OPTIONS запросов для CORS
  async options(request) {
    return new Response(null, {
      status: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': '*',
        'Access-Control-Max-Age': '86400',
      }
    });
  }
};
