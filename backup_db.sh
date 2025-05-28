#！/bin/bash

# mysql的账户信息
user='root'
password='QAZqaz1234@'

# 数据库的服务器地址
mysql_host='192.168.33.131'

# 数据库的备份目录
backup_dir='/home/mysql_backup'

# 备份文件后缀名
backup_suffix="$(date "+%Y-%m-%d %H:%M:%S").sql.gz"

# 备份哪一个数据库
database='test'


function backup_db(){
  [ -d $backup_dir ] || mkdir -p $backup_dir
  backup_file="$backup_dir/backup_$database.$backup_suffix"
  mysqldump -u$user -p$password -h $mysql_host --single-transaction --routines --triggers --events --add-drop-database --databases $db | gzip > "$backup_file"

  if [ $? -eq 0 ]
    then
        echo "备份$db成功，备份文件为$backup_file"
    else
        echo "备份$db失败"
    fi
}


main(){
    backup_db
}


main