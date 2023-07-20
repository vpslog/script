#!/bin/bash

if ! command -v docker &> /dev/null
then
    # 安装 Docker
    curl -sSL https://get.docker.com/ | sh
fi

# 安装 Python 依赖项
sudo apt-get update
sudo apt-get install -y python3-pip
pip3 install docker argparse

# 运行 docker_nat_server.py 脚本
wget https://raw.githubusercontent.com/vpslog/script/main/python/docker_nat_server.py
python3 docker_nat_server.py "$@"