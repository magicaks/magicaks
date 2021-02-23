# Magic AKS Setup

> **IMPORTANT:** There is a cost associated with provisioning resources on Azure. Specifically the Azure Firewall costs by the hour. If you are setting this up for testing purposes, you may want to tear down all resources after testing to avoid high bills for resources you don't use.

## Software requirements

We have tested this repo with OSX, Linux and Windows (on [WSL](https://docs.microsoft.com/en-us/windows/wsl/)).

You need to install:

* [curl](https://curl.se/)
* [fluxctl](https://docs.fluxcd.io/en/1.18.0/references/fluxctl.html)

  To install fluxctl on WSL run

    ```bash
    sudo curl -L https://github.com/fluxcd/flux/releases/download/1.21.1/fluxctl_linux_amd64 -o
    /usr/local/bin/fluxctl
    ```

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) logged in with a user with permissions to provision resources and create applications on the AAD.
* [Terraform](https://www.terraform.io/downloads.html) Tested with v0.14.2
* [jq](https://stedolan.github.io/jq/)

You can also use this [Docker dev container](./utils/docker-dev-env/README.md) if you don't want to install the tools on your own machine.

> **NOTE:** The installation assumes that you have an Azure Active Directory, and that you are the owner/admin of this directory or can request to create AAD apps. We will need this for RBAC setup for Kubernetes. For testing purposes you can [create a personal AAD](https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-access-create-new-tenant).

## One time setup

Before provisioning the AKS resources we need to prepare some repositories, set up AAD security groups and Service Principals.

[TODO]: # (is this correct?)

You can do everything in this section once, and reuse the assets when spinning up new AKS clusters.

### 1. Duplicate this repository

[Duplicate](https://docs.github.com/en/github/creating-cloning-and-archiving-repositories/duplicating-a-repository) this repository in GitHub and make your repository private. You will need to change some of the terraform scripts etc. throughout this setup.

### 2. Create an AKS cluster admins AAD group

1. Log in as AAD admin.

    ```sh
    az login
    ```

    > NOTE: You need to log in on tenant that you want to manage RBAC from - to login in to a specific tenant use `az login --tenant <tenant_id>` and if your AAD tenant does not have a subscription, run `az login --tenant <tenant_id> --allow-no-subscriptions` instead.

2. Create a new Azure AD group for the AKS cluster admins

    ```sh
    az ad group create --display-name magicaksadmins --mail-nickname magicaksadmins
    ```

3. Write down the **Object ID** of the group as you will need to supply this when creating the AKS cluster.

### 3. Set up the admin repository and configure RBAC

1. Duplicate the [fabricate-defs repository](https://github.com/magicaks/fabrikate-defs). We recommended making this repository private.

    This will be your Fabrikate High Level Definition (HLD) repo.

    You will use this repository to generate RBAC and Azure Monitor configuration

2. Follow the steps in the [README](https://github.com/magicaks/fabrikate-defs/blob/master/README.md) to set up RBAC for your cluster.

> **NOTE:** Make sure you finish the steps in the README before you continue

### 4. Set up the user workloads manifest repository

1. Duplicate the [k8sworkloads repository](https://github.com/magicaks/k8sworkloads). We recommended making this repository private.

This is user workloads manifest repo where you list non-privileged workloads. Flux gitOps non admin controller will track this repository.

### 5. Create Service Principals for provisioning resources

1. Create a service principal (**terraform-magicaks**) that terraform can use for deploying resources. **Write down the id and password for later.**

    > **NOTE:** Replace SUBSCRIPTION_ID with your own Azure subscription ID

    ```bash
    az ad sp create-for-rbac --role="Contributor" --name "terraform-magicaks" --scopes="/subscriptions/SUBSCRIPTION_ID"
    OBJECT_ID=$(az ad sp show --id app_id_from_above --query objectId)
    az role assignment create --assignee-object-id $OBJECT_ID --role "Resource Policy Contributor" # Needed to assign Azure Policy to cluster.
    ```

    [TODO]: # (why does this need --scopes and not the next one)

2. Create a service principal (**magicaks-grafana**) that grafana can use for talking to log analytics backend. We restrict this service principal to **Monitoring Reader**.

    ```bash
    az ad sp create-for-rbac  --role "Monitoring Reader" --name "magicaks-grafana"
    ```

### 6. Configure Terraform state

Terraform stores state configuration in Azure Storage.

1. If you don't have a storage account to use for terraform state already configured. Create a resource group and a storage account with a container per the instructions from the Microsoft docs [Tutorial: Store Terraform state in Azure Storage](https://docs.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage)

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

2. Note the storage account name, container name and storage access key. You will need the storage access key in step 7.

3. Update the terraform section of [1-preprovision/main.tf](1-preprovision/main.tf) with your values for resource_group_name, container_name, and storage_account_name. Leave the key as **"magicaks-longlasting"**.

    ```terraform
    terraform {
        backend "azurerm" {
            resource_group_name  = "longlasting"
            container_name = "tfstate"
            key = "magicaks-longlasting"
            storage_account_name = "longlasting"
        }
    }
    ```

### 7. Set up the environment variables for terraform

[TODO]: # (create a template in the repository)
[TODO]: # (rename some of these to better names)

1. Create a file called .env with the values gathered in the previous steps

    ```bash
    export ARM_SUBSCRIPTION_ID=
    export ARM_TENANT_ID=
    export ARM_CLIENT_ID=
    export ARM_CLIENT_SECRET=
    # Storage access key where the terraform state information is to be stored.
    export ARM_ACCESS_KEY=
    ```

    | Environment variable | Description | Where to find it |
    | -- | -- | -- |
    | ARM_SUBSCRIPTION_ID | The Azure subscription ID for the subscription where you want to provision the resources | In the Azure Portal |
    | ARM_TENANT_ID | The Azure Tenant ID for the tenant where you want to provision the resources | In the Azure Portal |
    | ARM_CLIENT_ID | The **terraform-magicaks** service principal password | Saved in step 5.1 |
    | ARM_CLIENT_SECRET | The **terraform-magicaks** service principal password | Saved in step 5.1 |
    | ARM_ACCESS_KEY | Terraform state storage access key | See step 6 |

    [TODO]: # (verify these - we could probably explain a bit more about where in the portal -- also, is this the tenant of the AAD or where you create the clusters)

2. Set the environment variables

   ```bash
   source .env
   ```

## Prepare to provision resources with terraform

> **NOTE** Terraform requires variables as input. You can provide these either interactively or if there is a terraform.tfvars file present then terraform will detect it and use variable names from there. Each of the folders ([1-preprovision](1-preprovision/terraform.tfvars.tmpl), [2-provision-aks](2-provision-aks/terraform.tfvars.tmpl), [3-postprovision](3-postprovision/terraform.tfvars.tmpl) have a terraform.tfvars.tmpl file. If you want to use terraform.tfvars support you can copy terraform.tfvars.tmpl to terraform.tfvars and fill the values.

1. If you are not logged in already, log in with `az login` to the subscription where you want to deploy the resources.

## Provision Common Resources (preprovision)

Before we provision the AKS clusters, we will provision some common resources that we can use for all clusters such as

* [Azure Virtual Network](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview)
* [Azure Firewall](https://docs.microsoft.com/en-us/azure/firewall/overview)
* [Azure Key Vault](https://docs.microsoft.com/en-us/azure/key-vault/general/basic-concepts)
* [Azure Container Registry](https://docs.microsoft.com/en-us/azure/container-registry/)

1. Open main.tf to verify that you have set the terraform backend variables appropriately and that the names for other resources look ok.

2. *Optionally* set the **location**, **resource_group_name** and **cluster_name** variables in terraform.tfvars.impl and remove the .impl from the name. (If you don't do this, terraform will ask you for these variables when you execute the terraform scripts)

    * **location** is the location where to create the resources, e.g. westeurope
    * **resource_group_name** is the resource group name to create for the long lasting resources
    * **cluster_name** is a prefix for many of the resources, keep this short, and without dashes to fulfill [Azure naming requirements](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules)

3. Execute the terraform scripts to provision the resources (from the [1-preprovision](./1-preprovision/) folder)

    ```bash
    terraform init
    terraform plan
    terraform apply
    ```

> NOTE: It's normal for this to take a long time to provision, especially the Firewall, so relax and grab a coffee.

## Provision an AKS cluster

1. Create a custom Grafana image (from the [./utils/grafana/](./utils/grafana/) folder). **NOTE: Replace registry_name with the name of the Azure Container Registry created during pre-provisioning**

    ```bash
    export registry=<registry_name>
    az acr build -t $registry.azurecr.io/grafana:v1 -r $registry .
    ```

    [TODO]: # (what is this registry_name_here)

2. Create an identity for the cluster

    MagicAKS creates a managed identity cluster. We create the identity for this cluster in the resource group with other long lasting resources, so the permissions remains even if we recreate the cluster. To create an identity follow the steps below:

    ```bash
    export RG_WHERE_NETWORK_EXISTS=magicaks-longlasting
    az identity create --name magicaksmsi --resource-group $RG_WHERE_NETWORK_EXIST
    MSI_CLIENT_ID=$(az identity show -n magicaksmsi -g $RG_WHERE_NETWORK_EXIST -o json | jq -r ".clientId")
    MSI_RESOURCE_ID=$(az identity show -n magicaksmsi -g $RG_WHERE_CLUSTER_EXISTS -o json | jq -r ".id")
    az role assignment create --role "Network Contributor" --assignee $MSI_CLIENT_ID -g $RG_WHERE_NETWORK_EXISTS
    az role assignment create --role "Virtual Machine Contributor" --assignee $MSI_CLIENT_ID -g $RG_WHERE_NETWORK_EXISTS
    ```

    > **NOTE** MagicAKS is not creating a system assigned managed identity, due to current [limitations](https://docs.microsoft.com/en-us/azure/aks/use-managed-identity#create-an-aks-cluster-with-managed-identities) of self managed VNet and static IP address outside the MC_ resource group.

    You will need to provide the Managed Identity ``MSI_RESOURCE_ID`` as a variable to terraform when creating the cluster.

3. Verify that the terraform backend values match your storage account in [./2-provision-aks/main.tf](2-provision-aks/main.tf)

4. Fill out the terraform parameters in [2-provision-aks/terraform.tfvars.tmpl](2-provision-aks/terraform.tfvars.tmpl) and save it without the .tmpl ending.

    [TODO]: # (explain what all the variables are)

5. Provision the cluster

    ```bash
    terraform init
    terraform plan
    terraform apply
    ```

    This step will also download the credentials we need for the following steps for interacting with the cluster.

    This step also creates Grafana and connects it to the log analytics workspace. The terraform scripts also creates Postgres which acts as the storage backend for Grafana.

## Provision support resources

After we provision the cluster, we need to provision all support resources.

This will set up flux for admin and non admin workloads and apply the desired state of the configs to your cluster. During this step we will also create the service bus and other supporting resources.

1. Verify that the terraform backend values match your storage account in [./3-postprovision/main.tf](3-postprovision/main.tf)

2. Fill out the terraform parameters in [3-postprovision/terraform.tfvars.tmpl](3-postprovision/terraform.tfvars.tmpl) and save it without the .tmpl ending.

    [TODO]: # (explain what all the variables are)

3. Provision the support resources

    ```bash
    terraform init
    terraform plan
    terraform apply
    ```

## What have we installed?

Congratulations, you have provisioned your AKS cluster with the following resources

1. AKS cluster.

   1. VMSS node pool with 1 - 5 nodes.
   2. Container insights in enabled.
   3. ~~Pod security policies enabled.~~ (AKS has deprecated PSP in favor of Azure Policy)
   4. RBAC enabled.
   5. Calico as the network plugin
   6. Kubernetes version = 1.19.7

2. Flux gitOps operator
3. Azure KeyVault
4. akv2k8s operator installed to provide seamless access to KeyVault secrets.
5. Service bus integrated and primary connection string stored in KeyVault and exposed in cluster as K8s secret.
6. Integration with Azure Active Directory for K8s RBAC.
7. Pod security policies enabled and a restricted policy added.
8. Azure Policy enabled on the cluster. No policies assigned right now.
9. Azure Firewall integrated with network and application rules as recommended by AKS.
10. Grafana connected to log analytics workspace of the cluster is running in Azure container instance backed by managed Postgresql Azure database.
