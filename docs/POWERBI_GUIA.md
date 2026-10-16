# Guia de implementação do Power BI

**Objetivo:** montar o novo modelo estrela e a **página Visão Executiva** numa cópia de trabalho do relatório (`powerbi/TECHSTORE_VENDAS_v2.pbix`). O arquivo original `TECHSTORE_VENDAS.pbix` **nunca é aberto para edição**.

> **Os arquivos `.pbix` não estão no repositório público.** Eles contêm identificadores do Power BI Service, um bloco de credenciais criptografado e um modelo binário que não pode ser auditado, por isso ficam só no repositório local do autor. Quem clonar o projeto pode montar o relatório do zero, num arquivo novo, com os passos abaixo.

**Arquivos de apoio:**

| Arquivo | Conteúdo |
|---|---|
| [powerbi/tema/TechstoreVendas.json](../powerbi/tema/TechstoreVendas.json) | Tema: cores, fontes, cartões, eixos |
| [powerbi/modelo/consultas_power_query.m](../powerbi/modelo/consultas_power_query.m) | 2 parâmetros e 5 consultas |
| [powerbi/modelo/medidas.dax](../powerbi/modelo/medidas.dax) | 35 medidas em 6 pastas |

> O formato `.pbix` não pode ser editado por script. Os passos abaixo são feitos no Power BI Desktop. Os arquivos de apoio **não foram testados no Desktop**; os valores esperados da seção 8 foram calculados no PostgreSQL e servem para conferir o resultado.

---

## 1. Pré-requisito: senha do leitor do Power BI

O conector PostgreSQL do Power BI só aceita usuário e senha (não aceita autenticação do Windows). Use o papel **somente leitura** `techstore_bi_leitor`, que já existe na instância de testes e só enxerga as views.

No PowerShell (você entra como administrador pela autenticação do Windows; a senha nova é digitada de forma oculta):
```powershell
psql "host=localhost port=5433 dbname=postgres user=pgdev_admin" -X   # psql do PostgreSQL 18 (no PATH ou pelo caminho completo)
```
```sql
SELECT current_setting('port'), current_setting('cluster_name');   -- 5433 | techstore_dev18
\password techstore_bi_leitor
\q
```
A senha fica guardada **só nas credenciais do Power BI Desktop**: nunca no `.pbix`, em arquivo do projeto ou no Git.

## 2. Abrir a cópia e configurar a localidade
1. Abra a cópia de trabalho `powerbi/TECHSTORE_VENDAS_v2.pbix` (no repositório local) ou crie um relatório novo no Power BI Desktop.
2. **Arquivo › Opções e configurações › Opções › Arquivo atual › Configurações regionais** e escolha **Português (Brasil)**. Isso faz `R$ 335.062,30` e `22,8%` aparecerem no padrão brasileiro.
3. **Exibir › Temas › Procurar temas** e selecione `powerbi/tema/TechstoreVendas.json`.

## 3. Parâmetros e consultas (troca de ambiente)
1. **Transformar dados › Gerenciar parâmetros › Novo:**
   - `ServidorPostgres` (Texto) = `localhost:5433`
   - `BancoDados` (Texto) = `techstore_dev_v3`
2. Para cada consulta em `consultas_power_query.m` (`Fato Vendas`, `Dim Cliente`, `Dim Produto`, `Dim Vendedor`, `Calendario`), use **Nova Fonte › Consulta Nula › Editor Avançado**, cole o bloco e renomeie a consulta.
3. Na primeira conexão, escolha **Banco de dados**, usuário `techstore_bi_leitor` e a senha do passo 1.
4. Para trocar de ambiente depois, basta editar os dois parâmetros. Nenhuma consulta precisa ser alterada.

## 4. Limpeza do modelo antigo (segurança)
Depois de recriar os visuais com as tabelas novas:
- **Exclua** `F_vw_vendas`, `D_Cliente`, `D_Vendedor`, `D_Produto`, `D_Categoria`, `D_Calendario` e as medidas antigas da `_Medidas`. A correspondência entre medidas antigas e novas está no fim de `medidas.dax`.
- **Antes de excluir**, confira no painel **Dados** se `D_Cliente` ou `D_Vendedor` têm CPF, e-mail, telefone ou salário. As consultas antigas apontavam para tabelas, e esses campos não devem existir no modelo novo.
- **Arquivo › Opções › Arquivo atual › Carga de dados:** desative "Detectar automaticamente novos relacionamentos" e "Data/hora automática".

## 5. Relacionamentos (Exibição de modelo)

| De (1) | Para (N) | Cardinalidade | Filtro |
|---|---|---|---|
| `Calendario[data]` | `Fato Vendas[data_pedido]` | 1:N | Único |
| `Dim Cliente[id_cliente]` | `Fato Vendas[id_cliente]` | 1:N | Único |
| `Dim Produto[id_produto]` | `Fato Vendas[id_produto]` | 1:N | Único |
| `Dim Vendedor[id_vendedor]` | `Fato Vendas[id_vendedor]` | 1:N | Único |

**Depois:**
- `Calendario`: **Marcar como tabela de datas** (coluna `data`). Ordene `ano_mes` por `ano_mes_num` e `dia_semana` por `dia_semana_num`.
- **Oculte** as chaves `id_*` da fato e as colunas técnicas (`ano_mes_num`, `dia_semana_num`).
- Formate como moeda `"R$ "#,0.00` as colunas monetárias, para o caso de alguém usá-las direto num visual.

## 6. Medidas
1. **Página Inicial › Inserir dados** › tabela vazia `_Medidas`.
2. Crie as medidas de `medidas.dax` com os formatos e as pastas de exibição indicados (1 Vendas … 6 Textos e formatação).
3. **Formatos:** moeda `"R$ "#,0.00`, percentual `0.0%`, inteiro `#,0`.

## 7. Página "Visão Executiva" (1280 × 720)

Grade de 8 px, margens de 24 px e espaço de 16 px entre visuais. Fundo `#F9F9F7`, cartões `#FCFCFB` com borda `#E1E0D9` (já vêm do tema).

```
 0 ┌──────────────────────────────────────────────────────────────────────────┐
   │ Visão Executiva                       Dados até 18/08/2026 · ago parcial │ faixa #0D366B, 64 px
64 ├──────────────────────────────────────────────────────────────────────────┤
76 │ [Período ▭▭▭▭▭]  [Categoria ▾]  [Vendedor ▾]                 [Limpar ⟲] │ filtros, 56 px
144├─────────────┬─────────────┬─────────────┬─────────────┬─────────────────┤
   │ Faturamento │ Lucro bruto │ Margem      │ Pedidos     │ Ticket médio    │ 5 cartões, 104 px
   │ R$ 335,1 mil│ R$ 76,4 mil │ 22,8%       │ 60          │ R$ 5,6 mil      │
   │ ▼ −2,3% jul │             │             │             │                 │
264├─────────────────────────────────────────┬────────────────────────────────┤
   │ Faturamento mensal                      │ Faturamento por categoria      │ 220 px
   │ (linha + média móvel 3 meses)           │ (barras horizontais)           │
500├──────────────────────────────┬──────────┴────────────────────────────────┤
   │ Top 5 produtos               │ Vendedores (tabela com ranking)           │ 196 px
696└──────────────────────────────┴───────────────────────────────────────────┘
```

| Visual | Posição (x, y, l × a) | Campos | Configuração |
|---|---|---|---|
| Faixa de título | 0, 0, 1280 × 64 | Caixa de texto "Visão Executiva" (Segoe UI Semibold 20, branco) e cartão com `[Aviso do Período]` (10, `#C3C2B7` sobre a faixa) | Retângulo `#0D366B` atrás |
| Filtro Período | 24, 76, 300 × 56 | `Calendario[data]` | Estilo "Entre"; filtros sincronizados se houver outras páginas |
| Filtro Categoria | 340, 76, 220 × 56 | `Dim Produto[categoria]` | Lista suspensa, várias seleções |
| Filtro Vendedor | 576, 76, 220 × 56 | `Dim Vendedor[vendedor]` | Lista suspensa |
| Limpar filtros | 1176, 84, 80 × 40 | Botão "Redefinir" | Indicador (bookmark) com o estado sem filtros |
| Cartão Faturamento | 24, 144, 232 × 104 | `[Faturamento]` | Cartão (novo). Rótulo de referência: `[Rótulo Variação]`, cor por valor do campo `[Cor Variação]`, e `[Rótulo Último Mês Completo]` |
| Cartão Lucro | 272, 144, 232 × 104 | `[Lucro Bruto]` | Unidade: mil |
| Cartão Margem | 520, 144, 232 × 104 | `[Margem Bruta %]` | 1 casa decimal |
| Cartão Pedidos | 768, 144, 232 × 104 | `[Pedidos]` | Rótulo de referência: `[Itens por Pedido]` "itens/pedido" |
| Cartão Ticket | 1016, 144, 240 × 104 | `[Ticket Médio]` | Unidade: mil, 1 casa decimal |
| Faturamento mensal | 24, 264, 760 × 220 | Eixo `Calendario[ano_mes]`; valores `[Faturamento]`, `[Média Móvel 3 Meses]` | Filtro do visual: `situacao_mes` em Completo e Parcial. Faturamento `#2A78D6`, média `#EB6834`, linha de 2 px, sem marcadores. Rótulo só no último ponto. Subtítulo: "Agosto/2026 parcial (até 18/08)" |
| Faturamento por categoria | 800, 264, 456 × 220 | Eixo `Dim Produto[categoria]`; valor `[Faturamento]`; dica: `[Margem Bruta %]` | Uma cor (`#2A78D6`), ordem decrescente, rótulos na ponta da barra |
| Top 5 produtos | 24, 500, 600 × 196 | Eixo `Dim Produto[produto]`; valor `[Faturamento]` | Filtro Top N = 5 por `[Faturamento]`; uma cor; dica: `[Classe ABC]`, `[% do Faturamento]` |
| Vendedores | 640, 500, 616 × 196 | `Dim Vendedor[vendedor]`, `[Ranking Vendedor]`, `[Faturamento]`, `[Margem Bruta %]`, `[Pedidos]`, `[Ticket Médio]` | Barras de dados em Faturamento (`#2A78D6`); ordenado por Ranking |

**Regras visuais:**
- um eixo por gráfico (nunca dois);
- sem pizza ou rosca;
- cor por categoria só quando a categoria for a legenda;
- a variação sempre com seta e sinal (`▲ +` / `▼ −`), nunca só pela cor;
- texto alternativo em cada visual (**Formato › Geral › Texto alternativo**);
- ordem de tabulação: faixa, filtros, cartões, gráficos.

**Outras páginas, só quando agregarem valor:**
1. **Produtos e categorias:** curva ABC com `[% do Faturamento]` em colunas e `[% Acumulado ABC]` em linha, **no mesmo eixo de porcentagem**; tabela com `[Classe ABC]`, `[Cobertura de Estoque (dias)]` e `[Estoque Atual]`.
2. **Clientes:** `[Novos Clientes]` por `Calendario[ano_mes]` (inclui 2025), `[% Clientes Recorrentes]`, top 10 por `Dim Cliente[cliente_exibicao]` e `[Dias até a 1ª Compra (média)]`.
3. **Vendedores:** só com a nota de que a distribuição entre eles é quase uniforme por construção dos dados.

Ao criar a segunda página, adicione um **navegador de páginas** na faixa superior e **sincronize** os filtros.

## 8. Conferência: valores esperados (calculados no PostgreSQL, banco `techstore_dev_v3`)

Sem filtros, período inteiro:

| Medida | Esperado |
|---|---|
| Faturamento | R$ 335.062,30 |
| Custo | R$ 258.699,00 |
| Lucro Bruto | R$ 76.363,30 |
| Margem Bruta % | 22,8% (22,79%) |
| Pedidos / Unidades | 60 / 260 |
| Ticket Médio | R$ 5.584,37 |
| Itens por Pedido | 2,83 |
| Preço Médio de Venda | R$ 1.288,70 |
| Clientes Ativos / Recorrentes | 40 / 15 (37,5%) |
| Último Mês Completo | julho/2026 |
| Faturamento Último Mês Completo | R$ 40.434,40 |
| Variação Último Mês Completo % | −2,25% (jun: R$ 41.367,10) |
| Dias até a 1ª Compra (média) | 155,6 |
| Dias com Operação | 221 |

**Faturamento por mês, variação mensal e média móvel:**

| Mês | Faturamento | Variação Mensal % | Média Móvel 3 Meses | Acumulado no ano |
|---|---:|---:|---:|---:|
| jan/26 | 33.115,90 | — | — | 33.115,90 |
| fev/26 | 30.866,60 | −6,79% | — | 63.982,50 |
| mar/26 | 39.856,80 | 29,13% | 34.613,10 | 103.839,30 |
| abr/26 | 63.511,10 | 59,35% | 44.744,83 | 167.350,40 |
| mai/26 | 64.142,30 | 0,99% | 55.836,73 | 231.492,70 |
| jun/26 | 41.367,10 | −35,51% | 56.340,17 | 272.859,80 |
| jul/26 | 40.434,40 | −2,25% | 48.647,93 | 313.294,20 |
| ago/26 (parcial) | 21.768,10 | *em branco* | 34.523,20 | 335.062,30 |

**Por categoria:**

| Categoria | Faturamento | Custo | Lucro | Margem |
|---|---:|---:|---:|---:|
| Informática | 148.584,50 | 116.850,00 | 31.734,50 | 21,36% |
| Eletrônicos | 80.296,40 | 62.300,00 | 17.996,40 | 22,41% |
| Monitores | 57.896,10 | 44.400,00 | 13.496,10 | 23,31% |
| Periféricos | 20.994,90 | 15.530,00 | 5.464,90 | 26,03% |
| Armazenamento | 20.035,60 | 14.824,00 | 5.211,60 | 26,01% |
| Acessórios | 7.254,80 | 4.795,00 | 2.459,80 | 33,91% |

**Vendedores (ranking por faturamento):**

| # | Vendedor | Faturamento | Lucro | Pedidos | Ticket | Clientes |
|---:|---|---:|---:|---:|---:|---:|
| 1 | Marcelo Santos | 76.661,40 | 17.352,40 | 12 | 6.388,45 | 10 |
| 2 | Carlos Henrique | 65.543,90 | 14.836,90 | 13 | 5.041,84 | 12 |
| 3 | Rafael Martins | 65.463,10 | 14.854,10 | 11 | 5.951,19 | 10 |
| 4 | Juliana Mendes | 63.861,50 | 14.658,50 | 12 | 5.321,79 | 10 |
| 5 | Patricia Oliveira | 63.532,40 | 14.661,40 | 12 | 5.294,37 | 10 |

**Curva ABC:**
- **A:** 8 produtos, 81,6% do faturamento acumulado. Do Notebook Dell Inspiron 15 ao Monitor LG UltraWide 29.
- **B:** 6 produtos, até 96,2%. Do Monitor Samsung 24 ao Mouse Logitech G502.
- **C:** 5 produtos.

A lista completa está em [docs/VALIDACAO.md](VALIDACAO.md#valores-de-referência-para-o-power-bi).

**Novos clientes por mês de cadastro:**

| Mês | jun/25 | jul/25 | ago/25 | set/25 | out/25 | nov/25 | dez/25 | jan/26 | fev/26 | mar/26 | abr/26 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Novos | 5 | 4 | 4 | 3 | 4 | 4 | 3 | 6 | 3 | 3 | 1 |

Se algum valor divergir, verifique nesta ordem:
1. relacionamentos e direção do filtro;
2. tabela de datas marcada;
3. filtros de página ou de visual esquecidos;
4. tipos das colunas (moeda × decimal).

## 9. Segurança e publicação
- O modelo novo **não tem** CPF, e-mail, telefone, endereço completo nem salário. As views já os excluem, e o papel de leitura não acessa as tabelas.
- **Antes de publicar** no Power BI Service ou de compartilhar o `.pbix`: o arquivo leva os dados importados, que são fictícios, mas **não leva a senha**. Quem abrir vai precisar das próprias credenciais.
- **Níveis de privacidade:** em **Configurações da fonte de dados**, defina a fonte PostgreSQL como **Organizacional**.

## 10. Checklist de conclusão
- [ ] Localidade pt-BR e tema aplicados
- [ ] 2 parâmetros e 5 consultas; carga sem erros
- [ ] 4 relacionamentos 1:N com filtro único; `Calendario` marcada como tabela de datas
- [ ] 35 medidas com formato e pasta
- [ ] Página Visão Executiva conforme a seção 7
- [ ] Valores da seção 8 conferidos
- [ ] Tabelas e medidas antigas removidas; nenhum campo pessoal no modelo
- [ ] Capturas de tela (página inteira e detalhes) salvas em `docs/imagens/` para o README
