#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# Setup PDF Converter - Workspace UV para Datamaster
# Execute: bash setup_pdf_converter.sh
# ══════════════════════════════════════════════════════════════════════════════

set -e
cd /workspaces/Datamaster

echo "📦 Criando estrutura de diretórios..."
mkdir -p packages/pdf_converter/src/pdf_converter
mkdir -p diversos/PDFs/arquivos_portal/saidas
mkdir -p notebooks

# ══════════════════════════════════════════════════════════════════════════════
# pyproject.toml ROOT (workspace)
# ══════════════════════════════════════════════════════════════════════════════
echo "📝 Criando pyproject.toml root..."
cat > pyproject.toml << 'ROOTEOF'
[project]
name = "datamaster"
version = "0.1.0"
description = "Ambiente de estudos: Backend Python, Data Engineering, Data Science"
readme = "README.md"
requires-python = ">=3.12"
dependencies = [
    "pandas>=2.0",
    "numpy>=2.0",
]

[project.optional-dependencies]
pdf = ["pdf-converter"]

[dependency-groups]
dev = [
    "marimo>=0.9",
    "pytest>=8.0",
    "ruff>=0.8",
]

[tool.uv.sources]
pdf-converter = { workspace = true }

[tool.uv.workspace]
members = ["packages/*"]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
ROOTEOF

# ══════════════════════════════════════════════════════════════════════════════
# pyproject.toml do subpacote pdf_converter
# ══════════════════════════════════════════════════════════════════════════════
echo "📝 Criando pyproject.toml do pdf-converter..."
cat > packages/pdf_converter/pyproject.toml << 'PKGEOF'
[project]
name = "pdf-converter"
version = "0.1.0"
description = "Conversor de PDF para Markdown usando Docling"
requires-python = ">=3.12"
dependencies = [
    "docling>=2.0",
    "docling-core>=2.0",
    "rich>=13.0",
    "pymupdf>=1.24",
]

[project.optional-dependencies]
gpu = ["torch>=2.0"]

[project.scripts]
pdf2md = "pdf_converter.cli:main"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/pdf_converter"]
PKGEOF

# ══════════════════════════════════════════════════════════════════════════════
# __init__.py
# ══════════════════════════════════════════════════════════════════════════════
echo "🐍 Criando módulos Python..."
cat > packages/pdf_converter/src/pdf_converter/__init__.py << 'EOF'
"""PDF Converter - Extração de PDF para Markdown com Docling."""
from pdf_converter.config import Config
from pdf_converter.converter import converter_pdf, processar_lote
__version__ = "0.1.0"
__all__ = ["Config", "converter_pdf", "processar_lote"]
EOF

# ══════════════════════════════════════════════════════════════════════════════
# config.py
# ══════════════════════════════════════════════════════════════════════════════
cat > packages/pdf_converter/src/pdf_converter/config.py << 'EOF'
"""Configurações centralizadas do PDF Converter."""
from dataclasses import dataclass, field
from pathlib import Path

@dataclass
class Config:
    dir_entrada: Path = field(default_factory=lambda: Path("diversos/PDFs/arquivos_portal/pdfs"))
    dir_saida: Path = field(default_factory=lambda: Path("diversos/PDFs/arquivos_portal/saidas"))
    copiar_pdf_original: bool = True
    habilitar_ocr: bool = True
    escala_imagens: float = 2.0
    max_workers_gpu: int = 2
    max_workers_cpu: int = 1
    limite_paginas_leve: int = 30
    limite_paginas_medio: int = 100
    limite_mb_leve: float = 5.0
    limite_mb_medio: float = 20.0
    razao_img_alta: float = 0.5
    marcador_completo: str = "<!-- CONVERSAO_COMPLETA -->"

    def __post_init__(self):
        if isinstance(self.dir_entrada, str): self.dir_entrada = Path(self.dir_entrada)
        if isinstance(self.dir_saida, str): self.dir_saida = Path(self.dir_saida)

    @classmethod
    def para_codespaces(cls) -> "Config":
        return cls(
            dir_entrada=Path("/workspaces/Datamaster/diversos/PDFs/arquivos_portal/pdfs"),
            dir_saida=Path("/workspaces/Datamaster/diversos/PDFs/arquivos_portal/saidas"),
        )

    @classmethod
    def para_colab(cls) -> "Config":
        return cls(
            dir_entrada=Path("/content/drive/MyDrive/AREAS/WIZARD/WIZ.TOOLS/Wizped/arquivos_portal/pdfs"),
            dir_saida=Path("/content/drive/MyDrive/AREAS/WIZARD/WIZ.TOOLS/Wizped/arquivos_portal/saidas"),
        )
EOF

# ══════════════════════════════════════════════════════════════════════════════
# hardware.py
# ══════════════════════════════════════════════════════════════════════════════
cat > packages/pdf_converter/src/pdf_converter/hardware.py << 'EOF'
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
EOF

# ══════════════════════════════════════════════════════════════════════════════
# analyzer.py
# ══════════════════════════════════════════════════════════════════════════════
cat > packages/pdf_converter/src/pdf_converter/analyzer.py << 'EOF'
"""Análise de PDFs (metadados, complexidade, status)."""
import hashlib
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import List
from pdf_converter.config import Config

class Complexidade(Enum):
    LEVE = "leve"
    MEDIO = "medio"
    PESADO = "pesado"

class StatusConversao(Enum):
    PENDENTE = "pendente"
    INCOMPLETO = "incompleto"
    COMPLETO = "completo"
    ERRO = "erro"

@dataclass
class InfoPDF:
    caminho: Path
    nome: str
    tamanho_mb: float
    num_paginas: int
    num_imagens: int
    complexidade: Complexidade
    status: StatusConversao
    tempo_estimado: float = 0.0
    hash_arquivo: str = ""

def calcular_hash(caminho: Path, amostra: int = 65536) -> str:
    hasher = hashlib.md5()
    with open(caminho, 'rb') as f:
        hasher.update(f.read(amostra))
        f.seek(0, 2)
        hasher.update(str(f.tell()).encode())
    return hasher.hexdigest()[:12]

def verificar_status(nome: str, dir_saida: Path, cfg: Config) -> StatusConversao:
    pasta = dir_saida / nome
    if not pasta.exists(): return StatusConversao.PENDENTE
    arquivo_md = pasta / f"{nome}.md"
    if not arquivo_md.exists(): return StatusConversao.INCOMPLETO
    try:
        with open(arquivo_md, 'r', encoding='utf-8') as f:
            if cfg.marcador_completo in f.read(): return StatusConversao.COMPLETO
    except: pass
    return StatusConversao.INCOMPLETO

def calcular_complexidade(tam: float, pags: int, imgs: int, cfg: Config) -> Complexidade:
    pts = 0
    if tam > cfg.limite_mb_medio: pts += 2
    elif tam > cfg.limite_mb_leve: pts += 1
    if pags > cfg.limite_paginas_medio: pts += 2
    elif pags > cfg.limite_paginas_leve: pts += 1
    if pags > 0:
        if imgs/pags > cfg.razao_img_alta: pts += 2
        elif imgs/pags > 0.2: pts += 1
        if tam/pags > 0.5: pts += 2
        elif tam/pags > 0.2: pts += 1
    return Complexidade.LEVE if pts <= 2 else (Complexidade.MEDIO if pts <= 5 else Complexidade.PESADO)

def analisar_pdf(caminho: Path, cfg: Config) -> InfoPDF:
    nome = caminho.stem
    tam = caminho.stat().st_size / (1024*1024)
    pags, imgs = 0, 0
    try:
        import fitz
        doc = fitz.open(caminho)
        pags = len(doc)
        for i in range(min(10, pags)): imgs += len(doc[i].get_images())
        if pags > 10: imgs = int(imgs * pags / 10)
        doc.close()
    except ImportError: pags = int(tam * 5)
    cplx = calcular_complexidade(tam, pags, imgs, cfg)
    status = verificar_status(nome, cfg.dir_saida, cfg)
    fator = {Complexidade.LEVE: 0.5, Complexidade.MEDIO: 1.5, Complexidade.PESADO: 3.0}
    return InfoPDF(caminho, nome, tam, pags, imgs, cplx, status, pags * fator.get(cplx, 1.0), calcular_hash(caminho))

def listar_pdfs(cfg: Config) -> List[InfoPDF]:
    if not cfg.dir_entrada.exists(): return []
    arqs = list(cfg.dir_entrada.glob("*.pdf")) + list(cfg.dir_entrada.glob("*.PDF"))
    pdfs = [analisar_pdf(a, cfg) for a in arqs]
    def ordem(p):
        s = {StatusConversao.INCOMPLETO: 0, StatusConversao.PENDENTE: 1, StatusConversao.ERRO: 2, StatusConversao.COMPLETO: 3}
        c = {Complexidade.LEVE: 0, Complexidade.MEDIO: 1, Complexidade.PESADO: 2}
        return (s.get(p.status, 99), c.get(p.complexidade, 99))
    return sorted(pdfs, key=ordem)
EOF

# ══════════════════════════════════════════════════════════════════════════════
# converter.py
# ══════════════════════════════════════════════════════════════════════════════
cat > packages/pdf_converter/src/pdf_converter/converter.py << 'EOF'
"""Conversão de PDF para Markdown usando Docling."""
import json, logging, shutil, time, traceback, warnings
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List
from pdf_converter.analyzer import InfoPDF, StatusConversao, listar_pdfs
from pdf_converter.config import Config
from pdf_converter.hardware import InfoHardware, detectar_hardware

warnings.filterwarnings("ignore")
for n in ["RapidOCR", "rapidocr", "PIL", "docling", "torch", "transformers"]:
    logging.getLogger(n).setLevel(logging.ERROR)

def preparar_pasta(nome: str, dir_saida: Path, limpar: bool = False) -> Path:
    pasta = dir_saida / nome
    if pasta.exists() and limpar:
        for item in pasta.iterdir():
            if item.is_file(): item.unlink()
            elif item.is_dir(): shutil.rmtree(item)
    pasta.mkdir(parents=True, exist_ok=True)
    return pasta

def converter_pdf(pdf: InfoPDF, cfg: Config, hw: InfoHardware = None, verbose: bool = True) -> Dict[str, Any]:
    if hw is None: hw = detectar_hardware()
    resultado = {"arquivo": pdf.nome, "sucesso": False, "erro": None, "erro_detalhado": None,
                 "etapa_falha": None, "tempo": 0.0, "pasta_saida": None, "num_imagens": 0, "tamanho_md": 0}
    inicio, etapa = time.time(), "inicialização"
    def log(msg):
        if verbose: print(f"   └─ {msg}")
    try:
        etapa = "imports"
        log("Carregando Docling...")
        from docling.document_converter import DocumentConverter, PdfFormatOption
        from docling.datamodel.base_models import InputFormat, ConversionStatus
        from docling.datamodel.pipeline_options import PdfPipelineOptions
        from docling_core.types.doc import ImageRefMode
        log("Docling carregado ✓")

        etapa = "preparar_pasta"
        limpar = pdf.status == StatusConversao.INCOMPLETO
        if limpar: log("Limpando conversão anterior...")
        pasta = preparar_pasta(pdf.nome, cfg.dir_saida, limpar=limpar)
        log(f"Pasta: {pasta.name} ✓")

        etapa = "configurar_pipeline"
        pipeline = PdfPipelineOptions()
        pipeline.images_scale = cfg.escala_imagens
        pipeline.generate_page_images = True
        pipeline.generate_picture_images = True
        if cfg.habilitar_ocr:
            pipeline.do_ocr = True
            log(f"OCR habilitado, escala: {cfg.escala_imagens}x")

        etapa = "criar_conversor"
        converter = DocumentConverter(format_options={InputFormat.PDF: PdfFormatOption(pipeline_options=pipeline)})
        log("Conversor inicializado ✓")

        etapa = "converter"
        log(f"Convertendo ({pdf.num_paginas} págs, {pdf.tamanho_mb:.1f} MB)...")
        t0 = time.time()
        conv_result = converter.convert(str(pdf.caminho))
        log(f"Conversão concluída em {time.time() - t0:.1f}s ✓")

        etapa = "verificar_status"
        if conv_result.status != ConversionStatus.SUCCESS:
            raise Exception(f"Status: {conv_result.status}")

        etapa = "salvar_markdown"
        arquivo_md = pasta / f"{pdf.nome}.md"
        conv_result.document.save_as_markdown(arquivo_md, image_mode=ImageRefMode.REFERENCED)
        with open(arquivo_md, 'a', encoding='utf-8') as f:
            f.write(f"\n\n{cfg.marcador_completo}\n")
        resultado["tamanho_md"] = arquivo_md.stat().st_size
        log(f"Markdown: {resultado['tamanho_md'] / 1024:.1f} KB ✓")

        pasta_artifacts = pasta / f"{pdf.nome}_artifacts"
        if pasta_artifacts.exists():
            imgs = list(pasta_artifacts.glob("*.png")) + list(pasta_artifacts.glob("*.jpg"))
            resultado["num_imagens"] = len(imgs)
            log(f"Imagens: {resultado['num_imagens']} ✓")

        if cfg.copiar_pdf_original:
            etapa = "copiar_pdf"
            shutil.copy2(str(pdf.caminho), str(pasta / f"{pdf.nome}.pdf"))
            log("PDF copiado ✓")

        resultado["sucesso"] = True
        resultado["pasta_saida"] = str(pasta)
    except Exception as e:
        resultado["erro"] = str(e)
        resultado["erro_detalhado"] = traceback.format_exc()
        resultado["etapa_falha"] = etapa
        if verbose:
            print(f"   └─ ✗ FALHA em: {etapa}")
            print(f"   └─ Erro: {e}")
    resultado["tempo"] = time.time() - inicio
    return resultado

def processar_lote(cfg: Config = None, apenas_pendentes: bool = True, verbose: bool = True) -> Dict[str, Any]:
    if cfg is None: cfg = Config()
    cfg.dir_entrada.mkdir(parents=True, exist_ok=True)
    cfg.dir_saida.mkdir(parents=True, exist_ok=True)
    hw = detectar_hardware()
    pdfs = listar_pdfs(cfg)
    if apenas_pendentes:
        pdfs = [p for p in pdfs if p.status in [StatusConversao.PENDENTE, StatusConversao.INCOMPLETO]]
    if not pdfs:
        if verbose: print("✓ Todos os PDFs já foram convertidos!")
        return {"processados": 0, "sucesso": 0, "falhas": 0, "detalhes": []}
    if verbose:
        print(f"\n📦 {len(pdfs)} PDFs a processar")
        print(f"⏱️  Tempo estimado: {sum(p.tempo_estimado for p in pdfs) / 60:.0f} min")
        print(f"🖥️  Hardware: {hw.nome_gpu if hw.tem_gpu else 'CPU'} ({hw.ambiente})\n")
    resultados = {"processados": 0, "sucesso": 0, "falhas": 0, "detalhes": []}
    for i, pdf in enumerate(pdfs, 1):
        if verbose: print(f"[{i}/{len(pdfs)}] {pdf.nome} [{pdf.complexidade.value}]")
        r = converter_pdf(pdf, cfg, hw, verbose)
        resultados["detalhes"].append(r)
        resultados["processados"] += 1
        if r["sucesso"]:
            resultados["sucesso"] += 1
            if verbose: print(f"   ✓ {r['tempo']:.1f}s\n")
        else:
            resultados["falhas"] += 1
            if verbose: print(f"   ✗ {r['erro']}\n")
    relatorio = cfg.dir_saida / f"_relatorio_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(relatorio, 'w', encoding='utf-8') as f:
        json.dump({"timestamp": datetime.now().isoformat(),
                   "hardware": {"gpu": hw.tem_gpu, "nome": hw.nome_gpu, "ambiente": hw.ambiente},
                   "stats": {k: v for k, v in resultados.items() if k != "detalhes"},
                   "detalhes": [{k: v for k, v in d.items() if k != "erro_detalhado"} for d in resultados["detalhes"]]
                  }, f, indent=2, ensure_ascii=False)
    if verbose:
        print(f"\n{'═' * 50}")
        print(f"📊 Processados: {resultados['processados']}")
        print(f"✓  Sucesso: {resultados['sucesso']}")
        if resultados["falhas"]: print(f"✗  Falhas: {resultados['falhas']}")
        print(f"📄 Relatório: {relatorio.name}")
        print(f"{'═' * 50}\n")
    return resultados
EOF

# ══════════════════════════════════════════════════════════════════════════════
# cli.py
# ══════════════════════════════════════════════════════════════════════════════
cat > packages/pdf_converter/src/pdf_converter/cli.py << 'EOF'
"""Interface de linha de comando para o PDF Converter."""
import argparse, sys
from pathlib import Path
from pdf_converter.analyzer import listar_pdfs, StatusConversao
from pdf_converter.config import Config
from pdf_converter.converter import converter_pdf, processar_lote
from pdf_converter.hardware import detectar_hardware

def exibir_lista(cfg: Config):
    pdfs = listar_pdfs(cfg)
    if not pdfs:
        print(f"Nenhum PDF em: {cfg.dir_entrada}")
        return
    print(f"\n{'#':>3} {'Arquivo':<45} {'Págs':>5} {'MB':>7} {'Status':<10}")
    print("─" * 75)
    for i, p in enumerate(pdfs, 1):
        icon = {"pendente": "⏳", "incompleto": "⚠️", "completo": "✓"}.get(p.status.value, "?")
        print(f"{i:>3} {p.nome[:44]:<45} {p.num_paginas:>5} {p.tamanho_mb:>6.1f} {icon} {p.status.value}")
    pend = sum(1 for p in pdfs if p.status != StatusConversao.COMPLETO)
    print(f"\nTotal: {len(pdfs)} | Pendentes: {pend}")

def main():
    parser = argparse.ArgumentParser(prog="pdf2md", description="Conversor PDF→Markdown com Docling")
    sub = parser.add_subparsers(dest="cmd", help="Comandos")

    p_list = sub.add_parser("list", help="Lista PDFs")
    p_list.add_argument("--entrada", "-e", type=Path)

    p_conv = sub.add_parser("convert", help="Converte um PDF")
    p_conv.add_argument("arquivo", type=Path)
    p_conv.add_argument("--saida", "-o", type=Path)
    p_conv.add_argument("--quiet", "-q", action="store_true")

    p_batch = sub.add_parser("batch", help="Converte todos pendentes")
    p_batch.add_argument("--entrada", "-e", type=Path)
    p_batch.add_argument("--saida", "-o", type=Path)
    p_batch.add_argument("--all", "-a", action="store_true")
    p_batch.add_argument("--quiet", "-q", action="store_true")

    sub.add_parser("info", help="Info de hardware")
    sub.add_parser("colab", help="Config Google Colab")
    sub.add_parser("codespaces", help="Config Codespaces")

    args = parser.parse_args()

    if args.cmd == "info":
        hw = detectar_hardware()
        print(f"Ambiente: {hw.ambiente}\nGPU: {hw.nome_gpu if hw.tem_gpu else 'N/A'}\nCPUs: {hw.num_cpus}")
        return
    if args.cmd == "list":
        cfg = Config()
        if args.entrada: cfg.dir_entrada = args.entrada
        exibir_lista(cfg)
        return
    if args.cmd == "convert":
        if not args.arquivo.exists():
            print(f"Não encontrado: {args.arquivo}"); sys.exit(1)
        from pdf_converter.analyzer import analisar_pdf
        cfg = Config()
        if args.saida: cfg.dir_saida = args.saida
        r = converter_pdf(analisar_pdf(args.arquivo, cfg), cfg, verbose=not args.quiet)
        sys.exit(0 if r["sucesso"] else 1)
    if args.cmd == "batch":
        cfg = Config()
        if args.entrada: cfg.dir_entrada = args.entrada
        if args.saida: cfg.dir_saida = args.saida
        r = processar_lote(cfg, apenas_pendentes=not args.all, verbose=not args.quiet)
        sys.exit(0 if r["falhas"] == 0 else 1)
    if args.cmd == "colab":
        r = processar_lote(Config.para_colab())
        sys.exit(0 if r["falhas"] == 0 else 1)
    if args.cmd == "codespaces":
        r = processar_lote(Config.para_codespaces())
        sys.exit(0 if r["falhas"] == 0 else 1)
    parser.print_help()

if __name__ == "__main__": main()
EOF

# ══════════════════════════════════════════════════════════════════════════════
# Sincronizar workspace
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "🔄 Sincronizando workspace UV..."
uv sync --all-packages

echo ""
echo "✅ Setup completo!"
echo ""
echo "Comandos disponíveis:"
echo "  uv run --package pdf-converter pdf2md info        # Info hardware"
echo "  uv run --package pdf-converter pdf2md list        # Listar PDFs"
echo "  uv run --package pdf-converter pdf2md codespaces  # Converter todos"
echo ""
echo "No Python/Marimo:"
echo "  from pdf_converter import Config, processar_lote"
echo "  processar_lote(Config.para_codespaces())"