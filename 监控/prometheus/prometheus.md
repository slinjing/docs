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
---------------------------------------------
./promtool check config prometheus.yml  #检查配置文件
```
