#!/bin/bash

# Check if required utilities are installed
command -v curl >/dev/null 2>&1 || { echo >&2 "I require curl but it's not installed. See https://curl.se/.  Aborting."; exit 1; }
command -v fluxctl >/dev/null 2>&1 || { echo >&2 "I require fluxctl cli but it's not installed. See https://docs.fluxcd.io/en/1.18.0/references/fluxctl.html. Aborting."; exit 1; }
command -v az >/dev/null 2>&1 || { echo >&2 "I require azure cli but it's not installed. See https://bit.ly/2Gc8IsS. Aborting."; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo >&2 "I require terraform but it's not installed. See https://www.terraform.io/downloads.html.  Aborting."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo >&2 "I require jq but it's not installed. See https://stedolan.github.io/jq/.  Aborting."; exit 1; }

# Check if user is logged in
[[ -n $(az account show 2> /dev/null) ]] || { echo "Please login via the Azure CLI: "; az login; }
