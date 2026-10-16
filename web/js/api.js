import { API_BASE, MODO } from "./config.js";

let demonstracao = null;

/**
 * GET na API somente leitura. Listas viram parâmetros repetidos (?categoria=1&categoria=2).
 * Em erro, lança Error com a mensagem genérica devolvida pela API.
 * No modo de demonstração, as mesmas respostas são calculadas por demo.js a
 * partir de dados estáticos, sem nenhuma requisição à API.
 */
export async function obter(caminho, parametros = {}) {
  if (MODO === "demo") {
    demonstracao = demonstracao || (await import("./demo.js"));
    return demonstracao.responder(caminho, parametros);
  }

  const url = new URL(API_BASE + caminho, window.location.href);
  for (const [chave, valor] of Object.entries(parametros)) {
    if (valor === null || valor === undefined || valor === "") continue;
    if (Array.isArray(valor)) {
      valor.forEach((item) => url.searchParams.append(chave, String(item)));
    } else {
      url.searchParams.set(chave, String(valor));
    }
  }

  let resposta;
  try {
    resposta = await fetch(url, {
      method: "GET",
      headers: { Accept: "application/json" },
      credentials: "omit",
      cache: "no-store",
    });
  } catch {
    throw new Error("Não foi possível conectar à API local (http://127.0.0.1:8000). Verifique se ela está em execução.");
  }

  if (!resposta.ok) {
    let mensagem = `A API respondeu com erro ${resposta.status}.`;
    try {
      const corpo = await resposta.json();
      if (corpo && typeof corpo.erro === "string") mensagem = corpo.erro;
    } catch {
      /* resposta sem JSON: mantém a mensagem genérica */
    }
    throw new Error(mensagem);
  }
  return resposta.json();
}
