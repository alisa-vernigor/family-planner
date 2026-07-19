import 'package:equatable/equatable.dart';

final class Household extends Equatable {
  const Household({required this.id, required this.name});

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}
