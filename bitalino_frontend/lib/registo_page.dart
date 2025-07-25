import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegistoPage extends StatefulWidget {
  @override
  _RegistoPageState createState() => _RegistoPageState();
}
// Esta página permite que novos utilizadores se registem na aplicação, escolhendo entre dois tipos de conta: Treinador ou Jogador.
class _RegistoPageState extends State<RegistoPage> {
  final _formKey = GlobalKey<FormState>();
  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String tipoConta = 'Treinador';
// Variável para armazenar o tipo de conta selecionado pelo utilizador.

// Método para construir a página de registo de utilizador.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Registar Utilizador')),
      body: Center(
        child: Container(
          width: 400,
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nomeController,
                  decoration: InputDecoration(labelText: 'Nome'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Preenche o nome' : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  decoration: InputDecoration(labelText: 'Email'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Preenche o email' : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: 'Password'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Preenche a password' : null,
                ),
                SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: tipoConta,
                  items: ['Treinador', 'Jogador']
                      .map((tipo) =>
                          DropdownMenuItem(value: tipo, child: Text(tipo)))
                      .toList(),
                  onChanged: (val) {
                    setState(() => tipoConta = val!);
                  },
                  decoration: InputDecoration(labelText: 'Tipo de Conta'),
                ),
                SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    textStyle: TextStyle(fontSize: 16),
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final response = await http.post(
                        Uri.parse('http://localhost:5000/registar'),
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode({
                          'nome': nomeController.text,
                          'email': emailController.text,
                          'password': passwordController.text,
                          'tipo': tipoConta,
                        }),
                      );

                      final data = json.decode(response.body);

                      if (response.statusCode == 200) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('✅ Registo concluído')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro: ${data['erro']}')),
                        );
                      }
                    }
                  },
                  child: Text('Registar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
