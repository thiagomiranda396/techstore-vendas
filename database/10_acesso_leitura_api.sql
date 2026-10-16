-- =============================================================================
-- TechstoreVendas | 10_acesso_leitura_api.sql
-- Acesso somente leitura da API do dashboard web (decisão C14).
--
-- NÃO é executado por 00_executar_tudo.sql: depende de um papel de servidor.
--
-- Pré-requisito (uma vez por instância, por um administrador):
--   CREATE ROLE techstore_api_leitor LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE
--          NOREPLICATION NOBYPASSRLS NOINHERIT CONNECTION LIMIT 10;
--   -- Toda sessão do papel é somente leitura e tem tempo limite,
--   -- mesmo que a API seja configurada de forma errada:
--   ALTER ROLE techstore_api_leitor SET default_transaction_read_only = on;
--   ALTER ROLE techstore_api_leitor SET statement_timeout = '5s';
--   \password techstore_api_leitor      -- senha digitada de forma oculta
--
-- Uso (como dono do banco de validação, depois de 00_executar_tudo.sql):
--   psql -h localhost -p 5433 -U techstore_dev_app -d techstore_dev_vN -f database/10_acesso_leitura_api.sql
--
-- Privilégio mínimo: só as 4 views usadas pelos endpoints da API.
-- Sem vw_dim_cliente (a API não expõe clientes individualmente), sem
-- vw_vendas e sem nenhuma tabela.
-- =============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
    IF current_database() !~ '^techstore_dev(_[a-z0-9]+)?$' THEN
        RAISE EXCEPTION 'Execução bloqueada: banco "%" não é um banco de validação.', current_database();
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'techstore_api_leitor') THEN
        RAISE EXCEPTION 'O papel techstore_api_leitor não existe. Crie-o antes (ver cabeçalho).';
    END IF;

    IF EXISTS (SELECT 1 FROM pg_roles
               WHERE rolname = 'techstore_api_leitor'
                 AND (rolsuper OR rolcreatedb OR rolcreaterole OR rolbypassrls OR rolreplication)) THEN
        RAISE EXCEPTION 'O papel techstore_api_leitor tem privilégios além de leitura; revise antes de conceder acesso.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_db_role_setting s JOIN pg_roles r ON r.oid = s.setrole
                   WHERE r.rolname = 'techstore_api_leitor' AND s.setdatabase = 0
                     AND 'default_transaction_read_only=on' = ANY (s.setconfig)) THEN
        RAISE EXCEPTION 'O papel techstore_api_leitor precisa de default_transaction_read_only = on (ver cabeçalho).';
    END IF;

    EXECUTE format('GRANT CONNECT ON DATABASE %I TO techstore_api_leitor', current_database());
END $$;



BEGIN;

GRANT USAGE ON SCHEMA public TO techstore_api_leitor;

GRANT SELECT ON public.vw_fato_vendas    TO techstore_api_leitor;
GRANT SELECT ON public.vw_dim_produto    TO techstore_api_leitor;
GRANT SELECT ON public.vw_dim_vendedor   TO techstore_api_leitor;
GRANT SELECT ON public.vw_dim_calendario TO techstore_api_leitor;

COMMIT;



-- Conferência: o que o papel pode ler neste banco.
SELECT
    c.relname AS objeto,
    CASE c.relkind WHEN 'r' THEN 'tabela' WHEN 'v' THEN 'view' ELSE c.relkind::TEXT END AS tipo,
    has_table_privilege('techstore_api_leitor', c.oid, 'SELECT') AS pode_ler,
    has_table_privilege('techstore_api_leitor', c.oid, 'INSERT,UPDATE,DELETE,TRUNCATE') AS pode_alterar
FROM pg_class c
WHERE c.relnamespace = 'public'::regnamespace
  AND c.relkind IN ('r', 'v')
ORDER BY tipo, objeto;
