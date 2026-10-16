"""Configuração da API, lida de variáveis de ambiente e, opcionalmente, de api/.env.

A senha nunca é registrada em log nem incluída em mensagens de erro.
"""

from __future__ import annotations

import os
import re
from dataclasses import dataclass, field
from pathlib import Path

RAIZ_API = Path(__file__).resolve().parent.parent
RAIZ_PROJETO = RAIZ_API.parent
ARQUIVO_ENV = RAIZ_API / ".env"
PASTA_WEB = RAIZ_PROJETO / "web"

HOSTS_LOCAIS = {"127.0.0.1", "localhost", "::1"}

# Origens aceitas para CORS de desenvolvimento (ex.: Live Preview do VS Code).
ORIGEM_LOCAL = re.compile(r"^http://(127\.0\.0\.1|localhost):\d{2,5}$")


def _carregar_env(caminho: Path) -> None:
    """Carrega KEY=VALUE de um arquivo .env sem sobrescrever variáveis já definidas."""
    if not caminho.is_file():
        return
    for linha in caminho.read_text(encoding="utf-8").splitlines():
        linha = linha.strip()
        if not linha or linha.startswith("#") or "=" not in linha:
            continue
        chave, valor = linha.split("=", 1)
        chave, valor = chave.strip(), valor.strip()
        if len(valor) >= 2 and valor[0] == valor[-1] and valor[0] in "\"'":
            valor = valor[1:-1]
        os.environ.setdefault(chave, valor)


@dataclass(frozen=True)
class Config:
    pg_host: str
    pg_port: int
    pg_banco: str
    pg_usuario: str
    pg_senha: str | None = field(repr=False)
    api_host: str
    api_porta: int
    origens_dev: tuple[str, ...] = ()

    @property
    def descricao_segura(self) -> str:
        """Descrição da conexão sem a senha, para logs."""
        return f"{self.pg_usuario}@{self.pg_host}:{self.pg_port}/{self.pg_banco}"


def carregar_config() -> Config:
    _carregar_env(ARQUIVO_ENV)
    config = Config(
        pg_host=os.environ.get("TECHSTORE_PG_HOST", "localhost"),
        pg_port=int(os.environ.get("TECHSTORE_PG_PORT", "5433")),
        pg_banco=os.environ.get("TECHSTORE_PG_BANCO", "techstore_dev_v3"),
        pg_usuario=os.environ.get("TECHSTORE_PG_USUARIO", "techstore_api_leitor"),
        pg_senha=os.environ.get("TECHSTORE_PG_SENHA") or None,
        api_host=os.environ.get("TECHSTORE_API_HOST", "127.0.0.1"),
        api_porta=int(os.environ.get("TECHSTORE_API_PORTA", "8000")),
        origens_dev=tuple(
            o.strip() for o in os.environ.get("TECHSTORE_API_ORIGENS_DEV", "").split(",") if o.strip()
        ),
    )
    invalidas = [o for o in config.origens_dev if not ORIGEM_LOCAL.match(o)]
    if invalidas:
        raise ValueError("TECHSTORE_API_ORIGENS_DEV só aceita origens locais http://127.0.0.1:<porta> ou http://localhost:<porta>.")
    if config.api_host not in HOSTS_LOCAIS:
        raise ValueError("TECHSTORE_API_HOST deve ser um endereço local (127.0.0.1, localhost ou ::1).")
    if config.pg_host not in HOSTS_LOCAIS:
        raise ValueError("TECHSTORE_PG_HOST deve ser local: a API só lê a instância de testes desta máquina.")
    return config
