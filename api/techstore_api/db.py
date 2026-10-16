"""Pool de conexões somente leitura e execução das consultas fixas."""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Any

from psycopg.conninfo import make_conninfo
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

from .config import Config

PASTA_CONSULTAS = Path(__file__).resolve().parent / "consultas"

# Proteção em profundidade: além das configurações do próprio papel no banco,
# cada sessão da API é aberta em modo somente leitura e com tempo limite.
OPCOES_SESSAO = "-c default_transaction_read_only=on -c statement_timeout=5000"


def criar_pool(config: Config) -> ConnectionPool:
    conninfo = make_conninfo(
        host=config.pg_host,
        port=config.pg_port,
        dbname=config.pg_banco,
        user=config.pg_usuario,
        application_name="techstore_api",
        connect_timeout=5,
        options=OPCOES_SESSAO,
    )
    kwargs: dict[str, Any] = {"row_factory": dict_row, "autocommit": True}
    if config.pg_senha:
        kwargs["password"] = config.pg_senha  # fora da conninfo, para não aparecer em logs
    return ConnectionPool(
        conninfo,
        kwargs=kwargs,
        min_size=1,
        max_size=4,
        open=False,
        check=ConnectionPool.check_connection,
        name="techstore_api",
    )


@lru_cache(maxsize=None)
def consulta(nome: str) -> str:
    """Lê uma consulta fixa de techstore_api/consultas/<nome>.sql."""
    return (PASTA_CONSULTAS / f"{nome}.sql").read_text(encoding="utf-8")


def buscar_todos(pool: ConnectionPool, nome: str, parametros: dict[str, Any] | None = None) -> list[dict[str, Any]]:
    with pool.connection() as conexao:
        return conexao.execute(consulta(nome), parametros or {}).fetchall()


def buscar_um(pool: ConnectionPool, nome: str, parametros: dict[str, Any] | None = None) -> dict[str, Any]:
    linhas = buscar_todos(pool, nome, parametros)
    return linhas[0] if linhas else {}
