// Fonte de dados do dashboard.
// - Em endereço local (localhost/127.0.0.1): API local somente leitura.
//   Página servida pela própria API (porta 8000) usa caminhos relativos;
//   aberta pela Live Preview do VS Code (outra porta) usa 127.0.0.1:8000
//   (liberada por CORS de desenvolvimento, TECHSTORE_API_ORIGENS_DEV).
//   ?fonte=demo força a demonstração localmente, para testes.
// - Em qualquer outro endereço (ex.: GitHub Pages): SEMPRE a demonstração
//   estática (dados-demo/demo.json). A página publicada nunca tenta acessar
//   localhost nem o banco de dados.
// O navegador nunca acessa o PostgreSQL diretamente.

const HOSTS_LOCAIS = new Set(["localhost", "127.0.0.1", "[::1]", "::1"]);
const local = HOSTS_LOCAIS.has(window.location.hostname);
const pedido = new URLSearchParams(window.location.search).get("fonte");

export const MODO = local && pedido !== "demo" ? "api" : "demo";

export const API_BASE = window.location.port === "8000" ? "" : "http://127.0.0.1:8000";

export const TEXTO_CONEXAO = MODO === "demo"
  ? "Demonstração · dados fictícios estáticos"
  : `${API_BASE === "" ? "API local" : "API local (prévia de desenvolvimento)"} · conectada`;

/** Parâmetro de URL a preservar ao reescrever filtros (só faz sentido localmente). */
export const PARAMETRO_FONTE = local && pedido === "demo" ? "demo" : null;

document.documentElement.dataset.modo = MODO;
