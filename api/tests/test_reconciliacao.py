"""Reconciliação da API com os valores de referência documentados
(docs/VALIDACAO.md e docs/POWERBI_GUIA.md §8, banco techstore_dev_v3)."""

import pytest

ACESSORIOS, MARCELO = 5, 5  # id_categoria e id_vendedor


def test_kpis_periodo_inteiro(cliente):
    r = cliente.get("/api/kpis")
    assert r.status_code == 200
    t = r.json()["totais"]
    assert t["faturamento"] == pytest.approx(335062.30)
    assert t["custo"] == pytest.approx(258699.00)
    assert t["lucro_bruto"] == pytest.approx(76363.30)
    assert t["margem_pct"] == pytest.approx(22.79)
    assert t["pedidos"] == 60
    assert t["unidades"] == 260
    assert t["ticket_medio"] == pytest.approx(5584.37)
    assert t["itens_por_pedido"] == pytest.approx(2.83)
    assert t["clientes_ativos"] == 40
    assert t["clientes_recorrentes"] == 15
    assert t["pct_clientes_recorrentes"] == pytest.approx(37.5)


def test_ultimo_mes_completo(cliente):
    corpo = cliente.get("/api/kpis").json()
    u = corpo["ultimo_mes_completo"]
    assert u["mes"] == "2026-07-01"
    assert u["faturamento"] == pytest.approx(40434.40)
    assert u["faturamento_mes_anterior"] == pytest.approx(41367.10)
    assert u["variacao_pct"] == pytest.approx(-2.25)
    assert corpo["ultima_venda"] == "2026-08-18"


MESES = [
    # ano_mes, faturamento, variacao_pct, media_movel_3m, situacao
    ("jan/26", 33115.90, None, None, "Completo"),
    ("fev/26", 30866.60, -6.79, None, "Completo"),
    ("mar/26", 39856.80, 29.13, 34613.10, "Completo"),
    ("abr/26", 63511.10, 59.35, 44744.83, "Completo"),
    ("mai/26", 64142.30, 0.99, 55836.73, "Completo"),
    ("jun/26", 41367.10, -35.51, 56340.17, "Completo"),
    ("jul/26", 40434.40, -2.25, 48647.93, "Completo"),
    ("ago/26", 21768.10, None, 34523.20, "Parcial"),  # variação em branco no mês parcial
]


def test_vendas_mensais(cliente):
    meses = cliente.get("/api/vendas-mensais").json()["meses"]
    assert [m["ano_mes"] for m in meses] == [m[0] for m in MESES]
    for obtido, (ano_mes, fat, var, mm3, situacao) in zip(meses, MESES):
        assert obtido["faturamento"] == pytest.approx(fat), ano_mes
        assert obtido["situacao_mes"] == situacao, ano_mes
        assert (obtido["variacao_pct"] is None) == (var is None), ano_mes
        if var is not None:
            assert obtido["variacao_pct"] == pytest.approx(var), ano_mes
        assert (obtido["media_movel_3m"] is None) == (mm3 is None), ano_mes
        if mm3 is not None:
            assert obtido["media_movel_3m"] == pytest.approx(mm3), ano_mes
    assert sum(m["faturamento"] for m in meses) == pytest.approx(335062.30)


def test_categorias(cliente):
    esperado = {
        "Informática": (148584.50, 116850.00, 31734.50, 21.36),
        "Eletrônicos": (80296.40, 62300.00, 17996.40, 22.41),
        "Monitores": (57896.10, 44400.00, 13496.10, 23.31),
        "Periféricos": (20994.90, 15530.00, 5464.90, 26.03),
        "Armazenamento": (20035.60, 14824.00, 5211.60, 26.01),
        "Acessórios": (7254.80, 4795.00, 2459.80, 33.91),
    }
    linhas = cliente.get("/api/categorias").json()["categorias"]
    assert [l["categoria"] for l in linhas] == list(esperado)  # ordem decrescente de faturamento
    for l in linhas:
        fat, custo, lucro, margem = esperado[l["categoria"]]
        assert (l["faturamento"], l["custo"], l["lucro_bruto"], l["margem_pct"]) == pytest.approx((fat, custo, lucro, margem))


def test_vendedores(cliente):
    esperado = [
        (1, "Marcelo Santos", 76661.40, 17352.40, 12, 6388.45, 10),
        (2, "Carlos Henrique", 65543.90, 14836.90, 13, 5041.84, 12),
        (3, "Rafael Martins", 65463.10, 14854.10, 11, 5951.19, 10),
        (4, "Juliana Mendes", 63861.50, 14658.50, 12, 5321.79, 10),
        (5, "Patricia Oliveira", 63532.40, 14661.40, 12, 5294.37, 10),
    ]
    linhas = cliente.get("/api/vendedores").json()["vendedores"]
    obtido = [(l["ranking"], l["vendedor"], l["faturamento"], l["lucro_bruto"], l["pedidos"], l["ticket_medio"], l["clientes"]) for l in linhas]
    assert len(obtido) == 5
    for o, e in zip(obtido, esperado):
        assert o[:2] == e[:2] and o[4] == e[4] and o[6] == e[6]
        assert (o[2], o[3], o[5]) == pytest.approx((e[2], e[3], e[5]))


def test_produtos_e_curva_abc(cliente):
    produtos = cliente.get("/api/produtos", params={"limite": 19}).json()["produtos"]
    assert len(produtos) == 19
    classes = [p["classe_abc"] for p in produtos]
    assert classes == ["A"] * 8 + ["B"] * 6 + ["C"] * 5
    assert produtos[0]["produto"] == "Notebook Dell Inspiron 15"
    assert produtos[0]["faturamento"] == pytest.approx(55898.70)
    assert produtos[7]["pct_acumulado"] == pytest.approx(81.6, abs=0.05)
    assert produtos[-1]["pct_acumulado"] == pytest.approx(100.0)
    top5 = cliente.get("/api/produtos").json()["produtos"]
    assert [p["produto"] for p in top5] == [p["produto"] for p in produtos[:5]]


def test_filtro_categoria(cliente):
    t = cliente.get("/api/kpis", params={"categoria": ACESSORIOS}).json()["totais"]
    assert t["faturamento"] == pytest.approx(7254.80)
    assert t["margem_pct"] == pytest.approx(33.91)


def test_filtro_vendedor(cliente):
    t = cliente.get("/api/kpis", params={"vendedor": MARCELO}).json()["totais"]
    assert t["faturamento"] == pytest.approx(76661.40)
    assert t["pedidos"] == 12


def test_filtro_periodo_mes_de_julho(cliente):
    params = {"inicio": "2026-07-01", "fim": "2026-07-31"}
    assert cliente.get("/api/kpis", params=params).json()["totais"]["faturamento"] == pytest.approx(40434.40)
    meses = cliente.get("/api/vendas-mensais", params=params).json()["meses"]
    assert [m["ano_mes"] for m in meses] == ["jul/26"]
    # A média móvel usa os meses anteriores ao período, como no DAX.
    assert meses[0]["media_movel_3m"] == pytest.approx(48647.93)


def test_consistencia_entre_endpoints_com_filtro(cliente):
    params = {"vendedor": MARCELO, "inicio": "2026-03-01", "fim": "2026-06-30"}
    total = cliente.get("/api/kpis", params=params).json()["totais"]["faturamento"]
    por_categoria = sum(c["faturamento"] for c in cliente.get("/api/categorias", params=params).json()["categorias"])
    por_mes = sum(m["faturamento"] for m in cliente.get("/api/vendas-mensais", params=params).json()["meses"])
    assert por_categoria == pytest.approx(total)
    assert por_mes == pytest.approx(total)
