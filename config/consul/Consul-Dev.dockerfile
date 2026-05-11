# Copyright IBM Corp. 2021, 2026
# SPDX-License-Identifier: MPL-2.0

ARG CONSUL_IMAGE_VERSION=latest
FROM consul:${CONSUL_IMAGE_VERSION}
RUN apk update && \
    apk add coreutils 
COPY consul /bin/consul
