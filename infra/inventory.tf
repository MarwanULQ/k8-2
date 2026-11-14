# Writes the Ansible inventory from live Terraform state.
resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory.ini"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/inventory.ini.tftpl", {
    bastion_ip = aws_instance.bastion.public_ip
    key_name   = var.key_name

    master = {
      ip   = aws_instance.nodes["master"].private_ip
      name = "k8-${local.nodes["master"].name}"
    }

    workers = {
      for key, inst in aws_instance.nodes : key => {
        ip   = inst.private_ip
        name = "k8-${local.nodes[key].name}"
      } if key != "master"
    }
  })
}
