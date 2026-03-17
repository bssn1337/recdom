#!/bin/bash

echo "[+] Collecting domains..."

DOMAINS=""

# APACHE
[ -d "/etc/apache2/sites-available" ] && \
DOMAINS+=" $(grep -h -E "ServerName|ServerAlias" /etc/apache2/sites-available/* 2>/dev/null \
| awk '{for(i=2;i<=NF;i++) print $i}')"

[ -d "/etc/httpd/conf.d" ] && \
DOMAINS+=" $(grep -h -E "ServerName|ServerAlias" /etc/httpd/conf.d/* 2>/dev/null \
| awk '{for(i=2;i<=NF;i++) print $i}')"

# NGINX
[ -d "/etc/nginx/sites-available" ] && \
DOMAINS+=" $(grep -h "server_name" /etc/nginx/sites-available/* 2>/dev/null \
| sed 's/server_name//g; s/;//g' \
| awk '{for(i=1;i<=NF;i++) print $i}')"

[ -d "/etc/nginx/conf.d" ] && \
DOMAINS+=" $(grep -h "server_name" /etc/nginx/conf.d/* 2>/dev/null \
| sed 's/server_name//g; s/;//g' \
| awk '{for(i=1;i<=NF;i++) print $i}')"

# CADDY
[ -f "/etc/caddy/Caddyfile" ] && \
DOMAINS+=" $(grep -v "#" /etc/caddy/Caddyfile \
| grep -E "^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}" \
| awk '{print $1}')"

# CLEAN
DOMAINS=$(echo $DOMAINS | tr ' ' '\n' | sed 's/\*\.//g' | grep -v localhost | grep -v "_" | sort -u)

echo "[+] Fingerprinting..."
echo ""

for d in $DOMAINS; do
    for proto in https http; do
        URL="$proto://$d"

        HEADER=$(curl -k -m 5 -s -I $URL)
        BODY=$(curl -k -m 5 -s $URL | head -n 80)

        CODE=$(echo "$HEADER" | head -n 1 | awk '{print $2}')
        SERVER=$(echo "$HEADER" | grep -i server | cut -d' ' -f2-)

        if [ ! -z "$CODE" ]; then

            TECH="unknown"
            FRAMEWORK="unknown"
            WAF="none"

            # ======================
            # WEB SERVER
            # ======================
            echo "$HEADER" | grep -qi "nginx" && TECH="nginx"
            echo "$HEADER" | grep -qi "apache" && TECH="apache"
            echo "$HEADER" | grep -qi "caddy" && TECH="caddy"

            # ======================
            # WAF / CDN DETECT
            # ======================
            echo "$HEADER" | grep -qi "cloudflare" && WAF="cloudflare"
            echo "$HEADER" | grep -qi "cf-ray" && WAF="cloudflare"
            echo "$HEADER" | grep -qi "akamai" && WAF="akamai"
            echo "$HEADER" | grep -qi "sucuri" && WAF="sucuri"

            # ======================
            # FRAMEWORK DETECT
            # ======================

            # Laravel
            echo "$HEADER $BODY" | grep -qi "laravel" && FRAMEWORK="laravel"

            # Next.js
            echo "$BODY" | grep -qi "_next" && FRAMEWORK="nextjs"

            # React
            echo "$BODY" | grep -qi "react" && FRAMEWORK="react"

            # Vue
            echo "$BODY" | grep -qi "vue" && FRAMEWORK="vue"

            # WordPress
            echo "$BODY" | grep -qi "wp-content" && FRAMEWORK="wordpress"

            # CodeIgniter
            echo "$BODY" | grep -qi "ci_session" && FRAMEWORK="codeigniter"

            # Node.js / Express
            echo "$HEADER" | grep -qi "express" && FRAMEWORK="nodejs"

            # ======================
            # EXTRA DETECT (panel/api)
            # ======================
            curl -k -m 3 -s "$URL/admin" | grep -qi "login" && FRAMEWORK="$FRAMEWORK+admin"
            curl -k -m 3 -s "$URL/api" | grep -qi "json" && FRAMEWORK="$FRAMEWORK+api"

            echo "$URL | $CODE | $TECH | $FRAMEWORK | $WAF | $SERVER"
            break
        fi
    done
done

echo ""
echo "[+] DONE"
