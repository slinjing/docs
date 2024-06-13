#  <center> Centos安装Docker与基本配置

## 必备条件

系统为Centos 7以上，Linux内核为3.8以上。

```bash
$ cat /etc/redhat-release
CentOS Linux release 7.9.2009 (Core)
$ uname -r
3.10.0-1160.el7.x86_64
```

## 环境准备

更换镜像源和安装必备工具

```shell
$ yum install -y wget
$ cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.back
$ wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
$ yum clean all && yum makecache
$ yum install -y epel-release yum-utils device-mapper-persistent-data lvm2
```

## 添加Docker软件源

```bash
$ yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
$ sed -i 's+download.docker.com+mirrors.aliyun.com/docker-ce+' /etc/yum.repos.d/docker-ce.repo
$ yum makecache fast
```

## 安装Docker

**安装最新版本命令**

```bash
$ yum -y install docker-ce
```

**安装指定版本命令**

```shell
# 查看可选版本
$ yum list docker-ce.x86_64 --showduplicates | sort -r
# 安装指定版本
$ yum -y install docker-ce-[VERSION]
```

## 启动Docker

```bash
$ systemctl enable docker --now
```

## 镜像加速

由于默认的镜像下载源是在国外，镜像下载速度会比较慢，所以这里更改一下镜像源提高镜像拉取速度。这里提供几个常用的镜像下载地址,也可以使用阿里云的镜像加速器，个人可以免费使用。

```shell
# 腾讯云 docker hub 镜像
https://mirror.ccs.tencentyun.com
# DaoCloud 镜像
https://docker.m.daocloud.io
# 阿里云 docker hub 镜像
https://registry.cn-hangzhou.aliyuncs.com
```

修改Docker的配置文件中（/etc/docker/daemon.json）添加以下内容：

```shell
$ tee /etc/docker/daemon.json <<-'EOF'
{  
"registry-mirrors": ["https://registry.cn-hangzhou.aliyuncs.com"]
}
EOF

$ systemctl daemon-reload
$ systemctl restart docker
```

## 修改Docker默认存储路径

使用以下命令可以看到Docker的默认存储路径是 /var/lib/docker

```shell
$ docker info | grep Dir
Docker Root Dir: /var/lib/docker
```

如果我们希望将数据存储到其他位置可以按照下面的流程修改

```shell
# 停止docker服务
$ systemctl stop docker

# 修改/etc/docker/daemon.json，加入一行新配置
$ cat /etc/docker/daemon.json
{  
"registry-mirrors": ["https://registry.cn-hangzhou.aliyuncs.com"],
"data-root": "/home/docker"  # 新存储路径必须存在
}

# 数据迁移
$ yum -y install rsync
$ rsync -avz /var/lib/docker /home/docker

# 重启docker
$ systemctl restart docker

# 检查验证
$ docker info | grep Dir
$ docker ps -a
$ docker images

# 验证无误后删除原目录
$ rm -rf /var/lib/docker/*
```

## 卸载Docker：

```bash
$ yum -y remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine

$ rm -rf /var/lib/docker/*
```