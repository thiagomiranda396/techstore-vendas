// Formatação em português do Brasil.

const MOEDA = new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" });
const MOEDA_COMPACTA = new Intl.NumberFormat("pt-BR", {
  style: "currency",
  currency: "BRL",
  notation: "compact",
  maximumFractionDigits: 1,
});
const INTEIRO = new Intl.NumberFormat("pt-BR", { maximumFractionDigits: 0 });

const MESES_ABREV = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"];
const MESES = [
  "janeiro", "fevereiro", "março", "abril", "maio", "junho",
  "julho", "agosto", "setembro", "outubro", "novembro", "dezembro",
];

const vazio = (v) => v === null || v === undefined || Number.isNaN(v);

function decimal(v, casas) {
  return new Intl.NumberFormat("pt-BR", { minimumFractionDigits: casas, maximumFractionDigits: casas }).format(v);
}

// Datas ISO (AAAA-MM-DD) são lidas por partes, sem fuso horário.
function partes(iso) {
  const [ano, mes, dia] = String(iso).slice(0, 10).split("-").map(Number);
  return { ano, mes, dia };
}

export const fmt = {
  moeda: (v) => (vazio(v) ? "—" : MOEDA.format(v)),
  moedaCompacta: (v) => (vazio(v) ? "—" : MOEDA_COMPACTA.format(v)),
  inteiro: (v) => (vazio(v) ? "—" : INTEIRO.format(v)),
  decimal: (v, casas = 1) => (vazio(v) ? "—" : decimal(v, casas)),
  pct: (v, casas = 1) => (vazio(v) ? "—" : `${decimal(v, casas)}%`),

  /** Diferença em pontos percentuais, com seta e sinal. */
  pontos(v) {
    if (vazio(v)) return { texto: "sem comparação", classe: "" };
    const seta = v >= 0 ? "▲" : "▼";
    const sinal = v >= 0 ? "+" : "−";
    return {
      texto: `${seta} ${sinal}${decimal(Math.abs(v), 1)} p.p.`,
      classe: v >= 0 ? "variacao--positiva" : "variacao--negativa",
    };
  },

  /** "2026-05" e "2026-07" -> "mai–jul/26"; anos diferentes -> "dez/25–fev/26"; mesmo mês -> "jul/26". */
  intervaloMeses(de, ate) {
    if (!de || !ate) return "—";
    const [a1, m1] = de.split("-").map(Number);
    const [a2, m2] = ate.split("-").map(Number);
    const rot = (a, m) => `${MESES_ABREV[m - 1]}/${String(a).slice(2)}`;
    if (de === ate) return rot(a1, m1);
    if (a1 === a2) return `${MESES_ABREV[m1 - 1]}–${rot(a2, m2)}`;
    return `${rot(a1, m1)}–${rot(a2, m2)}`;
  },

  /** Variação com seta e sinal: nunca depende só da cor. */
  variacao(v) {
    if (vazio(v)) return { texto: "sem comparação", classe: "" };
    const seta = v >= 0 ? "▲" : "▼";
    const sinal = v >= 0 ? "+" : "−";
    return {
      texto: `${seta} ${sinal}${decimal(Math.abs(v), 1)}%`,
      classe: v >= 0 ? "variacao--positiva" : "variacao--negativa",
    };
  },

  data(iso) {
    if (!iso) return "—";
    const { ano, mes, dia } = partes(iso);
    return `${String(dia).padStart(2, "0")}/${String(mes).padStart(2, "0")}/${ano}`;
  },

  mesAno(iso) {
    if (!iso) return "—";
    const { ano, mes } = partes(iso);
    return `${MESES_ABREV[mes - 1]}/${String(ano).slice(2)}`;
  },

  mesExtenso(iso) {
    if (!iso) return "—";
    const { ano, mes } = partes(iso);
    return `${MESES[mes - 1]}/${ano}`;
  },
};

/** "2026-08-18" -> true se não for o último dia do mês. */
export function mesParcial(iso) {
  const { ano, mes, dia } = partes(iso);
  return dia < new Date(ano, mes, 0).getDate();
}

/** "2026-07" -> "2026-07-31" (último dia do mês). */
export function ultimoDiaDoMes(anoMes) {
  const [ano, mes] = anoMes.split("-").map(Number);
  return `${anoMes}-${String(new Date(ano, mes, 0).getDate()).padStart(2, "0")}`;
}
