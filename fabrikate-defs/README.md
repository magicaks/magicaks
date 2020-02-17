# flux-manifests
manifests for flux

[![Build Status](https://dev.azure.com/sakundu/k8s/_apis/build/status/Flux%20to%20K8s%20Manifests?branchName=master)](https://dev.azure.com/sakundu/k8s/_build/latest?definitionId=16&branchName=master)

This folder contains fabrikate specific configs which are used to generate kubernetes manifests. 

There is a pipeline.yaml which corresponds to Azure DevOps which runs fabrikate to generate manifests which are then applied to kubenetes manifests git repo.

Flux(gitOps) is setup to track kubernetes manifest repo and any changes made to fabrikate definitions will eventually reflect in the cluster.

These definitions work in tandem with Magic AKS bootstrap to install a specific set of software components which make using AKS integrated with other open source tooling as well as suitable Azure PaaS. 