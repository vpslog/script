#!/bin/bash

# 检查参数数量是否正确
if [ "$#" -ne 6 ]; then
    echo "用法: $0 <zone_id> <api_key> <email> <domain> <api_host> <api_key_for_host>"
    exit 1
fi

# 从脚本参数获取变量
zone_id=$1
api_key=$2
email=$3
domain=$4
api_host=$5
api_key_for_host=$6

# 1. 获取 IPv4 地址
ipv4=$(curl -4 ip.sb)
# 打印当前 IPv4 地址
echo "当前 IPv4 地址为: "
echo "${ipv4}"

# 打印完整域名
echo "完整域名为: "
echo "${subdomain}"

# 打印 WebSocket 配置
echo "WebSocket 配置:"
echo "{"
echo '  "path": "/",'
echo '  "header": {'
echo "    \"Host\": \"${subdomain}\""
echo '  }'
echo "}"

# 2. 请求用户输入 NodeID
read -p "请输入 NodeID: " node_id

# 3. 使用 Cloudflare API 添加或更新 DNS 记录
subdomain="${ipv4}.${domain}"

curl -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
     -H "Authorization: Bearer ${api_key}" \
     -H "Content-Type: application/json" \
     --data '{
        "type": "A",
        "name": "'"${subdomain}"'",
        "content": "'"${ipv4}"'",
        "ttl": 120,
        "proxied": false
     }'

# 4. 安装 XrayR
wget -N https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/install.sh && bash install.sh

# 5. 创建或重写 XrayR 配置文件
cat > /etc/XrayR/config.yml <<EOF
Log:
  Level: warning
  AccessPath: 
  ErrorPath: 
DnsConfigPath: 
RouteConfigPath: 
InboundConfigPath: 
OutboundConfigPath: 
ConnectionConfig:
  Handshake: 4
  ConnIdle: 30
  UplinkOnly: 2
  DownlinkOnly: 4
  BufferSize: 64
Nodes:
  - PanelType: "NewV2board"
    ApiConfig:
      ApiHost: "${api_host}"
      ApiKey: "${api_key_for_host}"
      NodeID: ${node_id}
      NodeType: V2ray
      Timeout: 30
      EnableVless: false
      VlessFlow: "xtls-rprx-vision"
      SpeedLimit: 0
      DeviceLimit: 0
      RuleListPath: 
      DisableCustomConfig: false
    ControllerConfig:
      ListenIP: 0.0.0.0
      SendIP: 0.0.0.0
      UpdatePeriodic: 60
      EnableDNS: false
      DNSType: AsIs
      EnableProxyProtocol: false
      AutoSpeedLimitConfig:
        Limit: 0
        WarnTimes: 0
        LimitSpeed: 0
        LimitDuration: 0
      GlobalDeviceLimitConfig:
        Enable: false
        RedisNetwork: tcp
        RedisAddr: 127.0.0.1:6379
        RedisUsername: 
        RedisPassword: YOUR_PASSWORD
        RedisDB: 0
        Timeout: 5
        Expiry: 60
      EnableFallback: false
      FallBackConfigs:
        - SNI: 
          Alpn: 
          Path: 
          Dest: 80
          ProxyProtocolVer: 0
      DisableLocalREALITYConfig: false
      EnableREALITY: false
      REALITYConfigs:
        Show: true
        Dest: www.amazon.com:443
        ProxyProtocolVer: 0
        ServerNames: 
          - www.amazon.com
        PrivateKey: YOUR_PRIVATE_KEY
        MinClientVer: 
        MaxClientVer: 
        MaxTimeDiff: 0
        ShortIds: 
          - ""
          - 0123456789abcdef
      CertConfig:
        CertMode: dns
        CertDomain: "${subdomain}"
        CertFile: /etc/XrayR/cert/node1.test.com.cert
        KeyFile: /etc/XrayR/cert/node1.test.com.key
        Provider: cloudflare
        Email: test@test.com
        DNSEnv: 
          CLOUDFLARE_EMAIL: ${email}
          CLOUDFLARE_API_KEY: ${api_key}
EOF

# 6. 启动 XrayR
xrayr start
