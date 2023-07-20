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

# 运行 create_ssh_containers.py 脚本
python3 docker1.py "$@"