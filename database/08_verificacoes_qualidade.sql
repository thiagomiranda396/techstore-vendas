-- =============================================================================
-- TechstoreVendas | 08_verificacoes_qualidade.sql
-- Bateria de testes da carga. Resultado em RESULTADO_TESTES:
--   OK    = conforme o esperado
--   FALHA = bloqueia: ao final, uma exceção desfaz a transação inteira
--   AVISO = informativo, não bloqueia
--
-- Os valores esperados de faturamento e unidades não dependem de qual cliente
-- recebeu cada pedido, e por isso servem de referência contra o projeto
-- original (ver docs/DECISOES_E_CORRECOES.md).
--
-- Custos: valores reais de db_analise_vendas.public.produto (conferidos em
-- 2026-10-14). Os esperados de faturamento e lucro usam o preço dos scripts
-- para o ID 3 (3899.00), conforme a decisão C9.
-- =============================================================================

CREATE TEMP TABLE RESULTADO_TESTES(
    ORDEM INT GENERATED ALWAYS AS IDENTITY,
    GRUPO VARCHAR(20) NOT NULL,
    TESTE VARCHAR(120) NOT NULL,
    ESPERADO TEXT,
    OBTIDO TEXT,
    STATUS VARCHAR(5) NOT NULL,

    CONSTRAINT CK_RESULTADO_TESTES_STATUS
    CHECK(STATUS IN('OK', 'FALHA', 'AVISO'))
);



-- =============================================================================
-- 1. IDS E VOLUME
-- =============================================================================

INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'IDS',
    'Linhas em ' || T.TABELA,
    T.ESPERADO::TEXT,
    T.OBTIDO::TEXT,
    CASE WHEN T.OBTIDO = T.ESPERADO THEN 'OK' ELSE 'FALHA' END
FROM (
    VALUES
    ('CLIENTE',      40,  (SELECT COUNT(*) FROM CLIENTE)),
    ('ENDERECO',     10,  (SELECT COUNT(*) FROM ENDERECO)),
    ('TELEFONE',     13,  (SELECT COUNT(*) FROM TELEFONE)),
    ('VENDEDOR',      5,  (SELECT COUNT(*) FROM VENDEDOR)),
    ('CATEGORIA',     6,  (SELECT COUNT(*) FROM CATEGORIA)),
    ('PRODUTO',      19,  (SELECT COUNT(*) FROM PRODUTO)),
    ('PEDIDO',       60,  (SELECT COUNT(*) FROM PEDIDO)),
    ('ITENS_PEDIDO', 170, (SELECT COUNT(*) FROM ITENS_PEDIDO))
) AS T(TABELA, ESPERADO, OBTIDO);



INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'IDS',
    'IDs de pedido contínuos (mín-máx / total)',
    '1-60 / 60',
    MIN(ID_PEDIDO) || '-' || MAX(ID_PEDIDO) || ' / ' || COUNT(*),
    CASE WHEN MIN(ID_PEDIDO) = 1 AND MAX(ID_PEDIDO) = 60 AND COUNT(*) = 60
         THEN 'OK' ELSE 'FALHA' END
FROM PEDIDO;



INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'IDS',
    'Pedidos sem itens',
    '0',
    COUNT(*)::TEXT,
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM PEDIDO P
WHERE NOT EXISTS (
    SELECT 1 FROM ITENS_PEDIDO I WHERE I.ID_PEDIDO = P.ID_PEDIDO
);



-- Pedidos 1-15 são os manuais (IDs conferidos em 03_dados_base.sql).
INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'IDS',
    'Itens dos 15 pedidos manuais',
    '35',
    COUNT(*)::TEXT,
    CASE WHEN COUNT(*) = 35 THEN 'OK' ELSE 'FALHA' END
FROM ITENS_PEDIDO
WHERE ID_PEDIDO <= 15;



INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'IDS',
    'Pedidos gerados com quantidade de itens diferente de 3',
    '0',
    COUNT(*)::TEXT,
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM (
    SELECT P.ID_PEDIDO
    FROM PEDIDO P
    LEFT JOIN ITENS_PEDIDO I ON I.ID_PEDIDO = P.ID_PEDIDO
    WHERE P.ID_PEDIDO > 15
    GROUP BY P.ID_PEDIDO
    HAVING COUNT(I.ID_ITENS_PEDIDO) <> 3
) AS X;



INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'IDS',
    'Produto repetido no mesmo pedido',
    '0',
    COUNT(*)::TEXT,
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM (
    SELECT ID_PEDIDO, ID_PRODUTO
    FROM ITENS_PEDIDO
    GROUP BY ID_PEDIDO, ID_PRODUTO
    HAVING COUNT(*) > 1
) AS X;



-- =============================================================================
-- 2. DATAS
-- =============================================================================

INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'DATAS',
    'Pedidos anteriores ao cadastro do cliente',
    '0',
    COUNT(*)::TEXT,
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM PEDIDO P
INNER JOIN CLIENTE C ON C.ID_CLIENTE = P.ID_CLIENTE
WHERE P.DATA_PEDIDO < C.DATA_CADASTRO;



INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'DATAS',
    'Pedidos anteriores à admissão do vendedor',
    '0',
    COUNT(*)::TEXT,
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM PEDIDO P
INNER JOIN VENDEDOR V ON V.ID_VENDEDOR = P.ID_VENDEDOR
WHERE P.DATA_PEDIDO < V.DATA_ADMISSAO;



INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'DATAS',
    'Período dos pedidos',
    '2026-01-10 a 2026-08-18',
    MIN(DATA_PEDIDO) || ' a ' || MAX(DATA_PEDIDO),
    CASE WHEN MIN(DATA_PEDIDO) = DATE '2026-01-10' AND MAX(DATA_PEDIDO) = DATE '2026-08-18'
         THEN 'OK' ELSE 'FALHA' END
FROM PEDIDO;



INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'DATAS',
    'Clientes com ao menos 1 pedido',
    '40',
    COUNT(DISTINCT ID_CLIENTE)::TEXT,
    CASE WHEN COUNT(DISTINCT ID_CLIENTE) = 40 THEN 'OK' ELSE 'FALHA' END
FROM PEDIDO;



INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'DATAS',
    'Clientes com 2 ou mais pedidos',
    '15',
    COUNT(*)::TEXT,
    CASE WHEN COUNT(*) = 15 THEN 'OK' ELSE 'FALHA' END
FROM (
    SELECT ID_CLIENTE
    FROM PEDIDO
    GROUP BY ID_CLIENTE
    HAVING COUNT(*) >= 2
) AS X;



INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'DATAS',
    'Pedidos por vendedor (IDs 1/2/3/4/5)',
    '13/12/11/12/12',
    string_agg(X.TOTAL::TEXT, '/' ORDER BY X.ID_VENDEDOR),
    CASE WHEN string_agg(X.TOTAL::TEXT, '/' ORDER BY X.ID_VENDEDOR) = '13/12/11/12/12'
         THEN 'OK' ELSE 'FALHA' END
FROM (
    SELECT V.ID_VENDEDOR, COUNT(P.ID_PEDIDO) AS TOTAL
    FROM VENDEDOR V
    LEFT JOIN PEDIDO P ON P.ID_VENDEDOR = V.ID_VENDEDOR
    GROUP BY V.ID_VENDEDOR
) AS X;



-- =============================================================================
-- 3. FATURAMENTO E CATÁLOGO
-- =============================================================================

INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'FATURAMENTO',
    T.TESTE,
    T.ESPERADO::TEXT,
    COALESCE(T.OBTIDO, 0)::TEXT,
    CASE WHEN T.OBTIDO = T.ESPERADO THEN 'OK' ELSE 'FALHA' END
FROM (
    VALUES
    ('Faturamento total',
        335062.30,
        (SELECT SUM(QUANTIDADE * PRECO_UNITARIO) FROM ITENS_PEDIDO)),
    ('Faturamento dos pedidos manuais (1-15)',
        50044.00,
        (SELECT SUM(QUANTIDADE * PRECO_UNITARIO) FROM ITENS_PEDIDO WHERE ID_PEDIDO <= 15)),
    ('Faturamento dos pedidos gerados (16-60)',
        285018.30,
        (SELECT SUM(QUANTIDADE * PRECO_UNITARIO) FROM ITENS_PEDIDO WHERE ID_PEDIDO > 15)),
    ('Unidades vendidas',
        260,
        (SELECT SUM(QUANTIDADE) FROM ITENS_PEDIDO)),
    ('Soma dos preços do catálogo',
        26537.20,
        (SELECT SUM(PRECO) FROM PRODUTO)),
    ('Soma do estoque',
        367,
        (SELECT SUM(ESTOQUE) FROM PRODUTO)),
    ('Soma dos salários',
        21000.00,
        (SELECT SUM(SALARIO) FROM VENDEDOR))
) AS T(TESTE, ESPERADO, OBTIDO);



INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'FATURAMENTO',
    'Faturamento de ' || E.MES,
    E.VALOR::TEXT,
    COALESCE(R.VALOR, 0)::TEXT,
    CASE WHEN R.VALOR = E.VALOR THEN 'OK' ELSE 'FALHA' END
FROM (
    VALUES
    ('2026-01', 33115.90),
    ('2026-02', 30866.60),
    ('2026-03', 39856.80),
    ('2026-04', 63511.10),
    ('2026-05', 64142.30),
    ('2026-06', 41367.10),
    ('2026-07', 40434.40),
    ('2026-08', 21768.10)
) AS E(MES, VALOR)
LEFT JOIN (
    SELECT
        TO_CHAR(P.DATA_PEDIDO, 'YYYY-MM') AS MES,
        SUM(I.QUANTIDADE * I.PRECO_UNITARIO) AS VALOR
    FROM PEDIDO P
    INNER JOIN ITENS_PEDIDO I ON I.ID_PEDIDO = P.ID_PEDIDO
    GROUP BY TO_CHAR(P.DATA_PEDIDO, 'YYYY-MM')
) AS R ON R.MES = E.MES
ORDER BY E.MES;



-- =============================================================================
-- 3B. CUSTOS REAIS
-- Referência: db_analise_vendas.public.produto, conferido em 2026-10-14.
-- A lista abaixo é independente de 05_custos_carga.sql: segunda barreira
-- contra custo no produto errado ou valor alterado.
-- =============================================================================

INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'CUSTOS',
    'Produtos com custo de origem REAL',
    '19/19',
    COUNT(*) FILTER (WHERE CUSTO IS NOT NULL AND CUSTO_ORIGEM = 'REAL') || '/' || COUNT(*),
    CASE WHEN COUNT(*) = 19
          AND COUNT(*) FILTER (WHERE CUSTO IS NOT NULL AND CUSTO_ORIGEM = 'REAL') = 19
         THEN 'OK' ELSE 'FALHA' END
FROM PRODUTO;



INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'CUSTOS',
    'Custos divergentes da referência conferida (ID e valor)',
    '0',
    COUNT(*) || COALESCE(' -> IDs ' || string_agg(COALESCE(R.ID_PRODUTO, P.ID_PRODUTO)::TEXT, ', '), ''),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM (
    VALUES
    ( 1, 3400.00), ( 2, 2750.00), ( 3, 3050.00), ( 4,  300.00), ( 5,  220.00),
    ( 6,  330.00), ( 7,  370.00), ( 8, 1150.00), ( 9,  680.00), (10, 1700.00),
    (11, 1550.00), (12, 1450.00), (13, 2200.00), (14,   85.00), (15,  130.00),
    (16,   55.00), (17,  370.00), (18,  680.00), (19,   48.00)
) AS R(ID_PRODUTO, CUSTO)
FULL JOIN PRODUTO P
    ON P.ID_PRODUTO = R.ID_PRODUTO
   AND P.CUSTO = R.CUSTO
WHERE R.ID_PRODUTO IS NULL
   OR P.ID_PRODUTO IS NULL;



INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'CUSTOS',
    T.TESTE,
    T.ESPERADO::TEXT,
    COALESCE(T.OBTIDO, 0)::TEXT,
    CASE WHEN T.OBTIDO = T.ESPERADO THEN 'OK' ELSE 'FALHA' END
FROM (
    VALUES
    ('Soma dos custos do catálogo',
        20518.00,
        (SELECT SUM(CUSTO) FROM PRODUTO)),
    ('Custo total das vendas',
        258699.00,
        (SELECT SUM(I.QUANTIDADE * P.CUSTO)
         FROM ITENS_PEDIDO I
         INNER JOIN PRODUTO P ON P.ID_PRODUTO = I.ID_PRODUTO)),
    ('Lucro bruto',
        76363.30,
        (SELECT SUM(I.QUANTIDADE * I.PRECO_UNITARIO) - SUM(I.QUANTIDADE * P.CUSTO)
         FROM ITENS_PEDIDO I
         INNER JOIN PRODUTO P ON P.ID_PRODUTO = I.ID_PRODUTO)),
    ('Margem bruta % (2 casas)',
        22.79,
        (SELECT ROUND(100 * (SUM(I.QUANTIDADE * I.PRECO_UNITARIO) - SUM(I.QUANTIDADE * P.CUSTO))
                          / SUM(I.QUANTIDADE * I.PRECO_UNITARIO), 2)
         FROM ITENS_PEDIDO I
         INNER JOIN PRODUTO P ON P.ID_PRODUTO = I.ID_PRODUTO))
) AS T(TESTE, ESPERADO, OBTIDO);



-- =============================================================================
-- 4. COMPATIBILIDADE COM O POWER BI (contrato da vw_vendas)
-- =============================================================================

INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'POWER BI',
    'View public.vw_vendas existe',
    '1',
    COUNT(*)::TEXT,
    CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'FALHA' END
FROM information_schema.views
WHERE table_schema = 'public'
  AND table_name = 'vw_vendas';



-- Compara nome, posição e tipo das 15 colunas com o contrato.
INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'POWER BI',
    'Colunas da vw_vendas divergentes do contrato (nome/posição/tipo)',
    '0',
    COUNT(*) || COALESCE(' -> ' || string_agg(COALESCE(E.NOME, A.NOME), ', '), ''),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM (
    VALUES
    ( 1, 'pedido',         'integer'),
    ( 2, 'cliente',        'character varying'),
    ( 3, 'vendedor',       'character varying'),
    ( 4, 'produto',        'character varying'),
    ( 5, 'categoria',      'character varying'),
    ( 6, 'qtd',            'integer'),
    ( 7, 'preco_unitario', 'numeric'),
    ( 8, 'faturamento',    'numeric'),
    ( 9, 'data_pedido',    'date'),
    (10, 'custo_unitario', 'numeric'),
    (11, 'custo_total',    'numeric'),
    (12, 'id_cliente',     'integer'),
    (13, 'id_vendedor',    'integer'),
    (14, 'id_produto',     'integer'),
    (15, 'id_categoria',   'integer')
) AS E(POSICAO, NOME, TIPO)
FULL JOIN (
    SELECT
        ordinal_position::INT AS POSICAO,
        column_name::TEXT     AS NOME,
        data_type::TEXT       AS TIPO
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'vw_vendas'
) AS A
    ON A.POSICAO = E.POSICAO
   AND A.NOME = E.NOME
   AND A.TIPO = E.TIPO
WHERE E.POSICAO IS NULL
   OR A.POSICAO IS NULL;



INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'POWER BI',
    'Linhas da vw_vendas (1 por item)',
    '170',
    COUNT(*)::TEXT,
    CASE WHEN COUNT(*) = 170 THEN 'OK' ELSE 'FALHA' END
FROM vw_vendas;



INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'POWER BI',
    'Faturamento da vw_vendas igual ao de ITENS_PEDIDO',
    (SELECT SUM(QUANTIDADE * PRECO_UNITARIO) FROM ITENS_PEDIDO)::TEXT,
    SUM(FATURAMENTO)::TEXT,
    CASE WHEN SUM(FATURAMENTO) = (SELECT SUM(QUANTIDADE * PRECO_UNITARIO) FROM ITENS_PEDIDO)
         THEN 'OK' ELSE 'FALHA' END
FROM vw_vendas;



-- Base da medida do Power BI: Custo Total = SUM('F_vw_vendas'[custo_total]).
INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'POWER BI',
    'Linhas da vw_vendas com custo_total <> qtd * custo_unitario',
    '0',
    COUNT(*) FILTER (WHERE CUSTO_TOTAL IS DISTINCT FROM QTD * CUSTO_UNITARIO)::TEXT,
    CASE WHEN COUNT(*) FILTER (WHERE CUSTO_TOTAL IS DISTINCT FROM QTD * CUSTO_UNITARIO) = 0
         THEN 'OK' ELSE 'FALHA' END
FROM vw_vendas;



INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'POWER BI',
    'Linhas da vw_vendas sem custo',
    '0',
    COUNT(*) FILTER (WHERE CUSTO_UNITARIO IS NULL OR CUSTO_TOTAL IS NULL)::TEXT,
    CASE WHEN COUNT(*) FILTER (WHERE CUSTO_UNITARIO IS NULL OR CUSTO_TOTAL IS NULL) = 0
         THEN 'OK' ELSE 'FALHA' END
FROM vw_vendas;



INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'POWER BI',
    'Soma de custo_total na vw_vendas',
    '258699.00',
    COALESCE(SUM(CUSTO_TOTAL), 0)::TEXT,
    CASE WHEN SUM(CUSTO_TOTAL) = 258699.00 THEN 'OK' ELSE 'FALHA' END
FROM vw_vendas;



-- =============================================================================
-- 4B. CUSTO HISTÓRICO POR ITEM E CAMADA ESTRELA (decisões C10 e C11)
-- =============================================================================

INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'CUSTO HIST.',
    T.TESTE,
    T.ESPERADO::TEXT,
    COALESCE(T.OBTIDO, -1)::TEXT,
    CASE WHEN T.OBTIDO = T.ESPERADO THEN 'OK' ELSE 'FALHA' END
FROM (
    VALUES
    ('Itens sem custo histórico',
        0,
        (SELECT COUNT(*) FROM ITENS_PEDIDO WHERE CUSTO_UNITARIO IS NULL)),
    ('Custo total pelo custo histórico dos itens',
        258699.00,
        (SELECT SUM(QUANTIDADE * CUSTO_UNITARIO) FROM ITENS_PEDIDO)),
    -- Na carga inicial, custo do item = custo atual do produto. Se o custo do
    -- catálogo mudar no futuro, este teste deve ser revisto (diferença esperada).
    ('Itens com custo histórico diferente do custo atual do produto',
        0,
        (SELECT COUNT(*) FROM ITENS_PEDIDO I
         INNER JOIN PRODUTO P ON P.ID_PRODUTO = I.ID_PRODUTO
         WHERE I.CUSTO_UNITARIO <> P.CUSTO)),
    ('CUSTO_UNITARIO de ITENS_PEDIDO é NOT NULL (1 = sim)',
        1,
        (SELECT COUNT(*) FROM information_schema.columns
         WHERE table_schema = 'public' AND table_name = 'itens_pedido'
           AND column_name = 'custo_unitario' AND is_nullable = 'NO'))
) AS T(TESTE, ESPERADO, OBTIDO);



INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'ESTRELA',
    T.TESTE,
    T.ESPERADO::TEXT,
    COALESCE(T.OBTIDO, -1)::TEXT,
    CASE WHEN T.OBTIDO = T.ESPERADO THEN 'OK' ELSE 'FALHA' END
FROM (
    VALUES
    ('vw_fato_vendas: linhas',            170,       (SELECT COUNT(*) FROM vw_fato_vendas)),
    ('vw_fato_vendas: faturamento',       335062.30, (SELECT SUM(FATURAMENTO) FROM vw_fato_vendas)),
    ('vw_fato_vendas: custo total',       258699.00, (SELECT SUM(CUSTO_TOTAL) FROM vw_fato_vendas)),
    ('vw_fato_vendas: lucro bruto',       76363.30,  (SELECT SUM(LUCRO_BRUTO) FROM vw_fato_vendas)),
    ('vw_fato_vendas x vw_vendas: diferença de faturamento',
        0,
        (SELECT (SELECT SUM(FATURAMENTO) FROM vw_fato_vendas) - (SELECT SUM(FATURAMENTO) FROM vw_vendas))),
    ('vw_dim_cliente: linhas (1 por cliente)',   40, (SELECT COUNT(*) FROM vw_dim_cliente)),
    ('vw_dim_cliente: chaves duplicadas',         0, (SELECT COUNT(*) - COUNT(DISTINCT ID_CLIENTE) FROM vw_dim_cliente)),
    ('vw_dim_cliente: rótulos de exibição duplicados', 0, (SELECT COUNT(*) - COUNT(DISTINCT CLIENTE_EXIBICAO) FROM vw_dim_cliente)),
    ('vw_dim_produto: linhas',                   19, (SELECT COUNT(*) FROM vw_dim_produto)),
    ('vw_dim_produto: chaves duplicadas',         0, (SELECT COUNT(*) - COUNT(DISTINCT ID_PRODUTO) FROM vw_dim_produto)),
    ('vw_dim_vendedor: linhas',                   5, (SELECT COUNT(*) FROM vw_dim_vendedor)),
    ('vw_dim_calendario: dias (2025 e 2026)',   730, (SELECT COUNT(*) FROM vw_dim_calendario)),
    ('Clientes com cadastro fora do calendário',  0, (SELECT COUNT(*) FROM vw_dim_cliente C LEFT JOIN vw_dim_calendario D ON D.DATA = C.DATA_CADASTRO WHERE D.DATA IS NULL)),
    ('vw_dim_calendario: datas duplicadas',       0, (SELECT COUNT(*) - COUNT(DISTINCT DATA) FROM vw_dim_calendario)),
    ('Fato sem cliente na dimensão',              0, (SELECT COUNT(*) FROM vw_fato_vendas F LEFT JOIN vw_dim_cliente D USING (ID_CLIENTE) WHERE D.ID_CLIENTE IS NULL)),
    ('Fato sem produto na dimensão',              0, (SELECT COUNT(*) FROM vw_fato_vendas F LEFT JOIN vw_dim_produto D USING (ID_PRODUTO) WHERE D.ID_PRODUTO IS NULL)),
    ('Fato sem vendedor na dimensão',             0, (SELECT COUNT(*) FROM vw_fato_vendas F LEFT JOIN vw_dim_vendedor D USING (ID_VENDEDOR) WHERE D.ID_VENDEDOR IS NULL)),
    ('Fato sem data no calendário',               0, (SELECT COUNT(*) FROM vw_fato_vendas F LEFT JOIN vw_dim_calendario D ON D.DATA = F.DATA_PEDIDO WHERE D.DATA IS NULL)),
    ('Meses com situação "Parcial"',              1, (SELECT COUNT(DISTINCT INICIO_MES) FROM vw_dim_calendario WHERE SITUACAO_MES = 'Parcial'))
) AS T(TESTE, ESPERADO, OBTIDO);



-- Nenhum dado pessoal sensível nas views da camada estrela.
INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'ESTRELA',
    'Colunas com dados pessoais nas views vw_fato_*/vw_dim_*',
    '0',
    COUNT(*) || COALESCE(' -> ' || string_agg(table_name || '.' || column_name, ', '), ''),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FALHA' END
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (table_name LIKE 'vw\_fato\_%' OR table_name LIKE 'vw\_dim\_%')
  AND column_name ~ '(cpf|email|telefone|logradouro|numero|complemento|cep|salario)';



-- =============================================================================
-- 5. AVISOS (não bloqueiam)
-- =============================================================================

INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'AVISO',
    'Nomes de clientes homônimos (identificar sempre por ID)',
    '2 (conhecidos)',
    COUNT(*) || COALESCE(' -> ' || string_agg(NOME, ', ' ORDER BY NOME), ''),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'AVISO' END
FROM (
    SELECT NOME
    FROM CLIENTE
    GROUP BY NOME
    HAVING COUNT(*) > 1
) AS X;



INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'AVISO',
    'Produtos com custo maior ou igual ao preço',
    '0',
    COUNT(*)::TEXT,
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'AVISO' END
FROM PRODUTO
WHERE CUSTO >= PRECO;



INSERT INTO RESULTADO_TESTES (GRUPO, TESTE, ESPERADO, OBTIDO, STATUS)
SELECT
    'AVISO',
    'Último mês com dados completo',
    'último pedido no fim do mês',
    'último pedido em ' || MAX(DATA_PEDIDO),
    CASE
        WHEN MAX(DATA_PEDIDO) = (date_trunc('month', MAX(DATA_PEDIDO)) + INTERVAL '1 month - 1 day')::DATE
        THEN 'OK' ELSE 'AVISO'
    END
FROM PEDIDO;



-- =============================================================================
-- RESULTADO
-- =============================================================================

SELECT ORDEM, GRUPO, TESTE, ESPERADO, OBTIDO, STATUS
FROM RESULTADO_TESTES
ORDER BY ORDEM;



DO $$
DECLARE
    v_falhas INT;
BEGIN
    SELECT COUNT(*) INTO v_falhas
    FROM RESULTADO_TESTES
    WHERE STATUS = 'FALHA';

    IF v_falhas > 0 THEN
        RAISE EXCEPTION '% teste(s) com FALHA. A carga será desfeita (ROLLBACK).', v_falhas;
    END IF;

    RAISE NOTICE 'Todos os testes bloqueantes passaram.';
END $$;
