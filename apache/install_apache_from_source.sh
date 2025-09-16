#!/bin/bash
# install_apache_from_source.sh
# Instalación de Apache HTTP Server desde código fuente en /opt/apache

set -euo pipefail

APACHE_VERSION="2.4.65"      # Ajusta a la versión que necesites
APR_VERSION="1.7.6"
APR_UTIL_VERSION="1.6.3"
PREFIX="/opt/apache"

# Paquetes necesarios para compilar
echo "[+] Instalando dependencias de compilación..."
dnf config-manager --set-enabled crb
dnf groupinstall -y "Development Tools"
dnf install -y gcc gcc-c++ make wget tar \
               pcre pcre-devel expat expat-devel \
               openssl openssl-devel \
               libnghttp2 libnghttp2-devel \
               zlib zlib-devel

mkdir -p /usr/local/src
cd /usr/local/src

echo "[+] Descargando Apache HTTP Server..."
wget https://downloads.apache.org/httpd/httpd-${APACHE_VERSION}.tar.gz
tar xzf httpd-${APACHE_VERSION}.tar.gz

echo "[+] Descargando y preparando APR..."
cd httpd-${APACHE_VERSION}/srclib
wget https://downloads.apache.org/apr/apr-${APR_VERSION}.tar.gz
wget https://downloads.apache.org/apr/apr-util-${APR_UTIL_VERSION}.tar.gz
tar xzf apr-${APR_VERSION}.tar.gz
tar xzf apr-util-${APR_UTIL_VERSION}.tar.gz
mv apr-${APR_VERSION} apr
mv apr-util-${APR_UTIL_VERSION} apr-util
cd ..

echo "[+] Configurando compilación..."
./configure \
  --prefix=${PREFIX} \
  --enable-so \
  --enable-ssl \
  --with-ssl \
  --enable-rewrite \
  --enable-deflate \
  --enable-expires \
  --enable-headers \
  --enable-http2 \
  --enable-mods-shared=all

echo "[+] Compilando e instalando..."
make -j"$(nproc)"
make install

echo "[+] Creando usuario y grupo apache..."
id -u apache &>/dev/null || useradd -r -d ${PREFIX} -s /sbin/nologin apache

echo "[+] Ajustando permisos..."
chown -R apache:apache ${PREFIX}

echo "[+] Creando unidad systemd..."
cat >/etc/systemd/system/apache-custom.service <<EOF
[Unit]
Description=Apache HTTP Server (custom build)
After=network.target

[Service]
Type=forking
ExecStartPre=/opt/apache/bin/httpd -t
ExecStart=${PREFIX}/bin/apachectl start
ExecStop=${PREFIX}/bin/apachectl stop
ExecReload=${PREFIX}/bin/apachectl graceful
PrivateTmp=true
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable apache-custom

echo "[+] Instalación finalizada. Para iniciar:"
echo "    systemctl start apache-custom"

