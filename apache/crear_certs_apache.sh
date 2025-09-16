#!/bin/bash
set -e

# === Configuración ===
BASE_DIR=/opt/certs
CA_DIR=$BASE_DIR/ca
SERVER_DIR=$BASE_DIR/server
CLIENT_DIR=$BASE_DIR/client
DAYS=3650           # 10 años

mkdir -p "$CA_DIR" "$SERVER_DIR" "$CLIENT_DIR"

echo "### 1. Crear CA raíz ###"
openssl genrsa -out $CA_DIR/ca.key 4096
openssl req -x509 -new -nodes -key $CA_DIR/ca.key -sha256 -days $DAYS \
    -out $CA_DIR/ca.crt \
    -subj "/C=ES/ST=Madrid/L=Madrid/O=MiOrg/CN=MiCA"

echo "### 2. Crear certificado de Servidor ###"
openssl genrsa -out $SERVER_DIR/server.key 2048
openssl req -new -key $SERVER_DIR/server.key \
    -out $SERVER_DIR/server.csr \
    -subj "/C=ES/ST=Madrid/L=Madrid/O=MiOrg/CN=mi.servidor.local"

# Archivo de extensiones para SAN
cat > $SERVER_DIR/server_ext.cnf <<EOF
subjectAltName = @alt_names
[alt_names]
DNS.1 = mi.servidor.local
DNS.2 = localhost
EOF

openssl x509 -req -in $SERVER_DIR/server.csr -CA $CA_DIR/ca.crt \
    -CAkey $CA_DIR/ca.key -CAcreateserial \
    -out $SERVER_DIR/server.crt -days $DAYS -sha256 \
    -extfile $SERVER_DIR/server_ext.cnf

echo "### 3. Crear certificado de Cliente ###"
openssl genrsa -out $CLIENT_DIR/client.key 2048
openssl req -new -key $CLIENT_DIR/client.key \
    -out $CLIENT_DIR/client.csr \
    -subj "/C=ES/ST=Madrid/L=Madrid/O=MiOrg/CN=cliente"

openssl x509 -req -in $CLIENT_DIR/client.csr -CA $CA_DIR/ca.crt \
    -CAkey $CA_DIR/ca.key -CAcreateserial \
    -out $CLIENT_DIR/client.crt -days $DAYS -sha256

# (Opcional) PKCS#12 para importar en navegador
openssl pkcs12 -export -clcerts -inkey $CLIENT_DIR/client.key \
    -in $CLIENT_DIR/client.crt \
    -out $CLIENT_DIR/client.p12 -passout pass:
chown -R apache:apache $CA_DIR
echo
echo "### Certificados generados en $BASE_DIR ###"
echo "CA:        $CA_DIR/ca.crt"
echo "Servidor:  $SERVER_DIR/server.crt y server.key"
echo "Cliente:   $CLIENT_DIR/client.crt, client.key y client.p12"

