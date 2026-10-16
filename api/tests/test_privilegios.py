"""Privilégios reais do papel da API no banco.

Só roda quando a API está configurada com techstore_api_leitor (api/.env).
Com outro usuário, os testes são pulados e o motivo aparece no relatório.
"""

import psycopg
import pytest

from techstore_api.db import OPCOES_SESSAO

PAPEL_API = "techstore_api_leitor"


@pytest.fixture(scope="module")
def conexao(config):
    if config.pg_usuario != PAPEL_API:
        pytest.skip(f"API configurada com {config.pg_usuario}; testes de privilégio exigem {PAPEL_API}.")
    # Sem as opções de sessão da API: verifica as proteções do PRÓPRIO papel.
    with psycopg.connect(
        host=config.pg_host, port=config.pg_port, dbname=config.pg_banco,
        user=config.pg_usuario, password=config.pg_senha, connect_timeout=5, autocommit=True,
    ) as c:
        yield c


def test_le_as_quatro_views(conexao):
    for view in ["vw_fato_vendas", "vw_dim_produto", "vw_dim_vendedor", "vw_dim_calendario"]:
        assert conexao.execute(f"SELECT count(*) FROM {view}").fetchone()[0] > 0


@pytest.mark.parametrize("objeto", ["cliente", "pedido", "itens_pedido", "produto", "vendedor", "vw_dim_cliente", "vw_vendas"])
def test_nao_le_tabelas_nem_views_nao_concedidas(conexao, objeto):
    with pytest.raises(psycopg.errors.InsufficientPrivilege):
        conexao.execute(f"SELECT 1 FROM {objeto} LIMIT 1")


def test_sessao_do_papel_e_somente_leitura(conexao):
    assert conexao.execute("SHOW default_transaction_read_only").fetchone()[0] == "on"
    assert conexao.execute("SHOW statement_timeout").fetchone()[0] == "5s"
    with pytest.raises(psycopg.errors.ReadOnlySqlTransaction):
        conexao.execute("CREATE TEMP TABLE tentativa_escrita (x int)")


def test_papel_sem_atributos_especiais(conexao):
    linha = conexao.execute(
        "SELECT rolsuper, rolcreatedb, rolcreaterole, rolreplication, rolbypassrls FROM pg_roles WHERE rolname = current_user"
    ).fetchone()
    assert linha == (False, False, False, False, False)


def test_opcoes_de_sessao_da_api():
    assert "default_transaction_read_only=on" in OPCOES_SESSAO
    assert "statement_timeout=5000" in OPCOES_SESSAO
