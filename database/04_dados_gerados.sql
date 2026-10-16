-- =============================================================================
-- TechstoreVendas | 04_dados_gerados.sql
--
-- *** DADOS FICTÍCIOS DE EXEMPLO (originais do projeto, gerador corrigido) ***
--
-- Origem: sql/isercao_dados.sql, linhas 225-264.
-- Correções:
--   1. IDs: os itens usavam "n + 60" (IDs 61-105), mas os pedidos gerados
--      recebem 16-60 num banco limpo, o que causava erro de FK. Agora pedidos e
--      itens são inseridos numa única instrução: os IDs vêm do RETURNING,
--      sem nenhum valor fixo.
--   2. Datas: o rodízio de clientes considera apenas quem já estava cadastrado
--      na data do pedido (antes, 7 pedidos eram anteriores ao cadastro).
--      Ordem do rodízio: DATA_CADASTRO, depois ID_CLIENTE.
--   3. Vendedores: rodízio entre os já admitidos, por ID_VENDEDOR (com os
--      dados atuais equivale ao original ((n - 1) % 5) + 1).
-- Mantido: datas (10/01/2026 + (n - 1) * 5 dias), fórmula de produtos e
--          quantidades e preço de tabela. O faturamento total não muda.
-- =============================================================================

DO $$
BEGIN
    IF (SELECT COUNT(*) FROM PEDIDO) <> 15 THEN
        RAISE EXCEPTION 'Carga abortada: 04_dados_gerados.sql espera exatamente os 15 pedidos de 03_dados_base.sql.';
    END IF;
END $$;



WITH PARAMETROS AS (
    -- Cada n gera um pedido com data única (passo de 5 dias).
    SELECT
        n,
        DATE '2026-01-10' + (n - 1) * 5 AS DATA_PEDIDO
    FROM generate_series(1, 45) AS n
),

NOVOS_PEDIDOS AS (
    INSERT INTO PEDIDO (ID_CLIENTE, ID_VENDEDOR, DATA_PEDIDO)
    SELECT
        CLI.ID_CLIENTE,
        VEND.ID_VENDEDOR,
        PAR.DATA_PEDIDO
    FROM PARAMETROS PAR

    -- Rodízio entre clientes já cadastrados na data do pedido.
    CROSS JOIN LATERAL (
        SELECT ELEGIVEIS.ID_CLIENTE
        FROM (
            SELECT
                C.ID_CLIENTE,
                ROW_NUMBER() OVER (ORDER BY C.DATA_CADASTRO, C.ID_CLIENTE) AS POSICAO,
                COUNT(*) OVER () AS TOTAL
            FROM CLIENTE C
            WHERE C.DATA_CADASTRO <= PAR.DATA_PEDIDO
        ) AS ELEGIVEIS
        WHERE ELEGIVEIS.POSICAO = ((PAR.n - 1) % ELEGIVEIS.TOTAL) + 1
    ) AS CLI

    -- Rodízio entre vendedores já admitidos na data do pedido.
    CROSS JOIN LATERAL (
        SELECT ELEGIVEIS.ID_VENDEDOR
        FROM (
            SELECT
                V.ID_VENDEDOR,
                ROW_NUMBER() OVER (ORDER BY V.ID_VENDEDOR) AS POSICAO,
                COUNT(*) OVER () AS TOTAL
            FROM VENDEDOR V
            WHERE V.DATA_ADMISSAO <= PAR.DATA_PEDIDO
        ) AS ELEGIVEIS
        WHERE ELEGIVEIS.POSICAO = ((PAR.n - 1) % ELEGIVEIS.TOTAL) + 1
    ) AS VEND

    ORDER BY PAR.n
    RETURNING ID_PEDIDO, DATA_PEDIDO
)

INSERT INTO ITENS_PEDIDO (ID_PEDIDO, ID_PRODUTO, QUANTIDADE, PRECO_UNITARIO)
SELECT
    NP.ID_PEDIDO,
    PR.ID_PRODUTO,

    -- Mesma regra original: acessórios e pen drive vendem até 3 unidades.
    CASE
        WHEN PR.ID_PRODUTO IN (14, 15, 16, 19)
        THEN 1 + ((G.n + K.k) % 3)
        ELSE 1 + ((G.n + K.k) % 2)
    END AS QUANTIDADE,

    PR.PRECO AS PRECO_UNITARIO
FROM NOVOS_PEDIDOS NP

-- Recupera n a partir da data (única por pedido gerado).
CROSS JOIN LATERAL (
    SELECT ((NP.DATA_PEDIDO - DATE '2026-01-10') / 5) + 1 AS n
) AS G

CROSS JOIN generate_series(1, 3) AS K(k)

JOIN PRODUTO PR
    ON PR.ID_PRODUTO = ((G.n * 3 + K.k * 5) % 19) + 1

ORDER BY NP.ID_PEDIDO, K.k;



DO $$
BEGIN
    IF (SELECT COUNT(*) FROM PEDIDO) <> 60 THEN
        RAISE EXCEPTION 'Gerador: esperados 60 pedidos no total.';
    END IF;
    IF (SELECT COUNT(*) FROM ITENS_PEDIDO) <> 170 THEN
        RAISE EXCEPTION 'Gerador: esperados 170 itens no total.';
    END IF;
END $$;
