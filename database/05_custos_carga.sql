-- =============================================================================
-- TechstoreVendas | 05_custos_carga.sql
-- Carga dos custos REAIS dos 19 produtos.
--
-- Origem dos valores: tabela db_analise_vendas.public.produto (banco do
-- autor), conferidos pelo autor em 2026-10-14. Valores transcritos sem
-- nenhuma alteração. Ver docs/DECISOES_E_CORRECOES.md (C1 e C9).
--
-- Garantias:
--   * Custos obrigatórios: carga vazia ou incompleta é recusada.
--   * Cada custo leva o NOME do produto no banco real; se o nome não for
--     idêntico a PRODUTO.NOME, a carga é recusada (nenhum custo no produto
--     errado).
--   * Apenas origem REAL é aceita para PRODUTO; não sobrescreve custos.
--   * PRECO_REFERENCIA guarda o preço do banco real apenas para conferência:
--     divergências são listadas como aviso e NÃO alteram PRODUTO.PRECO.
--     Divergência conhecida e aceita: ID 3 (3899.90 no banco real, 3899.00
--     nos scripts; decisão C9 = manter 3899.00).
-- =============================================================================

CREATE TEMP TABLE CARGA_CUSTO(
    ID_PRODUTO INT NOT NULL,
    NOME_REFERENCIA VARCHAR(100) NOT NULL,
    PRECO_REFERENCIA NUMERIC(10,2) NOT NULL,
    CUSTO NUMERIC(10,2) NOT NULL,
    CUSTO_ORIGEM VARCHAR(10) NOT NULL,
    CUSTO_FONTE VARCHAR(200) NOT NULL,

    CONSTRAINT PK_CARGA_CUSTO
    PRIMARY KEY(ID_PRODUTO)
);



-- -----------------------------------------------------------------------------
-- BLOCO A | CUSTOS REAIS
-- Fonte: db_analise_vendas.public.produto, conferido em 2026-10-14.
-- NOME_REFERENCIA e PRECO_REFERENCIA exatamente como no banco real.
-- -----------------------------------------------------------------------------

INSERT INTO CARGA_CUSTO (ID_PRODUTO, NOME_REFERENCIA, PRECO_REFERENCIA, CUSTO, CUSTO_ORIGEM, CUSTO_FONTE)
VALUES
( 1, 'Notebook Dell Inspiron 15',     4299.90, 3400.00, 'REAL', 'db_analise_vendas.public.produto, conferido em 2026-10-14'),
( 2, 'Notebook Lenovo IdeaPad 3',     3499.90, 2750.00, 'REAL', 'db_analise_vendas.public.produto, conferido em 2026-10-14'),
( 3, 'Desktop Dell OptiPlex',         3899.90, 3050.00, 'REAL', 'db_analise_vendas.public.produto, conferido em 2026-10-14'),
( 4, 'Mouse Logitech G502',            399.90,  300.00, 'REAL', 'db_analise_vendas.public.produto, conferido em 2026-10-14'),
( 5, 'Teclado Mecânico Redragon',      299.90,  220.00, 'REAL', 'db_analise_vendas.public.produto, conferido em 2026-10-14'),
( 6, 'Headset HyperX Cloud II',        449.90,  330.00, 'REAL', 'db_analise_vendas.public.produto, conferido em 2026-10-14'),
( 7, 'Webcam Logitech C920',           499.90,  370.00, 'REAL', 'db_analise_vendas.public.produto, conferido em 2026-10-14'),
( 8, 'Monitor LG UltraWide 29',       1499.90, 1150.00, 'REAL', 'db_analise_vendas.public.produto, conferido em 2026-10-14'),
( 9, 'Monitor Samsung 24 Full HD',     899.90,  680.00, 'REAL', 'db_analise_vendas.public.produto, conferido em 2026-10-14'),
(10, 'Monitor Dell 27 QHD',           2199.90, 1700.00, 'REAL', 'db_analise_vendas.public.produto, conferido em 2026-10-14'),
(11, 'Smartphone Samsung Galaxy A55', 1999.90, 1550.00, 'REAL', 'db_analise_vendas.public.produto, conferido em 2026-10-14'),
(12, 'Tablet Samsung Galaxy Tab',     1899.90, 1450.00, 'REAL', 'db_analise_vendas.public.produto, conferido em 2026-10-14'),
(13, 'Smart TV LG 50 Polegadas',      2799.90, 2200.00, 'REAL', 'db_analise_vendas.public.produto, conferido em 2026-10-14'),
(14, 'Suporte para Notebook',          129.90,   85.00, 'REAL', 'db_analise_vendas.public.produto, conferido em 2026-10-14'),
(15, 'Hub USB-C 7 em 1',               189.90,  130.00, 'REAL', 'db_analise_vendas.public.produto, conferido em 2026-10-14'),
(16, 'Mousepad Gamer Grande',           89.90,   55.00, 'REAL', 'db_analise_vendas.public.produto, conferido em 2026-10-14'),
(17, 'SSD Kingston 1TB',               499.90,  370.00, 'REAL', 'db_analise_vendas.public.produto, conferido em 2026-10-14'),
(18, 'SSD Samsung 2TB',                899.90,  680.00, 'REAL', 'db_analise_vendas.public.produto, conferido em 2026-10-14'),
(19, 'Pen Drive Kingston 128GB',        79.90,   48.00, 'REAL', 'db_analise_vendas.public.produto, conferido em 2026-10-14');



-- -----------------------------------------------------------------------------
-- BLOCO B | CUSTOS SINTÉTICOS
-- NÃO APLICÁVEL A PRODUTO. Os custos reais foram confirmados e nunca serão
-- substituídos. Um eventual custo histórico sintético (fase de
-- enriquecimento) ficará em tabela própria, com origem identificada.
-- -----------------------------------------------------------------------------



-- -----------------------------------------------------------------------------
-- Validação e aplicação
-- -----------------------------------------------------------------------------

DO $$
DECLARE
    v_linhas      INT;
    v_produtos    INT;
    v_nomes       TEXT;
    v_aplicados   INT;
    r             RECORD;
BEGIN
    SELECT COUNT(*) INTO v_linhas FROM CARGA_CUSTO;
    SELECT COUNT(*) INTO v_produtos FROM PRODUTO;

    IF v_linhas = 0 THEN
        RAISE EXCEPTION 'Carga recusada: nenhum custo informado. Custos reais são obrigatórios.';
    END IF;

    IF EXISTS (SELECT 1 FROM PRODUTO WHERE CUSTO IS NOT NULL) THEN
        RAISE EXCEPTION 'Carga recusada: já há custos em PRODUTO; esta carga não sobrescreve valores existentes.';
    END IF;

    IF EXISTS (SELECT 1 FROM CARGA_CUSTO WHERE CUSTO_ORIGEM <> 'REAL') THEN
        RAISE EXCEPTION 'Carga recusada: PRODUTO aceita apenas custos de origem REAL.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM CARGA_CUSTO CC
        LEFT JOIN PRODUTO P ON P.ID_PRODUTO = CC.ID_PRODUTO
        WHERE P.ID_PRODUTO IS NULL
    ) THEN
        RAISE EXCEPTION 'Carga recusada: há ID_PRODUTO inexistente em CARGA_CUSTO.';
    END IF;

    IF v_linhas <> v_produtos THEN
        RAISE EXCEPTION 'Carga recusada: % custos informados para % produtos.', v_linhas, v_produtos;
    END IF;

    -- Associação correta: o nome do banco real deve ser idêntico ao do script.
    SELECT string_agg(
               'ID ' || CC.ID_PRODUTO || ' (real="' || CC.NOME_REFERENCIA || '", script="' || P.NOME || '")',
               '; ' ORDER BY CC.ID_PRODUTO)
    INTO v_nomes
    FROM CARGA_CUSTO CC
    INNER JOIN PRODUTO P ON P.ID_PRODUTO = CC.ID_PRODUTO
    WHERE CC.NOME_REFERENCIA <> P.NOME;

    IF v_nomes IS NOT NULL THEN
        RAISE EXCEPTION 'Carga recusada: nomes divergentes, risco de custo no produto errado: %', v_nomes;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM CARGA_CUSTO
        WHERE CUSTO <= 0
           OR btrim(CUSTO_FONTE) = ''
    ) THEN
        RAISE EXCEPTION 'Carga recusada: custo <= 0 ou fonte vazia.';
    END IF;

    -- Divergências de preço: apenas aviso (PRODUTO.PRECO não é alterado).
    FOR r IN
        SELECT CC.ID_PRODUTO, CC.PRECO_REFERENCIA, P.PRECO
        FROM CARGA_CUSTO CC
        INNER JOIN PRODUTO P ON P.ID_PRODUTO = CC.ID_PRODUTO
        WHERE CC.PRECO_REFERENCIA <> P.PRECO
        ORDER BY CC.ID_PRODUTO
    LOOP
        RAISE NOTICE 'Aviso de preço: ID % tem % no banco real e % nos scripts (mantido o dos scripts).',
            r.ID_PRODUTO, r.PRECO_REFERENCIA, r.PRECO;
    END LOOP;

    UPDATE PRODUTO P
    SET CUSTO        = CC.CUSTO,
        CUSTO_ORIGEM = CC.CUSTO_ORIGEM,
        CUSTO_FONTE  = CC.CUSTO_FONTE
    FROM CARGA_CUSTO CC
    WHERE CC.ID_PRODUTO = P.ID_PRODUTO;

    SELECT COUNT(*) INTO v_aplicados
    FROM PRODUTO
    WHERE CUSTO IS NOT NULL
      AND CUSTO_ORIGEM = 'REAL';

    IF v_aplicados <> v_produtos THEN
        RAISE EXCEPTION 'Carga incompleta: % de % produtos com custo REAL.', v_aplicados, v_produtos;
    END IF;

    RAISE NOTICE 'Custos REAIS carregados: % de % produtos.', v_aplicados, v_produtos;
END $$;



-- -----------------------------------------------------------------------------
-- Custo histórico por item (decisão C10)
-- Registra em cada item o custo do produto no momento da carga. Daqui em
-- diante o custo do item é obrigatório e independente de PRODUTO.CUSTO:
-- uma mudança futura de custo no catálogo não altera vendas já registradas.
-- -----------------------------------------------------------------------------

UPDATE ITENS_PEDIDO I
SET CUSTO_UNITARIO = P.CUSTO
FROM PRODUTO P
WHERE P.ID_PRODUTO = I.ID_PRODUTO
  AND I.CUSTO_UNITARIO IS NULL;



DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM ITENS_PEDIDO WHERE CUSTO_UNITARIO IS NULL) THEN
        RAISE EXCEPTION 'Custo histórico incompleto: há itens sem CUSTO_UNITARIO.';
    END IF;
END $$;



ALTER TABLE ITENS_PEDIDO
ALTER COLUMN CUSTO_UNITARIO SET NOT NULL;
