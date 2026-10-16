// Gráficos (Chart.js 4.4.7 local, carregado antes deste módulo).
// Regras: um eixo por gráfico (nunca dois eixos Y), marcas finas, grade discreta,
// cor de série nunca usada em texto, mês parcial sempre sinalizado, tabela
// alternativa para cada gráfico (montada em app.js).

import { fmt } from "./formatos.js";

const COR = {
  serie1: "#2A78D6",
  serie1Parcial: "rgba(42, 120, 214, 0.38)",
  serie2: "#EB6834",
  custo: "#B6C2D1",
  custoParcial: "rgba(182, 194, 209, 0.45)",
  abaixo: "#B6C2D1",
  abc: { A: "#1C5CAB", B: "#3987E5", C: "#86B6EF" },
  grade: "#E8EDF3",
  eixo: "#CBD5E1",
  texto2: "#475569",
  mudo: "#64748B",
  tinta: "#0F172A",
  superficie: "#FFFFFF",
};

const instancias = {};

export function configurarChartJs() {
  const { Chart } = window;
  Chart.defaults.font.family = '"Segoe UI", system-ui, -apple-system, Roboto, "Helvetica Neue", Arial, sans-serif';
  Chart.defaults.font.size = 12;
  Chart.defaults.color = COR.texto2;
  Chart.defaults.borderColor = COR.grade;
  Chart.defaults.maintainAspectRatio = false;
  Chart.defaults.locale = "pt-BR";
  Chart.defaults.plugins.legend.labels.usePointStyle = true;
  Chart.defaults.plugins.legend.labels.boxWidth = 8;
  Chart.defaults.plugins.legend.labels.boxHeight = 8;
  Chart.defaults.plugins.tooltip.backgroundColor = COR.tinta;
  Chart.defaults.plugins.tooltip.padding = 10;
  Chart.defaults.plugins.tooltip.cornerRadius = 8;
  Chart.defaults.plugins.tooltip.boxPadding = 4;
  Chart.defaults.plugins.tooltip.titleFont = { weight: "700" };
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    Chart.defaults.animation = false;
  }
}

// ----------------------------------------------------------------- plugins

// Valor na ponta das barras horizontais (texto em tinta neutra, nunca na cor da série).
const rotulosNaPonta = {
  id: "rotulosNaPonta",
  afterDatasetsDraw(chart, _args, opcoes) {
    if (!opcoes || typeof opcoes.formatar !== "function") return;
    const { ctx } = chart;
    ctx.save();
    ctx.font = `600 11.5px ${window.Chart.defaults.font.family}`;
    ctx.fillStyle = COR.texto2;
    ctx.textBaseline = "middle";
    chart.getDatasetMeta(0).data.forEach((barra, i) => {
      ctx.fillText(opcoes.formatar(chart.data.datasets[0].data[i]), barra.x + 6, barra.y);
    });
    ctx.restore();
  },
};

// Linha vertical de referência (ex.: margem geral do período).
const linhaReferencia = {
  id: "linhaReferencia",
  afterDatasetsDraw(chart, _args, opcoes) {
    if (!opcoes || opcoes.valor === null || opcoes.valor === undefined) return;
    const { ctx, chartArea } = chart;
    const x = chart.scales.x.getPixelForValue(opcoes.valor);
    if (x < chartArea.left || x > chartArea.right) return;
    ctx.save();
    ctx.strokeStyle = COR.tinta;
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(x, chartArea.top);
    ctx.lineTo(x, chartArea.bottom);
    ctx.stroke();
    ctx.font = `700 11.5px ${window.Chart.defaults.font.family}`;
    ctx.fillStyle = COR.tinta;
    ctx.textAlign = "center";
    ctx.textBaseline = "bottom";
    ctx.fillText(opcoes.rotulo, x, chartArea.top - 4);
    ctx.restore();
  },
};

const eixoMoeda = (extra = {}) => ({
  border: { display: false },
  grid: { color: COR.grade },
  ticks: { color: COR.mudo, maxTicksLimit: 5, callback: (v) => fmt.moedaCompacta(v) },
  ...extra,
});

const eixoCategorias = {
  grid: { display: false },
  border: { color: COR.eixo },
  ticks: { color: COR.mudo },
};

function criarOuAtualizar(id, configuracao) {
  const atual = instancias[id];
  if (atual) {
    atual.data = configuracao.data;
    atual.options = configuracao.options;
    atual.update();
    return atual;
  }
  instancias[id] = new window.Chart(document.getElementById(id), configuracao);
  return instancias[id];
}

const ehParcial = (m) => m.situacao_mes === "Parcial";
const AVISO_PARCIAL = "Mês parcial: não comparável aos meses completos";

// ----------------------------------------------------------------- tendência

/** Barras empilhadas custo + lucro (= faturamento) e média móvel de 3 meses. */
export function graficoTendencia(meses) {
  const parcial = meses.map(ehParcial);
  criarOuAtualizar("g-tendencia", {
    type: "bar",
    data: {
      labels: meses.map((m) => m.ano_mes),
      datasets: [
        {
          type: "line",
          label: "Média móvel 3 meses (faturamento)",
          data: meses.map((m) => m.media_movel_3m),
          borderColor: COR.serie2,
          backgroundColor: COR.serie2,
          borderWidth: 2,
          pointRadius: 0,
          pointHoverRadius: 4,
          tension: 0,
          spanGaps: false,
          stack: "media",
          order: 1,
        },
        {
          label: "Custo",
          data: meses.map((m) => m.custo),
          backgroundColor: parcial.map((p) => (p ? COR.custoParcial : COR.custo)),
          stack: "receita",
          order: 2,
          barPercentage: 0.62,
        },
        {
          label: "Lucro bruto",
          data: meses.map((m) => m.lucro_bruto),
          backgroundColor: parcial.map((p) => (p ? COR.serie1Parcial : COR.serie1)),
          borderRadius: { topLeft: 4, topRight: 4 },
          borderSkipped: false,
          stack: "receita",
          order: 2,
          barPercentage: 0.62,
        },
      ],
    },
    options: {
      interaction: { mode: "index", intersect: false },
      plugins: {
        legend: { position: "top", align: "start", reverse: true },
        tooltip: {
          itemSort: (a, b) => b.datasetIndex - a.datasetIndex,
          filter: (item) => item.parsed.y !== null && item.parsed.y !== undefined,
          callbacks: {
            title: (itens) => {
              const m = meses[itens[0].dataIndex];
              return parcial[itens[0].dataIndex] ? `${m.ano_mes} (parcial)` : m.ano_mes;
            },
            label: (c) => ` ${c.dataset.label}: ${fmt.moeda(c.parsed.y)}`,
            footer: (itens) => {
              const i = itens[0].dataIndex;
              const m = meses[i];
              const linhas = [
                `Faturamento: ${fmt.moeda(m.faturamento)}`,
                `Margem bruta: ${fmt.pct(m.faturamento ? (100 * m.lucro_bruto) / m.faturamento : null, 1)}`,
              ];
              if (m.variacao_pct !== null && m.variacao_pct !== undefined) {
                linhas.push(`Variação do faturamento: ${fmt.variacao(m.variacao_pct).texto}`);
              }
              if (parcial[i]) linhas.push(AVISO_PARCIAL);
              return linhas;
            },
          },
        },
      },
      scales: {
        x: { ...eixoCategorias, stacked: true },
        y: eixoMoeda({ stacked: true, beginAtZero: true }),
      },
    },
  });
}

// ----------------------------------------------------------------- pedidos e ticket

export function graficoPedidos(meses) {
  const parcial = meses.map(ehParcial);
  criarOuAtualizar("g-pedidos", {
    type: "bar",
    data: {
      labels: meses.map((m) => m.ano_mes),
      datasets: [
        {
          label: "Pedidos",
          data: meses.map((m) => m.pedidos),
          backgroundColor: parcial.map((p) => (p ? COR.serie1Parcial : COR.serie1)),
          borderRadius: 4,
          barPercentage: 0.6,
        },
      ],
    },
    options: {
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            label: (c) => ` Pedidos: ${fmt.inteiro(c.parsed.y)}`,
            footer: (itens) => (parcial[itens[0].dataIndex] ? AVISO_PARCIAL : ""),
          },
        },
      },
      scales: {
        x: { ...eixoCategorias, ticks: { color: COR.mudo, font: { size: 11 }, maxRotation: 0, autoSkipPadding: 8 } },
        y: { beginAtZero: true, border: { display: false }, grid: { color: COR.grade }, ticks: { color: COR.mudo, precision: 0, maxTicksLimit: 4 } },
      },
    },
  });
}

export function graficoTicket(meses) {
  const parcial = meses.map(ehParcial);
  criarOuAtualizar("g-ticket", {
    type: "line",
    data: {
      labels: meses.map((m) => m.ano_mes),
      datasets: [
        {
          label: "Ticket médio",
          data: meses.map((m) => (m.pedidos ? m.faturamento / m.pedidos : null)),
          borderColor: COR.serie1,
          backgroundColor: COR.serie1,
          borderWidth: 2,
          tension: 0,
          pointRadius: 3,
          pointHoverRadius: 5,
          pointBackgroundColor: parcial.map((p) => (p ? COR.superficie : COR.serie1)),
          pointBorderColor: COR.serie1,
          pointBorderWidth: 2,
        },
      ],
    },
    options: {
      interaction: { mode: "index", intersect: false },
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            label: (c) => ` Ticket médio: ${fmt.moeda(c.parsed.y)}`,
            footer: (itens) => (parcial[itens[0].dataIndex] ? AVISO_PARCIAL : ""),
          },
        },
      },
      scales: {
        x: { ...eixoCategorias, ticks: { color: COR.mudo, font: { size: 11 }, maxRotation: 0, autoSkipPadding: 8 } },
        y: eixoMoeda({ grace: "10%", ticks: { color: COR.mudo, maxTicksLimit: 4, callback: (v) => fmt.moedaCompacta(v) } }),
      },
    },
  });
}

// ----------------------------------------------------------------- margem por categoria

export function graficoMargem(categorias, margemGeral) {
  const ordenadas = [...categorias].sort((a, b) => b.margem_pct - a.margem_pct);
  const maximo = Math.max(...ordenadas.map((c) => c.margem_pct), margemGeral || 0);
  criarOuAtualizar("g-margem", {
    type: "bar",
    data: {
      labels: ordenadas.map((c) => c.categoria),
      datasets: [
        {
          label: "Margem bruta",
          data: ordenadas.map((c) => c.margem_pct),
          // Acima da margem geral: azul; abaixo: cinza (explicado no subtítulo).
          backgroundColor: ordenadas.map((c) => (c.margem_pct >= margemGeral ? COR.serie1 : COR.abaixo)),
          borderRadius: 4,
          barPercentage: 0.7,
          categoryPercentage: 0.9,
        },
      ],
    },
    plugins: [rotulosNaPonta, linhaReferencia],
    options: {
      indexAxis: "y",
      layout: { padding: { right: 52, top: 18 } },
      plugins: {
        legend: { display: false },
        rotulosNaPonta: { formatar: (v) => fmt.pct(v, 1) },
        linhaReferencia: { valor: margemGeral, rotulo: `Geral ${fmt.pct(margemGeral, 1)}` },
        tooltip: {
          callbacks: {
            label: (c) => ` Margem bruta: ${fmt.pct(c.parsed.x, 1)}`,
            afterLabel: (c) => {
              const cat = ordenadas[c.dataIndex];
              const dif = cat.margem_pct - margemGeral;
              return [` Faturamento: ${fmt.moeda(cat.faturamento)}`, ` vs margem geral: ${fmt.pontos(dif).texto}`];
            },
          },
        },
      },
      scales: {
        x: { display: false, beginAtZero: true, suggestedMax: maximo * 1.05 },
        y: { grid: { display: false }, border: { color: COR.eixo }, ticks: { color: COR.tinta } },
      },
    },
  });
}

// ----------------------------------------------------------------- curva ABC

export function graficoPareto(produtos) {
  criarOuAtualizar("g-pareto", {
    type: "bar",
    data: {
      labels: produtos.map((p) => String(p.ranking)),
      datasets: [
        {
          type: "line",
          label: "% acumulado",
          data: produtos.map((p) => p.pct_acumulado),
          borderColor: COR.serie2,
          backgroundColor: COR.serie2,
          borderWidth: 2,
          pointRadius: 2.5,
          pointHoverRadius: 5,
          tension: 0,
          order: 1,
        },
        {
          label: "% do faturamento",
          data: produtos.map((p) => p.pct_faturamento),
          backgroundColor: produtos.map((p) => COR.abc[p.classe_abc]),
          borderRadius: 3,
          barPercentage: 0.78,
          categoryPercentage: 0.9,
          order: 2,
        },
      ],
    },
    options: {
      interaction: { mode: "index", intersect: false },
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            title: (itens) => {
              const p = produtos[itens[0].dataIndex];
              return `${p.ranking}º · ${p.produto}`;
            },
            label: (c) => ` ${c.dataset.label}: ${fmt.pct(c.parsed.y, 1)}`,
            footer: (itens) => {
              const p = produtos[itens[0].dataIndex];
              return [`Faturamento: ${fmt.moeda(p.faturamento)}`, `Classe ${p.classe_abc} · ${p.categoria}`];
            },
          },
        },
      },
      scales: {
        x: { ...eixoCategorias, title: { display: true, text: "Posição no ranking de faturamento", color: COR.mudo, font: { size: 11 } } },
        y: {
          min: 0,
          max: 100,
          border: { display: false },
          grid: { color: COR.grade },
          ticks: { color: COR.mudo, stepSize: 20, callback: (v) => `${v}%` },
        },
      },
    },
  });
}
