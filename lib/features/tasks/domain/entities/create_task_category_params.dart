import 'package:equatable/equatable.dart';

/// Входные данные для создания категории.
final class CreateTaskCategoryParams extends Equatable {
  const CreateTaskCategoryParams({
    required this.householdId,
    required this.name,
    this.colorHex,
    this.iconName,
  });

  final String householdId;
  final String name;
  final String? colorHex;
  final String? iconName;

  @override
  List<Object?> get props => [householdId, name, colorHex, iconName];
}
