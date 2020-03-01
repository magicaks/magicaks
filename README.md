Magic AKS - Opinionated cluster config for microservices on Azure
===================================================================

## Introduction

Azure Kubernetes service makes it very easy to spin up a functional cluster. However there is more to running Kubernetes than just the nodes. Making a cluster workable requires good amount of grunt work.

This is an attempt to make things easier to adopt AKS for modern microservice based cloud native applications.

Microservice apps need supporting components to do their job. There are many components out there which can get the job done and chosing among them can be a trip down a rabbit hole. In this repo we have made choices which are according to us the most suitable and make full use of Azure as a cloud computing platform. The driving force behind this automation is to use Azure to its fullest and relieve the user to focus instead on writing business logic.

## Architecture and components.

This automation is by design not general purpose. It is supposed to make things easier by removing thinking of choices and instead get a working production grade kubernetes cluster so that developers can write business logic instead of spending time to figure out infrastructure concerns.

As mentioned above the other goal of this automation is to use as much as possible plaform offerings on Azure and integrate them tightly at a suitable abstraction. This should make it easier for developers to assume presence of services which they need under a standard access model.

These components are currently integrated

* Azure service bus as async message bus.
* Azure SQL as database provider.
* Azure container insights / Azure monitor for logging and metrics store.
* Azure Active Directory for autentication and authorization. Integrated with K8s RBAC.
* Azure KeyVault for secret storage.
* Azure Policy for policy enforcement, compliance and governance.
* Azure App Gateway as ingress controller.

When needed opensource tooling is integrated to provide components. For example kured.

This automation is divided in two separate parts

1. Bootstrapping Azure infrastructure like resource group, subnets, keyvault and the cluster itself using Terraform.
2. Installing workloads inside the cluster when it ready using gitOps connection to a kubernetes manifest repo. This is configured when the cluster in step 1 is bootstrapped.

Instead of writing k8s manifests directly we use Fabrikate HLD to write the config which is then translated to K8s manifests using a pipeline which in turn runs ``fab generate`` and pushes the config to the k8s manifest repo.

## How to use this repo

### One time setup

These steps need to be done once each time a new project is started.

* Generate AAD server and client applications by running the file ``utils/create-rbac-apps.sh``. Please notes that this script can only be run by owner or the active directory. You can use the same credentials for all projects so this is not needed per project but once for each Active Directory used.
* Extract the folder ``fabirkate-defs`` and push these files into a new repo called fabrikate-defs. Make sure to read README.md in that folder to do the configs required to set up AAD and RBAC setup.
* Make a new repo called k8smanifests. This will be your k8s manifests tracked by flux gitOps controller.
* Setup github actions pipeline using ``.github/workflows/generate-manifests-gh.yaml`` as the sample and use the above repo as the repo to write the generated k8s manifests.
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
export ARM_SUBSCRIPTION_ID=
export ARM_TENANT_ID=$TF_VAR_tenant_id
export ARM_CLIENT_SECRET=$TF_VAR_client_secret
export ARM_CLIENT_ID=$TF_VAR_client_id
# Storage access key where the terraform state information is to be stored.
export ARM_ACCESS_KEY=
```
* Run ``source .env``
* There is a folder ``onetime`` which contains terraform scripts to create those resources which need to be created just onetime. For example vnet, subnets and azure firewall and its rules. Check ``variables.tf`` and execute ``tf apply``. Please note if you create multiple clusters in the same vnet you need to then add the new subnet here and provide the route tables etc. Only one AKS cluster is allowed in one subnet.
* Root module in this directory creates per cluster resources such as service bus, keyvault and the cluster itself. Again check ``variables.tf`` and execute ``terraform apply``. All resoureces will eventually come up and if the gitOps connection is successful so will all the workloads mentioned in your manifest repo.

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

## What is upcoming
Check open issues at [Github Issues](https://github.com/sachinkundu/akstf/issues)
