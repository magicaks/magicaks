provider "tls" {
  version = "~> 2.0"
}

# sensitive_content parameter is supported from version 1.2
provider "local" {
  version = ">= 1.2"
}

# Generate the Tiller CA key
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Generate a self signed CA certificate
resource "tls_self_signed_cert" "ca" {
  key_algorithm         = "${tls_private_key.ca.algorithm}"
  private_key_pem       = "${tls_private_key.ca.private_key_pem}"
  is_ca_certificate     = true
  validity_period_hours = 87600
  early_renewal_hours   = 8760

  allowed_uses = [
    "v3_ca",
  ]

  subject {
    organization = "Tiller CA"
  }
}

# Write the CA key to file
resource "local_file" "ca_key" {
  sensitive_content  = "${tls_private_key.ca.private_key_pem}"
  filename           = "${path.module}/ca.key.pem"
}

# Write the CA cert to file
resource "local_file" "ca_cert" {
  content  = "${tls_self_signed_cert.ca.cert_pem}"
  filename = "${path.module}/ca.cert.pem"
}

# Generate the Tiller Server key
resource "tls_private_key" "tiller" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Generate a signing request for the Tiller Server certificate
resource "tls_cert_request" "tiller" {
  key_algorithm   = "${tls_private_key.tiller.algorithm}"
  private_key_pem = "${tls_private_key.tiller.private_key_pem}"

  ip_addresses = [
    "127.0.0.1",
  ]

  subject {
    organization = "Tiller Server"
  }
}

# Write the Tiller Server key to file
resource "local_file" "tiller_key" {
  sensitive_content  = "${tls_private_key.tiller.private_key_pem}"
  filename           = "${path.module}/tiller.key.pem"
}

# Write the Tiller Server cert to file
resource "local_file" "tiller_cert" {
  content  = "${tls_locally_signed_cert.tiller.cert_pem}"
  filename = "${path.module}/tiller.cert.pem"
}

# Sign the Tiller Server certificate signing request
resource "tls_locally_signed_cert" "tiller" {
  cert_request_pem      = "${tls_cert_request.tiller.cert_request_pem}"
  ca_key_algorithm      = "${tls_private_key.ca.algorithm}"
  ca_private_key_pem    = "${tls_private_key.ca.private_key_pem}"
  ca_cert_pem           = "${tls_self_signed_cert.ca.cert_pem}"
  validity_period_hours = 87600
  allowed_uses          = []
}

# Generate a key for the Helm Client
resource "tls_private_key" "helm" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Generate a signing request for the Helm Client certificate
resource "tls_cert_request" "helm" {
  key_algorithm   = "${tls_private_key.helm.algorithm}"
  private_key_pem = "${tls_private_key.helm.private_key_pem}"

  subject {
    organization = "Helm Client"
  }
}

# Sign the Helm Client certificate signing request
resource "tls_locally_signed_cert" "helm" {
  cert_request_pem      = "${tls_cert_request.helm.cert_request_pem}"
  ca_key_algorithm      = "${tls_private_key.ca.algorithm}"
  ca_private_key_pem    = "${tls_private_key.ca.private_key_pem}"
  ca_cert_pem           = "${tls_self_signed_cert.ca.cert_pem}"
  validity_period_hours = 87600
  allowed_uses          = []
}

# Write the Helm Client key to file
resource "local_file" "helm_key" {
  sensitive_content  = "${tls_private_key.helm.private_key_pem}"
  filename           = "${path.module}/helm.key.pem"
}

# Write the Helm Client cert to file
resource "local_file" "helm_cert" {
  content  = "${tls_locally_signed_cert.helm.cert_pem}"
  filename = "${path.module}/helm.cert.pem"
}
