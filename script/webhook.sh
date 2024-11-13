#!/bin/bash

# 企业微信群机器人配置说明：https://developer.work.weixin.qq.com/document/path/91770


sendkey=693a91f6-7xxx-4bc4-97a0-0ec2sifa5aaa

curl 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key'=$sendkey \
   -H 'Content-Type: application/json' \
   -d "
   {
    	\"msgtype\": \"text\",
    	\"text\": {
        	\"content\": \"$1\"
    	}
   }"