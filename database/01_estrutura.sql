-- =============================================================================
-- TechstoreVendas | 01_estrutura.sql
-- Criação das tabelas.
--
-- Origem: sql/criacao_tabelas.sql (linhas 1-102), mesmas colunas, tipos e PKs.
-- Mudança: PRODUTO recebe CUSTO, CUSTO_ORIGEM e CUSTO_FONTE.
--          A coluna CUSTO já era usada por vw_vendas (sql/views.sql:17-18)
--          e existe no banco real (db_analise_vendas), mas nunca havia sido
--          criada nos scripts versionados. Os valores reais são carregados
--          por 05_custos_carga.sql.
-- Mudança: ITENS_PEDIDO recebe CUSTO_UNITARIO (custo histórico por item;
--          decisão C10 em docs/DECISOES_E_CORRECOES.md).
-- Sem DROP: se alguma tabela já existir, o script falha e nada é alterado.
-- =============================================================================

CREATE TABLE CLIENTE(
    ID_CLIENTE INT GENERATED ALWAYS AS IDENTITY,
    NOME VARCHAR(100) NOT NULL,
    CPF CHAR(11) NOT NULL,
    EMAIL VARCHAR(150) NOT NULL,
    DATA_CADASTRO DATE NOT NULL,

    CONSTRAINT PK_CLIENTE
    PRIMARY KEY(ID_CLIENTE)
);



CREATE TABLE ENDERECO(
    ID_ENDERECO INT GENERATED ALWAYS AS IDENTITY,
    ID_CLIENTE INT NOT NULL,
    CEP CHAR(8) NOT NULL,
    LOGRADOURO VARCHAR(150) NOT NULL,
    NUMERO VARCHAR(10) NOT NULL,
    COMPLEMENTO VARCHAR(100),
    BAIRRO VARCHAR(100) NOT NULL,
    CIDADE VARCHAR(100) NOT NULL,
    UF CHAR(2) NOT NULL,

    CONSTRAINT PK_ENDERECO
    PRIMARY KEY(ID_ENDERECO)
);



CREATE TABLE TELEFONE(
    ID_TELEFONE INT GENERATED ALWAYS AS IDENTITY,
    ID_CLIENTE INT NOT NULL,
    NUMERO VARCHAR(15) NOT NULL,
    TIPO VARCHAR(20) NOT NULL,

    CONSTRAINT PK_TELEFONE
    PRIMARY KEY(ID_TELEFONE)
);



CREATE TABLE VENDEDOR(
    ID_VENDEDOR INT GENERATED ALWAYS AS IDENTITY,
    NOME VARCHAR(100) NOT NULL,
    EMAIL VARCHAR(150) NOT NULL,
    TELEFONE VARCHAR(15) NOT NULL,
    SALARIO NUMERIC(10,2) NOT NULL,
    DATA_ADMISSAO DATE NOT NULL,

    CONSTRAINT PK_VENDEDOR
    PRIMARY KEY(ID_VENDEDOR)
);



CREATE TABLE CATEGORIA(
    ID_CATEGORIA INT GENERATED ALWAYS AS IDENTITY,
    NOME VARCHAR(50) NOT NULL,
    DESCRICAO VARCHAR(255),

    CONSTRAINT PK_CATEGORIA
    PRIMARY KEY(ID_CATEGORIA)
);



CREATE TABLE PRODUTO(
    ID_PRODUTO INT GENERATED ALWAYS AS IDENTITY,
    ID_CATEGORIA INT NOT NULL,
    NOME VARCHAR(100) NOT NULL,
    PRECO NUMERIC(10,2) NOT NULL,
    ESTOQUE INT NOT NULL,

    -- Novas: custo real e sua rastreabilidade (preenchidas em 05_custos_carga.sql).
    CUSTO NUMERIC(10,2),
    CUSTO_ORIGEM VARCHAR(10),
    CUSTO_FONTE VARCHAR(200),

    CONSTRAINT PK_PRODUTO
    PRIMARY KEY(ID_PRODUTO)
);



CREATE TABLE PEDIDO(
    ID_PEDIDO INT GENERATED ALWAYS AS IDENTITY,
    ID_CLIENTE INT NOT NULL,
    ID_VENDEDOR INT NOT NULL,
    DATA_PEDIDO DATE NOT NULL,

    CONSTRAINT PK_PEDIDO
    PRIMARY KEY(ID_PEDIDO)
);



CREATE TABLE ITENS_PEDIDO(
    ID_ITENS_PEDIDO INT GENERATED ALWAYS AS IDENTITY,
    ID_PEDIDO INT NOT NULL,
    ID_PRODUTO INT NOT NULL,
    QUANTIDADE INT NOT NULL,
    PRECO_UNITARIO NUMERIC(10,2) NOT NULL,

    -- Novo: custo unitário registrado no item (custo histórico da venda).
    -- Preenchido em 05_custos_carga.sql e obrigatório (NOT NULL) a partir daí.
    CUSTO_UNITARIO NUMERIC(10,2),

    CONSTRAINT PK_ITENS_PEDIDO
    PRIMARY KEY(ID_ITENS_PEDIDO)
);



COMMENT ON COLUMN PRODUTO.CUSTO IS
    'Custo unitário atual do produto (não histórico). Valores reais de db_analise_vendas.public.produto, conferidos em 2026-10-14; carregados por 05_custos_carga.sql.';

COMMENT ON COLUMN PRODUTO.CUSTO_ORIGEM IS
    'REAL = extraído do banco/cache do Power BI do autor; SINTETICO = gerado por regra documentada. Obrigatório quando CUSTO for preenchido.';

COMMENT ON COLUMN ITENS_PEDIDO.CUSTO_UNITARIO IS
    'Custo unitário no momento da venda (histórico). Na carga inicial é igual a PRODUTO.CUSTO; não muda se o custo do produto mudar depois. Usado por vw_fato_vendas; vw_vendas mantém o custo atual do produto.';

COMMENT ON COLUMN PRODUTO.CUSTO_FONTE IS
    'Rastreabilidade do custo: de onde e quando foi obtido, ou qual regra sintética o gerou.';
