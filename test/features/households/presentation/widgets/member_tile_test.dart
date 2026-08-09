import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:family_planner/features/households/domain/entities/household_member.dart';
import 'package:family_planner/features/households/presentation/widgets/member_tile.dart';
import 'package:family_planner/features/profile/domain/entities/profile_stats.dart';
import 'package:family_planner/features/profile/domain/entities/user_profile.dart';
import 'package:family_planner/features/profile/domain/repositories/profile_repository.dart';
import 'package:family_planner/features/profile/presentation/pages/profile_page.dart';

import '../../../../helpers/mock_repository_factory.dart';

void main() {
  final member = HouseholdMember(
    profileId: 'user-1',
    displayName: 'Анна',
    role: 'member',
  );
  final ownerMember = HouseholdMember(
    profileId: 'user-2',
    displayName: 'Влад',
    role: 'owner',
  );
  final memberWithAvatar = HouseholdMember(
    profileId: 'user-3',
    displayName: 'Ольга',
    avatarUrl: 'https://example.com/avatar.png',
    role: 'member',
  );

  Widget buildSubject({
    HouseholdMember? m,
    bool isOwner = false,
    bool isCurrentUser = false,
    VoidCallback? onRemove,
  }) {
    return MockRepositoryFactoryProvider(
      child: MaterialApp(
        home: Scaffold(
          body: MemberTile(
            member: m ?? member,
            isOwner: isOwner,
            isCurrentUser: isCurrentUser,
            onRemove: onRemove ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('показывает имя, роль и аватар-инициалы', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Анна'), findsOneWidget);
    expect(find.text('Участник'), findsOneWidget);
    expect(find.text('А'), findsOneWidget);
  });

  testWidgets('владелец семьи показывает бейдж', (tester) async {
    await tester.pumpWidget(buildSubject(m: ownerMember));

    expect(find.text('Владелец семьи'), findsOneWidget);
    expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
  });

  testWidgets('текущий пользователь показывает метку «вы»', (tester) async {
    await tester.pumpWidget(buildSubject(isCurrentUser: true));

    expect(find.text('вы'), findsOneWidget);
  });

  testWidgets('владелец семьи видит кнопку удаления для других участников', (
    tester,
  ) async {
    var removed = 0;
    await tester.pumpWidget(
      buildSubject(
        isOwner: true,
        onRemove: () => removed++,
      ),
    );

    final removeButton = find.byIcon(Icons.remove_circle_outline);
    expect(removeButton, findsOneWidget);

    await tester.tap(removeButton);
    await tester.pump();

    expect(removed, 1);
  });

  testWidgets('не-владелец без роли owner видит person_outline', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
  });

  testWidgets('владелец не видит кнопку удаления для себя', (tester) async {
    await tester.pumpWidget(
      buildSubject(m: ownerMember, isOwner: true, isCurrentUser: true),
    );

    expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
    expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
  });

  testWidgets('тап по tile открывает ProfilePage', (tester) async {
    final mocks = MockRepositoryFactory();
    when(() => mocks.profile.getProfile('user-1')).thenAnswer(
      (_) async => const UserProfile(
        id: 'user-1',
        displayName: 'Анна',
        timezone: 'Europe/Moscow',
      ),
    );
    when(() => mocks.profile.getStats('user-1')).thenAnswer(
      (_) async => const ProfileStats(),
    );

    await tester.pumpWidget(
      MockRepositoryFactoryProvider(
        mock: mocks,
        child: MaterialApp(
          home: Scaffold(
            body: MemberTile(
              member: member,
              isOwner: false,
              isCurrentUser: false,
              onRemove: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Анна'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfilePage), findsOneWidget);
  });

  testWidgets('аватар по URL показывает NetworkImage', (tester) async {
    debugNetworkImageHttpClientProvider = () => _FakeHttpClient();

    await tester.pumpWidget(buildSubject(m: memberWithAvatar));
    // Даём NetworkImage время попытаться загрузиться.
    await tester.pump();

    final circleAvatar = tester.widget<CircleAvatar>(
      find.byType(CircleAvatar),
    );
    expect(circleAvatar.backgroundImage, isA<NetworkImage>());
    // Инициалы не показаны при наличии аватара.
    expect(find.text('О'), findsNothing);

    // Сбрасываем ДО конца теста (иначе invariant-проверка упадёт).
    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('пустое имя показывает «?»', (tester) async {
    final empty = HouseholdMember(
      profileId: 'user-4',
      displayName: '',
      role: 'member',
    );
    await tester.pumpWidget(buildSubject(m: empty));

    expect(find.text('?'), findsOneWidget);
  });
}

/// Оборачивает тест в RepositoryProvider&lt;ProfileRepository&gt; для ProfilePage.
final class MockRepositoryFactoryProvider extends StatelessWidget {
  const MockRepositoryFactoryProvider({required this.child, this.mock, super.key});

  final Widget child;
  final MockRepositoryFactory? mock;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<ProfileRepository>(
      create: (_) => mock?.profile ?? MockProfileRepository(),
      child: child,
    );
  }
}

/// Фейковый HttpClient, возвращающий прозрачный PNG, чтобы NetworkImage
/// не падал в widget-тестах.
final class _FakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpClientRequest();

  @override
  Future<HttpClientRequest> get(String host, int port, String path) async =>
      _FakeHttpClientRequest();

  @override
  bool autoUncompress = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final class _FakeHttpClientRequest implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final class _FakeHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final class _FakeHttpClientResponse implements HttpClientResponse {
  static final Uint8List _pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  @override
  int get statusCode => 200;

  @override
  int get contentLength => _pngBytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_pngBytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
