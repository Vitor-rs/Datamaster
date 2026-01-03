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
