"""Demonstração estática (web/ publicada no GitHub Pages).

Não usa banco nem API: confere os arquivos que vão para a internet. Roda também
no workflow de publicação, antes do deploy:
    python -m pytest api/tests/test_demo_estatica.py --noconftest
"""
import json
import re
from decimal import Decimal
from pathlib import Path

import pytest

WEB = Path(__file__).resolve().parents[2] / "web"
DEMO = WEB / "dados-demo" / "demo.json"

# Valores de referência do banco validado (docs/VALIDACAO.md).
REFERENCIA = {
    "faturamento": Decimal("335062.30"),
    "custo": Decimal("258699.00"),
    "pedidos": 60,
    "itens": 170,
    "unidades": 260,
    "clientes": 40,
    "recorrentes": 15,
}
COLUNAS_ITENS = [
    "id_item", "id_pedido", "data_pedido", "id_cliente", "id_vendedor",
    "id_produto", "quantidade", "preco_unitario", "custo_unitario",
]
CAMPOS_PESSOAIS = re.compile(r'"(cpf|email|e_mail|telefone|salario|nome_cliente|cliente|endereco)"', re.I)


@pytest.fixture(scope="module")
def demo():
    return json.loads(DEMO.read_text(encoding="utf-8"))


def _existe_com_mesma_grafia(caminho: Path) -> bool:
    """O GitHub Pages diferencia maiúsculas de minúsculas; o Windows não."""
    caminho = caminho.resolve()
    if not caminho.exists():
        return False
    atual = caminho
    while atual != WEB.parent and atual.parent != atual:
        if atual.name not in {p.name for p in atual.parent.iterdir()}:
            return False
        atual = atual.parent
    return True


# --------------------------------------------------------------- dados

def test_demo_reproduz_os_valores_de_referencia(demo):
    assert demo["colunas_itens"] == COLUNAS_ITENS
    i = {c: n for n, c in enumerate(demo["colunas_itens"])}
    itens = demo["itens"]
    faturamento = sum(Decimal(str(r[i["preco_unitario"]])) * r[i["quantidade"]] for r in itens)
    custo = sum(Decimal(str(r[i["custo_unitario"]])) * r[i["quantidade"]] for r in itens)
    pedidos_por_cliente = {}
    for r in itens:
        pedidos_por_cliente.setdefault(r[i["id_cliente"]], set()).add(r[i["id_pedido"]])

    assert faturamento == REFERENCIA["faturamento"]
    assert custo == REFERENCIA["custo"]
    assert len({r[i["id_pedido"]] for r in itens}) == REFERENCIA["pedidos"]
    assert len(itens) == REFERENCIA["itens"]
    assert sum(r[i["quantidade"]] for r in itens) == REFERENCIA["unidades"]
    assert len(pedidos_por_cliente) == REFERENCIA["clientes"]
    assert sum(len(p) > 1 for p in pedidos_por_cliente.values()) == REFERENCIA["recorrentes"]


def test_demo_sem_dados_pessoais(demo):
    assert not CAMPOS_PESSOAIS.search(DEMO.read_text(encoding="utf-8"))
    assert set(demo) == {"aviso", "gerado_em", "colunas_itens", "itens", "produtos", "vendedores", "meses", "filtros"}
    assert "fictícios" in demo["aviso"]


def test_referencias_dos_itens_existem(demo):
    i = {c: n for n, c in enumerate(demo["colunas_itens"])}
    produtos = {p["id_produto"] for p in demo["produtos"]}
    vendedores = {v["id_vendedor"] for v in demo["vendedores"]}
    assert all(r[i["id_produto"]] in produtos for r in demo["itens"])
    assert all(r[i["id_vendedor"]] in vendedores for r in demo["itens"])


# --------------------------------------------------------------- arquivos publicados

def test_arquivos_referenciados_pelo_html_existem_com_a_mesma_grafia():
    html = (WEB / "index.html").read_text(encoding="utf-8")
    refs = re.findall(r'(?:src|href)="([^"#?]+)"', html)
    locais = [r for r in refs if not re.match(r"^(https?:|data:|mailto:|/)", r)]
    assert "js/app.js" in locais and "css/estilos.css" in locais
    faltando = [r for r in locais if not _existe_com_mesma_grafia(WEB / r)]
    assert not faltando, faltando


def test_importacoes_dos_modulos_existem_com_a_mesma_grafia():
    faltando = []
    for js in sorted((WEB / "js").glob("*.js")):
        fonte = js.read_text(encoding="utf-8")
        alvos = re.findall(r'from\s+"(\.[^"]+)"', fonte)
        alvos += re.findall(r'import\(\s*"(\.[^"]+)"\s*\)', fonte)
        alvos += re.findall(r'new URL\(\s*"(\.[^"]+)"\s*,\s*import\.meta\.url\s*\)', fonte)
        faltando += [f"{js.name} -> {a}" for a in alvos if not _existe_com_mesma_grafia(js.parent / a)]
    assert not faltando, faltando


def test_demo_le_o_json_publicado():
    fonte = (WEB / "js" / "demo.js").read_text(encoding="utf-8")
    assert 'new URL("../dados-demo/demo.json", import.meta.url)' in fonte


# --------------------------------------------------------------- modo de demonstração

def test_fora_de_localhost_o_painel_usa_a_demonstracao():
    fonte = (WEB / "js" / "config.js").read_text(encoding="utf-8")
    hosts = json.loads(re.search(r"HOSTS_LOCAIS = new Set\((\[.*?\])\);", fonte).group(1))
    assert sorted(hosts) == sorted(["localhost", "127.0.0.1", "[::1]", "::1"])
    assert 'export const MODO = local && pedido !== "demo" ? "api" : "demo";' in fonte


def test_demonstracao_nao_faz_requisicoes_de_rede_para_a_api():
    api = (WEB / "js" / "api.js").read_text(encoding="utf-8")
    # No modo demo, obter() retorna antes de qualquer fetch.
    assert api.index('if (MODO === "demo")') < api.index("fetch(")
    for nome in ("demo.js", "app.js", "graficos.js", "formatos.js", "icones.js", "verificar-carga.js"):
        assert "127.0.0.1" not in (WEB / "js" / nome).read_text(encoding="utf-8"), nome


def test_textos_iniciais_nao_dependem_da_api_local():
    html = (WEB / "index.html").read_text(encoding="utf-8")
    assert '<span id="texto-conexao">Carregando…</span>' in html
    assert "Conectando à API local" not in html
    assert '<span id="rodape-fonte">Fonte: views analíticas do PostgreSQL (instância de testes).</span>' in html
    assert "API local" not in re.search(r'TEXTO_FONTE = MODO === "demo"\s*\?\s*"([^"]+)"', (WEB / "js" / "config.js").read_text(encoding="utf-8")).group(1)


def test_falha_de_carregamento_e_sinalizada():
    html = (WEB / "index.html").read_text(encoding="utf-8")
    # Script clássico (sem type="module"), depois de app.js: roda mesmo se um módulo falhar.
    assert '<script src="js/verificar-carga.js" defer></script>' in html
    assert html.index('src="js/app.js"') < html.index('src="js/verificar-carga.js"')
    app = (WEB / "js" / "app.js").read_text(encoding="utf-8")
    assert 'document.body.dataset.iniciado = "true"' in app
    assert "<noscript>" in html
