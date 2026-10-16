-- Faturamento do último mês completo e do mês anterior.
-- Ignora o filtro de datas (como a medida DAX equivalente), mas respeita
-- categorias e vendedores.
-- Parâmetros: categorias, vendedores (int[] ou NULL).
WITH ULTIMO AS (
    SELECT MAX(inicio_mes) AS mes
    FROM vw_dim_calendario
    WHERE situacao_mes = 'Completo'
),

MENSAL AS (
    SELECT C.inicio_mes, SUM(F.faturamento) AS faturamento
    FROM vw_fato_vendas F
    INNER JOIN vw_dim_produto P ON P.id_produto = F.id_produto
    INNER JOIN vw_dim_calendario C ON C.data = F.data_pedido
    WHERE (%(categorias)s::int[] IS NULL OR P.id_categoria = ANY (%(categorias)s::int[]))
      AND (%(vendedores)s::int[] IS NULL OR F.id_vendedor = ANY (%(vendedores)s::int[]))
    GROUP BY C.inicio_mes
)

SELECT
    U.mes                                                                            AS mes,
    (SELECT M.faturamento FROM MENSAL M WHERE M.inicio_mes = U.mes)                  AS faturamento_mes,
    (SELECT M.faturamento FROM MENSAL M
      WHERE M.inicio_mes = (U.mes - INTERVAL '1 month')::DATE)                       AS faturamento_mes_anterior,
    (SELECT MAX(data_pedido) FROM vw_fato_vendas)                                    AS ultima_venda
FROM ULTIMO U;
