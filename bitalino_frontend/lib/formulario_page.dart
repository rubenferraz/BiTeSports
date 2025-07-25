import 'package:bitalino_frontend/perfil_jogador.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'main.dart';
// Importa as bibliotecas necessárias para a página de formulário
class FormularioPage extends StatefulWidget {
  final int sessaoId;
  FormularioPage({required this.sessaoId});

  @override
  _FormularioPageState createState() => _FormularioPageState();
}

// Esta página permite ao jogador submeter um formulário de feedback após uma sessão de jogo.
class _FormularioPageState extends State<FormularioPage> {
  double performance = 5;
  double foco = 5;
  double confianca = 5;
  double desempenhoFisico = 5;
  double cansacoMental = 5;
  double stress = 5;
  double controlo = 5;
  double comunicacao = 5;
  double colaboracao = 5;
  double desconforto = 5;
  double confortoSensor = 5;
  double utilidade = 5;

  String? resultadoSelecionado;
// Variável para armazenar o resultado da partida (Vitória ou Derrota)
  Future<void> submeterFormulario() async {
    final prefs = await SharedPreferences.getInstance();
    final jogadorId = prefs.getInt('id');

    if (jogadorId == null || resultadoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Preenche todos os campos antes de submeter.')),
      );
      return;
    }
// Verifica se o jogador está autenticado e se o resultado foi selecionado
    final response = await http.post(
      Uri.parse('http://localhost:5000/formulario'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sessao_id': widget.sessaoId,
        'jogador_id': jogadorId,
        'resultado': resultadoSelecionado,
        'performance': performance.round(),
        'foco': foco.round(),
        'confianca': confianca.round(),
        'desempenho_fisico': desempenhoFisico.round(),
        'cansaco_mental': cansacoMental.round(),
        'stress': stress.round(),
        'controlo': controlo.round(),
        'comunicacao': comunicacao.round(),
        'colaboracao': colaboracao.round(),
        'desconforto': desconforto.round(),
        'conforto_sensor': confortoSensor.round(),
        'utilidade': utilidade.round(),
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Formulário submetido com sucesso!')),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => PerfilJogadorPage()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erro ao submeter formulário.')),
      );
    }
  }
// Função para submeter o formulário de feedback
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Formulário Pós-Sessão')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Text(
              '📊 Avalia a tua performance de 0 a 10 após a sessão:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),

            _secao("📋 Secção 1: Performance Individual"),
            _slider("Performance Geral", performance, (v) => performance = v, "Avaliação geral do teu desempenho."),
            _slider("Foco", foco, (v) => foco = v, "Sentiste-te focado durante o jogo?"),
            _dropdownResultado(),
            _slider("Confiança", confianca, (v) => confianca = v, "Confiança durante a partida."),
            _slider("Desempenho Físico", desempenhoFisico, (v) => desempenhoFisico = v, "Coordenação, reflexos, tempo de reação."),

            _secao("🧠 Secção 2: Estado Mental e Emocional"),
            _slider("Cansaço Mental", cansacoMental, (v) => cansacoMental = v, "Nível de fadiga cognitiva."),
            _slider("Stress / Frustração", stress, (v) => stress = v, "Sentiste stress ou frustração?"),
            _slider("Controlo da Situação", controlo, (v) => controlo = v, "Sentiste-te no controlo da partida?"),

            _secao("🤝 Secção 3: Comunicação e Equipa"),
            _slider("Comunicação", comunicacao, (v) => comunicacao = v, "Comunicação eficaz com a equipa."),
            _slider("Colaboração", colaboracao, (v) => colaboracao = v, "Trabalho em equipa e apoio mútuo."),

            _secao("🧪 Secção 4: Feedback sobre o Sistema"),
            _slider("Desconforto com o BITalino", desconforto, (v) => desconforto = v, "Avalia o desconforto sentido com o equipamento."),
            _slider("Conforto do Sensor", confortoSensor, (v) => confortoSensor = v, "Sentiste o sensor confortável?"),
            _slider("Utilidade da Monitorização", utilidade, (v) => utilidade = v, "A monitorização dos dados foi útil?"),

            SizedBox(height: 30),
            Center(
              child: ElevatedButton.icon(
                icon: Icon(Icons.send),
                label: Text("Submeter"),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  textStyle: TextStyle(fontSize: 18),
                ),
                onPressed: submeterFormulario,
              ),
            ),
          ],
        ),
      ),
    );
  }
// Função para construir um slider com rótulo e descrição
  // Cada slider permite ao jogador avaliar diferentes aspectos da sua performance e experiência durante a sessão de jogo.
  Widget _slider(String label, double value, Function(double) onChanged, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 18),
        Text('$label: ${value.round()}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        Text(desc, style: TextStyle(fontSize: 13, color: Colors.white70)),
        Slider(
          value: value,
          min: 0,
          max: 10,
          divisions: 10,
          label: value.round().toString(),
          onChanged: (v) => setState(() => onChanged(v)),
        ),
      ],
    );
  }
// Função para construir uma secção com título
  Widget _secao(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        titulo,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }
// Função para construir o dropdown de resultado da partida
  Widget _dropdownResultado() {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Resultado da Partida:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          DropdownButton<String>(
            value: resultadoSelecionado,
            hint: Text("Seleciona: Vitória ou Derrota"),
            items: [
              DropdownMenuItem(value: "vitoria", child: Text("Vitória")),
              DropdownMenuItem(value: "derrota", child: Text("Derrota")),
            ],
            onChanged: (val) {
              setState(() {
                resultadoSelecionado = val;
              });
            },
          ),
        ],
      ),
    );
  }
}
