# Docker Cert Tool

This container is designed to test for the presence of and generate SSL certificates and keys using OpenSSL when needed. It's built on the Alpine Linux image and will create a certificate and key in the `/certs` volume if they don't already exist.

## Image Description

The Docker image is based on the latest Alpine Linux image. OpenSSL is installed in the container to handle the creation of the certificates and keys. A script named `entrypoint.sh` is used to generate the certificates and keys if they are not present in the `/certs` volume.

## Usage

To use this container, you need to build the Docker image and then run the container while specifying the necessary environment variables and volume.

### Building the Image

First, build the image using the provided Dockerfile:

````
docker build -t build-certs .
````

### Running the Container

To run the container, use the following command:

docker run -v /path/to/certs:/certs build-certs

Replace `/path/to/certs` with the path where you want to store the certificates and keys on your host machine.

### Environment Variables

The script within the container supports several environment variables to customize the generated certificates:

- `CA_CN`: Common Name for the Certificate Authority. Default is "CertificateCA".
- `CERTIFICATE_CN`: Common Name for the certificate. Default is "certificate".
- `CERTIFICATE_SAN`: Subject Alternative Names for the certificate. Should be a comma-separated list. Default is "certificate".
- `DAYS_VALID`: Number of days the certificate is valid. Default is 365.

You can set these environment variables using the `-e` flag in the `docker run` command. For example:

````
docker run -v /path/to/certs:/certs -e CA_CN="MyCustomCACN" -e CERTIFICATE_CN="mydomain.com" build-certs
````

## Volume

The `/certs` volume is used to store the generated certificate (`certificate.crt`) and key (`certificate.key`). If these files already exist in the volume (for example if it is bind mounted), the script will not generate new ones. This allows the container to run as a build in workflows that support testing and production deployments.

## Using in Docker Compose

You can also use the container within a Docker Compose setup. Below is an example `docker-compose.yml` file that demonstrates how to use the generator in conjunction with another service that depends on it.

````
version: '3.8'

services:
  build-certs:
    build: .
    volumes:
      - ./certs:/certs

  webserver:
    image: nginx
    volumes:
      - ./certs:/etc/nginx/certs:ro
    depends_on:
      - build-certs
````

In this `docker-compose.yml`:

- The `build-certs` service is responsible for generating the SSL certificates.
- The `webserver` service (using the NGINX image as an example) depends on the `build-certs`. It mounts the same volume to read the certificates.
- The `depends_on` directive ensures that the `webserver` service starts only after the `build-certs` service has completed its execution.

Ensure that the certificates directory (`./certs`) exists on your host machine or is created by the SSL Certificate Generator service.
