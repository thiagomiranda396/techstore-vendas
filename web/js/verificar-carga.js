// Vigia o carregamento do painel. Script clássico (fora dos módulos ES): roda
// mesmo quando js/app.js ou um de seus módulos não carrega — por exemplo, um
// arquivo que falhou ou ficou desatualizado no cache do navegador logo depois
// de uma publicação. Sem ele, a página ficaria parada em "Carregando…".
//
// Módulos e scripts "defer" executam antes do DOMContentLoaded. Se nesse
// momento app.js ainda não marcou o início (body[data-iniciado]), ele falhou.
(function () {
  "use strict";

  function verificar() {
    if (document.body.dataset.iniciado === "true") return; // painel iniciou normalmente

    var alerta = document.getElementById("alerta");
    var titulo = document.getElementById("alerta-titulo");
    var texto = document.getElementById("alerta-texto");
    var botao = document.getElementById("tentar-novamente");
    var conexao = document.getElementById("conexao");
    var textoConexao = document.getElementById("texto-conexao");
    if (!alerta || !titulo || !texto || !botao) return;

    titulo.textContent = "Não foi possível carregar o painel";
    texto.textContent =
      "Alguns arquivos da página não foram carregados. Recarregue a página " +
      "(Ctrl+F5 no Windows ou Cmd+Shift+R no Mac) para buscar a versão mais recente.";
    botao.textContent = "Recarregar página";
    botao.addEventListener("click", function () { window.location.reload(); });
    alerta.hidden = false;
    if (conexao && textoConexao) {
      conexao.dataset.estado = "erro";
      textoConexao.textContent = "Página não carregada";
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", verificar);
  } else {
    verificar();
  }
})();
