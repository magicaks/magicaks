# Magic AKS - Opinionated cluster config for microservices on Azure

## Introduction

Azure Kubernetes service makes it very easy to spin up a functional cluster. However there is more to running Kubernetes than just the nodes. Making a cluster workable requires good amount of grunt work.

This is an attempt to make things easier to adopt AKS for modern microservice based cloud native applications.

Microservice apps need supporting components to do their job. There are many components out there which can get the job done and chosing among them can be a trip down a rabbit hole. In this repo we have made choices which are according to us the most suitable and make full use of Azure as a cloud computing platform. The driving force behind this automation is to use Azure to its fullest and relieve the user to focus instead on writing business logic.

## Inspiration and history

This project derives the concept for functional AKS cluster from [Project Bedrock](https://github.com/microsoft/bedrock). Bedrock provides patterns, implementation, and automation for operating production Kubernetes clusters based on a GitOps workflow, building on the best practices discovered while working with operationalizing Kubernetes clusters. MagicAKS extends the concepts in Bedrock to initialize a cluster with opinionated choice of technologies which are tigthly integrated. This level on integration provides for a smoother development experience with tooling, monitoring and other infrastructure services. While Bedrock provides guidance for Azure DevOps based release workflows, MagicAKS is focused on Github repositories and actions. Both projects use Fabrikate for specifying cluster software configs but Fabrikate is a replaceable component and one can use for example Kustomize or any other mainfest generation technology.

Bedrock is designed to be general and has some concepts like rings are not reflected in this project at all. MagicAKS has a specific use case - making microservices based development on Azure easy and it excels at that.

## Architecture and components

This automation is by design not general purpose. It makes things easier by removing thinking of choices and instead get a working production grade kubernetes cluster so that developers can write business logic instead of spending time to figure out infrastructure concerns.

As mentioned above the other goal of this automation is to use as much as possible plaform offerings on Azure and integrate them tightly at a suitable abstraction. This should make it easier for developers to assume presence of services which they need under a standard access model.

These components are currently are or will eventually be integrated

* Azure service bus as async message bus (Done)
* Azure SQL as database provider.
* Azure container insights / Azure monitor for logging and metrics store (Done)
* Azure Active Directory for autentication and authorization. Integrated with K8s RBAC (Done)
* Azure KeyVault for secret storage (Done)
* Azure Policy for policy enforcement, compliance and governance (Done)
* Azure App Gateway as ingress controller.

When needed opensource tooling is integrated to provide components. For example kured.

This automation is divided in 3 stages. We use terraform to bootstrap infrastructure and set up a gitOps connection in the cluster which then picks up kubernetes manifests for the declared state of the cluster.

These manifests are in turn divided into two parts.

1. Manifests which require admin permissions on the cluster to install.
2. Manifests for workloads which run within a namespace and with limited credentials.

This is done to prevent unauthorized installations in the cluster. Hence, there are two flux pods running, one for each type of manifest. Admin manifests should come from a repository which is controlled by cluster admins and has tighter process control methods so that every input is checked before being applied to the cluster.

Instead of writing k8s manifests directly we use Fabrikate HLD to write the config which is then translated to K8s manifests using a pipeline which in turn runs ``fab generate`` and pushes the config to the k8s manifest repo. However you do not need to use Fabrikate. The automation expects names of kubernetes manifest repo and you can use any manifest generation tool of your choice, for example kustomize.

If you use a different manifest generation system make sure you to run ``rbac-generator.py`` and ``azmonconfig-generator.py`` as part of building the manifests.

## How to use this repo

### Software requirements

This repo has been tested to work with OSX, Linux and Windows (on [WSL](https://docs.microsoft.com/en-us/windows/wsl/)). The provided [Docker development environment image](./utils/docker-dev-env/README.md) can be useful, especially for Windows users.

You need to install:

* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) min version 1.18.1
* [fluxctl](https://docs.fluxcd.io/en/1.18.0/references/fluxctl.html)
* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) and logged in with a user who has enough permissions.
* [Terraform](https://www.terraform.io/downloads.html) While different terraform versions might work, the automation has been tested with v0.14.2
* curl
* [jq](https://stedolan.github.io/jq/)

### One time setup

These steps need to be done once each time a new project is started.

* Run ``az ad group create --display-name magicaksadmins --mail-nickname magicaksadmins``. Note the object id of the group as it is used as an input variable when creating the AKS cluster.

> **NOTE:** This command can only be run by **owner** of the active directory. This is not needed per project but once for each active directory used. If you are not the owner of the AAD but would still like to try MagicAKS, [create a personal AAD](https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-access-create-new-tenant). To run the command above you need to be logged into the tenant where the RBAC would be managed from. You can use ``az login --tenant <<tenand_id>>`` to login into a specific tenant.

> **NOTE:** If the new Azure Active Directory tenant does not have a subscription, then run instead ``az login --tenant <<tenand_id>> --allow-no-subscriptions``.

* Fork [repo](https://github.com/sachinkundu/fabrikate-defs). This will be your Fabrikate High Level Definition(HLD) repo. In the repo there is a README which explains on how to set up RBAC for your cluster. Finish the steps there before continuing further.
* Fork [repo](https://github.com/magicaks/k8sworkloads). This is user workloads manifest repo where non-privileged workloads should be listed. This is tracked by flux gitOps non admin controller.

### Provisioning resources

* Create a service principal which terraform can use for deploying resources. You can create a service principal by using

    ``az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/SUBSCRIPTION_ID -n "terraform-magicaks"``

    where terraform-magicaks would be the name of the service principal. You can chose another name if you like.

* Create a service principal which grafana can use for talking to log analytics backend. This service principal is restricted to be a **Monitoring Reader**. You can create a service principal using

    ``az ad sp create-for-rbac -n "magicaks-grafana" --role "Monitoring Reader"``

* Terraform stores state config in Azure Storage. You need to provide access key to this storage in the .env file created below. If you don't have a storage account you can create one using

    ``az storage account create --name <<name>> --resource-group <<group_name>>``

> **NOTE** Before running terraform always verify that Azure Storage Backend has been set up correctly and that the chosen container exists. Otherwise terraform run will fail.

* Make a file called .env and put these values in it and fill those with suitable values.

```bash
# Service principal by terraform.
export TF_VAR_client_secret=
export TF_VAR_client_id=
# Github personal access token
export TF_VAR_pat=
export TF_VAR_tenant_id=
# Grafana password
export TF_VAR_grafana_admin_password=

export ARM_SUBSCRIPTION_ID=
export ARM_TENANT_ID=$TF_VAR_tenant_id
export ARM_CLIENT_SECRET=$TF_VAR_client_secret
export ARM_CLIENT_ID=$TF_VAR_client_id

# Storage access key where the terraform state information is to be stored.
export ARM_ACCESS_KEY=
```

* Run ``source .env``

* Make sure you are logged into azure command line ``az`` and the right subscription is selected.

> **NOTE** Terraform requires variables as input. These can be provided either interactively or if there is a terraform.tfvars file present then terraform will detect it and use variable names from there. Each of the folders below have a terraform.tfvars.tmpl file. If you want to use terraform.tfvars support you can copy terraform.tfvars.tmpl to terraform.tfvars and fill the values.

> **NOTE** Name of the cluster acts as a prefix for many other resources created and hence to fulfill Azure naming requirements it is essential to select a shorter name.

* There is a folder ``1-preprovision`` which contains terraform scripts to create those resources which need to be created just onetime. For example vnet, subnets azure firewall and its rules and keyvault etc. After you have verified all variable names you can exectute terraform.

* To provision the cluster you need to step into ``2-provision-aks`` folder and run terraform as usual. Before executing this however, step into [./utils/grafana/](./utils/grafana/) and run the following commands to create a custom Grafana image.

```bash
export registry=registry_name_here
az acr build -t $registry.azurecr.io/grafana:v1 -r $registry .
```

Now run terraform and wait for cluster to bootstrap.

This step will also download the credentials for interacting with the cluster which is required for the following steps. Grafana is also created at this step and connected to the log analytics workspace. Postgres is also created which acts as the storage backend for Grafana.

* After the cluster is provisioned we provision all support resources by stepping into ``3-postprovision`` and running terraform as usual. This will set up flux for admin and non admin workloads and eventually the desired state of the configs will be applied to your cluster. This is also where service bus etc will be created.

## What all is installed right now?

1. AKS cluster.

> 1. VMSS node pool with 1 - 5 nodes.
> 2. Container insights in enabled.
> 3. ~~Pod security policies is enabled.~~ (AKS has deprecated PSP in favor of Azure Policy)
> 4. RBAC is enabled.
> 5. Calico as the network plugin
> 6. Kubernetes version = 1.19.7

2. Flux gitOps operator
3. Azure KeyVault
4. akv2k8s operator installed to provide seamsless access to keyvault secrets.
5. Service bus integrated and primary connection string stored in KeyVault and exposed in cluster as K8s secret.
6. Integration with Azure Active Directory for K8s RBAC.
7. Pod security policies are enabled and a restricted policy added.
8. Azure Policy is enabled on the cluster. No policies are assigned right now.
9. Azure Firewall is integrated with network and application rules as recommended by AKS.
10. Grafana connected to log analytics workspace of the cluster is running in Azure container instance backed by managed Postgresql Azure database.

## What is upcoming

Check open issues at [Github Issues](https://github.com/sachinkundu/akstf/issues)
