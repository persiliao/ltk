#!/bin/sh
 
# Generate the openssl configuration files.
echo "创建openssl.cnf------------------->"
 
cat > openssl.cnf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
[req_distinguished_name]
countryName = Country Name (2 letter code)
countryName_default = CN
stateOrProvinceName = State or Province Name (full name)
stateOrProvinceName_default = HN
localityName = Locality Name (eg, city)
localityName_default = ZZ
organizationalUnitName  = Organizational Unit Name (eg, section)
organizationalUnitName_default  = xxx
commonName = commonName
commonName_default = xxx
commonName_max  = 64
[ v3_req ]
# Extensions to add to a certificate request
basicConstraints = CA:TRUE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
IP.1 = 172.16.3.17
IP.2 = 127.0.0.1
EOF

echo "创建v3.ext------------------->"
cat > v3.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage=digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName=@alt_names
[alt_names]
IP.1 = 172.16.3.17
IP.2 = 127.0.0.1
EOF

echo "创建CA 根证书------------------------->"
echo "创建私钥 ca.key"
openssl genrsa -out ca.key 2048
 
echo "创建CA证书 ca.crt"
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt
 
echo "生成服务器证书----------------->"
echo "创建私钥 server.key"
openssl genrsa -out server.key 2048
 
echo "创建服务器证书请求文件 server.csr"
openssl req -new -days 3650 -key server.key -out server.csr -config openssl.cnf
 
echo "创建服务器证书 server.crt"
openssl x509 -days 3650 -req -sha256 -extfile v3.ext -CA ca.crt -CAkey ca.key -CAcreateserial -in server.csr -out server.crt
 
echo "创建pem------------------------>"
cat server.crt server.key > server.pem
 
echo "创建p12----------------------->"
openssl pkcs12 -export -in server.crt -inkey server.key -out server.p12 -name "server"
 