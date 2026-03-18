#!/bin/bash

set -u

GREEN="\033[32m"
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

readarray -t DOMAINS < <(
    (collect_apache; collect_nginx; collect_caddy) \
    | sed 's/;//g' \
    | grep -Eo '([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}' \
    | grep -v '^www\.' \
    | sort -u
)

TOTAL=${#DOMAINS[@]}

echo -e "${CYAN}[+] Total domain: $TOTAL${RESET}"
echo -e "${CYAN}[+] Scanning (200 only)...${RESET}"

for domain in "${DOMAINS[@]}"; do
    url="https://$domain"

    RESPONSE=$(curl -skL --connect-timeout 2 --max-time 3 -D - "$url" -o /dev/null 2>/dev/null || true)

    STATUS=$(echo "$RESPONSE" | head -n 1 | awk '{print $2}')
    SERVER=$(echo "$RESPONSE" | grep -i "^Server:" | head -n1 | awk '{print $2}' | tr -d '\r')

    # hanya 200
    [[ "$STATUS" != "200" ]] && continue

    # kalau kosong skip
    [[ -z "$SERVER" ]] && continue

    echo -e "${GREEN}$url | $SERVER${RESET}"
done

echo -e "${GREEN}[+] DONE${RESET}"
