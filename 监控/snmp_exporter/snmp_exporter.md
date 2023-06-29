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
  HUAWEI:
    walk:
      - 1.3.6.1.2.1.1.1                     #sysDescr
      - 1.3.6.1.2.1.1.3                     #sysUpTimeInstance
      - 1.3.6.1.2.1.1.5                     #sysName
      - 1.3.6.1.2.1.2.1                     #ifNumber
      - 1.3.6.1.2.1.2.2.1.1                 #ifIndex
      - 1.3.6.1.2.1.2.2.1.2                 #IfDescr
      - 1.3.6.1.2.1.2.2.1.3                 #ifType
      - 1.3.6.1.2.1.2.2.1.5                 #ifSpeed
      - 1.3.6.1.2.1.31.1.1.1.15             #ifHighSpeed
      - 1.3.6.1.2.1.31.1.1.1.18             #ifAlias
      - 1.3.6.1.2.1.2.2.1.8                 #ifOperStatus
      - 1.3.6.1.2.1.2.2.1.13                #ifInDiscards
      - 1.3.6.1.2.1.2.2.1.14                #ifInErrors
      - 1.3.6.1.2.1.2.2.1.19                #ifOutDiscards
      - 1.3.6.1.2.1.2.2.1.20                #ifOutErrors
      - 1.3.6.1.2.1.31.1.1.1.1              #ifName
      - 1.3.6.1.2.1.31.1.1.1.6              #ifHCInOctets
      - 1.3.6.1.2.1.31.1.1.1.10             #ifHCOutOctets
      - 1.3.6.1.2.1.2.2.1.10                #ifInOctets
      - 1.3.6.1.2.1.2.2.1.16                #ifOutOctets
      - 1.3.6.1.2.1.47.1.1.1.1.1            #entPhysicalIndex
      - 1.3.6.1.2.1.47.1.1.1.1.7            #entPhysicalName
      - 1.3.6.1.4.1.2011.5.25.31.1.1.1.1.5  #hwEntityCpuUsage huawei
      - 1.3.6.1.4.1.2011.5.25.31.1.1.1.1.7  #hwEntityMemUsage huawei
      - 1.3.6.1.4.1.2011.5.25.31.1.1.1.1.11 #hwEntityTemperature
      - 1.3.6.1.4.1.2011.5.25.31.1.1.10.1.7 #hwEntityFanState
      - 1.3.6.1.4.1.2011.5.25.31.1.1.14.1.3 #hwSystemPowerUsedPower
      - 1.3.6.1.4.1.2011.5.25.31.1.1.1.1.9  #hwEntityMemSize
      - 1.3.6.1.4.1.2011.6.9.1.4.2.1.3      #hwStorageSpace
      - 1.3.6.1.4.1.2011.6.9.1.4.2.1.4      #hwStorageSpaceFree 
    #max_repetitions: 3
    #retries: 3
    #timeout: 25s
    version: 2
    auth:
      community: zZPBPtYcIZ1tM
    lookups:
      - source_indexes: [ifIndex]
        lookup: ifAlias
      - source_indexes: [ifIndex]
        lookup: 1.3.6.1.2.1.2.2.1.2 # ifDescr
      - source_indexes: [ifIndex]
        lookup: 1.3.6.1.2.1.31.1.1.1.1 # ifName
      - source_indexes: [entPhysicalIndex]
        lookup: 1.3.6.1.2.1.47.1.1.1.1.7 #entPhysicalName
    overrides:
      ifAlias:
        ignore: true # Lookup metric
      ifDescr:
        ignore: true # Lookup metric
      ifName:
        ignore: true # Lookup metric
      ifType:
        ignore: true # Lookup metric
      entPhysicalIndex:
        ignore: true # Lookup metric
      entPhysicalName:
        ignore: true # Lookup metric
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
    scrape_interval: 1m
    scrape_timeout: 30s
    static_configs:
      - targets:
        - 200.200.10.2  #交换机ip
        - 192.168.110.2 
      # - ....
    metrics_path: /snmp
    params:
      module: [HUAWEI]  
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: 192.168.32.146:9116  
-------------------------------------       
./promtool check config prometheus.yml  #检查配置文件
systemctl restart prometheus.service
```
