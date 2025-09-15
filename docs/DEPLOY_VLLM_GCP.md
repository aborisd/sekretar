Deploy vLLM on GCP (L4)
=======================

Overview
- We’ll create a GCE VM with L4 24GB GPU, install NVIDIA drivers + Docker + NVIDIA Container Toolkit, deploy vLLM with API key, and (optionally) front with Caddy TLS.

1) Create VM Instance (GCE)
- Machine: n1-standard-8 (or similar)
- GPU: 1x L4 (compute capability 8.9)
- Disk: 100GB SSD
- OS: Ubuntu 22.04 LTS
- Firewall: allow TCP 22, 80, 443 (and 8000 for dev)

2) Install Drivers (using GCP-provided drivers)
SSH to VM:
```
sudo apt-get update -y
sudo apt-get install -y build-essential
sudo /opt/google/bin/install_gpu_driver
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
BASE_URL=http://<VM_IP>:8000 API_KEY=$(grep ^API_KEY .env | cut -d= -f2) ./scripts/test.sh
```

5) TLS with Caddy (optional)
```
cd secure
cp .env.sample .env
# set DOMAIN (DNS A record to VM IP) and ACME_EMAIL
docker compose -f docker-compose.caddy.yml --env-file .env up -d
```

6) Harden
- VPC firewall: allow 80/443 only (unless dev)
- Rotate API key quarterly
- No content logs; only metadata

7) iOS Connection
- As in RunPod guide: set Info.plist and provider=remote

