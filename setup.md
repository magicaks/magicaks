# MagicAKS setup

If you run into issues, check the [Troubleshooting](#Troubleshooting) section.

> **Important:** There is a cost associated with provisioning these resources on Azure. Specifically, the Azure Firewall has an hourly billing rate. If you are setting this up for testing purposes, you should tear down all resources after testing to avoid high bills for resources you don't use.

## Software requirements

We have tested this repo with OSX, Linux and Windows (on [WSL2](https://docs.microsoft.com/en-us/windows/wsl/)).

You need to install:

* [curl](https://curl.se/)
* [fluxctl](https://docs.fluxcd.io/en/1.18.0/references/fluxctl.html)

  To install fluxctl on WSL run

    ```bash
    sudo curl -L https://github.com/fluxcd/flux/releases/download/1.21.1/fluxctl_linux_amd64 -o
    /usr/local/bin/fluxctl
    chmod a+x /usr/local/bin/fluxctl
    ```

    > Note the version number in the URL above.

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) [logged in](https://docs.microsoft.com/en-us/cli/azure/authenticate-azure-cli) with a user with permissions to provision resources in Azure and manage [Azure Active Directory (AAD)](https://azure.microsoft.com/en-us/services/active-directory/).
* [Terraform](https://www.terraform.io/downloads.html) (tested with version 0.14.2)
* [jq](https://stedolan.github.io/jq/)

You can also use this [Docker dev container](./utils/docker-dev-env/README.md), if you don't want to install the tools in your native environment, but note that there can be additional considerations using the Docker development environment that are not covered by this guide.

> **Note:** The installation assumes that you have an Azure Active Directory (AAD), and that you are the owner/admin of this directory or can request to create AAD apps. We will need this for [role-based access control (RBAC)](https://docs.microsoft.com/en-us/azure/role-based-access-control/overview) setup for Kubernetes. For testing purposes you can [create a personal AAD](https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-access-create-new-tenant).

## One time setup

Before provisioning the AKS resources we need to prepare some repositories, set up AAD security groups and service principals.

You can do everything in this section once, and reuse the assets when spinning up new AKS clusters.

### 1. Duplicate this repository

[Duplicate](https://docs.github.com/en/github/creating-cloning-and-archiving-repositories/duplicating-a-repository) this repository in GitHub and make your repository private. You will need to change some of the Terraform scripts etc. throughout this setup.

### 2. Create an AKS cluster admins AAD group

1. Log in as AAD admin:

    ```sh
    az login
    ```

    > **NOTE:** You need to log in on tenant that you want to manage RBAC from - to login in to a specific tenant use `az login --tenant <tenant_id>` and if your AAD tenant does not have a subscription, run `az login --tenant <tenant_id> --allow-no-subscriptions` instead.

1. Create a new Azure AD group for the AKS cluster admins:

    ```sh
    az ad group create --display-name magicaksadmins --mail-nickname magicaksadmins
    ```

1. Write down the **Object ID** of the group as you will need to supply this when creating the AKS cluster.

### 3. Set up the admin repository and configure RBAC

1. Duplicate the [Fabrikate high-level definitions (HLD) repository](https://github.com/magicaks/fabrikate-defs). We recommend making this repository private. You will use this repository, for example, to generate RBAC and Azure Monitor configuration.
1. Follow the steps in the [Fabrikate definitions repository README](https://github.com/magicaks/fabrikate-defs/blob/master/README.md) to set up RBAC for your cluster.

> **Note:** Make sure you finish the steps in the README before you continue.

### 4. Set up the user workloads manifest repository

1. Duplicate the [k8sworkloads repository](https://github.com/magicaks/k8sworkloads). We recommended making this repository private.

This is user workloads manifest repo where you list non-privileged workloads. [Flux (GitOps)](https://fluxcd.io/) non-admin controller will track this repository.

### 5. Create service principals for provisioning resources

1. Create a service principal (**magicaks-terraform**) that terraform can use for deploying resources. **Write down the id and password for later.**

    > **Note:** Replace `SUBSCRIPTION_ID` with your own Azure subscription ID.

    ```bash
    az ad sp create-for-rbac --role="Contributor" --name "magicaks-terraform" --scopes="/subscriptions/SUBSCRIPTION_ID"
    eval OBJECT_ID=$(az ad sp show --id app_id_from_above --query objectId)
    az role assignment create --assignee-object-id $OBJECT_ID --role "Resource Policy Contributor" # Needed to assign Azure Policy to cluster.
    ```

1. Create a service principal (**magicaks-grafana**) that Grafana can use for talking to Log Analytics backend. We restrict this service principal to **Monitoring Reader** role.

    ```bash
    az ad sp create-for-rbac --role "Monitoring Reader" --name "magicaks-grafana"
    ```

### 6. Configure Terraform state

Terraform stores state configuration in Azure Storage.

1. If you don't have a storage account to use for Terraform state already configured, create a resource group and a storage account with a container per the instructions from the Microsoft docs: [Tutorial: Store Terraform state in Azure Storage](https://docs.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage):

    ```bash
    #!/bin/bash

    RESOURCE_GROUP_NAME=tstate
    STORAGE_ACCOUNT_NAME=tstate$RANDOM
    CONTAINER_NAME=tstate
    LOCATION=eastus

    # Create resource group
    az group create --name $RESOURCE_GROUP_NAME --location $LOCATION

    # Create storage account
    az storage account create --resource-group $RESOURCE_GROUP_NAME --name $STORAGE_ACCOUNT_NAME --sku Standard_LRS --encryption-services blob

    # Get storage account key
    ACCOUNT_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP_NAME --account-name $STORAGE_ACCOUNT_NAME --query '[0].value' -o tsv)

    # Create blob container
    az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME --account-key $ACCOUNT_KEY

    echo "storage_account_name: $STORAGE_ACCOUNT_NAME"
    echo "container_name: $CONTAINER_NAME"
    echo "access_key: $ACCOUNT_KEY"
    ```

1. Note the storage account name, container name and storage access key. You will need the storage access key in step 7.

1. Copy the Terraform remote backend configuration [backend.tfvars.tmpl](./backend.tfvars.tmpl) file and remove the `.tmpl` postfix from the filename. Update the variables for the values `resource_group_name`, `container_name`, and `storage_account_name`. This is the configuration to store Terraform state in an Azure Storage Account.

    ```bash
    resource_group_name  = "longlasting"
    container_name = "tfstate"
    storage_account_name = "longlasting"
    ```
    > In each of the Terraform files for preprovision, provision and postprovision, the [Terraform remote backend configuration](https://www.terraform.io/docs/language/settings/backends/azurerm.html) key is pre-configured. This will create one state file per step named `magicaks-preprovision`, `magicaks-provision` and `magicaks-postprovision`.

### 7. Set up the environment variables for Terraform

1. Create a file called .env with the values gathered in the previous steps

    ```bash
    export ARM_SUBSCRIPTION_ID=
    export ARM_TENANT_ID=
    export ARM_CLIENT_ID=
    export ARM_CLIENT_SECRET=
    # Storage access key where the terraform state information is to be stored.
    export ARM_ACCESS_KEY=
    # Applies the Terraform remote backend configuration and 'Terraform init' commands
    export TF_CLI_ARGS_init='-backend-config=../backend.tfvars'
    ```

    | Environment variable | Description | Where to find it |
    | -- | -- | -- |
    | ARM_SUBSCRIPTION_ID | The Azure subscription ID for the subscription where you want to provision the resources | In the Azure Portal |
    | ARM_TENANT_ID | The Azure Tenant ID for the tenant where you want to provision the resources | In the Azure Portal |
    | ARM_CLIENT_ID | The **magicaks-terraform** service principal ID | Saved in step 5.1 |
    | ARM_CLIENT_SECRET | The **magicaks-terraform** service principal password | Saved in step 5.1 |
    | ARM_ACCESS_KEY | Terraform state storage access key | See step 6 |
    | TF_CLI_ARGS_init | Terraform remote storage configuration file location | [backend.tfvars](./backend.tfvars) |

1. Set the environment variables

   ```bash
   source .env
   ```

## Prepare to provision resources with terraform

> **Note:** Terraform requires variables as input. You can provide these either interactively or if there is a `terraform.tfvars` file present then Terraform will detect it and use the variables there. Each of the folders ([1-preprovision](1-preprovision/terraform.tfvars.tmpl), [2-provision-aks](2-provision-aks/terraform.tfvars.tmpl), [3-postprovision](3-postprovision/terraform.tfvars.tmpl) have a `terraform.tfvars.tmpl` file. If you want to use `terraform.tfvars` support, you can rename/copy `terraform.tfvars.tmpl` to `terraform.tfvars` and fill in the values.

1. If you are not logged in already, log in with `az login` to the subscription where you want to deploy the resources.

## Provision common resources (pre-provision)

Before we provision the AKS clusters, we will provision some common resources that we can use for all clusters such as:

* [Azure Virtual Network](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview)
* [Azure Firewall](https://docs.microsoft.com/en-us/azure/firewall/overview)
* [Azure Key Vault](https://docs.microsoft.com/en-us/azure/key-vault/general/basic-concepts)
* [Azure Container Registry](https://docs.microsoft.com/en-us/azure/container-registry/)

1. *Optionally* set the `location`, `resource_group_name` and `cluster_name` variables in `terraform.tfvars.tmpl` and remove the `.impl` postfix from the filename. (If you don't do this, Terraform will ask you for these variables when you execute the Terraform scripts.)

    * **location** is the location where to create the resources, e.g. westeurope
    * **resource_group_name** is the resource group name to create for the long lasting resources
    * **cluster_name** is a prefix for many of the resources, keep this short, and without dashes to fulfill [Azure naming requirements](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules)

1. Execute the Terraform scripts to provision the resources (from the [1-preprovision](./1-preprovision/) folder):

    ```bash
    terraform init
    terraform plan
    terraform apply
    ```

> Note: It's normal for this to take a long time to provision, especially the Firewall, so relax and grab a coffee.

## Provision an AKS cluster

1. Create a custom Grafana image (from the [./utils/grafana/](./utils/grafana/) folder). **NOTE: Replace registry_name with the name of the Azure Container Registry created during pre-provisioning**

    ```bash
    export registry=<registry_name>
    az acr build -t $registry.azurecr.io/grafana:v1 -r $registry .
    ```

2. Create an identity for the cluster

    MagicAKS creates a managed identity cluster. We create the identity for this cluster in the resource group with other long lasting resources, so the permissions remain even if we recreate the cluster. To create an identity follow the steps below:

    ```bash
    export RG_WHERE_NETWORK_EXISTS=magicaks-longlasting
    az identity create --name magicaksmsi --resource-group $RG_WHERE_NETWORK_EXIST
    MSI_CLIENT_ID=$(az identity show -n magicaksmsi -g $RG_WHERE_NETWORK_EXIST -o json | jq -r ".clientId")
    MSI_RESOURCE_ID=$(az identity show -n magicaksmsi -g $RG_WHERE_CLUSTER_EXISTS -o json | jq -r ".id")
    az role assignment create --role "Network Contributor" --assignee $MSI_CLIENT_ID -g $RG_WHERE_NETWORK_EXISTS
    az role assignment create --role "Virtual Machine Contributor" --assignee $MSI_CLIENT_ID -g $RG_WHERE_NETWORK_EXISTS
    ```

    > **Note:** MagicAKS is not creating a system assigned managed identity, due to current [limitations](https://docs.microsoft.com/en-us/azure/aks/use-managed-identity#create-an-aks-cluster-with-managed-identities) of self-managed VNet and static IP address outside the MC_ resource group.

    You will need to provide the managed identity `MSI_RESOURCE_ID` as a variable to Terraform when creating the cluster.

3. Fill out the Terraform parameters in [2-provision-aks/terraform.tfvars.tmpl](2-provision-aks/terraform.tfvars.tmpl) and save it without the `.tmpl` filename postfix.
4. Provision the cluster:

    ```bash
    terraform init
    terraform plan
    terraform apply
    ```

    Along with provisioning the cluster, the terraform script will also download the credentials we need for the following steps for interacting with the cluster. It will also create a Grafana instance and connects it to the Log Analytics workspace as well as Postgres, which acts as the storage backend for Grafana.

## Provision support resources

After we provision the cluster, we need to provision all support resources.

This will set up Flux for admin and non-admin workloads and apply the desired state of the configs to your cluster. During this step we will also create the service bus and other supporting resources.

1. Verify that the Terraform backend values match your storage account in [./3-postprovision/main.tf](3-postprovision/main.tf).
1. Fill out the Terraform parameters in [3-postprovision/terraform.tfvars.tmpl](3-postprovision/terraform.tfvars.tmpl) and save it without the `.tmpl` filename postfix.
1. Provision the support resources:

    ```bash
    terraform init
    terraform plan
    terraform apply
    ```

## What have we installed?

Congratulations, you have provisioned your AKS cluster with the following resources:

* AKS cluster with

  * VMSS node pool with 1 - 5 nodes
  * Container Insights enabled
  * ~~Pod security policies enabled~~ (AKS has deprecated PSP in favor of Azure Policy)
  * RBAC enabled
  * Calico as the network plugin
  * Kubernetes version = 1.19.7

* Flux GitOps operator
* Azure Key Vault
* akv2k8s operator installed to provide seamless access to Key Vault secrets
* Service bus integrated and primary connection string stored in Key Vault and exposed in cluster as K8s secret
* Integration with Azure Active Directory for K8s RBAC
* Azure Policy enabled on the cluster (no policies assigned right now)
* Azure Firewall integrated with network and application rules as recommended by AKS
* Grafana connected to Log Analytics workspace of the cluster is running in Azure Container Instances backed by managed PostgreSQL database

## Troubleshooting

* Terraform authentication error

    ```bash
    Error: Failed to get existing workspaces: containers.Client#ListBlobs: Failure responding to request: StatusCode=403 -- Original Error: autorest/azure: Service returned an error. Status=403 Code="AuthenticationFailed" Message="Server failed to authenticate the request. Make sure the value of Authorization header is formed correctly including the signature.\nRequestId:e4c5cf49-801e-0068-4539-0cb9e7000000\nTime:2021-02-26T12:18:40.6499706Z"
    ```

    This is due to WSL clock skew. Fix it by running this command:

    ```bash
    sudo hwclock -s
    ```

*  Line endings not correct for bash scripts

    ```bash
    Error: Error running command '/mnt/c//2-provision-aks/getcreds.sh ': exit status 127. Output: /bin/sh: 1: /mnt/c//2-provision-aks/getcreds.sh: not found
    ```

    *We know it's the 21 century, but check the line endings*. Line endings must be in LF format instead of CRLF. You may run into this issue, if you clone the repository in Windows for example. Check the line endings of all the bash script files (`*.sh`) in the repository and set them to LF format to correct the problem.

    You can use the `dos2unix` utility to do the conversion. Install it via `apt-get`.

- When does this happen Tess?

    ```bash
    Error: failed to create resource: namespaces "app1" not found
    ```

    This is due to a timing issue where `app1` is not yet created - wait a few minutes, rerun the apply and it should work.
