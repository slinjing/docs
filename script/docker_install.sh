#!/bin/bash

# centos 7安装docker
install_docker_centos7() {
  echo -e "\e[0m\e[33m正在安装docker...\e[0m"
  # 安装依赖
  yum install -y yum-utils device-mapper-persistent-data lvm2
  # 添加docker源
  yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
  sudo sed -i 's+download.docker.com+mirrors.aliyun.com/docker-ce+' /etc/yum.repos.d/docker-ce.repo
  # 安装docker
  yum install -y docker-ce docker-ce-cli docker-compose-plugin
  # 启动docker
  echo -e "\e[0m\e[33m正在启动docker...$(systemctl start docker)\e[0m"
  # 设置开机启动
  echo -e "\e[0m\e[33m设置开机启动...$(systemctl enable docker)\e[0m"
  
  # 查看docker版本
  echo -e "\e[0m\e[33m安装完成，查看docker版本...\e[0m"
  echo -e "\e[0m\e[33mdocker版本：$(docker --version)\e[0m"
  echo -e "\e[0m\e[33mdocker compose版本：$(docker compose version)\e[0m"
}

# ubuntu 安装docker
install_docker_ubuntu() {
  echo -e "\e[0m\e[33m正在安装docker...\e[0m"   
  # 安装依赖
  echo -e "\e[0m\e[33m安装依赖...\e[0m"  
  apt update
  apt install -y apt-transport-https ca-certificates curl software-properties-common
  # 添加docker源
  curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository -y "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
  # 安装docker
  apt update
  apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  # 启动docker
  systemctl start docker
  # 设置开机启动
  systemctl enable docker
  # 查看docker版本
  echo -e "\e[0m\e[33m安装完成，查看docker版本...\e[0m"
  echo -e "\e[0m\e[33mdocker版本：$(docker --version)\e[0m"
  echo -e "\e[0m\e[33mdocker compose版本：$(docker compose version)\e[0m"
}



if [ -f /etc/os-release ]; then
  . /etc/os-release
  echo -e "\e[0m\e[33m操作系统版本为: $ID linux $VERSION_ID\e[0m"  
  case "$ID" in
    centos|rocky)
      VERSION_ID=$(echo "$VERSION_ID" | cut -d'.' -f1)
      if [ "$VERSION_ID" == "7" ]; then
          install_docker_centos7
      else
          echo -e "\e[0m\e[33m当前系统版本不支持,脚本停止运行...\e[0m" 
          exit 1
      fi
      ;;
    debian|ubuntu)
      # Debian 或 Ubuntu 的安装步骤
      VERSION_ID_BIG=$(echo "$VERSION_ID" | cut -d'.' -f1)
      if ( [ "$VERSION_ID" == "12" ] || [ "$VERSION_ID_BIG" == "22" ] || [ "$VERSION_ID_BIG" == "24" ] ); then
      
          install_docker_ubuntu
      else
          echo -e "\e[0m\e[33m当前系统版本不支持,脚本停止运行...\e[0m"  
          exit 1
      fi
      ;;
  esac
fi