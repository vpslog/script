#!/bin/bash

# 检查参数数量是否正确
if [ "$#" -ne 8 ]; then
    echo "用法: $0 <zone_id> <api_key> <domain> <api_host> <api_key_for_host> <api_path> <api_email> <api_password>"
    exit 1
fi

# 从脚本参数获取变量
zone_id=$1
api_key=$2
domain=$3
api_host=$4
api_key_for_host=$5
api_path=$6
api_email=$7
api_password=$8

# 1. 获取 IPv4 地址
ipv4=$(curl -4 ip.sb)
# 打印当前 IPv4 地址
echo "当前 IPv4 地址为: "
echo "${ipv4}"

subdomain="${ipv4}.${domain}"

# 执行请求并获取响应
response=$(curl -s "${api_host}/api/v2/passport/auth/login" \
  -H 'accept: */*' \
  -H 'accept-language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6' \
  -H 'content-type: application/x-www-form-urlencoded' \
  -H 'cookie: dark_mode=0' \
  -H "origin: ${api_host}" \
  -H 'priority: u=1, i' \
  -H "referer: ${api_host}/${api_path}" \
  -H 'sec-ch-ua: "Chromium";v="130", "Microsoft Edge";v="130", "Not?A_Brand";v="99"' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'sec-ch-ua-platform: "Windows"' \
  -H 'sec-fetch-dest: empty' \
  -H 'sec-fetch-mode: cors' \
  -H 'sec-fetch-site: same-origin' \
  -H 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0' \
  --data-raw "email=${api_email}&password=${api_password}")

# 提取 auth_data 并存储到 jwt 变量
jwt=$(echo "$response" | grep -o '"auth_data":"[^"]*' | sed 's/"auth_data":"//')

# 添加节点
curl "${api_host}/api/v2/${api_path}/server/vmess/save" \
  -H 'accept: */*' \
  -H 'accept-language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6' \
  -H "authorization: ${jwt}" \
  -H 'content-type: application/x-www-form-urlencoded' \
  -H 'cookie: dark_mode=0' \
  -H "origin: ${api_host}" \
  -H 'priority: u=1, i' \
  -H "referer: ${api_host}/${api_path}" \
  -H 'sec-ch-ua: "Chromium";v="130", "Microsoft Edge";v="130", "Not?A_Brand";v="99"' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'sec-ch-ua-platform: "Windows"' \
  -H 'sec-fetch-dest: empty' \
  -H 'sec-fetch-mode: cors' \
  -H 'sec-fetch-site: same-origin' \
  -H 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0' \
  --data-raw "tls=1&rate=1&name=${ipv4}&host=${subdomain}&port=4444&server_port=4444&network=ws&networkSettings[path]=%2F&networkSettings[header][Host]=${subdomain}&group_id[0]=1&ips[0]=${ipv4}&dnsSettings="

# 执行请求并获取最后一个项的 id
node_id=$(curl -s "${api_host}/api/v2/${api_path}/server/manage/getNodes" \
  -H 'accept: */*' \
  -H 'accept-language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6' \
  -H "authorization: ${jwt}" \
  -H 'cookie: dark_mode=0' \
  -H 'priority: u=1, i' \
  -H "referer: ${api_host}/${api_path}" \
  -H 'sec-ch-ua: "Chromium";v="130", "Microsoft Edge";v="130", "Not?A_Brand";v="99"' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'sec-ch-ua-platform: "Windows"' \
  -H 'sec-fetch-dest: empty' \
  -H 'sec-fetch-mode: cors' \
  -H 'sec-fetch-site: same-origin' \
  -H 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0' \
  | grep -o '"id":[0-9]*' | tail -n 1 | sed 's/"id"://')


# 3. 使用 Cloudflare API 添加或更新 DNS 记录
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
  ConnIdle: 3000
  UplinkOnly: 20
  DownlinkOnly: 40
  BufferSize: 64
Nodes:
  - PanelType: "NewV2board"
    ApiConfig:
      ApiHost: "${api_host}"
      ApiKey: "${api_key_for_host}"
      NodeID: ${node_id}
      NodeType: V2ray
      Timeout: 30
      EnableVless: true
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
      DisableLocalREALITYConfig: true
      CertConfig:
        CertMode: dns
        CertDomain: "${subdomain}"
        CertFile: /etc/XrayR/cert/node1.test.com.cert
        KeyFile: /etc/XrayR/cert/node1.test.com.key
        Provider: cloudflare
        Email: test@test.com
        DNSEnv: 
          CF_DNS_API_TOKEN: ${api_key}
EOF

# 6. 启动 XrayR
xrayr start
