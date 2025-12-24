"""PDF Converter - Extração de PDF para Markdown com Docling."""
from pdf_converter.config import Config
from pdf_converter.converter import converter_pdf, processar_lote
__version__ = "0.1.0"
__all__ = ["Config", "converter_pdf", "processar_lote"]
