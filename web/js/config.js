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

/** Textos de estado que dependem da fonte: a demonstração nunca menciona a API local. */
export const TEXTO_CARREGANDO = MODO === "demo" ? "Carregando dados de demonstração…" : "Conectando à API local…";
export const TEXTO_INDISPONIVEL = MODO === "demo" ? "Dados de demonstração indisponíveis" : "API indisponível";
export const TEXTO_SEM_DADOS = MODO === "demo" ? "Dados indisponíveis" : "Sem conexão com a API";
export const TEXTO_FONTE = MODO === "demo"
  ? "Fonte: retrato estático das views analíticas do PostgreSQL (instância de testes), exportado para um arquivo de dados. Os indicadores são calculados no navegador, sem acesso a banco de dados ou API."
  : "Fonte: views analíticas do PostgreSQL (instância de testes), lidas por uma API local somente leitura. O navegador não acessa o banco de dados.";

/** Parâmetro de URL a preservar ao reescrever filtros (só faz sentido localmente). */
export const PARAMETRO_FONTE = local && pedido === "demo" ? "demo" : null;

document.documentElement.dataset.modo = MODO;
