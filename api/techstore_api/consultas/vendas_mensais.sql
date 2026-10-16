-- Série mensal: faturamento, custo, lucro, pedidos, variação mensal e média
-- móvel de 3 meses.
-- A série é calculada sobre todos os meses com operação (respeitando
-- categorias e vendedores) e só depois recortada pelo período. Assim a média
-- móvel do primeiro mês exibido usa os meses anteriores, como no DAX.
-- O período é tratado em meses inteiros (o frontend envia início e fim de mês).
-- Parâmetros: inicio, fim (date ou NULL); categorias, vendedores (int[] ou NULL).
WITH MESES AS (
    SELECT DISTINCT inicio_mes, ano_mes, situacao_mes
    FROM vw_dim_calendario
    WHERE situacao_mes IN ('Completo', 'Parcial')
),

VENDAS AS (
    SELECT
        C.inicio_mes,
        SUM(F.faturamento)          AS faturamento,
        SUM(F.custo_total)          AS custo,
        SUM(F.lucro_bruto)          AS lucro_bruto,
        COUNT(DISTINCT F.id_pedido) AS pedidos
    FROM vw_fato_vendas F
    INNER JOIN vw_dim_produto P ON P.id_produto = F.id_produto
    INNER JOIN vw_dim_calendario C ON C.data = F.data_pedido
    WHERE (%(categorias)s::int[] IS NULL OR P.id_categoria = ANY (%(categorias)s::int[]))
      AND (%(vendedores)s::int[] IS NULL OR F.id_vendedor = ANY (%(vendedores)s::int[]))
    GROUP BY C.inicio_mes
),

SERIE AS (
    SELECT
        M.inicio_mes,
        M.ano_mes,
        M.situacao_mes,
        COALESCE(V.faturamento, 0) AS faturamento,
        COALESCE(V.custo, 0)       AS custo,
        COALESCE(V.lucro_bruto, 0) AS lucro_bruto,
        COALESCE(V.pedidos, 0)     AS pedidos,
        LAG(COALESCE(V.faturamento, 0)) OVER (ORDER BY M.inicio_mes)                             AS faturamento_anterior,
        AVG(COALESCE(V.faturamento, 0)) OVER (ORDER BY M.inicio_mes ROWS 2 PRECEDING)            AS media_3m,
        COUNT(*) OVER (ORDER BY M.inicio_mes ROWS 2 PRECEDING)                                   AS meses_na_janela
    FROM MESES M
    LEFT JOIN VENDAS V ON V.inicio_mes = M.inicio_mes
)

SELECT
    inicio_mes,
    ano_mes,
    situacao_mes,
    faturamento,
    custo,
    lucro_bruto,
    pedidos,
    -- Em branco no mês parcial: a "queda" seria só falta de dias.
    CASE
        WHEN situacao_mes = 'Parcial' OR faturamento_anterior IS NULL OR faturamento_anterior = 0 THEN NULL
        ELSE ROUND(100 * (faturamento - faturamento_anterior) / faturamento_anterior, 2)
    END AS variacao_pct,
    CASE WHEN meses_na_janela = 3 THEN ROUND(media_3m, 2) END AS media_movel_3m
FROM SERIE
WHERE (%(inicio)s::date IS NULL OR inicio_mes >= DATE_TRUNC('month', %(inicio)s::date)::DATE)
  AND (%(fim)s::date IS NULL OR inicio_mes <= %(fim)s::date)
ORDER BY inicio_mes;
