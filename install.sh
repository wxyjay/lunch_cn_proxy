#!/bin/bash

PINK='\033[1;35m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# 定义一个函数，用于执行命令，如果当前用户是 root 则不使用 sudo
run_command() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

display_mosaic() {
  clear
  echo -e "${PINK}"
  echo "=================================================="
  echo "##                                              ##"
  echo "##   MM  MM   AAAA   DDDD  EEEEEE                ##"
  echo "##   MMM MMM  AA AA  DD DD EE                    ##"
  echo "##   MM MM MM AAAAAA DD  DD EEEE                  ##"
  echo "##   MM  MM  AA AA  DD DD EE                    ##"
  echo "##   MM  MM  AA AA  DDDD  EEEEEE                ##"
  echo "##                                              ##"
  echo "##   BBBBBB   YY  YY                             ##"
  echo "##   BB   BB   YY YY                             ##"
  echo "##   BBBBBB    YYYY                              ##"
  echo "##   BB   BB    YY                               ##"
  echo "##   BBBBBB    YY                               ##"
  echo "##                                              ##"
  echo "##   LL      UU UU NNNN NN CCCCCC HH  HH         ##"
  echo "##   LL      UU UU NN NNNN CC     HH  HH         ##"
  echo "##   LL      UU UU NN  NNN CC     HHHHHH         ##"
  echo "##   LL      UU UU NN   NN CC     HH  HH         ##"
  echo "##   LLLLLL   UUUU  NN    N CCCCCC HH  HH         ##"
  echo "##                                              ##"
  echo "=================================================="
  echo -e "${NC}"
}

display_mosaic

echo -e "\n安装程序即将启动，按住 Ctrl + C 以取消..."
sleep 5
clear

echo "检查是否已安装 cn_http_proxy 服务..."
if systemctl is-enabled cn_http_proxy --quiet && systemctl is-active cn_http_proxy --quiet; then
  echo "cn_http_proxy 服务已安装并运行。"
  installed=true
else
  echo "未发现 cn_http_proxy 服务。"
  installed=false
fi

if [ "$installed" = "false" ]; then

  echo "\n创建目录 /etc/lunchkit 和 /etc/lunchkit/cn_http_proxy ..."
  run_command mkdir -p /etc/lunchkit/cn_http_proxy

  echo "解压 lunch_proxy.zip 到 /etc/lunchkit/cn_http_proxy ..."
  if [ -f "lunch_proxy.zip" ]; then
    run_command unzip -d /etc/lunchkit/cn_http_proxy lunch_proxy.zip

    echo "删除 lunch_proxy.zip ..."
    rm -f lunch_proxy.zip
  else
    echo "错误: 当前目录下找不到 lunch_proxy.zip 文件，请确保该文件存在。"
    exit 1
  fi

  cd /etc/lunchkit/cn_http_proxy
  echo "\n切换工作目录到 /etc/lunchkit/cn_http_proxy"

  echo "检查是否安装 clang ..."
  if ! command -v clang &> /dev/null; then
    echo "clang 未安装，尝试安装 ..."
    run_command apt update
    run_command apt install clang -y
  else
    echo "clang 已安装。"
  fi

  echo "检查是否安装 make ..."
  if ! command -v make &> /dev/null; then
    echo "make 未安装，尝试安装 ..."
    run_command apt update
    run_command apt install make -y
  else
    echo "make 已安装。"
  fi

  echo "\n即将开始编译 ..."
  make
  if [ $? -eq 0 ]; then
    echo "编译结束。"
  else
    echo "编译过程中发生错误，请检查错误信息。"
    exit 1
  fi

  echo -e "\n请选择服务器地址:\n1) 默认\n2) 自定义"
  read -p "请选择 (1 或 2): " server_choice
  server_address=""
  case "$server_choice" in
    1)
      echo "使用默认服务器地址。"
      ;;
    2)
      read -p "请输入自定义服务器地址: " server_address
      ;;
    *)
      echo "无效的选择，使用默认服务器地址。"
      ;;
  esac

  echo -e "\n请选择 HTTP 代理端口:\n1) 默认 (9000)\n2) 自定义"
  read -p "请选择 (1 或 2): " port_choice
  port="9000"
  case "$port_choice" in
    1)
      echo "使用默认端口 9000。"
      ;;
    2)
      read -p "请输入自定义端口 (纯数字): " custom_port
      if [[ "$custom_port" =~ ^[0-9]+$ ]]; then
        port="$custom_port"
      else
        echo "无效的端口，使用默认端口 9000。"
      fi
      ;;
    *)
      echo "无效的选择，使用默认端口 9000。"
      ;;
  esac

  echo "\n创建 启动脚本：start.sh ..."
  cat > start.sh <<EOL
#!/bin/bash
if [ -z "$SERVER_ADDRESS" ]; then
  ./thread_socket -p "$PORT"
else
  ./thread_socket -p "$PORT" -r "$SERVER_ADDRESS"
fi
EOL
  chmod +x start.sh


  echo "创建 systemd 服务 cn_http_proxy ..."
  cat > /etc/systemd/system/cn_http_proxy.service <<EOL
[Unit]
Description=cn_http_proxy
After=network.target

[Service]
WorkingDirectory=/etc/lunchkit/cn_http_proxy
ExecStart=/etc/lunchkit/cn_http_proxy/start.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOL
  run_command systemctl daemon-reload

  echo "启动 cn_http_proxy 服务 ..."
  run_command systemctl enable cn_http_proxy
  run_command systemctl start cn_http_proxy
  run_command systemctl status cn_http_proxy
fi

cat > lunch_proxy <<EOL
#!/bin/bash

SERVICE_NAME="cn_http_proxy"
START_SCRIPT="/etc/lunchkit/cn_http_proxy/start.sh"
PROXY_DIR="/etc/lunchkit/cn_http_proxy"

# 定义一个函数，用于执行需要 root 权限的命令
run_root_command() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

menu() {
  echo "-------------------- Lunch CN Proxy 菜单 --------------------"
  echo "(1) 服务信息"
  echo "(2) 启动服务"
  echo "(3) 重启服务"
  echo "(4) 停止服务"
  echo "(5) 卸载服务"
  echo "(6) 查看当前端口"
  echo "(7) 查看/修改服务器地址"
  echo "(8) 修改服务器地址"
  echo "(q) 退出"
  echo "---------------------------------------------------------"
  choice=""
  read -p "请选择: " choice
  echo "您输入的字符是: '$choice'"
  choice=$(echo "$choice" | tr -d '[:space:]')
  sleep 1
  case "$choice" in
    1) systemctl status "$SERVICE_NAME"; read -n 1 -s -p "按 Enter 返回主菜单"; echo ;;
    2) run_root_command systemctl start "$SERVICE_NAME"; read -n 1 -s -p "按 Enter 返回主菜单"; echo ;;
    3) run_root_command systemctl restart "$SERVICE_NAME"; read -n 1 -s -p "按 Enter 返回主菜单"; echo ;;
    4) run_root_command systemctl stop "$SERVICE_NAME"; read -n 1 -s -p "按 Enter 返回主菜单"; echo ;;
    5)
      echo -e "停止 $SERVICE_NAME 服务..."
      run_root_command systemctl stop "$SERVICE_NAME"
      echo "禁用 $SERVICE_NAME 服务..."
      run_root_command systemctl disable "$SERVICE_NAME"
      echo "删除 $SERVICE_NAME 服务文件..."
      run_root_command rm -f /etc/systemd/system/"$SERVICE_NAME".service
      echo "删除 $PROXY_DIR 目录..."
      run_root_command rm -rf "$PROXY_DIR"
      echo "删除 lunch_proxy 菜单..."
      run_root_command rm -f "$0"
      echo "卸载完成。"
      exit 0
      ;;
    6)
      port=$(grep -oP '-p \K\S+' "$START_SCRIPT")
      echo "当前端口: ${port:-9000}"; read -n 1 -s -p "按 Enter 返回主菜单"; echo ;;
    7)
      server_address=$(grep -oP '-r \K\S+' "$START_SCRIPT")
      if [ -z "$server_address" ]; then
        echo "当前服务器地址: 默认"
        read -p "请输入新的服务器地址 (留空使用默认): " new_server_address
        run_root_command systemctl stop "$SERVICE_NAME"
        if [ -z "$new_server_address" ]; then
          sed -i "s/.*-r .*/./thread_socket -p \\"$port\\"/g" "$START_SCRIPT"
        else
          echo "修改 $START_SCRIPT 中的服务器地址为: $new_server_address"
          sed -i "s/.*-r .*/./thread_socket -p \\"$port\\" -r \\"$new_server_address\\"/g" "$START_SCRIPT"
        fi
        run_root_command systemctl start "$SERVICE_NAME"
      else
        echo "当前服务器地址: $server_address"
        read -p "请输入新的服务器地址 (留空使用默认): " new_server_address
        run_root_command systemctl stop "$SERVICE_NAME"
        if [ -z "$new_server_address" ]; then
          sed -i "s/.*-r .*/./thread_socket -p \\"$port\\"/g" "$START_SCRIPT"
        else
          echo "修改 $START_SCRIPT 中的服务器地址为: $new_server_address"
          sed -i "s/.*-r .*/./thread_socket -p \\"$port\\" -r \\"$new_server_address\\"/g" "$START_SCRIPT"
        fi
        run_root_command systemctl start "$SERVICE_NAME"
      fi
      read -n 1 -s -p "按 Enter 返回主菜单"; echo ;;
    8)
      read -p "请输入新的服务器地址 (留空使用默认): " new_server_address
      run_root_command systemctl stop "$SERVICE_NAME"
      if [ -z "$new_server_address" ]; then
        sed -i "s/.*-r .*/./thread_socket -p \\"$port\\"/g" "$START_SCRIPT"
      else
        echo "修改 $START_SCRIPT 中的服务器地址为: $new_server_address"
        sed -i "s/.*-r .*/./thread_socket -p \\"$port\\" -r \\"$new_server_address\\"/g" "$START_SCRIPT"
      fi
      run_root_command systemctl start "$SERVICE_NAME"
      read -n 1 -s -p "按 Enter 返回主菜单"; echo ;;
    q) exit 0 ;;
    *) echo "无效的选项，请重试。"; read -n 1 -s -p "按 Enter 返回主菜单"; echo ;;
  esac
  menu
}

menu
EOL
chmod +x lunch_proxy
echo "\n已创建 'lunch_proxy' 菜单。后续在终端中输入 './lunch_proxy' 即可打开菜单。"
./lunch_proxy
