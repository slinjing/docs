# prometheus
## 下载
```bash
wget https://github.com/prometheus/prometheus/releases/download/v2.45.0-rc.0/prometheus-2.45.0-rc.0.linux-amd64.tar.gz
tar -zxvf prometheus-2.43.0-rc.0.linux-amd64.tar.gz -C /home/
mv prometheus-2.43.0-rc.0.linux-amd64 prometheus
```
### prometheus.service
```bash
cat /etc/systemd/system/prometheus.service
-------------------------------------
[Unit]
Description=prometheus
After=network-online.target

[Service]
User=root
Restart=on-failure
ExecStart=/home/prometheus/prometheus --config.file=/home/prometheus/prometheus.yml

[Install]
WantedBy=multi-user.target
-------------------------------------
systemctl daemon-reload
systemctl enable prometheus.service
systemctl start prometheus.service
systemctl status prometheus.service
netstat -tuplan | grep 9090
```
### prometheus.yml
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
```
### 基于文件的服务发现
```
vim prometheus.yml
  - job_name: 'file_sd'
    file_sd_configs:
    - files:
      - 'sd_config/*.yml'
      refresh_interval: 5s  # 每隔5秒检查一次
```
vim sd_config/windows.yml
```yaml
- targets:
  - "192.168.33.205:9182"
  - "192.168.32.146:9100"
  - "192.168.33.205:9182"
  - "121.41.114.211:9100"
  - "34.239.0.205:9100"
  - "192.168.1.221:9100"
  - "10.1.20.201:9100"
  - "10.1.20.247:9100"
```
```
交换机

```
### 检查配置文件
./promtool check config prometheus.yml  
### 热加载配置：
curl -X POST http://192.168.32.146:9090/-/reload