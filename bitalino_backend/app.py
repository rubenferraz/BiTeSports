from flask import Flask, request, jsonify
from db import criar_jogador, criar_treinador, guardar_formulario, get_connection
from flask_cors import CORS
from datetime import datetime


app = Flask(__name__)
CORS(app)

# 🟢 Registo
@app.route('/registar', methods=['POST'])
def registar():
    data = request.get_json()
    nome = data.get('nome')
    email = data.get('email')
    password = data.get('password')
    tipo = data.get('tipo')

    if not all([nome, email, password, tipo]):
        return jsonify({'erro': 'Faltam campos'}), 400

    try:
        if tipo == 'Treinador':
            criar_treinador(nome, email, password)
        elif tipo == 'Jogador':
            criar_jogador(nome, email, password, equipa_id=None)
        else:
            return jsonify({'erro': 'Tipo inválido'}), 400

        return jsonify({'mensagem': 'Registo concluído'}), 200

    except Exception as e:
        return jsonify({'erro': str(e)}), 500

# 🟢 Login
@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')

    if not all([email, password]):
        return jsonify({'erro': 'Campos em falta'}), 400

    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT id FROM treinadores WHERE email=%s AND password=%s", (email, password))
    treinador = cur.fetchone()

    jogador = None
    if not treinador:
        cur.execute("SELECT id FROM jogadores WHERE email=%s AND password=%s", (email, password))
        jogador = cur.fetchone()

    cur.close()
    conn.close()

    if treinador:
        return jsonify({'mensagem': 'Login válido', 'tipo': 'treinador', 'id': treinador[0]}), 200
    elif jogador:
        return jsonify({'mensagem': 'Login válido', 'tipo': 'jogador', 'id': jogador[0]}), 200
    else:
        return jsonify({'erro': 'Credenciais inválidas'}), 401

# 🟢 ECG por jogador
@app.route('/ecg_dados/<int:jogador_id>', methods=['GET'])
def ecg_dados_por_jogador(jogador_id):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT timestamp, valor_mv
        FROM ecg_dados
        WHERE jogador_id = %s
        ORDER BY timestamp ASC
    """, (jogador_id,))
    rows = cur.fetchall()
    cur.close()
    conn.close()
    dados = [{'timestamp': row[0], 'valor_mv': row[1]} for row in rows]
    return jsonify(dados)

# ✅ Formulário
@app.route('/formulario', methods=['POST'])
def guardar_formulario_route():
    data = request.get_json()
    required = [
        'sessao_id', 'jogador_id', 'resultado', 'performance', 'foco', 'confianca',
        'desempenho_fisico', 'cansaco_mental', 'stress', 'controlo',
        'comunicacao', 'colaboracao', 'desconforto', 'conforto_sensor', 'utilidade'
    ]
    if not all(k in data for k in required):
        return jsonify({'erro': 'Faltam campos'}), 400

    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO formularios (
                sessao_id, jogador_id, resultado, performance, foco, confianca,
                desempenho_fisico, cansaco_mental, stress, controlo,
                comunicacao, colaboracao, desconforto, conforto_sensor, utilidade, timestamp
            ) VALUES (
                %s, %s, %s, %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s, %s, %s, %s, %s
            )
        """, (
            data['sessao_id'], data['jogador_id'], data['resultado'], data['performance'], data['foco'], data['confianca'],
            data['desempenho_fisico'], data['cansaco_mental'], data['stress'], data['controlo'],
            data['comunicacao'], data['colaboracao'], data['desconforto'], data['conforto_sensor'], data['utilidade'],
            datetime.now()
        ))
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({'mensagem': 'Formulário guardado'}), 200
    except Exception as e:
        return jsonify({'erro': str(e)}), 500
    
# 🟢 Obter formulário por sessão
@app.route('/formulario/<int:sessao_id>', methods=['GET'])
def obter_formulario_por_sessao(sessao_id):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT * FROM formularios WHERE sessao_id = %s", (sessao_id,))
    row = cur.fetchone()
    colnames = [desc[0] for desc in cur.description]
    cur.close()
    conn.close()
    if row:
        dados = dict(zip(colnames, row))
        if 'timestamp' in dados and dados['timestamp'] is not None:
            dados['timestamp'] = str(dados['timestamp'])
        return jsonify(dados), 200
    else:
        return jsonify({'erro': 'Formulário não encontrado'}), 404





# 🟢 Equipas de um treinador
@app.route('/equipas/<int:treinador_id>', methods=['GET'])
def listar_equipas(treinador_id):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT id, nome FROM equipas WHERE treinador_id = %s", (treinador_id,))
    equipas = [{'id': row[0], 'nome': row[1]} for row in cur.fetchall()]
    cur.close()
    conn.close()
    return jsonify(equipas), 200

# 🟢 Criar equipa
@app.route('/equipas', methods=['POST'])
def criar_equipa():
    data = request.get_json()
    nome = data.get('nome')
    treinador_id = data.get('treinador_id')

    if not nome or not treinador_id:
        return jsonify({'erro': 'Faltam dados'}), 400

    conn = get_connection()
    cur = conn.cursor()
    cur.execute("INSERT INTO equipas (nome, treinador_id) VALUES (%s, %s)", (nome, treinador_id))
    conn.commit()
    cur.close()
    conn.close()
    return jsonify({'mensagem': 'Equipa criada com sucesso'}), 201

# 🟢 Eliminar equipa
@app.route('/equipas/<string:nome>', methods=['DELETE'])
def eliminar_equipa(nome):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("DELETE FROM equipas WHERE nome = %s", (nome,))
    conn.commit()
    cur.close()
    conn.close()
    return jsonify({'mensagem': 'Equipa eliminada'}), 200

# 🟢 Jogadores de uma equipa (por ID)
@app.route('/equipas/<int:equipa_id>/jogadores', methods=['GET'])
def jogadores_da_equipa(equipa_id):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT id, nome, email
        FROM jogadores
        WHERE equipa_id = %s
    """, (equipa_id,))
    jogadores = [{'id': row[0], 'nome': row[1], 'email': row[2]} for row in cur.fetchall()]
    cur.close()
    conn.close()
    return jsonify(jogadores), 200

# 🟢 Jogadores de uma equipa (por nome)
@app.route('/equipas/<string:nome_equipa>/jogadores', methods=['GET'])
def jogadores_por_equipa(nome_equipa):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT jogadores.id, jogadores.nome FROM jogadores
        JOIN equipas ON jogadores.equipa_id = equipas.id
        WHERE equipas.nome = %s
    """, (nome_equipa,))
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([{'id': row[0], 'nome': row[1]} for row in rows])

# 🟢 Jogadores sem equipa
@app.route('/jogadores/sem_equipa', methods=['GET'])
def jogadores_sem_equipa():
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT id, nome FROM jogadores WHERE equipa_id IS NULL")
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([{'id': r[0], 'nome': r[1]} for r in rows])

# 🟢 Adicionar jogador a equipa (por nome)
@app.route('/equipas/<string:nome_equipa>/adicionar_jogador', methods=['POST'])
def adicionar_jogador(nome_equipa):
    data = request.get_json()
    jogador_id = data.get('jogador_id')
    if not jogador_id:
        return jsonify({'erro': 'Falta o jogador_id'}), 400

    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT id FROM equipas WHERE nome = %s", (nome_equipa,))
    equipa = cur.fetchone()
    if not equipa:
        return jsonify({'erro': 'Equipa não encontrada'}), 404

    cur.execute("UPDATE jogadores SET equipa_id = %s WHERE id = %s", (equipa[0], jogador_id))
    conn.commit()
    cur.close()
    conn.close()
    return jsonify({'mensagem': 'Jogador adicionado à equipa'})

# 🟢 Remover jogador de equipa (por nome da equipa)
@app.route('/equipas/<string:nome_equipa>/remover_jogador', methods=['POST'])
def remover_jogador(nome_equipa):
    data = request.get_json()
    jogador_id = data.get('jogador_id')
    if not jogador_id:
        return jsonify({'erro': 'Falta o jogador_id'}), 400

    conn = get_connection()
    cur = conn.cursor()
    cur.execute("UPDATE jogadores SET equipa_id = NULL WHERE id = %s", (jogador_id,))
    conn.commit()
    cur.close()
    conn.close()
    return jsonify({'mensagem': 'Jogador removido da equipa'})
# 🟢 Obter MAC de um jogador
@app.route('/jogadores/<int:jogador_id>/mac', methods=['GET'])
def obter_mac(jogador_id):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT mac_address FROM jogadores WHERE id = %s", (jogador_id,))
    row = cur.fetchone()
    cur.close()
    conn.close()
    if row is not None:
        return jsonify({'mac_address': row[0] if row[0] is not None else ""}), 200
    else:
        return jsonify({'erro': 'Jogador não encontrado'}), 404



# 🟢 Iniciar sessão de ECG
@app.route('/iniciar_sessao/<int:jogador_id>', methods=['POST'])
def iniciar_sessao(jogador_id):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("INSERT INTO sessoes (jogador_id) VALUES (%s) RETURNING id, timestamp_inicio", (jogador_id,))
    sessao = cur.fetchone()
    conn.commit()
    cur.close()
    conn.close()
    return jsonify({'id': sessao[0], 'timestamp': sessao[1].isoformat()})


# 🟢 Listar sessões de um jogador
@app.route('/ecg_sessoes/<int:jogador_id>', methods=['GET'])
def listar_sessoes(jogador_id):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT id, timestamp_inicio, timestamp_fim
        FROM sessoes
        WHERE jogador_id = %s
        ORDER BY timestamp_inicio DESC
    """, (jogador_id,))
    sessoes = []
    for row in cur.fetchall():
        sessoes.append({
            "id": row[0],
            "timestamp_inicio": row[1].isoformat() if row[1] else None,
            "timestamp_fim": row[2].isoformat() if row[2] else None
        })
    cur.close()
    conn.close()
    return jsonify(sessoes)



# 🟢 Obter dados de ECG de uma sessão específica
@app.route('/ecg_sessao/<int:sessao_id>', methods=['GET'])
def obter_dados_sessao(sessao_id):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT valor_mv, timestamp
        FROM ecg_dados
        WHERE sessao_id = %s
        ORDER BY timestamp ASC
    """, (sessao_id,))
    dados = [{"valor_mv": row[0], "timestamp": row[1].isoformat()} for row in cur.fetchall()]
    cur.close()
    conn.close()

    if not dados:
        return jsonify({"erro": "Sem dados para esta sessão"}), 404

    return jsonify(dados)
@app.route('/jogadores/<int:jogador_id>/equipa', methods=['GET'])
def obter_equipa_do_jogador(jogador_id):
    conn = get_connection()
    cur = conn.cursor()
    # Vai buscar o equipa_id do jogador
    cur.execute("SELECT equipa_id FROM jogadores WHERE id = %s", (jogador_id,))
    row = cur.fetchone()
    if not row or not row[0]:
        cur.close()
        conn.close()
        return jsonify({'nome_equipa': None}), 200  # Mostra None se não tiver equipa

    equipa_id = row[0]
    cur.execute("SELECT nome FROM equipas WHERE id = %s", (equipa_id,))
    equipa_row = cur.fetchone()
    cur.close()
    conn.close()
    if equipa_row:
        return jsonify({'nome_equipa': equipa_row[0]}), 200
    else:
        return jsonify({'nome_equipa': None}), 200

# 🟢 Listar formulários de um jogador
@app.route('/formularios/<int:jogador_id>', methods=['GET'])
def listar_formularios_jogador(jogador_id):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT resultado, performance, foco, confianca, desempenho_fisico,
               cansaco_mental, stress, controlo, comunicacao, colaboracao,
               desconforto, conforto_sensor, utilidade, timestamp
        FROM formularios
        WHERE jogador_id = %s
    """, (jogador_id,))
    rows = cur.fetchall()
    cur.close()
    conn.close()
    lista = []
    for row in rows:
        lista.append({
            'resultado': row[0],
            'performance': row[1],
            'foco': row[2],
            'confianca': row[3],
            'desempenho_fisico': row[4],
            'cansaco_mental': row[5],
            'stress': row[6],
            'controlo': row[7],
            'comunicacao': row[8],
            'colaboracao': row[9],
            'desconforto': row[10],
            'conforto_sensor': row[11],
            'utilidade': row[12],
            'timestamp': str(row[13])
        })
    return jsonify(lista), 200



# 🟢 Listar sessões de um jogador com duração
@app.route('/sessoes/<int:jogador_id>', methods=['GET'])
def listar_sessoes_com_duracao(jogador_id):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT id, timestamp_inicio, timestamp_fim
        FROM sessoes
        WHERE jogador_id = %s AND timestamp_fim IS NOT NULL
    """, (jogador_id,))
    rows = cur.fetchall()
    cur.close()
    conn.close()
    lista = []
    for row in rows:
        inicio = row[1]
        fim = row[2]
        if inicio and fim:
            duracao = (fim - inicio).total_seconds() / 60.0
        else:
            duracao = 0
        lista.append({'id': row[0], 'inicio': str(inicio), 'fim': str(fim), 'duracao': duracao})
    return jsonify(lista), 200


from datetime import datetime
# 🟢 Terminar sessão de ECG
@app.route('/terminar_sessao/<int:sessao_id>', methods=['POST'])
def terminar_sessao(sessao_id):
    conn = get_connection()
    cur = conn.cursor()
    # Só marca o fim, não mexe em mais nada!
    cur.execute("UPDATE sessoes SET timestamp_fim = %s WHERE id = %s", (datetime.now(), sessao_id))
    conn.commit()
    cur.close()
    conn.close()
    return jsonify({'mensagem': 'Sessão terminada'}), 200




# Run
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
