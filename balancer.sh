#!/bin/bash

LB_TYPE=""
BACKENDS=()
PORT=80

# --- Parsowanie argumentów ---
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        haproxy|nginx|apache)
            LB_TYPE="$1"
            shift
            ;;
        --backend)
            BACKENDS+=("$2")
            shift 2
            ;;
        *)
            echo "❌ Nieznany argument: $1"
            echo "Użycie: $0 [haproxy|nginx|apache] --backend <IP> [--backend <IP> ...]"
            exit 1
            ;;
    esac
done

if [[ -z "$LB_TYPE" || "${#BACKENDS[@]}" -lt 1 ]]; then
    echo "❌ Musisz podać typ balancera i co najmniej jeden backend."
    echo "Przykład: $0 haproxy --backend 10.21.130.11 --backend 10.21.130.12"
    exit 1
fi

echo "✅ Instaluję load balancer: $LB_TYPE"
apt update -y

# ------------------------
# HAProxy
# ------------------------
if [[ "$LB_TYPE" == "haproxy" ]]; then
    apt install haproxy -y

    cat <<EOF > /etc/haproxy/haproxy.cfg
global
    log /dev/log local0
    maxconn 2000
    daemon

defaults
    mode http
    timeout connect 5s
    timeout client  30s
    timeout server  30s

frontend http_front
    bind *:80
    default_backend web_servers

backend web_servers
    balance roundrobin
    option httpchk HEAD / HTTP/1.1\r\nHost:localhost
EOF

    for i in "${!BACKENDS[@]}"; do
        echo "    server web$((i+1)) ${BACKENDS[$i]}:$PORT check" >> /etc/haproxy/haproxy.cfg
    done

    sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/haproxy
    systemctl restart haproxy
    echo "✅ HAProxy skonfigurowany."

# ------------------------
# NGINX
# ------------------------
elif [[ "$LB_TYPE" == "nginx" ]]; then
    apt install nginx -y

    cat <<EOF > /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events { worker_connections 1024; }

http {
    upstream backend_servers {
EOF

    for backend in "${BACKENDS[@]}"; do
        echo "        server $backend:$PORT;" >> /etc/nginx/nginx.conf
    done

    cat <<EOF >> /etc/nginx/nginx.conf
    }

    server {
        listen 80;

        location / {
            proxy_pass http://backend_servers;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }
    }
}
EOF

    systemctl restart nginx
    echo "✅ Nginx skonfigurowany jako load balancer."

# ------------------------
# Apache
# ------------------------
elif [[ "$LB_TYPE" == "apache" ]]; then
    apt install apache2 -y
    a2enmod proxy proxy_http proxy_balancer lbmethod_byrequests headers

    cat <<EOF > /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
    ProxyPreserveHost On
    ProxyRequests Off

    <Proxy "balancer://backendcluster">
EOF

    for backend in "${BACKENDS[@]}"; do
        echo "        BalancerMember http://$backend:$PORT" >> /etc/apache2/sites-available/000-default.conf
    done

    cat <<EOF >> /etc/apache2/sites-available/000-default.conf
        ProxySet lbmethod=byrequests
    </Proxy>

    ProxyPass / balancer://backendcluster/
    ProxyPassReverse / balancer://backendcluster/
</VirtualHost>
EOF

    systemctl restart apache2
    echo "✅ Apache skonfigurowany jako load balancer."
fi

echo "🎉 Load balancer '$LB_TYPE' gotowy! Backend(y): ${BACKENDS[*]}"
