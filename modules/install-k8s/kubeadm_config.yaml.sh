#!/bin/bash
set +x

CONTROL_PLANE_ENDPOINT=$1

cat <<EOF
apiVersion: kubeadm.k8s.io/v1alpha3
kind: ClusterConfiguration
kubernetesVersion: ${KUBERNETES_VERSION:-stable}
certificatesDir: "/etc/kubernetes/pki"
apiServerCertSANs:
$(echo "${API_SERVER_CERT_SANS:-127.0.0.1}" | cut -d, -f1- --output-delimiter=$'\n' | sed 's/\(.*\)/- \1/g')
controlPlaneEndpoint: "$CONTROL_PLANE_ENDPOINT"
etcd:
  external:
    endpoints:
$(echo "${ETCD_ENDPOINTS:-https://127.0.0.1:2379}" | cut -d, -f1- --output-delimiter=$'\n' | sed 's/\(.*\)/    - \1/g')
    caFile: ${ETCD_CA_FILE}
    certFile: ${ETCD_CERT_FILE}
    keyFile: ${ETCD_KEY_FILE}
kubeProxy:
  config:
    mode: ${KUBEPROXY_CONFIG_MODE:-iptables}
networking:
  dnsDomain: ${CLUSTER_DOMAIN:-cluster.local}
  serviceSubnet: ${NETWORKING_SERVICE_SUBNET:-10.3.0.0/16}
  podSubnet: ${NETWORKING_POD_SUBNET:-10.2.0.0/16}
nodeName: $(hostname)
authorizationModes:
$(echo "${AUTHORIZATION_MODES:-Node,RBAC}" | cut -d, -f1- --output-delimiter=$'\n' | sed 's/\(.*\)/- \1/g')
selfHosted: false
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: coredns
  namespace: kube-system
  resourceVersion: "214"
  selfLink: /api/v1/namespaces/kube-system/configmaps/coredns
data:
  Corefile: |
    .:53 {
        errors
        health
        kubernetes ${CLUSTER_DOMAIN} in-addr.arpa ip6.arpa {
           pods insecure
           upstream
           fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        proxy . ${UPSTREAM_RESOLVER}
        cache 30
        loop
        reload
        loadbalance
    }
EOF
