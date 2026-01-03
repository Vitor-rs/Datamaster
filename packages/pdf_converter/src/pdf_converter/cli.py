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
