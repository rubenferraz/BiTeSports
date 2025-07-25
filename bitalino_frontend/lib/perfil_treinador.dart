import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
// import 'dart:io';
// import 'package:path_provider/path_provider.dart';
//import 'dart:convert';
import 'package:universal_html/html.dart' as html;

class PerfilTreinadorPage extends StatefulWidget {
  @override
  _PerfilTreinadorPageState createState() => _PerfilTreinadorPageState();
}
// Isto é o código para a página de perfil do treinador, onde ele pode gerir as suas equipas, monitorizar sessões de ECG dos jogadores e visualizar estatísticas.
class _PerfilTreinadorPageState extends State<PerfilTreinadorPage> {
  int _selectedTab = 0;
  List<String> equipas = [];
  String equipaSelecionada = '';
  TextEditingController equipaController = TextEditingController();
  TextEditingController pesquisaController = TextEditingController();
  List<Map<String, dynamic>> jogadoresEquipa = [];
  List<Map<String, dynamic>> jogadoresDisponiveis = [];
  List<Map<String, dynamic>> jogadoresFiltrados = [];
  int? jogadorSelecionadoId;
  int? sessaoSelecionadaId;
  List<Map<String, dynamic>> sessoes = [];
  List<FlSpot> ecgSpots = [];
  List<FlSpot> ecgHistoricoJogador = []; // Histórico total ECG
  bool monitorizar = false;
  Map<int, List<FlSpot>> ecgRealtimePorJogador = {};
  Map<int, WebSocketChannel> canais = {};
  Map<int, double> tempoPorJogador = {};
  Map<int, bool> ecgIniciadoPorJogador = {};
  Map<String, double> formularioValores = {};
  bool formularioCarregado = false;

  double? tempoSessaoMinutos;
  String? resultadoSessao;
// Variáveis para armazenar os dados do ECG e o tempo da sessão
  @override
  void initState() {
    super.initState();
    fetchEquipas();
    fetchJogadoresSemEquipa();
  }
// Método para exportar a sessão selecionada para CSV
  void exportarSessaoParaCSVWeb() {
  if (sessaoSelecionadaId == null || formularioValores.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Seleciona uma sessão com avaliação!')),
    );
    return;
  }

  StringBuffer csv = StringBuffer();
  csv.writeln("Campo,Valor");
  formularioValores.forEach((chave, valor) {
    csv.writeln('$chave,$valor');
  });
  csv.writeln("Resultado,${resultadoSessao ?? 'n/d'}");
  csv.writeln("Tempo de sessão (min),${tempoSessaoMinutos?.toStringAsFixed(1) ?? 'n/d'}");

  // Adiciona os valores do ECG desta sessão
  csv.writeln(""); // linha vazia
  csv.writeln("ECG (amostra),Valor (mV)");
  for (int i = 0; i < ecgSpots.length; i++) {
    csv.writeln("${ecgSpots[i].x.toStringAsFixed(2)},${ecgSpots[i].y.toStringAsFixed(4)}");
  }

  final bytes = utf8.encode(csv.toString());
  final blob = html.Blob([bytes], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', 'sessao_${sessaoSelecionadaId ?? 'desconhecida'}.csv')
    ..click();
  html.Url.revokeObjectUrl(url);
}
// Método para buscar as equipas do treinador logado
  Future<void> fetchEquipas() async {
    final prefs = await SharedPreferences.getInstance();
    final treinadorId = prefs.getInt('id');
    if (treinadorId == null) return;
    final res = await http.get(Uri.parse('http://localhost:5000/equipas/$treinadorId'));
    if (res.statusCode == 200) {
      final List<dynamic> data = json.decode(res.body);
      setState(() {
        equipas = data.map((e) => e['nome'].toString()).toList();
      });
    }
  }


// Método para criar uma nova equipa
  Future<void> criarEquipa() async {
    final prefs = await SharedPreferences.getInstance();
    final treinadorId = prefs.getInt('id');
    if (treinadorId == null) return;
    await http.post(
      Uri.parse('http://localhost:5000/equipas'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'nome': equipaController.text, 'treinador_id': treinadorId}),
    );
    equipaController.clear();
    fetchEquipas();
  }
// Método para eliminar uma equipa
  Future<void> eliminarEquipa(String nomeEquipa) async {
    await http.delete(Uri.parse('http://localhost:5000/equipas/$nomeEquipa'));
    fetchEquipas();
    setState(() {
      equipaSelecionada = '';
      jogadoresEquipa.clear();
    });
  }
// Método para buscar os jogadores de uma equipa específica
  Future<void> fetchJogadoresDaEquipa(String nomeEquipa) async {
    final res = await http.get(Uri.parse('http://localhost:5000/equipas/$nomeEquipa/jogadores'));
    if (res.statusCode == 200) {
      final List<dynamic> data = json.decode(res.body);
      setState(() {
        jogadoresEquipa = data.cast<Map<String, dynamic>>();
      });
    }
  }
// Método para buscar os jogadores que não estão em nenhuma equipa
  Future<void> fetchJogadoresSemEquipa() async {
    final res = await http.get(Uri.parse('http://localhost:5000/jogadores/sem_equipa'));
    if (res.statusCode == 200) {
      final List<dynamic> data = json.decode(res.body);
      setState(() {
        jogadoresDisponiveis = data.cast<Map<String, dynamic>>();
        jogadoresFiltrados = jogadoresDisponiveis;
      });
    }
  }
// Método para filtrar os jogadores disponíveis com base na pesquisa
  void filtrarJogadores(String query) {
    setState(() {
      jogadoresFiltrados = jogadoresDisponiveis
          .where((j) => j['nome'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }
// Método para adicionar um jogador a uma equipa
  Future<void> adicionarJogadorAEquipa(int jogadorId) async {
    if (equipaSelecionada.isEmpty) return;
    await http.post(
      Uri.parse('http://localhost:5000/equipas/$equipaSelecionada/adicionar_jogador'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'jogador_id': jogadorId}),
    );
    fetchJogadoresDaEquipa(equipaSelecionada);
    fetchJogadoresSemEquipa();
    pesquisaController.clear();
    filtrarJogadores('');
  }
// Método para remover um jogador de uma equipa
  Future<void> removerJogadorDaEquipa(int jogadorId) async {
    if (equipaSelecionada.isEmpty) return;
    await http.post(
      Uri.parse('http://localhost:5000/equipas/$equipaSelecionada/remover_jogador'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'jogador_id': jogadorId}),
    );
    fetchJogadoresDaEquipa(equipaSelecionada);
    fetchJogadoresSemEquipa();
  }
// Método para buscar as sessões de ECG de um jogador específico
  Future<void> fetchSessoesDoJogador(int jogadorId) async {
    final res = await http.get(Uri.parse('http://localhost:5000/ecg_sessoes/$jogadorId'));
    if (res.statusCode == 200) {
      final List<dynamic> data = json.decode(res.body);
      final sessoesConvertidas = data.cast<Map<String, dynamic>>();
      setState(() {
        sessoes = sessoesConvertidas;
        if (sessoes.isNotEmpty) {
          sessaoSelecionadaId = sessoes.first['id'];
          var sessao = sessoes.firstWhere((s) => s['id'] == sessaoSelecionadaId, orElse: () => {});
          if (sessao.isNotEmpty && sessao['timestamp_inicio'] != null && sessao['timestamp_fim'] != null) {
            DateTime inicio = DateTime.parse(sessao['timestamp_inicio']);
            DateTime fim = DateTime.parse(sessao['timestamp_fim']);
            tempoSessaoMinutos = fim.difference(inicio).inSeconds / 60.0;
          } else {
            tempoSessaoMinutos = null;
          }
          fetchDadosECG(sessaoSelecionadaId!);
          fetchFormulario(sessaoSelecionadaId!);
        } else {
          ecgSpots = [];
          sessaoSelecionadaId = null;
          tempoSessaoMinutos = null;
        }
      });
    }
  }
// Método para buscar os dados de ECG de uma sessão específica
  Future<void> fetchDadosECG(int sessaoId) async {
    final res = await http.get(Uri.parse('http://localhost:5000/ecg_sessao/$sessaoId'));
    if (res.statusCode == 200) {
      final List<dynamic> dados = json.decode(res.body);
      dados.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
      List<FlSpot> pontos = [];
      for (int i = 0; i < dados.length; i++) {
        double y = (dados[i]['valor_mv'] as num).toDouble();
        pontos.add(FlSpot(i.toDouble(), y.clamp(-2.0, 2.0)));
      }
      setState(() {
        ecgSpots = pontos;
      });
    }
  }

  // NOVA: buscar histórico total ECG do jogador
  Future<void> fetchEcgHistoricoJogador(int jogadorId) async {
    final res = await http.get(Uri.parse('http://localhost:5000/ecg_dados/$jogadorId'));
    if (res.statusCode == 200) {
      final List<dynamic> dados = json.decode(res.body);
      List<FlSpot> pontos = [];
      double t = 0;
      for (var item in dados) {
        double y = (item['valor_mv'] as num).toDouble().clamp(-1.5, 1.5);
        pontos.add(FlSpot(t, y));
        t += 0.01;
      }
      setState(() {
        ecgHistoricoJogador = pontos;
      });
    }
  }
// Método para buscar o formulário de avaliação pós-sessão
  Future<void> fetchFormulario(int sessaoId) async {
    final res = await http.get(Uri.parse('http://localhost:5000/formulario/$sessaoId'));
    if (res.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(res.body);
      final camposRadar = [
        'foco', 'confianca', 'stress', 'controlo',
        'comunicacao', 'colaboracao'
      ];
      setState(() {
        formularioValores = {
          for (var k in camposRadar) k: (data[k] as num).toDouble(),
        };
        resultadoSessao = data['resultado']?.toString() ?? '';
        formularioCarregado = true;
      });
    } else {
      setState(() {
        formularioValores = {};
        resultadoSessao = null;
        formularioCarregado = false;
      });
    }
  }
// Método para iniciar a monitorização de ECG dos jogadores da equipa
  void iniciarMonitorizacaoECG() {
    setState(() => monitorizar = true);
    for (var jogador in jogadoresEquipa) {
      final id = jogador['id'];
      ecgRealtimePorJogador[id] = [];
      tempoPorJogador[id] = 0.0;
      ecgIniciadoPorJogador[id] = false;
      http.post(Uri.parse('http://localhost:5000/iniciar_sessao/$id')).then((res) {
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final sessaoId = data['id'];
          final canal = WebSocketChannel.connect(Uri.parse('ws://localhost:8765'));
          canais[id] = canal;
          canal.sink.add(json.encode({
            "jogador_id": id,
            "sessao_id": sessaoId
          }));
          canal.stream.listen((mensagem) {
            final decoded = json.decode(mensagem);
            final List<dynamic> ecgValues = decoded["ecg"];
            setState(() {
              for (var v in ecgValues) {
                double y = v.toDouble().clamp(-1.5, 1.5);
                ecgIniciadoPorJogador[id] = true;
                ecgRealtimePorJogador[id]!.add(FlSpot(tempoPorJogador[id]!, y));
                tempoPorJogador[id] = tempoPorJogador[id]! + 0.01;
              }
              if (ecgRealtimePorJogador[id]!.length > 500) {
                ecgRealtimePorJogador[id]!.removeRange(0, ecgRealtimePorJogador[id]!.length - 500);
              }
            });
          });
        }
      });
    }
  }
// Método para parar a monitorização de ECG
  void pararMonitorizacaoECG() {
    for (var canal in canais.values) {
      canal.sink.close();
    }
    setState(() {
      monitorizar = false;
      canais.clear();
    });
  }
// Método para verificar se o treinador está logado
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Perfil Treinador'),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sessão terminada')),
              );
            },
          ),
        ],
      ),
      body: DefaultTabController(
        length: 3,
        initialIndex: _selectedTab,
        child: Column(
          children: [
            Material(
              color: Theme.of(context).appBarTheme.backgroundColor ?? Colors.black,
              child: TabBar(
                onTap: (i) => setState(() => _selectedTab = i),
                tabs: [
                  Tab(icon: Icon(Icons.group), text: "Equipas"),
                  Tab(icon: Icon(Icons.bar_chart), text: "Estatísticas"),
                  Tab(icon: Icon(Icons.sports_esports), text: "Sessão de Jogo"),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                physics: NeverScrollableScrollPhysics(),
                children: [
                  _buildGerirEquipasTab(),
                  _buildEstatisticasTab(),
                  _buildSessaoJogoTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
// Método para construir a aba de gestão de equipas
  Widget _buildGerirEquipasTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          Text('Gerir Equipas', style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: equipaController,
                  decoration: InputDecoration(labelText: 'Nome da nova Equipa'),
                ),
              ),
              SizedBox(width: 10),
              ElevatedButton(onPressed: criarEquipa, child: Text('Criar')),
            ],
          ),
          SizedBox(height: 20),
          Text('Equipas existentes:', style: TextStyle(fontWeight: FontWeight.bold)),
          ...equipas.map((nome) => Card(
                color: nome == equipaSelecionada ? Colors.deepPurple[100] : null,
                child: ListTile(
                  title: Text(nome),
                  trailing: IconButton(icon: Icon(Icons.delete), onPressed: () => eliminarEquipa(nome)),
                  onTap: () {
                    setState(() => equipaSelecionada = nome);
                    fetchJogadoresDaEquipa(nome);
                    fetchJogadoresSemEquipa();
                  },
                ),
              )),
          if (equipaSelecionada.isNotEmpty) ...[
            Divider(),
            Text('Jogadores da equipa "$equipaSelecionada":', style: TextStyle(fontWeight: FontWeight.bold)),
            ...jogadoresEquipa.map((j) => Card(
                  child: ListTile(
                    title: Text(j['nome']),
                    trailing: IconButton(
                      icon: Icon(Icons.remove_circle, color: Colors.redAccent),
                      onPressed: () => removerJogadorDaEquipa(j['id']),
                    ),
                  ),
                )),
            Divider(),
            Text('Procurar jogadores sem equipa:', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: pesquisaController,
              onChanged: filtrarJogadores,
              decoration: InputDecoration(
                hintText: 'Pesquisar por nome...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            if (pesquisaController.text.isNotEmpty)
              ...jogadoresFiltrados.map((j) => Card(
                child: ListTile(
                  title: Text(j['nome']),
                  trailing: IconButton(
                    icon: Icon(Icons.add_circle, color: Colors.green),
                    onPressed: () => adicionarJogadorAEquipa(j['id']),
                  ),
                ),
              )),
          ],
        ],
      ),
    );
  }
// Método para construir a aba de estatísticas e ECG
  Widget _buildEstatisticasTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          Text('Estatísticas ECG', style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: 12),
          DropdownButton<int>(
            hint: Text('Seleciona um jogador'),
            value: jogadorSelecionadoId,
            items: jogadoresEquipa.map((j) {
              return DropdownMenuItem<int>(
                value: j['id'],
                child: Text(j['nome']),
              );
            }).toList(),
            onChanged: (novoId) {
              setState(() {
                jogadorSelecionadoId = novoId;
                sessaoSelecionadaId = null;
                ecgSpots = [];
                sessoes = [];
                formularioCarregado = false;
                resultadoSessao = null;
                tempoSessaoMinutos = null;
                ecgHistoricoJogador = [];
              });
              fetchSessoesDoJogador(novoId!);
              fetchEcgHistoricoJogador(novoId); // <-- buscar histórico ao selecionar
            },
          ),
          

          // NOVO: Gráfico histórico de todas as sessões
          if (ecgHistoricoJogador.isNotEmpty)
            Card(
              color: Colors.white10,
              margin: EdgeInsets.only(top: 22, bottom: 22),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Histórico ECG (Todas as Sessões)', style: TextStyle(color: Colors.white70)),
                    SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: LineChart(
                        LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: ecgHistoricoJogador,
                              isCurved: true,
                              dotData: FlDotData(show: false),
                              color: Colors.redAccent,
                              barWidth: 2,
                            )
                          ],
                          titlesData: FlTitlesData(show: false),
                          gridData: FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          minY: -1.5,
                          maxY: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (sessoes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: DropdownButton<int>(
                hint: Text('Seleciona uma sessão'),
                value: sessaoSelecionadaId,
                items: sessoes.map((s) {
                  return DropdownMenuItem<int>(
                    value: s['id'],
                    child: Text("Sessão ${s['id']} - ${s['timestamp']}"),
                  );
                }).toList(),
                onChanged: (sessaoId) {
                  setState(() => sessaoSelecionadaId = sessaoId);
                  fetchDadosECG(sessaoId!);
                  fetchFormulario(sessaoId);
                  var sessao = sessoes.firstWhere((s) => s['id'] == sessaoId, orElse: () => {});
                  if (sessao.isNotEmpty && sessao['timestamp_inicio'] != null && sessao['timestamp_fim'] != null) {
                    DateTime inicio = DateTime.parse(sessao['timestamp_inicio']);
                    DateTime fim = DateTime.parse(sessao['timestamp_fim']);
                    tempoSessaoMinutos = fim.difference(inicio).inSeconds / 60.0;
                  } else {
                    tempoSessaoMinutos = null;
                  }
                },
              ),
            ),
          SizedBox(height: 10),
          if (ecgSpots.isNotEmpty)
            Card(
              color: Colors.white10,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      lineBarsData: [
                        LineChartBarData(
                          spots: ecgSpots,
                          isCurved: false,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(show: false),
                          color: Colors.greenAccent,
                          barWidth: 2,
                        )
                      ],
                      titlesData: FlTitlesData(show: false),
                      gridData: FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
              ),
            ),
            if (jogadorSelecionadoId != null)
  Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            fetchSessoesDoJogador(jogadorSelecionadoId!);
            fetchEcgHistoricoJogador(jogadorSelecionadoId!);
          },
          icon: Icon(Icons.refresh),
          label: Text("Atualizar Sessões"),
        ),
        if (sessaoSelecionadaId != null && formularioCarregado)
          SizedBox(width: 10),
        if (sessaoSelecionadaId != null && formularioCarregado)
          ElevatedButton.icon(
  icon: Icon(Icons.download),
  label: Text('Exportar CSV'),
  onPressed: exportarSessaoParaCSVWeb,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
      ],
    ),
  ),

          if (formularioCarregado)
            Card(
              margin: EdgeInsets.only(top: 32),
              color: Colors.white10,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Avaliação Pós-Sessão', style: Theme.of(context).textTheme.titleMedium),
                    SizedBox(height: 10),
                    SizedBox(
                      height: 200,
                      child: RadarChart(
                        RadarChartData(
                          radarBackgroundColor: Colors.transparent,
                          radarBorderData: BorderSide.none,
                          titleTextStyle: TextStyle(fontSize: 12, color: Colors.white),
                          getTitle: (index, angle) => RadarChartTitle(
                            text: formularioValores.keys.elementAt(index),
                          ),
                          dataSets: [
                            RadarDataSet(
                              dataEntries: formularioValores.values
                                  .map((v) => RadarEntry(value: v))
                                  .toList(),
                              fillColor: Colors.blue.withOpacity(0.4),
                              borderColor: Colors.blueAccent,
                              entryRadius: 3,
                              borderWidth: 2,
                            ),
                          ],
                          tickCount: 4,
                          tickBorderData: BorderSide(color: Colors.grey.shade300),
                          gridBorderData: BorderSide(color: Colors.grey),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Icon(Icons.timer, color: Colors.cyan),
                        SizedBox(width: 8),
                        Text(
                          tempoSessaoMinutos != null
                            ? "Tempo de sessão: ${tempoSessaoMinutos!.toStringAsFixed(1)} min"
                            : "Tempo de sessão: n/d",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          resultadoSessao == 'vitoria'
                            ? Icons.emoji_events
                            : Icons.close,
                          color: resultadoSessao == 'vitoria' ? Colors.amber : Colors.redAccent,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Resultado: ${resultadoSessao?.toUpperCase() ?? 'n/d'}",
                          style: TextStyle(
                            fontSize: 16,
                            color: resultadoSessao == 'vitoria' ? Colors.amber : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
// Método para construir a aba de sessão de jogo
  Widget _buildSessaoJogoTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sessão de Jogo', style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: 12),
          DropdownButton<String>(
            hint: Text('Selecionar Equipa'),
            value: equipaSelecionada.isEmpty ? null : equipaSelecionada,
            items: equipas.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                equipaSelecionada = newValue!;
                fetchJogadoresDaEquipa(newValue);
                fetchJogadoresSemEquipa();
              });
            },
          ),
          Row(
            children: [
              ElevatedButton(
                onPressed: equipaSelecionada.isEmpty || monitorizar ? null : iniciarMonitorizacaoECG,
                child: Text('Iniciar Sessão'),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: monitorizar ? pararMonitorizacaoECG : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Parar Sessão'),
              ),
            ],
          ),
          SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: jogadoresEquipa.length,
              itemBuilder: (context, index) {
                final jogador = jogadoresEquipa[index];
                final id = jogador['id'];
                final nome = jogador['nome'];
                final ecg = ecgRealtimePorJogador[id] ?? [];
                return Card(
                  margin: EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Jogador: $nome', style: TextStyle(fontWeight: FontWeight.bold)),
                        Container(
                          height: 120,
                          margin: EdgeInsets.only(top: 8),
                          child: ecg.isEmpty
                              ? Center(child: Text('Sem dados ainda'))
                              : LineChart(
                                  LineChartData(
                                    minY: -1.5,
                                    maxY: 1.5,
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: ecg,
                                        isCurved: true,
                                        barWidth: 2,
                                        color: Colors.greenAccent,
                                        dotData: FlDotData(show: false),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
