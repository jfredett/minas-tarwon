# generate a self-signed certificate for the given domain
[group('cert')]
self-signed-cert DOMAIN:
    #!/usr/bin/env bash

    set -euo pipefail

    TARGET_PATH="narya/modules/infra/trusted-certs/{{DOMAIN}}"

    mkdir -p $TARGET_PATH

    if ! [ -e "$TARGET_PATH/ssl.cfg" ] ; then
        echo "=> Copy templates to the domain directory"
        cp ./just/ssl.cfg "$TARGET_PATH/ssl.cfg"
        cp ./just/ssl.cfg "$TARGET_PATH/ssl.ext"
        echo "=> Edit the ssl.cfg file in the domain directory, then rerun to create the cert"
        exit 0
    fi

    pushd $TARGET_PATH

    echo "=> Create a private key"
    openssl genpkey                 \
      -algorithm RSA                \
      -pkeyopt rsa_keygen_bits:2048 \
      -out {{DOMAIN}}.key

    echo "=> Create the pubkey from the privkey"
    openssl pkey -in {{DOMAIN}}.key -pubout -out {{DOMAIN}}.pub

    echo "=> Create a CSR for this key"
    openssl req -new -config ssl.cfg -key {{DOMAIN}}.key -out {{DOMAIN}}.csr

    echo "=> Sign the CSR"
    openssl x509 -req -days 3650 -in {{DOMAIN}}.csr -signkey {{DOMAIN}}.key -out {{DOMAIN}}.ss.crt -extfile ssl.ext

    echo "=> Make the Self-signed PEM"
    cat {{DOMAIN}}.ss.crt {{DOMAIN}}.key > {{DOMAIN}}.ss.pem

    echo "=> Fix key permissions"
    chmod 400 {{DOMAIN}}.key

    popd




# install the key to a certificate on the given host in the canonical location
[group('cert')]
install-key DOMAIN HOST:
    #!/usr/bin/env bash

    scp "narya/modules/infra/trusted-certs/{{DOMAIN}}/{{DOMAIN}}.key" "{{HOST}}:{{DOMAIN}}.key"
    ssh "{{HOST}}" <<SCRIPT
        sudo mv "{{DOMAIN}}.key" "/run/keys/{{DOMAIN}}.key"
        sudo chown nginx:nginx "/run/keys/{{DOMAIN}}.key"
        sudo chmod 400 "/run/keys/{{DOMAIN}}.key"
    SCRIPT
