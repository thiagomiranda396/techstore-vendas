-- Ranking de produtos com participação e classe ABC.
-- A classe é calculada sobre todos os produtos do filtro, antes do LIMIT.
-- Classe pelo acumulado ANTES do produto: A abaixo de 0.80, B abaixo de 0.95, C restante.
-- Parâmetros: inicio, fim (date ou NULL); categorias, vendedores (int[] ou NULL); limite (int).
WITH F AS (
    SELECT F.faturamento, F.lucro_bruto, F.quantidade, P.id_produto, P.produto, P.categoria
    FROM vw_fato_vendas F
    INNER JOIN vw_dim_produto P ON P.id_produto = F.id_produto
    WHERE (%(inicio)s::date IS NULL OR F.data_pedido >= %(inicio)s::date)
      AND (%(fim)s::date IS NULL OR F.data_pedido <= %(fim)s::date)
      AND (%(categorias)s::int[] IS NULL OR P.id_categoria = ANY (%(categorias)s::int[]))
      AND (%(vendedores)s::int[] IS NULL OR F.id_vendedor = ANY (%(vendedores)s::int[]))
),

POR_PRODUTO AS (
    SELECT id_produto, produto, categoria,
           SUM(faturamento) AS faturamento,
           SUM(lucro_bruto) AS lucro_bruto,
           SUM(quantidade)  AS unidades
    FROM F
    GROUP BY id_produto, produto, categoria
),

ACUMULADO AS (
    SELECT *,
           SUM(faturamento) OVER ()                                                AS total,
           SUM(faturamento) OVER (ORDER BY faturamento DESC, id_produto
                                  ROWS UNBOUNDED PRECEDING)                         AS acumulado,
           DENSE_RANK() OVER (ORDER BY faturamento DESC)                            AS ranking
    FROM POR_PRODUTO
)

SELECT
    ranking,
    id_produto,
    produto,
    categoria,
    faturamento,
    lucro_bruto,
    unidades,
    ROUND(100 * faturamento / NULLIF(total, 0), 2) AS pct_faturamento,
    ROUND(100 * acumulado / NULLIF(total, 0), 2)   AS pct_acumulado,
    CASE
        WHEN (acumulado - faturamento) / NULLIF(total, 0) < 0.80 THEN 'A'
        WHEN (acumulado - faturamento) / NULLIF(total, 0) < 0.95 THEN 'B'
        ELSE 'C'
    END AS classe_abc
FROM ACUMULADO
ORDER BY faturamento DESC, id_produto
LIMIT %(limite)s;
