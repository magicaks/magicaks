variable "client_id" {}
variable "client_secret" {}

variable "agent_count" {
    default = 1
}

variable "dns_prefix" {
    default = "sakunduk8s"
}

variable cluster_name {
    default = "k8s"
}

variable k8s_rg_name {
    default = "k8s"
}

variable location {
    default = "West Europe"
}