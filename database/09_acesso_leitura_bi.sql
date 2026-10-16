-- =============================================================================
-- TechstoreVendas | 09_acesso_leitura_bi.sql
-- Acesso somente leitura do Power BI às views analíticas (decisão C12).
--
-- NÃO é executado por 00_executar_tudo.sql: depende de um papel de servidor.
--
-- Pré-requisito (uma vez por instância, por um administrador):
--   CREATE ROLE techstore_bi_leitor LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE
--          NOREPLICATION NOBYPASSRLS NOINHERIT;
--   \password techstore_bi_leitor      -- senha digitada de forma oculta
--
-- Uso (como dono do banco de validação, depois de 00_executar_tudo.sql):
--   psql -h localhost -p 5433 -U techstore_dev_app -d techstore_dev_vN -f database/09_acesso_leitura_bi.sql
--
-- Resultado: o papel conecta ao banco e lê APENAS as views abaixo.
-- Nenhuma tabela é concedida; dados pessoais das tabelas ficam inacessíveis.
-- =============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
    IF current_database() !~ '^techstore_dev(_[a-z0-9]+)?$' THEN
        RAISE EXCEPTION 'Execução bloqueada: banco "%" não é um banco de validação.', current_database();
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'techstore_bi_leitor') THEN
        RAISE EXCEPTION 'O papel techstore_bi_leitor não existe. Crie-o antes (ver cabeçalho).';
    END IF;

    IF EXISTS (SELECT 1 FROM pg_roles
               WHERE rolname = 'techstore_bi_leitor'
                 AND (rolsuper OR rolcreatedb OR rolcreaterole OR rolbypassrls)) THEN
        RAISE EXCEPTION 'O papel techstore_bi_leitor tem privilégios além de leitura; revise antes de conceder acesso.';
    END IF;

    EXECUTE format('GRANT CONNECT ON DATABASE %I TO techstore_bi_leitor', current_database());
END $$;



BEGIN;

GRANT USAGE ON SCHEMA public TO techstore_bi_leitor;

-- Camada estrela (recomendada para o novo modelo do Power BI)
GRANT SELECT ON public.vw_fato_vendas    TO techstore_bi_leitor;
GRANT SELECT ON public.vw_dim_cliente    TO techstore_bi_leitor;
GRANT SELECT ON public.vw_dim_produto    TO techstore_bi_leitor;
GRANT SELECT ON public.vw_dim_vendedor   TO techstore_bi_leitor;
GRANT SELECT ON public.vw_dim_calendario TO techstore_bi_leitor;

-- Contrato do relatório original (F_vw_vendas)
GRANT SELECT ON public.vw_vendas TO techstore_bi_leitor;

COMMIT;



-- Conferência: o que o papel pode ler neste banco.
SELECT
    c.relname AS objeto,
    CASE c.relkind WHEN 'r' THEN 'tabela' WHEN 'v' THEN 'view' ELSE c.relkind::TEXT END AS tipo,
    has_table_privilege('techstore_bi_leitor', c.oid, 'SELECT') AS pode_ler,
    has_table_privilege('techstore_bi_leitor', c.oid, 'INSERT,UPDATE,DELETE,TRUNCATE') AS pode_alterar
FROM pg_class c
WHERE c.relnamespace = 'public'::regnamespace
  AND c.relkind IN ('r', 'v')
ORDER BY tipo, objeto;
