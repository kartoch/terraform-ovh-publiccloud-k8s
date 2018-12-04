provider "openstack" {
  version   = "~> 1.5.0"
  region    = "${var.region}"
}


data "http" "myip" {
  count = "${var.remote_ip_prefix == "" ? 1 : 0}"
  url = "https://api.ipify.org/"
}

data "template_file" "custom" {
  template = <<EOF
- path: /etc/systemd/system/customruncmd.service.d/run.conf
  mode: 0644
  content: |
    [Service]
    ExecStart=
    ExecStart=/bin/sh -c 'echo bar | tee -a /tmp/foo'
EOF
}

module "k8s" {
  source                 = "../.."
  region                 = "${var.region}"
  name                   = "${var.name}"
  count                  = "${var.count}"
  master_mode            = true
  worker_mode            = true
  cfssl                  = true
  etcd                   = true
  image_name             = "${var.image_name}"
  image_tag              = "${var.image_tag}"
  flavor_name            = "${var.flavor_name}"
  create_secgroups       = true
  key_pair               = "${var.key_pair}"
  ssh_authorized_keys    = ["${file(var.public_sshkey == "" ? "/dev/null" : var.public_sshkey)}"]
  associate_public_ipv4  = true
  associate_private_ipv4 = false

  additional_write_files = [
    "- path: /tmp/bar\n  mode: 0644\n  content: |\n    foo",
    "${data.template_file.custom.rendered}"
  ]
}

resource "openstack_networking_secgroup_rule_v2" "in_traffic_k8s_sg" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  remote_ip_prefix  = "${var.remote_ip_prefix == "" ? join("", formatlist("%s/32", data.http.myip.*.body)) : var.remote_ip_prefix}"
  port_range_min    = 6443
  port_range_max    = 6443
  security_group_id = "${module.k8s.master_group_id}"
}

resource "openstack_networking_secgroup_rule_v2" "in_traffic_ssh_master" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  remote_ip_prefix  = "${var.remote_ip_prefix == "" ? join("", formatlist("%s/32", data.http.myip.*.body)) : var.remote_ip_prefix}"
  port_range_min    = 22
  port_range_max    = 22
  security_group_id = "${module.k8s.master_group_id}"
}
