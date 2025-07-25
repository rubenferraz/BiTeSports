-- Treinadores
CREATE TABLE treinadores (
    id SERIAL PRIMARY KEY,
    nome TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL
);

-- Equipas
CREATE TABLE equipas (
    id SERIAL PRIMARY KEY,
    nome TEXT NOT NULL,
    treinador_id INTEGER REFERENCES treinadores(id) ON DELETE CASCADE
);

-- Jogadores
CREATE TABLE jogadores (
    id SERIAL PRIMARY KEY,
    nome TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    equipa_id INTEGER REFERENCES equipas(id)
);

-- ECG (dados fisiológicos)
CREATE TABLE ecg_dados (
    id SERIAL PRIMARY KEY,
    jogador_id INTEGER REFERENCES jogadores(id),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    valor_mv REAL NOT NULL
);

-- Formulários
CREATE TABLE formularios (
    id SERIAL PRIMARY KEY,
    jogador_id INTEGER REFERENCES jogadores(id) ON DELETE CASCADE,  -- Relacionamento com a tabela de jogadores
    resultado VARCHAR(10) NOT NULL,  -- "vitoria" ou "derrota"
    performance INTEGER CHECK (performance BETWEEN 0 AND 10),
    foco INTEGER CHECK (foco BETWEEN 0 AND 10),
    confianca INTEGER CHECK (confianca BETWEEN 0 AND 10),
    desempenho_fisico INTEGER CHECK (desempenho_fisico BETWEEN 0 AND 10),
    cansaco_mental INTEGER CHECK (cansaco_mental BETWEEN 0 AND 10),
    stress INTEGER CHECK (stress BETWEEN 0 AND 10),
    controlo INTEGER CHECK (controlo BETWEEN 0 AND 10),
    comunicacao INTEGER CHECK (comunicacao BETWEEN 0 AND 10),
    colaboracao INTEGER CHECK (colaboracao BETWEEN 0 AND 10),
    desconforto INTEGER CHECK (desconforto BETWEEN 0 AND 10),
    conforto_sensor INTEGER CHECK (conforto_sensor BETWEEN 0 AND 10),
    utilidade INTEGER CHECK (utilidade BETWEEN 0 AND 10),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP  -- Timestamp automático
);

CREATE TABLE sessoes (
    id SERIAL PRIMARY KEY,
    jogador_id INTEGER REFERENCES jogadores(id) ON DELETE CASCADE,
    timestamp_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE ecg_dados ADD COLUMN sessao_id INTEGER REFERENCES sessoes(id);
