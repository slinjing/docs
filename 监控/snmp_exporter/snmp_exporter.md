# snmp_exporter：

## 环境准备
```bash
yum install -y gcc gcc-g++ make net-snmp net-snmp-utils net-snmp-libs net-snmp-devel go
```
## 配置snmp_exporter
### 测试SNMP
```bash
snmpwalk -v2c -c community ip .1
```
### generator
```bash
#上传generator包
tar -zxvf snmp_exporter-0.21.0.tar.gz
mv snmp_exporter-0.21.0 snmp_exporter-generator
cd snmp_exporter-generator/generator
mkdir mibs  #将mib文件上传至本目录
```
### 修改generator.yml
```bash
mv generator.yml generator.yml.backup
-------------------------------------
#generator.yml:
modules:
  GT-SW-S7703:
    walk:
          # 设备状态监控
          - 1.3.6.1.4.1.2011.5.25.31.1.1.1.1.5
          - 1.3.6.1.4.1.2011.5.25.31.1.1.1.1.7
          - 1.3.6.1.4.1.2011.5.25.31.1.1.1.1.9
          - 1.3.6.1.4.1.2011.5.25.31.1.1.1.1.11
          - 1.3.6.1.4.1.2011.5.25.31.1.1.3.1.5
          - 1.3.6.1.4.1.2011.5.25.31.1.1.3.1.6
          - 1.3.6.1.4.1.2011.5.25.31.1.1.3.1.7
          - 1.3.6.1.4.1.2011.5.25.31.1.1.3.1.8
          - 1.3.6.1.4.1.2011.5.25.31.1.1.3.1.9
          # 端口流量控制 
          - 1.3.6.1.2.1.2.2.1
          - 1.3.6.1.2.1.2.2.1.8
          - 1.3.6.1.4.1.2011.5.25.41.1.7.1.1.8
          - 1.3.6.1.4.1.2011.5.25.41.1.7.1.1.10
          # MAC、ARP监控
          - 1.3.6.1.2.1.17.4.3.1.1
          - 1.3.6.1.4.1.2011.5.25.42.2.1.3.1.1
          - 1.3.6.1.4.1.2011.5.25.42.2.1.2.1.1
          - 1.3.6.1.4.1.2011.5.25.123.1.17.1
          - 1.3.6.1.4.1.2011.5.25.123.1.18.1
          # 业务监控
          - 1.3.6.1.2.1.17.2.15.1.3
          - 1.3.6.1.4.1.2011.5.25.113.2.2.1.4
          - 1.3.6.1.2.1.68.1.3.1.3    
    version: 2
    auth:
      community: password

```
### 生成snmp.yml
```bash
#当前路径:/root/snmp_exporter-generator/generator
export GO111MODULE=on
export GOPROXY=https://goproxy.cn,direct
go build
export MIBDIRS=mibs
./generator generate
```
## snmp_exporter
### 下载
```bash
wget https://github.com/prometheus/snmp_exporter/releases/download/v0.21.0/snmp_exporter-0.21.0.linux-386.tar.gz
tar -zxvf snmp_exporter-0.21.0.linux-386.tar.gz
mv snmp_exporter-0.21.0.linux-386 /home/snmp_exporter
```
### 将snmp_exporter的配置文件替换为生成的snmp.yml
```bash
cd /home/snmp_exporter/
cp /root/snmp_exporter-generator/generator/snmp.yml .
```

### snmp_exporter.service
```bash
cat /etc/systemd/system/snmp_exporter.service
-------------------------------------
[Unit]
Description=SNMP Exporter
After=network-online.target

[Service]
User=root
Restart=on-failure
ExecStart=/home/snmp_exporter/snmp_exporter --config.file=/home/snmp_exporter/snmp.yml

[Install]
WantedBy=multi-user.target
-------------------------------------
systemctl daemon-reload
systemctl enable snmp_exporter.service
systemctl start snmp_exporter.service
systemctl status snmp_exporter.service
netstat -tuplan | grep 9116
```
## prometheus.yml
```bash
  - job_name: 'snmp'
#    scrape_interval: 10s
#    scrape_timeout: 10s
    static_configs:
      - targets:
        - ip  #交换机ip
    metrics_path: /snmp
    params:
      module: [GT-SW-S7703]  
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: 192.168.33.49:9116
-------------------------------------       
./promtool check config prometheus.yml  #检查配置文件
systemctl restart prometheus.service
```
