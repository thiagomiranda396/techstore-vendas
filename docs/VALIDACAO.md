# Validação dos scripts

Registro das execuções reais feitas em 2026-10-15 na **instância de testes isolada**:
- PostgreSQL 18.3, porta 5433, cluster `techstore_dev18`;
- usuário `techstore_dev_app`, sem senha e sem privilégios especiais.

O banco do autor (`db_analise_vendas`, porta 5432) **não foi acessado**. O ambiente está descrito em [AMBIENTE_DE_VALIDACAO.md](AMBIENTE_DE_VALIDACAO.md).

As saídas completas estão em [docs/evidencias/](evidencias/).

---

## 1. Resumo

| # | Verificação | Banco | Resultado |
|---|---|---|---|
| 1 | **Teste negativo:** cópia temporária dos scripts com um valor esperado alterado de propósito (clientes: 41) | `techstore_dev` | Código de saída 3, 1 FALHA (a provocada), transação desfeita, **0 objetos** no banco depois ✅ |
| 2 | Primeira carga com `00_executar_tudo.sql` | `techstore_dev` | Código 0 · **47/47 bloqueantes OK** · 2 avisos esperados ✅ |
| 3 | Conferências independentes, somente leitura | `techstore_dev` | 7 FKs · 0 órfãos · índices · contrato da view · 19 custos ✅ ([evidência](evidencias/2026-10-15_conferencias_independentes.txt)) |
| 4 | `07_consultas_analiticas.sql`, somente leitura | `techstore_dev` | Código 0 · 19 blocos de resultado, incluindo a Q01 corrigida ✅ |
| 5 | **Reexecução** do `00` no banco já carregado | `techstore_dev` | Código 3, `relação "cliente" já existe`. **Impressão digital antes e depois idêntica** ✅ |
| 6 | Carga após C10 e C11 (custo histórico e camada estrela) | `techstore_dev_v2` | Código 0 · **70/70 bloqueantes OK** · reexecução sem alteração ✅ |
| 7 | **Carga final** após o calendário estendido | `techstore_dev_v3` | Código 0 · **71/71 bloqueantes OK** · 2 avisos esperados ✅ ([evidência](evidencias/2026-10-15_v3_carga_e_testes.txt)) |
| 8 | `09_acesso_leitura_bi.sql` + teste real de privilégio | `techstore_dev_v3` | O leitor lê as 6 views; `SELECT` em `cliente` → `permissão negada` ✅ ([evidência](evidencias/2026-10-15_v3_acesso_leitura_bi.txt)) |
| 9 | `07` na versão final, somente leitura | `techstore_dev_v3` | Código 0 · 19 blocos ✅ ([evidência](evidencias/2026-10-15_v3_consultas_analiticas.txt)) |

**Avisos esperados**, informativos e não bloqueantes:
- 2 nomes homônimos (Daniel Oliveira #5 e #16; Lucas Pereira #9 e #29);
- o último mês tem dados só até 18/08/2026.

**Aviso de carga esperado:** preço do ID 3 diverge do banco do autor (3899.90 × 3899.00, decisão [C9](DECISOES_E_CORRECOES.md)).

---

## 2. Testes bloqueantes da versão final (71)

| Grupo | Quantidade | O que verifica |
|---|---:|---|
| IDS | 13 | Linhas por tabela, IDs de pedido contínuos (1–60), pedidos sem itens, 35 itens manuais, 3 itens por pedido gerado, produto repetido no pedido |
| DATAS | 6 | Pedido antes do cadastro ou da admissão (0), período, clientes com pedido (40), recorrentes (15), pedidos por vendedor (13/12/11/12/12) |
| FATURAMENTO | 15 | Total, manuais/gerados, unidades, catálogo, estoque, salários, os 8 meses |
| CUSTOS | 6 | 19/19 REAL, 0 divergências com a referência, catálogo, custo, lucro, margem |
| POWER BI | 7 | View existe, contrato de 15 colunas (nome, posição, tipo), 170 linhas, faturamento igual ao das tabelas, `custo_total = qtd × custo_unitario`, 0 sem custo, soma do custo |
| CUSTO HIST. | 4 | Itens sem custo (0), custo total pelo item, custo do item = custo atual (na carga inicial), `NOT NULL` |
| ESTRELA | 20 | Totais da fato, fato = `vw_vendas`, chaves únicas nas dimensões, 0 órfãos fato→dimensões, calendário de 730 dias sem duplicatas, cadastros cobertos pelo calendário, 1 mês parcial, **0 colunas pessoais** |

## 3. Reconciliação dos indicadores de referência

| Indicador | Referência documentada | `vw_vendas` | `vw_fato_vendas` | Tabelas |
|---|---:|---:|---:|---:|
| Faturamento | 335.062,30 | 335.062,30 | 335.062,30 | 335.062,30 |
| Custo | 258.699,00 | 258.699,00 | 258.699,00 | 258.699,00 |
| Lucro bruto | 76.363,30 | — | 76.363,30 | 76.363,30 |
| Margem bruta | 22,79% | — | 22,79% | 22,79% |

**Nenhum valor divergiu.** Todos os indicadores de referência bateram exatamente, sem qualquer ajuste nos dados.

## 4. Prova de que a reexecução não altera o estado

A impressão digital foi tirada em sessão somente leitura antes e depois da segunda execução do `00`. Ela inclui:
- MD5 do conteúdo ordenado de cada tabela;
- MD5 da lista de objetos e das definições de restrições;
- MD5 da definição da view;
- `last_value` das sequências.

Resultado em `techstore_dev`:
```
tabela categoria: 6 linhas, md5 a943a243753649b58dff5945f55f7b81
tabela cliente: 40 linhas, md5 47d03764d0fc1c1e712bfa122724d736
tabela endereco: 10 linhas, md5 b5580d05c519ec93ee94be0f82265b79
tabela itens_pedido: 170 linhas, md5 724dbe3ace42132901dd916bafbf27f8
tabela pedido: 60 linhas, md5 364297d3138468ca64c77a63d871c390
tabela produto: 19 linhas, md5 36ca632c7360928b20282893b6cad303
tabela telefone: 13 linhas, md5 92ce3eef6a0b1dd2916bd06cb750caf5
tabela vendedor: 5 linhas, md5 d140175b2a3556d563333f8d3834f726
objetos public: 35, md5 7537e1c1729c85fcedaa85af49f6f9fd
restricoes: 70, md5 22fa917dde4e19de137da5b917c80c9c
view: md5 67ce37da2596a42623817adf1f9854f3
sequencias: ..._seq=6, =40, =10, =170, =60, =19, =13, =5
→ antes e depois: IDÊNTICAS
```
Em `techstore_dev_v2`, o hash combinado `926724dc871be7539dcdd6844c6f28f3` também ficou idêntico antes e depois.

**Correção de processo registrada:** a primeira tentativa de impressão digital tinha um erro na minha consulta (`text || "char"` sem conversão). O ciclo foi refeito com a consulta corrigida, e o resultado acima vem da segunda execução.

## 5. Como repetir esta validação

```bash
# Banco novo e vazio a cada rodada (os scripts não usam DROP)
createdb -h localhost -p 5433 -O techstore_dev_app techstore_dev_v4
psql "host=localhost port=5433 dbname=techstore_dev_v4 user=techstore_dev_app" -X -w -v ON_ERROR_STOP=1 -f database/00_executar_tudo.sql
PGOPTIONS="-c default_transaction_read_only=on" psql "host=localhost port=5433 dbname=techstore_dev_v4 user=techstore_dev_app" -X -w -f database/07_consultas_analiticas.sql
```
Resultado esperado: código de saída 0, tabela de testes sem FALHA e `Carga concluída e validada.`

---

## Valores de referência para o Power BI

Calculados com SQL na `techstore_dev_v3`. Os principais estão replicados no [guia do Power BI](POWERBI_GUIA.md#8-conferência-valores-esperados-calculados-no-postgresql-banco-techstore_dev_v3).

**Curva ABC completa** (classe pelo acumulado *antes* do produto: A abaixo de 80%, B abaixo de 95%):

| # | Produto | Faturamento | % | % acum. | Classe |
|---:|---|---:|---:|---:|:-:|
| 1 | Notebook Dell Inspiron 15 | 55.898,70 | 16,7 | 16,7 | A |
| 2 | Desktop Dell OptiPlex | 50.687,00 | 15,1 | 31,8 | A |
| 3 | Notebook Lenovo IdeaPad 3 | 41.998,80 | 12,5 | 44,3 | A |
| 4 | Smart TV LG 50 Polegadas | 33.598,80 | 10,0 | 54,4 | A |
| 5 | Monitor Dell 27 QHD | 26.398,80 | 7,9 | 62,3 | A |
| 6 | Tablet Samsung Galaxy Tab | 24.698,70 | 7,4 | 69,6 | A |
| 7 | Smartphone Samsung Galaxy A55 | 21.998,90 | 6,6 | 76,2 | A |
| 8 | Monitor LG UltraWide 29 | 17.998,80 | 5,4 | 81,6 | A |
| 9 | Monitor Samsung 24 Full HD | 13.498,50 | 4,0 | 85,6 | B |
| 10 | SSD Samsung 2TB | 12.598,60 | 3,8 | 89,3 | B |
| 11 | Webcam Logitech C920 | 6.498,70 | 1,9 | 91,3 | B |
| 12 | SSD Kingston 1TB | 5.998,80 | 1,8 | 93,1 | B |
| 13 | Headset HyperX Cloud II | 5.398,80 | 1,6 | 94,7 | B |
| 14 | Mouse Logitech G502 | 5.198,70 | 1,6 | 96,2 | B |
| 15 | Teclado Mecânico Redragon | 3.898,70 | 1,2 | 97,4 | C |
| 16 | Hub USB-C 7 em 1 | 3.608,10 | 1,1 | 98,5 | C |
| 17 | Suporte para Notebook | 2.208,30 | 0,7 | 99,1 | C |
| 18 | Mousepad Gamer Grande | 1.438,40 | 0,4 | 99,6 | C |
| 19 | Pen Drive Kingston 128GB | 1.438,20 | 0,4 | 100,0 | C |

**Pedidos por dia da semana:**

| Dia | Seg | Ter | Qua | Qui | Sex | Sáb | Dom |
|---|---:|---:|---:|---:|---:|---:|---:|
| Pedidos | 8 | 10 | 8 | 7 | 10 | 10 | 7 |
| Faturamento | 46.335,30 | 53.885,00 | 40.875,70 | 46.383,70 | 55.573,40 | 53.874,10 | 38.135,10 |

**Menor cobertura de estoque** (estoque atual ÷ venda média diária em 221 dias):

| Produto | Estoque | Unidades vendidas | Cobertura |
|---|---:|---:|---:|
| Smart TV LG 50 Polegadas | 6 | 12 | 110,5 dias |
| Monitor Dell 27 QHD | 7 | 12 | 128,9 dias |
| Desktop Dell OptiPlex | 8 | 13 | 136,0 dias |
