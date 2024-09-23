#!/bin/bash

# Generate SSL Certificate

set -e

if [ -s $1 ]; then
  echo "The domain name cannot be empty."
  exit 0
fi

openssl req -x509 -out "${1}.crt" -keyout "${1}.key" \
  -newkey rsa:2048 -nodes -sha256 \
  -subj "/CN=${1}" -extensions EXT -config <( \
   printf "[dn]\nCN=${1}\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:${1}\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth")
