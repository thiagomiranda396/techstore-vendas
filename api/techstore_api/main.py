"""API somente leitura do dashboard web TechstoreVendas.

Segurança (ver docs/DASHBOARD_WEB.md):
  * só GET; consultas SQL fixas e parametrizadas (techstore_api/consultas/*.sql);
  * filtros validados contra os valores existentes; parâmetros desconhecidos recusados;
  * sessões do banco somente leitura, com tempo limite;
  * cabeçalhos de segurança e CSP restrita à própria origem;
  * erros sem detalhes técnicos para o cliente.
"""

from __future__ import annotations

import logging
import time
from contextlib import asynccontextmanager
from datetime import date
from decimal import Decimal
from typing import Any

import psycopg
from fastapi import Depends, FastAPI, HTTPException, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from starlette.exceptions import HTTPException as StarletteHTTPException
from starlette.middleware.trustedhost import TrustedHostMiddleware

from . import db
from .config import PASTA_WEB, carregar_config

log = logging.getLogger("techstore_api")

MAX_ITENS_FILTRO = 20
CACHE_FILTROS_SEGUNDOS = 300

CABECALHOS_SEGURANCA = {
    "Content-Security-Policy": (
        "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; "
        "connect-src 'self'; font-src 'self'; object-src 'none'; base-uri 'none'; "
        "frame-ancestors 'none'; form-action 'none'"
    ),
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Referrer-Policy": "no-referrer",
    "Permissions-Policy": "camera=(), microphone=(), geolocation=(), payment=()",
    "Cross-Origin-Opener-Policy": "same-origin",
    "Cross-Origin-Resource-Policy": "same-origin",
}


# ----------------------------------------------------------------------------- ciclo de vida

@asynccontextmanager
async def ciclo_de_vida(app: FastAPI):
    config = carregar_config()
    pool = db.criar_pool(config)
    pool.open(wait=False)
    app.state.config = config
    app.state.pool = pool
    app.state.cache_filtros = None
    log.info("API iniciada; banco %s", config.descricao_segura)
    try:
        yield
    finally:
        pool.close()


app = FastAPI(
    title="TechstoreVendas API",
    docs_url=None,       # a documentação interativa usa scripts externos, incompatíveis com a CSP
    redoc_url=None,
    openapi_url=None,
    lifespan=ciclo_de_vida,
)

app.add_middleware(TrustedHostMiddleware, allowed_hosts=["127.0.0.1", "localhost"])

# CORS só para desenvolvimento (ex.: Live Preview do VS Code em outra porta).
# Desligado por padrão; ativado por TECHSTORE_API_ORIGENS_DEV, que só aceita
# origens locais. Só GET, sem credenciais nem cabeçalhos extras.
_ORIGENS_DEV = list(carregar_config().origens_dev)
if _ORIGENS_DEV:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=_ORIGENS_DEV,
        allow_methods=["GET"],
        allow_headers=[],
        allow_credentials=False,
        max_age=600,
    )


@app.middleware("http")
async def cabecalhos_de_seguranca(request: Request, call_next):
    resposta = await call_next(request)
    for nome, valor in CABECALHOS_SEGURANCA.items():
        resposta.headers.setdefault(nome, valor)
    if request.url.path.startswith("/api/"):
        resposta.headers["Cache-Control"] = "no-store"
    return resposta


# ----------------------------------------------------------------------------- erros

def _erro(status: int, mensagem: str) -> JSONResponse:
    return JSONResponse(status_code=status, content={"erro": mensagem})


@app.exception_handler(RequestValidationError)
async def erro_validacao(_: Request, __: RequestValidationError):
    return _erro(400, "Parâmetros inválidos.")


@app.exception_handler(StarletteHTTPException)
async def erro_http(_: Request, exc: StarletteHTTPException):
    mensagens = {404: "Recurso não encontrado.", 405: "Método não permitido."}
    mensagem = exc.detail if exc.status_code == 400 else mensagens.get(exc.status_code, "Requisição recusada.")
    return _erro(exc.status_code, mensagem)


@app.exception_handler(psycopg.OperationalError)
async def erro_banco_indisponivel(_: Request, exc: psycopg.OperationalError):
    log.error("Banco indisponível: %s", type(exc).__name__)
    return _erro(503, "Banco de dados indisponível.")


@app.exception_handler(Exception)
async def erro_interno(_: Request, exc: Exception):
    log.error("Erro interno: %s", type(exc).__name__)
    return _erro(500, "Erro interno.")


# ----------------------------------------------------------------------------- filtros

def _filtros_permitidos(request: Request) -> dict[str, Any]:
    """Valores válidos dos filtros, com cache curto."""
    cache = request.app.state.cache_filtros
    if cache is None or time.monotonic() - cache[0] > CACHE_FILTROS_SEGUNDOS:
        linha = db.buscar_um(request.app.state.pool, "filtros")
        cache = (time.monotonic(), linha)
        request.app.state.cache_filtros = cache
    return cache[1]


def _recusar_parametros_desconhecidos(request: Request, permitidos: set[str]) -> None:
    desconhecidos = set(request.query_params.keys()) - permitidos
    if desconhecidos:
        raise HTTPException(status_code=400, detail="Parâmetros inválidos.")


def filtros_comuns(
    request: Request,
    inicio: date | None = Query(default=None),
    fim: date | None = Query(default=None),
    categoria: list[int] = Query(default=[], max_length=MAX_ITENS_FILTRO),
    vendedor: list[int] = Query(default=[], max_length=MAX_ITENS_FILTRO),
) -> dict[str, Any]:
    _recusar_parametros_desconhecidos(request, {"inicio", "fim", "categoria", "vendedor", "limite"})
    if inicio and fim and inicio > fim:
        raise HTTPException(status_code=400, detail="Período inválido: início depois do fim.")
    permitidos = _filtros_permitidos(request)
    ids_categoria = {c["id"] for c in permitidos["categorias"]}
    ids_vendedor = {v["id"] for v in permitidos["vendedores"]}
    if not set(categoria) <= ids_categoria or not set(vendedor) <= ids_vendedor:
        raise HTTPException(status_code=400, detail="Filtro com valor inexistente.")
    return {
        "inicio": inicio,
        "fim": fim,
        "categorias": sorted(set(categoria)) or None,
        "vendedores": sorted(set(vendedor)) or None,
    }


def _filtros_aplicados(f: dict[str, Any]) -> dict[str, Any]:
    return {
        "inicio": f["inicio"],
        "fim": f["fim"],
        "categorias": f["categorias"] or [],
        "vendedores": f["vendedores"] or [],
    }


def _numero(valor: Any) -> Any:
    return float(valor) if isinstance(valor, Decimal) else valor


def _linha(linha: dict[str, Any]) -> dict[str, Any]:
    return {chave: _numero(valor) for chave, valor in linha.items()}


# ----------------------------------------------------------------------------- endpoints

@app.get("/api/saude")
def saude(request: Request):
    _recusar_parametros_desconhecidos(request, set())
    filtros = _filtros_permitidos(request)
    return {"status": "ok", "primeira_venda": filtros["primeira_venda"], "ultima_venda": filtros["ultima_venda"]}


@app.get("/api/filtros")
def filtros(request: Request):
    _recusar_parametros_desconhecidos(request, set())
    return _filtros_permitidos(request)


@app.get("/api/kpis")
def kpis(request: Request, f: dict[str, Any] = Depends(filtros_comuns)):
    pool = request.app.state.pool
    totais = _linha(db.buscar_um(pool, "kpis", f))
    mes = db.buscar_um(pool, "ultimo_mes_completo", {"categorias": f["categorias"], "vendedores": f["vendedores"]})
    atual, anterior = mes.get("faturamento_mes"), mes.get("faturamento_mes_anterior")
    variacao = round(float((atual - anterior) / anterior * 100), 2) if atual is not None and anterior else None
    ativos, recorrentes = totais["clientes_ativos"], totais["clientes_recorrentes"]
    totais["pct_clientes_recorrentes"] = round(100 * recorrentes / ativos, 1) if ativos else None
    return {
        "filtros": _filtros_aplicados(f),
        "totais": totais,
        "ultimo_mes_completo": {
            "mes": mes.get("mes"),
            "faturamento": _numero(atual),
            "faturamento_mes_anterior": _numero(anterior),
            "variacao_pct": variacao,
        },
        "ultima_venda": mes.get("ultima_venda"),
    }


@app.get("/api/vendas-mensais")
def vendas_mensais(request: Request, f: dict[str, Any] = Depends(filtros_comuns)):
    linhas = db.buscar_todos(request.app.state.pool, "vendas_mensais", f)
    return {"filtros": _filtros_aplicados(f), "meses": [_linha(l) for l in linhas]}


@app.get("/api/categorias")
def categorias(request: Request, f: dict[str, Any] = Depends(filtros_comuns)):
    linhas = db.buscar_todos(request.app.state.pool, "categorias", f)
    return {"filtros": _filtros_aplicados(f), "categorias": [_linha(l) for l in linhas]}


@app.get("/api/produtos")
def produtos(
    request: Request,
    f: dict[str, Any] = Depends(filtros_comuns),
    limite: int = Query(default=5, ge=1, le=50),
):
    linhas = db.buscar_todos(request.app.state.pool, "produtos", {**f, "limite": limite})
    return {"filtros": _filtros_aplicados(f), "limite": limite, "produtos": [_linha(l) for l in linhas]}


@app.get("/api/vendedores")
def vendedores(request: Request, f: dict[str, Any] = Depends(filtros_comuns)):
    linhas = db.buscar_todos(request.app.state.pool, "vendedores", f)
    return {"filtros": _filtros_aplicados(f), "vendedores": [_linha(l) for l in linhas]}


# ----------------------------------------------------------------------------- frontend
# Montado por último, para não encobrir as rotas /api.
if PASTA_WEB.is_dir():
    app.mount("/", StaticFiles(directory=PASTA_WEB, html=True), name="web")
