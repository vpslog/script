# script 一些一键部署脚本

## Caddy

Caddy 是一个现代化的 Web 服务器，支持自动 HTTPS 和反向代理等功能。

### 安装 Caddy

```
bash <(curl -s https://raw.githubusercontent.com/vpslog/script/main/caddy.sh) -i
```
这将自动安装 Caddy 并将其配置为使用默认设置。

### 配置反向代理

要将 Caddy 配置为反向代理，请使用以下命令：

```
bash <(curl -s https://raw.githubusercontent.com/vpslog/script/main/caddy.sh) -r <远程域名>:<本地端口> -e <TLS 邮箱>
```

例如，要将 Caddy 配置为反向代理到本地端口 5053 并使用 TLS，请运行以下命令：

```
bash <(curl -s https://raw.githubusercontent.com/vpslog/script/main/caddy.sh) -r example.vpslog.net:5053 -e admin@vpslog.net
```

这将自动将远程域名 example.vpslog.net 的流量重定向到本地端口 5053，并使用提供的 TLS 邮箱来自动为该域名签发证书。

### 编辑 Caddyfile

要编辑 Caddyfile，请使用以下命令：

```
bash <(curl -s https://raw.githubusercontent.com/vpslog/script/main/caddy.sh) -n
```

这将使用 Nano 编辑器打开 Caddyfile 文件，您可以在其中添加其他自定义反向代理规则。

注意事项
在运行脚本之前，请确保您的系统已经安装了 curl 和 sudo 工具。
脚本只能在 Debian 和 Ubuntu 系统上运行，其他 Linux 发行版可能不兼容。
在运行脚本之前，请确保您已经备份了重要的文件和数据，以避免意外数据丢失。


