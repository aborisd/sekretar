Deploy vLLM on AWS (G5 A10G)
============================

Overview
- We’ll launch an EC2 g5.xlarge (A10G 24GB), install drivers + Docker + NVIDIA toolkit, run vLLM with API key, and (optionally) use Caddy TLS.

1) Launch EC2 Instance
- AMI: Ubuntu 22.04 LTS
- Type: g5.xlarge (1× A10G)
- Storage: 100GB gp3
- Security Group: allow TCP 22, 80, 443 (and 8000 for dev)

2) Install NVIDIA Drivers
```
sudo apt-get update -y
sudo apt-get install -y build-essential dkms
wget https://us.download.nvidia.com/tesla/535.183.01/NVIDIA-Linux-x86_64-535.183.01.run
chmod +x NVIDIA-Linux-*.run
sudo ./NVIDIA-Linux-*.run --silent
nvidia-smi
```

3) Install Docker + NVIDIA Container Toolkit
```
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -fsSL https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update -y
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
```

4) Deploy vLLM
```
git clone https://github.com/aborisd/sekretar.git
cd sekretar/server
cp .env.sample .env
echo "API_KEY=$(openssl rand -hex 32)" | tee -a .env
docker compose up -d
```
Test:
```
BASE_URL=http://<EC2_PUBLIC_IP>:8000 API_KEY=$(grep ^API_KEY .env | cut -d= -f2) ./scripts/test.sh
```

5) TLS (optional)
- Same steps as other guides: use Caddy with DNS A record.

6) Harden
- Security Group: restrict to 80/443 (unless dev), add your IP allow-list if needed
- Rotate API key; no content logs

7) iOS Connection
- As in RunPod guide: set Info.plist and provider=remote

