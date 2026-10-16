# Publicação no GitHub e no GitHub Pages

Como o repositório e o dashboard de demonstração são publicados, e o que **não** vai para a internet.

## O que é publicado

| Publicado | Não publicado |
|---|---|
| Scripts SQL (`database/`, `sql/`) | `api/.env` e qualquer credencial |
| API (`api/`) e testes | Arquivos `.pbix` (ver abaixo) |
| Dashboard web (`web/`) com dados fictícios em `web/dados-demo/demo.json` | Ambientes virtuais, caches e logs |
| Documentação, capturas e material de Power BI (tema, consultas, DAX) | Banco de dados: a porta do PostgreSQL nunca é exposta |

**Banco:** o GitHub Pages serve só os arquivos estáticos de `web/`. Na internet, o dashboard entra automaticamente em **modo demonstração**: lê `dados-demo/demo.json` e calcula os indicadores no navegador, sem acessar API nem banco. A faixa "Demonstração · dados fictícios" no cabeçalho indica esse modo.

**Por que o `.pbix` fica de fora:** o arquivo contém identificadores do Power BI Service (Connections), um bloco de credenciais criptografado (SecurityBindings) e um modelo de dados binário que não dá para auditar antes de publicar. O original continua no repositório **local**; o branch publicado é gerado sem ele.

## Branch de publicação

O commit inicial do repositório local contém o `.pbix` original e foi registrado com o e-mail pessoal. Para publicar sem reescrever `main`, o script [`scripts/gerar_branch_publicacao.ps1`](../scripts/gerar_branch_publicacao.ps1) cria o branch `publicacao`, um espelho de `main`:

- sem os arquivos `powerbi/*.pbix`;
- com o autor trocado pelo e-mail privado do GitHub (`...@users.noreply.github.com`);
- com mensagem e data de cada commit preservadas e a linha `Espelho-de: <sha>` apontando para o original.

O script não altera `main`, o índice nem os arquivos de trabalho. Ele é incremental: novos commits em `main` viram novos commits em `publicacao`, e o envio nunca precisa de force push.

## Passo a passo (primeira publicação)

1. **E-mail privado do GitHub:** em *Settings › Emails*, ative *Keep my email addresses private* e copie o endereço `NUMERO+usuario@users.noreply.github.com`. Se quiser, ative também *Block command line pushes that expose my email*.
2. **Criar o repositório** no GitHub, vazio, sem README, `.gitignore` nem licença. Sugestão de nome: `techstore-vendas`.
3. **Gerar o branch de publicação** (na raiz do projeto):
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\gerar_branch_publicacao.ps1 -Email NUMERO+usuario@users.noreply.github.com
   ```
   A última linha deve terminar em "nenhum .pbix".
4. **Conferir antes de enviar:**
   ```powershell
   git ls-tree -r --name-only publicacao | Select-String "\.pbix$|\.env$"   # não deve listar nada
   git log publicacao --format="%an <%ae>" | Sort-Object -Unique             # só o e-mail noreply
   ```
5. **Enviar** o branch `publicacao` como `main` do GitHub:
   ```powershell
   git remote add origin https://github.com/USUARIO/techstore-vendas.git
   git push origin publicacao:main
   ```
6. **Ativar o Pages:** em *Settings › Pages › Build and deployment › Source*, escolha **GitHub Actions**. O workflow [`.github/workflows/pages.yml`](../.github/workflows/pages.yml) roda a cada push que altere `web/` (ou manualmente, em *Actions › Publicar dashboard (GitHub Pages) › Run workflow*).
7. **Atualizar o link:** troque o endereço provisório no topo do README por `https://USUARIO.github.io/techstore-vendas/`, faça o commit em `main` e repita os passos 3 e 5.

## Atualizações seguintes

```powershell
# depois de commitar em main
powershell -ExecutionPolicy Bypass -File scripts\gerar_branch_publicacao.ps1 -Email NUMERO+usuario@users.noreply.github.com
git push origin publicacao:main
```

Não faça commits direto no `main` do GitHub nem em `publicacao`: o fluxo é sempre `main` local → `publicacao` → `origin/main`.

**Cache do navegador:** o GitHub Pages manda o navegador guardar os arquivos por 10 minutos. Logo depois de uma publicação, quem já abriu a página pode receber uma mistura de arquivos antigos e novos. Nesse caso o painel mostra "Não foi possível carregar o painel" e um botão para recarregar, e um Ctrl+F5 (Cmd+Shift+R no Mac) resolve.

## O que o workflow verifica

Antes de publicar, o workflow interrompe a publicação se:

- `web/` contiver arquivos `.py`, `.env`, `.pbix` ou `.sql`;
- `demo.json` contiver campos de dados pessoais (`cpf`, `email`, `telefone`, `salario`);
- algum dos 10 testes de [`api/tests/test_demo_estatica.py`](../api/tests/test_demo_estatica.py) falhar. Eles conferem, sem banco, os valores de referência, a ausência de dados pessoais, a grafia exata de arquivos e importações (o Pages diferencia maiúsculas de minúsculas) e o modo demonstração fora de localhost.

Ele envia ao Pages **somente** a pasta `web/`.

## Atualizar os dados de demonstração

O arquivo `web/dados-demo/demo.json` é exportado do banco de teste pela própria API, com o usuário somente leitura:

```powershell
cd api
.\.venv\Scripts\python.exe exportar_demo.py
```

Ele contém só as colunas das views analíticas (itens, produtos, vendedores e meses), sem nome de cliente nem dado pessoal. Depois de exportar, valide a equivalência com a API ([DASHBOARD_WEB.md](DASHBOARD_WEB.md#demonstração-pública)).
