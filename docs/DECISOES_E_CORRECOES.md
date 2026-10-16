# TechstoreVendas: decisões e correções

Registro das correções aplicadas aos scripts SQL do projeto, com a evidência que motivou cada uma e a ligação entre os arquivos originais e os novos.

- **Fases:** 3 (scripts corrigidos), 5 (custos reais) e 6 (validação, custo histórico, camada estrela e acesso do BI)
- **Datas:** 2026-10-14 (C1–C9) e 2026-10-15 (C10–C13 e validação)
- **Situação:** scripts **validados** em 2026-10-15 numa instância de testes isolada: 71/71 testes bloqueantes OK ([VALIDACAO.md](VALIDACAO.md)).
- **Banco real do autor:** `db_analise_vendas`, porta 5432. Os scripts nunca rodam nele: o executor só aceita bancos `techstore_dev*`, e a validação usou outra instância (porta 5433).

---

## 1. Princípios

1. **Os originais são preservados.** `sql/`, `documentacao/` e `powerbi/` não são alterados. Os scripts corrigidos ficam em `database/`.
2. **Compatibilidade com o Power BI.** O schema continua `public`, e a `vw_vendas` mantém as 15 colunas, na mesma ordem e com os mesmos nomes.
3. **Nenhum dado inventado é apresentado como real.** Os custos de produto são os valores reais do banco do autor, transcritos sem alteração.
4. **Execução segura:**
   - só em bancos `techstore_dev` ou `techstore_dev_<sufixo>`;
   - tudo numa única transação;
   - sem `DROP`;
   - testes que desfazem a carga se falharem.

---

## 2. Preservação do histórico

O commit `5d6d1e7` ("Estado original do projeto TechstoreVendas") registra os arquivos exatamente como foram recebidos.

Hashes SHA-256 dos originais, conferidos antes e depois da Fase 3:

| Arquivo | SHA-256 |
|---|---|
| `sql/criacao_tabelas.sql` | `AC880FCBB222E5E4EC5A63D478C5C47D2C8B2EA3371F02998B35F5099115BACC` |
| `sql/isercao_dados.sql` | `5DE6EAA31D959BAE2B50492A954494B1A7284CA3584ECEB28368CA814195810F` |
| `sql/views.sql` | `A58739A067EED78165A18E017478E32577AD18FFFCC9FC13C0F5B57E8B5208E8` |
| `documentacao/Modelagem_BRModelo.png` | `A78DFA68B89D3FEB0ADD3473DA5044BDAAF720417D71A54E552C9E769630CE1D` |
| `powerbi/TECHSTORE_VENDAS.pbix` | `F7B6148A3390E2F28DF21A026DDDEB8A8844BA2F9B6784EDC6169678E8863593` |

Para conferir no Windows:

```powershell
Get-FileHash sql\*.sql, documentacao\*.png, powerbi\*.pbix -Algorithm SHA256
```

---

## 3. Glossário de origem dos dados

| Termo | Significado | Onde aparece |
|---|---|---|
| **Fictício de exemplo** | Dados originais do projeto: clientes, vendedores, catálogo e pedidos. Não representam pessoas nem empresas reais. | `03_dados_base.sql`, `04_dados_gerados.sql` |
| **Real** | Valor extraído do banco do autor ou do cache do Power BI, com fonte e data registradas. | `PRODUTO.CUSTO_ORIGEM = 'REAL'` |
| **Sintético** | Valor gerado por uma regra documentada e aprovada. **Nenhum foi gerado até agora.** | `PRODUTO.CUSTO_ORIGEM = 'SINTETICO'` |

Proteções contra confusão entre real e sintético:

- `CUSTO_ORIGEM` e `CUSTO_FONTE` são obrigatórios sempre que `CUSTO` estiver preenchido (`CK_PRODUTO_CUSTO_CONSISTENCIA`).
- Uma carga não pode misturar as duas origens (`05_custos_carga.sql`).
- A seção 5 do `08_verificacoes_qualidade.sql` mostra a situação dos custos: PENDENTE, REAL ou SINTÉTICO.
- A `vw_vendas` não pode ganhar uma coluna de origem por causa do contrato com o Power BI. A origem será exposta numa view de dimensão e num aviso no dashboard, em fase futura.

---

## 4. Correções

### C1. Coluna `CUSTO` ausente nos scripts

- **Evidência:** [views.sql:17-18](../sql/views.sql#L17-L18) e [views.sql:316-317](../sql/views.sql#L316-L317) usam `PR.CUSTO`, mas [criacao_tabelas.sql:68-77](../sql/criacao_tabelas.sql#L68-L77) não cria a coluna e nenhum INSERT a preenche. Num banco novo, a view falha.
- **Indício:** as datas dos arquivos (tabelas 18:23, inserts 18:25, views 18:41 de 04/09) e as medidas `Custo Total`, `Lucro Bruto` e `Margem de Lucro` no .pbix sugerem que a coluna foi criada direto no banco do autor. É uma hipótese ainda não confirmada.
- **Confirmação (2026-10-14).** O autor verificou no banco `db_analise_vendas`, em modo somente leitura:
  - `public.produto` tem 19 produtos com `custo NUMERIC(10,2)` preenchido;
  - `public.vw_vendas` tem 15 colunas, incluindo `custo_unitario` e `custo_total`;
  - `custo_total = qtd × custo_unitario` em 20 registros conferidos (diferença zero);
  - a medida do Power BI é `Custo Total = SUM('F_vw_vendas'[custo_total])`.

  A hipótese está confirmada: a coluna foi criada no banco fora dos scripts versionados.
- **Correção:**
  - `PRODUTO` recebe `CUSTO`, `CUSTO_ORIGEM` e `CUSTO_FONTE` (`01_estrutura.sql`), com regras de consistência (`02_restricoes_indices.sql`).
  - `05_custos_carga.sql` carrega os **19 custos reais**, com `CUSTO_ORIGEM = 'REAL'` e `CUSTO_FONTE = 'db_analise_vendas.public.produto, conferido em 2026-10-14'`.
- **Proteções contra custo no produto errado:**
  - a carga confere o **nome** de cada produto com o do banco real e recusa qualquer divergência;
  - `08_verificacoes_qualidade.sql` compara os 19 pares (ID, custo) com uma lista de referência independente.
- **Custos reais (`db_analise_vendas.public.produto`, conferidos em 2026-10-14):**

  | ID | Produto | Custo |
  |---:|---|---:|
  | 1 | Notebook Dell Inspiron 15 | 3400.00 |
  | 2 | Notebook Lenovo IdeaPad 3 | 2750.00 |
  | 3 | Desktop Dell OptiPlex | 3050.00 |
  | 4 | Mouse Logitech G502 | 300.00 |
  | 5 | Teclado Mecânico Redragon | 220.00 |
  | 6 | Headset HyperX Cloud II | 330.00 |
  | 7 | Webcam Logitech C920 | 370.00 |
  | 8 | Monitor LG UltraWide 29 | 1150.00 |
  | 9 | Monitor Samsung 24 Full HD | 680.00 |
  | 10 | Monitor Dell 27 QHD | 1700.00 |
  | 11 | Smartphone Samsung Galaxy A55 | 1550.00 |
  | 12 | Tablet Samsung Galaxy Tab | 1450.00 |
  | 13 | Smart TV LG 50 Polegadas | 2200.00 |
  | 14 | Suporte para Notebook | 85.00 |
  | 15 | Hub USB-C 7 em 1 | 130.00 |
  | 16 | Mousepad Gamer Grande | 55.00 |
  | 17 | SSD Kingston 1TB | 370.00 |
  | 18 | SSD Samsung 2TB | 680.00 |
  | 19 | Pen Drive Kingston 128GB | 48.00 |

- **Limitação:** é o custo **atual** do produto, não o histórico. A margem de qualquer período usa o custo de hoje. Um custo histórico, se vier a existir, ficará numa tabela própria e nunca substituirá estes valores.

### C2. Itens gerados apontando para pedidos inexistentes

- **Evidência:** [isercao_dados.sql:246](../sql/isercao_dados.sql#L246) usa `n + 60` (IDs 61-105). Num banco limpo, os pedidos gerados recebem os IDs 16-60, o que causa erro de chave estrangeira.
- **Hipótese sobre o banco do autor:** os pedidos foram inseridos duas vezes. Nesse caso existiriam os pedidos 16-60 sem itens. Não confirmado.
- **Correção:** pedidos e itens são inseridos numa única instrução (`04_dados_gerados.sql`). Os IDs vêm do `RETURNING` e o `n` é recuperado pela data, que é única para cada pedido gerado.
- **Efeito:** na versão corrigida, os pedidos gerados têm os IDs 16-60.

### C3. Pedidos anteriores ao cadastro do cliente

- **Evidência:** o rodízio original (`(n - 1) % total de clientes`, [isercao_dados.sql:227-233](../sql/isercao_dados.sql#L227-L233)) atribuía 7 pedidos a clientes que ainda não estavam cadastrados:

  | Cliente | Data do pedido | Data de cadastro |
  |---|---|---|
  | 4 | 25/01/2026 | 02/02/2026 |
  | 5 | 30/01/2026 | 10/02/2026 |
  | 6 | 04/02/2026 | 18/02/2026 |
  | 7 | 09/02/2026 | 01/03/2026 |
  | 8 | 14/02/2026 | 12/03/2026 |
  | 9 | 19/02/2026 | 20/03/2026 |
  | 10 | 24/02/2026 | 05/04/2026 |

- **Correção:** o rodízio considera só os clientes já cadastrados na data do pedido, em ordem de `DATA_CADASTRO` e depois `ID_CLIENTE`. Os cadastros originais não mudam.
- **Resultado simulado:**
  - os 40 clientes recebem pedidos;
  - nenhum cliente aparece em dois pedidos seguidos;
  - 15 clientes têm 2 ou mais pedidos.
- **Alternativa descartada:** antecipar o cadastro dos 7 clientes, porque alteraria um dado de cadastro.

### C4. `GROUP BY` ambíguo

- **Evidência:** [views.sql:49](../sql/views.sql#L49) usa `GROUP BY NOME` numa consulta que junta `PRODUTO` e `CATEGORIA`, e as duas têm coluna `NOME`. O PostgreSQL recusa a consulta.
- **Correção:** `07_consultas_analiticas.sql` (Q01) usa `GROUP BY C.ID_CATEGORIA, C.NOME` e `LEFT JOIN`.

### C5. View criada duas vezes

- **Evidência:** [views.sql:1-40](../sql/views.sql#L1-L40) e [views.sql:300-339](../sql/views.sql#L300-L339) são idênticas.
- **Correção:** a view é criada uma única vez em `06_views.sql`, com o mesmo texto.

### C6. Homônimos somados como uma só pessoa

- **Evidência:** "Daniel Oliveira" (IDs 5 e 16) e "Lucas Pereira" (IDs 9 e 29). As consultas em [views.sql:75-87](../sql/views.sql#L75-L87) e [views.sql:371-378](../sql/views.sql#L371-L378) agrupavam só pelo nome.
- **Decisão:** os homônimos são mantidos, porque são realistas, e os agrupamentos passam a incluir o ID.

### C7. Scripts não reproduzíveis

- **Evidências:**
  - sem transação;
  - IDs fixos que dependem de tabelas recém-criadas;
  - o gerador depende de quantos clientes existem no momento da execução;
  - uma segunda execução falha no meio e deixa dados parciais.
- **Correções:**
  - executor com trava de banco, `ON_ERROR_STOP` e uma única transação;
  - verificação de tabelas vazias;
  - conferência de IDs após a carga base;
  - nenhum `DROP`.

### C8. Integridade adicional

- **Novas restrições:**
  - `UQ_ITENS_PEDIDO_PEDIDO_PRODUTO`;
  - `CK_CLIENTE_CPF_FORMATO`;
  - `CK_ENDERECO_CEP_FORMATO`, `CK_ENDERECO_UF_FORMATO`;
  - `CK_PRODUTO_CUSTO`, `CK_PRODUTO_CUSTO_ORIGEM`, `CK_PRODUTO_CUSTO_CONSISTENCIA`.
- **Índices:** 6 índices `IX_*` nas chaves estrangeiras. `ITENS_PEDIDO(ID_PEDIDO)` não recebeu índice próprio porque já é coberto por `UQ_ITENS_PEDIDO_PEDIDO_PRODUTO`, cuja primeira coluna é `ID_PEDIDO`. O plano previa 7 índices; o sétimo seria redundante.
- **Mantido igual:** as chaves estrangeiras originais seguem sem `ON DELETE` explícito (comportamento padrão NO ACTION).
- **Fora desta fase:** a regra "pedido não anterior ao cadastro" envolve duas tabelas e é validada no `08`, não por trigger.

### C9. Preço do produto ID 3 diverge do banco real

- **Evidência:**

  | Fonte | Preço do Desktop Dell OptiPlex (ID 3) |
  |---|---|
  | Script original, [isercao_dados.sql:97](../sql/isercao_dados.sql#L97) | **3899.00** |
  | Itens vendidos dos pedidos 6 e 15, [isercao_dados.sql:164](../sql/isercao_dados.sql#L164) e [:186](../sql/isercao_dados.sql#L186) | **3899.00** |
  | `db_analise_vendas.public.produto`, conferido em 2026-10-14 | **3899.90** |

  Os outros 18 produtos têm nome e preço idênticos nas três fontes.
- **Decisão do autor (Opção A):** manter **3899.00** nos scripts reproduzíveis. É fiel aos scripts originais e ao preço registrado nos itens vendidos.
- **Implementação:** `05_custos_carga.sql` guarda o preço do banco real (`PRECO_REFERENCIA`) só para conferência. A divergência aparece como aviso na carga e **não altera** `PRODUTO.PRECO`.
- **Efeito:**
  - o custo não depende do preço, então a associação dos custos não é afetada;
  - faturamento e lucro esperados seguem o preço dos scripts.
- **Não investigado:** a causa da diferença (atualização posterior de preço no banco real ou outra versão do script).

### C10. Custo histórico por item vendido

- **Problema (auditoria):** a `vw_vendas` calcula o custo com `PRODUTO.CUSTO`, que é o custo **atual**. Se o custo de um produto mudar, a margem de todas as vendas passadas muda junto.
- **Decisão:** registrar o custo no momento da venda, **sem alterar a regra da `vw_vendas`**:
  - nova coluna `ITENS_PEDIDO.CUSTO_UNITARIO` (`01`), com `CHECK (> 0)` (`02`);
  - preenchida por `05_custos_carga.sql` a partir do custo real atual, e depois tornada `NOT NULL`;
  - a nova `vw_fato_vendas` usa o custo do item;
  - a `vw_vendas` continua com o custo atual do produto (contrato do relatório original).
- **Efeito hoje:** nenhum. As duas regras somam R$ 258.699,00, o que o `08` confere, e 0 itens têm custo diferente do produto.
- **Efeito futuro:** se o custo de algum produto mudar, as duas views passam a divergir. Isso é o comportamento esperado. O teste "itens com custo histórico diferente do custo atual" deve ser revisto nesse momento.
- **Limitação:** não existe histórico real de custos anteriores. O custo registrado é o atual, aplicado a todas as vendas da carga inicial.

### C11. Camada estrela para o Power BI, sem dados pessoais

- **Problema:** o relatório original lê a `vw_vendas`, uma tabela única com nomes repetidos em cada linha, e dimensões criadas no Power Query a partir de tabelas que podem conter CPF, e-mail e salário (não verificado, ver [POWERBI_GUIA.md](POWERBI_GUIA.md) §4).
- **Decisão:** 5 views novas em `06_views.sql`, **ao lado** da `vw_vendas`, que não muda:

  | View | Conteúdo |
  |---|---|
  | `vw_fato_vendas` | Só chaves e medidas (faturamento, custo histórico, lucro) |
  | `vw_dim_cliente` | Sem CPF, e-mail, telefone ou endereço completo; `cliente_exibicao = "Nome (#ID)"` para os homônimos |
  | `vw_dim_produto` | Categoria desnormalizada; preço, custo, margem e estoque **atuais** |
  | `vw_dim_vendedor` | Sem e-mail, telefone ou salário (dado de RH fora do escopo analítico) |
  | `vw_dim_calendario` | 2025–2026, nomes em português, `situacao_mes` (`Antes das vendas`, `Completo`, `Parcial`, `Sem vendas registradas`) |

- **Calendário:** cobre desde o primeiro cadastro de cliente (jun/2025), para permitir a análise de novos clientes. A primeira versão cobria só 2026 e foi ampliada antes da validação final.
- **Testes:** 20 testes no `08`, incluindo um que reprova a carga se aparecer coluna pessoal numa `vw_fato_*` ou `vw_dim_*`.
- **Indicador removido:** "faturamento ÷ salário", proposto na auditoria. Exigiria levar salário ao modelo analítico.

### C12. Acesso somente leitura para o Power BI

- **Problema:** o conector PostgreSQL do Power BI não aceita autenticação do Windows, e não convém usar o dono do banco para leitura.
- **Decisão:** papel `techstore_bi_leitor` com `SELECT` **apenas nas 6 views** ([09_acesso_leitura_bi.sql](../database/09_acesso_leitura_bi.sql)). Nenhuma tabela é concedida.
- **Evidência:** o papel lê `vw_fato_vendas` (170 linhas), e `SELECT` em `cliente` retorna `permissão negada`.
- **Senha:** definida pelo autor com `\password` e guardada só nas credenciais do Power BI.

### C13. Bancos de validação versionados, sem `DROP`

- **Problema:** depois de uma carga com sucesso, revalidar exigiria apagar o banco, o que é destrutivo e precisa de aprovação.
- **Decisão:** a trava do executor aceita `techstore_dev` e `techstore_dev_<sufixo>`, e cada rodada usa um banco **novo e vazio**:
  - `techstore_dev`: primeira validação;
  - `techstore_dev_v2`: C10 e C11;
  - `techstore_dev_v3`: versão final.
- Os bancos antigos ficam como evidência até haver aprovação para removê-los.

### C14. Acesso somente leitura para a API do dashboard web

- **Decisão do autor:** usar um papel próprio para a API, `techstore_api_leitor`, separado do leitor do Power BI.
- **Privilégio mínimo:** `SELECT` só em `vw_fato_vendas`, `vw_dim_produto`, `vw_dim_vendedor` e `vw_dim_calendario` ([10_acesso_leitura_api.sql](../database/10_acesso_leitura_api.sql)).
  - fica de fora a `vw_dim_cliente`: nenhum endpoint expõe clientes individualmente;
  - ficam de fora a `vw_vendas` e todas as tabelas.
- **Proteções no próprio papel:**
  - `default_transaction_read_only = on`;
  - `statement_timeout = 5s`;
  - `CONNECTION LIMIT 10`;
  - nenhum atributo especial.

  Elas valem mesmo que a API seja configurada de forma errada.
- **Evidência (2026-10-15, `techstore_dev_v3`):**
  - leu `vw_fato_vendas` (170 linhas) e `vw_dim_calendario` (730 linhas);
  - recebeu `permissão negada` em `vw_dim_cliente`, `vw_vendas` e na tabela `cliente`.
- **Senha:** definida pelo autor com `\password`. A API lê a senha de `api/.env`, que fica fora do Git e só é legível pelo usuário do Windows.
- **Evidência com login real (2026-10-15):** os 10 testes de privilégio de `api/tests/test_privilegios.py` passaram conectando como `techstore_api_leitor`. A suíte completa da API deu 55/55.


---

## 4A. Banco real × versão reproduzível

| Aspecto | `db_analise_vendas` (real) | `techstore_dev` (scripts de `database/`) |
|---|---|---|
| Custos dos 19 produtos | Preenchidos | Mesmos valores (C1) |
| Preço do ID 3 | 3899.90 | 3899.00 (C9) |
| Colunas de rastreabilidade em `PRODUTO` | Não existem | `CUSTO_ORIGEM` e `CUSTO_FONTE` (o Power BI não é afetado, porque lê só a view) |
| Custo histórico no item | Não existe | `ITENS_PEDIDO.CUSTO_UNITARIO` (C10) |
| Camada estrela e papel de leitura | Não existem | 5 views e `techstore_bi_leitor` (C11, C12) |
| `custo` aceita nulo? | Não verificado | Aceita, mas o `08` reprova qualquer custo vazio |
| `vw_vendas` | 15 colunas (verificado pelo autor) | Mesmo texto da view original; contrato conferido pelo `08` |
| IDs e quantidade de pedidos | Não verificados (hipótese C2: IDs 61-105) | IDs 1-60 |
| Totais de faturamento e custo | Não verificados | Ver seção 7 |

---

## 5. Rastreabilidade: original → novo

| Original | Novo | Observação |
|---|---|---|
| `criacao_tabelas.sql:1-102` | `01_estrutura.sql` | Idêntico, mais as 3 colunas de custo em `PRODUTO` e `CUSTO_UNITARIO` em `ITENS_PEDIDO` (C10) |
| `criacao_tabelas.sql:106-205` | `02_restricoes_indices.sql` | Idêntico, mais as novas restrições e índices |
| `isercao_dados.sql:1-187` | `03_dados_base.sql` | Mesmos valores |
| `isercao_dados.sql:190-222` | `03_dados_base.sql` | Movido para logo após os 10 primeiros clientes; mesmos IDs (11-40) |
| `isercao_dados.sql:225-264` | `04_dados_gerados.sql` | Gerador corrigido (C2, C3) |
| `views.sql:1-40` e `300-339` | `06_views.sql` | Criada uma única vez (C5) |
| `views.sql:43-298` e `341-378` | `07_consultas_analiticas.sql` | Q01-Q21; correções C4 e C6; Q14-Q16 originais consolidadas numa só; versão primitiva da view (279-298) mantida comentada |
| — | `05_custos_carga.sql` | Novo: carga dos 19 custos reais (C1), com conferência de nomes, e custo histórico nos itens (C10) |
| — | `06_views.sql` (fim do arquivo) | Novo: camada estrela (C11) |
| — | `08_verificacoes_qualidade.sql` | Novo: 71 testes bloqueantes e 3 informativos |
| — | `09_acesso_leitura_bi.sql` | Novo: acesso somente leitura do Power BI (C12) |
| — | `00_executar_tudo.sql` | Novo: executor seguro (trava `techstore_dev*`, C13) |

---

## 6. Como executar

1. Crie um banco **novo e vazio** com nome `techstore_dev` ou `techstore_dev_<sufixo>`, nunca o banco real.
2. Na raiz do projeto, rode:

   ```bash
   psql "host=localhost port=5433 dbname=techstore_dev_vN user=<usuario>" -X -v ON_ERROR_STOP=1 -f database/00_executar_tudo.sql
   ```

3. Confira a tabela de resultados mostrada pelo `08`. Qualquer FALHA desfaz toda a carga.
4. Os scripts não rodam duas vezes no mesmo banco: a segunda execução falha logo no início, sem alterar nada. Para repetir, crie outro banco vazio.

Execuções reais e evidências: [VALIDACAO.md](VALIDACAO.md).

---

## 7. Resultados esperados (`08_verificacoes_qualidade.sql`)

Os valores de faturamento e unidades não dependem de qual cliente recebeu cada pedido. Foram calculados reproduzindo a lógica dos scripts, sem banco de dados, e **confirmados exatamente na execução real** de 2026-10-15 ([VALIDACAO.md](VALIDACAO.md)).

| Grupo | Verificação | Esperado |
|---|---|---|
| IDs | Linhas por tabela | 40 clientes · 10 endereços · 13 telefones · 5 vendedores · 6 categorias · 19 produtos · 60 pedidos · 170 itens |
| IDs | Pedidos | IDs 1-60 contínuos, nenhum sem itens; 35 itens nos manuais; 3 itens em cada gerado |
| Datas | Pedido anterior ao cadastro ou à admissão | 0 |
| Datas | Período | 2026-01-10 a 2026-08-18 |
| Datas | Clientes | 40 com pedido; 15 com 2 ou mais pedidos |
| Datas | Pedidos por vendedor (IDs 1-5) | 13 / 12 / 11 / 12 / 12 |
| Faturamento | Total | R$ 335.062,30 (manuais R$ 50.044,00 + gerados R$ 285.018,30) |
| Faturamento | Unidades | 260 |
| Faturamento | Por mês | Jan 33.115,90 · Fev 30.866,60 · Mar 39.856,80 · Abr 63.511,10 · Mai 64.142,30 · Jun 41.367,10 · Jul 40.434,40 · Ago 21.768,10 |
| Catálogo | Somas | Preços 26.537,20 · estoque 367 · salários 21.000,00 |
| Custos | Origem | 19/19 produtos com custo `REAL` |
| Custos | Referência | 0 divergências nos 19 pares (ID, custo) |
| Custos | Soma dos custos do catálogo | R$ 20.518,00 |
| Custos | Custo total das vendas | **R$ 258.699,00** |
| Custos | Lucro bruto | **R$ 76.363,30** |
| Custos | Margem bruta | **22,79%** |
| Power BI | `vw_vendas` | Existe em `public`; 15 colunas conforme o contrato; 170 linhas; faturamento igual ao de `ITENS_PEDIDO` |
| Power BI | Custo na view | 0 linhas com `custo_total <> qtd × custo_unitario`; 0 linhas sem custo; soma de `custo_total` = 258.699,00 |
| Aviso | Homônimos | 2 |
| Aviso | Custo maior ou igual ao preço | 0 |
| Aviso | Mês incompleto | Agosto (dados até o dia 18) |

Faturamento e lucro usam o preço dos scripts para o ID 3 (3899.00, decisão C9). O custo total não depende do preço.

**Unidades e custo por produto (base dos valores esperados):**

| ID | Unidades | Custo total | ID | Unidades | Custo total |
|---:|---:|---:|---:|---:|---:|
| 1 | 13 | 44.200,00 | 11 | 11 | 17.050,00 |
| 2 | 12 | 33.000,00 | 12 | 13 | 18.850,00 |
| 3 | 13 | 39.650,00 | 13 | 12 | 26.400,00 |
| 4 | 13 | 3.900,00 | 14 | 17 | 1.445,00 |
| 5 | 13 | 2.860,00 | 15 | 19 | 2.470,00 |
| 6 | 12 | 3.960,00 | 16 | 16 | 880,00 |
| 7 | 13 | 4.810,00 | 17 | 12 | 4.440,00 |
| 8 | 12 | 13.800,00 | 18 | 14 | 9.520,00 |
| 9 | 15 | 10.200,00 | 19 | 18 | 864,00 |
| 10 | 12 | 20.400,00 | | **260** | **258.699,00** |

**Teste no Power BI (fase futura):** apontar uma **cópia** do .pbix para `techstore_dev`, atualizar e conferir R$ 335.062,30 no card de faturamento. O .pbix original nunca é editado.

---

## 8. Pendências

| # | Pendência | Depende de |
|---|---|---|
| 1 | ~~Fonte real dos custos~~: **resolvida em 2026-10-14** (C1) | — |
| 2 | Confirmar o estado do banco real (IDs 61-105? pedidos sem itens? totais?) e a definição completa da `vw_vendas` (posição e tipo das colunas) | Consultas só de leitura, executadas pelo autor |
| 3 | ~~Executar a validação~~: **concluída em 2026-10-15** ([VALIDACAO.md](VALIDACAO.md)) | — |
| 4 | Enriquecimento sintético: status, desconto, pagamento, canal, frete e metas | Regras aprovadas pelo autor |
| 5 | ~~Mascaramento de dados pessoais no BI~~: **resolvido pela C11** (dados pessoais fora das views analíticas). CPFs fictícios com dígito verificador inválido continuam nas tabelas | Fase de enriquecimento |
| 6 | ~~README, diagrama e modelo estrela~~: **feitos** ([README](../README.md), [MODELO_DE_DADOS.md](MODELO_DE_DADOS.md)) | — |
| 7 | Montar o novo modelo e a página executiva na cópia `TECHSTORE_VENDAS_v2.pbix` | Autor, no Power BI Desktop ([POWERBI_GUIA.md](POWERBI_GUIA.md)) |
| 8 | Remover os bancos de validação antigos (`techstore_dev`, `techstore_dev_v2`) | Aprovação para `DROP DATABASE` |
| 9 | ~~Senha do `techstore_api_leitor`, testes de privilégio e troca da prévia~~: **concluídos em 2026-10-15** (55/55 testes com o papel real; [DASHBOARD_WEB.md](DASHBOARD_WEB.md#tarefas-em-aberto)) | — |
