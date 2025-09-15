Deploy vLLM on RunPod (L4/A10G)
===============================

Overview
- RunPod offers on-demand NVIDIA GPU instances. We will provision a GPU VM, install Docker + NVIDIA Container Toolkit, and run vLLM with API key and optional TLS via Caddy.

Prerequisites
- RunPod account and billing enabled
- Chosen GPU: A10G 24GB or L4 24GB (recommended for 7B/8B)
- Ubuntu 22.04 image (suggested)
- DNS A-record ready if using TLS (e.g., llm.example.com → VM IP)

1) Launch a GPU Instance
- Select a community template with Ubuntu 22.04 (or Base OS) and your GPU
- Ensure the VM has at least 50GB disk for HF cache
- Open ports: 22 (SSH), 8000 (dev), 80/443 (if TLS via Caddy)

2) SSH and System Prep
```
ssh ubuntu@<VM_IP>
sudo apt-get update -y
sudo apt-get upgrade -y
```

3) Install Docker and NVIDIA Container Toolkit (Ubuntu 22.04)
Option A: use provided script
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
```
Verify:
```
nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
```

4) Clone repo and set env
```
git clone https://github.com/aborisd/sekretar.git
cd sekretar/server
cp .env.sample .env
echo "API_KEY=$(openssl rand -hex 32)" | tee -a .env
sed -n '1,200p' .env
```
Set MODEL if needed (default: mistralai/Mistral-7B-Instruct-v0.2).

5) Start vLLM (dev, no TLS)
```
docker compose up -d
BASE_URL=http://<VM_IP>:8000 API_KEY=$(grep ^API_KEY .env | cut -d= -f2) ./scripts/test.sh
```

6) Optional: TLS via Caddy
- Create DNS A record: llm.example.com → VM IP
```
cd secure
cp .env.sample .env
vi .env    # set DOMAIN, ACME_EMAIL, API_KEY, MODEL
docker compose -f docker-compose.caddy.yml --env-file .env up -d
```
Test:
```
curl -H "Authorization: Bearer $(grep ^API_KEY .env | cut -d= -f2)" https://$DOMAIN/v1/models
```

7) Hardening
- Restrict inbound to 80/443 (if TLS) or 8000 (dev)
- Enforce API key (already enabled), rotate quarterly
- No content logging; only metadata

8) Connect iOS app
- Info.plist:
  - REMOTE_LLM_BASE_URL = http://<VM_IP>:8000 (or https://$DOMAIN)
  - REMOTE_LLM_MODEL = mistralai/Mistral-7B-Instruct-v0.2
  - REMOTE_LLM_API_KEY = (from .env)
- Set provider: UserDefaults.standard.set("remote", forKey: "ai_provider")

