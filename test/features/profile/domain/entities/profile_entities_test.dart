import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/features/profile/domain/entities/user_profile.dart';
import 'package:family_planner/features/profile/domain/entities/profile_stats.dart';

void main() {
  group('UserProfile', () {
    const profile = UserProfile(
      id: 'u1',
      displayName: 'Alice',
      avatarUrl: 'https://example.com/avatar.png',
      timezone: 'Europe/Moscow',
      bio: 'Hello!',
    );

    test('constructor assigns fields correctly', () {
      expect(profile.id, 'u1');
      expect(profile.displayName, 'Alice');
      expect(profile.avatarUrl, 'https://example.com/avatar.png');
      expect(profile.timezone, 'Europe/Moscow');
      expect(profile.bio, 'Hello!');
    });

    test('copyWith displayName', () {
      final updated = profile.copyWith(displayName: 'Bob');
      expect(updated.displayName, 'Bob');
      expect(updated.id, profile.id);
      expect(updated.avatarUrl, profile.avatarUrl);
      expect(updated.timezone, profile.timezone);
      expect(updated.bio, profile.bio);
    });

    test('copyWith avatarUrl', () {
      final updated =
          profile.copyWith(avatarUrl: 'https://example.com/new.png');
      expect(updated.avatarUrl, 'https://example.com/new.png');
      expect(updated.id, profile.id);
      expect(updated.displayName, profile.displayName);
    });

    test('copyWith bio', () {
      final updated = profile.copyWith(bio: 'Updated bio');
      expect(updated.bio, 'Updated bio');
      expect(updated.id, profile.id);
      expect(updated.displayName, profile.displayName);
    });

    test('copyWith(clearAvatar: true) nulls avatarUrl', () {
      final updated = profile.copyWith(clearAvatar: true);
      expect(updated.avatarUrl, isNull);
      expect(updated.id, profile.id);
      expect(updated.displayName, profile.displayName);
    });

    test('copyWith(clearAvatar: true) keeps avatarUrl null if already null',
        () {
      const noAvatar = UserProfile(
        id: 'u2',
        displayName: 'Bob',
        timezone: 'UTC',
      );
      final updated = noAvatar.copyWith(clearAvatar: true);
      expect(updated.avatarUrl, isNull);
    });

    test('UserProfile equality', () {
      const same = UserProfile(
        id: 'u1',
        displayName: 'Alice',
        avatarUrl: 'https://example.com/avatar.png',
        timezone: 'Europe/Moscow',
        bio: 'Hello!',
      );
      const different = UserProfile(
        id: 'u2',
        displayName: 'Bob',
        timezone: 'UTC',
      );
      expect(profile, equals(same));
      expect(profile, isNot(equals(different)));
    });

    test('UserProfile props match', () {
      expect(
        profile.props,
        ['u1', 'Alice', 'https://example.com/avatar.png', 'Europe/Moscow',
            'Hello!'],
      );
    });
  });

  group('ProfileStats', () {
    test('default constructor zero values', () {
      const stats = ProfileStats();
      expect(stats.totalAssigned, 0);
      expect(stats.completedTasks, 0);
      expect(stats.completedThisMonth, 0);
      expect(stats.completedThisWeek, 0);
    });

    test('with values', () {
      const stats = ProfileStats(
        totalAssigned: 10,
        completedTasks: 7,
        completedThisMonth: 5,
        completedThisWeek: 3,
      );
      expect(stats.totalAssigned, 10);
      expect(stats.completedTasks, 7);
      expect(stats.completedThisMonth, 5);
      expect(stats.completedThisWeek, 3);
    });

    test('completionRate 0 when total=0', () {
      const stats = ProfileStats();
      expect(stats.completionRate, 0);
    });

    test('completionRate = completed/total', () {
      const stats = ProfileStats(
        totalAssigned: 10,
        completedTasks: 7,
      );
      expect(stats.completionRate, 0.7);
    });

    test('ProfileStats equality', () {
      const stats1 = ProfileStats(
        totalAssigned: 10,
        completedTasks: 7,
        completedThisMonth: 5,
        completedThisWeek: 3,
      );
      const stats2 = ProfileStats(
        totalAssigned: 10,
        completedTasks: 7,
        completedThisMonth: 5,
        completedThisWeek: 3,
      );
      const stats3 = ProfileStats(
        totalAssigned: 5,
        completedTasks: 2,
      );
      expect(stats1, equals(stats2));
      expect(stats1, isNot(equals(stats3)));
    });

    test('ProfileStats props', () {
      const stats = ProfileStats(
        totalAssigned: 10,
        completedTasks: 7,
        completedThisMonth: 5,
        completedThisWeek: 3,
      );
      expect(stats.props, [10, 7, 5, 3]);
    });
  });
}
