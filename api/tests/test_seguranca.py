"""Validação de entradas, métodos, cabeçalhos, ausência de dados pessoais e erros genéricos."""

import re

import pytest

from techstore_api import main as modulo_main
from techstore_api.config import carregar_config

ENDPOINTS = ["/api/kpis", "/api/vendas-mensais", "/api/categorias", "/api/produtos", "/api/vendedores"]


@pytest.mark.parametrize(
    "params",
    [
        {"inicio": "2026-13-01"},
        {"inicio": "ontem"},
        {"inicio": "2026-08-01", "fim": "2026-07-01"},
        {"categoria": "abc"},
        {"categoria": "1;DROP TABLE cliente"},
        {"categoria": "1 OR 1=1"},
        {"categoria": 999},
        {"vendedor": -1},
        {"parametro_desconhecido": "x"},
        {"categoria": list(range(1, 30))},
    ],
)
def test_entradas_invalidas_retornam_400_generico(cliente, params):
    r = cliente.get("/api/kpis", params=params)
    assert r.status_code == 400
    assert set(r.json()) == {"erro"}
    assert "Traceback" not in r.text and "psycopg" not in r.text.lower()


@pytest.mark.parametrize("limite", [0, -1, 51, "dez"])
def test_limite_de_produtos_validado(cliente, limite):
    assert cliente.get("/api/produtos", params={"limite": limite}).status_code == 400


@pytest.mark.parametrize("metodo", ["post", "put", "patch", "delete"])
def test_somente_get(cliente, metodo):
    r = getattr(cliente, metodo)("/api/kpis")
    assert r.status_code == 405
    assert r.json() == {"erro": "Método não permitido."}


def test_host_externo_recusado(cliente):
    assert cliente.get("/api/kpis", headers={"host": "exemplo-malicioso.com"}).status_code == 400


def test_cabecalhos_de_seguranca(cliente):
    r = cliente.get("/api/kpis")
    csp = r.headers["content-security-policy"]
    assert "default-src 'self'" in csp and "script-src 'self'" in csp and "frame-ancestors 'none'" in csp
    assert r.headers["x-content-type-options"] == "nosniff"
    assert r.headers["x-frame-options"] == "DENY"
    assert r.headers["referrer-policy"] == "no-referrer"
    assert r.headers["cache-control"] == "no-store"


@pytest.mark.parametrize("caminho", ["/docs", "/redoc", "/openapi.json"])
def test_documentacao_interativa_desativada(cliente, caminho):
    assert cliente.get(caminho).status_code == 404


SENSIVEIS = re.compile(r"cpf|e-?mail|telefone|salario|salário|logradouro|cep|endereco|endereço|senha|password", re.I)


def _chaves(obj):
    if isinstance(obj, dict):
        for k, v in obj.items():
            yield k
            yield from _chaves(v)
    elif isinstance(obj, list):
        for item in obj:
            yield from _chaves(item)


def test_nenhum_dado_pessoal_nas_respostas(cliente):
    respostas = [cliente.get(e, params={"limite": 19} if e.endswith("produtos") else None).json() for e in ENDPOINTS]
    respostas += [cliente.get("/api/filtros").json(), cliente.get("/api/saude").json()]
    for corpo in respostas:
        assert not [k for k in _chaves(corpo) if SENSIVEIS.search(k)]
        assert "@" not in str(corpo)  # nenhum e-mail em valores


def test_sessoes_do_pool_sao_somente_leitura(cliente):
    # Vale para qualquer usuário configurado: a própria API abre sessões read-only.
    import psycopg

    with modulo_main.app.state.pool.connection() as c:
        assert c.execute("SHOW default_transaction_read_only").fetchone()["default_transaction_read_only"] == "on"
        assert c.execute("SHOW statement_timeout").fetchone()["statement_timeout"] == "5s"
        with pytest.raises(psycopg.errors.ReadOnlySqlTransaction):
            c.execute("CREATE TEMP TABLE tentativa_escrita (x int)")


def test_erro_interno_sem_detalhes(cliente, monkeypatch):
    def falha(*_, **__):
        raise RuntimeError("detalhe interno que não pode vazar")

    monkeypatch.setattr(modulo_main.db, "buscar_todos", falha)
    r = cliente.get("/api/categorias")
    assert r.status_code == 500
    assert r.json() == {"erro": "Erro interno."}
    assert "detalhe interno" not in r.text


def test_config_recusa_host_nao_local(monkeypatch):
    monkeypatch.setenv("TECHSTORE_API_HOST", "0.0.0.0")
    with pytest.raises(ValueError):
        carregar_config()
    monkeypatch.setenv("TECHSTORE_API_HOST", "127.0.0.1")
    monkeypatch.setenv("TECHSTORE_PG_HOST", "servidor-remoto.exemplo")
    with pytest.raises(ValueError):
        carregar_config()


def test_cors_desligado_por_padrao(cliente):
    # Nos testes, TECHSTORE_API_ORIGENS_DEV não está definida: nenhuma origem externa é liberada.
    r = cliente.get("/api/kpis", headers={"Origin": "http://127.0.0.1:3000"})
    assert "access-control-allow-origin" not in {k.lower() for k in r.headers}


@pytest.mark.parametrize(
    "origens",
    ["https://exemplo.com", "http://192.168.0.10:3000", "http://127.0.0.1", "*", "http://localhost:3000,http://evil.com"],
)
def test_config_recusa_origens_cors_nao_locais(monkeypatch, origens):
    monkeypatch.setenv("TECHSTORE_API_ORIGENS_DEV", origens)
    with pytest.raises(ValueError):
        carregar_config()


def test_senha_nao_aparece_na_representacao_da_config(config):
    assert "pg_senha" not in repr(config)
    assert config.pg_senha is None or config.pg_senha not in config.descricao_segura
