#!/bin/bash

BLUE='\033[1;34m'
NC='\033[0m'
DELAY=0.1


run_command() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

display_banner() {
    cat << "EOF"
**********************************************
* *
* 🚀 Welcome to Lunch Proxy Installer 🚀  *
* *
* *
**********************************************
EOF
    echo
}
clear
display_banner

echo -e "\n⏳ 安装程序即将启动，按住 Ctrl + C 以取消..."
sleep 5
clear

echo "🔍 检查是否已安装 cn_http_proxy 服务..."
if systemctl is-enabled cn_http_proxy --quiet && systemctl is-active cn_http_proxy --quiet; then
  echo "✅ cn_http_proxy 服务已安装并运行。"
  sleep 1
  installed=true
else
  echo "ℹ️ 未发现 cn_http_proxy 服务。"
  sleep 0.5
  installed=false
fi

if [ "$installed" = "false" ]; then

  echo -e "\n📁 创建目录 /etc/lunchkit 和 /etc/lunchkit/cn_http_proxy ..."
  run_command mkdir -p /etc/lunchkit/cn_http_proxy
  sleep 0.5

  echo "📦 解压 lunch_proxy.zip 到 /etc/lunchkit/cn_http_proxy ..."
  sleep 0.5
  if [ -f "lunch_proxy.zip" ]; then

    run_command unzip -o lunch_proxy.zip -d temp_lunch_dir
    run_command cp -r temp_lunch_dir/lunch_cn_proxy-main/* /etc/lunchkit/cn_http_proxy/
    rm -rf temp_lunch_dir

    echo "🗑️ 删除 lunch_proxy.zip ..."
    sleep 0.5
    rm -f lunch_proxy.zip
  else
    echo "❌ 错误: 当前目录下找不到 lunch_proxy.zip 文件，请确保该文件存在。"
    exit 1
  fi

  cd /etc/lunchkit/cn_http_proxy
  echo -e "\n↪️ 切换工作目录到 /etc/lunchkit/cn_http_proxy"
  sleep 0.25
  echo "🛠️ 检查是否安装 clang ..."
  sleep 0.25
  if ! command -v clang &> /dev/null; then
    echo "⚙️ clang 未安装，尝试安装 ..."
    run_command apt update
    run_command apt install clang -y
  else
    echo "✅ clang 已安装。"
    sleep 0.25
  fi

  echo "🛠️ 检查是否安装 make ..."
  if ! command -v make &> /dev/null; then
    echo "⚙️ make 未安装，尝试安装 ..."
    run_command apt update
    run_command apt install make -y
  else
    echo "✅ make 已安装。"
  fi

  echo -e "\n⚙️ 即将开始编译 ..."
  sleep 0.5
  make
  if [ $? -eq 0 ]; then
    echo "✅ 编译结束。"
  else
    echo "❌ 编译过程中发生错误，请检查错误信息。"
    exit 1
  fi

  echo -e "\n🌐 请选择服务器地址:\n1) 默认\n2) 自定义"
  read -p "👉 请选择 (1 或 2): " server_choice
  server_address=""
  case "$server_choice" in
    1)
      echo "🔩 使用默认服务器地址。"
      ;;
    2)
      read -p "📝 请输入自定义服务器地址: " server_address
      ;;
    *)
      echo "⚠️ 无效的选择，使用默认服务器地址。"
      sleep 0.25
      ;;
  esac

  echo -e "\n🔌 请选择 HTTP 代理端口:\n1) 默认 (9000)\n2) 自定义"

  read -p "👉 请选择 (1 或 2): " port_choice
  if [[ "$port_choice" == "1" ]]; then
    port="9000"
    echo "🔩 使用默认端口 9000。"
  elif [[ "$port_choice" == "2" ]]; then
    read -p "📝 请输入新的端口 (纯数字): " custom_port
    if [[ "$custom_port" =~ ^[0-9]+$ ]]; then
        port="$custom_port"
        echo "🔧 端口设置为: $port"
    else
        echo "⚠️ 无效的端口，使用默认端口 9000。"
        port="9000"
    fi
  elif [[ -z "$port_choice" ]]; then
    port="9000"
    echo "🔩 使用默认端口 9000。"
  elif [[ ! "$port_choice" =~ ^[0-9]+$ && "$port_choice" != "1" && "$port_choice" != "2" ]]; then
    if [[ "$port_choice" =~ ^[0-9]+$ ]]; then
        port="$port_choice"
        echo "🔧 端口设置为: $port"
    else
        echo "⚠️ 无效的选择或端口，使用默认端口 9000。"
        port="9000"
    fi
  fi


  echo -e "\n📜 创建 启动脚本：start.sh ..."
  sleep 0.25
  echo "#!/bin/bash" > start.sh
  if [ -z "$server_address" ]; then
    echo "./thread_socket -p $port" >> start.sh
  else
    echo "./thread_socket -p $port -r $server_address" >> start.sh
  fi
  chmod +x start.sh


  echo "⚙️ 创建 systemd 服务 cn_http_proxy ..."
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

  echo "🚀 启动 cn_http_proxy 服务 ..."
  run_command systemctl enable cn_http_proxy
  run_command systemctl start cn_http_proxy
  run_command systemctl status cn_http_proxy
fi

cat > lunch_proxy <<'EOL'
#!/bin/bash

SERVICE_NAME="cn_http_proxy"
START_SCRIPT="/etc/lunchkit/cn_http_proxy/start.sh"
PROXY_DIR="/etc/lunchkit/cn_http_proxy"


run_root_command() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

menu() {
  echo "-------------------- 🛠️ Lunch CN Proxy 菜单 🛠️ --------------------"
  echo "(1) 服务信息"
  echo "(2) 启动服务"
  echo "(3) 重启服务"
  echo "(4) 停止服务"
  echo "(5) 卸载服务"
  echo "(6) 查看当前端口"
  echo "(7) 修改服务器端口"
  echo "(8) 修改服务器地址"
  echo "(q) 退出"
  echo "---------------------------------------------------------"
  choice=""
  read -p "👉 请选择: " choice
  echo "⌨️ 您输入的字符是: '$choice'"
  choice=$(echo "$choice" | tr -d '[:space:]')

  case "$choice" in
    1) systemctl status "$SERVICE_NAME"; read -n 1 -s -r -p "按 Enter 返回主菜单"; echo ;;
    2) run_root_command systemctl start "$SERVICE_NAME"; echo "✅ 服务已启动。"; read -n 1 -s -r -p "按 Enter 返回主菜单"; echo ;;
    3) run_root_command systemctl restart "$SERVICE_NAME"; echo "✅ 服务已重启。"; read -n 1 -s -r -p "按 Enter 返回主菜单"; echo ;;
    4) run_root_command systemctl stop "$SERVICE_NAME"; echo "✅ 服务已停止。"; read -n 1 -s -r -p "按 Enter 返回主菜单"; echo ;;
    5)
      echo -e "🗑️  准备卸载服务..."
      read -p "❓ 您确定要卸载服务吗? 这将删除所有相关文件。[y/N]: " confirm_uninstall
      if [[ "$confirm_uninstall" =~ ^[Yy]$ ]]; then
        echo -e "⏹️ 停止 $SERVICE_NAME 服务..."
        run_root_command systemctl stop "$SERVICE_NAME"
        echo "🚫 禁用 $SERVICE_NAME 服务..."
        run_root_command systemctl disable "$SERVICE_NAME"
        echo "🗑️ 删除 $SERVICE_NAME 服务文件..."
        run_root_command rm -f /etc/systemd/system/"$SERVICE_NAME".service
        echo "🗑️ 删除 $PROXY_DIR 目录..."
        run_root_command rm -rf "$PROXY_DIR"
        echo "🗑️ 删除 lunch_proxy 菜单..."
        run_root_command rm -f "$0"
        if [ -f "/usr/local/bin/lunch_proxy" ]; then # Check if the symlink/copy exists
            run_root_command rm -f /usr/local/bin/lunch_proxy
        fi
        echo "✅ 卸载完成。"
        exit 0
      else
        echo "🚫 卸载已取消。"
      fi
      read -n 1 -s -r -p "按 Enter 返回主菜单"; echo
      ;;
    6)
      current_config=$(cat "$START_SCRIPT")
      port_val=$(echo "$current_config" | grep -oP '(?<=-p )\d+' | head -n 1) # More robust port extraction
      echo "🔌 当前端口: ${port_val:-9000}"
      read -n 1 -s -r -p "按 Enter 返回主菜单"; echo
      ;;
    7)
      current_config_line=$(grep "^\./thread_socket" "$START_SCRIPT" | head -n 1)
      current_port_val=$(echo "$current_config_line" | grep -oP '(?<=-p )\d+' | head -n 1)
      # 提取当前的 "-r server_address" 部分 (如果存在)，注意包含前导空格
      current_server_address_param=$(echo "$current_config_line" | grep -oP ' -r \S+' || echo "")

      echo "🔌 当前端口: ${current_port_val:-9000}"
      read -p "📝 请输入新的端口 (纯数字, 留空使用默认 9000): " new_port

      if [[ -z "$new_port" ]]; then
        new_port="9000"
        echo "🔩 使用默认端口 9000。"
      elif [[ ! "$new_port" =~ ^[0-9]+$ ]]; then
        echo "⚠️ 无效的端口，使用默认端口 9000。"
        new_port="9000"
      fi

      run_root_command systemctl stop "$SERVICE_NAME"
      # 重建命令: ./thread_socket -p <新端口><可选的服务器地址部分>
      # $current_server_address_param 如果有值，会自带前导空格
      sed -i "s|^\./thread_socket.*|./thread_socket -p $new_port${current_server_address_param}|" "$START_SCRIPT"
      echo "✅ 端口已修改为: $new_port"

      if ! grep -q "^#!/bin/bash" "$START_SCRIPT"; then
        sed -i '1s|^|#!/bin/bash\n|' "$START_SCRIPT"
      fi
      chmod +x "$START_SCRIPT"
      run_root_command systemctl start "$SERVICE_NAME"
      read -n 1 -s -r -p "按 Enter 返回主菜单"; echo ;;
    8)
      # 从 start.sh 中获取当前实际的命令行
      current_config_line=$(grep "^\./thread_socket" "$START_SCRIPT" | head -n 1)
      # 从这行命令中提取当前的端口号
      current_port_val_for_addr_change=$(echo "$current_config_line" | grep -oP '(?<=-p )\d+' | head -n 1)
      # 从这行命令中提取当前的服务器地址 (如果存在)
      current_server_address=$(echo "$current_config_line" | grep -oP '(?<=-r )\S+' || echo "无")

      echo "🌐 当前服务器地址: ${current_server_address}"
      read -p "📝 请输入新的服务器地址 (留空则不使用远程服务器): " new_server_address
      run_root_command systemctl stop "$SERVICE_NAME"

      if [ -z "$new_server_address" ]; then
        # 如果新地址为空，则移除 -r 参数，只保留 -p <端口>
        sed -i "s|^\./thread_socket -p ${current_port_val_for_addr_change}.*|./thread_socket -p ${current_port_val_for_addr_change}|" "$START_SCRIPT"
        echo "🔩 服务器地址已移除 (使用本地代理)。"
      else
        # 如果新地址不为空，则设置为 -p <端口> -r <新地址>
        sed -i "s|^\./thread_socket -p ${current_port_val_for_addr_change}.*|./thread_socket -p ${current_port_val_for_addr_change} -r ${new_server_address}|" "$START_SCRIPT"
        echo "✅ 服务器地址已修改为: $new_server_address"
      fi
      # （可选但推荐）确保 shebang 存在并且脚本可执行
      if ! grep -q "^#!/bin/bash" "$START_SCRIPT"; then
        sed -i '1s|^|#!/bin/bash\n|' "$START_SCRIPT"
      fi
      chmod +x "$START_SCRIPT"
      run_root_command systemctl start "$SERVICE_NAME"
      read -n 1 -s -r -p "按 Enter 返回主菜单"; echo ;;
    q) exit 0 ;;
    *) echo "❌ 无效的选项，请重试。"; read -n 1 -s -r -p "按 Enter 返回主菜单"; echo ;;
  esac
  menu # Call menu again, ensure it's outside case for some options like exit
}

menu
EOL
chmod +x lunch_proxy
sudo mv lunch_proxy /usr/local/bin/lunch_proxy
sudo chmod +x /usr/local/bin/lunch_proxy
echo -e "\n✅ 已创建 'lunch_proxy' 菜单；后续在终端中输入 'lunch_proxy' 即可打开菜单。🚀"
sleep 0.5
lunch_proxy
