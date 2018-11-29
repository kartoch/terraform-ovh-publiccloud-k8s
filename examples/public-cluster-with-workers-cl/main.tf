provider "openstack" {
  version   = "~> 1.5.0"
  region    = "${var.region}"
}

data "http" "myip" {
  count = "${var.remote_ip_prefix == "" ? 1 : 0}"
  url = "https://api.ipify.org/"
}

module "k8s_secgroups" {
  source = "../../modules/k8s-secgroups"
  name   = "${var.name}"
  etcd   = true
  cfssl  = true
}

resource "openstack_networking_secgroup_rule_v2" "in_traffic_ssh_master" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  remote_ip_prefix  = "${var.remote_ip_prefix == "" ? join("", formatlist("%s/32", data.http.myip.*.body)) : var.remote_ip_prefix}"
  port_range_min    = 22
  port_range_max    = 22
  security_group_id = "${module.k8s_secgroups.master_group_id}"
}

resource "openstack_networking_secgroup_rule_v2" "in_traffic_ssh_worker" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  remote_ip_prefix  = "${var.remote_ip_prefix == "" ? join("", formatlist("%s/32", data.http.myip.*.body)) : var.remote_ip_prefix}"
  port_range_min    = 22
  port_range_max    = 22
  security_group_id = "${module.k8s_secgroups.worker_group_id}"
}

resource "openstack_networking_secgroup_rule_v2" "k8s-api" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  remote_ip_prefix  = "${var.remote_ip_prefix == "" ? join("", formatlist("%s/32", data.http.myip.*.body)) : var.remote_ip_prefix}"
  port_range_min    = 6443
  port_range_max    = 6443
  security_group_id = "${module.k8s_secgroups.master_group_id}"
}

module "k8s" {
  source                 = "../.."
  region                 = "${var.region}"
  name                   = "${var.name}_master"
  count                  = "${var.master_count}"
  master_mode            = true
  cfssl                  = true
  etcd                   = true
  post_install_modules   = true
  image_name             = "CoreOS Stable"
  flavor_name            = "${var.masters_flavor_name}"
  ssh_user               = "core"
  key_pair               = "${var.key_pair}"
  ssh_authorized_keys    = ["${file(var.public_sshkey == "" ? "/dev/null" : var.public_sshkey)}"]
  security_group_ids     = ["${module.k8s_secgroups.master_group_id}"]
  associate_public_ipv4  = true
}

module "k8s_workers" {
  source                 = "../.."
  region                 = "${var.region}"
  name                   = "${var.name}_worker"
  count                  = "${var.worker_count}"
  worker_mode            = true
  cfssl_endpoint         = "${module.k8s.cfssl_endpoint}"
  etcd_endpoints         = "${module.k8s.etcd_endpoints}"
  post_install_modules   = true
  image_name             = "CoreOS Stable"
  flavor_name            = "${var.workers_flavor_name}"
  ssh_user               = "core"
  key_pair               = "${var.key_pair}"
  ssh_authorized_keys    = ["${file(var.public_sshkey == "" ? "/dev/null" : var.public_sshkey)}"]
  security_group_ids     = ["${module.k8s_secgroups.worker_group_id}"]
  associate_public_ipv4  = true
  api_endpoint           = "${module.k8s.api_endpoint}"
}
