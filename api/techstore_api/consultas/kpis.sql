-- KPIs do período e dos filtros selecionados.
-- Parâmetros: inicio, fim (date ou NULL); categorias, vendedores (int[] ou NULL).
WITH F AS (
    SELECT F.*
    FROM vw_fato_vendas F
    INNER JOIN vw_dim_produto P ON P.id_produto = F.id_produto
    WHERE (%(inicio)s::date IS NULL OR F.data_pedido >= %(inicio)s::date)
      AND (%(fim)s::date IS NULL OR F.data_pedido <= %(fim)s::date)
      AND (%(categorias)s::int[] IS NULL OR P.id_categoria = ANY (%(categorias)s::int[]))
      AND (%(vendedores)s::int[] IS NULL OR F.id_vendedor = ANY (%(vendedores)s::int[]))
),

RECORRENTES AS (
    SELECT id_cliente
    FROM F
    GROUP BY id_cliente
    HAVING COUNT(DISTINCT id_pedido) >= 2
)

SELECT
    COALESCE(SUM(faturamento), 0)                                         AS faturamento,
    COALESCE(SUM(custo_total), 0)                                         AS custo,
    COALESCE(SUM(lucro_bruto), 0)                                         AS lucro_bruto,
    ROUND(100 * SUM(lucro_bruto) / NULLIF(SUM(faturamento), 0), 2)        AS margem_pct,
    COUNT(DISTINCT id_pedido)                                             AS pedidos,
    COALESCE(SUM(quantidade), 0)                                          AS unidades,
    ROUND(SUM(faturamento) / NULLIF(COUNT(DISTINCT id_pedido), 0), 2)     AS ticket_medio,
    ROUND(COUNT(*)::NUMERIC / NULLIF(COUNT(DISTINCT id_pedido), 0), 2)    AS itens_por_pedido,
    COUNT(DISTINCT id_cliente)                                            AS clientes_ativos,
    (SELECT COUNT(*) FROM RECORRENTES)                                    AS clientes_recorrentes
FROM F;
