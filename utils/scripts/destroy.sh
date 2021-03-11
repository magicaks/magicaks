#!/bin/bash
# This scripts runs the destroy command for all the provisioned resources

source ../../.env

echo "Terraform destroying post-provision"
cd ../../3-postprovision/
terraform destroy -auto-approve

echo "Terraform destroying aks"
cd ../2-provision-aks/
terraform destroy -auto-approve

cd ../1-preprovision/
SHARED_RESOURCE_GROUP=$(terraform show -json | jq -r '.values.root_module.resources[] | select(.address == "azurerm_resource_group.shared_rg") | .values.name')
echo "Terraform destroying pre provision resources"
terraform destroy -auto-approve

echo "Deleting the MagicAKS service identity"
az identity delete --name magicaksmsi --resource-group $SHARED_RESOURCE_GROUP

echo "Deleting the MagicAKS service principal"
az ad sp delete --id $ARM_CLIENT_ID

echo "If you have used a provisioning service principal from a different tenant than the one hosting your subscription you will need to manually log in with:"
echo "az login --tenant <tenant_id> --allow-no-subscriptions"
echo "and then execute following to delete the group:"
echo "az ad group delete --group magicaksadmins"
