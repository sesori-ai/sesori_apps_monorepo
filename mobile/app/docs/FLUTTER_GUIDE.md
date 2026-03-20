# Flutter Integration Guide for OpenCode

Architecture patterns, recommended packages, and code snippets for building a Flutter mobile client.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Recommended Packages](#recommended-packages)
- [Server Discovery & Connection](#server-discovery--connection)
- [HTTP Client Setup](#http-client-setup)
- [SSE Integration](#sse-integration)
- [Streaming Chat UI](#streaming-chat-ui)
- [Permission & Question Dialogs](#permission--question-dialogs)
- [WebSocket Terminal](#websocket-terminal)
- [State Management Considerations](#state-management-considerations)
- [Suggested Project Structure](#suggested-project-structure)

---

## Architecture Overview

```
┌──────────────────────┐         ┌──────────────────────────┐
│   Flutter Mobile App  │  HTTP   │  OpenCode Local Server   │
│                       │◄───────►│  (user's machine)        │
│  ┌─────────────────┐ │  REST   │                          │
│  │ API Client Layer │ │         │  Hono + Bun              │
│  │ (dio / openapi) │ │         │  Port 4096               │
│  └────────┬────────┘ │         └──────────────────────────┘
│           │          │               ▲         ▲
│  ┌────────▼────────┐ │    SSE        │   WS    │
│  │ Event Bus       │ │◄─────────────┘         │
│  │ (SSE stream)    │ │                         │
│  └────────┬────────┘ │         ┌───────────────┘
│           │          │         │
│  ┌────────▼────────┐ │  ┌─────▼──────────┐
│  │ State Mgmt      │ │  │ Terminal View   │
│  │ (riverpod/bloc) │ │  │ (xterm.dart)   │
│  └────────┬────────┘ │  └────────────────┘
│           │          │
│  ┌────────▼────────┐ │
│  │ UI Layer        │ │
│  │ (Material 3)    │ │
│  └─────────────────┘ │
└──────────────────────┘
```

The mobile app connects to the server running on the user's computer over the local network. There are three communication channels:

1. **REST API** — CRUD operations, sending prompts, managing sessions
2. **SSE stream** — Real-time events (message deltas, status changes, permission requests)
3. **WebSocket** — PTY terminal I/O (optional, for terminal feature)

---

## Recommended Packages

### Core

| Package                            | Purpose            | Why                                          |
| ---------------------------------- | ------------------ | -------------------------------------------- |
| `dio`                              | HTTP client        | Interceptors for auth, error handling, retry |
| `retrofit` / `openapi_generator`   | API client codegen | Generate typed client from `openapi.json`    |
| `eventsource_client` or raw `http` | SSE client         | Server-Sent Events consumption               |
| `riverpod` or `flutter_bloc`       | State management   | Reactive state for streaming events          |
| `go_router`                        | Navigation         | Deep link support                            |

### Discovery & Connectivity

| Package             | Purpose                  |
| ------------------- | ------------------------ |
| `nsd` or `bonsoir`  | mDNS service discovery   |
| `connectivity_plus` | Network state monitoring |

### UI

| Package                           | Purpose                                          |
| --------------------------------- | ------------------------------------------------ |
| `flutter_markdown`                | Render AI markdown responses                     |
| `flutter_highlight` / `highlight` | Code syntax highlighting                         |
| `xterm`                           | Terminal emulator widget (for PTY WebSocket)     |
| `flutter_local_notifications`     | Permission/question alerts when app backgrounded |

### Storage

| Package              | Purpose                           |
| -------------------- | --------------------------------- |
| `shared_preferences` | Server URL, auth credentials      |
| `hive` or `isar`     | Local cache for sessions/messages |

---

## Server Discovery & Connection

### mDNS Discovery

```dart
import 'package:bonsoir/bonsoir.dart';

class ServerDiscovery {
  final _discovery = BonsoirDiscovery(type: '_http._tcp');

  Stream<ResolvedBonsoirService> discover() async* {
    await _discovery.ready;
    await _discovery.start();

    await for (final event in _discovery.eventStream!) {
      if (event.type == BonsoirDiscoveryEventType.discoveryServiceResolved) {
        final service = event.service as ResolvedBonsoirService;
        if (service.name.startsWith('opencode-')) {
          yield service;
        }
      }
    }
  }

  void stop() => _discovery.stop();
}
```

### Manual Connection

```dart
class ServerConnection {
  String? _baseUrl;
  String? _password;

  Future<bool> connect(String host, int port, {String? password}) async {
    _baseUrl = 'http://$host:$port';
    _password = password;

    try {
      final response = await dio.get('$_baseUrl/global/health');
      return response.data['healthy'] == true;
    } catch (e) {
      return false;
    }
  }
}
```

---

## HTTP Client Setup

### Dio Configuration

```dart
import 'dart:convert';
import 'package:dio/dio.dart';

Dio createClient({required String baseUrl, String? password}) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  // Basic Auth
  if (password != null) {
    final credentials = base64Encode(utf8.encode('opencode:$password'));
    dio.options.headers['Authorization'] = 'Basic $credentials';
  }

  // Error handling
  dio.interceptors.add(InterceptorsWrapper(
    onError: (error, handler) {
      if (error.response?.statusCode == 401) {
        // Handle auth failure — prompt for password
      }
      handler.next(error);
    },
  ));

  return dio;
}
```

### OpenAPI Code Generation

You can auto-generate a typed Dart client from `openapi.json`:

```yaml
# pubspec.yaml
dev_dependencies:
  openapi_generator: ^5.0.0

# openapi_generator.yaml
openapi_generator:
  input_spec:
    path: mobile-api-docs/openapi.json
  generator_name: dio
  output_directory: lib/api/generated
```

Or use `dart run openapi_generator_cli generate -i openapi.json -g dart-dio -o lib/api`.

---

## SSE Integration

This is the **core real-time channel**. All streaming AI output, permission requests, and state changes come through SSE.

### SSE Client

```dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SseClient {
  final String baseUrl;
  final String? password;
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;
  final _controller = StreamController<SseEvent>.broadcast();

  SseClient({required this.baseUrl, this.password});

  Stream<SseEvent> get events => _controller.stream;

  Future<void> connect() async {
    final headers = <String, String>{
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
    };
    if (password != null) {
      headers['Authorization'] = 'Basic ${base64Encode(utf8.encode('opencode:$password'))}';
    }

    final request = http.Request('GET', Uri.parse('$baseUrl/global/event'));
    request.headers.addAll(headers);

    final client = http.Client();
    final response = await client.send(request);

    _resetHeartbeatTimer();

    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    _subscription = lines.listen(
      (line) {
        if (line.startsWith('data: ')) {
          final json = line.substring(6);
          try {
            final data = jsonDecode(json) as Map<String, dynamic>;
            final payload = data['payload'] as Map<String, dynamic>? ?? data;
            final type = payload['type'] as String;
            final properties = payload['properties'] as Map<String, dynamic>? ?? {};

            if (type == 'server.heartbeat') {
              _resetHeartbeatTimer();
              return;
            }

            _controller.add(SseEvent(
              type: type,
              properties: properties,
              directory: data['directory'] as String?,
            ));
          } catch (e) {
            // Skip malformed events
          }
        }
      },
      onDone: () => _reconnect(),
      onError: (e) => _reconnect(),
    );
  }

  void _resetHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer(const Duration(seconds: 30), () {
      // No heartbeat in 30s — connection stale
      _reconnect();
    });
  }

  Future<void> _reconnect() async {
    await disconnect();
    await Future.delayed(const Duration(seconds: 3));
    connect(); // Retry
  }

  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    await _subscription?.cancel();
  }
}

class SseEvent {
  final String type;
  final Map<String, dynamic> properties;
  final String? directory;

  SseEvent({required this.type, required this.properties, this.directory});
}
```

### Event Routing

```dart
class EventRouter {
  final SseClient _sse;

  // Typed event streams
  final _sessionCreated = StreamController<Session>.broadcast();
  final _sessionUpdated = StreamController<Session>.broadcast();
  final _sessionDeleted = StreamController<Session>.broadcast();
  final _messageDelta = StreamController<MessageDelta>.broadcast();
  final _partUpdated = StreamController<Part>.broadcast();
  final _permissionAsked = StreamController<PermissionRequest>.broadcast();
  final _questionAsked = StreamController<QuestionRequest>.broadcast();
  final _sessionStatus = StreamController<SessionStatus>.broadcast();
  final _todoUpdated = StreamController<TodoUpdate>.broadcast();

  Stream<Session> get sessionCreated => _sessionCreated.stream;
  Stream<Session> get sessionUpdated => _sessionUpdated.stream;
  Stream<MessageDelta> get messageDelta => _messageDelta.stream;
  Stream<Part> get partUpdated => _partUpdated.stream;
  Stream<PermissionRequest> get permissionAsked => _permissionAsked.stream;
  Stream<QuestionRequest> get questionAsked => _questionAsked.stream;

  EventRouter(this._sse) {
    _sse.events.listen(_route);
  }

  void _route(SseEvent event) {
    switch (event.type) {
      case 'session.created':
        _sessionCreated.add(Session.fromJson(event.properties['info']));
      case 'session.updated':
        _sessionUpdated.add(Session.fromJson(event.properties['info']));
      case 'session.deleted':
        _sessionDeleted.add(Session.fromJson(event.properties['info']));
      case 'message.part.delta':
        _messageDelta.add(MessageDelta.fromJson(event.properties));
      case 'message.part.updated':
        _partUpdated.add(Part.fromJson(event.properties['part']));
      case 'permission.asked':
        _permissionAsked.add(PermissionRequest.fromJson(event.properties));
      case 'question.asked':
        _questionAsked.add(QuestionRequest.fromJson(event.properties));
      case 'session.status':
        _sessionStatus.add(SessionStatus.fromJson(event.properties));
      case 'todo.updated':
        _todoUpdated.add(TodoUpdate.fromJson(event.properties));
    }
  }
}
```

---

## Streaming Chat UI

The most important UX feature — showing AI output as it streams.

### State Model

```dart
class ChatState {
  final List<MessageWithParts> messages;
  final Map<String, StringBuffer> streamingParts; // partID -> accumulated text
  final String sessionStatus; // "idle" | "busy"

  // Apply a delta event
  ChatState applyDelta(MessageDelta delta) {
    final buffer = streamingParts.putIfAbsent(
      delta.partID,
      () => StringBuffer(),
    );
    buffer.write(delta.delta);
    return copyWith(streamingParts: {...streamingParts});
  }

  // Finalize a part (replace streaming buffer with final part)
  ChatState finalizePart(Part part) {
    streamingParts.remove(part.id);
    // Update the part in the corresponding message
    return copyWith(/* update messages list */);
  }
}
```

### Sending a Message

```dart
Future<void> sendMessage(String sessionId, String text) async {
  // Fire-and-forget — responses come via SSE
  await dio.post(
    '/session/$sessionId/prompt_async',
    data: {
      'parts': [
        {'type': 'text', 'text': text},
      ],
    },
  );
  // SSE will emit:
  //   message.updated (user message)
  //   message.updated (assistant message created)
  //   message.part.updated (text part started)
  //   message.part.delta (streaming text chunks)
  //   message.part.updated (part finalized)
  //   message.updated (assistant message completed with tokens/cost)
}
```

### Displaying Streaming Text

```dart
class StreamingTextWidget extends StatelessWidget {
  final String partId;
  final Map<String, StringBuffer> streamingParts;
  final List<Part> finalizedParts;

  @override
  Widget build(BuildContext context) {
    // Check if still streaming
    final buffer = streamingParts[partId];
    if (buffer != null) {
      return MarkdownBody(data: buffer.toString());
    }

    // Show finalized text
    final part = finalizedParts.firstWhere((p) => p.id == partId);
    return MarkdownBody(data: part.text);
  }
}
```

---

## Permission & Question Dialogs

### Permission Request Handler

```dart
void setupPermissionHandler(EventRouter events, Dio dio) {
  events.permissionAsked.listen((request) async {
    // Show dialog
    final reply = await showDialog<String>(
      context: navigatorKey.currentContext!,
      builder: (ctx) => AlertDialog(
        title: Text('Permission Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tool: ${request.tool}'),
            Text(request.description),
            if (request.input != null)
              Text('Input: ${jsonEncode(request.input)}',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'deny'),
            child: Text('Deny'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'allow_always'),
            child: Text('Always Allow'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'allow'),
            child: Text('Allow'),
          ),
        ],
      ),
    );

    if (reply != null) {
      await dio.post('/permission/${request.requestID}/reply', data: {
        'reply': reply,
      });
    }
  });
}
```

### Question Handler

```dart
void setupQuestionHandler(EventRouter events, Dio dio) {
  events.questionAsked.listen((question) async {
    final answers = await showDialog<List<String>>(
      context: navigatorKey.currentContext!,
      builder: (ctx) => QuestionDialog(
        question: question.question,
        options: question.options,
        multiple: question.multiple,
      ),
    );

    if (answers != null) {
      await dio.post('/question/${question.requestID}/reply', data: {
        'answers': answers,
      });
    } else {
      await dio.post('/question/${question.requestID}/reject');
    }
  });
}
```

---

## WebSocket Terminal

For an embedded terminal in the mobile app (optional advanced feature):

```dart
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:xterm/xterm.dart';

class RemoteTerminal {
  final Terminal terminal = Terminal();
  WebSocketChannel? _channel;

  Future<void> connect(String baseUrl, String ptyId, {String? password}) async {
    // Create PTY session first
    // final response = await dio.post('/pty', data: {'size': {'cols': 80, 'rows': 24}});
    // final ptyId = response.data['id'];

    final wsUrl = baseUrl.replaceFirst('http', 'ws');
    _channel = WebSocketChannel.connect(Uri.parse('$wsUrl/pty/$ptyId/connect'));

    // Terminal output → display
    _channel!.stream.listen((data) {
      if (data is String) {
        terminal.write(data);
      }
    });

    // Terminal input → server
    terminal.onOutput = (data) {
      _channel?.sink.add(data);
    };
  }

  void disconnect() {
    _channel?.sink.close();
  }
}
```

---

## State Management Considerations

### With Riverpod

```dart
// Server connection provider
final serverProvider = StateNotifierProvider<ServerNotifier, ServerState>((ref) {
  return ServerNotifier();
});

// SSE event stream
final sseProvider = StreamProvider<SseEvent>((ref) {
  final server = ref.watch(serverProvider);
  if (!server.isConnected) return const Stream.empty();
  return server.sseClient.events;
});

// Sessions list (auto-refreshes on SSE events)
final sessionsProvider = StateNotifierProvider<SessionsNotifier, List<Session>>((ref) {
  final notifier = SessionsNotifier(ref.read(dioProvider));

  // Listen for session events
  ref.listen(sseProvider, (prev, next) {
    next.whenData((event) {
      switch (event.type) {
        case 'session.created':
          notifier.addSession(Session.fromJson(event.properties['info']));
        case 'session.updated':
          notifier.updateSession(Session.fromJson(event.properties['info']));
        case 'session.deleted':
          notifier.removeSession(event.properties['info']['id']);
      }
    });
  });

  return notifier;
});

// Active chat messages (includes streaming state)
final chatProvider = StateNotifierProvider.family<ChatNotifier, ChatState, String>(
  (ref, sessionId) {
    final notifier = ChatNotifier(sessionId, ref.read(dioProvider));

    ref.listen(sseProvider, (prev, next) {
      next.whenData((event) {
        final props = event.properties;
        if (props['sessionID'] != sessionId &&
            props['info']?['sessionID'] != sessionId) return;

        switch (event.type) {
          case 'message.updated':
            notifier.onMessageUpdated(props['info']);
          case 'message.part.delta':
            notifier.onDelta(props['partID'], props['field'], props['delta']);
          case 'message.part.updated':
            notifier.onPartUpdated(props['part']);
          case 'message.part.removed':
            notifier.onPartRemoved(props['partID']);
          case 'session.status':
            notifier.onStatusChanged(props['status']);
        }
      });
    });

    return notifier;
  },
);
```

---

## Suggested Project Structure

```
lib/
├── main.dart
├── api/
│   ├── client.dart              # Dio setup, auth interceptor
│   ├── generated/               # OpenAPI-generated types and client
│   └── sse_client.dart          # SSE connection manager
├── models/
│   ├── session.dart
│   ├── message.dart
│   ├── part.dart
│   ├── project.dart
│   ├── permission.dart
│   └── question.dart
├── providers/                   # Riverpod providers
│   ├── server_provider.dart     # Connection state
│   ├── session_provider.dart    # Session list + CRUD
│   ├── chat_provider.dart       # Message streaming
│   └── event_provider.dart      # SSE event routing
├── screens/
│   ├── connect/                 # Server discovery + connect
│   │   ├── discover_screen.dart
│   │   └── manual_connect_screen.dart
│   ├── sessions/                # Session list
│   │   └── sessions_screen.dart
│   ├── chat/                    # Chat conversation
│   │   ├── chat_screen.dart
│   │   ├── message_bubble.dart
│   │   ├── streaming_text.dart
│   │   ├── tool_call_card.dart
│   │   └── prompt_input.dart
│   ├── terminal/                # PTY terminal (optional)
│   │   └── terminal_screen.dart
│   └── settings/                # Config, providers, MCP
│       ├── config_screen.dart
│       └── providers_screen.dart
├── widgets/
│   ├── permission_dialog.dart
│   ├── question_dialog.dart
│   ├── todo_list.dart
│   └── diff_viewer.dart
└── utils/
    ├── markdown.dart
    └── connection.dart
```

---

## Key Implementation Notes

1. **Use `prompt_async` over `prompt`** — The async variant returns 204 immediately and you get responses via SSE. This is more natural for mobile where you don't want to hold an HTTP connection open for minutes.

2. **Heartbeat monitoring** — If you don't receive `server.heartbeat` within ~30s, the connection is likely dead. Reconnect and refetch state.

3. **Offline tolerance** — Cache session list and recent messages locally. When reconnecting, refetch from the server to reconcile.

4. **Permission urgency** — `permission.asked` events block the AI until answered. Show these as high-priority notifications, even when the app is backgrounded.

5. **Delta accumulation** — `message.part.delta` events are the core of streaming. Accumulate them in a `StringBuffer` keyed by `partID`. When `message.part.updated` fires with the final content, swap the buffer for the finalized part.

6. **Tool call rendering** — Tool parts have a `state` that transitions: `pending` → `running` → `completed`/`error`. Show a loading spinner for `pending`/`running`, then the result for `completed`.

7. **Session status** — Show a "typing..." or spinner indicator when `session.status` reports `"busy"`.

8. **LAN only** — The server runs on localhost by default. The user must start it with `--hostname 0.0.0.0` (or `--mdns`) for the phone to reach it. Consider showing setup instructions in the app.
