INSERT INTO CLIENTE(NOME, CPF, EMAIL, DATA_CADASTRO)
VALUES
('Thiago Miranda', '12345678901', 'thiago.miranda@email.com', '2026-01-10'),
('Ana Carolina Souza', '23456789012', 'ana.souza@email.com', '2026-01-15'),
('Bruno Almeida', '34567890123', 'bruno.almeida@email.com', '2026-01-20'),
('Camila Ferreira', '45678901234', 'camila.ferreira@email.com', '2026-02-02'),
('Daniel Oliveira', '56789012345', 'daniel.oliveira@email.com', '2026-02-10'),
('Fernanda Costa', '67890123456', 'fernanda.costa@email.com', '2026-02-18'),
('Gabriel Santos', '78901234567', 'gabriel.santos@email.com', '2026-03-01'),
('Juliana Martins', '89012345678', 'juliana.martins@email.com', '2026-03-12'),
('Lucas Pereira', '90123456789', 'lucas.pereira@email.com', '2026-03-20'),
('Mariana Rocha', '01234567890', 'mariana.rocha@email.com', '2026-04-05');



INSERT INTO ENDERECO(
ID_CLIENTE,
CEP,
LOGRADOURO,
NUMERO,
COMPLEMENTO,
BAIRRO,
CIDADE,
UF
)
VALUES
(1, '20550013', 'Rua Conde de Bonfim', '125', 'Apto 301', 'Tijuca', 'Rio de Janeiro', 'RJ'),
(2, '22231050', 'Rua Voluntários da Pátria', '450', 'Apto 702', 'Botafogo', 'Rio de Janeiro', 'RJ'),
(3, '22041080', 'Rua Visconde de Pirajá', '890', 'Apto 504', 'Ipanema', 'Rio de Janeiro', 'RJ'),
(4, '22441020', 'Rua Jardim Botânico', '620', 'Casa', 'Jardim Botânico', 'Rio de Janeiro', 'RJ'),
(5, '22793080', 'Avenida das Américas', '3500', 'Sala 1205', 'Barra da Tijuca', 'Rio de Janeiro', 'RJ'),
(6, '20551040', 'Rua Haddock Lobo', '210', 'Apto 402', 'Tijuca', 'Rio de Janeiro', 'RJ'),
(7, '22271030', 'Rua São Clemente', '315', 'Apto 803', 'Botafogo', 'Rio de Janeiro', 'RJ'),
(8, '20261040', 'Rua do Catete', '180', 'Apto 205', 'Catete', 'Rio de Janeiro', 'RJ'),
(9, '20735020', 'Rua Dias da Cruz', '540', 'Apto 601', 'Méier', 'Rio de Janeiro', 'RJ'),
(10, '22471000', 'Avenida Ataulfo de Paiva', '900', 'Apto 1102', 'Leblon', 'Rio de Janeiro', 'RJ');



INSERT INTO TELEFONE (ID_CLIENTE, NUMERO, TIPO)
VALUES
(1, '21987654321', 'CELULAR'),
(1, '2132567890', 'RESIDENCIAL'),
(2, '21976543210', 'CELULAR'),
(3, '21965432109', 'CELULAR'),
(4, '21954321098', 'CELULAR'),
(4, '2133456789', 'RESIDENCIAL'),
(5, '21943210987', 'CELULAR'),
(5, '2132123456', 'COMERCIAL'),
(6, '21932109876', 'CELULAR'),
(7, '21921098765', 'CELULAR'),
(8, '21910987654', 'CELULAR'),
(9, '21909876543', 'CELULAR'),
(10, '21998765432', 'CELULAR');



INSERT INTO VENDEDOR (
NOME,
EMAIL,
TELEFONE,
SALARIO,
DATA_ADMISSAO
)
VALUES
('Carlos Henrique', 'carlos.henrique@empresa.com', '21987651234', 3500.00, '2024-02-15'),
('Juliana Mendes', 'juliana.mendes@empresa.com', '21976542345', 3800.00, '2024-06-10'),
('Rafael Martins', 'rafael.martins@empresa.com', '21965433456', 4200.00, '2025-01-20'),
('Patricia Oliveira', 'patricia.oliveira@empresa.com', '21954324567', 4500.00, '2025-04-05'),
('Marcelo Santos', 'marcelo.santos@empresa.com', '21943215678', 5000.00, '2025-09-12');



INSERT INTO CATEGORIA (
NOME,
DESCRICAO
)
VALUES
('Informática', 'Computadores, notebooks e equipamentos de informática'),
('Periféricos', 'Teclados, mouses e outros periféricos'),
('Monitores', 'Monitores para uso profissional e pessoal'),
('Eletrônicos', 'Equipamentos eletrônicos em geral'),
('Acessórios', 'Acessórios para computadores e dispositivos eletrônicos'),
('Armazenamento', 'Dispositivos para armazenamento de dados');



INSERT INTO PRODUTO (
ID_CATEGORIA,
NOME,
PRECO,
ESTOQUE
)
VALUES
(1, 'Notebook Dell Inspiron 15', 4299.90, 15),
(1, 'Notebook Lenovo IdeaPad 3', 3499.90, 20),
(1, 'Desktop Dell OptiPlex', 3899.00, 8),

(2, 'Mouse Logitech G502', 399.90, 25),
(2, 'Teclado Mecânico Redragon', 299.90, 30),
(2, 'Headset HyperX Cloud II', 449.90, 18),
(2, 'Webcam Logitech C920', 499.90, 12),

(3, 'Monitor LG UltraWide 29', 1499.90, 10),
(3, 'Monitor Samsung 24 Full HD', 899.90, 22),
(3, 'Monitor Dell 27 QHD', 2199.90, 7),

(4, 'Smartphone Samsung Galaxy A55', 1999.90, 14),
(4, 'Tablet Samsung Galaxy Tab', 1899.90, 9),
(4, 'Smart TV LG 50 Polegadas', 2799.90, 6),

(5, 'Suporte para Notebook', 129.90, 35),
(5, 'Hub USB-C 7 em 1', 189.90, 20),
(5, 'Mousepad Gamer Grande', 89.90, 40),

(6, 'SSD Kingston 1TB', 499.90, 16),
(6, 'SSD Samsung 2TB', 899.90, 10),
(6, 'Pen Drive Kingston 128GB', 79.90, 50);



INSERT INTO PEDIDO (
ID_CLIENTE,
ID_VENDEDOR,
DATA_PEDIDO
)
VALUES
(1, 1, '2026-04-10'),
(2, 2, '2026-04-12'),
(3, 1, '2026-04-15'),
(4, 3, '2026-04-18'),
(5, 4, '2026-04-20'),
(1, 2, '2026-04-22'),
(6, 5, '2026-04-25'),
(7, 3, '2026-04-28'),
(8, 1, '2026-05-02'),
(9, 4, '2026-05-05'),
(10, 5, '2026-05-08'),
(3, 2, '2026-05-12'),
(5, 1, '2026-05-15'),
(2, 4, '2026-05-18'),
(7, 5, '2026-05-22');



INSERT INTO ITENS_PEDIDO (
ID_PEDIDO,
ID_PRODUTO,
QUANTIDADE,
PRECO_UNITARIO
)
VALUES
(1, 1, 1, 4299.90),
(1, 4, 2, 399.90),
(1, 5, 1, 299.90),
(2, 8, 1, 1499.90),
(2, 15, 1, 189.90),
(3, 2, 1, 3499.90),
(3, 6, 1, 449.90),
(4, 9, 2, 899.90),
(4, 16, 1, 89.90),
(5, 11, 1, 1999.90),
(5, 17, 2, 499.90),
(6, 3, 1, 3899.00),
(6, 7, 1, 499.90),
(6, 14, 1, 129.90),
(7, 10, 1, 2199.90),
(7, 18, 1, 899.90),
(8, 13, 1, 2799.90),
(8, 19, 2, 79.90),
(9, 1, 1, 4299.90),
(9, 5, 1, 299.90),
(9, 16, 1, 89.90),
(10, 12, 1, 1899.90),
(10, 15, 1, 189.90),
(11, 4, 1, 399.90),
(11, 6, 1, 449.90),
(11, 7, 1, 499.90),
(12, 8, 1, 1499.90),
(12, 10, 1, 2199.90),
(13, 2, 1, 3499.90),
(13, 18, 1, 899.90),
(14, 11, 1, 1999.90),
(14, 14, 2, 129.90),
(14, 19, 3, 79.90),
(15, 3, 1, 3899.00),
(15, 9, 1, 899.90);


INSERT INTO cliente
(nome, cpf, email, data_cadastro)
VALUES
('Amanda Ferreira', '00000000011', 'amanda.ferreira@techstore.com.br', '2025-06-03'),
('André Martins', '00000000012', 'andre.martins@techstore.com.br', '2025-06-08'),
('Beatriz Almeida', '00000000013', 'beatriz.almeida@techstore.com.br', '2025-06-15'),
('Bruno Carvalho', '00000000014', 'bruno.carvalho@techstore.com.br', '2025-06-20'),
('Camila Rocha', '00000000015', 'camila.rocha@techstore.com.br', '2025-06-28'),
('Daniel Oliveira', '00000000016', 'daniel.oliveira@techstore.com.br', '2025-07-04'),
('Eduardo Costa', '00000000017', 'eduardo.costa@techstore.com.br', '2025-07-10'),
('Fernanda Lima', '00000000018', 'fernanda.lima@techstore.com.br', '2025-07-18'),
('Felipe Gomes', '00000000019', 'felipe.gomes@techstore.com.br', '2025-07-25'),
('Gabriela Santos', '00000000020', 'gabriela.santos@techstore.com.br', '2025-08-02'),
('Gustavo Ribeiro', '00000000021', 'gustavo.ribeiro@techstore.com.br', '2025-08-11'),
('Helena Barbosa', '00000000022', 'helena.barbosa@techstore.com.br', '2025-08-19'),
('Igor Mendes', '00000000023', 'igor.mendes@techstore.com.br', '2025-08-28'),
('Isabela Castro', '00000000024', 'isabela.castro@techstore.com.br', '2025-09-05'),
('João Almeida', '00000000025', 'joao.almeida@techstore.com.br', '2025-09-13'),
('Julia Rodrigues', '00000000026', 'julia.rodrigues@techstore.com.br', '2025-09-22'),
('Leonardo Souza', '00000000027', 'leonardo.souza@techstore.com.br', '2025-10-01'),
('Larissa Mendes', '00000000028', 'larissa.mendes@techstore.com.br', '2025-10-10'),
('Lucas Pereira', '00000000029', 'lucas.pereira@techstore.com.br', '2025-10-18'),
('Mariana Alves', '00000000030', 'mariana.alves@techstore.com.br', '2025-10-27'),
('Matheus Silva', '00000000031', 'matheus.silva@techstore.com.br', '2025-11-03'),
('Natalia Freitas', '00000000032', 'natalia.freitas@techstore.com.br', '2025-11-12'),
('Pedro Henrique', '00000000033', 'pedro.henrique@techstore.com.br', '2025-11-20'),
('Rafael Gomes', '00000000034', 'rafael.gomes@techstore.com.br', '2025-11-28'),
('Renata Martins', '00000000035', 'renata.martins@techstore.com.br', '2025-12-04'),
('Ricardo Nunes', '00000000036', 'ricardo.nunes@techstore.com.br', '2025-12-10'),
('Sabrina Costa', '00000000037', 'sabrina.costa@techstore.com.br', '2025-12-18'),
('Thiago Ribeiro', '00000000038', 'thiago.ribeiro@techstore.com.br', '2026-01-05'),
('Vanessa Oliveira', '00000000039', 'vanessa.oliveira@techstore.com.br', '2026-01-15'),
('Vinicius Carvalho', '00000000040', 'vinicius.carvalho@techstore.com.br', '2026-01-25');


INSERT INTO pedido (id_cliente, id_vendedor, data_pedido)
SELECT
(
SELECT id_cliente
FROM cliente
ORDER BY id_cliente
OFFSET ((n - 1) % (SELECT COUNT(*) FROM cliente))
LIMIT 1
) AS id_cliente,

((n - 1) % 5) + 1 AS id_vendedor,

DATE '2026-01-10' + ((n - 1) * 5) AS data_pedido

FROM generate_series(1, 45) AS n;


INSERT INTO itens_pedido
(id_pedido, id_produto, quantidade, preco_unitario)

SELECT
n + 60 AS id_pedido,

((n * 3 + k * 5) % 19) + 1 AS id_produto,

CASE
WHEN ((n * 3 + k * 5) % 19) + 1 IN (14, 15, 16, 19)
THEN 1 + ((n + k) % 3)
ELSE
1 + ((n + k) % 2)
END AS quantidade,

p.preco AS preco_unitario

FROM generate_series(1, 45) AS n

CROSS JOIN generate_series(1, 3) AS k

JOIN produto p
ON p.id_produto = ((n * 3 + k * 5) % 19) + 1;