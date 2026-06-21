import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'room.dart';
import 'gamescreen.dart';
import 'match_viewer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? savedUsername = prefs.getString('username');
  
  runApp(MyApp(savedUsername: savedUsername));
}

class MyApp extends StatelessWidget {
  final String? savedUsername;
  const MyApp({super.key, this.savedUsername});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xadrez Multiplayer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark, 
        scaffoldBackgroundColor: const Color(0xFF161512), 
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161512), 
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: savedUsername != null && savedUsername!.isNotEmpty
          ? MainMenuScreen(username: savedUsername!)
          : const AuthScreen(),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    String url = _isLogin 
        ? 'https://xadrez-a8qm.onrender.com/api/login' 
        : 'https://xadrez-a8qm.onrender.com/api/register';
    
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": _usernameController.text,
          "password": _passwordController.text,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (_isLogin) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('username', _usernameController.text);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MainMenuScreen(username: _usernameController.text)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registrado com sucesso! Faça login.')));
          setState(() => _isLogin = true);
        }
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorData['message'] ?? 'Erro desconhecido')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro de conexão: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161512),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF262421),
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 4)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isLogin ? 'Entrar' : 'Registrar',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Usuário',
                    labelStyle: const TextStyle(color: Color(0xFFBABABA)),
                    enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF363431))),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blueGrey)),
                    filled: true,
                    fillColor: const Color(0xFF161512),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    labelStyle: const TextStyle(color: Color(0xFFBABABA)),
                    enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF363431))),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blueGrey)),
                    filled: true,
                    fillColor: const Color(0xFF161512),
                  ),
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF363431),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          onPressed: _submit,
                          child: Text(_isLogin ? 'ENTRAR' : 'CRIAR CONTA', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin ? 'Não tem uma conta? Registre-se' : 'Já tem conta? Faça login',
                    style: const TextStyle(color: Color(0xFFBABABA)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum GameMode { umContraUm, doisContraDois, tresContraTres, contraIA }

class MainMenuScreen extends StatefulWidget {
  final String username;
  const MainMenuScreen({super.key, required this.username});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  GameMode _selectedMode = GameMode.umContraUm;

  Future<void> _escolherEquipeEEntrar(BuildContext context, String codigo, String modo, String username) async {
    String? equipeEscolhida = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF262421), 
        title: const Text('Escolha sua Equipe', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
        content: const Text('Em qual lado do tabuleiro você deseja jogar?', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFBABABA))),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(context, 'w'), 
            child: const Text('Brancas', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24)),
            onPressed: () => Navigator.pop(context, 'b'), 
            child: const Text('Pretas', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (equipeEscolhida != null) {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChessBoardScreen(
            roomCode: codigo,
            username: username,
            mode: modo,
            team: equipeEscolhida, 
          ),
        ),
      );
    }
  }

  void _handleAction(String acao) {
    String modoParaOGo = "1v1";
    if (_selectedMode == GameMode.doisContraDois) modoParaOGo = "2v2";
    if (_selectedMode == GameMode.tresContraTres) modoParaOGo = "3v3";

    if (acao == 'criar') {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final random = Random();
      String novoCodigo = String.fromCharCodes(Iterable.generate(
          4, (_) => chars.codeUnitAt(random.nextInt(chars.length))));

      _escolherEquipeEEntrar(context, novoCodigo, modoParaOGo, widget.username);
    } else if (acao == 'entrar') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => JoinRoomScreen(username: widget.username, mode: modoParaOGo)),
      );
    } else if (acao == 'historico') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => HistoryScreen(username: widget.username)),
      );
    }
  }

  Widget _buildModeButton(String title, String subtitle, GameMode mode, String tooltipMsg) {
    bool isSelected = _selectedMode == mode;
    return Tooltip(
      message: tooltipMsg,
      waitDuration: const Duration(milliseconds: 500),
      child: GestureDetector(
        onTap: () => setState(() => _selectedMode = mode),
        child: Container(
          width: 130, 
          height: 110,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF363431) : const Color(0xFF262421), 
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: isSelected ? Colors.blueGrey : Colors.transparent, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 4)],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(fontSize: 14, color: Color(0xFFBABABA))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF262421), 
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 4)],
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFBABABA), size: 28),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isWide = MediaQuery.of(context).size.width > 600;

    Widget modesGrid = Wrap(
      spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
      children: [
        _buildModeButton('1v1', 'Clássico', GameMode.umContraUm, 'Xadrez tradicional. Um jogador contra o outro.'),
        _buildModeButton('2v2', 'Duplas', GameMode.doisContraDois, 'Modo em que os jogadores ficam alternando o controle das peças'),
        _buildModeButton('3v3', 'Conselho', GameMode.tresContraTres, 'Dois jogadores propõem lances, o terceiro decide em caso de impasse.'),
      ],
    );

    Widget actionButtons = Column(
      children: [
        _buildActionButton(Icons.group_add, 'Criar partida na sala', () => _handleAction('criar')),
        _buildActionButton(Icons.list_alt, 'Lista de salas abertas', () => _handleAction('entrar')),
        _buildActionButton(Icons.history, 'Histórico de partidas', () => _handleAction('historico')),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFF161512),
      appBar: AppBar(
        title: const Text('Xadrez Multiplayer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white)),
        actions: [
          Center(child: Padding(padding: const EdgeInsets.only(right: 16), child: Text(widget.username, style: const TextStyle(color: Color(0xFFBABABA), fontSize: 16)))),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFBABABA)), 
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.remove('username');
              
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context, 
                MaterialPageRoute(builder: (context) => const AuthScreen())
              );
            }
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: modesGrid), 
                      const SizedBox(width: 40),
                      Expanded(flex: 2, child: actionButtons), 
                    ],
                  )
                : Column(
                    children: [
                      modesGrid,
                      const SizedBox(height: 40),
                      actionButtons,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  final String username;
  const HistoryScreen({super.key, required this.username});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _historico = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _buscarHistorico();
  }

  Future<void> _buscarHistorico() async {
    try {
      final response = await http.get(Uri.parse('https://xadrez-a8qm.onrender.com/api/history?user=${widget.username}'));
      if (response.statusCode == 200) {
        List<dynamic> dadosJson = jsonDecode(response.body);
        setState(() {
          _historico = dadosJson.map((p) => p as Map<String, dynamic>).toList();
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161512),
      appBar: AppBar(
        title: const Text('Histórico de Partidas', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF262421), 
        iconTheme: const IconThemeData(color: Color(0xFFBABABA)), 
      ),
      body: _buildHistoryContent(),
    );
  }

  Widget _buildHistoryContent() {
    if (_isLoadingHistory) return const Center(child: CircularProgressIndicator(color: Colors.white));
    if (_historico.isEmpty) return const Center(child: Text('Nenhuma partida encontrada.', style: TextStyle(fontSize: 16, color: Color(0xFFBABABA))));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _historico.length,
      itemBuilder: (context, index) {
        final partida = _historico[index];
        String status = partida['status'] ?? '*';
        String modo = partida['mode'] ?? '1v1';
        
        List<String> brancas = []; List<String> pretas = [];

        void addIfValid(String? name, List<String> team) {
          if (name != null && name.trim().isNotEmpty && name != "Aguardando..." && name != "Desconhecido") team.add(name);
        }

        addIfValid(partida['white_name'], brancas); addIfValid(partida['w2_name'], brancas); addIfValid(partida['w3_name'], brancas);
        addIfValid(partida['black_name'], pretas); addIfValid(partida['b2_name'], pretas); addIfValid(partida['b3_name'], pretas);

        String strBrancas = brancas.isEmpty ? "Brancas" : brancas.join(", ");
        String strPretas = pretas.isEmpty ? "Pretas" : pretas.join(", ");

        bool isWhiteTeam = brancas.contains(widget.username);
        bool isBlackTeam = pretas.contains(widget.username);
        bool? isWin;
        
        if (status == '1-0') isWin = isWhiteTeam ? true : (isBlackTeam ? false : null);
        else if (status == '0-1') isWin = isBlackTeam ? true : (isWhiteTeam ? false : null);
        else if (status == '1/2-1/2') isWin = null; 

        Color iconColor = const Color(0xFFBABABA);
        IconData iconData = Icons.schedule; 
        String textoResultado = "Em Andamento";

        if (isWin == true) { iconColor = Colors.green[400]!; iconData = Icons.emoji_events; textoResultado = "Vitória"; }
        else if (isWin == false) { iconColor = Colors.red[400]!; iconData = Icons.cancel; textoResultado = "Derrota"; }
        else if (status == '1/2-1/2') { iconColor = Colors.orange[400]!; iconData = Icons.handshake; textoResultado = "Empate"; }

        return GestureDetector(
          onTap: () {
            List<String> lances = List<String>.from(partida['moves'] ?? []);
            if (lances.isNotEmpty) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => MatchViewerScreen(moves: lances, whiteName: strBrancas, blackName: strPretas)));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Partida sem lances gravados.', style: TextStyle(color: Colors.white))));
            }
          },
          child: Card(
            color: const Color(0xFF262421), 
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: iconColor.withOpacity(0.15), child: Icon(iconData, color: iconColor)),
                title: Text('Modo $modo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text('⚪ $strBrancas', style: const TextStyle(color: Color(0xFFBABABA))),
                    const SizedBox(height: 2),
                    Text('⚫ $strPretas', style: const TextStyle(color: Color(0xFFBABABA))),
                    const SizedBox(height: 6),
                    Text('Data: ${partida['date'] ?? "Hoje"}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF888888))),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Text(textoResultado, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: iconColor))],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
