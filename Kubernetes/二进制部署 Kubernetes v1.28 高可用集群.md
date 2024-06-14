# <center> 二进制部署 Kubernetes v1.28 高可用集群

## 基础环境

|       IP        |     角色     |                             组件                             |
| :-------------: | :----------: | :----------------------------------------------------------: |
| 192.168.183.163 | k8s-master01 | kube-apiserver、kubectl、kube-controller-manager、kube-scheduler、etcd |
| 192.168.183.167 | k8s-master02 | kube-apiserver、kubectl、kube-controller-manager、kube-scheduler、etcd |
| 192.168.183.166 | k8s-master03 | kube-apiserver、kubectl、kube-controller-manager、kube-scheduler、etcd |
| 192.168.183.168 |  k8s-node01  |               kubelet、kube-proxy、containerd                |
| 192.168.183.169 |   k8s-ha01   |                     haproxy、keepalived                      |
| 192.168.183.170 |   k8s-ha02   |                     haproxy、keepalived                      |

以上为演示环境基础信息，接下来集群所有节点做初始化配置，第一步配置主机名与IP地址解析

```shell
$ cat >> /etc/hosts << EOF
192.168.183.163 k8s-master01
192.168.183.167 k8s-master02
192.168.183.166 k8s-master03
192.168.183.168 k8s-node01
192.168.183.169 k8s-ha01
192.168.183.170 k8s-ha02
EOF
```

配置时间同步
```shell
$ timedatectl set-timezone Asia/Shanghai
$ ntpdate ntp1.aliyun.com 
$ cat > /var/spool/cron/root << EOF
* */1 * * * ntpdate -u ntp1.aliyun.com > /dev/null 2>&1
EOF
$ hwclock -w
```

关闭防火墙
```shell
$ systemctl stop firewalld
$ systemctl disable firewalld
```

关闭SELINUX
```shell
$ setenforce 0
$ sed -ri 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
```

关闭SWAP分区
```shell
$ swapoff -a  
$ sed -ri 's/.*swap.*/#&/' /etc/fstab
```

开启主机内核路由转发及网桥过滤，配置内核加载`br_netfilter`和`iptables`放行`ipv6`和`ipv4`的流量，确保集群内的容器能够正常通信。
```shell
$ cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
vm.swappiness = 0
EOF

# 加载br_netfilter模块
$ modprobe br_netfilter

# 验证
$ lsmod | grep br_netfilter
br_netfilter           22256  0
bridge                151336  1 br_netfilter
```


安装ipvs管理工具并加载模块，仅k8s节点安装，忽略ha节点
```shell
$ yum -y install ipvsadm ipset sysstat conntrack libseccomp

# 添加需要加载的模块
$ cat > /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack
EOF

# 授权、运行、检查是否加载
$ chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules && lsmod | grep -e ip_vs -e nf_conntrack
```

配置免密登录，在k8s-master01节点上执行
```shell
$ ssh-keygen
$ ssh-copy-id root@k8s-master02
$ ssh-copy-id root@k8s-master03
$ ssh-copy-id root@k8s-ha01
$ ssh-copy-id root@k8s-ha02
$ ssh-copy-id root@k8s-node01
```

## 部署 Haproxy+Keepalived
关于apiserver高可用更多信息可以参考：https://github.com/kubernetes/kubeadm/blob/main/docs/ha-considerations.md#options-for-software-load-balancing

### Keepalived 配置
keepalived由两个文件组成：服务配置文件和健康检查脚本，该脚本将被定期调用以验证持有虚拟 IP 的节点是否仍然可运行，配置文件对应不同的节点需要对应修改。
```sh
$ yum -y install keepalived haproxy
```

```sh
$ mv /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf-backup
$ cat > /etc/keepalived/keepalived.conf <<EOF
global_defs {
    router_id LVS_DEVEL
}
vrrp_script check_apiserver {
  script "/etc/keepalived/check_apiserver.sh"  # 健康检查脚本路径
  interval 3
  weight -2
  fall 10
  rise 2
}

vrrp_instance VI_1 {
    state BACKUP  # MASTER或BACKUP
    interface ens33  # 网卡名称 
    virtual_router_id 51  # keepalived集群主机都应该相同
    priority 100  # MASTER节点的优先级应大于BACKUP节点
    authentication {
        auth_type PASS
        auth_pass 42  # 认证密码，同一keepalived集群保持一致
    }
    virtual_ipaddress {
        192.168.183.200  # VIP地址
    }
    track_script {
        check_apiserver
    }
}
EOF
```

健康检查脚本，两台主机都一样，不需要改动。
```shell
$ cat > /etc/keepalived/check_apiserver.sh <<EOF
#!/bin/sh

errorExit() {
    echo "*** $*" 1>&2
    exit 1
}

curl -sfk --max-time 2 https://localhost:6443/healthz -o /dev/null || errorExit "Error GET https://localhost:6443/healthz"
EOF

$ chmod +x /etc/keepalived/check_apiserver.sh
```


### haproxy 配置

haproxy配置文件，两台主机都一样。
```shell
$ mv /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg-backup
$ cat > /etc/haproxy/haproxy.cfg <<EOF
#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
    log stdout format raw local0
    daemon

#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 1
    timeout http-request    10s
    timeout queue           20s
    timeout connect         5s
    timeout client          35s
    timeout server          35s
    timeout http-keep-alive 10s
    timeout check           10s

#---------------------------------------------------------------------
# apiserver frontend which proxys to the control plane nodes
#---------------------------------------------------------------------
frontend apiserver
    bind *:6443
    mode tcp
    option tcplog
    default_backend apiserverbackend

#---------------------------------------------------------------------
# round robin balancing for apiserver
#---------------------------------------------------------------------
backend apiserverbackend
    option httpchk

    http-check connect ssl
    http-check send meth GET uri /healthz
    http-check expect status 200

    mode tcp
    balance     roundrobin
    
    server k8s-master01 192.168.183.163:6443 check
    server k8s-master02 192.168.183.167:6443 check
    server k8s-master01 192.168.183.166:6443 check
EOF
```

运行Haproxy+Keepalived
```shell
$ systemctl enable haproxy --now
$ systemctl enable keepalived --now
```

## 部署etcd
首先获取cfssl工具，cfssl是使用go编写，由CloudFlare开源的一款PKI/TLS工具。主要程序有：cfssl是CFSSL的命令行工具，cfssljson用来从cfssl程序获取JSON输出，并将证书，密钥，CSR和bundle写入文件中。
地址：https://github.com/cloudflare/cfssl
```shell
$ wget https://github.com/cloudflare/cfssl/releases/download/v1.6.5/cfssl_1.6.5_linux_amd64
$ mv cfssl_1.6.5_linux_amd64 /usr/local/bin/cfssl
$ chmod +x /usr/local/bin/cfssl

$ wget https://github.com/cloudflare/cfssl/releases/download/v1.6.5/cfssljson_1.6.5_linux_amd64
$ mv cfssljson_1.6.5_linux_amd64 /usr/local/bin/cfssljson
$ chmod +x /usr/local/bin/cfssljson

$ wget https://github.com/cloudflare/cfssl/releases/download/v1.6.5/cfssl-certinfo_1.6.5_linux_amd64
$ mv cfssl-certinfo_1.6.5_linux_amd64 /usr/local/bin/cfssl-certinfo
$ chmod +x /usr/local/bin/cfssl-certinfo
```

### 创建CA证书
CA证书请求文件:
```shell
$ mkdir -p /etc/etcd/ssl
$ cd /etc/etcd/ssl
$ cat > ca-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
      "algo": "rsa",
      "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "Beijing",
      "L": "Beijing",
      "O": "kubemsb",
      "OU": "CN"
    }
  ],
  "ca": {
          "expiry": "87600h"
  }
}
EOF
```

### 创建CA证书
```shell
$ cfssl gencert -initca ca-csr.json | cfssljson -bare ca
2024/06/14 11:19:17 [INFO] generating a new CA key and certificate from CSR
2024/06/14 11:19:17 [INFO] generate received request
2024/06/14 11:19:17 [INFO] received CSR
2024/06/14 11:19:17 [INFO] generating key: rsa-2048
2024/06/14 11:19:17 [INFO] encoded CSR
2024/06/14 11:19:17 [INFO] signed certificate with serial number 367517871777742057903646976472954743978464916668

[root@k8s-master01 ssl]# ls
ca.csr  ca-csr.json  ca-key.pem  ca.pem
```

### CA证书策略
```shell
cat > ca-config.json <<EOF
{
  "signing": {
      "default": {
          "expiry": "87600h"
        },
      "profiles": {
          "kubernetes": {
              "usages": [
                  "signing",
                  "key encipherment",
                  "server auth",
                  "client auth"
              ],
              "expiry": "87600h"
          }
      }
  }
}
EOF
```
> server auth 表示client可以对使用该ca对server提供的证书进行验证；client auth 表示server可以使用该ca对client提供的证书进行验证

### 配置etcd请求文件
```shell
$ cat > etcd-csr.json <<EOF
{
  "CN": "etcd",
  "hosts": [
    "192.168.183.163",
    "192.168.183.167",
    "192.168.183.166"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [{
    "C": "CN",
    "ST": "Beijing",
    "L": "Beijing",
    "O": "kubemsb",
    "OU": "CN"
  }]
}
EOF
```

### 生成etcd证书
```shell
$ cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes etcd-csr.json | cfssljson  -bare etcd
2024/06/14 11:30:42 [INFO] generate received request
2024/06/14 11:30:42 [INFO] received CSR
2024/06/14 11:30:42 [INFO] generating key: rsa-2048
2024/06/14 11:30:42 [INFO] encoded CSR
2024/06/14 11:30:42 [INFO] signed certificate with serial number 403663573731306296336301465001781948321175155647
```

### etcd集群部署
下载etcd软件包，下载地址：https://github.com/etcd-io/etcd
```shell
$ wget https://github.com/etcd-io/etcd/releases/download/v3.4.33/etcd-v3.4.33-linux-amd64.tar.gz
$ tar -zxvf etcd-v3.4.33-linux-amd64.tar.gz
$ cp -p etcd-v3.4.33-linux-amd64/etcd* /usr/local/bin/
$ scp -p etcd-v3.4.33-linux-amd64/etcd* k8s-master02:/usr/local/bin/
etcd                                                                                                                                   100%   20MB  17.8MB/s   00:01
etcdctl                                                                                                                                100%   16MB  32.5MB/s   00:00
$ scp -p etcd-v3.4.33-linux-amd64/etcd* k8s-master03:/usr/local/bin/
etcd                                                                                                                                   100%   20MB  12.3MB/s   00:01
etcdctl                                                                                                                                100%   16MB  23.6MB/s   00:00

```


### 创建etcd.services文件
```shell
# k8s-master01
$ cat > /etc/systemd/system/etcd.service <<EOF
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name etcd1 \\
  --cert-file=/etc/etcd/ssl/etcd.pem \\
  --key-file=/etc/etcd/ssl/etcd-key.pem \\
  --peer-cert-file=/etc/etcd/ssl/etcd.pem  \\
  --peer-key-file=/etc/etcd/ssl/etcd-key.pem \\
  --trusted-ca-file=/etc/etcd/ssl/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ssl/etcd.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://192.168.183.163:2380 \\
  --listen-peer-urls https://192.168.183.163:2380 \\
  --listen-client-urls https://192.168.183.163:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://192.168.183.163:2379 \\
  --initial-cluster-token etcd-cluster-1 \\
  --initial-cluster etcd1=https://192.168.183.163:2380,etcd2=https://192.168.183.167:2380,etcd3=https://192.168.183.166:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

```shell
# k8s-master02
$ cat > /etc/systemd/system/etcd.service <<EOF
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name etcd2 \\
  --cert-file=/etc/etcd/ssl/etcd.pem \\
  --key-file=/etc/etcd/ssl/etcd-key.pem \\
  --peer-cert-file=/etc/etcd/ssl/etcd.pem  \\
  --peer-key-file=/etc/etcd/ssl/etcd-key.pem \\
  --trusted-ca-file=/etc/etcd/ssl/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ssl/etcd.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://192.168.183.167:2380 \\
  --listen-peer-urls https://192.168.183.167:2380 \\
  --listen-client-urls https://192.168.183.167:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://192.168.183.167:2379 \\
  --initial-cluster-token etcd-cluster-1 \\
  --initial-cluster etcd1=https://192.168.183.163:2380,etcd2=https://192.168.183.167:2380,etcd3=https://192.168.183.166:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

```shell
# k8s-master03
$ cat > /etc/systemd/system/etcd.service <<EOF
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name etcd3 \\
  --cert-file=/etc/etcd/ssl/etcd.pem \\
  --key-file=/etc/etcd/ssl/etcd-key.pem \\
  --peer-cert-file=/etc/etcd/ssl/etcd.pem  \\
  --peer-key-file=/etc/etcd/ssl/etcd-key.pem \\
  --trusted-ca-file=/etc/etcd/ssl/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ssl/etcd.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://192.168.183.166:2380 \\
  --listen-peer-urls https://192.168.183.166:2380 \\
  --listen-client-urls https://192.168.183.166:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://192.168.183.166:2379 \\
  --initial-cluster-token etcd-cluster-1 \\
  --initial-cluster etcd1=https://192.168.183.163:2380,etcd2=https://192.168.183.167:2380,etcd3=https://192.168.183.166:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```


分发证书
```shell
$ scp /etc/etcd/ssl/* k8s-master02:/etc/etcd/ssl/
$ scp /etc/etcd/ssl/* k8s-master03:/etc/etcd/ssl/
```

启动
```shell
$ systemctl daemon-reload
$ systemctl enable etcd --now 
$ systemctl status etcd
```

验证
```shell
$ ETCDCTL_API=3 /usr/local/bin/etcdctl --write-out=table --cacert=/etc/etcd/ssl/ca.pem --cert=/etc/etcd/ssl/etcd.pem --key=/etc/etcd/ssl/etcd-key.pem --endpoints=https://192.168.183.163:2379,https://192.168.183.167:2379,https://192.168.183.166:2379 endpoint health
+------------------------------+--------+-------------+-------+
|           ENDPOINT           | HEALTH |    TOOK     | ERROR |
+------------------------------+--------+-------------+-------+
| https://192.168.183.167:2379 |   true | 11.645158ms |       |
| https://192.168.183.163:2379 |   true | 12.779309ms |       |
| https://192.168.183.166:2379 |   true | 17.193942ms |       |
+------------------------------+--------+-------------+-------+

$ ETCDCTL_API=3 /usr/local/bin/etcdctl --write-out=table --cacert=/etc/etcd/ssl/ca.pem --cert=/etc/etcd/ssl/etcd.pem --key=/etc/etcd/ssl/etcd-key.pem --endpoints=https://192.168.183.163:2379,https://192.168.183.167:2379,https://192.168.183.166:2379 endpoint status
+------------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|           ENDPOINT           |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+------------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://192.168.183.163:2379 | c1b461efd79007df |  3.5.13 |   20 kB |     false |      false |         2 |         12 |                 12 |        |
| https://192.168.183.167:2379 | c2eed83422caacba |  3.5.13 |   29 kB |      true |      false |         2 |         12 |                 12 |        |
| https://192.168.183.166:2379 | 74cd1bd143750b5b |  3.5.13 |   20 kB |     false |      false |         2 |         12 |                 12 |        |
+------------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

## 部署Kubernetes集群
二进制文件下载，稳定版本下载地址：https://www.downloadkubernetes.com/
在所有k8s master节点上，创建目录
```shell
$ mkdir -p /etc/kubernetes/        
$ mkdir -p /etc/kubernetes/ssl     
$ mkdir -p /var/log/kubernetes 
```

### 部署kube-apiserver
下载kube-apiserver二进制文件，下载地址：https://dl.k8s.io/v1.28.0/kubernetes-server-linux-amd64.tar.gz

https://dl.k8s.io/v1.28.11/bin/linux/amd64/kube-apiserver