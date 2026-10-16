// Fonte de dados da DEMONSTRAÇÃO PÚBLICA (hospedagem estática).
// Recalcula no navegador as mesmas respostas da API, a partir de
// dados-demo/demo.json (dados fictícios exportados por api/exportar_demo.py).
// Cada função espelha uma consulta de api/techstore_api/consultas/*.sql; a
// equivalência é verificada contra a API real (docs/DASHBOARD_WEB.md).
// Valores monetários são somados em centavos inteiros e arredondados como o
// ROUND do PostgreSQL (metade para longe do zero), sem erro de ponto flutuante.

let base = null;

async function carregar() {
  if (base) return base;
  const resposta = await fetch(new URL("../dados-demo/demo.json", import.meta.url), { cache: "no-cache" });
  if (!resposta.ok) throw new Error("Não foi possível carregar os dados da demonstração.");
  const doc = await resposta.json();
  const i = Object.fromEntries(doc.colunas_itens.map((c, n) => [c, n]));
  const produtos = new Map(doc.produtos.map((p) => [p.id_produto, p]));
  const centavos = (v) => Math.round(Number(v) * 100);
  base = {
    doc,
    produtos,
    vendedores: new Map(doc.vendedores.map((v) => [v.id_vendedor, v])),
    meses: doc.meses,
    itens: doc.itens.map((l) => {
      const qtd = l[i.quantidade];
      const preco = centavos(l[i.preco_unitario]);
      const custo = centavos(l[i.custo_unitario]);
      return {
        pedido: l[i.id_pedido],
        data: l[i.data_pedido],
        mes: `${l[i.data_pedido].slice(0, 7)}-01`,
        cliente: l[i.id_cliente],
        vendedor: l[i.id_vendedor],
        produto: l[i.id_produto],
        categoria: produtos.get(l[i.id_produto]).id_categoria,
        qtd,
        fat: qtd * preco,
        custo: qtd * custo,
        lucro: qtd * (preco - custo),
      };
    }),
  };
  return base;
}

// ----------------------------------------------------------------- arredondamento exato

/** num/den arredondado para inteiro, metade para longe do zero (ROUND do PostgreSQL). */
function arredondar(num, den) {
  const sinal = (num < 0) !== (den < 0) ? -1 : 1;
  const a = Math.abs(num);
  const b = Math.abs(den);
  let q = Math.floor(a / b);
  if (2 * (a - q * b) >= b) q += 1;
  return sinal * q;
}

/** num/den arredondado para inteiro, metade para o par (round() do Python). */
function arredondarPar(num, den) {
  const sinal = (num < 0) !== (den < 0) ? -1 : 1;
  const a = Math.abs(num);
  const b = Math.abs(den);
  let q = Math.floor(a / b);
  const resto2 = 2 * (a - q * b);
  if (resto2 > b || (resto2 === b && q % 2 === 1)) q += 1;
  return sinal * q;
}

const reais = (c) => c / 100;
const pct2 = (num, den) => (den ? arredondar(10000 * num, den) / 100 : null); // ROUND(100*num/den, 2)

// ----------------------------------------------------------------- filtros

function filtrar(itens, p, { usarDatas = true } = {}) {
  const cats = p.categorias ? new Set(p.categorias) : null;
  const vends = p.vendedores ? new Set(p.vendedores) : null;
  return itens.filter((x) =>
    (!usarDatas || !p.inicio || x.data >= p.inicio)
    && (!usarDatas || !p.fim || x.data <= p.fim)
    && (!cats || cats.has(x.categoria))
    && (!vends || vends.has(x.vendedor)));
}

function normalizar(parametros, b) {
  const lista = (v) => {
    const valores = (Array.isArray(v) ? v : v === undefined || v === null || v === "" ? [] : [v]).map(Number);
    return [...new Set(valores)].sort((x, y) => x - y);
  };
  const categorias = lista(parametros.categoria);
  const vendedores = lista(parametros.vendedor);
  const idsCat = new Set(b.doc.filtros.categorias.map((c) => c.id));
  if (categorias.some((c) => !idsCat.has(c)) || vendedores.some((v) => !b.vendedores.has(v))) {
    throw new Error("Filtro com valor inexistente.");
  }
  if (parametros.inicio && parametros.fim && parametros.inicio > parametros.fim) {
    throw new Error("Período inválido: início depois do fim.");
  }
  return {
    inicio: parametros.inicio || null,
    fim: parametros.fim || null,
    categorias: categorias.length ? categorias : null,
    vendedores: vendedores.length ? vendedores : null,
  };
}

const aplicados = (p) => ({ inicio: p.inicio, fim: p.fim, categorias: p.categorias || [], vendedores: p.vendedores || [] });

function agrupar(itens, chave) {
  const grupos = new Map();
  for (const x of itens) {
    const k = chave(x);
    if (!grupos.has(k)) grupos.set(k, []);
    grupos.get(k).push(x);
  }
  return grupos;
}

function somar(itens) {
  let fat = 0, custo = 0, lucro = 0, qtd = 0;
  const pedidos = new Set();
  const clientes = new Set();
  for (const x of itens) {
    fat += x.fat; custo += x.custo; lucro += x.lucro; qtd += x.qtd;
    pedidos.add(x.pedido); clientes.add(x.cliente);
  }
  return { fat, custo, lucro, qtd, pedidos: pedidos.size, clientes: clientes.size, linhas: itens.length };
}

// Ordenação de texto equivalente à do banco para os nomes do projeto.
const porTexto = (a, b) => (a < b ? -1 : a > b ? 1 : 0);

function rankingDenso(lista, valor) {
  let rank = 0;
  let anterior = null;
  return lista.map((item) => {
    const v = valor(item);
    if (v !== anterior) { rank += 1; anterior = v; }
    return rank;
  });
}

// ----------------------------------------------------------------- endpoints

function kpis(b, p) {
  const f = filtrar(b.itens, p);
  const s = somar(f);
  const porCliente = agrupar(f, (x) => x.cliente);
  const recorrentes = [...porCliente.values()].filter((l) => new Set(l.map((x) => x.pedido)).size >= 2).length;

  const ultimoMes = b.meses.filter((m) => m.situacao_mes === "Completo").map((m) => m.inicio_mes).sort().pop();
  const doMes = (mes) => {
    const l = filtrar(b.itens, p, { usarDatas: false }).filter((x) => x.mes === mes);
    return l.length ? l.reduce((t, x) => t + x.fat, 0) : null;
  };
  const [ano, mes] = ultimoMes.split("-").map(Number);
  const anteriorIso = `${mes === 1 ? ano - 1 : ano}-${String(mes === 1 ? 12 : mes - 1).padStart(2, "0")}-01`;
  const atual = doMes(ultimoMes);
  const anterior = doMes(anteriorIso);

  return {
    filtros: aplicados(p),
    totais: {
      faturamento: reais(s.fat),
      custo: reais(s.custo),
      lucro_bruto: reais(s.lucro),
      margem_pct: pct2(s.lucro, s.fat),
      pedidos: s.pedidos,
      unidades: s.qtd,
      ticket_medio: s.pedidos ? arredondar(s.fat, s.pedidos) / 100 : null,
      itens_por_pedido: s.pedidos ? arredondar(100 * s.linhas, s.pedidos) / 100 : null,
      clientes_ativos: s.clientes,
      clientes_recorrentes: recorrentes,
      pct_clientes_recorrentes: s.clientes ? arredondarPar(1000 * recorrentes, s.clientes) / 10 : null,
    },
    ultimo_mes_completo: {
      mes: ultimoMes,
      faturamento: atual === null ? null : reais(atual),
      faturamento_mes_anterior: anterior === null ? null : reais(anterior),
      variacao_pct: atual !== null && anterior ? arredondarPar(10000 * (atual - anterior), anterior) / 100 : null,
    },
    ultima_venda: b.doc.filtros.ultima_venda,
  };
}

function vendasMensais(b, p) {
  const porMes = agrupar(filtrar(b.itens, p, { usarDatas: false }), (x) => x.mes);
  const serie = b.meses.map((m) => {
    const s = somar(porMes.get(m.inicio_mes) || []);
    return { ...m, fat: s.fat, custo: s.custo, lucro: s.lucro, pedidos: s.pedidos };
  });
  const inicioMes = p.inicio ? `${p.inicio.slice(0, 7)}-01` : null;
  return {
    filtros: aplicados(p),
    meses: serie
      .map((m, n) => {
        const anterior = n > 0 ? serie[n - 1].fat : null;
        const janela = serie.slice(Math.max(0, n - 2), n + 1);
        return {
          inicio_mes: m.inicio_mes,
          ano_mes: m.ano_mes,
          situacao_mes: m.situacao_mes,
          faturamento: reais(m.fat),
          custo: reais(m.custo),
          lucro_bruto: reais(m.lucro),
          pedidos: m.pedidos,
          variacao_pct: m.situacao_mes === "Parcial" || anterior === null || anterior === 0
            ? null : arredondar(10000 * (m.fat - anterior), anterior) / 100,
          media_movel_3m: janela.length === 3 ? arredondar(janela.reduce((t, x) => t + x.fat, 0), 3) / 100 : null,
        };
      })
      .filter((m) => (!inicioMes || m.inicio_mes >= inicioMes) && (!p.fim || m.inicio_mes <= p.fim)),
  };
}

function categorias(b, p) {
  const grupos = agrupar(filtrar(b.itens, p), (x) => x.categoria);
  const linhas = [...grupos.entries()].map(([id, l]) => {
    const s = somar(l);
    const nome = b.doc.produtos.find((pr) => pr.id_categoria === id).categoria;
    return { id_categoria: id, categoria: nome, fat: s.fat, custo: s.custo, lucro: s.lucro, qtd: s.qtd };
  });
  linhas.sort((x, y) => y.fat - x.fat || porTexto(x.categoria, y.categoria));
  return {
    filtros: aplicados(p),
    categorias: linhas.map((c) => ({
      id_categoria: c.id_categoria,
      categoria: c.categoria,
      faturamento: reais(c.fat),
      custo: reais(c.custo),
      lucro_bruto: reais(c.lucro),
      margem_pct: pct2(c.lucro, c.fat),
      unidades: c.qtd,
    })),
  };
}

function produtos(b, p, limite) {
  const grupos = agrupar(filtrar(b.itens, p), (x) => x.produto);
  const linhas = [...grupos.entries()].map(([id, l]) => ({ id, ...somar(l) }));
  linhas.sort((x, y) => y.fat - x.fat || x.id - y.id);
  const total = linhas.reduce((t, x) => t + x.fat, 0);
  const ranks = rankingDenso(linhas, (x) => x.fat);
  let acumulado = 0;
  const resultado = linhas.map((x, n) => {
    acumulado += x.fat;
    const antes = acumulado - x.fat;
    const pr = b.produtos.get(x.id);
    return {
      ranking: ranks[n],
      id_produto: x.id,
      produto: pr.produto,
      categoria: pr.categoria,
      faturamento: reais(x.fat),
      lucro_bruto: reais(x.lucro),
      unidades: x.qtd,
      pct_faturamento: pct2(x.fat, total),
      pct_acumulado: pct2(acumulado, total),
      classe_abc: 100 * antes < 80 * total ? "A" : 100 * antes < 95 * total ? "B" : "C",
    };
  });
  return { filtros: aplicados(p), limite, produtos: resultado.slice(0, limite) };
}

function vendedores(b, p) {
  const grupos = agrupar(filtrar(b.itens, p), (x) => x.vendedor);
  const linhas = [...grupos.entries()].map(([id, l]) => ({ id, nome: b.vendedores.get(id).vendedor, ...somar(l) }));
  linhas.sort((x, y) => y.fat - x.fat || porTexto(x.nome, y.nome));
  const ranks = rankingDenso(linhas, (x) => x.fat);
  return {
    filtros: aplicados(p),
    vendedores: linhas.map((v, n) => ({
      ranking: ranks[n],
      id_vendedor: v.id,
      vendedor: v.nome,
      faturamento: reais(v.fat),
      lucro_bruto: reais(v.lucro),
      margem_pct: pct2(v.lucro, v.fat),
      pedidos: v.pedidos,
      ticket_medio: v.pedidos ? arredondar(v.fat, v.pedidos) / 100 : null,
      clientes: v.clientes,
    })),
  };
}

/** Mesma interface de api.js: caminho do endpoint + parâmetros. */
export async function responder(caminho, parametros = {}) {
  const b = await carregar();
  switch (caminho) {
    case "/api/saude":
      return { status: "ok", primeira_venda: b.doc.filtros.primeira_venda, ultima_venda: b.doc.filtros.ultima_venda };
    case "/api/filtros":
      return b.doc.filtros;
    case "/api/kpis":
      return kpis(b, normalizar(parametros, b));
    case "/api/vendas-mensais":
      return vendasMensais(b, normalizar(parametros, b));
    case "/api/categorias":
      return categorias(b, normalizar(parametros, b));
    case "/api/produtos": {
      const limite = Number(parametros.limite ?? 5);
      if (!Number.isInteger(limite) || limite < 1 || limite > 50) throw new Error("Parâmetros inválidos.");
      return produtos(b, normalizar(parametros, b), limite);
    }
    case "/api/vendedores":
      return vendedores(b, normalizar(parametros, b));
    default:
      throw new Error("Recurso não encontrado.");
  }
}
