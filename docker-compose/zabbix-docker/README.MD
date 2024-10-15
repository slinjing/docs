# ZABBIX-DOCKER

## 部署
克隆存储库后切换到 zabbix-docker 目录下，执行`docker-compose up -d`命令。

## 修改版本
修改 .env 文件中的 ZABBIX_UBUNTU_IMAGE_TAG 参数，目前只支持 ubuntu-5.0-latest、ubuntu-6.0-latest 和 ubuntu-7.0-latest。

## Agent
部署完成后需要修改 Agent 地址为 zabbix-agent 容器地址：110.20.240.5，否则代理无法连接。

## 删除
```shell
$ docker-compose down
$ docker volume rm zabbix-docker_zabbix-mysql zabbix-docker_zabbix-server
```



