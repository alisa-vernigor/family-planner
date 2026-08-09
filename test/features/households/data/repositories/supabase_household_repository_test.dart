import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:family_planner/features/households/data/repositories/supabase_household_repository.dart';

typedef _Router = http.Response Function(http.Request request);

http.Response _json(Object body, http.Request request, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    request: request,
    headers: {'content-type': 'application/json'},
  );
}

SupabaseClient _buildClient(
  List<({String method, String path, Map<String, dynamic>? body})>
      capturedRequests, {
  required _Router router,
}) {
  final mockHttp = MockClient((request) async {
    Map<String, dynamic>? body;
    if (request.body.isNotEmpty) {
      try {
        body = jsonDecode(request.body) as Map<String, dynamic>;
      } catch (_) {}
    }
    capturedRequests.add((
      method: request.method,
      path: request.url.path,
      body: body,
    ));
    final path = request.url.path;
    if (path.startsWith('/auth/v1/')) {
      return _json({}, request);
    }
    if (path.startsWith('/storage/v1/') || path.startsWith('/realtime/v1/')) {
      return _json({}, request);
    }
    return router(request);
  });

  return SupabaseClient(
    'http://localhost:54321',
    'test-key',
    httpClient: mockHttp,
    authOptions: const AuthClientOptions(
      autoRefreshToken: false,
      authFlowType: AuthFlowType.implicit,
    ),
  );
}

void main() {
  group('SupabaseHouseholdRepository', () {
    late List<({String method, String path, Map<String, dynamic>? body})>
        captured;
    late _Router router;
    late SupabaseClient client;
    late SupabaseHouseholdRepository repo;

    setUp(() {
      captured = [];
      router = (request) => _json(const [], request);
      client = _buildClient(captured, router: (request) => router(request));
      repo = SupabaseHouseholdRepository(client: client);
    });

    void mockRouter(_Router r) {
      router = r;
    }

    test('getMyHouseholds парсит JOIN household_members→households и дедупит',
        () async {
      mockRouter((request) {
        expect(request.url.path, '/rest/v1/household_members');
        expect(request.method, 'GET');
        return _json([
          {'households': {'id': 'h1', 'name': 'Семья'}},
          // Дубликат по id должен отсеяться.
          {'households': {'id': 'h1', 'name': 'Семья'}},
          {'households': {'id': 'h2', 'name': 'Другая'}},
        ], request);
      });

      final households = await repo.getMyHouseholds();

      expect(households, hasLength(2));
      expect(households.first.id, 'h1');
      expect(households.first.name, 'Семья');
      expect(households.last.id, 'h2');

      final req = captured.singleWhere((r) => r.method == 'GET');
      expect(req.path, '/rest/v1/household_members');
    });

    test('create вызывает RPC create_household и парсит результат', () async {
      mockRouter((request) {
        expect(request.url.path, '/rest/v1/rpc/create_household');
        expect(request.method, 'POST');
        return _json({'id': 'h-new', 'name': 'Моя семья'}, request);
      });

      final household = await repo.create(name: 'Моя семья');

      expect(household.id, 'h-new');
      expect(household.name, 'Моя семья');

      final rpc = captured.singleWhere((r) => r.method == 'POST');
      expect(rpc.path, '/rest/v1/rpc/create_household');
      expect(rpc.body!['household_name'], 'Моя семья');
    });

    test('getMembers парсит JOIN household_members→profiles', () async {
      mockRouter((request) {
        expect(request.url.path, '/rest/v1/household_members');
        return _json([
          {
            'profile_id': 'user-1',
            'role': 'owner',
            'profiles': {
              'display_name': 'Алиса',
              'avatar_url': 'https://x/a.jpg',
            },
          },
          {
            'profile_id': 'user-2',
            'role': 'member',
            'profiles': {'display_name': 'Боб', 'avatar_url': null},
          },
        ], request);
      });

      final members = await repo.getMembers(householdId: 'h1');

      expect(members, hasLength(2));
      final owner = members.first;
      expect(owner.profileId, 'user-1');
      expect(owner.displayName, 'Алиса');
      expect(owner.avatarUrl, 'https://x/a.jpg');
      expect(owner.isOwner, isTrue);
      expect(members.last.isOwner, isFalse);
      expect(members.last.avatarUrl, isNull);
    });

    test('createInvitation шлёт RPC с нормализованным email', () async {
      final rpcCalls = <String>[];
      mockRouter((request) {
        expect(request.url.path, '/rest/v1/rpc/create_household_invitation');
        rpcCalls.add(request.body);
        return _json(const {}, request);
      });

      await repo.createInvitation(
        householdId: 'h1',
        email: '  Alice@Example.com  ',
      );

      expect(rpcCalls, hasLength(1));
      final body = jsonDecode(rpcCalls.single) as Map<String, dynamic>;
      expect(body['p_household_id'], 'h1');
      expect(body['p_email'], 'alice@example.com');
    });

    group('getPendingInvitations', () {
      test('парсит приглашения и подтягивает имена семей', () async {
        final paths = <String>[];
        mockRouter((request) {
          paths.add(request.url.path);
          if (request.url.path == '/rest/v1/household_invitations') {
            return _json([
              {
                'id': 'inv-1',
                'household_id': 'h1',
                'created_at': '2026-08-01T10:00:00.000Z',
                'expires_at': '2026-09-01T10:00:00.000Z',
                'invited_by_profile_id': 'user-2',
                'profiles': {'display_name': 'Боб'},
              },
            ], request);
          }
          if (request.url.path == '/rest/v1/households') {
            return _json([
              {'id': 'h1', 'name': 'Семья Боба'},
            ], request);
          }
          return _json(const [], request);
        });

        final invitations = await repo.getPendingInvitations();

        expect(invitations, hasLength(1));
        final inv = invitations.single;
        expect(inv.id, 'inv-1');
        expect(inv.householdName, 'Семья Боба');
        expect(inv.invitedByDisplayName, 'Боб');
        expect(inv.createdAt, DateTime.parse('2026-08-01T10:00:00.000Z'));
        expect(inv.expiresAt, DateTime.parse('2026-09-01T10:00:00.000Z'));
        expect(paths, contains('/rest/v1/households'));
      });

      test('неизвестная семья → дефолтное имя', () async {
        mockRouter((request) {
          if (request.url.path == '/rest/v1/household_invitations') {
            return _json([
              {
                'id': 'inv-1',
                'household_id': 'h-unknown',
                'created_at': '2026-08-01T10:00:00.000Z',
                'expires_at': '2026-09-01T10:00:00.000Z',
                'invited_by_profile_id': 'user-2',
                'profiles': null,
              },
            ], request);
          }
          if (request.url.path == '/rest/v1/households') {
            return _json(const [], request);
          }
          return _json(const [], request);
        });

        final invitations = await repo.getPendingInvitations();

        expect(invitations.single.householdName, 'Неизвестная семья');
        expect(invitations.single.invitedByDisplayName, 'Неизвестный');
      });

      test('пустой список не делает второй запрос к households', () async {
        mockRouter((request) {
          if (request.url.path == '/rest/v1/household_invitations') {
            return _json(const [], request);
          }
          return _json(const [], request);
        });

        final invitations = await repo.getPendingInvitations();

        expect(invitations, isEmpty);
        expect(
          captured.where((r) => r.path == '/rest/v1/households'),
          isEmpty,
        );
      });
    });

    test('acceptInvitation возвращает строку из RPC', () async {
      mockRouter((request) {
        expect(request.url.path, '/rest/v1/rpc/accept_household_invitation');
        return _json('h1', request);
      });

      final householdId = await repo.acceptInvitation(invitationId: 'inv-1');

      expect(householdId, 'h1');
      final rpc = captured.singleWhere((r) => r.method == 'POST');
      expect(rpc.body!['p_invitation_id'], 'inv-1');
    });

    test('declineInvitation шлёт RPC', () async {
      mockRouter((request) {
        expect(
          request.url.path,
          '/rest/v1/rpc/decline_household_invitation',
        );
        return _json(const {}, request);
      });

      await repo.declineInvitation(invitationId: 'inv-1');

      final rpc = captured.singleWhere((r) => r.method == 'POST');
      expect(rpc.body!['p_invitation_id'], 'inv-1');
    });

    test('leaveHousehold шлёт RPC с p_household_id', () async {
      mockRouter((request) {
        expect(request.url.path, '/rest/v1/rpc/leave_household');
        return _json(const {}, request);
      });

      await repo.leaveHousehold(householdId: 'h1');

      final rpc = captured.singleWhere((r) => r.method == 'POST');
      expect(rpc.body!['p_household_id'], 'h1');
    });

    test('removeMember шлёт RPC с обоими id', () async {
      mockRouter((request) {
        expect(request.url.path, '/rest/v1/rpc/remove_household_member');
        return _json(const {}, request);
      });

      await repo.removeMember(householdId: 'h1', profileId: 'user-2');

      final rpc = captured.singleWhere((r) => r.method == 'POST');
      expect(rpc.body!['p_household_id'], 'h1');
      expect(rpc.body!['p_profile_id'], 'user-2');
    });

    test('deleteHousehold шлёт RPC', () async {
      mockRouter((request) {
        expect(request.url.path, '/rest/v1/rpc/delete_household');
        return _json(const {}, request);
      });

      await repo.deleteHousehold(householdId: 'h1');

      final rpc = captured.singleWhere((r) => r.method == 'POST');
      expect(rpc.body!['p_household_id'], 'h1');
    });

    test('updateHousehold шлёт RPC с trim-имени', () async {
      mockRouter((request) {
        expect(request.url.path, '/rest/v1/rpc/update_household_name');
        return _json(const {}, request);
      });

      await repo.updateHousehold(householdId: 'h1', name: '  Новая  ');

      final rpc = captured.singleWhere((r) => r.method == 'POST');
      expect(rpc.body!['p_household_id'], 'h1');
      expect(rpc.body!['p_name'], 'Новая');
    });
  });
}
