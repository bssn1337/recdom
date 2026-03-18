#!/bin/bash

set -u  # jangan pakai -e dulu biar gak mati di tengah

# warna
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RESET="\033[0m"

echo -e "${CYAN}[+] Collecting domains...${RESET}"

collect_apache() {
    grep -hE "ServerName|ServerAlias" /etc/apache2/sites-available/* 2>/dev/null \
    | awk '{for(i=2;i<=NF;i++) print $i}'
}

collect_nginx() {
    grep -hE "server_name" /etc/nginx/sites-enabled/* 2>/dev/null \
    | sed 's/server_name//g' | tr ' ' '\n'
}

collect_caddy() {
    grep -hE "^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}" /etc/caddy/Caddyfile 2>/dev/null || true
}

DOMAINS=$( (collect_apache; collect_nginx; collect_caddy) \
| sed 's/;//g' \
| grep -Eo '([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}' \
| sort -u )

TOTAL=$(echo "$DOMAINS" | wc -l)

echo -e "${CYAN}[+] Total domain: $TOTAL${RESET}"
echo -e "${CYAN}[+] Scanning...${RESET}"

count=0

for domain in $DOMAINS; do
    count=$((count+1))

    url="https://$domain"

    RESPONSE=$(curl -skL --max-time 3 -D - "$url" -o /dev/null 2>/dev/null || true)

    STATUS=$(echo "$RESPONSE" | head -n 1 | awk '{print $2}')
    SERVER=$(echo "$RESPONSE" | grep -i "^Server:" | awk '{print $2}' | tr -d '\r')

    # detect server
    TECH="unknown"
    echo "$SERVER" | grep -qi nginx && TECH="nginx"
    echo "$SERVER" | grep -qi apache && TECH="apache"
    echo "$SERVER" | grep -qi openresty && TECH="openresty"

    # detect framework
    FRAME="unknown"
    echo "$RESPONSE" | grep -qi laravel && FRAME="laravel"
    echo "$RESPONSE" | grep -qi next && FRAME="nextjs"

    # detect WAF
    WAF="none"
    echo "$RESPONSE" | grep -qi cloudflare && WAF="cloudflare"

    # warna status
    COLOR=$RESET
    if [[ "$STATUS" =~ ^2 ]]; then COLOR=$GREEN
    elif [[ "$STATUS" =~ ^3 ]]; then COLOR=$YELLOW
    elif [[ "$STATUS" =~ ^4|^5 ]]; then COLOR=$RED
    fi

    echo -e "${CYAN}[$count/$TOTAL]${RESET} ${COLOR}$url | ${STATUS:-dead} | $TECH | $FRAME | $WAF | ${SERVER:-unknown}${RESET}"
done

echo -e "${GREEN}[+] DONE${RESET}"
