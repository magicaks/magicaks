Magic AKS - Opinionated cluster config for microservices on Azure
===================================================================

## Introduction

Azure Kubernetes service makes it very easy to spin up a functional cluster. However there is more to running Kubernetes than just the nodes. Making a cluster workable requires good amount of grunt work.

This is an attempt to make things easier to adopt AKS for modern microservice based cloud native applications.

Microservice apps need supporting components to do their job. There are many components out there which can get the job done and chosing among them can be a trip down a rabbit hole. In this repo we have made choices which are according to us the most suitable and make full use of Azure as a cloud computing platform. The driving force behind this automation is to use Azure to its fullest and relieve the user to focus instead on writing business logic.

## Architecture and components.

This automation is by design not general purpose. It is supposed to make things easier by removing thinking of choices and instead get a working production grade kubernetes cluster so that developers can write business logic instead of spending time to figure out infrastructure concerns.

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

Instead of writing k8s manifests directly we use Fabrikate HLD to write the config which is then translated to K8s manifests using a pipeline which in turn runs ``fab generate`` and pushes the config to the k8s manifest repo. However you do not need to use Fabrikate. The automatiion expects names of kubernetes manifest repo and you can use any manifest generation tool of your choice, for example kustomize.

If you use a different manifest generation system make sure you to run ``rbac-generator.py`` and ``azmonconfig-generator.py`` as part of building the manifests.

## How to use this repo

### Software requirements

This repo has been tested to work with OSX, Linux and Windows(on wsl). You need to install
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [fluxctl](https://docs.fluxcd.io/en/1.18.0/references/fluxctl.html)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) and logged in with a user who has enough permissions.
- [Terraform](https://www.terraform.io/downloads.html)
- curl

### One time setup

These steps need to be done once each time a new project is started.

* Generate AAD server and client applications by running the file ``utils/create-rbac-apps.sh``. Please notes that this script can only be run by **owner** or the active directory. You can use the same credentials for all projects so this is not needed per project but once for each Active Directory used.
* Extract the folder ``fabirkate-defs`` and push these files into a new repo. This is the admin HLD repo. Make sure to read README.md in that folder to do the configs required to set up AAD and RBAC setup.
* Make a new repo called k8smanifests. this will be your admin manifest repo as tracked by flux gitOps admin controller.
* Setup github actions pipeline using ``.github/workflows/generate-manifests-gh.yaml`` as the sample and use the above repo as the repo to write the generated k8s manifests.
* Make another repo called k8sworkloads, a sample is [here](https://github.com/sachinkundu/k8sworkloads). This is where non privileged workloads should be listed. This is tracked by flux gitOps non admin controller. 

### Provisioning resources
* Make a file called .env and put these values in it and fill those with suitable values.
```
# Service principal used for creating cluster.
export TF_VAR_client_secret=
export TF_VAR_client_id=
# Github personal access token
export TF_VAR_pat=
export TF_VAR_tenant_id=
# Azure AAD server application secret. 
export TF_VAR_aad_server_app_secret=
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
* All terraform state information is stored in Azure storage. Credentials of this storage is provided using the exported variable ``ARM_ACCESS_KEY`` above. Please make sure you check ``main.tf`` in each step below to confirm the settings for state storage. Default values should also work fine.
* There is a folder ``1-preprovision`` which contains terraform scripts to create those resources which need to be created just onetime. For example vnet, subnets azure firewall and its rules and keyvault etc. Check ``variables.tf`` and execute ``tf apply``. Please note if you create multiple clusters in the same vnet you need to then add the new subnet here and provide the route tables etc. Only one AKS cluster is allowed in one subnet.
* To provision the cluster you need to step into ``2-provision-aks`` folder and run terraform as usual. This step will also download the credentials for interacting with the cluster which is required for the following steps. Grafana is also created at this step and connected to the log analytics workspace. Postgres is also created which acts as the storage backend for grafana.
* After the cluster is provisioned we provision all support resources by stepping into ``3-postprovision`` and running terraform as usual. This will set up flux for admin and non admin workloads and eventually the desired state of the configs will be applied to your cluster. This is also where service bus etc will be created.

## What all is installed right now?

1. AKS cluster.
> 1. VMSS node pool with 1 - 5 nodes.
> 2. Container insights in enabled.
> 3. Pod security policies is enabled.
> 4. RBAC is enabled.
> 5. Kubenet as the network plugin
> 6. Kubernetes version = 1.17

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
