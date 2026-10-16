"""Exporta o conjunto de dados da demonstração pública do dashboard.

Gera web/dados-demo/demo.json a partir das views analíticas, lidas pelo papel
somente leitura da API (techstore_api_leitor, ver api/.env). O arquivo contém
só o necessário para o dashboard recalcular os indicadores no navegador:

  * itens de venda (chaves numéricas, datas, quantidades, preço e custo do item);
  * produtos (nome e categoria) e vendedores (nome);
  * meses com operação e a situação de cada um (Completo/Parcial);
  * os valores de /api/filtros.

Nenhum dado pessoal: clientes aparecem só como ID numérico (a API nem tem
acesso à vw_dim_cliente). Todos os dados do projeto são fictícios.

Uso (dentro de api/):  .venv\\Scripts\\python.exe exportar_demo.py
"""

from __future__ import annotations

import json
from datetime import date, datetime, timezone
from decimal import Decimal
from pathlib import Path

import psycopg
from psycopg.rows import dict_row

from techstore_api import db
from techstore_api.config import PASTA_WEB, carregar_config

DESTINO = PASTA_WEB / "dados-demo" / "demo.json"


def _valor(v):
    if isinstance(v, Decimal):
        return float(v)
    if isinstance(v, date):
        return v.isoformat()
    return v


def _linhas(conexao, sql: str) -> list[dict]:
    return [{k: _valor(v) for k, v in linha.items()} for linha in conexao.execute(sql).fetchall()]


def main() -> None:
    config = carregar_config()
    with psycopg.connect(
        host=config.pg_host, port=config.pg_port, dbname=config.pg_banco,
        user=config.pg_usuario, password=config.pg_senha,
        connect_timeout=5, autocommit=True, row_factory=dict_row,
        options=db.OPCOES_SESSAO,
    ) as conexao:
        itens = conexao.execute(
            """SELECT id_item, id_pedido, data_pedido, id_cliente, id_vendedor, id_produto,
                      quantidade, preco_unitario, custo_unitario
               FROM vw_fato_vendas ORDER BY id_item"""
        ).fetchall()
        produtos = _linhas(conexao, "SELECT id_produto, produto, id_categoria, categoria FROM vw_dim_produto ORDER BY id_produto")
        vendedores = _linhas(conexao, "SELECT id_vendedor, vendedor FROM vw_dim_vendedor ORDER BY id_vendedor")
        meses = _linhas(
            conexao,
            """SELECT DISTINCT inicio_mes, ano_mes, situacao_mes FROM vw_dim_calendario
               WHERE situacao_mes IN ('Completo', 'Parcial') ORDER BY inicio_mes""",
        )
        filtros = {k: _valor(v) for k, v in conexao.execute(db.consulta("filtros")).fetchone().items()}

    colunas = ["id_item", "id_pedido", "data_pedido", "id_cliente", "id_vendedor", "id_produto",
               "quantidade", "preco_unitario", "custo_unitario"]
    documento = {
        "aviso": "Dados fictícios de portfólio. Gerados por api/exportar_demo.py a partir das views analíticas.",
        "gerado_em": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "colunas_itens": colunas,
        "itens": [[_valor(linha[c]) for c in colunas] for linha in itens],
        "produtos": produtos,
        "vendedores": vendedores,
        "meses": meses,
        "filtros": filtros,
    }
    DESTINO.parent.mkdir(parents=True, exist_ok=True)
    DESTINO.write_text(json.dumps(documento, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"{DESTINO.relative_to(PASTA_WEB.parent)}: {len(itens)} itens, {len(produtos)} produtos, "
          f"{len(vendedores)} vendedores, {len(meses)} meses")


if __name__ == "__main__":
    main()
