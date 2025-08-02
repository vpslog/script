#!/bin/bash

# 禁用 IPv6 内核模块
echo "options ipv6 disable=1" | sudo tee /etc/modprobe.d/disable-ipv6.conf

# 更新 sysctl 配置
echo "# 禁用 IPv6" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.all.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.lo.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf

# 应用 sysctl 配置更改
sudo sysctl -p

# 阻止 IPv6 内核模块加载
sudo depmod -a
