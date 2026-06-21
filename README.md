# Xadrez Multiplayer Cooperativo

Projeto desenvolvido para o Trabalho Integrado de Sistemas Distribuidos e Introducao ao Desenvolvimento Web.

A aplicacao implementa um jogo de xadrez multiplayer com modos colaborativos, usando frontend em Flutter/Dart, backend em Go e persistencia em MongoDB. A comunicacao combina endpoints REST para autenticacao, salas e historico com WebSocket para sincronizar partidas em tempo real.

## Funcionalidades

- Cadastro e login de usuarios.
- Persistencia de usuarios e partidas em MongoDB.
- Criacao e listagem de salas.
- Partidas em tempo real via WebSocket.
- Modos de jogo `1v1`, `2v2` e `3v3`.
- Escolha de equipe, brancas ou pretas.
- Validacao de lances de xadrez no backend.
- Pedido de empate, rendicao e revanche.
- Historico de partidas por usuario.
- Replay de partidas a partir da lista de movimentos.

## Arquitetura

O projeto segue uma organizacao multitier:

- `front/`: camada de apresentacao em Flutter/Dart.
- `back/`: backend em Go, com API REST, WebSocket, regras de negocio e acesso ao banco.
- MongoDB: camada de dados, usada para usuarios e historico de partidas.

Fluxo principal:

1. O usuario faz cadastro ou login pelo frontend.
2. O frontend cria ou consulta salas pelo backend REST.
3. Ao entrar em uma sala, o frontend abre uma conexao WebSocket.
4. O backend valida jogadas, atualiza o estado da sala e transmite o novo estado para os jogadores.
5. As partidas sao salvas no MongoDB e podem ser consultadas no historico.

## Estrutura do Projeto

```text
xadrez-coop/
├── back/
│   ├── cmd/api/                  # Entrada da API Go
│   ├── internal/delivery/         # HTTP, CORS e WebSocket
│   ├── internal/domain/           # Modelos e interfaces
│   ├── internal/repository/       # Repositorios MongoDB
│   ├── internal/service/          # Regras de negocio
│   ├── pkg/config/                # Configuracao por ambiente
│   ├── go.mod
│   └── Makefile
├── front/
│   ├── main.dart                  # Login, menu e historico
│   ├── room.dart                  # Salas
│   ├── gamescreen.dart            # Partida em tempo real
│   ├── match_viewer.dart          # Replay de partidas
│   └── lobby_screen.dart
├── back.md                        # Relatorio tecnico do backend
├── front.md                       # Relatorio tecnico do frontend
├── test.tex                       # Relatorio final em LaTeX
└── README.md
```

## Backend

O backend foi implementado em Go e esta em `back/`.

Principais responsabilidades:

- carregar configuracoes de ambiente;
- conectar ao MongoDB;
- registrar rotas REST;
- aceitar conexoes WebSocket;
- autenticar usuarios;
- gerenciar salas em memoria;
- validar e executar lances;
- salvar partidas no MongoDB.

### Variaveis de Ambiente

Antes de rodar o backend, configure:

```bash
export MONGO_URI="mongodb+srv://..."
export JWT_SECRET="uma-chave-secreta"
```

Variaveis opcionais:

```bash
export PORT="8080"
export MONGO_DATABASE="auth_db"
export MONGO_USERS_COLLECTION="users"
export MONGO_MATCHES_COLLECTION="matches"
export JWT_TTL_MINUTES="60"
```

### Rodando o Backend

```bash
cd back
go run ./cmd/api
```

Ou usando o Makefile:

```bash
cd back
make build-release
./bin/api
```

### Testes

```bash
cd back
make test
```

Tambem e possivel rodar diretamente:

```bash
cd back
go test ./...
```

## API REST

Rotas principais:

| Metodo | Rota | Descricao |
| --- | --- | --- |
| `POST` | `/api/register` | Cadastra um usuario |
| `POST` | `/api/login` | Autentica um usuario |
| `GET` | `/api/rooms` | Lista salas disponiveis |
| `GET` | `/api/history?user=<nome>` | Retorna historico do usuario |

Exemplo de cadastro:

```bash
curl -X POST http://localhost:8080/api/register \
  -H "Content-Type: application/json" \
  -d '{"username":"ana","password":"segredo"}'
```

Exemplo de login:

```bash
curl -X POST http://localhost:8080/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"ana","password":"segredo"}'
```

## WebSocket

Endpoint:

```text
ws://localhost:8080/ws/play?room=<sala>&user=<usuario>&mode=<modo>&team=<time>
```

Parametros:

- `room`: codigo da sala.
- `user`: nome do usuario.
- `mode`: `1v1`, `2v2` ou `3v3`.
- `team`: `w` para brancas ou `b` para pretas.

Mensagens enviadas pelo cliente:

```json
{"move":"e2e4"}
```

Acoes especiais:

```json
{"move":"offer_draw"}
{"move":"resign"}
{"move":"rematch"}
```

## Banco de Dados

O projeto usa MongoDB com duas colecoes principais:

- `users`: armazena usuarios, senha com hash `bcrypt` e salt.
- `matches`: armazena partidas, jogadores, FEN atual, status, data e lista de movimentos.

A colecao de partidas usa `upsert`, permitindo criar ou atualizar o documento da partida conforme o jogo evolui.

Campos relevantes de uma partida:

- `_id`: identificador da sala/partida.
- `mode`: modo de jogo.
- `current_fen`: estado atual do tabuleiro.
- `white_name`, `black_name`, `w2_name`, `b2_name`, `w3_name`, `b3_name`: jogadores por papel.
- `status`: resultado ou estado da partida.
- `date`: data da partida.
- `moves`: lista de movimentos em UCI.

## Frontend

O frontend esta em `front/` e foi escrito em Flutter/Dart.

Telas principais:

- `main.dart`: inicializacao, login, cadastro, menu e historico.
- `room.dart`: listagem e criacao de salas.
- `gamescreen.dart`: tabuleiro e comunicacao WebSocket.
- `match_viewer.dart`: replay de partidas.

Observacao: o diretorio `front/` deste repositorio contem os arquivos Dart da aplicacao, mas nao inclui um `pubspec.yaml`. Para executar o frontend como projeto Flutter completo, e necessario estar em um projeto Flutter configurado com as dependencias usadas no codigo.

Dependencias identificadas pelos imports:

- `flutter/material.dart`
- `http`
- `shared_preferences`
- `web_socket_channel`
- `chess`

## Relatorio

Arquivos de documentacao tecnica:

- `relatorio.tex`: relatorio completo em LaTeX.

## Observacoes

- O backend esta preparado para receber configuracao por variaveis de ambiente.
- O frontend atualmente aponta para o backend hospedado em Render em algumas chamadas HTTP/WebSocket.
- O estado das salas fica em memoria no backend; o historico das partidas e persistido no MongoDB.
- O token retornado pelo login e gerado pelo backend, mas o frontend analisado salva localmente apenas o nome de usuario.
