import 'package:bitalino_frontend/perfil_jogador.dart';
import 'package:bitalino_frontend/perfil_treinador.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
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
                        Uri.parse('http://localhost:5000/login'),
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode({
                          'email': emailController.text,
                          'password': passwordController.text,
                        }),
                      );

                      final data = json.decode(response.body);

                      if (response.statusCode == 200) {
                        String tipo = data['tipo'];
                        int id = data['id'];

                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('tipo', tipo);
                        await prefs.setString('email', emailController.text);
                        await prefs.setInt('id', id);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Bem-vindo $tipo!')),
                        );

                        if (tipo == 'treinador') {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => PerfilTreinadorPage()),
                          );
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => PerfilJogadorPage()),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro: ${data['erro']}')),
                        );
                      }
                    }
                  },
                  child: Text('Entrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
