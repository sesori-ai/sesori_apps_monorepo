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
        title: 'My Session',
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
      const message = Message(
        id: 'msg_001',
        sessionID: 'ses_abc',
        role: 'assistant',
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
      expect(cast.info.role, 'assistant');
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
          ProjectActivitySummary(worktree: '/foo', activeSessions: 2),
          ProjectActivitySummary(worktree: '/bar', activeSessions: 0),
        ],
      );
      final json = event.toJson();

      expect(json['type'], 'projects.summary');
      expect(json['projects'], hasLength(2));
      final first = (json['projects'] as List)[0] as Map<String, dynamic>;
      expect(first['worktree'], '/foo');
      expect(first['activeSessions'], 2);
      final second = (json['projects'] as List)[1] as Map<String, dynamic>;
      expect(second['worktree'], '/bar');
      expect(second['activeSessions'], 0);
    });

    test('deserializes correctly', () {
      final json = {
        'type': 'projects.summary',
        'projects': [
          {'worktree': '/foo', 'activeSessions': 3},
        ],
      };
      final event = SesoriSseEvent.fromJson(json);

      expect(event, isA<SesoriProjectsSummary>());
      final cast = event as SesoriProjectsSummary;
      expect(cast.projects, hasLength(1));
      expect(cast.projects.first.worktree, '/foo');
      expect(cast.projects.first.activeSessions, 3);
    });

    test('round-trips correctly', () {
      const original = SesoriSseEvent.projectsSummary(
        projects: [
          ProjectActivitySummary(worktree: '/alpha', activeSessions: 5),
          ProjectActivitySummary(worktree: '/beta', activeSessions: 1),
          ProjectActivitySummary(worktree: '/gamma', activeSessions: 0),
        ],
      );
      final json = original.toJson();
      final parsed = SesoriSseEvent.fromJson(json);

      expect(parsed, isA<SesoriProjectsSummary>());
      final cast = parsed as SesoriProjectsSummary;
      expect(cast.projects, hasLength(3));
      expect(cast.projects[0].worktree, '/alpha');
      expect(cast.projects[0].activeSessions, 5);
      expect(cast.projects[1].worktree, '/beta');
      expect(cast.projects[1].activeSessions, 1);
      expect(cast.projects[2].worktree, '/gamma');
      expect(cast.projects[2].activeSessions, 0);
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
        info: Session(id: 'x', projectID: 'p', directory: '/d'),
      );
      expect(created, isA<SesoriSessionEvent>());
    });

    test('sessionUpdated implements SesoriSessionEvent', () {
      const updated = SesoriSseEvent.sessionUpdated(
        info: Session(id: 'x', projectID: 'p', directory: '/d'),
      );
      expect(updated, isA<SesoriSessionEvent>());
    });

    test('sessionDeleted implements SesoriSessionEvent', () {
      const deleted = SesoriSseEvent.sessionDeleted(
        info: Session(id: 'x', projectID: 'p', directory: '/d'),
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
        info: Message(id: 'm', sessionID: 's', role: 'user'),
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
    test('defaults activeSessions to 0', () {
      const summary = ProjectActivitySummary(worktree: '/test');
      expect(summary.activeSessions, 0);
    });

    test('accepts explicit activeSessions value', () {
      const summary = ProjectActivitySummary(worktree: '/test', activeSessions: 7);
      expect(summary.worktree, '/test');
      expect(summary.activeSessions, 7);
    });

    test('serializes worktree and activeSessions to JSON', () {
      const summary = ProjectActivitySummary(worktree: '/my/path', activeSessions: 4);
      final json = summary.toJson();
      expect(json['worktree'], '/my/path');
      expect(json['activeSessions'], 4);
    });

    test('deserializes from JSON correctly', () {
      final json = {'worktree': '/from/json', 'activeSessions': 9};
      final summary = ProjectActivitySummary.fromJson(json);
      expect(summary.worktree, '/from/json');
      expect(summary.activeSessions, 9);
    });

    test('fromJson uses 0 as default when activeSessions absent', () {
      final json = {'worktree': '/no/count'};
      final summary = ProjectActivitySummary.fromJson(json);
      expect(summary.worktree, '/no/count');
      expect(summary.activeSessions, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // Wire-format type strings — no regressions
  // ---------------------------------------------------------------------------

  group('wire-format type strings', () {
    test('sessionCreated uses session.created', () {
      final json = const SesoriSseEvent.sessionCreated(
        info: Session(id: 'i', projectID: 'p', directory: '/d'),
      ).toJson();
      expect(json['type'], 'session.created');
    });

    test('sessionUpdated uses session.updated', () {
      final json = const SesoriSseEvent.sessionUpdated(
        info: Session(id: 'i', projectID: 'p', directory: '/d'),
      ).toJson();
      expect(json['type'], 'session.updated');
    });

    test('sessionDeleted uses session.deleted', () {
      final json = const SesoriSseEvent.sessionDeleted(
        info: Session(id: 'i', projectID: 'p', directory: '/d'),
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
        info: Message(id: 'm', sessionID: 's', role: 'user'),
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
