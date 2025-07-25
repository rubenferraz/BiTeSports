import psycopg2
import os

# ⚙️ Configurações da Base de Dados
DB_NAME = os.getenv("DB_NAME", "ecgdb")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASS = os.getenv("DB_PASS", "admin")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")

def get_connection():
    return psycopg2.connect(
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASS,
        host=DB_HOST,
        port=DB_PORT
    )

# 🟢 Função para guardar os dados do formulário
def guardar_formulario(jogador_id, resultado, performance, foco, confianca, desempenho_fisico,
                      cansaco_mental, stress, controlo, comunicacao, colaboracao,
                      desconforto, conforto_sensor, utilidade):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        INSERT INTO formularios (
            jogador_id, resultado, performance, foco, confianca, desempenho_fisico,
            cansaco_mental, stress, controlo, comunicacao, colaboracao,
            desconforto, conforto_sensor, utilidade
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """, (
        jogador_id, resultado, performance, foco, confianca, desempenho_fisico,
        cansaco_mental, stress, controlo, comunicacao, colaboracao,
        desconforto, conforto_sensor, utilidade
    ))
    conn.commit()
    cur.close()
    conn.close()

# 🟢 Função para criar um novo jogador
def criar_jogador(nome, email, password, equipa_id):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        INSERT INTO jogadores (nome, email, password, equipa_id) 
        VALUES (%s, %s, %s, %s)
    """, (nome, email, password, equipa_id))
    conn.commit()
    cur.close()
    conn.close()

# 🟢 Função para criar um novo treinador
def criar_treinador(nome, email, password):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        INSERT INTO treinadores (nome, email, password)
        VALUES (%s, %s, %s)
    """, (nome, email, password))
    conn.commit()
    cur.close()
    conn.close()
    
# ✅ ECG
def guardar_ecg(jogador_id, valor_mv, sessao_id):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        INSERT INTO ecg_dados (jogador_id, valor_mv, timestamp, sessao_id)
        VALUES (%s, %s, NOW(), %s)
    """, (jogador_id, valor_mv, sessao_id))
    conn.commit()
    cur.close()
    conn.close()

# ✅ Sessões    
def atualizar_mac(jogador_id, mac_address):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("UPDATE jogadores SET mac_address = %s WHERE id = %s", (mac_address, jogador_id))
    conn.commit()
    cur.close()
    conn.close()
# 🟢 Função para obter o ID do jogador a partir do MAC address
def obter_jogador_por_mac(mac_address):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT id FROM jogadores WHERE mac_address = %s", (mac_address,))
    jogador = cur.fetchone()
    cur.close()
    conn.close()
    return jogador[0] if jogador else None
# 🟢 Função para obter o MAC address do jogador
def obter_mac_jogador(jogador_id):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT mac_address FROM jogadores WHERE id = %s", (jogador_id,))
    row = cur.fetchone()
    cur.close()
    conn.close()
    return row[0] if row else None