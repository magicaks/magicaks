resource "null_resource" "expose_eventgrid" {
  provisioner "local-exec" {
      command = "${path.module}/expose.sh ${var.endpoint}" 
  }
}
