#!/bin/sh
set -e

BFF_URL="${BFF_URL:-}"
BFF_INTERNAL_URL="${BFF_INTERNAL_URL:-http://bff:8080}"

# Generate config.js for the browser
cat > /usr/share/nginx/html/config.js <<EOF
window.__BFF_URL__ = '${BFF_URL}';
EOF

# Patch nginx proxy_pass with internal BFF URL
sed -i "s|BFF_PROXY_PLACEHOLDER|${BFF_INTERNAL_URL}|g" /etc/nginx/conf.d/default.conf

exec nginx -g "daemon off;"
