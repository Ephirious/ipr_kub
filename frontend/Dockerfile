FROM nginx:1.27-alpine

RUN rm /etc/nginx/conf.d/default.conf

COPY nginx.conf        /etc/nginx/conf.d/default.conf
COPY index.html        /usr/share/nginx/html/index.html
COPY app.js            /usr/share/nginx/html/static/app.js
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# BFF_URL     — public URL браузер использует для API-запросов
#               (пусто = same-origin, nginx проксирует)
# BFF_INTERNAL_URL — URL для nginx proxy_pass внутри Docker-сети
ENV BFF_URL=""
ENV BFF_INTERNAL_URL="http://bff:8080"

EXPOSE 80
ENTRYPOINT ["/docker-entrypoint.sh"]
