#!/bin/bash
# ============================================================================
# configurar_vhost_ssl_apache.sh
# Crea un VirtualHost SSL en Apache compilado en /opt/apache
# y habilita los módulos SSL si están comentados.
# Usa certificados existentes en /opt/certs/
# ============================================================================

set -e

APACHE_PREFIX="/opt/apache"
HTTPD_CONF="$APACHE_PREFIX/conf/httpd.conf"
SSL_CONF_DIR="$APACHE_PREFIX/conf/extra"
SSL_VHOST="$SSL_CONF_DIR/ssl-client-server.conf"
CERT_DIR="/opt/certs"   # <---- RUTA DE LOS CERTIFICADOS

echo "==> Verificando que Apache existe en $APACHE_PREFIX"
[ -x "$APACHE_PREFIX/bin/httpd" ] || { echo "Apache no encontrado en $APACHE_PREFIX"; exit 1; }

# ---------------------------------------------------------------------------
# 1. Habilitar módulos SSL en httpd.conf
# ---------------------------------------------------------------------------
echo "==> Habilitando módulos SSL en httpd.conf (si estaban comentados)"
sed -i 's|^[#[:space:]]*LoadModule ssl_module|LoadModule ssl_module|' "$HTTPD_CONF"
sed -i 's|^[#[:space:]]*LoadModule socache_shmcb_module|LoadModule socache_shmcb_module|' "$HTTPD_CONF"

# ---------------------------------------------------------------------------
# 2. Asegurar que escucha en el puerto 443
# ---------------------------------------------------------------------------
grep -q "^Listen 443" "$HTTPD_CONF" || echo "Listen 443" >> "$HTTPD_CONF"

# ---------------------------------------------------------------------------
# 3. Crear VirtualHost SSL
# ---------------------------------------------------------------------------
echo "==> Creando VirtualHost SSL en $SSL_VHOST"
mkdir -p "$SSL_CONF_DIR"
cat > "$SSL_VHOST" <<EOF
<VirtualHost *:443>
    ServerName ejemplo.local
    DocumentRoot "/opt/apache/htdocs"

    SSLEngine on
    SSLCertificateFile "$CERT_DIR/server/server.crt"
    SSLCertificateKeyFile "$CERT_DIR/server/server.key"
    SSLCACertificateFile "$CERT_DIR/ca/ca.crt"

    # === Autenticación de cliente (mutua) ===
    # Require que el cliente presente un certificado firmado por la CA
    SSLVerifyClient require
    # Nivel de verificación: require = obligatorio, optional = opcional
    SSLVerifyDepth 2

    # Logs
    ErrorLog "/opt/apache/logs/ssl_error.log"
    CustomLog "/opt/apache/logs/ssl_access.log" combined
</VirtualHost>
EOF
# ---------------------------------------------------------------------------
# 4. Incluir el VirtualHost en httpd.conf si no está
# ---------------------------------------------------------------------------
echo "==> Incluyendo VirtualHost en httpd.conf si no existe"
grep -q "ssl-client-server.conf" "$HTTPD_CONF" || \
    echo "Include conf/extra/ssl-client-server.conf" >> "$HTTPD_CONF"

# ---------------------------------------------------------------------------
# 5. Verificar configuración
# ---------------------------------------------------------------------------
echo "==> Verificando configuración de Apache"
/opt/apache/bin/apachectl configtest
echo "==> Si no hay errores, reinicia Apache:"
echo "    systemctl restart apache-custom  (si usas el servicio systemd)"

