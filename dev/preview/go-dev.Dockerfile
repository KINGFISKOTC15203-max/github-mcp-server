# Development image for the Base44 sandbox.
#
# Only the Go toolchain and the `air` live-reload watcher live in this image.
# The repository itself is bind-mounted at /src by docker-compose.base44.yml and
# built inside the container, so source edits are never baked into a layer.
FROM golang:1.27.1-alpine

RUN apk add --no-cache git && \
    GOBIN=/usr/local/bin go install github.com/air-verse/air@v1.67.4

WORKDIR /src
