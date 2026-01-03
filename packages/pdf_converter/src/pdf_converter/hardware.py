"""Detecção de hardware (GPU, CPU, ambiente)."""
import os, subprocess
from dataclasses import dataclass

@dataclass
class InfoHardware:
    tem_gpu: bool
    nome_gpu: str
    memoria_gpu_gb: float
    num_cpus: int
    ambiente: str

def detectar_hardware() -> InfoHardware:
    ambiente = "local"
    if os.path.exists("/content"): ambiente = "colab"
    elif os.environ.get("CODESPACES"): ambiente = "codespaces"
    elif os.environ.get("GITPOD_WORKSPACE_ID"): ambiente = "gitpod"

    tem_gpu, nome_gpu, memoria_gpu = False, "", 0.0
    try:
        import torch
        if torch.cuda.is_available():
            tem_gpu, nome_gpu = True, torch.cuda.get_device_name(0)
            memoria_gpu = torch.cuda.get_device_properties(0).total_memory / (1024**3)
    except ImportError: pass

    if not tem_gpu:
        try:
            r = subprocess.run(["nvidia-smi", "--query-gpu=name,memory.total", "--format=csv,noheader"],
                               capture_output=True, text=True, timeout=5)
            if r.returncode == 0:
                parts = r.stdout.strip().split(",")
                if len(parts) >= 2:
                    tem_gpu, nome_gpu = True, parts[0].strip()
                    memoria_gpu = float(parts[1].strip().replace(" MiB", "")) / 1024
        except: pass

    return InfoHardware(tem_gpu, nome_gpu, memoria_gpu, os.cpu_count() or 1, ambiente)
