-- =============================================================================
-- TechstoreVendas | 00_executar_tudo.sql
-- Executor da carga completa em banco DESCARTÁVEL de validação.
--
-- Uso (a partir da raiz do projeto):
--   psql -h localhost -U <usuario> -d techstore_dev -f database/00_executar_tudo.sql
--
-- Garantias:
--   * Só executa em bancos de validação: "techstore_dev" ou
--     "techstore_dev_<sufixo>" (ex.: techstore_dev_v2). Cada nova validação
--     usa um banco novo e vazio, sem necessidade de DROP.
--   * Para no primeiro erro (ON_ERROR_STOP).
--   * Tudo roda em UMA transação: qualquer erro ou teste reprovado em
--     08_verificacoes_qualidade.sql desfaz a carga inteira.
--   * Nenhum script usa DROP. Se as tabelas já existirem, a execução falha
--     em 01_estrutura.sql sem alterar nada.
--
-- 07_consultas_analiticas.sql NÃO é executado aqui (biblioteca de consultas).
-- =============================================================================

\set ON_ERROR_STOP on
\encoding UTF8
SET client_encoding = 'UTF8';

-- Trava de segurança: nunca executar fora do banco de validação.
DO $$
BEGIN
    IF current_database() !~ '^techstore_dev(_[a-z0-9]+)?$' THEN
        RAISE EXCEPTION
            'Execução bloqueada: banco atual "%" não é um banco de validação (techstore_dev ou techstore_dev_<sufixo>).',
            current_database();
    END IF;
END $$;

SET search_path = public;

BEGIN;

\echo '>> 01 - Estrutura'
\ir 01_estrutura.sql

\echo '>> 02 - Restrições e índices'
\ir 02_restricoes_indices.sql

\echo '>> 03 - Dados base (fictícios de exemplo)'
\ir 03_dados_base.sql

\echo '>> 04 - Dados gerados (fictícios de exemplo)'
\ir 04_dados_gerados.sql

\echo '>> 05 - Carga de custos'
\ir 05_custos_carga.sql

\echo '>> 06 - Views'
\ir 06_views.sql

\echo '>> 08 - Verificações de qualidade'
\ir 08_verificacoes_qualidade.sql

COMMIT;

\echo '>> Carga concluída e validada.'
