// =============================================================================
// TechstoreVendas | Consultas do Power Query (linguagem M)
//
// Como usar: no Power BI Desktop, Página Inicial > Transformar dados >
// Nova Fonte > Consulta Nula > Editor Avançado. Cole cada bloco em uma
// consulta com o nome indicado no comentário "Consulta:".
//
// Fonte: views da camada estrela (database/06_views.sql), lidas pelo papel
// somente leitura techstore_bi_leitor (database/09_acesso_leitura_bi.sql).
// Credencial: Power BI > Configurações da fonte de dados > Banco de dados
// (usuário techstore_bi_leitor). A senha fica no Power BI, nunca no arquivo.
// =============================================================================


// -----------------------------------------------------------------------------
// Consulta: ServidorPostgres   (Parâmetro)
// Troca de ambiente: altere aqui ou em Transformar dados > Editar parâmetros.
//   Testes isolados:  localhost:5433
//   Outro ambiente:   <host>:<porta>
// -----------------------------------------------------------------------------
"localhost:5433" meta [IsParameterQuery = true, Type = "Text", IsParameterQueryRequired = true]


// -----------------------------------------------------------------------------
// Consulta: BancoDados   (Parâmetro)
//   Banco validado em 2026-10-15: techstore_dev_v3
// -----------------------------------------------------------------------------
"techstore_dev_v3" meta [IsParameterQuery = true, Type = "Text", IsParameterQueryRequired = true]


// -----------------------------------------------------------------------------
// Consulta: Fato Vendas
// -----------------------------------------------------------------------------
let
    Fonte = PostgreSQL.Database(ServidorPostgres, BancoDados),
    Dados = Fonte{[Schema = "public", Item = "vw_fato_vendas"]}[Data],
    Tipos = Table.TransformColumnTypes(
        Dados,
        {
            {"id_item", Int64.Type},
            {"id_pedido", Int64.Type},
            {"data_pedido", type date},
            {"id_cliente", Int64.Type},
            {"id_vendedor", Int64.Type},
            {"id_produto", Int64.Type},
            {"quantidade", Int64.Type},
            {"preco_unitario", Currency.Type},
            {"faturamento", Currency.Type},
            {"custo_unitario", Currency.Type},
            {"custo_total", Currency.Type},
            {"lucro_bruto", Currency.Type}
        }
    )
in
    Tipos


// -----------------------------------------------------------------------------
// Consulta: Dim Cliente   (sem CPF, e-mail, telefone ou endereço completo)
// -----------------------------------------------------------------------------
let
    Fonte = PostgreSQL.Database(ServidorPostgres, BancoDados),
    Dados = Fonte{[Schema = "public", Item = "vw_dim_cliente"]}[Data],
    Tipos = Table.TransformColumnTypes(
        Dados,
        {
            {"id_cliente", Int64.Type},
            {"cliente", type text},
            {"cliente_exibicao", type text},
            {"data_cadastro", type date},
            {"mes_cadastro", type date},
            {"bairro", type text},
            {"cidade", type text},
            {"uf", type text}
        }
    )
in
    Tipos


// -----------------------------------------------------------------------------
// Consulta: Dim Produto   (valores atuais do catálogo)
// -----------------------------------------------------------------------------
let
    Fonte = PostgreSQL.Database(ServidorPostgres, BancoDados),
    Dados = Fonte{[Schema = "public", Item = "vw_dim_produto"]}[Data],
    Tipos = Table.TransformColumnTypes(
        Dados,
        {
            {"id_produto", Int64.Type},
            {"produto", type text},
            {"id_categoria", Int64.Type},
            {"categoria", type text},
            {"preco_atual", Currency.Type},
            {"custo_atual", Currency.Type},
            {"margem_atual_pct", type number},
            {"estoque_atual", Int64.Type}
        }
    ),
    // margem_atual_pct vem em pontos percentuais (ex.: 20.93); convertida para fração (0,2093)
    // para usar o formato de porcentagem do Power BI.
    MargemFracao = Table.TransformColumns(Tipos, {{"margem_atual_pct", each _ / 100, type number}}),
    Renomeada = Table.RenameColumns(MargemFracao, {{"margem_atual_pct", "margem_atual"}})
in
    Renomeada


// -----------------------------------------------------------------------------
// Consulta: Dim Vendedor   (sem e-mail, telefone e salário)
// -----------------------------------------------------------------------------
let
    Fonte = PostgreSQL.Database(ServidorPostgres, BancoDados),
    Dados = Fonte{[Schema = "public", Item = "vw_dim_vendedor"]}[Data],
    Tipos = Table.TransformColumnTypes(
        Dados,
        {
            {"id_vendedor", Int64.Type},
            {"vendedor", type text},
            {"data_admissao", type date}
        }
    )
in
    Tipos


// -----------------------------------------------------------------------------
// Consulta: Calendario
// Depois de carregar: Ferramentas de tabela > Marcar como tabela de datas
// (coluna "data"). Ordenar "ano_mes" por "ano_mes_num" e "dia_semana" por
// "dia_semana_num".
// -----------------------------------------------------------------------------
let
    Fonte = PostgreSQL.Database(ServidorPostgres, BancoDados),
    Dados = Fonte{[Schema = "public", Item = "vw_dim_calendario"]}[Data],
    Tipos = Table.TransformColumnTypes(
        Dados,
        {
            {"data", type date},
            {"ano", Int64.Type},
            {"trimestre", Int64.Type},
            {"mes", Int64.Type},
            {"nome_mes", type text},
            {"ano_mes", type text},
            {"ano_mes_num", Int64.Type},
            {"inicio_mes", type date},
            {"dia_semana_num", Int64.Type},
            {"dia_semana", type text},
            {"situacao_mes", type text}
        }
    )
in
    Tipos
