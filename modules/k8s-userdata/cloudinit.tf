locals {
  networkd_route_tpl = "[Route]\nDestination=%s\nGatewayOnlink=yes\nMetric=2048\nScope=link"
}

data "template_file" "cfssl_ca_files" {
  template = <<TPL
- path: /opt/cfssl/cacert/ca.pem
  permissions: '0644'
  owner: cfssl:cfssl
  content: |
     ${indent(5, var.cacert)}
- path: /opt/cfssl/cacert/ca-key.pem
  permissions: '0600'
  owner: cfssl:cfssl
  content: |
     ${indent(5, var.cacert_key)}
TPL
}

data "template_file" "systemd_network_files" {
  template = <<TPL
- path: /etc/systemd/network/10-eth0.network
  permissions: '0644'
  content: |
    [Match]
    Name=ens3 eth0
    [Network]
    DHCP=ipv4
    ${var.host_cidr != "" ? indent(4, format(local.networkd_route_tpl, var.host_cidr)) : ""}
    [DHCP]
    RouteMetric=2048
    UseDNS=no
- path: /etc/systemd/network/20-eth1.network
  permissions: '0644'
  content: |
    [Match]
    Name=ens4 eth0
    [Network]
    DHCP=ipv4
    [DHCP]
    RouteMetric=1024
    UseDNS=no
TPL
}

data "template_file" "systemd_resolved_file" {
  template = <<TPL
- path: /etc/systemd/resolved.conf
  permissions: '0644'
  content: |
    [Resolve]
    DNS=${local.cluster_dns} ${length(split("/", var.upstream_resolver)) > 1 ? "213.186.33.99" : element(split(":", var.upstream_resolver), 0)}
    Domains=${var.domain}
TPL
}

data "template_file" "cfssl_conf" {
  template = <<TPL
- path: /etc/sysconfig/cfssl.conf
  mode: 0644
  content: |
    ${indent(4, module.cfssl.conf)}
TPL
}

data "template_file" "etcd_conf" {
  count = "${var.count}"

  template = <<TPL
- path: /etc/sysconfig/etcd.conf
  mode: 0644
  content: |
    ${indent(4, module.etcd.conf[count.index])}
TPL
}

data "template_file" "kubernetes_conf" {
  template = <<TPL
- path: /etc/sysconfig/kubernetes.conf
  mode: 0644
  content: |
    ${indent(4, data.template_file.k8s_vars.rendered)}
TPL
}

data "template_file" "modprobe" {
  template = <<TPL
- path: /etc/modules-load.d/ip_vs.conf
  mode: 0644
  content: |
    ip_vs
    ip_vs_rr
    ip_vs_wrr
    ip_vs_sh
TPL
}

data "template_file" "cfssl_files" {
  template = <<TPL
${var.cacert != "" && var.cacert_key != "" ? data.template_file.cfssl_ca_files.rendered : ""}
${data.template_file.cfssl_conf.rendered}
TPL
}

data "template_file" "clound_conf_file" {
  template = <<TPL
- path: /etc/kubernetes/cloud.conf
  permissions: '0600'
  content: |
    [Global]
    username=${var.os_username}
    password=${var.os_password}
    auth-url=${var.os_auth_url}
    tenant-id=${var.os_tenant_id}
TPL
}

# Render a multi-part cloudinit config making use of the part
# above, and other source files
data "template_file" "config" {
  count = "${var.count}"

  template = <<CLOUDCONFIG
#cloud-config
ssh_authorized_keys:
  ${length(var.ssh_authorized_keys) > 0 ? indent(2, join("\n", formatlist("- %s", var.ssh_authorized_keys))) : ""}
## This route has to be added in order to reach other subnets of the network
write_files:
  ${var.master_mode && var.cfssl && var.cfssl_endpoint == "" && count.index == 0 ? indent(2, element(data.template_file.cfssl_files.*.rendered, count.index)) : ""}
  ${var.master_mode && var.etcd ? indent(2, element(data.template_file.etcd_conf.*.rendered, count.index)) : ""}
  ${indent(2, data.template_file.modprobe.rendered)}
  ${indent(2, data.template_file.kubernetes_conf.rendered)}
  ${indent(2, data.template_file.systemd_network_files.rendered)}
  ${indent(2, data.template_file.systemd_resolved_file.rendered)}
  ${var.master_mode && var.os_mode ? indent(2, data.template_file.cloud_conf_file.rendered) : ""}  
  ${indent(2, join("\n", var.additional_write_files))}

# ensures networking config & k8s-init is taken into account at first boot
# once files are written
runcmd:
  - systemctl reload-or-restart systemd-networkd systemd-resolved
CLOUDCONFIG
}
