#!/usr/bin/env bash

function verify_access_token() {
    echo "VERIFYING PERSONAL ACCESS TOKEN"
    if [[ -z "$ACCESS_TOKEN_SECRET" ]]; then
        echo "Please set env var ACCESS_TOKEN_SECRET for git host: $GIT_HOST"
        exit 1
    fi
}
function verify_repo() {
    echo "CHECKING HLD/MANIFEST REPO URL"
    # shellcheck disable=SC2153
    if [[ -z "$REPO" ]]; then
        echo "HLD/MANIFEST REPO URL not specified in variable $REPO"
        exit 1
    fi
}

# Install the HLD repo if it's not running as part of the HLD build pipeline
function install_hld() {
    echo "DOWNLOADING HLD REPO"
    echo "git clone $HLD_PATH"
    git clone "$HLD_PATH"
    # Extract repo name from url
    repo=${HLD_PATH##*/}
    repo_name=${repo%%.*}
    echo "Setting HLD path to $repo_name"
    cd "$repo_name"
    echo "HLD DOWNLOADED SUCCESSFULLY"
}

# Install Fabrikate
function install_fab() {
    # Run this command to make script exit on any failure
    echo "FAB INSTALL"
    set -e

    if [ -z "$HLD_PATH" ]; then
        echo "HLD path not specified, going to run fab install in current dir"
    else
        echo "HLD repo specified: $HLD_PATH"
        install_hld
    fi
    fab install
    echo "FAB INSTALL COMPLETED"
}

# Run fab generate
function fab_generate() {
    # For backwards compatibility, support pipelines that have not set this variable
    echo "CHECKING FABRIKATE ENVIRONMENTS"
    if [ -z "$FAB_ENVS" ]; then
        echo "FAB_ENVS is not set"
        echo "FAB GENERATE prod"
        fab generate prod
        generate_rbac_configs prod $(pwd)
        generate_azmon_configs prod $(pwd)
    else
        echo "FAB_ENVS is set to $FAB_ENVS"
        IFS=',' read -ra ENV <<< "$FAB_ENVS"
        for i in "${ENV[@]}"; do
            echo "FAB GENERATE $i"
            # In this case, we do want to split the string by unquoting $i so that the fab generate command
            # recognizes multiple environments as separate strings.
            # shellcheck disable=SC2086
            fab generate $i
            generate_rbac_configs $i $(pwd)
            generate_azmon_configs $i $(pwd)
        done
    fi

    echo "FAB GENERATE COMPLETED"
    set +e

    # If generated folder is empty, quit
    # In the case that all components are removed from the source hld,
    # generated folder should still not be empty
    if find "generated" -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
        export manifest_files_location=$(pwd)
        echo "Manifest files have been generated in `pwd`."
    else
        echo "Manifest files could not be generated in `pwd`, quitting..."
        exit 1
    fi
}

# Authenticate with Git
function git_connect() {
    cd "$HOME"
    # Remove http(s):// protocol from URL so we can insert PA token
    repo_url=$REPO
    repo_url="${repo_url#http://}"
    repo_url="${repo_url#https://}"

    echo "GIT CLONE: https://automated:<ACCESS_TOKEN_SECRET>@$repo_url"
    git clone "https://automated:$ACCESS_TOKEN_SECRET@$repo_url"

    # Extract repo name from url
    repo_url=$REPO
    repo=${repo_url##*/}
    repo_name=${repo%.*}

    cd "$repo_name"
    echo "GIT PULL ORIGIN MASTER"
    git pull origin master
}

# Git commit
function git_commit() {
    echo "GIT CHECKOUT $BRANCH_NAME"
    if ! git checkout "$BRANCH_NAME" ; then
        git checkout -b "$BRANCH_NAME"
    fi

    echo "GIT STATUS"
    git status
    echo "GIT REMOVE"
    rm -rf ./*/
    git rm -rf ./*/
    echo "COPY YAML FILES FROM $manifest_files_location/generated/ TO REPO DIRECTORY..."
    cp -r "$manifest_files_location/generated/"* .
    echo "GIT ADD"
    git add -A

    #Set git identity
    git config user.email "automated@magicaks.io"
    git config user.name "Automated Account"

    if [[ $(git status --porcelain) ]]; then
        echo "GIT COMMIT"
        git commit -m "Updated k8s manifest files post commit: $COMMIT_MESSAGE"
        retVal=$? && [ $retVal -ne 0 ] && exit $retVal
    else
        echo "NOTHING TO COMMIT"
    fi

    echo "GIT PULL origin $BRANCH_NAME"
    git pull origin "$BRANCH_NAME"
}

# Perform a Git push
function git_push() {
    # Remove http(s):// protocol from URL so we can insert PA token
    repo_url=$REPO
    repo_url="${repo_url#http://}"
    repo_url="${repo_url#https://}"

    echo "GIT PUSH: https://<ACCESS_TOKEN_SECRET>@$repo_url"
    git push "https://$ACCESS_TOKEN_SECRET@$repo_url"
    retVal=$? && [ $retVal -ne 0 ] && exit $retVal
    echo "GIT STATUS"
    git status
}

function unit_test() {
    echo "Sourcing build.sh ..."
}

function verify_pull_request() {
    echo "Starting verification"
    install_fab
    fab_generate
}

function generate_rbac_configs() {
    echo "generate rbac configs"
    python rbac-generator.py $1 $2
}

function generate_azmon_configs() {
    echo "generate azure monitor configs"
    python azmonconfig-generator.py $1 $2
}

# Run functions
function verify_pull_request_and_merge() {
    verify_repo
    verify_access_token
    verify_pull_request
    echo "Verification complete, push to yaml repo"
    git_connect
    git_commit
    git_push
}

echo $1
export PATH=$1:$PATH
echo $PATH

verify_pull_request_and_merge