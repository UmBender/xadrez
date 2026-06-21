import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChessBoardScreen extends StatefulWidget {
  final String roomCode;
  final String username; 
  final String mode; 
  final String team; 
  
  const ChessBoardScreen({super.key, required this.roomCode, required this.username, required this.mode, required this.team});

  @override
  State<ChessBoardScreen> createState() => _ChessBoardScreenState();
}

class _ChessBoardScreenState extends State<ChessBoardScreen> {
  late WebSocketChannel _channel;
  
  String currentFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR"; 
  String? lastFen; 
  String gameStatus = "*"; 
  String? casaSelecionada;
  List<String> movimentosValidos = [];
  bool isDialogOpen = false; 
  bool euPediRevanche = false; 
  int rematchVotes = 0;
  
  int playerCount = 0; 
  int maxPlayers = 2;
  Map<String, dynamic> jogadoresConectados = {}; 
  String? myRole; 

  List<String> activeRoles = ['w1']; 
  Map<String, dynamic> proposedMoves = {}; 
  String drawOffer = ""; 
  
  bool localDrawOffered = false; 

  @override
  void initState() {
    super.initState();

    _channel = WebSocketChannel.connect(
      Uri.parse('wss://xadrez-a8qm.onrender.com/ws/play?room=${widget.roomCode}&user=${widget.username}&mode=${widget.mode}&team=${widget.team}')
    );
    
    _channel.stream.listen((message) {
      final data = jsonDecode(message);
      if (data['error'] != null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'])));
        return;
      }
      
      setState(() {
        currentFen = data['fen'];
        gameStatus = data['status'] ?? '*';
        playerCount = data['player_count']; 
        maxPlayers = data['max_players'] ?? 2;
        movimentosValidos = List<String>.from(data['valid_moves'] ?? []);
        rematchVotes = data['rematch_votes'] ?? 0;
        jogadoresConectados = data['players'] ?? {};
        activeRoles = List<String>.from(data['active_roles'] ?? ['w1']);
        proposedMoves = data['proposed_moves'] ?? {};
        
        if (myRole == null) {
          jogadoresConectados.forEach((cargo, nome) {
            if (nome == widget.username && cargo.startsWith(widget.team)) myRole = cargo;
          });
          if (myRole == null && jogadoresConectados.containsValue(widget.username)) {
            jogadoresConectados.forEach((cargo, nome) { if (nome == widget.username) myRole = cargo; });
          }
        }

        String novoDrawOffer = data['draw_offer'] ?? ""; 

        if (gameStatus != '*') {
          localDrawOffered = false;
          drawOffer = "";
          novoDrawOffer = "";
        } else {
          bool moveHappened = false;
          if (lastFen != null && lastFen != currentFen) moveHappened = true; 
          lastFen = currentFen; 

          if (moveHappened) localDrawOffered = false;

          if (myRole != null && novoDrawOffer == myRole![0]) {
             localDrawOffered = true;
          }

          if (myRole != null && novoDrawOffer.isNotEmpty && novoDrawOffer != myRole![0]) {
             localDrawOffered = false; 
          }
        }

        drawOffer = novoDrawOffer; 
        casaSelecionada = null; 
      });

      if (gameStatus != '*') {
        if (!isDialogOpen) _mostrarFimDeJogo(gameStatus); 
        else {
          Navigator.of(context).pop(); isDialogOpen = false;
          _mostrarFimDeJogo(gameStatus); 
        }
      } else {
        if (isDialogOpen) { Navigator.pop(context); isDialogOpen = false; }
        euPediRevanche = false; 
      }
    });
  }

  void _mostrarRegrasDoModo() {
    String regras = "";
    if (widget.mode == "1v1") regras = "Xadrez clássico. Jogue normalmente seguindo as regras da FIDE.";
    else if (widget.mode == "2v2") regras = "Modo Duplas:\nOs jogadores vão alternar entre si para mover as peças.\nConfie na sua dupla!";
    else if (widget.mode == "3v3") regras = "Modo Conselho (3v3):\n- Um jogador é escolhido como juiz os outros dois realizam jogadas\n- Se ambos fizerem o mesmo lance, a peça se move\n- Se discordarem, o painel de Impasse aparece e o Juiz decide qual dos lances deve ser jogado.";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF262421),
        title: Row(
          children: [
            const Icon(Icons.menu_book, color: Colors.blueGrey),
            const SizedBox(width: 10),
            Text("Regras: ${widget.mode}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(regras, style: const TextStyle(color: Color(0xFFBABABA), fontSize: 16, height: 1.5)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF363431), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: const Text("Entendi"),
          ),
        ],
      ),
    );
  }

  void _mostrarFimDeJogo(String resultado) {
    if (isDialogOpen) return; 
    isDialogOpen = true;

    String mensagem = "O jogo terminou em empate!";
    if (resultado == "1-0") mensagem = "Fim de Jogo!\nAs Brancas Venceram!";
    else if (resultado == "0-1") mensagem = "Fim de Jogo!\nAs Pretas Venceram!";

    Widget rematchWidget = euPediRevanche 
        ? const Text("Aguardando votos...", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
        : ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              _channel.sink.add(jsonEncode({"move": "rematch"}));
              setState(() => euPediRevanche = true);
            },
            child: Text("Pedir Revanche ($rematchVotes/$playerCount)"),
          );

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF262421),
        title: const Text("Resultado", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        content: Text(mensagem, style: const TextStyle(fontSize: 18, color: Color(0xFFBABABA)), textAlign: TextAlign.center),
        actions: [
          rematchWidget,
          TextButton(
            onPressed: () {
              Navigator.pop(context); Navigator.pop(context); isDialogOpen = false;
            },
            child: const Text("Sair da Sala", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  void _confirmResign() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF262421),
        title: const Text("Render-se", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("Tem a certeza que deseja desistir da partida?", style: TextStyle(color: Color(0xFFBABABA))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], foregroundColor: Colors.white),
            onPressed: () {
              _channel.sink.add(jsonEncode({"move": "resign"}));
              Navigator.pop(context);
            },
            child: const Text("Sim, Render-se"),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerBadge(String roleID) {
    String name = jogadoresConectados[roleID] ?? "Aguardando...";
    bool isMe = (myRole == roleID);
    bool isWhiteTeam = roleID.startsWith('w');
    bool isActiveNow = activeRoles.contains(roleID);
    bool jaVotou = proposedMoves[roleID] != null && proposedMoves[roleID] != "";

    return AnimatedOpacity(
      opacity: isActiveNow ? 1.0 : 0.35,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: isWhiteTeam ? Colors.grey[200] : Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActiveNow ? (isWhiteTeam ? Colors.blue : Colors.cyan) : Colors.black12,
            width: isActiveNow ? 2 : 1,
          ),
          boxShadow: isActiveNow ? [BoxShadow(color: isWhiteTeam ? Colors.blue[200]! : Colors.black45, blurRadius: 4)] : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "$name ${isMe ? '(Vc)' : ''}",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isWhiteTeam ? Colors.black87 : Colors.white),
            ),
            if (jaVotou) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_circle, size: 14, color: isWhiteTeam ? Colors.green[700] : Colors.green[400]),
            ]
          ],
        ),
      ),
    );
  }

  List<String> gerarListaDoTabuleiro() {
    List<String> board = [];
    String linhasFen = currentFen.split(' ')[0];
    for (int i = 0; i < linhasFen.length; i++) {
      String caractere = linhasFen[i];
      if (caractere == '/') continue;
      if (int.tryParse(caractere) != null) board.addAll(List.filled(int.parse(caractere), ''));
      else board.add(caractere);
    }
    return board;
  }

  Widget _obterWidgetPeca(String fenChar) {
    if (fenChar.isEmpty) return const SizedBox();
    String url = '';
    switch (fenChar) {
      case 'r': url = 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/ff/Chess_rdt45.svg/120px-Chess_rdt45.svg.png'; break;
      case 'n': url = 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/ef/Chess_ndt45.svg/120px-Chess_ndt45.svg.png'; break;
      case 'b': url = 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/98/Chess_bdt45.svg/120px-Chess_bdt45.svg.png'; break;
      case 'q': url = 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/Chess_qdt45.svg/120px-Chess_qdt45.svg.png'; break;
      case 'k': url = 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f0/Chess_kdt45.svg/120px-Chess_kdt45.svg.png'; break;
      case 'p': url = 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c7/Chess_pdt45.svg/120px-Chess_pdt45.svg.png'; break;
      case 'R': url = 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/72/Chess_rlt45.svg/120px-Chess_rlt45.svg.png'; break;
      case 'N': url = 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/70/Chess_nlt45.svg/120px-Chess_nlt45.svg.png'; break;
      case 'B': url = 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b1/Chess_blt45.svg/120px-Chess_blt45.svg.png'; break;
      case 'Q': url = 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/15/Chess_qlt45.svg/120px-Chess_qlt45.svg.png'; break;
      case 'K': url = 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/42/Chess_klt45.svg/120px-Chess_klt45.svg.png'; break;
      case 'P': url = 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/45/Chess_plt45.svg/120px-Chess_plt45.svg.png'; break;
    }
    return Padding(padding: const EdgeInsets.all(4.0), child: Image.network(url, fit: BoxFit.contain));
  }

  Future<String?> _mostrarDialogoPromocao() async {
    bool isWhiteTeam = myRole != null && myRole!.startsWith('w');
    String q = isWhiteTeam ? 'Q' : 'q'; String r = isWhiteTeam ? 'R' : 'r';
    String b = isWhiteTeam ? 'B' : 'b'; String n = isWhiteTeam ? 'N' : 'n';
    return showDialog<String>(
      context: context, barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF262421),
        title: const Text('Promover Peão', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: SizedBox(width: 40, height: 40, child: _obterWidgetPeca(q)), title: const Text('Rainha', style: TextStyle(color: Colors.white)), onTap: () => Navigator.pop(context, 'q')),
            ListTile(leading: SizedBox(width: 40, height: 40, child: _obterWidgetPeca(r)), title: const Text('Torre', style: TextStyle(color: Colors.white)), onTap: () => Navigator.pop(context, 'r')),
            ListTile(leading: SizedBox(width: 40, height: 40, child: _obterWidgetPeca(b)), title: const Text('Bispo', style: TextStyle(color: Colors.white)), onTap: () => Navigator.pop(context, 'b')),
            ListTile(leading: SizedBox(width: 40, height: 40, child: _obterWidgetPeca(n)), title: const Text('Cavalo', style: TextStyle(color: Colors.white)), onTap: () => Navigator.pop(context, 'n')),
          ],
        ),
      ),
    );
  }

  void _aoClicarNaCasa(String nomeDaCasa) async {
    if (!activeRoles.contains(myRole)) return;

    setState(() {
      if (casaSelecionada == null) {
        bool temMovimento = movimentosValidos.any((m) => m.startsWith(nomeDaCasa));
        if (temMovimento) casaSelecionada = nomeDaCasa; 
      } else {
        String jogadaBase = "$casaSelecionada$nomeDaCasa";
        bool ehValida = movimentosValidos.any((m) => m.startsWith(jogadaBase));
        
        if (ehValida) {
          int col = casaSelecionada!.codeUnitAt(0) - 97;
          int row = 8 - int.parse(casaSelecionada![1]);
          String peca = gerarListaDoTabuleiro()[row * 8 + col];
          
          if ((peca == 'P' && nomeDaCasa.endsWith('8')) || (peca == 'p' && nomeDaCasa.endsWith('1'))) {
            _mostrarDialogoPromocao().then((escolha) {
              if (escolha != null) _channel.sink.add(jsonEncode({"move": "$jogadaBase$escolha"}));
              setState(() => casaSelecionada = null);
            });
            return; 
          } else {
            _channel.sink.add(jsonEncode({"move": jogadaBase}));
          }
        }
        casaSelecionada = null; 
      }
    });
  }

  Widget _buildActionToolbar() {
    if (gameStatus != '*') return const SizedBox.shrink(); 
    if (myRole == null) return const SizedBox.shrink(); 

    bool myTeamOffered = (drawOffer.isNotEmpty && drawOffer == myRole![0]) || localDrawOffered;
    bool enemyOffered = drawOffer.isNotEmpty && drawOffer != myRole![0];

    Widget drawButton;

    if (enemyOffered) {
      drawButton = ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF363431), 
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          side: const BorderSide(color: Colors.orangeAccent, width: 2), 
        ),
        icon: const Icon(Icons.handshake, size: 22, color: Colors.orangeAccent),
        label: const Text("Pedido de Empate 1/2", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        onPressed: () => _channel.sink.add(jsonEncode({"move": "offer_draw"})),
      );
    } else if (myTeamOffered) {
      drawButton = ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF262421), 
          foregroundColor: Colors.grey[400],
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          side: const BorderSide(color: Colors.white12, width: 1),
        ),
        icon: const SizedBox(
          width: 14, height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent),
        ),
        label: const Text("Pedido Enviado (1/2) ⏳", style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: null, 
      );
    } else {
      drawButton = ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF363431), 
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        icon: const Icon(Icons.handshake),
        label: const Text("Pedir Empate", style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          setState(() { localDrawOffered = true; });
          _channel.sink.add(jsonEncode({"move": "offer_draw"}));
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[800], 
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            icon: const Icon(Icons.flag),
            label: const Text("Render-se", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _confirmResign,
          ),
          const SizedBox(width: 15),
          drawButton,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String> casasVisuais = gerarListaDoTabuleiro();

    if (playerCount < maxPlayers) {
      return Scaffold(
        backgroundColor: const Color(0xFF161512),
        appBar: AppBar(backgroundColor: const Color(0xFF262421), title: Text('Lobby ${widget.mode} - Aguardando ($playerCount/$maxPlayers)', style: const TextStyle(color: Colors.white))),
        body: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    bool souEquipePretas = myRole != null && myRole!.startsWith('b');
    
    List<Widget> topRow = [];
    List<Widget> bottomRow = [];

    if (widget.mode == "3v3") {
      topRow = souEquipePretas ? [_buildPlayerBadge('w1'), _buildPlayerBadge('w2'), _buildPlayerBadge('w3')] : [_buildPlayerBadge('b1'), _buildPlayerBadge('b2'), _buildPlayerBadge('b3')];
      bottomRow = souEquipePretas ? [_buildPlayerBadge('b1'), _buildPlayerBadge('b2'), _buildPlayerBadge('b3')] : [_buildPlayerBadge('w1'), _buildPlayerBadge('w2'), _buildPlayerBadge('w3')];
    } else if (widget.mode == "2v2") {
      topRow = souEquipePretas ? [_buildPlayerBadge('w1'), _buildPlayerBadge('w2')] : [_buildPlayerBadge('b1'), _buildPlayerBadge('b2')];
      bottomRow = souEquipePretas ? [_buildPlayerBadge('b1'), _buildPlayerBadge('b2')] : [_buildPlayerBadge('w1'), _buildPlayerBadge('w2')];
    } else {
      topRow = souEquipePretas ? [_buildPlayerBadge('w1')] : [_buildPlayerBadge('b1')];
      bottomRow = souEquipePretas ? [_buildPlayerBadge('b1')] : [_buildPlayerBadge('w1')];
    }

    Widget painelDesempate = const SizedBox.shrink();
    String lanceA = ""; String lanceB = "";

    if (widget.mode == "3v3" && myRole != null && activeRoles.contains(myRole)) {
      List<MapEntry<String, dynamic>> votosDaEquipa = proposedMoves.entries
          .where((e) => e.key.startsWith(myRole![0]) && e.value.toString().length >= 4 && e.value != "voted").toList();

      if (votosDaEquipa.length == 2 && votosDaEquipa[0].value != votosDaEquipa[1].value) {
        String nomeA = jogadoresConectados[votosDaEquipa[0].key] ?? "Jogador 1";
        String nomeB = jogadoresConectados[votosDaEquipa[1].key] ?? "Jogador 2";
        lanceA = votosDaEquipa[0].value; lanceB = votosDaEquipa[1].value;

        painelDesempate = Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.deepOrange)),
          child: Column(
            children: [
              const Text("🚨 IMPASSE DETECTADO!", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              const Text("Escolha qual dos lances aliados deve ser jogado:", style: TextStyle(color: Colors.white)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white), onPressed: () => _channel.sink.add(jsonEncode({"move": lanceA})), child: Text("$nomeA: $lanceA")),
                  const SizedBox(width: 15),
                  ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white), onPressed: () => _channel.sink.add(jsonEncode({"move": lanceB})), child: Text("$nomeB: $lanceB")),
                ],
              )
            ],
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF161512),
      appBar: AppBar(
        backgroundColor: const Color(0xFF262421), 
        title: Text("Sala ${widget.mode}: ${widget.roomCode}", style: const TextStyle(color: Colors.white)),
        actions: [
          Tooltip(
            message: "Ver regras do modo de jogo",
            child: IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.white),
              onPressed: _mostrarRegrasDoModo,
            ),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: topRow),
            const SizedBox(height: 15),

            painelDesempate,

            SizedBox(
              width: 400, height: 400,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 64,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                itemBuilder: (context, index) {
                  int boardIndex = souEquipePretas ? 63 - index : index;
                  int linha = boardIndex ~/ 8; int coluna = boardIndex % 8;
                  
                  String pecaFen = casasVisuais[boardIndex];
                  String nomeDaCasa = '${String.fromCharCode(97 + coluna)}${8 - linha}'; 
                  
                  bool estaSelecionada = casaSelecionada == nomeDaCasa;
                  bool ehDestinoValido = false;
                  if (casaSelecionada != null) {
                    ehDestinoValido = movimentosValidos.any((m) => m.startsWith(casaSelecionada!) && m.substring(2, 4) == nomeDaCasa);
                  }

                  bool casaDoLanceA = lanceA.isNotEmpty && (lanceA.startsWith(nomeDaCasa) || lanceA.substring(2,4) == nomeDaCasa);
                  bool casaDoLanceB = lanceB.isNotEmpty && (lanceB.startsWith(nomeDaCasa) || lanceB.substring(2,4) == nomeDaCasa);

                  Color corDaCasa = (linha + coluna) % 2 == 0 ? Colors.brown[200]! : Colors.brown[600]!;

                  if (casaDoLanceA) {
                    corDaCasa = Colors.blue.withOpacity(0.6); 
                  } else if (casaDoLanceB) {
                    corDaCasa = Colors.purple.withOpacity(0.6); 
                  } else if (estaSelecionada) {
                    corDaCasa = Colors.yellow.withOpacity(0.5); 
                  }

                  Widget conteudoCasa = _obterWidgetPeca(pecaFen);

                  if (ehDestinoValido) {
                    if (pecaFen.isEmpty) {
                      conteudoCasa = Stack(
                        alignment: Alignment.center,
                        children: [
                          conteudoCasa,
                          Container(
                            width: 16, height: 16,
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.25), shape: BoxShape.circle),
                          ),
                        ],
                      );
                    } else {
                      conteudoCasa = Stack(
                        alignment: Alignment.center,
                        children: [
                          conteudoCasa,
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(border: Border.all(color: Colors.black.withOpacity(0.3), width: 5), shape: BoxShape.circle),
                          ),
                        ],
                      );
                    }
                  }

                  return GestureDetector(
                    onTap: () => _aoClicarNaCasa(nomeDaCasa),
                    child: Container(color: corDaCasa, child: Center(child: conteudoCasa)),
                  );
                },
              ),
            ),

            const SizedBox(height: 15),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: bottomRow),
            
            _buildActionToolbar(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() { 
    _channel.sink.close(); 
    super.dispose(); 
  }
}
