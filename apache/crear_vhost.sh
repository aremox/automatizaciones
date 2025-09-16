#!/bin/bash
###########################################################################
# Script: crear_vhost.sh
#
# Descripción:
#   Crea un VirtualHost en /opt/apache/conf/sites/ con o sin SSL
#   y, opcionalmente, con validación de certificado de cliente.
#
# Ejemplos de uso:
#   1) Solo HTTP (puerto 80):
#        sudo ./crear_vhost.sh midominio.local /opt/apache/htdocs/midominio
#
#   2) HTTPS sin autenticación de cliente:
#        sudo ./crear_vhost.sh seguro.local /opt/apache/htdocs/seguro yes
#
#   3) HTTPS con autenticación de cliente:
#        sudo ./crear_vhost.sh privado.local /opt/apache/htdocs/privado yes yes
#
#   Parámetros:
#     <nombre_host>   = FQDN del sitio (ej: ejemplo.local)
#     <document_root> = Carpeta de los ficheros estáticos
#     [ssl]           = yes|no  (default: no)
#     [client_auth]   = yes|no  (default: no, solo válido si ssl=yes)
#
###########################################################################

APACHE_BASE="/opt/apache"
SITES_DIR="$APACHE_BASE/conf/sites"
HTTPD_CONF="$APACHE_BASE/conf/httpd.conf"
CERT_DIR="/opt/certs"

# --- Comprobación de argumentos ---
if [[ $# -lt 2 ]]; then
    echo "Uso: $0 <nombre_host> <document_root> [ssl] [client_auth]"
    echo "   <nombre_host>   = FQDN del sitio (ej: ejemplo.local)"
    echo "   <document_root> = Carpeta de los ficheros estáticos"
    echo "   [ssl]           = yes|no  (default: no)"
    echo "   [client_auth]   = yes|no  (default: no, solo válido si ssl=yes)"
    exit 1
fi

SERVER_NAME="$1"
DOC_ROOT="$2"
ENABLE_SSL="${3:-no}"
CLIENT_AUTH="${4:-no}"

mkdir -p "$DOC_ROOT"
mkdir -p "$SITES_DIR"

CONF_FILE="$SITES_DIR/$SERVER_NAME.conf"

echo "==> Creando VirtualHost: $CONF_FILE"

if [[ "$ENABLE_SSL" == "yes" ]]; then
    cat > "$CONF_FILE" <<EOF
<VirtualHost *:443>
    ServerName $SERVER_NAME
    DocumentRoot "$DOC_ROOT"

    SSLEngine on
    SSLCertificateFile "$CERT_DIR/server/server.crt"
    SSLCertificateKeyFile "$CERT_DIR/server/server.key"
    SSLCACertificateFile "$CERT_DIR/ca/ca.crt"

    ErrorLog "$APACHE_BASE/logs/${SERVER_NAME}_ssl_error.log"
    CustomLog "$APACHE_BASE/logs/${SERVER_NAME}_ssl_access.log" combined
EOF

    # Autenticación de cliente si se pide
    if [[ "$CLIENT_AUTH" == "yes" ]]; then
        cat >> "$CONF_FILE" <<EOF
    SSLVerifyClient require
    SSLVerifyDepth 2
EOF
    fi

    echo "</VirtualHost>" >> "$CONF_FILE"
else
    cat > "$CONF_FILE" <<EOF
<VirtualHost *:80>
    ServerName $SERVER_NAME
    DocumentRoot "$DOC_ROOT"

    ErrorLog "$APACHE_BASE/logs/${SERVER_NAME}_error.log"
    CustomLog "$APACHE_BASE/logs/${SERVER_NAME}_access.log" combined
</VirtualHost>
EOF
fi

# --- Incluir el nuevo fichero en httpd.conf si no existe ---
if ! grep -q "Include conf/sites" "$HTTPD_CONF"; then
    echo "Include conf/sites/*.conf" >> "$HTTPD_CONF"
fi

# --- Verificar y recargar Apache ---
echo "==> Verificando configuración..."
$APACHE_BASE/bin/apachectl configtest || {
    echo "Error de configuración. Revise $CONF_FILE"
    exit 1
}

echo "==> Recargando Apache..."
systemctl reload apache-custom

echo "==> VirtualHost creado correctamente: $CONF_FILE"

