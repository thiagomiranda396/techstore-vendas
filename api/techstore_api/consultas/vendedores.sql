-- Ranking de vendedores.
-- Parâmetros: inicio, fim (date ou NULL); categorias, vendedores (int[] ou NULL).
SELECT
    DENSE_RANK() OVER (ORDER BY SUM(F.faturamento) DESC)                    AS ranking,
    V.id_vendedor,
    V.vendedor,
    SUM(F.faturamento)                                                      AS faturamento,
    SUM(F.lucro_bruto)                                                      AS lucro_bruto,
    ROUND(100 * SUM(F.lucro_bruto) / NULLIF(SUM(F.faturamento), 0), 2)      AS margem_pct,
    COUNT(DISTINCT F.id_pedido)                                             AS pedidos,
    ROUND(SUM(F.faturamento) / NULLIF(COUNT(DISTINCT F.id_pedido), 0), 2)   AS ticket_medio,
    COUNT(DISTINCT F.id_cliente)                                            AS clientes
FROM vw_fato_vendas F
INNER JOIN vw_dim_produto P ON P.id_produto = F.id_produto
INNER JOIN vw_dim_vendedor V ON V.id_vendedor = F.id_vendedor
WHERE (%(inicio)s::date IS NULL OR F.data_pedido >= %(inicio)s::date)
  AND (%(fim)s::date IS NULL OR F.data_pedido <= %(fim)s::date)
  AND (%(categorias)s::int[] IS NULL OR P.id_categoria = ANY (%(categorias)s::int[]))
  AND (%(vendedores)s::int[] IS NULL OR F.id_vendedor = ANY (%(vendedores)s::int[]))
GROUP BY V.id_vendedor, V.vendedor
ORDER BY ranking, V.vendedor;
