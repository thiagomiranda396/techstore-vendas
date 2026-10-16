# Procedimento: descobrir os custos existentes sem modificar nada

**Objetivo:** encontrar os custos de produto usados pelo dashboard (medidas `Custo Total`, `Lucro Bruto` e `Margem de Lucro`) sem alterar o banco nem o .pbix original.

**Contexto:** nenhum script versionado cria ou preenche custos. Ver a correção C1 em [DECISOES_E_CORRECOES.md](DECISOES_E_CORRECOES.md).

Há três caminhos, em ordem de preferência. O autor executa os caminhos A e B.

---

## ✅ Resultado da verificação (2026-10-14)

O autor executou o Caminho A no banco **`db_analise_vendas`**, em modo somente leitura:

| Verificação | Resultado |
|---|---|
| `public.produto.custo` | Existe, `NUMERIC(10,2)`, preenchido nos 19 produtos |
| `public.vw_vendas` | 15 colunas, incluindo `custo_unitario` e `custo_total` |
| `custo_total = qtd × custo_unitario` | Diferença zero nos 20 registros conferidos |
| Medida do Power BI | `Custo Total = SUM('F_vw_vendas'[custo_total])`: o custo vem dos dados, não de uma premissa fixa |
| Nomes dos 19 produtos | Idênticos aos dos scripts |
| Preços | Idênticos, exceto o ID 3: 3899.90 no banco real e 3899.00 nos scripts (ver C9 em [DECISOES_E_CORRECOES.md](DECISOES_E_CORRECOES.md)) |

**Classificação:** custos **REAIS**. Os 19 valores estão em C1 de [DECISOES_E_CORRECOES.md](DECISOES_E_CORRECOES.md) e no Bloco A de `database/05_custos_carga.sql`, com `CUSTO_FONTE = 'db_analise_vendas.public.produto, conferido em 2026-10-14'`.

**Ainda não verificado no banco real:**
- consistência `custo_total = qtd × custo_unitario` em **todas** as linhas da view;
- totais de faturamento e custo;
- faixa de IDs de pedido e pedidos sem itens;
- posição e tipo de cada coluna da view;
- se `custo` aceita nulo.

As consultas para isso estão em "Consultas complementares", no fim deste documento.

Os caminhos abaixo ficam registrados para repetir a verificação no futuro.

---

## Caminho A: PostgreSQL em modo somente leitura

Use pgAdmin ou psql conectado ao banco onde o projeto foi desenvolvido. A primeira linha torna a sessão somente leitura: qualquer tentativa de escrita é recusada.

```sql
BEGIN TRANSACTION READ ONLY;

-- 0. Confirmar onde você está
SELECT current_database(), current_user, now();

-- 1. Existe alguma coluna de custo, compra ou margem?
SELECT table_name, column_name, data_type, numeric_precision, numeric_scale
FROM information_schema.columns
WHERE table_schema = 'public'
  AND column_name ILIKE ANY (ARRAY['%custo%', '%cost%', '%compra%', '%margem%']);

-- 2. Se a coluna custo existir em produto:
SELECT id_produto, nome, preco, custo,
       ROUND(100 * (preco - custo) / preco, 2) AS margem_pct
FROM produto
ORDER BY id_produto;

SELECT COUNT(*)                                 AS produtos,
       COUNT(custo)                             AS com_custo,
       COUNT(*) FILTER (WHERE custo >= preco)   AS custo_maior_igual_preco
FROM produto;

-- 3. Definição atual da view usada pelo Power BI
SELECT pg_get_viewdef('public.vw_vendas'::regclass, true);

-- 4. Estado dos IDs (hipótese da correção C2)
SELECT MIN(id_pedido), MAX(id_pedido), COUNT(*) FROM pedido;

SELECT COUNT(*) AS pedidos_sem_itens
FROM pedido p
WHERE NOT EXISTS (SELECT 1 FROM itens_pedido i WHERE i.id_pedido = p.id_pedido);

ROLLBACK;
```

Se a consulta 1 não retornar `produto.custo`, pule a consulta 2: ela daria erro, sem nenhum efeito no banco.

**Exportar o resultado.** O arquivo é gravado só no seu computador, não no banco:

- pgAdmin: botão "Save results to file" na grade de resultados.
- psql:

  ```
  \copy (SELECT id_produto, custo FROM produto ORDER BY 1) TO 'custos_reais.csv' WITH CSV HEADER
  ```

  O `.gitignore` do projeto impede que `custos_reais*.csv` seja versionado por engano.

---

## Caminho B: cache de dados do Power BI, sobre uma cópia

1. Copie `powerbi/TECHSTORE_VENDAS.pbix` para uma pasta **fora do projeto** e abra **a cópia** no Power BI Desktop.
2. Abra a **Exibição de tabela** e selecione `F_vw_vendas`. Confira as colunas `id_produto`, `produto` e `custo_unitario`.
3. Outra opção é a **Exibição de consulta DAX**:

   ```
   EVALUATE
   SUMMARIZECOLUMNS(
       F_vw_vendas[id_produto],
       F_vw_vendas[produto],
       "custo_min", MIN(F_vw_vendas[custo_unitario]),
       "custo_max", MAX(F_vw_vendas[custo_unitario]),
       "linhas", COUNTROWS(F_vw_vendas)
   )
   ORDER BY F_vw_vendas[id_produto]
   ```

   O nome da coluna pode ser outro se o Power Query renomeou; confira no painel **Dados**.
4. Confira também, sem editar:
   - a fórmula das medidas `Custo Total` e `Margem de Lucro` (clique na medida e leia a barra de fórmulas);
   - o Power Query (**Transformar dados › Editor Avançado**), para ver se o custo vem do banco ou de uma etapa criada no próprio Power Query. Feche com **Cancelar**.
5. Feche **sem salvar**.

**Limitações deste caminho:**

- O cache reflete a última atualização do relatório, provavelmente 05/09/2026.
- Só aparecem produtos que foram vendidos.
- Se `custo_min` for diferente de `custo_max` para o mesmo produto, o custo variou e é preciso investigar antes de usar.

**Prova de que o original não foi alterado.** O hash deve continuar `F7B6148A3390E2F28DF21A026DDDEB8A8844BA2F9B6784EDC6169678E8863593`:

```powershell
Get-FileHash powerbi\TECHSTORE_VENDAS.pbix -Algorithm SHA256
```

---

## Caminho C: nenhuma fonte encontrada

O custo continua vazio (`NULL`) e o dashboard de validação mostra lucro e margem em branco. O custo sintético só será definido na fase de enriquecimento, com uma regra aprovada, `CUSTO_ORIGEM = 'SINTETICO'` e `CUSTO_FONTE` descrevendo a regra.

---

## Depois de obter os valores

1. Se A e B divergirem, o custo foi alterado no banco depois de 05/09. O autor decide qual vale como oficial.
2. Os valores entram no **Bloco A** de `database/05_custos_carga.sql`, com:
   - `CUSTO_ORIGEM = 'REAL'`;
   - `CUSTO_FONTE` com o caminho e a data, por exemplo `'SELECT em produto no banco local, 2026-10-20'`.
3. A carga exige os 19 produtos, recusa origens misturadas e não sobrescreve custos já carregados.

---

## Consultas complementares (melhorias da Fase 4)

Todas são somente leitura. Execute um bloco por vez no pgAdmin.

```sql
-- Sessão somente leitura (a 3ª coluna deve mostrar "on")
SET SESSION CHARACTERISTICS AS TRANSACTION READ ONLY;
SELECT current_database(), current_user, current_setting('transaction_read_only');

-- Colunas de custo em QUALQUER schema (não só public)
SELECT table_schema, table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
  AND column_name ILIKE ANY (ARRAY['%custo%','%cost%','%compra%','%margem%']);

-- Definição da coluna e restrições de produto
SELECT column_name, data_type, numeric_precision, numeric_scale, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'produto'
ORDER BY ordinal_position;

SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'public.produto'::regclass
ORDER BY conname;

-- Contrato da view: posição, nome e tipo
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'vw_vendas'
ORDER BY ordinal_position;

-- Consistência do custo em TODAS as linhas da view
SELECT COUNT(*) AS linhas,
       COUNT(*) FILTER (WHERE custo_total IS DISTINCT FROM qtd * custo_unitario) AS divergentes,
       COUNT(*) FILTER (WHERE custo_unitario IS NULL) AS sem_custo
FROM public.vw_vendas;

-- Totais, para comparar com a versão reproduzível (custo total esperado: 258699.00)
SELECT COUNT(*) AS linhas, COUNT(DISTINCT pedido) AS pedidos,
       SUM(faturamento) AS faturamento, SUM(custo_total) AS custo,
       SUM(faturamento) - SUM(custo_total) AS lucro
FROM public.vw_vendas;

-- Preço do ID 3 nos itens vendidos (investigação da divergência C9)
SELECT preco_unitario, COUNT(*)
FROM public.itens_pedido
WHERE id_produto = 3
GROUP BY preco_unitario;

-- Voltar ao normal
SET SESSION CHARACTERISTICS AS TRANSACTION READ WRITE;
```

No Power BI, sobre uma **cópia** e sem salvar, a Exibição de consulta DAX lista todas as medidas e as colunas calculadas:

```dax
EVALUATE SELECTCOLUMNS(INFO.MEASURES(), "Medida", [Name], "Formula", [Expression])

EVALUATE SELECTCOLUMNS(FILTER(INFO.COLUMNS(), [Type] = 2), "Coluna", [ExplicitName], "Formula", [Expression])
```
