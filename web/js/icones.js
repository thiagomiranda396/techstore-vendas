// Ícones de traço (24×24) desenhados para o projeto: sem biblioteca externa.
// Cada ícone é uma lista de formas criadas via DOM (nenhum innerHTML).

const ICONES = {
  logo: [["rect", { x: 3, y: 3, width: 18, height: 18, rx: 5 }], ["path", { d: "M8 16v-4M12 16V8M16 16v-6" }]],
  receita: [["circle", { cx: 12, cy: 12, r: 9 }], ["path", { d: "M15 9.5c0-1.4-1.3-2.5-3-2.5s-3 1-3 2.3c0 3.2 6 1.8 6 5 0 1.4-1.3 2.7-3 2.7s-3-1.1-3-2.5M12 5.5V7M12 17v1.5" }]],
  lucro: [["path", { d: "M3 17l6-6 4 4 8-8" }], ["path", { d: "M15 7h6v6" }]],
  margem: [["path", { d: "M19 5L5 19" }], ["circle", { cx: 7, cy: 7, r: 2.5 }], ["circle", { cx: 17, cy: 17, r: 2.5 }]],
  pedidos: [["path", { d: "M6 8h12l-1 12H7L6 8z" }], ["path", { d: "M9 8V6a3 3 0 0 1 6 0v2" }]],
  ticket: [["path", { d: "M6 3h12v18l-3-2-3 2-3-2-3 2V3z" }], ["path", { d: "M9 8h6M9 12h6M9 16h3" }]],
  unidades: [["path", { d: "M3 7l9-4 9 4-9 4-9-4z" }], ["path", { d: "M3 7v10l9 4 9-4V7M12 11v10" }]],
  visao: [["path", { d: "M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z" }]],
  tendencia: [["path", { d: "M3 3v18h18" }], ["path", { d: "M7 15l4-4 3 3 5-6" }]],
  categorias: [["path", { d: "M12 3l9 5-9 5-9-5 9-5z" }], ["path", { d: "M3 13l9 5 9-5" }]],
  produtos: [["path", { d: "M20 13l-7 7-9-9V4h7l9 9z" }], ["circle", { cx: 7.5, cy: 7.5, r: 1.2 }]],
  equipe: [["circle", { cx: 9, cy: 8, r: 3.5 }], ["path", { d: "M2.5 20c0-3.6 2.9-6 6.5-6s6.5 2.4 6.5 6M16 4.5a3.5 3.5 0 0 1 0 7M18 14c2.2.6 3.5 2.6 3.5 6" }]],
  filtro: [["path", { d: "M3 5h18l-7 8v6l-4-2v-4L3 5z" }]],
  redefinir: [["path", { d: "M3 12a9 9 0 1 0 3-6.7" }], ["path", { d: "M3 4v5h5" }]],
  menu: [["path", { d: "M4 6h16M4 12h16M4 18h16" }]],
  fechar: [["path", { d: "M6 6l12 12M18 6L6 18" }]],
  destaque: [["path", { d: "M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8L12 3z" }], ["path", { d: "M19 16l.8 2.2L22 19l-2.2.8L19 22l-.8-2.2L16 19l2.2-.8L19 16z" }]],
  calendario: [["rect", { x: 3, y: 5, width: 18, height: 16, rx: 2 }], ["path", { d: "M3 10h18M8 3v4M16 3v4" }]],
  alerta: [["path", { d: "M12 3l10 18H2L12 3z" }], ["path", { d: "M12 10v5M12 18v.01" }]],
  tabela: [["rect", { x: 3, y: 4, width: 18, height: 16, rx: 2 }], ["path", { d: "M3 10h18M3 15h18M9 10v10" }]],
  grafico: [["path", { d: "M4 20V10M10 20V4M16 20v-7M22 20H2" }]],
};

const SVG = "http://www.w3.org/2000/svg";

export function icone(nome, classe = "icone") {
  const svg = document.createElementNS(SVG, "svg");
  svg.setAttribute("viewBox", "0 0 24 24");
  svg.setAttribute("fill", "none");
  svg.setAttribute("stroke", "currentColor");
  svg.setAttribute("stroke-width", "1.8");
  svg.setAttribute("stroke-linecap", "round");
  svg.setAttribute("stroke-linejoin", "round");
  svg.setAttribute("aria-hidden", "true");
  svg.setAttribute("focusable", "false");
  svg.setAttribute("class", classe);
  for (const [tag, atributos] of ICONES[nome] || []) {
    const forma = document.createElementNS(SVG, tag);
    Object.entries(atributos).forEach(([k, v]) => forma.setAttribute(k, String(v)));
    svg.append(forma);
  }
  return svg;
}

/** Substitui todo elemento [data-icone="nome"] pelo ícone correspondente. */
export function aplicarIcones(raiz = document) {
  raiz.querySelectorAll("[data-icone]").forEach((alvo) => {
    alvo.replaceWith(icone(alvo.dataset.icone, alvo.className || "icone"));
  });
}
