#!/bin/bash

# --- Parsowanie argumentów ---
WEB_SERVER=$1
NR=""

shift
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --nr)
            NR="$2"
            shift 2
            ;;
        *)
            echo "❌ Nieznany argument: $1"
            exit 1
            ;;
    esac
done

if [[ "$WEB_SERVER" != "nginx" && "$WEB_SERVER" != "apache" ]]; then
    echo "Użycie: $0 [nginx|apache] --nr <numer>"
    exit 1
fi

if [[ -z "$NR" ]]; then
    echo "❌ Musisz podać numer maszyny przez --nr, np. --nr 130"
    exit 1
fi

# --- Ustawienia ---
HOSTNAME_VAL=$(hostname)  # Zawsze pobieramy nazwę maszyny z hostname
DOMAINS=("$NR.blog.pl" "$NR.biz")
ALIASES=("$NR.edu.lab" "$NR.net.lab")

# --- Detekcja systemu ---
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "❌ Nie można rozpoznać systemu operacyjnego."
    exit 1
fi

echo "✅ System: $OS"
echo "📦 Aktualizacja pakietów..."
apt update -y

# ------------------------
# INSTALACJA I KONFIGURACJA
# ------------------------

if [ "$WEB_SERVER" == "nginx" ]; then
    echo "🌐 Instalacja Nginx..."
    apt install nginx -y

    # Strona główna (dla IP)
    echo "$HOSTNAME_VAL" | tee /var/www/html/index.html > /dev/null

    for i in "${!DOMAINS[@]}"; do
        DOMAIN=${DOMAINS[$i]}
        ALIAS=${ALIASES[$i]}
        DIR="/var/www/$DOMAIN"

        mkdir -p "$DIR"
        echo "$HOSTNAME_VAL - $DOMAIN" | tee "$DIR/index.html" > /dev/null

        cat <<EOF | tee "/etc/nginx/sites-available/$DOMAIN"
server {
    listen 80;
    server_name $DOMAIN $ALIAS;

    root $DIR;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

        ln -sf "/etc/nginx/sites-available/$DOMAIN" "/etc/nginx/sites-enabled/$DOMAIN"
    done

    systemctl restart nginx
    echo "✅ Nginx skonfigurowany."

elif [ "$WEB_SERVER" == "apache" ]; then
    echo "🌐 Instalacja Apache..."
    apt install apache2 -y

    # Strona główna (dla IP)
    echo "$HOSTNAME_VAL" | tee /var/www/html/index.html > /dev/null

    for i in "${!DOMAINS[@]}"; do
        DOMAIN=${DOMAINS[$i]}
        ALIAS=${ALIASES[$i]}
        DIR="/var/www/$DOMAIN"

        mkdir -p "$DIR"
        echo "$HOSTNAME_VAL - $DOMAIN" | tee "$DIR/index.html" > /dev/null

        cat <<EOF | tee "/etc/apache2/sites-available/$DOMAIN.conf"
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAlias $ALIAS
    DocumentRoot $DIR

    <Directory $DIR>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

        a2ensite "$DOMAIN.conf"
    done

    systemctl reload apache2
    echo "✅ Apache skonfigurowany."
fi

echo "🎉 Gotowe! Sprawdź: http://<IP>, http://$NR.blog.pl, http://$NR.biz"
