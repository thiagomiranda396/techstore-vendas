-- Faturamento, custo, lucro e margem por categoria.
-- Parâmetros: inicio, fim (date ou NULL); categorias, vendedores (int[] ou NULL).
SELECT
    P.id_categoria,
    P.categoria,
    SUM(F.faturamento)                                                  AS faturamento,
    SUM(F.custo_total)                                                  AS custo,
    SUM(F.lucro_bruto)                                                  AS lucro_bruto,
    ROUND(100 * SUM(F.lucro_bruto) / NULLIF(SUM(F.faturamento), 0), 2)  AS margem_pct,
    SUM(F.quantidade)                                                   AS unidades
FROM vw_fato_vendas F
INNER JOIN vw_dim_produto P ON P.id_produto = F.id_produto
WHERE (%(inicio)s::date IS NULL OR F.data_pedido >= %(inicio)s::date)
  AND (%(fim)s::date IS NULL OR F.data_pedido <= %(fim)s::date)
  AND (%(categorias)s::int[] IS NULL OR P.id_categoria = ANY (%(categorias)s::int[]))
  AND (%(vendedores)s::int[] IS NULL OR F.id_vendedor = ANY (%(vendedores)s::int[]))
GROUP BY P.id_categoria, P.categoria
ORDER BY faturamento DESC, P.categoria;
