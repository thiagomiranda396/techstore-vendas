// Painel comercial Techstore Vendas.
// Todo texto vindo da API entra na página por textContent (nunca innerHTML).
// Nenhum valor é inventado: indicadores, comparações e destaques são calculados
// a partir das respostas da API somente leitura.

import { obter } from "./api.js";
import {
  MODO, PARAMETRO_FONTE, TEXTO_CARREGANDO, TEXTO_CONEXAO, TEXTO_FONTE, TEXTO_INDISPONIVEL, TEXTO_SEM_DADOS,
} from "./config.js";
import { fmt, mesParcial, ultimoDiaDoMes } from "./formatos.js";
import { configurarChartJs, graficoMargem, graficoPareto, graficoPedidos, graficoTendencia, graficoTicket } from "./graficos.js";
import { aplicarIcones, icone } from "./icones.js";

const $ = (id) => document.getElementById(id);
const RE_MES = /^\d{4}-(0[1-9]|1[0-2])$/;

const estado = {
  filtros: null,
  min: null,          // primeiro mês com vendas (AAAA-MM)
  max: null,          // último mês com vendas (AAAA-MM)
  mesParcial: null,   // último mês, se incompleto (AAAA-MM) ou null
  categorias: new Map(),
  vendedores: new Map(),
  requisicao: 0,
  dados: null,
};

// ================================================================= utilidades

function somarMeses(anoMes, n) {
  let [ano, mes] = anoMes.split("-").map(Number);
  mes += n;
  ano += Math.floor((mes - 1) / 12);
  mes = (((mes - 1) % 12) + 12) % 12 + 1;
  return `${ano}-${String(mes).padStart(2, "0")}`;
}

function difMeses(de, ate) {
  const [a1, m1] = de.split("-").map(Number);
  const [a2, m2] = ate.split("-").map(Number);
  return (a2 - a1) * 12 + (m2 - m1);
}

function el(tag, { classe, texto, atributos } = {}, filhos = []) {
  const no = document.createElement(tag);
  if (classe) no.className = classe;
  if (texto !== undefined) no.textContent = texto;
  if (atributos) Object.entries(atributos).forEach(([k, v]) => no.setAttribute(k, v));
  filhos.forEach((f) => no.append(f));
  return no;
}

function iniciais(nome) {
  return nome.split(/\s+/).filter(Boolean).slice(0, 2).map((p) => p[0].toUpperCase()).join("");
}

// ================================================================= conexão e alertas

function marcarConexao(situacao, texto) {
  $("conexao").dataset.estado = situacao;
  $("texto-conexao").textContent = texto;
}

function mostrarAlerta(texto, titulo = "Não foi possível atualizar os dados") {
  $("alerta-titulo").textContent = titulo;
  $("alerta-texto").textContent = texto;
  $("alerta").hidden = false;
}

function esconderAlerta() {
  $("alerta").hidden = true;
}

// ================================================================= menu lateral (telas menores)

const telaPequena = window.matchMedia("(max-width: 1023px)");

function sincronizarInerte() {
  const lateral = $("lateral");
  lateral.inert = telaPequena.matches && !lateral.classList.contains("aberta");
}

function abrirMenu() {
  $("lateral").classList.add("aberta");
  $("sobreposicao").hidden = false;
  document.body.classList.add("menu-aberto");
  $("abrir-menu").setAttribute("aria-expanded", "true");
  sincronizarInerte();
  $("fechar-menu").focus();
}

function fecharMenu(devolverFoco = true) {
  if (!$("lateral").classList.contains("aberta")) return;
  $("lateral").classList.remove("aberta");
  $("sobreposicao").hidden = true;
  document.body.classList.remove("menu-aberto");
  $("abrir-menu").setAttribute("aria-expanded", "false");
  sincronizarInerte();
  if (devolverFoco) $("abrir-menu").focus();
}

function configurarMenu() {
  $("abrir-menu").addEventListener("click", abrirMenu);
  $("fechar-menu").addEventListener("click", () => fecharMenu());
  $("sobreposicao").addEventListener("click", () => fecharMenu());
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") fecharMenu();
  });
  telaPequena.addEventListener("change", () => {
    fecharMenu(false);
    sincronizarInerte();
  });
  sincronizarInerte();
}

function configurarNavegacao() {
  const links = [...document.querySelectorAll(".nav__link")];
  links.forEach((link) => link.addEventListener("click", () => {
    if (telaPequena.matches) fecharMenu(false);
  }));
  if (!("IntersectionObserver" in window)) return;
  const observador = new IntersectionObserver(
    (entradas) => {
      entradas.forEach((entrada) => {
        if (!entrada.isIntersecting) return;
        links.forEach((l) => l.setAttribute("aria-current", String(l.dataset.secao === entrada.target.id)));
      });
    },
    { rootMargin: "-20% 0px -70% 0px" },
  );
  links.forEach((l) => {
    const secao = document.getElementById(l.dataset.secao);
    if (secao) observador.observe(secao);
  });
  links[0]?.setAttribute("aria-current", "true");
}

// ================================================================= filtros

function montarOpcoes(idContainer, opcoes) {
  $(idContainer).replaceChildren(
    ...opcoes.map((o) => {
      const caixa = el("input", { atributos: { type: "checkbox", value: String(o.id) } });
      caixa.addEventListener("change", agendarAtualizacao);
      return el("label", { classe: "opcao" }, [caixa, el("span", { texto: o.nome })]);
    }),
  );
}

function marcados(idContainer) {
  return [...$(idContainer).querySelectorAll("input:checked")].map((c) => Number(c.value));
}

function definirMarcados(idContainer, ids) {
  const escolhidos = new Set(ids);
  $(idContainer).querySelectorAll("input").forEach((c) => {
    c.checked = escolhidos.has(Number(c.value));
  });
}

function limitarMes(anoMes) {
  if (!anoMes || !RE_MES.test(anoMes)) return null;
  if (anoMes < estado.min) return estado.min;
  if (anoMes > estado.max) return estado.max;
  return anoMes;
}

function definirPeriodo(de, ate) {
  $("f-inicio").value = de;
  $("f-fim").value = ate;
}

function selecao() {
  let de = limitarMes($("f-inicio").value) || estado.min;
  let ate = limitarMes($("f-fim").value) || estado.max;
  if (de > ate) [de, ate] = [ate, de];
  return { de, ate, categorias: marcados("f-categoria"), vendedores: marcados("f-vendedor") };
}

function parametrosApi(sel) {
  return {
    inicio: `${sel.de}-01`,
    fim: ultimoDiaDoMes(sel.ate),
    categoria: sel.categorias,
    vendedor: sel.vendedores,
  };
}

function periodoCompleto(sel) {
  return sel.de === estado.min && sel.ate === estado.max;
}

function quantidadeFiltros(sel) {
  return (periodoCompleto(sel) ? 0 : 1) + sel.categorias.length + sel.vendedores.length;
}

/** Atalhos de período calculados a partir dos dados (meses completos). */
function atalhosPeriodo() {
  const ultimoCompleto = estado.mesParcial ? somarMeses(estado.max, -1) : estado.max;
  const atalhos = [{ rotulo: "Período todo", de: estado.min, ate: estado.max }];
  if (difMeses(estado.min, ultimoCompleto) >= 2) {
    atalhos.push({ rotulo: "Últimos 3 meses completos", de: somarMeses(ultimoCompleto, -2), ate: ultimoCompleto });
  }
  const [anoIni] = estado.min.split("-").map(Number);
  const [anoFim] = estado.max.split("-").map(Number);
  for (let ano = anoIni; ano <= anoFim; ano += 1) {
    for (let tri = 1; tri <= 4; tri += 1) {
      const de = `${ano}-${String(tri * 3 - 2).padStart(2, "0")}`;
      const ate = `${ano}-${String(tri * 3).padStart(2, "0")}`;
      if (de >= estado.min && ate <= ultimoCompleto) {
        atalhos.push({ rotulo: `${tri}º tri/${String(ano).slice(2)}`, de, ate });
      }
    }
  }
  return atalhos;
}

function montarAtalhos() {
  $("atalhos-periodo").replaceChildren(
    ...atalhosPeriodo().map((a) => {
      const botao = el("button", { classe: "atalho", texto: a.rotulo, atributos: { type: "button", "aria-pressed": "false" } });
      botao.dataset.de = a.de;
      botao.dataset.ate = a.ate;
      botao.addEventListener("click", () => {
        definirPeriodo(a.de, a.ate);
        atualizar();
      });
      return botao;
    }),
  );
}

function lerUrl() {
  const q = new URLSearchParams(window.location.search);
  // Na URL, mês inválido ou fora do intervalo com dados é ignorado (não ajustado).
  const valido = (anoMes) => (anoMes && RE_MES.test(anoMes) && anoMes >= estado.min && anoMes <= estado.max ? anoMes : null);
  const de = valido(q.get("de"));
  const ate = valido(q.get("ate"));
  if (de) $("f-inicio").value = de;
  if (ate) $("f-fim").value = ate;
  const ids = (nome, mapa) => q.getAll(nome).map(Number).filter((id) => Number.isInteger(id) && mapa.has(id));
  definirMarcados("f-categoria", ids("categoria", estado.categorias));
  definirMarcados("f-vendedor", ids("vendedor", estado.vendedores));
}

function escreverUrl(sel) {
  const q = new URLSearchParams();
  if (sel.de !== estado.min) q.set("de", sel.de);
  if (sel.ate !== estado.max) q.set("ate", sel.ate);
  sel.categorias.forEach((id) => q.append("categoria", String(id)));
  sel.vendedores.forEach((id) => q.append("vendedor", String(id)));
  if (PARAMETRO_FONTE) q.set("fonte", PARAMETRO_FONTE);
  const busca = q.toString();
  window.history.replaceState(null, "", `${window.location.pathname}${busca ? `?${busca}` : ""}${window.location.hash}`);
}

function redefinirFiltros() {
  definirPeriodo(estado.min, estado.max);
  definirMarcados("f-categoria", []);
  definirMarcados("f-vendedor", []);
  atualizar();
}

function chipFiltro(texto, remover) {
  const botao = el("button", { atributos: { type: "button", "aria-label": `Remover filtro: ${texto}` } }, [icone("fechar")]);
  botao.addEventListener("click", remover);
  return el("span", { classe: "filtro-ativo" }, [el("span", { texto }), botao]);
}

function renderEstadoFiltros(sel) {
  // Mantém os campos coerentes com o período efetivamente aplicado (limitado e ordenado).
  definirPeriodo(sel.de, sel.ate);

  const chips = [];
  if (!periodoCompleto(sel)) {
    chips.push(chipFiltro(`Período: ${fmt.intervaloMeses(sel.de, sel.ate)}`, () => {
      definirPeriodo(estado.min, estado.max);
      atualizar();
    }));
  }
  sel.categorias.forEach((id) => chips.push(chipFiltro(estado.categorias.get(id), () => {
    definirMarcados("f-categoria", marcados("f-categoria").filter((x) => x !== id));
    atualizar();
  })));
  sel.vendedores.forEach((id) => chips.push(chipFiltro(estado.vendedores.get(id), () => {
    definirMarcados("f-vendedor", marcados("f-vendedor").filter((x) => x !== id));
    atualizar();
  })));
  $("filtros-ativos").replaceChildren(...chips);

  const n = quantidadeFiltros(sel);
  for (const id of ["contador-filtros", "contador-filtros-movel"]) {
    $(id).hidden = n === 0;
    $(id).textContent = String(n);
  }
  $("limpar").disabled = n === 0;

  document.querySelectorAll(".atalho").forEach((b) => {
    b.setAttribute("aria-pressed", String(b.dataset.de === sel.de && b.dataset.ate === sel.ate));
  });

  $("chip-periodo").textContent = `Período: ${fmt.intervaloMeses(sel.de, sel.ate)}`;
  // Com período filtrado, a etiqueta removível já mostra o período: evita repetir no cabeçalho.
  $("chip-periodo").parentElement.hidden = !periodoCompleto(sel);
  const parcial = estado.mesParcial && sel.ate === estado.mesParcial;
  $("chip-parcial").hidden = !parcial;
  if (parcial) {
    $("chip-parcial").textContent = `${fmt.mesAno(`${estado.mesParcial}-01`)} parcial: dados até ${fmt.data(estado.filtros.ultima_venda)}`;
  }
}

function montarFiltros(filtros) {
  estado.filtros = filtros;
  estado.min = filtros.primeira_venda.slice(0, 7);
  estado.max = filtros.ultima_venda.slice(0, 7);
  estado.mesParcial = mesParcial(filtros.ultima_venda) ? estado.max : null;
  estado.categorias = new Map(filtros.categorias.map((c) => [c.id, c.nome]));
  estado.vendedores = new Map(filtros.vendedores.map((v) => [v.id, v.nome]));

  for (const id of ["f-inicio", "f-fim"]) {
    $(id).min = estado.min;
    $(id).max = estado.max;
    $(id).addEventListener("change", agendarAtualizacao);
  }
  definirPeriodo(estado.min, estado.max);
  montarOpcoes("f-categoria", filtros.categorias);
  montarOpcoes("f-vendedor", filtros.vendedores);
  montarAtalhos();
  $("limpar").addEventListener("click", redefinirFiltros);
  lerUrl();
  $("rodape-ultima").textContent = `Última venda registrada: ${fmt.data(filtros.ultima_venda)}.`;
}

let temporizador;
function agendarAtualizacao() {
  clearTimeout(temporizador);
  temporizador = setTimeout(atualizar, 150);
}

// ================================================================= comparação entre períodos

/**
 * Período anterior de mesma duração. Só é válido quando há dados para ele e
 * quando o período atual não inclui o mês parcial (comparação seria desigual).
 */
function comparacao(sel) {
  const meses = difMeses(sel.de, sel.ate) + 1;
  if (estado.mesParcial && sel.ate === estado.mesParcial) {
    return { valida: false, motivo: `o período inclui ${fmt.mesExtenso(`${estado.mesParcial}-01`)}, que é parcial` };
  }
  const de = somarMeses(sel.de, -meses);
  const ate = somarMeses(sel.de, -1);
  if (de < estado.min) {
    return { valida: false, motivo: "não há dados para um período anterior de mesma duração" };
  }
  return { valida: true, de, ate, rotulo: fmt.intervaloMeses(de, ate) };
}

// ================================================================= KPIs

const KPIS = [
  {
    id: "faturamento", titulo: "Faturamento", icone: "receita", destaque: true,
    valor: (t) => t.faturamento, formatar: fmt.moedaCompacta, completo: fmt.moeda,
    serie: (m) => m.faturamento, tipo: "pct",
    contexto: (t) => `Custo dos produtos: ${fmt.moedaCompacta(t.custo)}`,
  },
  {
    id: "lucro", titulo: "Lucro bruto", icone: "lucro",
    valor: (t) => t.lucro_bruto, formatar: fmt.moedaCompacta, completo: fmt.moeda,
    serie: (m) => m.lucro_bruto, tipo: "pct",
    contexto: () => "Faturamento menos custo dos produtos",
  },
  {
    id: "margem", titulo: "Margem bruta", icone: "margem",
    valor: (t) => t.margem_pct, formatar: (v) => fmt.pct(v, 1),
    serie: (m) => (m.faturamento ? (100 * m.lucro_bruto) / m.faturamento : null), tipo: "pp",
    contexto: () => "Lucro bruto ÷ faturamento",
  },
  {
    id: "pedidos", titulo: "Pedidos", icone: "pedidos",
    valor: (t) => t.pedidos, formatar: fmt.inteiro,
    serie: (m) => m.pedidos, tipo: "pct",
    contexto: (t) => `${fmt.decimal(t.itens_por_pedido, 1)} itens por pedido`,
  },
  {
    id: "ticket", titulo: "Ticket médio", icone: "ticket",
    valor: (t) => t.ticket_medio, formatar: fmt.moeda,
    serie: (m) => (m.pedidos ? m.faturamento / m.pedidos : null), tipo: "pct",
    contexto: (t) => `${fmt.inteiro(t.clientes_ativos)} clientes · ${fmt.pct(t.pct_clientes_recorrentes, 1)} recorrentes`,
  },
  {
    id: "unidades", titulo: "Unidades vendidas", icone: "unidades",
    valor: (t) => t.unidades, formatar: fmt.inteiro,
    serie: null, tipo: "pct",
    contexto: (t) => `Preço médio: ${fmt.moeda(t.unidades ? t.faturamento / t.unidades : null)} por unidade`,
  },
];

const SVG = "http://www.w3.org/2000/svg";

function svgEl(tag, atributos) {
  const no = document.createElementNS(SVG, tag);
  Object.entries(atributos).forEach(([k, v]) => no.setAttribute(k, String(v)));
  return no;
}

/** Minigráfico de tendência mensal (meses completos). */
function sparkline(valores, rotulo) {
  const pontos = valores
    .map((v, i) => [i, v])
    .filter(([, v]) => v !== null && v !== undefined && !Number.isNaN(v));
  if (pontos.length < 2) return null;
  const L = 96, A = 36, M = 3;
  const xs = pontos.map((p) => p[0]);
  const ys = pontos.map((p) => p[1]);
  const [x0, x1, y0, y1] = [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys)];
  const px = (x) => M + ((x - x0) / (x1 - x0 || 1)) * (L - 2 * M);
  const py = (y) => A - M - (y1 === y0 ? 0.5 : (y - y0) / (y1 - y0)) * (A - 2 * M);
  const coords = pontos.map(([x, y]) => [px(x), py(y)]);
  const linha = coords.map(([x, y]) => `${x.toFixed(1)},${y.toFixed(1)}`).join(" ");
  const [ux, uy] = coords[coords.length - 1];

  const svg = svgEl("svg", { viewBox: `0 0 ${L} ${A}`, class: "kpi__spark", role: "img", "aria-label": rotulo });
  svg.append(
    svgEl("path", {
      d: `M${coords[0][0].toFixed(1)},${A - M} L${linha.replaceAll(" ", " L")} L${ux.toFixed(1)},${A - M} Z`,
      fill: "currentColor",
      "fill-opacity": 0.12,
      stroke: "none",
    }),
    svgEl("polyline", { points: linha, fill: "none", stroke: "currentColor", "stroke-width": 2, "stroke-linejoin": "round", "stroke-linecap": "round" }),
    svgEl("circle", { cx: ux.toFixed(1), cy: uy.toFixed(1), r: 2.6, fill: "currentColor" }),
  );
  return svg;
}

function mesAnteriorIso(isoMes) {
  return `${somarMeses(isoMes.slice(0, 7), -1)}-01`;
}

function cartaoKpi(def, dados) {
  const { kpis, anterior, cmp, meses } = dados;
  const t = kpis.totais;
  const semVendas = t.pedidos === 0;
  const valor = def.valor(t);

  const cartao = el("article", { classe: `kpi${def.destaque ? " kpi--destaque" : ""}`, atributos: { "aria-labelledby": `kpi-t-${def.id}` } });
  cartao.dataset.kpi = def.id;
  const cab = el("div", { classe: "kpi__cab" }, [
    el("span", { classe: "kpi__icone" }, [icone(def.icone)]),
    el("h2", { classe: "kpi__titulo", texto: def.titulo, atributos: { id: `kpi-t-${def.id}` } }),
  ]);
  const campoValor = el("p", { classe: "kpi__valor", texto: semVendas ? "—" : def.formatar(valor) });
  if (def.completo && !semVendas) campoValor.title = def.completo(valor);

  const variacao = el("p", { classe: "kpi__variacao" });
  if (!semVendas && anterior) {
    const ant = def.valor(anterior.totais);
    let delta;
    if (def.tipo === "pp") delta = fmt.pontos(valor - ant);
    else delta = ant ? fmt.variacao((100 * (valor - ant)) / ant) : { texto: "sem base anterior", classe: "" };
    variacao.append(el("span", { classe: `variacao ${delta.classe}`, texto: delta.texto }), ` vs ${cmp.rotulo}`);
  } else if (!semVendas && def.id === "faturamento") {
    const u = kpis.ultimo_mes_completo;
    if (u && u.mes && u.faturamento !== null && u.faturamento !== undefined) {
      const delta = fmt.variacao(u.variacao_pct);
      variacao.title = `Último mês completo (${fmt.mesExtenso(u.mes)}): ${fmt.moeda(u.faturamento)}; mês anterior: ${fmt.moeda(u.faturamento_mes_anterior)}`;
      variacao.append(
        el("span", { classe: `variacao ${delta.classe}`, texto: delta.texto }),
        ` ${fmt.mesAno(u.mes)} vs ${fmt.mesAno(mesAnteriorIso(u.mes))}`,
      );
    }
  }
  const contexto = el("p", { classe: "kpi__contexto", texto: semVendas ? "Sem vendas para os filtros selecionados" : def.contexto(t) });
  cartao.append(cab, campoValor, variacao, contexto);

  if (def.serie && !semVendas) {
    const completos = meses.filter((m) => m.situacao_mes !== "Parcial");
    const spark = sparkline(completos.map(def.serie), `Tendência mensal de ${def.titulo.toLowerCase()} (meses completos)`);
    if (spark) cartao.append(spark);
  }
  return cartao;
}

function renderKpis(dados) {
  $("kpis").replaceChildren(...KPIS.map((def) => cartaoKpi(def, dados)));
  const { sel, cmp } = dados;
  if (dados.kpis.totais.pedidos === 0) {
    $("nota-comparacao").textContent = "Sem vendas para os filtros selecionados. Ajuste ou redefina os filtros na lateral.";
    return;
  }
  $("nota-comparacao").textContent = cmp.valida
    ? `Variações dos cartões: ${fmt.intervaloMeses(sel.de, sel.ate)} comparado ao período anterior de mesma duração (${cmp.rotulo}). Minigráficos: tendência mensal dos meses completos.`
    : `Sem comparação entre períodos: ${cmp.motivo}. O faturamento mostra a variação do último mês completo da base sobre o mês anterior (respeitando categorias e vendedores). Minigráficos: tendência mensal dos meses completos.`;
}

// ================================================================= destaques

function renderDestaques({ kpis, meses, categorias, produtos }) {
  const t = kpis.totais;
  const itens = [];
  if (t.pedidos > 0) {
    const completos = meses.filter((m) => m.situacao_mes === "Completo" && m.faturamento > 0);
    if (completos.length >= 2) {
      const melhor = completos.reduce((a, b) => (b.faturamento > a.faturamento ? b : a));
      itens.push([`Melhor mês: ${fmt.mesExtenso(melhor.inicio_mes)}`, `${fmt.moeda(melhor.faturamento)} de faturamento, o maior entre os meses completos do período.`]);
    }
    if (categorias.length) {
      const lider = categorias[0];
      itens.push([`${lider.categoria} lidera a receita`, `${fmt.pct((100 * lider.faturamento) / t.faturamento, 1)} do faturamento do período.`]);
    }
    if (categorias.length >= 2) {
      const ord = [...categorias].sort((a, b) => b.margem_pct - a.margem_pct);
      const menor = ord[ord.length - 1];
      itens.push([`Maior margem: ${ord[0].categoria}`, `${fmt.pct(ord[0].margem_pct, 1)} de margem bruta, contra ${fmt.pct(menor.margem_pct, 1)} em ${menor.categoria}.`]);
    }
    const classeA = produtos.filter((p) => p.classe_abc === "A");
    if (produtos.length >= 3 && classeA.length) {
      itens.push([
        `${classeA.length} de ${produtos.length} produtos somam ${fmt.pct(classeA[classeA.length - 1].pct_acumulado, 1)} da receita`,
        "Concentração da classe A na curva ABC do período.",
      ]);
    }
    if (t.clientes_ativos) {
      itens.push([`${fmt.pct(t.pct_clientes_recorrentes, 1)} de clientes recorrentes`, `${fmt.inteiro(t.clientes_recorrentes)} de ${fmt.inteiro(t.clientes_ativos)} clientes fizeram mais de um pedido no período.`]);
    }
  }
  $("lista-destaques").replaceChildren(
    ...(itens.length
      ? itens.map(([titulo, texto]) => el("li", { classe: "destaque" }, [el("strong", { texto: titulo }), texto]))
      : [el("li", { classe: "destaque", texto: "Sem vendas para os filtros selecionados." })]),
  );
}

// ================================================================= listas com barras

function barraItem({ posicao, nome, sub, valor, subValor, proporcao }) {
  const preenchimento = el("div", { classe: "barra-trilho__preenchimento" });
  preenchimento.style.width = `${Math.max(0, Math.min(1, proporcao || 0)) * 100}%`; // CSSOM: permitido pela CSP
  const filhos = [];
  if (posicao !== undefined) filhos.push(el("span", { classe: "posicao", texto: String(posicao) }));
  filhos.push(el("span", { classe: "barra-item__nome", atributos: { title: nome } }, [nome, el("small", { texto: sub })]));
  filhos.push(el("span", { classe: "barra-item__valor" }, [valor, el("small", { texto: subValor })]));
  filhos.push(el("div", { classe: "barra-trilho", atributos: { "aria-hidden": "true" } }, [preenchimento]));
  return el("li", { classe: "barra-item" }, filhos);
}

function renderMix(categorias, total) {
  const maior = Math.max(...categorias.map((c) => c.faturamento), 0);
  $("lista-mix").replaceChildren(
    ...categorias.map((c) => barraItem({
      nome: c.categoria,
      sub: `${fmt.inteiro(c.unidades)} unidades · margem ${fmt.pct(c.margem_pct, 1)}`,
      valor: fmt.moeda(c.faturamento),
      subValor: `${fmt.pct(total ? (100 * c.faturamento) / total : 0, 1)} do total`,
      proporcao: maior ? c.faturamento / maior : 0,
    })),
  );
}

function renderRentaveis(produtos) {
  const top = [...produtos].sort((a, b) => b.lucro_bruto - a.lucro_bruto).slice(0, 5);
  const maior = top.length ? top[0].lucro_bruto : 0;
  $("lista-rentaveis").replaceChildren(
    ...top.map((p, i) => barraItem({
      posicao: i + 1,
      nome: p.produto,
      sub: p.categoria,
      valor: fmt.moeda(p.lucro_bruto),
      subValor: `margem ${fmt.pct(p.faturamento ? (100 * p.lucro_bruto) / p.faturamento : null, 1)}`,
      proporcao: maior ? p.lucro_bruto / maior : 0,
    })),
  );
}

function renderLegendaAbc(produtos) {
  const itens = ["A", "B", "C"].map((classe) => {
    const lista = produtos.filter((p) => p.classe_abc === classe);
    const soma = lista.reduce((s, p) => s + p.pct_faturamento, 0);
    return el("li", {}, [
      el("span", { classe: `amostra amostra--${classe.toLowerCase()}`, atributos: { "aria-hidden": "true" } }),
      el("span", {}, [el("strong", { texto: `Classe ${classe}` }), ` · ${lista.length} produtos · ${fmt.pct(soma, 1)}`]),
    ]);
  });
  itens.push(el("li", {}, [el("span", { classe: "amostra amostra--linha", atributos: { "aria-hidden": "true" } }), "% acumulado"]));
  $("legenda-abc").replaceChildren(...itens);
}

function renderVendedores(vendedores, total) {
  const maior = Math.max(...vendedores.map((v) => v.faturamento), 0);
  const linhas = vendedores.map((v) => {
    const preenchimento = el("div", { classe: "barra-trilho__preenchimento" });
    preenchimento.style.width = `${maior ? (100 * v.faturamento) / maior : 0}%`;
    return el("tr", {}, [
      el("td", { classe: "num" }, [el("span", { classe: "posicao", texto: String(v.ranking) })]),
      el("td", {}, [el("span", { classe: "celula-vendedor" }, [el("span", { classe: "avatar-mini", texto: iniciais(v.vendedor), atributos: { "aria-hidden": "true" } }), v.vendedor])]),
      el("td", {}, [
        el("div", { classe: "celula-barra" }, [
          el("div", { classe: "barra-trilho", atributos: { "aria-hidden": "true" } }, [preenchimento]),
          el("span", {}, [fmt.moeda(v.faturamento), " ", el("small", { texto: fmt.pct(total ? (100 * v.faturamento) / total : 0, 1) })]),
        ]),
      ]),
      el("td", { classe: "num", texto: fmt.moeda(v.lucro_bruto) }),
      el("td", { classe: "num", texto: fmt.pct(v.margem_pct, 1) }),
      el("td", { classe: "num", texto: fmt.inteiro(v.pedidos) }),
      el("td", { classe: "num", texto: fmt.moeda(v.ticket_medio) }),
      el("td", { classe: "num", texto: fmt.inteiro(v.clientes) }),
    ]);
  });
  if (!linhas.length) {
    linhas.push(el("tr", {}, [el("td", { texto: "Sem vendas para os filtros selecionados.", atributos: { colspan: "8" } })]));
  }
  $("tabela-vendedores").querySelector("tbody").replaceChildren(...linhas);
}

// ================================================================= tabelas alternativas

function tabela(colunas, linhas, legenda) {
  const cab = el("tr", {}, colunas.map((c) => el("th", { classe: c.num ? "num" : "", texto: c.titulo, atributos: { scope: "col" } })));
  const corpo = linhas.map((l) => el("tr", {}, colunas.map((c) => el("td", { classe: c.num ? "num" : "", texto: c.valor(l) }))));
  return el("div", { classe: "tabela-rolagem" }, [
    el("table", { classe: "tabela" }, [
      el("caption", { classe: "visualmente-oculto", texto: legenda }),
      el("thead", {}, [cab]),
      el("tbody", {}, corpo),
    ]),
  ]);
}

const rotuloMes = (m) => (m.situacao_mes === "Parcial" ? `${m.ano_mes} (parcial)` : m.ano_mes);

function renderTabelasAlternativas({ meses, categorias, produtos, kpis }) {
  $("tab-tendencia").replaceChildren(tabela([
    { titulo: "Mês", valor: rotuloMes },
    { titulo: "Faturamento", num: true, valor: (m) => fmt.moeda(m.faturamento) },
    { titulo: "Custo", num: true, valor: (m) => fmt.moeda(m.custo) },
    { titulo: "Lucro bruto", num: true, valor: (m) => fmt.moeda(m.lucro_bruto) },
    { titulo: "Margem", num: true, valor: (m) => fmt.pct(m.faturamento ? (100 * m.lucro_bruto) / m.faturamento : null, 1) },
    { titulo: "Média móvel 3m", num: true, valor: (m) => fmt.moeda(m.media_movel_3m) },
  ], meses, "Faturamento, custo e lucro por mês"));

  $("tab-ritmo").replaceChildren(tabela([
    { titulo: "Mês", valor: rotuloMes },
    { titulo: "Pedidos", num: true, valor: (m) => fmt.inteiro(m.pedidos) },
    { titulo: "Ticket médio", num: true, valor: (m) => fmt.moeda(m.pedidos ? m.faturamento / m.pedidos : null) },
  ], meses, "Pedidos e ticket médio por mês"));

  const geral = kpis.totais.margem_pct;
  $("tab-margem").replaceChildren(tabela([
    { titulo: "Categoria", valor: (c) => c.categoria },
    { titulo: "Margem", num: true, valor: (c) => fmt.pct(c.margem_pct, 1) },
    { titulo: "vs geral", num: true, valor: (c) => fmt.pontos(c.margem_pct - geral).texto },
    { titulo: "Faturamento", num: true, valor: (c) => fmt.moeda(c.faturamento) },
  ], [...categorias].sort((a, b) => b.margem_pct - a.margem_pct), "Margem bruta por categoria"));

  $("tab-pareto").replaceChildren(tabela([
    { titulo: "#", num: true, valor: (p) => String(p.ranking) },
    { titulo: "Produto", valor: (p) => p.produto },
    { titulo: "Faturamento", num: true, valor: (p) => fmt.moeda(p.faturamento) },
    { titulo: "%", num: true, valor: (p) => fmt.pct(p.pct_faturamento, 1) },
    { titulo: "% acum.", num: true, valor: (p) => fmt.pct(p.pct_acumulado, 1) },
    { titulo: "Classe", valor: (p) => p.classe_abc },
  ], produtos, "Curva ABC de produtos"));
}

function ligarAlternadores() {
  document.querySelectorAll(".alternar").forEach((botao) => {
    botao.addEventListener("click", () => {
      const cartao = botao.closest(".cartao");
      const mostrarTabela = botao.getAttribute("aria-pressed") !== "true";
      botao.setAttribute("aria-pressed", String(mostrarTabela));
      botao.querySelector("span:last-child").textContent = mostrarTabela ? "Gráfico" : "Tabela";
      $(`tab-${botao.dataset.alvo}`).hidden = !mostrarTabela;
      cartao.querySelectorAll(".grafico, .grafico-duplo").forEach((g) => {
        if (!g.parentElement.classList.contains("grafico-duplo")) g.hidden = mostrarTabela;
      });
    });
  });
}

// ================================================================= estado vazio e descrições acessíveis

function marcarVazio(semVendas) {
  document.querySelectorAll(".cartao").forEach((cartao) => {
    const aviso = cartao.querySelector(".vazio");
    if (!aviso) return;
    cartao.dataset.vazio = String(semVendas);
    aviso.hidden = !semVendas;
  });
}

function descreverGraficos({ meses, categorias, produtos, kpis }) {
  if (meses.length) {
    const pico = meses.reduce((a, b) => (b.faturamento > a.faturamento ? b : a));
    $("g-tendencia").setAttribute("aria-label", `Faturamento, custo e lucro de ${meses[0].ano_mes} a ${meses[meses.length - 1].ano_mes}. Maior faturamento em ${pico.ano_mes}: ${fmt.moeda(pico.faturamento)}.`);
  }
  if (categorias.length) {
    const ord = [...categorias].sort((a, b) => b.margem_pct - a.margem_pct);
    $("g-margem").setAttribute("aria-label", `Margem bruta por categoria. Margem geral ${fmt.pct(kpis.totais.margem_pct, 1)}. Maior: ${ord[0].categoria}, ${fmt.pct(ord[0].margem_pct, 1)}.`);
  }
  if (produtos.length) {
    $("g-pareto").setAttribute("aria-label", `Curva ABC com ${produtos.length} produtos. Primeiro: ${produtos[0].produto}, ${fmt.pct(produtos[0].pct_faturamento, 1)} do faturamento.`);
  }
  $("s-margem").textContent = `Azul: acima da margem geral do período (${fmt.pct(kpis.totais.margem_pct, 1)}) · cinza: abaixo`;
}

// ================================================================= ciclo principal

function renderTudo(dados) {
  const semVendas = dados.kpis.totais.pedidos === 0;
  renderKpis(dados);
  renderDestaques(dados);
  renderVendedores(dados.vendedores, dados.kpis.totais.faturamento);
  marcarVazio(semVendas);
  if (semVendas) return;

  graficoTendencia(dados.meses);
  graficoPedidos(dados.meses);
  graficoTicket(dados.meses);
  renderMix(dados.categorias, dados.kpis.totais.faturamento);
  graficoMargem(dados.categorias, dados.kpis.totais.margem_pct);
  renderLegendaAbc(dados.produtos);
  graficoPareto(dados.produtos);
  renderRentaveis(dados.produtos);
  renderTabelasAlternativas(dados);
  descreverGraficos(dados);
}

async function atualizar() {
  const id = ++estado.requisicao;
  const sel = selecao();
  escreverUrl(sel);
  renderEstadoFiltros(sel);
  const p = parametrosApi(sel);
  const cmp = comparacao(sel);
  document.body.classList.add("carregando");
  try {
    const chamadas = [
      obter("/api/kpis", p),
      obter("/api/vendas-mensais", p),
      obter("/api/categorias", p),
      obter("/api/produtos", { ...p, limite: 50 }),
      obter("/api/vendedores", p),
    ];
    if (cmp.valida) {
      chamadas.push(obter("/api/kpis", { ...p, inicio: `${cmp.de}-01`, fim: ultimoDiaDoMes(cmp.ate) }));
    }
    const [kpis, mensal, categorias, produtos, vendedores, anterior] = await Promise.all(chamadas);
    if (id !== estado.requisicao) return; // chegou uma resposta mais nova

    estado.dados = {
      sel, cmp, kpis,
      anterior: anterior || null,
      meses: mensal.meses,
      categorias: categorias.categorias,
      produtos: produtos.produtos,
      vendedores: vendedores.vendedores,
    };
    esconderAlerta();
    document.body.classList.remove("sem-dados");
    marcarConexao("ok", TEXTO_CONEXAO);
    renderTudo(estado.dados);
    document.body.dataset.pronto = "true"; // usado pela verificação automatizada
  } catch (erro) {
    if (id !== estado.requisicao) return;
    marcarConexao("erro", TEXTO_INDISPONIVEL);
    mostrarAlerta(erro.message);
  } finally {
    if (id === estado.requisicao) document.body.classList.remove("carregando");
  }
}

async function carregar() {
  marcarConexao("conectando", TEXTO_CARREGANDO);
  try {
    const filtros = await obter("/api/filtros");
    if (!estado.filtros) montarFiltros(filtros);
    await atualizar();
  } catch (erro) {
    marcarConexao("erro", TEXTO_INDISPONIVEL);
    $("chip-periodo").textContent = TEXTO_SEM_DADOS;
    document.body.classList.add("sem-dados");
    if (MODO === "demo") {
      mostrarAlerta(erro.message, "Demonstração indisponível");
    } else {
      mostrarAlerta(
        `${erro.message} Para iniciar a API: powershell -ExecutionPolicy Bypass -File api\\iniciar_previa.ps1`,
        "API local indisponível",
      );
    }
  }
}

function iniciar() {
  document.body.dataset.iniciado = "true"; // sinal para js/verificar-carga.js
  $("rodape-fonte").textContent = TEXTO_FONTE;
  aplicarIcones();
  configurarMenu();
  configurarNavegacao();
  ligarAlternadores();
  $("tentar-novamente").addEventListener("click", () => (estado.filtros ? atualizar() : carregar()));
  if (!window.Chart) {
    mostrarAlerta("Não foi possível carregar a biblioteca de gráficos (vendor/chartjs-4.4.7/chart.umd.js).", "Erro ao carregar a página");
    return;
  }
  configurarChartJs();
  carregar();
}

iniciar();
