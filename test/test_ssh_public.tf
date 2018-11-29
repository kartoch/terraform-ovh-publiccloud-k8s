locals {
  test_ssh_prefix = "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${local.sshuser}@${module.k8s.public_ipv4_addrs[0]} --"
}

resource "null_resource" "test" {
  triggers {
    trigger = "${module.k8s.ids[0]}"
  }

  connection {
    host                = "${module.k8s.public_ipv4_addrs[0]}"
    user                = "${local.sshuser}"
  }

  provisioner "file" {
    content = "${data.template_file.test_script.rendered}"
    destination = "/tmp/test.sh"
  }
}
