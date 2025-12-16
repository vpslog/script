#!/usr/bin/env bash

set -e

echo "======================================"
echo "  Samba (SMB) 中文交互式配置脚本 v2"
echo "======================================"
echo

# 检测 root
if [[ $EUID -ne 0 ]]; then
   echo "❌ 请使用 root 或 sudo 运行该脚本"
   exit 1
fi

# 系统识别
if command -v apt >/dev/null 2>&1; then
  PKG_INSTALL="apt install -y"
  FIREWALL="ufw"
elif command -v dnf >/dev/null 2>&1; then
  PKG_INSTALL="dnf install -y"
  FIREWALL="firewalld"
else
  echo "❌ 不支持的系统"
  exit 1
fi

SMB_CONF="/etc/samba/smb.conf"

# 检查 Samba 是否已安装
if ! command -v smbd >/dev/null 2>&1; then
  echo "📦 安装 Samba..."
  $PKG_INSTALL samba samba-client >/dev/null
fi

# 函数定义

function check_existing_shares {
  echo "📊 现有 Samba 共享："
  testparm -s 2>/dev/null | grep -E '^\[' | sed 's/\[//' | sed 's/\]//' | while read share; do
    if [[ "$share" != "global" && "$share" != "printers" && "$share" != "print$" ]]; then
      echo "  - $share"
    fi
  done
}

function delete_share {
  read -rp "请输入要删除的共享名称: " SHARE_TO_DELETE
  if grep -q "^\[$SHARE_TO_DELETE\]" "$SMB_CONF"; then
    cp "$SMB_CONF" "${SMB_CONF}.bak.$(date +%F-%T)"
    sed -i "/^\[$SHARE_TO_DELETE\]/,/^$/d" "$SMB_CONF"
    systemctl restart smbd
    echo "✅ 共享 $SHARE_TO_DELETE 已删除"
  else
    echo "❌ 共享 $SHARE_TO_DELETE 不存在"
  fi
  exit 0
}

function check_status {
  echo
  echo "======================================"
  echo "📊 当前 Samba 连接状态:"
  echo "======================================"
  smbstatus | awk '
  BEGIN {print "用户\tIP\t打开的文件"}
  NR>1 {printf "%s\t%s\t%s\n", $1,$2,$5}'
  echo "======================================"
}

function add_samba_user {
  # 检查是否有 Samba 用户
  if pdbedit -L | grep -q .; then
    echo "🔑 现有 Samba 用户："
    pdbedit -L | awk -F: '{print "  - " $1}'
    echo
    read -rp "是否新增 Samba 用户？(y/n): " ADD_NEW
    if [[ ! "$ADD_NEW" =~ ^[Yy]$ ]]; then
      read -rp "请输入现有 Samba 用户名: " SMB_USER
      return
    fi
  fi

  # 新增流程
  echo "👥 现有 Linux 用户："
  cut -d: -f1 /etc/passwd | grep -v '^#' | while read user; do
    echo "  - $user"
  done

  echo
  echo "Smb 用户和 Linux 用户共享目录权限，但是密码可以不同。"
  read -rp "请输入允许访问的 Linux 用户名: " SMB_USER

  # 检查用户
  if ! id "$SMB_USER" >/dev/null 2>&1; then
    read -rp "👤 Linux 用户 $SMB_USER 不存在，是否创建？(y/n): " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      useradd "$SMB_USER"
      passwd "$SMB_USER"
    else
      exit 1
    fi
  fi

  # Samba 用户
  echo
  echo "🔑 设置 Samba 用户密码（与 Linux 密码无关）"
  smbpasswd -a "$SMB_USER"
}

function add_samba_share {
  # 读取配置
  read -rp "请输入共享名称（如 share）: " SHARE_NAME
  read -rp "请输入共享目录完整路径（如 /data/share，留空使用当前目录）: " SHARE_PATH
  if [[ -z "$SHARE_PATH" ]]; then
    SHARE_PATH="$(pwd)"
  fi

  # 创建目录
  if [[ ! -d "$SHARE_PATH" ]]; then
    echo "📁 创建共享目录 $SHARE_PATH"
    mkdir -p "$SHARE_PATH"
  fi

  # 备份配置
  cp "$SMB_CONF" "${SMB_CONF}.bak.$(date +%F-%T)"

  # 写入配置
  echo
  echo "✍️ 写入 Samba 配置"

  cat >>"$SMB_CONF" <<EOF

[$SHARE_NAME]
   path = $SHARE_PATH
   browseable = yes
   writable = yes
   valid users = $SMB_USER
   read only = no
EOF

  # 强制 SMB2 及以上
  if ! grep -q "server min protocol" "$SMB_CONF"; then
    sed -i '/^\[global\]/a server min protocol = SMB2' "$SMB_CONF"
  fi

  # 优化安全性
  if ! grep -q "restrict anonymous" "$SMB_CONF"; then
    sed -i '/^\[global\]/a restrict anonymous = 2' "$SMB_CONF"
  fi

  # 重启服务
  echo
  echo "🔄 重启 Samba 服务"
  systemctl restart smbd
  systemctl enable smbd

  # 防火墙
  read -rp "是否配置防火墙？(y/n): " SET_FIREWALL
  if [[ "$SET_FIREWALL" =~ ^[Yy]$ ]]; then
    echo "🔥 配置防火墙"
    if [[ "$FIREWALL" == "ufw" ]]; then
      ufw allow samba >/dev/null || true
    elif [[ "$FIREWALL" == "firewalld" ]]; then
      firewall-cmd --add-service=samba --permanent >/dev/null
      firewall-cmd --reload >/dev/null
    fi
  fi

  # 目录权限
  read -rp "是否配置共享目录权限？(y/n): " SET_PERMS
  if [[ "$SET_PERMS" =~ ^[Yy]$ ]]; then
    echo "🔐 设置共享目录权限为 755"
    chown -R "$SMB_USER":"$SMB_USER" "$SHARE_PATH"
    chmod -R 755 "$SHARE_PATH"
  fi

  # 完成提示
  IP_ADDR=$(hostname -I | awk '{print $1}')

  echo
  echo "======================================"
  echo "✅ Samba 配置完成！"
  echo
  echo "📂 共享名: $SHARE_NAME"
  echo "📁 目录: $SHARE_PATH"
  echo "👤 用户: $SMB_USER"
  echo
  echo "💻 Windows 访问方式:"
  echo "   \\\\$IP_ADDR\\$SHARE_NAME"
  echo
  echo "🐧 Linux 测试:"
  echo "   smbclient //$IP_ADDR/$SHARE_NAME -U $SMB_USER"
  echo
  echo "======================================"
}

# 主流程

check_existing_shares

EXISTING_SHARES=$(testparm -s 2>/dev/null | grep -E '^\[' | sed 's/\[//' | sed 's/\]//' | grep -v -E '^(global|printers|print\$)$' | wc -l)

echo
if [[ $EXISTING_SHARES -gt 0 ]]; then
  read -rp "请选择操作：1. 新增共享 2. 删除共享 3. 查看共享状态: " ACTION
  case $ACTION in
    1)
      add_samba_user
      add_samba_share
      ;;
    2)
      delete_share
      ;;
    3)
      check_status
      ;;
    *)
      echo "无效选择"
      exit 1
      ;;
  esac
else
  echo "没有现有共享，将新增共享。"
  add_samba_user
  add_samba_share
fi

