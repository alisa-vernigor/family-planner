import 'package:equatable/equatable.dart';

/// Тип уведомления в ленте (inbox).
enum NotificationKind { taskAssigned, taskCompleted, taskSkipped, invitation }

/// Одно событие в центре уведомлений.
///
/// Показывает, что произошло в семье:
/// — вам назначили задачу (`taskAssigned`);
/// — кто-то выполнил задачу (`taskCompleted`);
/// — кто-то пропустил задачу (`taskSkipped`);
/// — вас пригласили в семью (`invitation`).
///
/// Не хранит ссылку на «непрочитано»: read-статус живёт отдельно
/// (в локальном кэше/очереди sync), чтобы не требовать новых колонок
/// в Supabase.
final class NotificationItem extends Equatable {
  const NotificationItem({
    required this.id,
    required this.kind,
    required this.actorId,
    required this.actorName,
    required this.title,
    required this.subtitle,
    required this.occurredAt,
    this.taskId,
    this.taskStatus,
    this.invitationId,
    this.invitationStatus,
    this.householdId,
  });

  /// Уникальный ключ события: `task:<id>:<status>` или `invitation:<id>`.
  final String id;

  final NotificationKind kind;

  /// Профиль, совершивший действие (или создавший приглашение).
  final String actorId;
  final String actorName;

  /// Основной текст (например «Задача назначена»).
  final String title;

  /// Пояснение (например «Мария назначила вам задачу „Убраться"»).
  final String subtitle;

  final DateTime occurredAt;

  /// id задачи — если событие относится к задаче (для открытия редактора).
  final String? taskId;

  /// Текущий статус задачи на момент формирования ленты (для меню/меток).
  final String? taskStatus;

  /// id приглашения — для кнопок «Принять/Отклонить».
  final String? invitationId;

  /// Статус приглашения (pending / accepted / declined) — для кнопок.
  final String? invitationStatus;

  /// Семья, к которой относится событие (необходима для открытия задач).
  final String? householdId;

  bool get isInvitation => kind == NotificationKind.invitation;

  NotificationItem copyWith({
    String? taskStatus,
    String? invitationStatus,
  }) {
    return NotificationItem(
      id: id,
      kind: kind,
      actorId: actorId,
      actorName: actorName,
      title: title,
      subtitle: subtitle,
      occurredAt: occurredAt,
      taskId: taskId,
      taskStatus: taskStatus ?? this.taskStatus,
      invitationId: invitationId,
      invitationStatus: invitationStatus ?? this.invitationStatus,
      householdId: householdId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    kind,
    actorId,
    actorName,
    title,
    subtitle,
    occurredAt,
    taskId,
    taskStatus,
    invitationId,
    invitationStatus,
    householdId,
  ];
}
