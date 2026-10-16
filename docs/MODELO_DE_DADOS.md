# Modelo de dados

Este documento substitui, como referência atual, o diagrama conceitual original em [documentacao/Modelagem_BRModelo.png](../documentacao/Modelagem_BRModelo.png). O original fica preservado como histórico.

Os diagramas usam Mermaid, que o GitHub desenha automaticamente.

---

## 1. Modelo transacional (tabelas)

```mermaid
erDiagram
    CLIENTE ||--o{ ENDERECO : "possui"
    CLIENTE ||--o{ TELEFONE : "possui"
    CLIENTE ||--o{ PEDIDO : "realiza"
    VENDEDOR ||--o{ PEDIDO : "registra"
    PEDIDO ||--|{ ITENS_PEDIDO : "contém"
    PRODUTO ||--o{ ITENS_PEDIDO : "é vendido em"
    CATEGORIA ||--o{ PRODUTO : "classifica"

    CLIENTE {
        int id_cliente PK
        varchar nome
        char cpf UK "11 dígitos"
        varchar email UK
        date data_cadastro
    }
    ENDERECO {
        int id_endereco PK
        int id_cliente FK
        char cep "8 dígitos"
        varchar logradouro
        varchar numero
        varchar complemento "opcional"
        varchar bairro
        varchar cidade
        char uf "2 letras"
    }
    TELEFONE {
        int id_telefone PK
        int id_cliente FK
        varchar numero
        varchar tipo "CELULAR, RESIDENCIAL, COMERCIAL"
    }
    VENDEDOR {
        int id_vendedor PK
        varchar nome
        varchar email UK
        varchar telefone
        numeric salario "maior que 0"
        date data_admissao
    }
    CATEGORIA {
        int id_categoria PK
        varchar nome
        varchar descricao "opcional"
    }
    PRODUTO {
        int id_produto PK
        int id_categoria FK
        varchar nome
        numeric preco "maior que 0"
        int estoque "maior ou igual a 0"
        numeric custo "real, maior que 0"
        varchar custo_origem "REAL ou SINTETICO"
        varchar custo_fonte "rastreabilidade"
    }
    PEDIDO {
        int id_pedido PK
        int id_cliente FK
        int id_vendedor FK
        date data_pedido
    }
    ITENS_PEDIDO {
        int id_itens_pedido PK
        int id_pedido FK "UK com id_produto"
        int id_produto FK
        int quantidade "maior que 0"
        numeric preco_unitario "maior que 0"
        numeric custo_unitario "custo histórico, NOT NULL"
    }
```

**Mudanças em relação ao diagrama original:**

| Original (BRModelo) | Atual | Motivo |
|---|---|---|
| `PRODUTO` sem custo | `custo`, `custo_origem`, `custo_fonte` | C1: custo existia só no banco do autor |
| `ITENS_PEDIDO` sem custo | `custo_unitario` (custo histórico) | C10 |
| Cardinalidade mínima 1 em endereço, telefone e pedido | Mínima 0 (`o{`) | 30 dos 40 clientes não têm endereço nem telefone; um cliente pode existir sem pedido |
| Rótulos sobrepostos em `ENDERECO` | Diagrama legível | Correção de documentação |
| Sem unicidade em itens | `UNIQUE (id_pedido, id_produto)` | C8 |

**Regras que não cabem num diagrama** (validadas em `database/08_verificacoes_qualidade.sql`):
- data do pedido maior ou igual ao cadastro do cliente e à admissão do vendedor;
- todo pedido tem ao menos um item;
- `custo_total = quantidade × custo_unitario` em todas as linhas da fato.

---

## 2. Modelo analítico (estrela) para o Power BI

```mermaid
erDiagram
    vw_dim_calendario ||--o{ vw_fato_vendas : "data = data_pedido"
    vw_dim_cliente    ||--o{ vw_fato_vendas : "id_cliente"
    vw_dim_produto    ||--o{ vw_fato_vendas : "id_produto"
    vw_dim_vendedor   ||--o{ vw_fato_vendas : "id_vendedor"

    vw_fato_vendas {
        int id_item PK
        int id_pedido
        date data_pedido FK
        int id_cliente FK
        int id_vendedor FK
        int id_produto FK
        int quantidade
        numeric preco_unitario
        numeric faturamento
        numeric custo_unitario "histórico"
        numeric custo_total
        numeric lucro_bruto
    }
    vw_dim_cliente {
        int id_cliente PK
        varchar cliente
        text cliente_exibicao "Nome (#ID)"
        date data_cadastro
        date mes_cadastro
        varchar bairro
        varchar cidade
        text uf
    }
    vw_dim_produto {
        int id_produto PK
        varchar produto
        int id_categoria
        varchar categoria
        numeric preco_atual
        numeric custo_atual
        numeric margem_atual_pct
        int estoque_atual
    }
    vw_dim_vendedor {
        int id_vendedor PK
        varchar vendedor
        date data_admissao
    }
    vw_dim_calendario {
        date data PK
        int ano
        int trimestre
        int mes
        text nome_mes
        text ano_mes "jan/26"
        int ano_mes_num "ordenação"
        date inicio_mes
        int dia_semana_num
        text dia_semana
        text situacao_mes "Antes das vendas, Completo, Parcial, Sem vendas registradas"
    }
```

**Relacionamentos no Power BI:** todos 1:N, com filtro em direção única, das dimensões para a fato. `Calendario` é marcada como tabela de datas.

**Dados pessoais:** nenhuma dimensão expõe CPF, e-mail, telefone, logradouro, número, CEP ou salário. Um teste do `08` reprova a carga se alguma dessas colunas aparecer numa `vw_fato_*` ou `vw_dim_*`.

---

## 3. Linhagem das views

```mermaid
flowchart LR
    PEDIDO --> vw_fato_vendas
    ITENS_PEDIDO --> vw_fato_vendas
    CLIENTE --> vw_dim_cliente
    ENDERECO --> vw_dim_cliente
    PRODUTO --> vw_dim_produto
    CATEGORIA --> vw_dim_produto
    VENDEDOR --> vw_dim_vendedor
    PEDIDO --> vw_dim_calendario
    CLIENTE --> vw_dim_calendario

    PEDIDO --> vw_vendas
    ITENS_PEDIDO --> vw_vendas
    CLIENTE --> vw_vendas
    VENDEDOR --> vw_vendas
    PRODUTO --> vw_vendas
    CATEGORIA --> vw_vendas
```

| View | Para que serve | Custo usado |
|---|---|---|
| `vw_vendas` | Contrato do relatório original (`F_vw_vendas`, 15 colunas fixas) | Custo **atual** do produto |
| `vw_fato_vendas` | Fato do novo modelo estrela | Custo **histórico** do item |

Hoje as duas somam R$ 258.699,00, porque o custo histórico foi registrado a partir do custo atual na carga inicial. Elas só passam a divergir se o custo de algum produto mudar depois. Essa divergência é esperada e é o motivo de existir o custo histórico ([C10](DECISOES_E_CORRECOES.md)).
