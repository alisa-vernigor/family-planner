import 'package:equatable/equatable.dart';

final class ProfileStats extends Equatable {
  const ProfileStats({
    this.totalAssigned = 0,
    this.completedTasks = 0,
    this.completedThisMonth = 0,
    this.completedThisWeek = 0,
  });

  final int totalAssigned;
  final int completedTasks;
  final int completedThisMonth;
  final int completedThisWeek;

  double get completionRate =>
      totalAssigned > 0 ? completedTasks / totalAssigned : 0;

  @override
  List<Object?> get props =>
      [totalAssigned, completedTasks, completedThisMonth, completedThisWeek];
}
