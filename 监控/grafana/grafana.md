# grafana
## 安装
```bash
wget https://dl.grafana.com/oss/release/grafana-8.0.5.linux-amd64.tar.gz
tar -zxvf grafana-8.0.5.linux-amd64.tar.gz -C /home/
nohup /home/grafana/bin/grafana-server &
```
## grafana-server.service
```
cat <<EOF >/etc/systemd/system/grafana-server.service
[Unit]
Description=grafana
Documentation=https://grafana.com/
After=network.target
[Service]
Type=simple
ExecStart=/home/grafana/bin/grafana-server --homepath /home/grafana
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
-----------------------------------------------------
systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server
systemctl status grafana-server
netstat -tuplan | grep 3000
```
