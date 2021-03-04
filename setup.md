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

**Optional:** Run `./utils/scripts/verify-prerequisites.sh` to verify that you have installed all pre-requisites for MagicAKS.

> **Note:** The installation assumes that you have an Azure Active Directory (AAD), and that you are the owner/admin of this directory or can request to create AAD apps. We will need this for [role-based access control (RBAC)](https://docs.microsoft.com/en-us/azure/role-based-access-control/overview) setup for Kubernetes. For testing purposes you can [create a personal AAD](https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-access-create-new-tenant).

## One time setup

Before provisioning the AKS resources we need to prepare some repositories, set up AAD security groups and service principals.

You can do everything in this section once, and reuse the assets when spinning up new AKS clusters.

### 1. Duplicate repositories

1. Create a new, **private** `magicaks` repository for yourself using the following link: [`https://github.com/magicaks/magicaks/generate`](https://github.com/magicaks/magicaks/generate)
1. Clone the repository
1. [Create a personal access token](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) with **repo** scope (full control of private repositories)
    > **Note:** Make sure to copy the access token value once created, because you cannot access it again.
1. Run the repository copier script:

    ```bash
    ./utils/scripts/copy-repos.sh <GitHub personal access token value>
    ```

    * This will copy the following three repositories:
        * [magicaks/fabrikate-defs](https://github.com/magicaks/fabrikate-defs)
        * [magicaks/k8sworkloads](https://github.com/magicaks/k8sworkloads)
        * [magicaks/k8smanifests](https://github.com/magicaks/k8smanifests)
    * Alternatively, you create the repositories manually using the same method as for the main (`magicaks`) repository in step 1

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

Follow the steps in your copy of the [Fabrikate definitions repository README](https://github.com/magicaks/fabrikate-defs/blob/master/README.md) to set up RBAC for your cluster.

> **Note:**
>
> * Make sure you finish the steps in the README before you continue
> * You can safely ignore the steps in the README you've already completed such as duplicating the manifest repository and creating a personal access token

### 4. Create service principals for provisioning resources

We need to create two service principals:

* `magicaks-terraform`: Terraform will use this for deploying resources and assign Azure policy for the cluster
* `magicaks-grafana`: Grafana will use this to talk to the Log Analytics backend (restricted to "Monitoring Reader" role)

1. Get the subscription ID of your Azure account

    > **Note:** Use the subscription ID associated with the tenant of active directory used. If your active directory where RBAC is managed is different from where subscription is present you need to log into the correct tenant using ``az login --tenant <tenand ID>`` before running the following commands.

1. Run the script to create required service principals and **collect the app IDs and passwords from the output**:

    ```bash
    ./utils/scripts/create-service-principals.sh <Azure subscription ID>
    ```

    * **Or** if you prefer to run the steps manually:

        ```bash
        az ad sp create-for-rbac --role "Contributor" --name "http://magicaks-terraform" --scopes="/subscriptions/<SUBSCRIPTION ID>"
        eval OBJECT_ID=$(az ad sp show --id <APP ID FROM OUTPUT ABOVE> --query objectId)
        az role assignment create --assignee-object-id $OBJECT_ID --role "Resource Policy Contributor"

        az ad sp create-for-rbac --role "Monitoring Reader" --name "http://magicaks-grafana"
        ```

> **Note:** You may get "Found an existing application instance of "GUID". We will patch it". This means that a service principal with the same already exists in the tenant. Delete the existing service principal or change the name of the service principal and try again.

### 5. Configure Terraform state

Terraform stores state configuration in Azure Storage.

1. If you don't have a storage account to use for Terraform state already configured, create a resource group and a storage account with a container per the instructions from the Microsoft docs: [Tutorial: Store Terraform state in Azure Storage](https://docs.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage):

    You can use the configure-terraform-storage.sh script for this, supply the location where you want your resources to be provisioned.

    ```cmd
    ./utils/scripts/configure-terraform-storage.sh westeurope
    ```

2. Note the resource group name, storage account name, container name and storage access key. You will need the storage access key in step 6.

3. Copy the Terraform remote backend configuration [backend.tfvars.tmpl](./backend.tfvars.tmpl) file and remove the `.tmpl` postfix from the filename. Update the variables for the values `resource_group_name`, `container_name`, and `storage_account_name`. This is the configuration to store Terraform state in an Azure Storage Account.

    ```bash
    resource_group_name  = "rg-terraform-state"
    container_name = "tfstate"
    storage_account_name = "tfstate1234"
    ```

    > In each of the Terraform files for preprovision, provision and postprovision, the [Terraform remote backend configuration](https://www.terraform.io/docs/language/settings/backends/azurerm.html) key is pre-configured. This will create one state file per step named `magicaks-preprovision`, `magicaks-provision` and `magicaks-postprovision`.

### 6. Set up the environment variables for Terraform

1. Create a file called .env with the values gathered in the previous steps

    ```bash
    export ARM_SUBSCRIPTION_ID=
    export ARM_TENANT_ID=
    export ARM_CLIENT_ID=
    export ARM_CLIENT_SECRET=
    # Storage access key where the Terraform state information is to be stored.
    export ARM_ACCESS_KEY=
    # Applies the Terraform remote backend configuration and 'Terraform init' commands
    export TF_CLI_ARGS_init='-backend-config=../backend.tfvars'
    ```

    | Environment variable | Description | Where to find it |
    | -- | -- | -- |
    | ARM_SUBSCRIPTION_ID | The Azure subscription ID for the subscription where you want to provision the resources | In the Azure Portal |
    | ARM_TENANT_ID | The Azure Tenant ID for the tenant where you want to provision the resources | In the Azure Portal |
    | ARM_CLIENT_ID | The **magicaks-terraform** service principal ID | Saved in "[Create service principals](#4.-create-service-principals-for-provisioning-resources)" step |
    | ARM_CLIENT_SECRET | The **magicaks-terraform** service principal password | Saved in "[Create service principals](#4.-create-service-principals-for-provisioning-resources)" step |
    | ARM_ACCESS_KEY | Terraform state storage access key | See step 5 |
    | TF_CLI_ARGS_init | Terraform remote storage configuration file location | [backend.tfvars](./backend.tfvars) |

1. Set the environment variables

   ```bash
   source .env
   ```

## Prepare to provision resources with Terraform

> **Note:** Terraform requires variables as input. You can provide these either interactively or if there is a `terraform.tfvars` file present then Terraform will detect it and use the variables there. Each of the folders ([1-preprovision](1-preprovision/terraform.tfvars.tmpl), [2-provision-aks](2-provision-aks/terraform.tfvars.tmpl), [3-postprovision](3-postprovision/terraform.tfvars.tmpl) have a `terraform.tfvars.tmpl` file. If you want to use `terraform.tfvars` support, you can rename/copy `terraform.tfvars.tmpl` to `terraform.tfvars` and fill in the values.

1. If you are not logged in already, log in with `az login` to the subscription where you want to deploy the resources.

## Provision common resources (pre-provision)

Before we provision the AKS clusters, we will provision some common resources that we can use for all clusters such as:

* [Azure Virtual Network](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview)
* [Azure Firewall](https://docs.microsoft.com/en-us/azure/firewall/overview)
* [Azure Key Vault](https://docs.microsoft.com/en-us/azure/key-vault/general/basic-concepts)
* [Azure Container Registry](https://docs.microsoft.com/en-us/azure/container-registry/)

1. Set the variables in `terraform.tfvars.tmpl` and remove the `.impl` postfix from the filename. (If you don't do this, Terraform will ask you for these variables when you execute the Terraform scripts.)

    | Variable | Description | Example |
    | -- | -- | -- |
    | location | The location where to create the resources | "westeurope" |
    | resource_group_name | The resource group name to create for the shared resources | "rg-magicaks-shared" |
    | tenant_id | The [Azure Tenant ID](https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-how-to-find-tenant) for the tenant where the resources should be created. | "GUID" |
    | resource_suffix | A unique string used to for resources that need globally unique names. Keep this short and without dashes to fulfill [Azure naming requirements](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules) | "magic123" |

1. Execute the Terraform scripts to provision the resources (from the [1-preprovision](./1-preprovision/) folder):

    ```bash
    terraform init
    terraform plan
    terraform apply
    ```

> **Note:** It's normal for this to take a long time to provision, especially the Firewall, so relax and grab a coffee.

After provisioning the resources take note of the Terraform output variables, you will be using them in upcoming steps.

## Provision an AKS cluster

1. Create a custom Grafana image (from the [./utils/grafana/](./utils/grafana/) folder).

   > **Note:** Replace acr_name with the name of the Azure Container Registry created during pre-provisioning

    ```bash
    eval ACR_NAME=<acr_name>
    az acr build -t $ACR_NAME.azurecr.io/grafana:v1 -r $ACR_NAME .
    ```

2. Create a managed identity for the cluster

    MagicAKS creates a managed identity cluster. We create the identity for this cluster in the resource group with other shared resources, so the permissions remain even if we recreate the cluster. To create an identity run the [create-cluster-managed-identity.sh](utils/scripts/create-cluster-managed-identity.sh) script, providing the **resource_group_name** you entered in the Terraform variables:

    ```bash
    ./utils/scripts/create-cluster-managed-identity.sh rg-magicaks-shared
    ```

    > **Note:** MagicAKS is not creating a system assigned managed identity, due to current [limitations](https://docs.microsoft.com/en-us/azure/aks/use-managed-identity#create-an-aks-cluster-with-managed-identities) of self-managed VNet and static IP address outside the MC_ resource group.

    You will need to provide the **managed identity resource ID** (provided as output of the script) as a variable to Terraform when creating the cluster.

3. Fill out the Terraform parameters in [2-provision-aks/terraform.tfvars.tmpl](2-provision-aks/terraform.tfvars.tmpl) and save it without the `.tmpl` filename postfix.

    | Variable | Description | Where do I find this | Example |
    | -- | -- | -- | -- |
    | cluster_name | A unique string used to for resources that need globally unique names. Keep this short and without dashes to fulfill [Azure naming requirements](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules) | You choose | "magic123" |
    | location | The location where to create the resources | You choose | "westeurope" |
    | subscription_id | Your Azure Subscription ID | | |
    | tenant_id | The Azure Tenant ID for the tenant where the resources should be created. | [How to find](https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-how-to-find-tenant) | | |
    | aad_tenant_id | The Azure Active Directory Tenant ID | | |
    | key_vault_id | Resource ID for the key vault | From the previous Terraform step | |
    | cluster_support_db_admin_password | Password for the cluster support Postgres DB | Provide a strong password | |
    | aci_subnet_id | Azure Container Instance subnet ID | From the previous Terraform step | |
    | k8s_subnet_id | Kubernetes subnet ID | From the previous Terraform step | |
    | admin_group_object_ids | Admin group object ID | From the "[Create AKS cluster admins AAD group](#2.-create-an-aks-cluster-admins-aad-group)" step | |
    | user_assigned_identity_resource_id | Managed Identity Resource ID | From `create-cluster-managed-identity.sh` | |
    | grafana_admin_password | Grafana Admin Password | Provide a strong password | |
    | aci_network_profile_id | Azure Container Instance Profile ID | From the previous Terraform step | |
    | acr_name | Azure Container Registry where the grafana image can be found | From the previous Terraform step | |
    | monitoring_reader_sp_client_id | Grafana service principal ID | From the "[Create service principals](#4.-create-service-principals-for-provisioning-resources)" step | |
    | monitoring_reader_sp_client_secret | Grafana service principal password | From the "[Create service principals](#4.-create-service-principals-for-provisioning-resources)" step | |

4. Provision the cluster:

    ```bash
    terraform init
    terraform plan
    terraform apply
    ```

    > **Note:** This will also take a while to provision, so time for another coffee.

    Along with provisioning the cluster, the Terraform script will also download the credentials we need for the following steps for interacting with the cluster. It will also create a Grafana instance and connects it to the Log Analytics workspace as well as Postgres, which acts as the storage backend for Grafana.

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

* Terraform authentication error.

    ```bash
    Error: Failed to get existing workspaces: containers.Client#ListBlobs: Failure responding to request: StatusCode=403 -- Original Error: autorest/azure: Service returned an error. Status=403 Code="AuthenticationFailed" Message="Server failed to authenticate the request. Make sure the value of Authorization header is formed correctly including the signature.\nRequestId:e4c5cf49-801e-0068-4539-0cb9e7000000\nTime:2021-02-26T12:18:40.6499706Z"
    ```

    This is due to WSL clock skew. Fix it by running this command:

    ```bash
    sudo hwclock -s
    ```

* Line endings not correct for bash scripts, e.g. by Git clone/pull from Windows (with CRLF as the default).

    ```bash
    Error: Error running command '/mnt/c//2-provision-aks/getcreds.sh ': exit status 127. Output: /bin/sh: 1: /mnt/c//2-provision-aks/getcreds.sh: not found
    ```

    *We know it's the 21 century, but check the line endings*. Line endings must be in LF format instead of CRLF. You may run into this issue, if you clone the repository in Windows for example. Check the line endings of all the bash script files (`*.sh`) in the repository and set them to LF format to correct the problem.

    You can use the `dos2unix` utility to do the conversion. Install it via `apt-get`.

* In step 3 postprovision you might run into this error.

    ```bash
    Error: failed to create resource: namespaces "app1" not found
    ```

    This is due to a timing issue where `app1` is not yet created - wait a few minutes, rerun the apply and it should work. We are investigating the issue (#66).
