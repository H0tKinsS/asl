#!/bin/bash

WEB_SERVER=$1

if [[ "$WEB_SERVER" != "nginx" && "$WEB_SERVER" != "apache" ]]; then
    echo "Użycie: $0 [nginx|apache]"
    exit 1
fi

# Pobieramy hostname
HOSTNAME_VAL=$(hostname)

# Rozpoznawanie systemu
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "❌ Nie można rozpoznać systemu operacyjnego."
    exit 1
fi

echo "✅ System: $OS"
echo "📦 Aktualizacja pakietów..."
sudo apt update -y

# Instalacja i konfiguracja
if [ "$WEB_SERVER" == "nginx" ]; then
    echo "🌐 Instalacja Nginx..."
    sudo apt install nginx -y

    # Strona główna dla IP (w /var/www/html)
    echo "<h1>$HOSTNAME_VAL</h1>" | sudo tee /var/www/html/index.html > /dev/null

    # Strona dla domeny
    sudo mkdir -p /var/www/strona130.pl
    echo "<h1>$HOSTNAME_VAL - strona130.pl</h1>" | sudo tee /var/www/strona130.pl/index.html > /dev/null

    # Domyślny virtualhost (dla IP)
    cat <<EOF | sudo tee /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    server_name _;

    root /var/www/html;
    index index.html;
}
EOF

    # Virtualhost dla domeny
    cat <<EOF | sudo tee /etc/nginx/sites-available/strona130.pl
server {
    listen 80;
    server_name strona130.pl;

    root /var/www/strona130.pl;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

    sudo ln -sf /etc/nginx/sites-available/strona130.pl /etc/nginx/sites-enabled/

    sudo systemctl restart nginx
    echo "✅ Nginx skonfigurowany."

elif [ "$WEB_SERVER" == "apache" ]; then
    echo "🌐 Instalacja Apache..."
    sudo apt install apache2 -y

    # Strona dla IP (w /var/www/html)
    echo "<h1>$HOSTNAME_VAL</h1>" | sudo tee /var/www/html/index.html > /dev/null

    # Strona dla domeny
    sudo mkdir -p /var/www/strona130.pl
    echo "<h1>$HOSTNAME_VAL - strona130.pl</h1>" | sudo tee /var/www/strona130.pl/index.html > /dev/null

    # Domyślna konfiguracja (dla IP)
    cat <<EOF | sudo tee /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
    DocumentRoot /var/www/html
</VirtualHost>
EOF

    # Virtualhost dla domeny
    cat <<EOF | sudo tee /etc/apache2/sites-available/strona130.pl.conf
<VirtualHost *:80>
    ServerName strona130.pl
    DocumentRoot /var/www/strona130.pl

    <Directory /var/www/strona130.pl>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/strona130_error.log
    CustomLog \${APACHE_LOG_DIR}/strona130_access.log combined
</VirtualHost>
EOF

    sudo a2ensite strona130.pl.conf
    sudo systemctl reload apache2
    echo "✅ Apache skonfigurowany."
fi

echo "🎉 Gotowe! Sprawdź: http://<IP> lub http://strona130.pl"
