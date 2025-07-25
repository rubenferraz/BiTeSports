import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'perfil_treinador.dart';
import 'perfil_jogador.dart';
import 'registo_page.dart';
import 'login_page.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final tipo = prefs.getString('tipo');
  runApp(ECGApp(tipoSessao: tipo));
}
// Esta função inicializa o aplicativo e verifica o tipo de sessão do utilizador
class ECGApp extends StatelessWidget {
  final String? tipoSessao;

  const ECGApp({this.tipoSessao});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECG em Tempo Real',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: tipoSessao == 'treinador'
          ? PerfilTreinadorPage()
          : tipoSessao == 'jogador'
              ? PerfilJogadorPage()
              : HomePage(),
    );
  }
}
// Esta classe representa a página inicial da aplicação, onde são exibidas imagens e informações sobre o BiTeSports
class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<List<String>> imageGroups = [
    ['assets/esp5.png', 'assets/esp3.png', 'assets/esp6.png'],
    ['assets/esp1.png', 'assets/esp8.png', 'assets/esp7.png'],
    ['assets/esp2.png', 'assets/esp4.png', 'assets/esp9.png'],
  ];

  int currentIndex1 = 0;
  int currentIndex2 = 0;
  int currentIndex3 = 0;
// Estes índices controlam qual imagem está atualmente visível em cada grupo
  @override
  void initState() {
    super.initState();

    Timer.periodic(Duration(seconds: 15), (timer) {
      setState(() => currentIndex1 = (currentIndex1 + 1) % imageGroups[0].length);
    });
    Timer(Duration(seconds: 5), () {
      Timer.periodic(Duration(seconds: 15), (timer) {
        setState(() => currentIndex2 = (currentIndex2 + 1) % imageGroups[1].length);
      });
    });
    Timer(Duration(seconds: 10), () {
      Timer.periodic(Duration(seconds: 15), (timer) {
        setState(() => currentIndex3 = (currentIndex3 + 1) % imageGroups[2].length);
      });
    });
  }
// Estes timers alternam as imagens a cada 15 segundos, com um atraso inicial para cada grupo
  Widget _buildImageSwitcher(String imagePath) {
    return AnimatedSwitcher(
      duration: Duration(seconds: 1),
      child: Image.asset(
        imagePath,
        key: ValueKey(imagePath),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
// Esta função constrói um widget de cartão para exibir as funcionalidades do BiTeSports
  Widget _buildFeatureCard(IconData icon, String title, String desc) {
    return Container(
      width: 170,
      margin: EdgeInsets.symmetric(horizontal: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 6)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: Colors.deepPurpleAccent),
          SizedBox(height: 10),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
          SizedBox(height: 7),
          Text(desc, style: TextStyle(fontSize: 12, color: Colors.white70), textAlign: TextAlign.center),
        ],
      ),
    );
  }
// Este método constrói a interface do utilizador da página inicial, incluindo o cabeçalho, imagens e cartões de funcionalidades
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.7),
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logobit.png',
              height: 62, // Altura do logo
            ),
            SizedBox(width: 12),
            Text(
              'BiTeSports',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.login, color: Colors.white),
            label: Text('Login', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => LoginPage()));
            },
          ),
          SizedBox(width: 8),
          TextButton.icon(
            icon: Icon(Icons.app_registration, color: Colors.white),
            label: Text('Registar Conta', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => RegistoPage()));
            },
          ),
          SizedBox(width: 24),
        ],
      ),
      body: Column(
        children: [
          // Conteúdo principal
          Expanded(
            child: Stack(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildImageSwitcher(imageGroups[0][currentIndex1])),
                    Expanded(child: _buildImageSwitcher(imageGroups[1][currentIndex2])),
                    Expanded(child: _buildImageSwitcher(imageGroups[2][currentIndex3])),
                  ],
                ),
                Center(
                  child: SingleChildScrollView(
                    child: Container(
  constraints: BoxConstraints(
    maxWidth: 800, // Largura máxima do container
  ),
  padding: EdgeInsets.all(32),
  decoration: BoxDecoration(
    color: Colors.black.withOpacity(0.84),
    borderRadius: BorderRadius.circular(16),
  ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Bem-vindo ao BiTeSports',
                            style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Plataforma inovadora de monitorização em tempo real para equipas de esports.\n'
                            'Melhora a performance, analisa métricas e toma decisões baseadas em dados!',
                            style: TextStyle(fontSize: 18, color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 32),
                          // Cartões de funcionalidades
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildFeatureCard(
                                Icons.show_chart, "Análise de Performance", "Vê o progresso em tempo real."
                              ),
                              _buildFeatureCard(
                                Icons.health_and_safety, "Saúde em 1º lugar", "Monitorização sem esforço."
                              ),
                              _buildFeatureCard(
                                Icons.groups, "Gestão de Equipas", "Todos os jogadores num só dashboard."
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Footer fixo
          Container(
            width: double.infinity,
            color: Colors.black.withOpacity(0.8),
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                '© 2024 BiTeSports — Projeto UBI | Contacto: bitesports@gmail.com',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
