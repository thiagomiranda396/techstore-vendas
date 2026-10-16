-- =============================================================================
-- TechstoreVendas | 06_views.sql
--
-- Origem: sql/views.sql, linhas 1-40 (repetida, idêntica, nas linhas 300-339).
-- Correção: a view é criada uma única vez.
-- Acréscimo (C11): camada estrela para o Power BI, ao final deste arquivo
-- (vw_fato_vendas, vw_dim_cliente, vw_dim_produto, vw_dim_vendedor,
-- vw_dim_calendario). A vw_vendas não muda.
--
-- CONTRATO COM O POWER BI (TECHSTORE_VENDAS.pbix, tabela F_vw_vendas):
-- manter exatamente as 15 colunas abaixo, nesta ordem e com estes nomes, no
-- schema public. CREATE OR REPLACE VIEW não permite renomear nem remover
-- colunas; qualquer mudança de contrato deve ser feita numa view nova.
--   1 pedido          6 qtd              11 custo_total
--   2 cliente         7 preco_unitario   12 id_cliente
--   3 vendedor        8 faturamento      13 id_vendedor
--   4 produto         9 data_pedido      14 id_produto
--   5 categoria      10 custo_unitario   15 id_categoria
-- A conferência automática está em 08_verificacoes_qualidade.sql.
-- =============================================================================

CREATE OR REPLACE VIEW public.vw_vendas AS

SELECT
P.ID_PEDIDO AS PEDIDO,
C.NOME AS CLIENTE,
V.NOME AS VENDEDOR,
PR.NOME AS PRODUTO,
CA.NOME AS CATEGORIA,

I.QUANTIDADE AS QTD,
I.PRECO_UNITARIO AS PRECO_UNITARIO,

I.QUANTIDADE * I.PRECO_UNITARIO AS FATURAMENTO,

P.DATA_PEDIDO AS DATA_PEDIDO,

PR.CUSTO AS CUSTO_UNITARIO,
I.QUANTIDADE * PR.CUSTO AS CUSTO_TOTAL,

C.ID_CLIENTE AS ID_CLIENTE,
V.ID_VENDEDOR AS ID_VENDEDOR,
PR.ID_PRODUTO AS ID_PRODUTO,
CA.ID_CATEGORIA AS ID_CATEGORIA

FROM PEDIDO P

INNER JOIN CLIENTE C
ON P.ID_CLIENTE = C.ID_CLIENTE

INNER JOIN VENDEDOR V
ON P.ID_VENDEDOR = V.ID_VENDEDOR

INNER JOIN ITENS_PEDIDO I
ON I.ID_PEDIDO = P.ID_PEDIDO

INNER JOIN PRODUTO PR
ON I.ID_PRODUTO = PR.ID_PRODUTO

INNER JOIN CATEGORIA CA
ON PR.ID_CATEGORIA = CA.ID_CATEGORIA;



COMMENT ON VIEW public.vw_vendas IS
    'Fato de vendas por item (1 linha por item de pedido). Contrato com o Power BI: 15 colunas fixas. CUSTO_UNITARIO/CUSTO_TOTAL vêm do custo real atual de PRODUTO (db_analise_vendas, conferido em 2026-10-14).';



-- =============================================================================
-- CAMADA ESTRELA PARA O POWER BI (decisão C11)
-- Views novas, criadas AO LADO da vw_vendas (que não muda).
-- Princípios:
--   * Fato só com chaves e medidas; nomes e atributos ficam nas dimensões.
--   * Nenhum dado pessoal desnecessário: sem CPF, e-mail, telefone,
--     logradouro, número, CEP ou salário.
--   * Custo da fato = custo histórico do item (ITENS_PEDIDO.CUSTO_UNITARIO).
-- =============================================================================

CREATE OR REPLACE VIEW public.vw_fato_vendas AS

SELECT
I.ID_ITENS_PEDIDO AS ID_ITEM,
I.ID_PEDIDO,
P.DATA_PEDIDO,
P.ID_CLIENTE,
P.ID_VENDEDOR,
I.ID_PRODUTO,

I.QUANTIDADE,
I.PRECO_UNITARIO,
I.QUANTIDADE * I.PRECO_UNITARIO AS FATURAMENTO,

I.CUSTO_UNITARIO,
I.QUANTIDADE * I.CUSTO_UNITARIO AS CUSTO_TOTAL,

I.QUANTIDADE * (I.PRECO_UNITARIO - I.CUSTO_UNITARIO) AS LUCRO_BRUTO

FROM ITENS_PEDIDO I

INNER JOIN PEDIDO P
ON P.ID_PEDIDO = I.ID_PEDIDO;



COMMENT ON VIEW public.vw_fato_vendas IS
    'Fato de vendas (1 linha por item). Somente chaves e medidas. Custo = custo histórico registrado no item.';



CREATE OR REPLACE VIEW public.vw_dim_cliente AS

SELECT
C.ID_CLIENTE,
C.NOME AS CLIENTE,

-- Homônimos (ex.: "Daniel Oliveira" IDs 5 e 16): rótulo único para visuais.
C.NOME || ' (#' || C.ID_CLIENTE || ')' AS CLIENTE_EXIBICAO,

C.DATA_CADASTRO,
DATE_TRUNC('month', C.DATA_CADASTRO)::DATE AS MES_CADASTRO,

COALESCE(E.BAIRRO, 'Não informado') AS BAIRRO,
COALESCE(E.CIDADE, 'Não informado') AS CIDADE,
COALESCE(E.UF::TEXT, 'NI') AS UF

FROM CLIENTE C

-- No máximo um endereço por cliente (o de menor ID), para manter a granularidade.
LEFT JOIN LATERAL (
    SELECT EN.BAIRRO, EN.CIDADE, EN.UF
    FROM ENDERECO EN
    WHERE EN.ID_CLIENTE = C.ID_CLIENTE
    ORDER BY EN.ID_ENDERECO
    LIMIT 1
) AS E ON TRUE;



COMMENT ON VIEW public.vw_dim_cliente IS
    'Dimensão de clientes sem dados pessoais sensíveis (sem CPF, e-mail, telefone ou endereço completo). CLIENTE_EXIBICAO diferencia homônimos.';



CREATE OR REPLACE VIEW public.vw_dim_produto AS

SELECT
PR.ID_PRODUTO,
PR.NOME AS PRODUTO,
CA.ID_CATEGORIA,
CA.NOME AS CATEGORIA,
PR.PRECO AS PRECO_ATUAL,
PR.CUSTO AS CUSTO_ATUAL,
ROUND(100 * (PR.PRECO - PR.CUSTO) / PR.PRECO, 2) AS MARGEM_ATUAL_PCT,
PR.ESTOQUE AS ESTOQUE_ATUAL

FROM PRODUTO PR

INNER JOIN CATEGORIA CA
ON CA.ID_CATEGORIA = PR.ID_CATEGORIA;



COMMENT ON VIEW public.vw_dim_produto IS
    'Dimensão de produtos com a categoria desnormalizada. Preço, custo, margem e estoque são valores ATUAIS (foto do catálogo), não históricos.';



CREATE OR REPLACE VIEW public.vw_dim_vendedor AS

SELECT
V.ID_VENDEDOR,
V.NOME AS VENDEDOR,
V.DATA_ADMISSAO

FROM VENDEDOR V;



COMMENT ON VIEW public.vw_dim_vendedor IS
    'Dimensão de vendedores sem e-mail, telefone e salário (dado de RH fora do escopo analítico).';



CREATE OR REPLACE VIEW public.vw_dim_calendario AS

-- Cobre os anos completos desde o primeiro cadastro de cliente (ou a primeira
-- venda, se anterior) até o ano da última venda, para servir tanto à fato
-- quanto à análise de novos clientes por data de cadastro.
WITH LIMITES AS (
    SELECT
        LEAST((SELECT MIN(DATA_PEDIDO) FROM PEDIDO),
              (SELECT MIN(DATA_CADASTRO) FROM CLIENTE)) AS INICIO,
        (SELECT MIN(DATA_PEDIDO) FROM PEDIDO) AS PRIMEIRA_VENDA,
        (SELECT MAX(DATA_PEDIDO) FROM PEDIDO) AS ULTIMA_VENDA
),

DIAS AS (
    SELECT
        G.DIA::DATE AS DATA,
        L.PRIMEIRA_VENDA,
        L.ULTIMA_VENDA
    FROM LIMITES L
    CROSS JOIN generate_series(
        DATE_TRUNC('year', L.INICIO),
        DATE_TRUNC('year', L.ULTIMA_VENDA) + INTERVAL '1 year - 1 day',
        INTERVAL '1 day'
    ) AS G(DIA)
)

SELECT
D.DATA,
EXTRACT(YEAR FROM D.DATA)::INT AS ANO,
EXTRACT(QUARTER FROM D.DATA)::INT AS TRIMESTRE,
EXTRACT(MONTH FROM D.DATA)::INT AS MES,

(ARRAY['Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho',
       'Agosto','Setembro','Outubro','Novembro','Dezembro'])[EXTRACT(MONTH FROM D.DATA)::INT] AS NOME_MES,

(ARRAY['jan','fev','mar','abr','mai','jun','jul','ago','set','out','nov','dez'])[EXTRACT(MONTH FROM D.DATA)::INT]
    || '/' || TO_CHAR(D.DATA, 'YY') AS ANO_MES,

(EXTRACT(YEAR FROM D.DATA) * 100 + EXTRACT(MONTH FROM D.DATA))::INT AS ANO_MES_NUM,

DATE_TRUNC('month', D.DATA)::DATE AS INICIO_MES,

EXTRACT(ISODOW FROM D.DATA)::INT AS DIA_SEMANA_NUM,

(ARRAY['Segunda','Terça','Quarta','Quinta','Sexta','Sábado','Domingo'])[EXTRACT(ISODOW FROM D.DATA)::INT] AS DIA_SEMANA,

-- Situação do mês em relação à última venda registrada.
CASE
    WHEN (DATE_TRUNC('month', D.DATA) + INTERVAL '1 month - 1 day')::DATE < D.PRIMEIRA_VENDA THEN 'Antes das vendas'
    WHEN DATE_TRUNC('month', D.DATA)::DATE > D.ULTIMA_VENDA THEN 'Sem vendas registradas'
    WHEN (DATE_TRUNC('month', D.DATA) + INTERVAL '1 month - 1 day')::DATE > D.ULTIMA_VENDA THEN 'Parcial'
    ELSE 'Completo'
END AS SITUACAO_MES

FROM DIAS D;



COMMENT ON VIEW public.vw_dim_calendario IS
    'Calendário diário (anos completos do primeiro cadastro de cliente ao ano da última venda), com nomes em português e situação do mês (Antes das vendas, Completo, Parcial, Sem vendas registradas).';
