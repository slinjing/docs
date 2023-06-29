# snmp配置
snmp-agent
snmp-agent sys-info version v2c
snmp-agent community read cipher zZPBPtYcIZ1tM
snmp-agent target-host trap address udp-domain 192.168.32.146 params securityname cipher zZPBPtYcIZ1tM
snmp-agent trap enable
snmp-agent protocol source-interface vlanif 206