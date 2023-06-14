#!/bin/bash

# 解析命令行选项
while getopts ":ie:nr:" opt; do
  case ${opt} in
    i )
      INSTALL_CADDY=true
      ;;
    n )
      EDIT_CADDYFILE=true
      ;;
    r )
      REMOTE_DOMAIN=$(echo "${OPTARG}" | cut -d":" -f1)
      LOCAL_PORT=$(echo "${OPTARG}" | cut -d":" -f2)
      ;;
    e )
      TLS_EMAIL="${OPTARG}"
      ;;
    \? )
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    : )
      echo "Invalid option: -$OPTARG requires an argument" >&2
      exit 1
      ;;
  esac
done

# 打印参数并请求确认
echo "Parameters:"
echo "Install Caddy: $INSTALL_CADDY"
echo "Edit Caddyfile: $EDIT_CADDYFILE"
echo "Remote Domain: $REMOTE_DOMAIN"
echo "Local Port: $LOCAL_PORT"
echo "TLS Email: $TLS_EMAIL"

read -p "Are these parameters correct? [y/n] " 


if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Aborted."
    exit 1
fi
# 检查是否需要安装 Caddy
if [ "$INSTALL_CADDY" = true ]; then
  if dpkg -s caddy >/dev/null 2>&1; then
    echo "Caddy is already installed on this system."
  else
    # 安装 Caddy
    echo "Installing Caddy..."
    sudo apt update && sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg2
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    sudo apt update && sudo apt install -y caddy

    # 检查安装是否成功
    if dpkg -s caddy >/dev/null 2>&1; then
      # 输出安装成功消息
      echo -e "\033[32mCaddy has been installed successfully.\033[0m"
    else
      # 输出安装失败消息并退出
      echo -e "\033[31mFailed to install Caddy.\033[0m"
      exit 1
    fi
  fi
fi

if [ "$EDIT_CADDYFILE" = true ]; then
  # 使用 Nano 编辑 Caddyfile 文件
  sudo nano /etc/caddy/Caddyfile
fi

# 添加反向代理规则
if [ ! -z "$REMOTE_DOMAIN" ] && [ ! -z "$LOCAL_PORT" ]; then
  if [ ! -z "$TLS_EMAIL" ]; then
    # 检查 Caddyfile 中是否已存在同名的域名，如果存在则删除该行
    sudo sed -i "/$REMOTE_DOMAIN/d" /etc/caddy/Caddyfile

    # 将带有 HTTPS/TLS 的反向代理规则添加到 Caddyfile 文件末尾
    echo "$REMOTE_DOMAIN {
      reverse_proxy localhost:$LOCAL_PORT
      tls $TLS_EMAIL
    }" | sudo tee -a /etc/caddy/Caddyfile > /dev/null

    # 输出反向代理添加成功消息
    echo -e "\033[32mReverse proxy for $REMOTE_DOMAIN has been added successfully.\033[0m"
  else
    # 检查 Caddyfile 中是否已存在同名的域名，如果存在则删除该行
    sudo sed -i "/$REMOTE_DOMAIN/d" /etc/caddy/Caddyfile

    # 将不带 HTTPS/TLS 的反向代理规则添加到 Caddyfile 文件末尾
    echo "$REMOTE_DOMAIN {
      reverse_proxy localhost:$LOCAL_PORT
    }" | sudo tee -a /etc/caddy/Caddyfile > /dev/null

    # 输出反向代理添加成功消息
    echo -e "\033[32mReverse proxy for $REMOTE_DOMAIN has been added successfully.\033[0m"
  fi
fi

# 重启 Caddy 服务使其生效
echo "Restarting Caddy service..."
sudo systemctl restart caddy

# 检查服务是否正常运行
if ! systemctl is-active --quiet caddy.service; then
  # 输出服务启动失败的消息并退出
  echo -e "\033[31mFailed to start Caddy service.\033[0m"
  exit 1

# 输出完成消息
echo -e "\033[32mAll tasks have been completed.\033[0m"
