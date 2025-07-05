#!/bin/bash

# --- Parse arguments ---
NR=""
FIRST_IP=""
SECOND_IP=""

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --nr)
            NR="$2"
            shift 2
            ;;
        --first)
            FIRST_IP="$2"
            shift 2
            ;;
        --second)
            SECOND_IP="$2"
            shift 2
            ;;
        *)
            echo "❌ Unknown argument: $1"
            echo "Usage: $0 --nr <number> --first <IP1> --second <IP2>"
            exit 1
            ;;
    esac
done

# --- Validate input ---
if [[ -z "$NR" || -z "$FIRST_IP" || -z "$SECOND_IP" ]]; then
    echo "❌ Missing required arguments."
    echo "Usage: $0 --nr <number> --first <IP1> --second <IP2>"
    exit 1
fi

# --- Domain setup ---
BLOG_DOMAIN="$NR.blog.pl"
BLOG_ALIAS="$NR.edu.lab"
BLOG_IP="$FIRST_IP"

BIZ_DOMAIN="$NR.biz"
BIZ_ALIAS="$NR.net.lab"
BIZ_IP="$SECOND_IP"

DNS_IP=$(hostname -I | awk '{print $1}')  # First IP of the current host
ZONES_DIR="/etc/bind/zones"

echo "📦 Installing BIND9..."
apt update -y
apt install bind9 bind9utils bind9-doc -y

mkdir -p "$ZONES_DIR"

# --- Generate zone files ---
create_zone_file() {
  DOMAIN=$1
  ALIAS=$2
  TARGET_IP=$3

  cat <<EOF > "$ZONES_DIR/db.$DOMAIN"
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN. admin.$DOMAIN. (
                         2         ; Serial
                    604800         ; Refresh
                     86400         ; Retry
                   2419200         ; Expire
                    604800 )       ; Negative Cache TTL

; NS
        IN      NS      ns1.$DOMAIN.

; A records
ns1     IN      A       $DNS_IP
@       IN      A       $TARGET_IP
www     IN      A       $TARGET_IP

; Alias
$ALIAS  IN      CNAME   $DOMAIN.
EOF
}

echo "📝 Generating zone files..."
create_zone_file "$BLOG_DOMAIN" "$BLOG_ALIAS" "$BLOG_IP"
create_zone_file "$BIZ_DOMAIN" "$BIZ_ALIAS" "$BIZ_IP"

# --- Configure named.conf.local ---
cat <<EOF > /etc/bind/named.conf.local
zone "$BLOG_DOMAIN" {
    type master;
    file "$ZONES_DIR/db.$BLOG_DOMAIN";
};

zone "$BIZ_DOMAIN" {
    type master;
    file "$ZONES_DIR/db.$BIZ_DOMAIN";
};
EOF

# --- Validate config ---
echo "✅ Validating BIND config..."
named-checkconf || exit 1
named-checkzone "$BLOG_DOMAIN" "$ZONES_DIR/db.$BLOG_DOMAIN" || exit 1
named-checkzone "$BIZ_DOMAIN" "$ZONES_DIR/db.$BIZ_DOMAIN" || exit 1

# --- Restart service ---
echo "🔄 Restarting BIND9..."
systemctl restart bind9

echo "🎉 DNS setup complete!"
echo "✔ $BLOG_DOMAIN → $BLOG_IP"
echo "✔ $BLOG_ALIAS (CNAME)"
echo "✔ $BIZ_DOMAIN → $BIZ_IP"
echo "✔ $BIZ_ALIAS (CNAME)"
