#!/bin/bash

set -u

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

# ambil & clean domain
readarray -t DOMAINS < <(
    (collect_apache; collect_nginx; collect_caddy) \
    | sed 's/;//g' \
    | grep -Eo '([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}' \
    | sort -u
)

TOTAL=${#DOMAINS[@]}

echo -e "${CYAN}[+] Total domain: $TOTAL${RESET}"
echo -e "${CYAN}[+] Scanning...${RESET}"

count=0

for domain in "${DOMAINS[@]}"; do
    ((count++))

    url="https://$domain"

    RESPONSE=$(curl -skL --max-time 3 -D - "$url" -o /dev/null 2>/dev/null || true)

    STATUS=$(echo "$RESPONSE" | head -n 1 | awk '{print $2}')
    SERVER=$(echo "$RESPONSE" | grep -i "^Server:" | awk '{print $2}' | tr -d '\r')

    TECH="unknown"
    [[ "$SERVER" =~ [Nn]ginx ]] && TECH="nginx"
    [[ "$SERVER" =~ [Aa]pache ]] && TECH="apache"
    [[ "$SERVER" =~ [Oo]penresty ]] && TECH="openresty"

    FRAME="unknown"
    echo "$RESPONSE" | grep -qi laravel && FRAME="laravel"
    echo "$RESPONSE" | grep -qi next && FRAME="nextjs"

    WAF="none"
    echo "$RESPONSE" | grep -qi cloudflare && WAF="cloudflare"

    COLOR=$RESET
    [[ "$STATUS" =~ ^2 ]] && COLOR=$GREEN
    [[ "$STATUS" =~ ^3 ]] && COLOR=$YELLOW
    [[ "$STATUS" =~ ^4|^5 ]] && COLOR=$RED

    echo -e "${CYAN}[$count/$TOTAL]${RESET} ${COLOR}$url | ${STATUS:-dead} | $TECH | $FRAME | $WAF | ${SERVER:-unknown}${RESET}"
done

echo -e "${GREEN}[+] DONE${RESET}"
