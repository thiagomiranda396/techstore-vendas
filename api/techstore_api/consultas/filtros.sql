-- Valores permitidos nos filtros (também usados para validar as entradas).
SELECT
    (SELECT MIN(data_pedido) FROM vw_fato_vendas) AS primeira_venda,
    (SELECT MAX(data_pedido) FROM vw_fato_vendas) AS ultima_venda,
    (SELECT COALESCE(json_agg(json_build_object('id', id_categoria, 'nome', categoria) ORDER BY categoria), '[]'::json)
       FROM (SELECT DISTINCT id_categoria, categoria FROM vw_dim_produto) C)              AS categorias,
    (SELECT COALESCE(json_agg(json_build_object('id', id_vendedor, 'nome', vendedor) ORDER BY vendedor), '[]'::json)
       FROM vw_dim_vendedor)                                                               AS vendedores;
