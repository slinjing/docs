# <center> 二进制部署 Kubernetes v1.28 高可用集群

## 环境准备

|       IP       |     角色     |                             组件                             |
| :------------: | :----------: | :----------------------------------------------------------: |
| 192.168.33.163 | k8s-master01 | kube-apiserver、kubectl、kube-controller-manager、kube-scheduler、etcd |
| 192.168.33.167 | k8s-master02 | kube-apiserver、kubectl、kube-controller-manager、kube-scheduler、etcd |
| 192.168.33.166 | k8s-master03 | kube-apiserver、kubectl、kube-controller-manager、kube-scheduler、etcd |
| 192.168.33.168 |  k8s-node01  |               kubelet、kube-proxy、containerd                |
| 192.168.33.169 |   k8s-ha01   |                     haproxy、keepalived                      |
| 192.168.33.170 |   k8s-ha02   |                     haproxy、keepalived                      |

