output "key_vault_id" {
    value = module.kv.key_vault_id
}

output "acr_name" {
    value = module.acr.acr_name
}

output "k8s_subnet_id" {
    value = module.networking.k8s_subnet_id
}

output "aci_subnet_id" {
    value = module.networking.aci_subnet_id
}

output "aci_network_profile_id" {
    value = module.networking.aci_network_profile_id
}
