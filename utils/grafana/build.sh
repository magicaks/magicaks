#!/bin/bash

ver=$1

docker build --build-arg "GRAFANA_VERSION=latest" \
--build-arg "GF_INSTALL_IMAGE_RENDERER_PLUGIN=true" \
-t grafana:$ver -f Dockerfile .