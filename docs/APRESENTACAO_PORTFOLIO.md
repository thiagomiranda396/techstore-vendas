# Apresentação do projeto (GitHub e LinkedIn)

Material de apoio para divulgar o projeto. Revise e ajuste ao seu tom antes de publicar.

---

## GitHub: configuração do repositório

**Nome sugerido:** `techstore-vendas`

**Descrição (até 350 caracteres):**
> Análise de vendas de ponta a ponta: PostgreSQL com 71 testes de qualidade, modelo estrela sem dados pessoais, API FastAPI somente leitura (55 testes) e dashboard web responsivo em Chart.js, com demonstração pública. Material de Power BI com 35 medidas DAX. Dados fictícios.

**Website do repositório:** o endereço do GitHub Pages (Settings › Pages).

**Tópicos:** `postgresql` · `sql` · `data-modeling` · `star-schema` · `data-quality` · `fastapi` · `python` · `javascript` · `chartjs` · `dashboard` · `power-bi` · `dax` · `github-pages` · `portfolio`

**Antes de tornar público:**
- [x] Capturas de tela atualizadas em `docs/imagens/` e referenciadas no README
- [x] Nenhum caminho pessoal ou nome de máquina nos arquivos (só exemplos marcados como tal)
- [x] Nenhuma credencial versionada: `api/.env` é ignorado; só o `api/.env.exemplo`, sem valores, vai para o repositório
- [x] `.pbix` fora do repositório público (identificadores do Power BI Service, credenciais criptografadas e modelo binário não auditável); no lugar, tema, consultas, medidas DAX, guia e capturas
- [x] Commits publicados com o e-mail privado do GitHub ([PUBLICACAO.md](PUBLICACAO.md))
- [ ] Atualizar o link da demonstração no README depois da primeira publicação no GitHub Pages

---

## LinkedIn: rascunho de publicação

> Publiquei um projeto de análise de vendas que vai do banco de dados ao dashboard, com uma preocupação que nem sempre aparece em portfólio: **como provar que os números estão certos?**
>
> 🔹 **PostgreSQL:** modelei e corrigi os scripts de uma loja fictícia. A carga roda numa única transação e é seguida por **71 testes automáticos**: chaves, datas, reconciliação de faturamento, custos e o contrato da view usada pelo Power BI. Se um teste falha, a carga inteira é desfeita. Testei isso de propósito.
>
> 🔹 **Modelagem:** camada analítica em modelo estrela, custo histórico por item e nenhum dado pessoal (CPF, e-mail, telefone, salário) no modelo analítico.
>
> 🔹 **API em Python (FastAPI):** só leitura, com um usuário de banco que enxerga apenas 4 views. São **55 testes**: valores conferidos com a referência, entradas maliciosas recusadas e privilégios verificados com login real.
>
> 🔹 **Dashboard web:** HTML, CSS, JavaScript e Chart.js, responsivo:
> - filtros combináveis e comparação com o período anterior de mesma duração;
> - curva ABC, margem por categoria e ranking de vendedores.
>
> A versão pública roda como demonstração estática e reproduz **exatamente** os números da API: 482 de 482 comparações iguais.
>
> 🔹 **Power BI:** tema, consultas com parâmetros de ambiente e 35 medidas DAX (variação mensal, média móvel, curva ABC, recorrência).
>
> 📊 No período: R$ 335 mil de faturamento e margem bruta de 22,8%. 8 de 19 produtos concentram 82% da receita.
>
> Os dados são fictícios; o processo é o que eu aplicaria num projeto real.
>
> 🔗 Dashboard: [link do GitHub Pages] · Código: [link do repositório]
>
> #PostgreSQL #SQL #Python #FastAPI #PowerBI #DataAnalytics #BusinessIntelligence #QualidadeDeDados #Portfolio

---

## Roteiro curto para entrevista (2 minutos)

1. **Problema:** os scripts originais não rodavam do zero (coluna de custo inexistente, itens apontando para pedidos inexistentes, pedidos antes do cadastro do cliente).
2. **Abordagem:**
   - preservei os originais e criei scripts reproduzíveis em transação única;
   - escrevi testes que desfazem a carga se algo falhar;
   - validei tudo numa instância isolada, sem tocar no banco real.
3. **Decisões:**
   - custos conferidos na origem;
   - divergência de preço documentada, não corrigida em silêncio;
   - custo histórico por item;
   - camada estrela sem dados pessoais;
   - privilégio mínimo para a API e para o Power BI.
4. **Entrega:**
   - API somente leitura testada;
   - dashboard web responsivo;
   - demonstração pública equivalente à API, sem expor o banco;
   - guia do Power BI com valores de referência.
5. **Limitações que eu conheço:**
   - dados fictícios com distribuição artificial entre vendedores;
   - 7,5 meses de dados;
   - estoque como foto do momento;
   - demonstração pública estática.
