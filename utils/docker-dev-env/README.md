# Docker development environment

> The current image is not complete to support the entire process

This Docker image provides an isolated development environment with the required tools to run in your host system. Since the utility scripts, for example, have been written as Bash scripts, Windows users in particular may have problems setting up their development environment. The Docker image takes care of that.

## Setup instructions

1. Install [Docker](https://docs.docker.com/get-docker/)
    * Run `docker` command in terminal (e.g. PowerShell) to make sure the installation was successful
1. Launch terminal and navigate to this folder (where the [Dockerfile](./Dockerfile) lives)
1. Build the Docker image:

    ```plaintext
    docker build -t magicaks-dev-env:latest .
    ```

    In the example above, "`magicaks-dev-env`" is the name of the image to create and is used throughout these instructions.
1. Run the Docker image:

    ```plaintext
    docker run -i -t magicaks-dev-env bash
    ```

1. Now inside the running Docker container, list files to verify the image was properly created:

    ```plaintext
    root@626be9d44688:~/magicaks# ll -a
    ````

    The files in the root of the cloned Magic AKS repository are listed:

    ```plaintext
    .  
    ..  
    .git  
    .github  
    .gitignore  
    1-preprovision  
    2-provision-aks  
    3-postprovision  
    README.md  
    fabrikate-defs  
    utils
    ```

> Do not forget to login to Azure ("`az login`" command) and to select the correct subscriptuon ("`az account set --subscription <subscription ID>`" command) before running the setup scripts in the `utils` folder.

### Cleanup

To remove the Docker image:

1. Open terminal
1. List the Docker images:

    ```plaintext
    docker image ls
    ```

    ```plaintext
    REPOSITORY          TAG     IMAGE ID ...
    magicaks-dev-env    latest  62f6da401265 ...
    ```

1. Copy the `IMAGE ID` (in this case "`62f6da401265`")
1. Remove the image using the copied ID:

    ```plaintext
    docker image rm -f 62f6da401265
    ```

    ```plaintext
    Untagged: magicaks-dev-env:latest
    Deleted: sha256:62f6da401265...
    Deleted: sha256:4ea20ee44ec1...
    Deleted: sha256:a9e886e57342...
    ```

## References

* [Use the Docker command line](https://docs.docker.com/engine/reference/commandline/cli/)
* [Get started with Azure CLI](https://docs.microsoft.com/en-us/cli/azure/get-started-with-azure-cli?view=azure-cli-latest)
