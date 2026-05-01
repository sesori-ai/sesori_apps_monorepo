// ignore_for_file: no_slop_linter/avoid_as_cast, no_slop_linter/prefer_specific_type
import 'package:sesori_shared/sesori_shared.dart';
import 'package:test/test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Round-trip JSON compatibility
  // ---------------------------------------------------------------------------

  group('sessionStatus round-trip', () {
    test('busy status serializes and deserializes correctly', () {
      const event = SesoriSseEvent.sessionStatus(
        sessionID: 'ses_abc',
        status: SessionStatus.busy(),
      );
      final json = event.toJson();

      expect(json['type'], 'session.status');
      expect(json['sessionID'], 'ses_abc');
      expect((json['status'] as Map<String, dynamic>)['type'], 'busy');

      final parsed = SesoriSseEvent.fromJson(json);
      expect(parsed, isA<SesoriSessionStatus>());
      final cast = parsed as SesoriSessionStatus;
      expect(cast.sessionID, 'ses_abc');
      expect(cast.status, isA<SessionStatusBusy>());
    });

    test('idle status serializes and deserializes correctly', () {
      const event = SesoriSseEvent.sessionStatus(
        sessionID: 'ses_idle',
        status: SessionStatus.idle(),
      );
      final json = event.toJson();

      expect(json['type'], 'session.status');
      expect(json['sessionID'], 'ses_idle');
      expect((json['status'] as Map<String, dynamic>)['type'], 'idle');

      final parsed = SesoriSseEvent.fromJson(json);
      expect(parsed, isA<SesoriSessionStatus>());
      final cast = parsed as SesoriSessionStatus;
      expect(cast.sessionID, 'ses_idle');
      expect(cast.status, isA<SessionStatusIdle>());
    });

    test('retry status serializes and deserializes correctly', () {
      const event = SesoriSseEvent.sessionStatus(
        sessionID: 'ses_retry',
        status: SessionStatus.retry(attempt: 3, message: 'overload', next: 5000),
      );
      final json = event.toJson();

      expect(json['type'], 'session.status');
      expect(json['sessionID'], 'ses_retry');
      final statusJson = json['status'] as Map<String, dynamic>;
      expect(statusJson['type'], 'retry');
      expect(statusJson['attempt'], 3);
      expect(statusJson['message'], 'overload');
      expect(statusJson['next'], 5000);

      final parsed = SesoriSseEvent.fromJson(json);
      expect(parsed, isA<SesoriSessionStatus>());
      final cast = parsed as SesoriSessionStatus;
      expect(cast.sessionID, 'ses_retry');
      expect(cast.status, isA<SessionStatusRetry>());
      final retry = cast.status as SessionStatusRetry;
      expect(retry.attempt, 3);
      expect(retry.message, 'overload');
      expect(retry.next, 5000);
    });
  });

  group('sessionCreated round-trip', () {
    test('serializes and deserializes Session info correctly', () {
      const session = Session(
        id: 'ses_001',
        projectID: 'proj_001',
        directory: '/home/user/project',
        parentID: null,
        title: null,
        time: null,
        summary: null,
        pullRequest: null,
      );
      const event = SesoriSseEvent.sessionCreated(info: session);
      final json = event.toJson();

      expect(json['type'], 'session.created');
      final infoJson = json['info'] as Map<String, dynamic>;
      expect(infoJson['id'], 'ses_001');
      expect(infoJson['projectID'], 'proj_001');
      expect(infoJson['directory'], '/home/user/project');

      final parsed = SesoriSseEvent.fromJson(json);
      expect(parsed, isA<SesoriSessionCreated>());
      final cast = parsed as SesoriSessionCreated;
      expect(cast.info.id, 'ses_001');
      expect(cast.info.projectID, 'proj_001');
      expect(cast.info.directory, '/home/user/project');
    });
  });

  group('sessionUpdated round-trip', () {
    test('serializes and deserializes correctly', () {
      const session = Session(
        id: 'ses_002',
        projectID: 'proj_002',
        directory: '/home/user/other',
        parentID: null,
        title: 'My Session',
        time: null,
        summary: null,
        pullRequest: null,
      );
      const event = SesoriSseEvent.sessionUpdated(info: session);
      final json = event.toJson();

      expect(json['type'], 'session.updated');
      final infoJson = json['info'] as Map<String, dynamic>;
      expect(infoJson['id'], 'ses_002');
      expect(infoJson['title'], 'My Session');

      final parsed = SesoriSseEvent.fromJson(json);
      expect(parsed, isA<SesoriSessionUpdated>());
      final cast = parsed as SesoriSessionUpdated;
      expect(cast.info.id, 'ses_002');
      expect(cast.info.title, 'My Session');
    });
  });

  group('sessionDeleted round-trip', () {
    test('serializes and deserializes correctly', () {
      const session = Session(
        id: 'ses_003',
        projectID: 'proj_003',
        directory: '/deleted/path',
        parentID: null,
        title: null,
        time: null,
        summary: null,
        pullRequest: null,
      );
      const event = SesoriSseEvent.sessionDeleted(info: session);
      final json = event.toJson();

      expect(json['type'], 'session.deleted');
      final infoJson = json['info'] as Map<String, dynamic>;
      expect(infoJson['id'], 'ses_003');

      final parsed = SesoriSseEvent.fromJson(json);
      expect(parsed, isA<SesoriSessionDeleted>());
      final cast = parsed as SesoriSessionDeleted;
      expect(cast.info.id, 'ses_003');
    });
  });

  group('messageUpdated round-trip', () {
    test('serializes and deserializes Message info correctly', () {
      const message = Message.assistant(
        id: 'msg_001',
        sessionID: 'ses_abc',
        agent: null,
        modelID: null,
        providerID: null,
      );
      const event = SesoriSseEvent.messageUpdated(info: message);
      final json = event.toJson();

      expect(json['type'], 'message.updated');
      final infoJson = json['info'] as Map<String, dynamic>;
      expect(infoJson['id'], 'msg_001');
      expect(infoJson['sessionID'], 'ses_abc');
      expect(infoJson['role'], 'assistant');

      final parsed = SesoriSseEvent.fromJson(json);
      expect(parsed, isA<SesoriMessageUpdated>());
      final cast = parsed as SesoriMessageUpdated;
      expect(cast.info.id, 'msg_001');
      expect(cast.info.sessionID, 'ses_abc');
      expect(cast.info, isA<MessageAssistant>());
    });
  });

  group('serverHeartbeat round-trip', () {
    test('serializes and deserializes correctly', () {
      const event = SesoriSseEvent.serverHeartbeat();
      final json = event.toJson();

      expect(json['type'], 'server.heartbeat');

      final parsed = SesoriSseEvent.fromJson(json);
      expect(parsed, isA<SesoriServerHeartbeat>());
    });
  });

  group('serverConnected round-trip', () {
    test('serializes and deserializes correctly', () {
      const event = SesoriSseEvent.serverConnected();
      final json = event.toJson();

      expect(json['type'], 'server.connected');

      final parsed = SesoriSseEvent.fromJson(json);
      expect(parsed, isA<SesoriServerConnected>());
    });
  });

  // ---------------------------------------------------------------------------
  // projectsSummary serialization
  // ---------------------------------------------------------------------------

  group('projectsSummary serialization', () {
    test('serializes correctly', () {
      const event = SesoriSseEvent.projectsSummary(
        projects: [
          ProjectActivitySummary(
            id: '/foo',
            activeSessions: [
              ActiveSession(id: 's1'),
              ActiveSession(id: 's2'),
            ],
          ),
          ProjectActivitySummary(id: '/bar', activeSessions: []),
        ],
      );
      final json = event.toJson();

      expect(json['type'], 'projects.summary');
      expect(json['projects'], hasLength(2));
      final first = (json['projects'] as List)[0] as Map<String, dynamic>;
      expect(first['id'], '/foo');
      expect(first['activeSessions'], <Map<String, dynamic>>[
        {'id': 's1', 'mainAgentRunning': false, 'awaitingInput': false, 'childSessionIds': <String>[]},
        {'id': 's2', 'mainAgentRunning': false, 'awaitingInput': false, 'childSessionIds': <String>[]},
      ]);
      final second = (json['projects'] as List)[1] as Map<String, dynamic>;
      expect(second['id'], '/bar');
      expect(second['activeSessions'], <Map<String, dynamic>>[]);
    });

    test('deserializes correctly', () {
      final json = <String, dynamic>{
        'type': 'projects.summary',
        'projects': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': '/foo',
            'activeSessions': <Map<String, dynamic>>[
              {'id': 's1', 'mainAgentRunning': false, 'awaitingInput': false, 'childSessionIds': <String>[]},
              {'id': 's2', 'mainAgentRunning': false, 'awaitingInput': false, 'childSessionIds': <String>[]},
              {'id': 's3', 'mainAgentRunning': false, 'awaitingInput': false, 'childSessionIds': <String>[]},
            ],
          },
        ],
      };
      final event = SesoriSseEvent.fromJson(json);

      expect(event, isA<SesoriProjectsSummary>());
      final cast = event as SesoriProjectsSummary;
      expect(cast.projects, hasLength(1));
      expect(cast.projects.first.id, '/foo');
      expect(cast.projects.first.activeSessions.length, 3);
      expect(cast.projects.first.activeSessions[0].id, 's1');
      expect(cast.projects.first.activeSessions[1].id, 's2');
      expect(cast.projects.first.activeSessions[2].id, 's3');
    });

    test('round-trips correctly', () {
      const original = SesoriSseEvent.projectsSummary(
        projects: [
          ProjectActivitySummary(
            id: '/alpha',
            activeSessions: [
              ActiveSession(id: 's1'),
              ActiveSession(id: 's2'),
              ActiveSession(id: 's3'),
              ActiveSession(id: 's4'),
              ActiveSession(id: 's5'),
            ],
          ),
          ProjectActivitySummary(
            id: '/beta',
            activeSessions: [ActiveSession(id: 's1')],
          ),
          ProjectActivitySummary(id: '/gamma', activeSessions: []),
        ],
      );
      final json = original.toJson();
      final parsed = SesoriSseEvent.fromJson(json);

      expect(parsed, isA<SesoriProjectsSummary>());
      final cast = parsed as SesoriProjectsSummary;
      expect(cast.projects, hasLength(3));
      expect(cast.projects[0].id, '/alpha');
      expect(cast.projects[0].activeSessions.length, 5);
      expect(cast.projects[1].id, '/beta');
      expect(cast.projects[1].activeSessions.length, 1);
      expect(cast.projects[2].id, '/gamma');
      expect(cast.projects[2].activeSessions.length, 0);
    });

    test('empty projects list round-trips correctly', () {
      const event = SesoriSseEvent.projectsSummary(projects: []);
      final json = event.toJson();

      expect(json['type'], 'projects.summary');
      expect(json['projects'], isEmpty);

      final parsed = SesoriSseEvent.fromJson(json);
      expect(parsed, isA<SesoriProjectsSummary>());
      final cast = parsed as SesoriProjectsSummary;
      expect(cast.projects, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Session-scoped event marker (SesoriSessionEvent)
  // ---------------------------------------------------------------------------

  group('SesoriSessionEvent marker interface', () {
    test('sessionCreated implements SesoriSessionEvent', () {
      const created = SesoriSseEvent.sessionCreated(
        info: Session(
          id: 'x',
          projectID: 'p',
          directory: '/d',
          parentID: null,
          title: null,
          time: null,
          summary: null,
          pullRequest: null,
        ),
      );
      expect(created, isA<SesoriSessionEvent>());
    });

    test('sessionUpdated implements SesoriSessionEvent', () {
      const updated = SesoriSseEvent.sessionUpdated(
        info: Session(
          id: 'x',
          projectID: 'p',
          directory: '/d',
          parentID: null,
          title: null,
          time: null,
          summary: null,
          pullRequest: null,
        ),
      );
      expect(updated, isA<SesoriSessionEvent>());
    });

    test('sessionDeleted implements SesoriSessionEvent', () {
      const deleted = SesoriSseEvent.sessionDeleted(
        info: Session(
          id: 'x',
          projectID: 'p',
          directory: '/d',
          parentID: null,
          title: null,
          time: null,
          summary: null,
          pullRequest: null,
        ),
      );
      expect(deleted, isA<SesoriSessionEvent>());
    });

    test('sessionStatus implements SesoriSessionEvent', () {
      const status = SesoriSseEvent.sessionStatus(
        sessionID: 'x',
        status: SessionStatus.idle(),
      );
      expect(status, isA<SesoriSessionEvent>());
    });

    test('messageUpdated implements SesoriSessionEvent', () {
      const event = SesoriSseEvent.messageUpdated(
        info: Message.user(id: 'm', sessionID: 's', agent: null),
      );
      expect(event, isA<SesoriSessionEvent>());
    });

    test('projectsSummary does NOT implement SesoriSessionEvent', () {
      const event = SesoriSseEvent.projectsSummary(projects: []);
      expect(event, isNot(isA<SesoriSessionEvent>()));
    });

    test('serverHeartbeat does NOT implement SesoriSessionEvent', () {
      const event = SesoriSseEvent.serverHeartbeat();
      expect(event, isNot(isA<SesoriSessionEvent>()));
    });

    test('serverConnected does NOT implement SesoriSessionEvent', () {
      const event = SesoriSseEvent.serverConnected();
      expect(event, isNot(isA<SesoriSessionEvent>()));
    });
  });

  // ---------------------------------------------------------------------------
  // ProjectActivitySummary defaults
  // ---------------------------------------------------------------------------

  group('ProjectActivitySummary', () {
    test('requires id and activeSessions', () {
      const summary = ProjectActivitySummary(id: '/test', activeSessions: []);
      expect(summary.id, '/test');
      expect(summary.activeSessions, <ActiveSession>[]);
    });

    test('accepts explicit activeSessions list', () {
      const summary = ProjectActivitySummary(
        id: '/test',
        activeSessions: [
          ActiveSession(id: 's1'),
          ActiveSession(id: 's2'),
          ActiveSession(id: 's3'),
          ActiveSession(id: 's4'),
          ActiveSession(id: 's5'),
          ActiveSession(id: 's6'),
          ActiveSession(id: 's7'),
        ],
      );
      expect(summary.id, '/test');
      expect(summary.activeSessions.length, 7);
    });

    test('serializes id and activeSessions to JSON', () {
      const summary = ProjectActivitySummary(
        id: '/my/path',
        activeSessions: [
          ActiveSession(id: 's1'),
          ActiveSession(id: 's2'),
          ActiveSession(id: 's3'),
          ActiveSession(id: 's4'),
        ],
      );
      final json = summary.toJson();
      expect(json['id'], '/my/path');
      expect(json['activeSessions'], <Map<String, dynamic>>[
        {'id': 's1', 'mainAgentRunning': false, 'awaitingInput': false, 'childSessionIds': <String>[]},
        {'id': 's2', 'mainAgentRunning': false, 'awaitingInput': false, 'childSessionIds': <String>[]},
        {'id': 's3', 'mainAgentRunning': false, 'awaitingInput': false, 'childSessionIds': <String>[]},
        {'id': 's4', 'mainAgentRunning': false, 'awaitingInput': false, 'childSessionIds': <String>[]},
      ]);
    });

    test('deserializes from JSON correctly', () {
      final json = <String, dynamic>{
        'id': '/from/json',
        'activeSessions': <Map<String, dynamic>>[
          {'id': 's1', 'mainAgentRunning': false, 'awaitingInput': false, 'childSessionIds': <String>[]},
          {'id': 's2', 'mainAgentRunning': false, 'awaitingInput': false, 'childSessionIds': <String>[]},
          {'id': 's3', 'mainAgentRunning': false, 'awaitingInput': false, 'childSessionIds': <String>[]},
          {'id': 's4', 'mainAgentRunning': false, 'awaitingInput': false, 'childSessionIds': <String>[]},
          {'id': 's5', 'mainAgentRunning': false, 'awaitingInput': false, 'childSessionIds': <String>[]},
          {'id': 's6', 'mainAgentRunning': false, 'awaitingInput': false, 'childSessionIds': <String>[]},
          {'id': 's7', 'mainAgentRunning': false, 'awaitingInput': false, 'childSessionIds': <String>[]},
          {'id': 's8', 'mainAgentRunning': false, 'awaitingInput': false, 'childSessionIds': <String>[]},
          {'id': 's9', 'mainAgentRunning': false, 'awaitingInput': false, 'childSessionIds': <String>[]},
        ],
      };
      final summary = ProjectActivitySummary.fromJson(json);
      expect(summary.id, '/from/json');
      expect(summary.activeSessions.length, 9);
    });

    test('fromJson requires activeSessions', () {
      final json = {'id': '/no/sessions'};
      expect(
        () => ProjectActivitySummary.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Wire-format type strings — no regressions
  // ---------------------------------------------------------------------------

  group('wire-format type strings', () {
    test('sessionCreated uses session.created', () {
      final json = const SesoriSseEvent.sessionCreated(
        info: Session(
          id: 'i',
          projectID: 'p',
          directory: '/d',
          parentID: null,
          title: null,
          time: null,
          summary: null,
          pullRequest: null,
        ),
      ).toJson();
      expect(json['type'], 'session.created');
    });

    test('sessionUpdated uses session.updated', () {
      final json = const SesoriSseEvent.sessionUpdated(
        info: Session(
          id: 'i',
          projectID: 'p',
          directory: '/d',
          parentID: null,
          title: null,
          time: null,
          summary: null,
          pullRequest: null,
        ),
      ).toJson();
      expect(json['type'], 'session.updated');
    });

    test('sessionDeleted uses session.deleted', () {
      final json = const SesoriSseEvent.sessionDeleted(
        info: Session(
          id: 'i',
          projectID: 'p',
          directory: '/d',
          parentID: null,
          title: null,
          time: null,
          summary: null,
          pullRequest: null,
        ),
      ).toJson();
      expect(json['type'], 'session.deleted');
    });

    test('sessionStatus uses session.status', () {
      final json = const SesoriSseEvent.sessionStatus(
        sessionID: 'x',
        status: SessionStatus.busy(),
      ).toJson();
      expect(json['type'], 'session.status');
    });

    test('messageUpdated uses message.updated', () {
      final json = const SesoriSseEvent.messageUpdated(
        info: Message.user(id: 'm', sessionID: 's', agent: null),
      ).toJson();
      expect(json['type'], 'message.updated');
    });

    test('serverHeartbeat uses server.heartbeat', () {
      final json = const SesoriSseEvent.serverHeartbeat().toJson();
      expect(json['type'], 'server.heartbeat');
    });

    test('serverConnected uses server.connected', () {
      final json = const SesoriSseEvent.serverConnected().toJson();
      expect(json['type'], 'server.connected');
    });

    test('projectsSummary uses projects.summary', () {
      final json = const SesoriSseEvent.projectsSummary(projects: []).toJson();
      expect(json['type'], 'projects.summary');
    });
  });
}
