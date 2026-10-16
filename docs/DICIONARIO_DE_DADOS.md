# Dicionário de dados

Schema `public`, PostgreSQL 15 ou mais novo. Volumes da carga validada (`techstore_dev_v3`, 2026-10-15).

**Classificação de sensibilidade:**
- 🔒 **Pessoal:** dado pessoal (LGPD). Não vai para o Power BI.
- 🔐 **RH:** dado de RH. Não vai para o Power BI.
- 🟢 **Analítico:** pode ser usado em análises.

---

## Tabelas

### `cliente` (40 linhas)
| Coluna | Tipo | Regras | Sensib. | Descrição |
|---|---|---|---|---|
| id_cliente | int identity | PK | 🟢 | Identificador. **Use sempre o ID**: há homônimos (IDs 5/16 e 9/29) |
| nome | varchar(100) | NOT NULL | 🟢 | Nome fictício |
| cpf | char(11) | NOT NULL, UNIQUE, 11 dígitos | 🔒 | CPF fictício. Os 30 clientes gerados (`00000000011`…) não têm dígitos verificadores válidos |
| email | varchar(150) | NOT NULL, UNIQUE | 🔒 | E-mail fictício |
| data_cadastro | date | NOT NULL | 🟢 | De 2025-06-03 a 2026-04-05 |

### `endereco` (10 linhas, só para os clientes 1 a 10)
| Coluna | Tipo | Regras | Sensib. | Descrição |
|---|---|---|---|---|
| id_endereco | int identity | PK | 🟢 | |
| id_cliente | int | FK → cliente | 🟢 | |
| cep | char(8) | 8 dígitos | 🔒 | |
| logradouro, numero, complemento | varchar | complemento opcional | 🔒 | |
| bairro, cidade | varchar | NOT NULL | 🟢 | Todos no Rio de Janeiro |
| uf | char(2) | 2 letras maiúsculas | 🟢 | |

### `telefone` (13 linhas)
| Coluna | Tipo | Regras | Sensib. | Descrição |
|---|---|---|---|---|
| id_telefone | int identity | PK | 🟢 | |
| id_cliente | int | FK → cliente | 🟢 | |
| numero | varchar(15) | NOT NULL | 🔒 | |
| tipo | varchar(20) | CELULAR, RESIDENCIAL ou COMERCIAL | 🟢 | |

### `vendedor` (5 linhas)
| Coluna | Tipo | Regras | Sensib. | Descrição |
|---|---|---|---|---|
| id_vendedor | int identity | PK | 🟢 | |
| nome | varchar(100) | NOT NULL | 🟢 | |
| email | varchar(150) | UNIQUE | 🔒 | |
| telefone | varchar(15) | NOT NULL | 🔒 | |
| salario | numeric(10,2) | maior que 0 | 🔐 | Fora do modelo analítico |
| data_admissao | date | NOT NULL | 🟢 | De 2024-02-15 a 2025-09-12 |

### `categoria` (6 linhas)
| Coluna | Tipo | Regras | Descrição |
|---|---|---|---|
| id_categoria | int identity | PK | |
| nome | varchar(50) | NOT NULL | Informática, Periféricos, Monitores, Eletrônicos, Acessórios, Armazenamento |
| descricao | varchar(255) | opcional | |

### `produto` (19 linhas)
| Coluna | Tipo | Regras | Descrição |
|---|---|---|---|
| id_produto | int identity | PK | |
| id_categoria | int | FK → categoria | |
| nome | varchar(100) | NOT NULL | |
| preco | numeric(10,2) | maior que 0 | Preço de tabela **atual** |
| estoque | int | maior ou igual a 0 | Foto do estoque atual, não histórico |
| custo | numeric(10,2) | vazio ou maior que 0 | Custo unitário **atual**, real ([C1](DECISOES_E_CORRECOES.md)) |
| custo_origem | varchar(10) | vazio, REAL ou SINTETICO | Origem do custo. Hoje: REAL nos 19 produtos |
| custo_fonte | varchar(200) | obrigatório quando há custo | `db_analise_vendas.public.produto, conferido em 2026-10-14` |

### `pedido` (60 linhas)
| Coluna | Tipo | Regras | Descrição |
|---|---|---|---|
| id_pedido | int identity | PK | 1 a 15 manuais; 16 a 60 gerados ([C2](DECISOES_E_CORRECOES.md)) |
| id_cliente | int | FK → cliente | Sempre um cliente já cadastrado na data ([C3](DECISOES_E_CORRECOES.md)) |
| id_vendedor | int | FK → vendedor | Sempre um vendedor já admitido na data |
| data_pedido | date | NOT NULL | De 2026-01-10 a 2026-08-18 |

### `itens_pedido` (170 linhas)
| Coluna | Tipo | Regras | Descrição |
|---|---|---|---|
| id_itens_pedido | int identity | PK | |
| id_pedido | int | FK → pedido; UNIQUE com id_produto | |
| id_produto | int | FK → produto | |
| quantidade | int | maior que 0 | Total: 260 unidades |
| preco_unitario | numeric(10,2) | maior que 0 | Preço praticado na venda |
| custo_unitario | numeric(10,2) | NOT NULL, maior que 0 | **Custo histórico** registrado na venda ([C10](DECISOES_E_CORRECOES.md)) |

---

## Views

### `vw_vendas`: contrato do relatório original (170 linhas, 1 por item)
As 15 colunas, nesta ordem, são **fixas** (o Power BI original depende delas):

| # | Coluna | Tipo | Origem |
|---|---|---|---|
| 1 | pedido | integer | pedido.id_pedido |
| 2 | cliente | varchar | cliente.nome |
| 3 | vendedor | varchar | vendedor.nome |
| 4 | produto | varchar | produto.nome |
| 5 | categoria | varchar | categoria.nome |
| 6 | qtd | integer | itens_pedido.quantidade |
| 7 | preco_unitario | numeric | itens_pedido.preco_unitario |
| 8 | faturamento | numeric | qtd × preco_unitario |
| 9 | data_pedido | date | pedido.data_pedido |
| 10 | custo_unitario | numeric | produto.custo (**atual**) |
| 11 | custo_total | numeric | qtd × produto.custo |
| 12–15 | id_cliente, id_vendedor, id_produto, id_categoria | integer | chaves |

### `vw_fato_vendas`: fato do modelo estrela (170 linhas)
| Coluna | Tipo | Regra |
|---|---|---|
| id_item | integer | itens_pedido.id_itens_pedido (chave) |
| id_pedido | integer | |
| data_pedido | date | → vw_dim_calendario.data |
| id_cliente, id_vendedor, id_produto | integer | → dimensões |
| quantidade | integer | |
| preco_unitario | numeric | |
| faturamento | numeric | quantidade × preco_unitario |
| custo_unitario | numeric | itens_pedido.custo_unitario (**histórico**) |
| custo_total | numeric | quantidade × custo_unitario |
| lucro_bruto | numeric | quantidade × (preco_unitario − custo_unitario) |

### `vw_dim_cliente` (40 linhas)
| Coluna | Descrição |
|---|---|
| id_cliente | Chave |
| cliente | Nome |
| cliente_exibicao | `Nome (#ID)`: rótulo único para gráficos, por causa dos homônimos |
| data_cadastro, mes_cadastro | Data e primeiro dia do mês do cadastro |
| bairro, cidade, uf | Do primeiro endereço; `Não informado` / `NI` quando não há (30 clientes) |

### `vw_dim_produto` (19 linhas)
| Coluna | Descrição |
|---|---|
| id_produto, produto | Chave e nome |
| id_categoria, categoria | Categoria desnormalizada |
| preco_atual, custo_atual | Valores atuais do catálogo |
| margem_atual_pct | (preço − custo) ÷ preço × 100, com 2 casas |
| estoque_atual | Foto do estoque |

### `vw_dim_vendedor` (5 linhas)
`id_vendedor`, `vendedor`, `data_admissao`. Sem e-mail, telefone ou salário.

### `vw_dim_calendario` (730 linhas: 2025-01-01 a 2026-12-31)
| Coluna | Exemplo | Descrição |
|---|---|---|
| data | 2026-08-18 | Chave diária |
| ano, trimestre, mes | 2026, 3, 8 | |
| nome_mes | Agosto | Em português, sem depender da configuração regional do servidor |
| ano_mes | ago/26 | Rótulo; ordenar por `ano_mes_num` |
| ano_mes_num | 202608 | |
| inicio_mes | 2026-08-01 | |
| dia_semana_num, dia_semana | 2, Terça | Semana ISO (1 = segunda-feira) |
| situacao_mes | Parcial | `Antes das vendas` (até dez/25) · `Completo` (jan a jul/26) · `Parcial` (ago/26) · `Sem vendas registradas` (set a dez/26) |
