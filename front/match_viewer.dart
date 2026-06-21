import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_logic;

class MatchViewerScreen extends StatefulWidget {
  final List<String> moves;
  final String whiteName;
  final String blackName;

  const MatchViewerScreen({super.key, required this.moves, required this.whiteName, required this.blackName});

  @override
  State<MatchViewerScreen> createState() => _MatchViewerScreenState();
}

class _MatchViewerScreenState extends State<MatchViewerScreen> {
  late chess_logic.Chess game;
  int currentMoveIndex = -1; 

  @override
  void initState() {
    super.initState();
    game = chess_logic.Chess(); 
  }

  void _irParaLance(int index) {
    if (index < -1 || index >= widget.moves.length) return;

    chess_logic.Chess newGame = chess_logic.Chess();
    
    for (int i = 0; i <= index; i++) {
      String lance = widget.moves[i];
      
      if (lance.length >= 4) {
        String de = lance.substring(0, 2);    
        String para = lance.substring(2, 4); 
        String? promocao = (lance.length == 5) ? lance.substring(4, 5) : null; 
        
        newGame.move({
          "from": de,
          "to": para,
          if (promocao != null) "promotion": promocao
        });
      }
    }

    setState(() {
      game = newGame;
      currentMoveIndex = index;
    });
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
    return Padding(padding: const EdgeInsets.all(4.0), child: Image.network(url));
  }

  @override
  Widget build(BuildContext context) {
    List<String> board = [];
    String fen = game.fen.split(' ')[0];
    for (var char in fen.split('')) {
      if (char == '/') continue;
      if (int.tryParse(char) != null) board.addAll(List.filled(int.parse(char), ''));
      else board.add(char);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF161512),
      appBar: AppBar(backgroundColor: const Color(0xFF262421),title: const Text("Replay da Partida")),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Text("${widget.blackName} (Pretas)", style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 10),
          Center(
            child: SizedBox(
              width: 360, height: 360,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                itemCount: 64,
                itemBuilder: (context, index) {
                  int row = index ~/ 8; int col = index % 8;
                  return Container(
                    color: (row + col) % 2 == 0 ? Colors.brown[200] : Colors.brown[600],
                    child: _obterWidgetPeca(board[index]),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text("${widget.whiteName} (Brancas)", style: const TextStyle(fontSize: 18)),
          const Spacer(),
          Text("Lance ${currentMoveIndex + 1} de ${widget.moves.length}"),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.first_page, size: 40), onPressed: () => _irParaLance(-1)),
              IconButton(icon: const Icon(Icons.chevron_left, size: 40), onPressed: () => _irParaLance(currentMoveIndex - 1)),
              IconButton(icon: const Icon(Icons.chevron_right, size: 40), onPressed: () => _irParaLance(currentMoveIndex + 1)),
              IconButton(icon: const Icon(Icons.last_page, size: 40), onPressed: () => _irParaLance(widget.moves.length - 1)),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
