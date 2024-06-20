#!/bin/sh

# Directory where the certificates and key will be stored
CERT_DIR="${CERT_DIR:-/certs}"

# File names for the certificate and key
CERT_FILE="${CERT_FILE:-certificate.crt}"
KEY_FILE="${KEY_FILE:-certificate.key}"
KEYSTORE_TEMP_FILE="${KEYSTORE_TEMP_FILE:-staging-keystore.jks}"
KEYSTORE_FILE="${KEYSTORE_FILE:-keystore.jks}"
CERTIFICATE_CSR="${CERTIFICATE_CSR:-certificate.csr}"
CERTIFICATE_CSR_CONF="${CERTIFICATE_CSR_CONF:-certificate_csr.conf}"

# Set default values for environment variables if not set
CA_CN="${CA_CN:-CertificateCA}"
CERTIFICATE_CN="${CERTIFICATE_CN:-localhost}"
CERTIFICATE_SAN="${CERTIFICATE_SAN:-localhost}"
DAYS_VALID="${DAYS_VALID:-365}"
KEYSTORE_PASSWORD="${KEYSTORE_PASSWORD:-password}"

# Function to generate a CA, CSR, and sign the CSR
generate_certs() {
    # Generate a private key for CA
    openssl genrsa -out "$CERT_DIR/ca.key" 2048

    # Generate a CA certificate
    openssl req -x509 -new -nodes -key "$CERT_DIR/ca.key" -sha256 -days "$DAYS_VALID" -out "$CERT_DIR/ca.crt" \
        -subj "/CN=$CA_CN"

    # Generate a private key for CSR
    openssl genrsa -out "$CERT_DIR/$KEY_FILE" 2048

    # Generate a CSR configuration file
    cat > "$CERT_DIR/$CERTIFICATE_CSR_CONF" <<-EOF
    [req]
    distinguished_name = req_distinguished_name
    req_extensions = v3_req
    prompt = no

    [req_distinguished_name]
    CN = $CERTIFICATE_CN

    [v3_req]
    keyUsage = critical, digitalSignature, keyEncipherment
    extendedKeyUsage = serverAuth, clientAuth
    subjectAltName = @alt_names

    [alt_names]
EOF

    # Append SAN entries
    index=1
    OLDIFS=$IFS
    IFS=','
    for san in $CERTIFICATE_SAN
    do
        echo "DNS.$index = $san" >> "$CERT_DIR/$CERTIFICATE_CSR_CONF"
        index=$((index+1))
    done
    IFS=$OLDIFS

    # Generate a CSR
    openssl req -new -key "$CERT_DIR/$KEY_FILE" -out "$CERT_DIR/$CERTIFICATE_CSR" -config "$CERT_DIR/$CERTIFICATE_CSR_CONF"

    # Sign the CSR with the CA certificate to generate the certificate
    openssl x509 -req -in "$CERT_DIR/$CERTIFICATE_CSR" -CA "$CERT_DIR/ca.crt" -CAkey "$CERT_DIR/ca.key" -CAcreateserial \
        -out "$CERT_DIR/$CERT_FILE" -days "$DAYS_VALID" -sha256 -extfile "$CERT_DIR/$CERTIFICATE_CSR_CONF" -extensions v3_req
}

# Function to create a Java keystore and import the certificates
create_keystore() {
    # Create a PKCS12 keystore from the private key and certificate
    openssl pkcs12 -export -name certificate -in "$CERT_DIR/$CERT_FILE" -inkey "$CERT_DIR/$KEY_FILE" -out "$CERT_DIR/certificate.p12" -password "pass:$KEYSTORE_PASSWORD"

    # Convert the PKCS12 keystore to a Java keystore
    keytool -importkeystore -srckeystore "$CERT_DIR/certificate.p12" -srcstoretype PKCS12 -destkeystore "$CERT_DIR/$KEYSTORE_TEMP_FILE" -deststoretype JKS -srcstorepass "$KEYSTORE_PASSWORD" -deststorepass "$KEYSTORE_PASSWORD" -destkeypass "$KEYSTORE_PASSWORD" -noprompt

    # Import the CA certificate into the Java keystore
    keytool -import -trustcacerts -alias "$CA_CN" -file "$CERT_DIR/ca.crt" -keystore "$CERT_DIR/$KEYSTORE_TEMP_FILE" -storepass "$KEYSTORE_PASSWORD" -noprompt

    # Cat keystore to the correct file
    cat "$CERT_DIR/$KEYSTORE_TEMP_FILE" > "$CERT_DIR/$KEYSTORE_FILE"
}


# Check if both the certificate and key files exist
if [ ! -f "$CERT_DIR/$CERT_FILE" ] || [ ! -f "$CERT_DIR/$KEY_FILE" ]; then
    echo "Certificate and/or key file not found. Generating new ones..."

    # Create CERT_DIR if it does not exist
    mkdir -p "$CERT_DIR"

    # Generate the certificates and keys
    generate_certs
else
    echo "Certificate and key files already exist."
fi

# Check again if both the certificate and key files exist after generation
if [ -f "$CERT_DIR/$CERT_FILE" ] && [ -f "$CERT_DIR/$KEY_FILE" ]; then
    echo "Certificate and key files exist. Creating keystore. Exiting with success."
    create_keystore
    echo "Exiting with success."
    exit 0
else
    echo "Certificate and/or key file generation failed. Exiting with failure."
    exit 1
fi
