#!/bin/bash
function check_deps() {
  test -f $(which jq) || error_exit "jq command not detected in path, please install it"
}
function parse_input() {
  eval "$(jq -r '@sh "export NS=\(.namespace)"')"
  if [[ -z "${NS}" ]]; then export NS=none; fi
}
function return_key() {
  KEY=$(fluxctl identity --k8s-fwd-ns $NS)
  jq -n \
    --arg key "$KEY" \
    '{"key":$key}'
}
check_deps && \
parse_input && \
sleep 30 && \
return_key