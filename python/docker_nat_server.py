import argparse
import docker
import random
import io

client = docker.from_env()

parser = argparse.ArgumentParser(description='Create multiple Docker containers with SSH access')
parser.add_argument('--num_containers', type=int, default=10, help='Number of containers to create')
parser.add_argument('--mem_limit', default='512m', help='Memory limit for each container in MB')
parser.add_argument('--cpu', type=float, default=0.5, help='CPU quota for each container, as a fraction of a core')
parser.add_argument('--ip_address', default='202.5.26.214', help='IP address to use')

args = parser.parse_args()

num_containers = args.num_containers
mem_limit = args.mem_limit
cpu_period = int(1e6)
cpu_quota = int(args.cpu * cpu_period)
ip_address = args.ip_address

ssh_port_base = 5000
other_ports_base = 10000

containers = []

# 构建新镜像
dockerfile = '''
FROM debian

RUN apt-get update \\
    && apt-get install -y openssh-server \\
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config \\
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \\
    && service ssh restart
    
CMD ["/usr/sbin/sshd", "-D"]
'''

new_image, logs = client.images.build(
    fileobj=io.BytesIO(dockerfile.encode('utf-8')),
    tag='my-ssh-image',
    rm=True,
)

for i in range(num_containers):
    password = ''.join(random.choices('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890', k=16))

    ssh_port = ssh_port_base + i
    ports = {
        '22/tcp': ssh_port,
        '80/tcp': other_ports_base,
        '443/tcp': other_ports_base+1,
        '8080/tcp': other_ports_base+2,
        '9090/tcp': other_ports_base+3,
    }
    other_ports_base += 4
    
    container = client.containers.run(
        'my-ssh-image',  # 使用新镜像
        detach=True,
        ports=ports,
        mem_limit=mem_limit,
        cpu_quota=cpu_quota,
        cpu_period=cpu_period,
    )

    command = f'''/bin/bash -c 'echo -e "{password}\\n{password}" | passwd root && echo "Password updated successfully"' '''
    response = container.exec_run(command)

    containers.append({
        'id': container.id,
        'name': container.name,
        'password': password,
        'port':ports
    })

for item in containers:
    print(f"地址 {ip_address}:{item['port']['22/tcp']} - 密码 {item['password']} - 端口 {';'.join([f'{key}:{value}' for key,value in item['port'].items() ]) }")