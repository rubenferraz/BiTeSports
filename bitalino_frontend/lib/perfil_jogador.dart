import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'main.dart';
import 'package:fl_chart/fl_chart.dart';
import 'formulario_page.dart';

class PerfilJogadorPage extends StatefulWidget {
  @override
  _PerfilJogadorPageState createState() => _PerfilJogadorPageState();
}
// Este é o código para a página de perfil do jogador
class _PerfilJogadorPageState extends State<PerfilJogadorPage> {
  List<FlSpot> ecgHistorico = [];
  List<FlSpot> ecgTempoReal = [];
  double tempo = 0;
  TextEditingController macController = TextEditingController();
  WebSocketChannel? channel;
  bool sessaoAtiva = false;
  int? sessaoIdAtiva;
  String nomeJogador = '';
  String? emailJogador;
  String? equipaJogador;

  List<dynamic> formularios = [];
  int vitorias = 0;
  int derrotas = 0;
  double ratio = 0;
  double tempoTotal = 0.0;
  Map<String, double> radarData = {};

  final List<String> radarMetricas = [
    'performance', 'foco', 'confianca', 'desempenho_fisico',
    'comunicacao', 'colaboracao', 'controlo',
  ];

  final Map<String, String> radarTitulos = {
    'performance': 'Performance',
    'foco': 'Foco',
    'confianca': 'Confiança',
    'desempenho_fisico': 'Físico',
    'comunicacao': 'Comunicação',
    'colaboracao': 'Colaboração',
    'controlo': 'Controlo',
  };
// NOVO: Adiciona o WebSocketChannel para comunicação em tempo real
  @override
  void initState() {
    super.initState();
    carregarDadosECG();
    carregarMac();
    carregarPerfil();
    carregarEquipa();
    carregarFormularios();
    carregarTempoTotalDasSessoes();
    _verificarSessaoAtivaAoEntrar();
  }

  // NOVO: Verifica automaticamente se há sessão ativa
  Future<void> _verificarSessaoAtivaAoEntrar() async {
    final prefs = await SharedPreferences.getInstance();
    final jogadorId = prefs.getInt('id');
    if (jogadorId == null) return;

    final response = await http.get(Uri.parse('http://localhost:5000/ecg_sessoes/$jogadorId'));
    if (response.statusCode == 200) {
      final List<dynamic> sessoes = json.decode(response.body);
      if (sessoes.isNotEmpty) {
        final sessao = sessoes.first;
        if (sessao['timestamp_fim'] == null) {
          sessaoIdAtiva = sessao['id'];
          _iniciarLigacaoWebSocket(sessao['id'], jogadorId);
          setState(() {
            sessaoAtiva = true;
          });
        }
      }
    }
  }

  // NOVO: Inicia ligação WebSocket a uma sessão já ativa
  void _iniciarLigacaoWebSocket(int sessaoId, int jogadorId) {
    channel = WebSocketChannel.connect(Uri.parse('ws://localhost:8765'));
    channel!.sink.add(json.encode({
      "jogador_id": jogadorId,
      "sessao_id": sessaoId
    }));

    setState(() {
      ecgTempoReal.clear();
      tempo = 0;
    });

    channel!.stream.listen((mensagem) {
      final decoded = json.decode(mensagem);
      final List<dynamic> ecgValues = decoded["ecg"];
      setState(() {
        for (var value in ecgValues) {
          double y = value.toDouble().clamp(-1.5, 1.5);
          ecgTempoReal.add(FlSpot(tempo, y));
          tempo += 0.01;
        }
        if (ecgTempoReal.length > 5000) {
          ecgTempoReal.removeRange(0, ecgTempoReal.length - 10000);
        }
      });
    });
  }
// Carrega o perfil do jogador a partir das preferências
  Future<void> carregarPerfil() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      nomeJogador = prefs.getString('nome') ?? '';
      emailJogador = prefs.getString('email');
    });
  }

  Future<void> carregarTempoTotalDasSessoes() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('id');
    if (id == null) return;

    final response = await http.get(Uri.parse('http://localhost:5000/sessoes/$id'));
    if (response.statusCode == 200) {
      final List<dynamic> lista = json.decode(response.body);
      setState(() {
        tempoTotal = lista.fold<double>(
          0,
          (soma, s) => soma + (s['duracao'] != null ? s['duracao'].toDouble() : 0),
        );
      });
    }
  }
// Carrega a equipa do jogador a partir do servidor
  Future<void> carregarEquipa() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('id');
    if (id == null) return;

    final res = await http.get(Uri.parse('http://localhost:5000/jogadores/$id/equipa'));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      setState(() {
        equipaJogador = data['nome_equipa'];
      });
    } else {
      setState(() {
        equipaJogador = null;
      });
    }
  }
// Carrega os dados do ECG do jogador a partir do servidor
  Future<void> carregarDadosECG() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('id');
    if (id == null) return;

    final response = await http.get(Uri.parse('http://localhost:5000/ecg_dados/$id'));
    if (response.statusCode == 200) {
      final List<dynamic> dados = json.decode(response.body);
      final List<FlSpot> pontos = [];
      double t = 0;
      for (var item in dados) {
        double y = item['valor_mv'].toDouble().clamp(-1.5, 1.5);
        pontos.add(FlSpot(t, y));
        t += 0.01;
      }
      setState(() => ecgHistorico = pontos);
    }
  }
// Carrega os formulários do jogador a partir do servidor
  Future<void> carregarFormularios() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('id');
    if (id == null) return;

    final response = await http.get(Uri.parse('http://localhost:5000/formularios/$id'));
    if (response.statusCode == 200) {
      final List<dynamic> lista = json.decode(response.body);
      setState(() {
        formularios = lista;

        vitorias = lista.where((f) => f['resultado'] == 'vitoria').length;
        derrotas = lista.where((f) => f['resultado'] == 'derrota').length;

        ratio = derrotas > 0 ? vitorias / derrotas : (vitorias > 0 ? vitorias.toDouble() : 0);

        tempoTotal = lista.fold<double>(
          0,
          (soma, f) => soma + (f['duracao'] != null ? f['duracao'].toDouble() : 0),
        );

        radarData = {};
        if (lista.isNotEmpty) {
          for (var metrica in radarMetricas) {
            radarData[metrica] = lista.map((f) => (f[metrica] ?? 0) * 1.0).reduce((a, b) => a + b) / lista.length;
          }
        } else {
          for (var metrica in radarMetricas) {
            radarData[metrica] = 0;
          }
        }
      });
    }
  }
// Guarda o MAC do BITalino no servidor
  Future<void> guardarMac() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('id');
    if (id == null) return;

    await http.post(
      Uri.parse('http://localhost:5000/jogadores/$id/mac'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'mac_address': macController.text}),
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('MAC guardado com sucesso.')));
  }
// Carrega o MAC do BITalino do servidor
  Future<void> carregarMac() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('id');
    if (id == null) return;

    final res = await http.get(Uri.parse('http://localhost:5000/jogadores/$id/mac'));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      setState(() => macController.text = data['mac_address'] ?? '');
    }
  }

  Future<int?> _getUltimaSessaoId() async {
    final prefs = await SharedPreferences.getInstance();
    final jogadorId = prefs.getInt('id');
    if (jogadorId == null) return null;

    final response = await http.get(Uri.parse('http://localhost:5000/ecg_sessoes/$jogadorId'));
    if (response.statusCode == 200) {
      final List<dynamic> sessoes = json.decode(response.body);
      if (sessoes.isNotEmpty) {
        return sessoes.first['id'];
      }
    }
    return null;
  }
// Inicia ou para a sessão de ECG
  Future<void> iniciarOuPararSessaoECG() async {
    if (sessaoAtiva) {
      channel?.sink.close();

      final ultimoSessaoId = await _getUltimaSessaoId();

      if (ultimoSessaoId != null) {
        await http.post(Uri.parse('http://localhost:5000/terminar_sessao/$ultimoSessaoId'));
      }

      setState(() {
        sessaoAtiva = false;
        channel = null;
        ecgTempoReal.clear();
        tempo = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sessão terminada.')));

      if (ultimoSessaoId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FormularioPage(sessaoId: ultimoSessaoId)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível encontrar a sessão para associar ao formulário.')),
        );
      }
      return;
    }
// Inicia uma nova sessão de ECG
    final prefs = await SharedPreferences.getInstance();
    final jogadorId = prefs.getInt('id');
    if (jogadorId == null) return;

    final response = await http.post(Uri.parse('http://localhost:5000/iniciar_sessao/$jogadorId'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final sessaoId = data['id'];

      channel = WebSocketChannel.connect(Uri.parse('ws://localhost:8765'));

      channel!.sink.add(json.encode({
        "jogador_id": jogadorId,
        "sessao_id": sessaoId
      }));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sessão iniciada com sucesso.')),
      );

      setState(() {
        sessaoAtiva = true;
        ecgTempoReal.clear();
        tempo = 0;
      });

      channel!.stream.listen((mensagem) {
        final decoded = json.decode(mensagem);
        final List<dynamic> ecgValues = decoded["ecg"];

        setState(() {
          for (var value in ecgValues) {
            double y = value.toDouble().clamp(-1.5, 1.5);
            ecgTempoReal.add(FlSpot(tempo, y));
            tempo += 0.01;
          }

          if (ecgTempoReal.length > 1000) {
            ecgTempoReal.removeRange(0, ecgTempoReal.length - 1000);
          }
        });
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao iniciar sessão.')),
      );
    }
  }
// Guarda o MAC do BITalino no servidor
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Perfil Jogador'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => HomePage()),
                (route) => false,
              );
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sessão terminada')));
            },
          ),
        ],
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Material(
              color: Theme.of(context).appBarTheme.backgroundColor ?? Colors.black,
              child: TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.play_circle_outline), text: "Sessão ECG"),
                  Tab(icon: Icon(Icons.bar_chart), text: "Estatística"),
                  Tab(icon: Icon(Icons.person), text: "Perfil"),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Sessão em tempo real
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          icon: Icon(sessaoAtiva ? Icons.stop : Icons.play_arrow),
                          label: Text(sessaoAtiva ? "Parar Sessão ECG" : "Iniciar Sessão ECG"),
                          onPressed: iniciarOuPararSessaoECG,
                        ),
                        SizedBox(height: 16),
                        Container(
                          height: 300,
                          width: double.infinity,
                          child: ecgTempoReal.isEmpty
                              ? Center(child: Text(''))
                              : LineChart(
                                  LineChartData(
                                    minY: -1.5,
                                    maxY: 1.5,
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: ecgTempoReal,
                                        isCurved: true,
                                        barWidth: 2,
                                        dotData: FlDotData(show: false),
                                        color: Colors.greenAccent,
                                        belowBarData: BarAreaData(show: false),
                                      ),
                                    ],
                                    titlesData: FlTitlesData(show: false),
                                    gridData: FlGridData(show: false),
                                    borderData: FlBorderData(show: false),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  // Tab 2: Estatística (igual)
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: ListView(
                      children: [
                        Text('Estatística de Sessões', style: Theme.of(context).textTheme.titleLarge),
                        SizedBox(height: 10),
                        Container(
                          height: 200,
                          width: double.infinity,
                          child: ecgHistorico.isEmpty
                              ? Center(child: Text('Sem dados de ECG guardados', style: TextStyle(color: Colors.white)))
                              : LineChart(
                                  LineChartData(
                                    backgroundColor: Colors.grey[850],
                                    minX: 0,
                                    maxX: ecgHistorico.isEmpty ? 1 : ecgHistorico.last.x,
                                    minY: -1.5,
                                    maxY: 1.5,
                                    gridData: FlGridData(show: false),
                                    borderData: FlBorderData(
                                      show: true,
                                      border: Border(
                                        bottom: BorderSide(color: Colors.white, width: 2),
                                        left: BorderSide(color: Colors.white, width: 2),
                                      ),
                                    ),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: ecgHistorico,
                                        isCurved: true,
                                        barWidth: 3,
                                        dotData: FlDotData(show: false),
                                        gradient: LinearGradient(
                                          colors: [Colors.redAccent, Colors.red.shade700],
                                        ),
                                      ),
                                    ],
                                    titlesData: FlTitlesData(show: false),
                                  ),
                                ),
                        ),
                        SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Card(
                                color: Colors.grey[900],
                                elevation: 3,
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      Text('Médias do Formulário', style: TextStyle(color: Colors.white)),
                                      SizedBox(height: 16),
                                      SizedBox(
                                        height: 360,
                                        child: RadarChart(
                                          RadarChartData(
                                            radarBorderData: BorderSide.none,
                                            dataSets: [
                                              RadarDataSet(
                                                dataEntries: radarMetricas
                                                    .map((m) => RadarEntry(value: radarData[m] ?? 0))
                                                    .toList(),
                                                fillColor: Colors.deepPurpleAccent.withOpacity(0.5),
                                                borderColor: Colors.deepPurple,
                                                entryRadius: 2.5,
                                                borderWidth: 2,
                                              ),
                                            ],
                                            radarShape: RadarShape.polygon,
                                            getTitle: (index, _) => RadarChartTitle(
                                              text: radarTitulos[radarMetricas[index]] ?? '',
                                            ),
                                            tickCount: 5,
                                            ticksTextStyle: TextStyle(color: Colors.white38, fontSize: 10),
                                            tickBorderData: BorderSide(color: Colors.deepPurpleAccent, width: 0.7),
                                            gridBorderData: BorderSide(color: Colors.white12, width: 0.5),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 18),
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  Card(
                                    color: Colors.black87,
                                    child: Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.emoji_events, color: Colors.amber),
                                              SizedBox(width: 8),
                                              Text("Vitórias:", style: TextStyle(color: Colors.white)),
                                              SizedBox(width: 4),
                                              Text(vitorias.toString(), style: TextStyle(fontSize: 20, color: Colors.greenAccent)),
                                              SizedBox(width: 16),
                                              Icon(Icons.cancel, color: Colors.redAccent, size: 24),
                                              SizedBox(width: 4),
                                              Text("Derrotas:", style: TextStyle(color: Colors.white)),
                                              SizedBox(width: 4),
                                              Text(derrotas.toString(), style: TextStyle(fontSize: 20, color: Colors.redAccent)),
                                            ],
                                          ),
                                          SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(Icons.percent, color: Colors.blueAccent, size: 20),
                                              SizedBox(width: 6),
                                              Text(
                                                "Ratio (Vit/Der): ",
                                                style: TextStyle(color: Colors.white70, fontSize: 15),
                                              ),
                                              Text(
                                                derrotas > 0 ? ratio.toStringAsFixed(2) : "N/A",
                                                style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 18),
                                  Card(
                                    color: Colors.black87,
                                    child: ListTile(
                                      leading: Icon(Icons.timer, color: Colors.cyan),
                                      title: Text("Tempo total de jogo", style: TextStyle(color: Colors.white)),
                                      trailing: Text("${tempoTotal.toStringAsFixed(0)} min", style: TextStyle(fontSize: 20, color: Colors.white)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Tab 3: Perfil
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: ListView(
                      children: [
                        Icon(Icons.account_circle, size: 80, color: Colors.deepPurpleAccent),
                        SizedBox(height: 20),
                        Text(
                          nomeJogador.isNotEmpty ? nomeJogador : 'Jogador',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        if (emailJogador != null) ...[
                          SizedBox(height: 6),
                          Text(
                            emailJogador!,
                            style: TextStyle(fontSize: 18, color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (equipaJogador != null && equipaJogador!.isNotEmpty) ...[
                          SizedBox(height: 6),
                          Text(
                            'Equipa: $equipaJogador',
                            style: TextStyle(fontSize: 18, color: Colors.blue[200]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        SizedBox(height: 30),
                        Text("MAC do BITalino", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 6),
                        TextField(
                          controller: macController,
                          decoration: InputDecoration(
                            labelText: 'MAC do BITalino',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 8),
                        ElevatedButton(onPressed: guardarMac, child: Text('Guardar MAC')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
