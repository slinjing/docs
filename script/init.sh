#!/bin/bash

######################### 更换镜像源 #########################
# CentOS7
yum_repos_centos(){
    # 备份原有的yum源配置
    mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
    
    # 下载阿里云的CentOS源配置文件
    curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
   
    # 清理缓存并生成新的缓存
    yum clean all
    yum makecache
    yum install -y epel-release
    echo -e "\e[0m\e[33m阿里云yum源更换完成。\e[0m"
}

# ubuntu
yum_repos_ubuntu(){
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup
    # 更新sources.list文件
    echo "deb http://mirrors.aliyun.com/ubuntu/ $(lsb_release -sc) main restricted universe multiverse" | sudo tee /etc/apt/sources.list
    echo "deb-src http://mirrors.aliyun.com/ubuntu/ $(lsb_release -sc) main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list
    echo "deb http://mirrors.aliyun.com/ubuntu/ $(lsb_release -sc)-updates main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list
    echo "deb-src http://mirrors.aliyun.com/ubuntu/ $(lsb_release -sc)-updates main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list
    echo "deb http://mirrors.aliyun.com/ubuntu/ $(lsb_release -sc)-security main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list
    echo "deb-src http://mirrors.aliyun.com/ubuntu/ $(lsb_release -sc)-security main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list
    
    # 更新软件包列表
    sudo apt-get update
    
    echo -e "\e[0m\e[33m已将Ubuntu系统的YUM源更换为阿里云源。\e[0m"
}

########################## 时间同步 ##########################
# CentOS7
sudo yum install chrony

ntp_centos(){
    timedatectl set-timezone Asia/Shanghai
    ntpdate ntp1.aliyun.com 
    cat > /var/spool/cron/root << EOF
    * */1 * * * ntpdate -u ntp1.aliyun.com > /dev/null 2>&1 
EOF
    hwclock -w
}

# Debian/Ubuntu
ntp_ubuntu(){
    sudo apt-get install chrony
}

# Fedora
ntp_fedora(){
    sudo dnf install chrony
}


#############################################################


if [ -f /etc/os-release ]; then
    source /etc/os-release
    echo "当前系统版本: $PRETTY_NAME"
    case "$ID" in
        centos)
        VERSION_ID=$(echo "$VERSION_ID" | cut -d'.' -f1)
        if [ "$VERSION_ID" == "7" ]; then
            yum_repos_centos
        else
            echo -e "\e[0m\e[33m当前系统版本不支持,脚本停止运行...\e[0m" 
            exit 1
        fi
        ;;
    debian|ubuntu)
      # Debian 或 Ubuntu 的安装步骤
      VERSION_ID_BIG=$(echo "$VERSION_ID" | cut -d'.' -f1)
      if ( [ "$VERSION_ID" == "12" ] || [ "$VERSION_ID_BIG" == "22" ] || [ "$VERSION_ID_BIG" == "24" ] ); then
      
          yum_repos_ubuntu
      else
          echo -e "\e[0m\e[33m当前系统版本不支持,脚本停止运行...\e[0m"  
          exit 1
      fi
      ;;
  esac
fi
