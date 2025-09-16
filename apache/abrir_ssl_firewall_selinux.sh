#!/bin/bash
# ============================================================================
# abrir_http_https_firewall_selinux.sh
# Abre los puertos 80 (HTTP) y 443 (HTTPS) en firewalld
# y ajusta SELinux para Apache en /opt/apache
# ============================================================================

set -e

# --- Firewalld ---------------------------------------------------------------
echo "==> Abriendo puertos 80/TCP y 443/TCP en firewalld"
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --reload

# --- SELinux -----------------------------------------------------------------
echo "==> Ajustando SELinux para permitir que Apache escuche en 80 y 443"
# Habilitar las booleanas para conexiones de red y SSL
setsebool -P httpd_can_network_connect 1

# Añadir/actualizar puertos en el contexto http_port_t
for PORT in 80 443; do
    if ! semanage port -l | grep -qE "^http_port_t.*\\b${PORT}\\b"; then
        semanage port -a -t http_port_t -p tcp $PORT
    else
        semanage port -m -t http_port_t -p tcp $PORT
    fi
done

echo "==> Reglas aplicadas correctamente."
echo "    Reinicia Apache con: systemctl restart apache-custom"

