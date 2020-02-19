# flux-manifests
manifests for flux

![Fabrikate Defs -> K8s Manifests](https://github.com/sachinkundu/akstf/workflows/Fabrikate%20Defs%20-%3E%20K8s%20Manifests/badge.svg?branch=master)

This folder contains fabrikate specific configs which are used to generate kubernetes manifests. 

There is a githubs actions file in ../.github/workflows/generate-manifests-gh.yaml which runs fabrikate to generate manifests which are then applied to kubenetes manifests git repo.

Flux(gitOps) is setup to track kubernetes manifest repo and any changes made to fabrikate definitions will eventually reflect in the cluster.

These definitions work in tandem with Magic AKS bootstrap to install a specific set of software components which make using AKS integrated with other open source tooling as well as suitable Azure PaaS. 
