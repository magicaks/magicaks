#!/bin/bash

# This script copies the MagicAKS repositories to the user/organization defined by the personal
# access token provided. Only the content in main branch is included and without history.
# The copied repository is set private.
#
# Note: The personal access token must have "repo" permission set
# See https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token

# MagicAKS repositories to copy
REPOSITORIES=(fabrikate-defs k8sworkloads k8smanifests)

GITHUB_REPOS_API_BASE_URL=https://api.github.com/repos
PERSONAL_ACCESS_TOKEN=$1

if [ -z "$PERSONAL_ACCESS_TOKEN" ]
then
    echo "MagicAKS GitHub repository copier script"
    echo
    echo "Usage: $0 <GitHub personal access token value>"
    echo
    echo "Note: The personal access token must have "repo" permission set"
    echo "See https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token for more information"
    exit 1
fi

for REPOSITORY in ${REPOSITORIES[@]}; do
    # Get the description of the repository
    DESCRIPTION=$(curl "$GITHUB_REPOS_API_BASE_URL/magicaks/$REPOSITORY" | jq --raw-output '.description')

    echo "Copying repository \"$REPOSITORY\""
    echo "Description: $DESCRIPTION"

    RESPONSE_BODY='{"name":"'"$REPOSITORY"'","description":"'"$DESCRIPTION"'","private":true}'

    # Create a new repository from the template
    curl \
        --header "Authorization: token $PERSONAL_ACCESS_TOKEN" \
        --header "Accept: application/vnd.github.baptiste-preview+json" \
        --request POST \
        --data "$RESPONSE_BODY" \
        $GITHUB_REPOS_API_BASE_URL/magicaks/$REPOSITORY/generate
done

echo "Finished"
