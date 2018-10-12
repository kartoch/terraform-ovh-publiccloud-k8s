cat <<EOF
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
