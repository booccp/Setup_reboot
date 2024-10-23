#!/bin/bash

# 定义绿色输出的函数
green_echo() {
  echo -e "\033[32m$1\033[0m"
}

# 定义红色输出的函数
red_echo() {
  echo -e "\033[31m$1\033[0m"
}

# 定义黄色输出的函数
yellow_echo() {
  echo -e "\033[33m$1\033[0m"
}

# 提示用户确认
green_echo "请确认本Linux系统有正确源，有同步时间ntpdate需要安装。"
read -p "请确认是否继续（Y/n，默认为Y）: " CONFIRM
CONFIRM=${CONFIRM:-Y}
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
  red_echo "取消操作。"
  exit 1
fi

# 检查系统发行版
if [ -f /etc/debian_version ]; then
  OS="Debian"
elif [ -f /etc/redhat-release ]; then
  OS="CentOS"
else
  red_echo "不支持的操作系统。"
  exit 1
fi

# 设置时区为东八区（香港时间）
green_echo "设置时区为东八区（香港时间）..."
timedatectl set-timezone Asia/Hong_Kong

# 同步时间
green_echo "同步时间..."
if [ "$OS" = "Debian" ]; then
  apt-get update && apt-get install -y ntpdate
  ntpdate pool.ntp.org
elif [ "$OS" = "CentOS" ]; then
  yum update && yum install -y chrony
  systemctl start chronyd
  systemctl enable chronyd
  chronyc -a makestep

  # 检查并关闭SELinux
  green_echo "检查并关闭SELinux..."
  SELINUX_STATUS=$(getenforce)
  if [ "$SELINUX_STATUS" != "Disabled" ]; then
    green_echo "SELinux已启用，正在关闭..."
    setenforce 0
    sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
    green_echo "SELinux已关闭。"
  else
    green_echo "SELinux已禁用。"
  fi
  green_echo "当前SELinux状态：$(getenforce)"
fi

while true; do
  # 提示用户选择功能
  green_echo "请选择您需要的功能："
  green_echo "1. 设置仅一次重启时间"
  green_echo "2. 每月固定时间日期重启"
  green_echo "3. 每月1号固定时间重启"
  green_echo "4. 查看所有重启任务"
  green_echo "5. 取消所有重启任务"
  green_echo "6. 退出"
  read -p "请输入选项（1/2/3/4/5/6）: " OPTION

  case $OPTION in
    1)
      # 设置仅一次重启时间
      read -p "请输入重启日期和时间（格式：YYYYMMDDHHMM，例如202410222150表示2024年10月22日21:50）: " REBOOT_DATETIME

      # 检查输入的日期和时间格式是否正确
      if [[ ! $REBOOT_DATETIME =~ ^[0-9]{12}$ ]]; then
        red_echo "输入的日期和时间格式有误，请使用YYYYMMDDHHMM格式。"
        continue
      fi

      # 分解输入的日期和时间
      green_echo "解析输入的日期和时间..."
      YEAR=${REBOOT_DATETIME:0:4}
      MONTH=${REBOOT_DATETIME:4:2}
      DAY=${REBOOT_DATETIME:6:2}
      HOUR=${REBOOT_DATETIME:8:2}
      MINUTE=${REBOOT_DATETIME:10:2}

      # 验证时间格式
      if (( HOUR < 0 || HOUR > 23 || MINUTE < 0 || MINUTE > 59 )); then
        red_echo "输入的时间格式有误，请使用HHMM格式，小时应在00到23之间，分钟应在00到59之间。"
        continue
      fi

      # 确认输入的日期和时间
      green_echo "您输入的重启时间是：$YEAR-$MONTH-$DAY $HOUR:$MINUTE"
      read -p "请确认输入的时间是否正确（Y/n，默认为Y）: " CONFIRM
      CONFIRM=${CONFIRM:-Y}
      if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        red_echo "取消操作。"
        continue
      fi

      # 创建重启脚本
      RESTART_SCRIPT="/usr/local/bin/restart.sh"
      green_echo "创建重启脚本 $RESTART_SCRIPT..."
      echo "#!/bin/bash" > $RESTART_SCRIPT
      echo "/sbin/shutdown -r now" >> $RESTART_SCRIPT

      # 赋予脚本执行权限
      green_echo "赋予重启脚本执行权限..."
      chmod +x $RESTART_SCRIPT

      # 使用 cron 设置一次性任务
      green_echo "设置一次性重启任务..."
      (crontab -l 2>/dev/null; echo "$MINUTE $HOUR $DAY $MONTH * /bin/bash $RESTART_SCRIPT") | crontab -

      green_echo "一次性重启任务已设置，将在 $YEAR-$MONTH-$DAY $HOUR:$MINUTE 重启系统。"
      exit 0
      ;;

    2)
      # 每月固定时间日期重启
      read -p "请输入每月重启的日期和时间（格式：DDHHMM，例如190220表示每月19号02:20）: " REBOOT_DATETIME

      # 检查输入的日期和时间格式是否正确
      if [[ ! $REBOOT_DATETIME =~ ^[0-9]{6}$ ]]; then
        red_echo "输入的日期和时间格式有误，请使用DDHHMM格式。"
        continue
      fi

      # 分解输入的日期和时间
      green_echo "解析输入的日期和时间..."
      REBOOT_DAY=${REBOOT_DATETIME:0:2}
      HOUR=${REBOOT_DATETIME:2:2}
      MINUTE=${REBOOT_DATETIME:4:2}

      # 验证时间格式
      if (( HOUR < 0 || HOUR > 23 || MINUTE < 0 || MINUTE > 59 )); then
        red_echo "输入的时间格式有误，请使用HHMM格式，小时应在00到23之间，分钟应在00到59之间。"
        continue
      fi

      # 确认输入的日期和时间
      green_echo "您输入的重启时间是：每月 $REBOOT_DAY 日 $HOUR:$MINUTE"
      read -p "请确认输入的时间是否正确（Y/n，默认为Y）: " CONFIRM
      CONFIRM=${CONFIRM:-Y}
      if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        red_echo "取消操作。"
        continue
      fi

      # 创建重启脚本
      RESTART_SCRIPT="/usr/local/bin/restart.sh"
      green_echo "创建重启脚本 $RESTART_SCRIPT..."
      echo "#!/bin/bash" > $RESTART_SCRIPT
      echo "/sbin/shutdown -r now" >> $RESTART_SCRIPT

      # 赋予脚本执行权限
      green_echo "赋予重启脚本执行权限..."
      chmod +x $RESTART_SCRIPT

      # 使用 cron 设置定时任务
      green_echo "设置定时任务..."
      (crontab -l 2>/dev/null; echo "$MINUTE $HOUR $REBOOT_DAY * * /bin/bash $RESTART_SCRIPT") | crontab -

      green_echo "定时重启任务已设置，将在每月 $REBOOT_DAY 日 $HOUR:$MINUTE 重启系统。"
      exit 0
      ;;

    3)
      # 每月1号固定时间重启
      read -p "请输入重启时间（格式：HHMM，例如2150表示21:50）: " REBOOT_TIME

      # 检查输入的时间格式是否正确
      if [[ ! $REBOOT_TIME =~ ^[0-9]{4}$ ]]; then
        red_echo "输入的时间格式有误，请使用HHMM格式。"
        continue
      fi

      # 分解输入的时间
      HOUR=${REBOOT_TIME:0:2}
      MINUTE=${REBOOT_TIME:2:2}

      # 验证时间格式
      if (( HOUR < 0 || HOUR > 23 || MINUTE < 0 || MINUTE > 59 )); then
        red_echo "输入的时间格式有误，请使用HHMM格式，小时应在00到23之间，分钟应在00到59之间。"
        continue
      fi

      # 确认输入的时间
      green_echo "您输入的重启时间是：每月 1 日 $HOUR:$MINUTE"
      read -p "请确认输入的时间是否正确（Y/n，默认为Y）: " CONFIRM
      CONFIRM=${CONFIRM:-Y}
      if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        red_echo "取消操作。"
        continue
      fi

      # 创建重启脚本
      RESTART_SCRIPT="/usr/local/bin/restart.sh"
      green_echo "创建重启脚本 $RESTART_SCRIPT..."
      echo "#!/bin/bash" > $RESTART_SCRIPT
      echo "/sbin/shutdown -r now" >> $RESTART_SCRIPT

      # 赋予脚本执行权限
      green_echo "赋予重启脚本执行权限..."
      chmod +x $RESTART_SCRIPT

      # 使用 cron 设置定时任务
      green_echo "设置定时任务..."
      (crontab -l 2>/dev/null; echo "$MINUTE $HOUR 1 * * /bin/bash $RESTART_SCRIPT") | crontab -

      green_echo "定时重启任务已设置，将在每月 1 日 $HOUR:$MINUTE 重启系统。"
      exit 0
      ;;

    4)
      # 查看所有重启任务
      green_echo "查看所有重启任务..."
      CRON_TASKS=$(crontab -l | grep '/usr/local/bin/restart.sh')

      if [ -z "$CRON_TASKS" ]; then
        red_echo "没有任何重启任务。"
      else
        green_echo "已设置的重启任务："
        CURRENT_TIME=$(date +%s)
        NEW_CRON_TASKS=""
        while IFS= read -r line; do
          MINUTE=$(echo "$line" | awk '{print $1}')
          HOUR=$(echo "$line" | awk '{print $2}')
          DAY=$(echo "$line" | awk '{print $3}')
          MONTH=$(echo "$line" | awk '{print $4}')
          if [ "$MONTH" = "*" ]; then
            yellow_echo "每月 $DAY 日 $HOUR:$MINUTE 重启系统"
            NEW_CRON_TASKS+="$line"$'\n'
          else
            TASK_TIME=$(date -d "$MONTH/$DAY $HOUR:$MINUTE" +%s)
            if [ "$TASK_TIME" -lt "$CURRENT_TIME" ]; then
              red_echo "已删除过期任务：在 $MONTH 月 $DAY 日 $HOUR:$MINUTE 重启系统"
            else
              yellow_echo "在 $MONTH 月 $DAY 日 $HOUR:$MINUTE 重启系统"
              NEW_CRON_TASKS+="$line"$'\n'
            fi
          fi
        done <<< "$CRON_TASKS"
        echo "$NEW_CRON_TASKS" | crontab -
      fi
      ;;

    5)
      # 取消所有重启任务
      green_echo "取消所有重启任务..."
      crontab -l | grep -v '/usr/local/bin/restart.sh' | crontab -
      green_echo "所有重启任务已取消。"
      ;;

    6)
      # 退出
      green_echo "退出脚本。"
      exit 0
      ;;

    *)
      red_echo "无效的选项。"
      ;;
  esac
done