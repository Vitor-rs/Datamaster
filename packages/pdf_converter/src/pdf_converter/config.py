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
