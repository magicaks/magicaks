# flux-manifests
manifests for flux

![Fabrikate Defs -> K8s Manifests](https://github.com/sachinkundu/akstf/workflows/Fabrikate%20Defs%20-%3E%20K8s%20Manifests/badge.svg?branch=master)

This folder contains fabrikate specific configs which are used to generate kubernetes manifests. 

There is a github actions [file](https://github.com/sachinkundu/akstf/blob/master/.github/workflows/generate-manifests-gh.yaml) which runs fabrikate to generate manifests which are then applied to kubenetes manifests git repo.

Flux(gitOps) is setup to track kubernetes manifest repo and any changes made to fabrikate definitions will eventually reflect in the cluster.

These definitions work in tandem with Magic AKS bootstrap to install a specific set of software components which make using AKS integrated with other open source tooling as well as suitable Azure PaaS. 

Within ``build.sh`` which is executed from the actions pipeline mentioned above you will find

```bash
function generate_rbac_configs() {
    echo "generate rbac configs"
    python rbac-generator.py $1 $2
}

function generate_azmon_configs() {
    echo "generate azure monitor configs"
    python azmonconfig-generator.py $1 $2
}
```
This creates the necessary rbac configs which are then placed in the fabrikate generated folder and hence pushed to the k8s manifest repo during git push.