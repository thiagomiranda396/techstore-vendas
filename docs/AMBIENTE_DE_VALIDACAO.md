# Ambiente de validação isolado

Os scripts são validados numa **segunda instância do PostgreSQL**, separada da instância de trabalho do autor. Assim nenhum teste consegue alcançar o banco real.

| | Instância de trabalho (não tocada) | Instância de testes |
|---|---|---|
| Porta | 5432 | **5433**, só `localhost` |
| Pasta de dados | Pasta padrão da instalação do PostgreSQL | Pasta dedicada, por exemplo `C:\pgdev\techstore18\data` |
| Como roda | Serviço do Windows `postgresql-x64-18` | Processo manual (`pg_ctl`), sem serviço |
| Bancos | `db_analise_vendas`, … | `techstore_dev`, `techstore_dev_v2`, `techstore_dev_v3` |
| Identificador do cluster | 7628394574182138840 | 7696982031096139488 |

A separação foi comprovada pelos identificadores de cluster diferentes, PIDs e portas distintos, e pela lista de bancos da 5433, onde `db_analise_vendas` não existe.

---

## 1. Montar a instância (resumo)

```powershell
$bin  = "<pasta bin do PostgreSQL 18>"     # ex.: C:\Program Files\PostgreSQL\18\bin
$base = "<pasta da instância de testes>"  # ex.: C:\pgdev\techstore18
New-Item -ItemType Directory -Force "$base\log" | Out-Null

# Superusuário com nome próprio; a senha é pedida de forma oculta (-W)
& "$bin\initdb.exe" -D "$base\data" -U pgdev_admin -W -A scram-sha-256 -E UTF8

Add-Content -Encoding utf8 "$base\data\postgresql.conf" @"

port = 5433
listen_addresses = 'localhost'
cluster_name = 'techstore_dev18'
log_statement = 'none'
"@

& "$bin\pg_ctl.exe" -D "$base\data" -l "$base\log\postgresql.log" start
```
Para parar: `& "$bin\pg_ctl.exe" -D "$base\data" stop -m fast`. A instância **não inicia sozinha** com o Windows.

**Iniciada num terminal, a instância fica presa a ele.** Em 2026-10-15 às 20:14, um Ctrl+C (ou o fechamento da janela) no terminal onde o `pg_ctl start` foi executado derrubou um processo do servidor (código Windows `0xC000013A`, "encerrado por Ctrl+C") e o próprio servidor. O desligamento foi rápido e limpo. Às 21:17 a instância foi reiniciada; a recuperação automática terminou sem erros e os testes da API voltaram a passar (55/55).

Para evitar que se repita, inicie a instância numa janela própria e oculta, sem `-Wait`:
```powershell
Start-Process -FilePath "$bin\pg_ctl.exe" -ArgumentList "-D", "`"$base\data`"", "-l", "`"$base\log\postgresql.log`"", "start" -WindowStyle Hidden
```

## 2. Autenticação sem senhas em arquivo (Windows SSPI)

A conta do Windows dona do cluster autentica pelo próprio login do Windows. Não existe `pgpass` nem senha em script ou log.

**`pg_hba.conf`**, regras no **topo** do arquivo (a primeira que casar vale):
```
host  all                              pgdev_admin        127.0.0.1/32  sspi map=techstore
host  all                              pgdev_admin        ::1/128       sspi map=techstore
host  "/^techstore_dev(_[a-z0-9]+)?$"  techstore_dev_app  127.0.0.1/32  sspi map=techstore
host  "/^techstore_dev(_[a-z0-9]+)?$"  techstore_dev_app  ::1/128       sspi map=techstore
host  all                              techstore_dev_app  all           reject
local all                              techstore_dev_app                reject
```

**`pg_ident.conf`** (use a sua conta, no formato `Usuario@COMPUTADOR`; confira com `whoami` e `$env:COMPUTERNAME`):
```
techstore    <Usuario>@<COMPUTADOR>    pgdev_admin
techstore    <Usuario>@<COMPUTADOR>    techstore_dev_app
```
Aplicar: `& "$bin\pg_ctl.exe" -D "$base\data" reload`.

Os backups dos arquivos anteriores a cada mudança ficam em `<pasta da instância>\backup_conf\<data_hora>\`.

## 3. Papéis e bancos

| Papel | Atributos | Acesso |
|---|---|---|
| `pgdev_admin` | Superusuário (só da instância de testes) | SSPI local |
| `techstore_dev_app` | `LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS NOINHERIT`, sem senha | SSPI, **só** em bancos `techstore_dev*`; recusado no `postgres` e no `template1` |
| `techstore_bi_leitor` | Mesmos atributos restritos, `LOGIN` | Senha definida pelo autor (`\password`); `SELECT` **só nas 6 views** ([09](../database/09_acesso_leitura_bi.sql)) |
| `techstore_api_leitor` | Atributos restritos, `CONNECTION LIMIT 10`, sessões `read_only` com `statement_timeout = 5s` | Senha definida pelo autor; `SELECT` **só em 4 views** ([10](../database/10_acesso_leitura_api.sql)) |

Proteções extras:
- `REVOKE CONNECT ON DATABASE postgres, template1 FROM PUBLIC`;
- `REVOKE ALL ON DATABASE techstore_dev* FROM PUBLIC`.

**Criar um banco de validação novo** (sem apagar nada):
```sql
-- conectado como pgdev_admin na 5433, banco postgres
CREATE DATABASE techstore_dev_v4 OWNER techstore_dev_app ENCODING 'UTF8' TEMPLATE template0;
REVOKE ALL ON DATABASE techstore_dev_v4 FROM PUBLIC;
```

## 4. Pendências de limpeza (dependem de aprovação)

| Item | Situação | Ação sugerida |
|---|---|---|
| `techstore_dev` e `techstore_dev_v2` | Bancos de validações anteriores, mantidos como evidência | `DROP DATABASE`, **só com aprovação** |
| Mapeamento SSPI do `pgdev_admin` | Ativo, para administrar a instância de testes sem senha | Remover as 2 primeiras regras do `pg_hba.conf` se não for mais necessário |
| Instância inteira | — | `pg_ctl stop` e apagar a pasta da instância de testes |

## 5. Regras de execução usadas na validação
- Toda conexão com `host`, `port=5433`, `dbname` e `user` explícitos.
- `-X`, para ignorar o `psqlrc`; `-w`, para nunca pedir senha; `-v ON_ERROR_STOP=1`.
- Leituras com `PGOPTIONS="-c default_transaction_read_only=on"`.
- Antes de qualquer alteração, a sessão confere `port = 5433` e `cluster_name = techstore_dev18` e aborta se não bater.
