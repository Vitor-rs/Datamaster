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
