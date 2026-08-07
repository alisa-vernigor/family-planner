// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TaskOccurrencesTable extends TaskOccurrences
    with TableInfo<$TaskOccurrencesTable, TaskOccurrence> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskOccurrencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _householdIdMeta = const VerificationMeta(
    'householdId',
  );
  @override
  late final GeneratedColumn<String> householdId = GeneratedColumn<String>(
    'household_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _estimatedDurationMinutesMeta =
      const VerificationMeta('estimatedDurationMinutes');
  @override
  late final GeneratedColumn<int> estimatedDurationMinutes =
      GeneratedColumn<int>(
        'estimated_duration_minutes',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _plannedForMeta = const VerificationMeta(
    'plannedFor',
  );
  @override
  late final GeneratedColumn<String> plannedFor = GeneratedColumn<String>(
    'planned_for',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deadlineMeta = const VerificationMeta(
    'deadline',
  );
  @override
  late final GeneratedColumn<String> deadline = GeneratedColumn<String>(
    'deadline',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _assignedMemberIdMeta = const VerificationMeta(
    'assignedMemberId',
  );
  @override
  late final GeneratedColumn<String> assignedMemberId = GeneratedColumn<String>(
    'assigned_member_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pinnedMemberIdMeta = const VerificationMeta(
    'pinnedMemberId',
  );
  @override
  late final GeneratedColumn<String> pinnedMemberId = GeneratedColumn<String>(
    'pinned_member_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<String> completedAt = GeneratedColumn<String>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _allowedMemberIdsMeta = const VerificationMeta(
    'allowedMemberIds',
  );
  @override
  late final GeneratedColumn<String> allowedMemberIds = GeneratedColumn<String>(
    'allowed_member_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  @override
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
    'template_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurrenceTypeMeta = const VerificationMeta(
    'recurrenceType',
  );
  @override
  late final GeneratedColumn<String> recurrenceType = GeneratedColumn<String>(
    'recurrence_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _intervalDaysMeta = const VerificationMeta(
    'intervalDays',
  );
  @override
  late final GeneratedColumn<int> intervalDays = GeneratedColumn<int>(
    'interval_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weekdaysMeta = const VerificationMeta(
    'weekdays',
  );
  @override
  late final GeneratedColumn<String> weekdays = GeneratedColumn<String>(
    'weekdays',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurrenceStartDateMeta =
      const VerificationMeta('recurrenceStartDate');
  @override
  late final GeneratedColumn<String> recurrenceStartDate =
      GeneratedColumn<String>(
        'recurrence_start_date',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _recurrenceEndDateMeta = const VerificationMeta(
    'recurrenceEndDate',
  );
  @override
  late final GeneratedColumn<String> recurrenceEndDate =
      GeneratedColumn<String>(
        'recurrence_end_date',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    householdId,
    title,
    description,
    estimatedDurationMinutes,
    plannedFor,
    deadline,
    assignedMemberId,
    pinnedMemberId,
    status,
    createdAt,
    completedAt,
    updatedAt,
    priority,
    allowedMemberIds,
    templateId,
    recurrenceType,
    intervalDays,
    weekdays,
    recurrenceStartDate,
    recurrenceEndDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_occurrences';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskOccurrence> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('household_id')) {
      context.handle(
        _householdIdMeta,
        householdId.isAcceptableOrUnknown(
          data['household_id']!,
          _householdIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_householdIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('estimated_duration_minutes')) {
      context.handle(
        _estimatedDurationMinutesMeta,
        estimatedDurationMinutes.isAcceptableOrUnknown(
          data['estimated_duration_minutes']!,
          _estimatedDurationMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_estimatedDurationMinutesMeta);
    }
    if (data.containsKey('planned_for')) {
      context.handle(
        _plannedForMeta,
        plannedFor.isAcceptableOrUnknown(data['planned_for']!, _plannedForMeta),
      );
    } else if (isInserting) {
      context.missing(_plannedForMeta);
    }
    if (data.containsKey('deadline')) {
      context.handle(
        _deadlineMeta,
        deadline.isAcceptableOrUnknown(data['deadline']!, _deadlineMeta),
      );
    }
    if (data.containsKey('assigned_member_id')) {
      context.handle(
        _assignedMemberIdMeta,
        assignedMemberId.isAcceptableOrUnknown(
          data['assigned_member_id']!,
          _assignedMemberIdMeta,
        ),
      );
    }
    if (data.containsKey('pinned_member_id')) {
      context.handle(
        _pinnedMemberIdMeta,
        pinnedMemberId.isAcceptableOrUnknown(
          data['pinned_member_id']!,
          _pinnedMemberIdMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('allowed_member_ids')) {
      context.handle(
        _allowedMemberIdsMeta,
        allowedMemberIds.isAcceptableOrUnknown(
          data['allowed_member_ids']!,
          _allowedMemberIdsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_allowedMemberIdsMeta);
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    }
    if (data.containsKey('recurrence_type')) {
      context.handle(
        _recurrenceTypeMeta,
        recurrenceType.isAcceptableOrUnknown(
          data['recurrence_type']!,
          _recurrenceTypeMeta,
        ),
      );
    }
    if (data.containsKey('interval_days')) {
      context.handle(
        _intervalDaysMeta,
        intervalDays.isAcceptableOrUnknown(
          data['interval_days']!,
          _intervalDaysMeta,
        ),
      );
    }
    if (data.containsKey('weekdays')) {
      context.handle(
        _weekdaysMeta,
        weekdays.isAcceptableOrUnknown(data['weekdays']!, _weekdaysMeta),
      );
    }
    if (data.containsKey('recurrence_start_date')) {
      context.handle(
        _recurrenceStartDateMeta,
        recurrenceStartDate.isAcceptableOrUnknown(
          data['recurrence_start_date']!,
          _recurrenceStartDateMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_end_date')) {
      context.handle(
        _recurrenceEndDateMeta,
        recurrenceEndDate.isAcceptableOrUnknown(
          data['recurrence_end_date']!,
          _recurrenceEndDateMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskOccurrence map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskOccurrence(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      householdId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}household_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      estimatedDurationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estimated_duration_minutes'],
      )!,
      plannedFor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}planned_for'],
      )!,
      deadline: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deadline'],
      ),
      assignedMemberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assigned_member_id'],
      ),
      pinnedMemberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pinned_member_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      ),
      allowedMemberIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}allowed_member_ids'],
      )!,
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_id'],
      ),
      recurrenceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_type'],
      ),
      intervalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_days'],
      ),
      weekdays: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}weekdays'],
      ),
      recurrenceStartDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_start_date'],
      ),
      recurrenceEndDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_end_date'],
      ),
    );
  }

  @override
  $TaskOccurrencesTable createAlias(String alias) {
    return $TaskOccurrencesTable(attachedDatabase, alias);
  }
}

class TaskOccurrence extends DataClass implements Insertable<TaskOccurrence> {
  final String id;
  final String householdId;
  final String title;
  final String? description;
  final int estimatedDurationMinutes;
  final String plannedFor;
  final String? deadline;
  final String? assignedMemberId;
  final String? pinnedMemberId;
  final String status;
  final String createdAt;
  final String? completedAt;
  final String? updatedAt;
  final int? priority;
  final String allowedMemberIds;
  final String? templateId;
  final String? recurrenceType;
  final int? intervalDays;
  final String? weekdays;
  final String? recurrenceStartDate;
  final String? recurrenceEndDate;
  const TaskOccurrence({
    required this.id,
    required this.householdId,
    required this.title,
    this.description,
    required this.estimatedDurationMinutes,
    required this.plannedFor,
    this.deadline,
    this.assignedMemberId,
    this.pinnedMemberId,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.updatedAt,
    this.priority,
    required this.allowedMemberIds,
    this.templateId,
    this.recurrenceType,
    this.intervalDays,
    this.weekdays,
    this.recurrenceStartDate,
    this.recurrenceEndDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['household_id'] = Variable<String>(householdId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['estimated_duration_minutes'] = Variable<int>(estimatedDurationMinutes);
    map['planned_for'] = Variable<String>(plannedFor);
    if (!nullToAbsent || deadline != null) {
      map['deadline'] = Variable<String>(deadline);
    }
    if (!nullToAbsent || assignedMemberId != null) {
      map['assigned_member_id'] = Variable<String>(assignedMemberId);
    }
    if (!nullToAbsent || pinnedMemberId != null) {
      map['pinned_member_id'] = Variable<String>(pinnedMemberId);
    }
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<String>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<String>(completedAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || priority != null) {
      map['priority'] = Variable<int>(priority);
    }
    map['allowed_member_ids'] = Variable<String>(allowedMemberIds);
    if (!nullToAbsent || templateId != null) {
      map['template_id'] = Variable<String>(templateId);
    }
    if (!nullToAbsent || recurrenceType != null) {
      map['recurrence_type'] = Variable<String>(recurrenceType);
    }
    if (!nullToAbsent || intervalDays != null) {
      map['interval_days'] = Variable<int>(intervalDays);
    }
    if (!nullToAbsent || weekdays != null) {
      map['weekdays'] = Variable<String>(weekdays);
    }
    if (!nullToAbsent || recurrenceStartDate != null) {
      map['recurrence_start_date'] = Variable<String>(recurrenceStartDate);
    }
    if (!nullToAbsent || recurrenceEndDate != null) {
      map['recurrence_end_date'] = Variable<String>(recurrenceEndDate);
    }
    return map;
  }

  TaskOccurrencesCompanion toCompanion(bool nullToAbsent) {
    return TaskOccurrencesCompanion(
      id: Value(id),
      householdId: Value(householdId),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      estimatedDurationMinutes: Value(estimatedDurationMinutes),
      plannedFor: Value(plannedFor),
      deadline: deadline == null && nullToAbsent
          ? const Value.absent()
          : Value(deadline),
      assignedMemberId: assignedMemberId == null && nullToAbsent
          ? const Value.absent()
          : Value(assignedMemberId),
      pinnedMemberId: pinnedMemberId == null && nullToAbsent
          ? const Value.absent()
          : Value(pinnedMemberId),
      status: Value(status),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      priority: priority == null && nullToAbsent
          ? const Value.absent()
          : Value(priority),
      allowedMemberIds: Value(allowedMemberIds),
      templateId: templateId == null && nullToAbsent
          ? const Value.absent()
          : Value(templateId),
      recurrenceType: recurrenceType == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceType),
      intervalDays: intervalDays == null && nullToAbsent
          ? const Value.absent()
          : Value(intervalDays),
      weekdays: weekdays == null && nullToAbsent
          ? const Value.absent()
          : Value(weekdays),
      recurrenceStartDate: recurrenceStartDate == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceStartDate),
      recurrenceEndDate: recurrenceEndDate == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceEndDate),
    );
  }

  factory TaskOccurrence.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskOccurrence(
      id: serializer.fromJson<String>(json['id']),
      householdId: serializer.fromJson<String>(json['householdId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      estimatedDurationMinutes: serializer.fromJson<int>(
        json['estimatedDurationMinutes'],
      ),
      plannedFor: serializer.fromJson<String>(json['plannedFor']),
      deadline: serializer.fromJson<String?>(json['deadline']),
      assignedMemberId: serializer.fromJson<String?>(json['assignedMemberId']),
      pinnedMemberId: serializer.fromJson<String?>(json['pinnedMemberId']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      completedAt: serializer.fromJson<String?>(json['completedAt']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
      priority: serializer.fromJson<int?>(json['priority']),
      allowedMemberIds: serializer.fromJson<String>(json['allowedMemberIds']),
      templateId: serializer.fromJson<String?>(json['templateId']),
      recurrenceType: serializer.fromJson<String?>(json['recurrenceType']),
      intervalDays: serializer.fromJson<int?>(json['intervalDays']),
      weekdays: serializer.fromJson<String?>(json['weekdays']),
      recurrenceStartDate: serializer.fromJson<String?>(
        json['recurrenceStartDate'],
      ),
      recurrenceEndDate: serializer.fromJson<String?>(
        json['recurrenceEndDate'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'householdId': serializer.toJson<String>(householdId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'estimatedDurationMinutes': serializer.toJson<int>(
        estimatedDurationMinutes,
      ),
      'plannedFor': serializer.toJson<String>(plannedFor),
      'deadline': serializer.toJson<String?>(deadline),
      'assignedMemberId': serializer.toJson<String?>(assignedMemberId),
      'pinnedMemberId': serializer.toJson<String?>(pinnedMemberId),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<String>(createdAt),
      'completedAt': serializer.toJson<String?>(completedAt),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'priority': serializer.toJson<int?>(priority),
      'allowedMemberIds': serializer.toJson<String>(allowedMemberIds),
      'templateId': serializer.toJson<String?>(templateId),
      'recurrenceType': serializer.toJson<String?>(recurrenceType),
      'intervalDays': serializer.toJson<int?>(intervalDays),
      'weekdays': serializer.toJson<String?>(weekdays),
      'recurrenceStartDate': serializer.toJson<String?>(recurrenceStartDate),
      'recurrenceEndDate': serializer.toJson<String?>(recurrenceEndDate),
    };
  }

  TaskOccurrence copyWith({
    String? id,
    String? householdId,
    String? title,
    Value<String?> description = const Value.absent(),
    int? estimatedDurationMinutes,
    String? plannedFor,
    Value<String?> deadline = const Value.absent(),
    Value<String?> assignedMemberId = const Value.absent(),
    Value<String?> pinnedMemberId = const Value.absent(),
    String? status,
    String? createdAt,
    Value<String?> completedAt = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
    Value<int?> priority = const Value.absent(),
    String? allowedMemberIds,
    Value<String?> templateId = const Value.absent(),
    Value<String?> recurrenceType = const Value.absent(),
    Value<int?> intervalDays = const Value.absent(),
    Value<String?> weekdays = const Value.absent(),
    Value<String?> recurrenceStartDate = const Value.absent(),
    Value<String?> recurrenceEndDate = const Value.absent(),
  }) => TaskOccurrence(
    id: id ?? this.id,
    householdId: householdId ?? this.householdId,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    estimatedDurationMinutes:
        estimatedDurationMinutes ?? this.estimatedDurationMinutes,
    plannedFor: plannedFor ?? this.plannedFor,
    deadline: deadline.present ? deadline.value : this.deadline,
    assignedMemberId: assignedMemberId.present
        ? assignedMemberId.value
        : this.assignedMemberId,
    pinnedMemberId: pinnedMemberId.present
        ? pinnedMemberId.value
        : this.pinnedMemberId,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    priority: priority.present ? priority.value : this.priority,
    allowedMemberIds: allowedMemberIds ?? this.allowedMemberIds,
    templateId: templateId.present ? templateId.value : this.templateId,
    recurrenceType: recurrenceType.present
        ? recurrenceType.value
        : this.recurrenceType,
    intervalDays: intervalDays.present ? intervalDays.value : this.intervalDays,
    weekdays: weekdays.present ? weekdays.value : this.weekdays,
    recurrenceStartDate: recurrenceStartDate.present
        ? recurrenceStartDate.value
        : this.recurrenceStartDate,
    recurrenceEndDate: recurrenceEndDate.present
        ? recurrenceEndDate.value
        : this.recurrenceEndDate,
  );
  TaskOccurrence copyWithCompanion(TaskOccurrencesCompanion data) {
    return TaskOccurrence(
      id: data.id.present ? data.id.value : this.id,
      householdId: data.householdId.present
          ? data.householdId.value
          : this.householdId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      estimatedDurationMinutes: data.estimatedDurationMinutes.present
          ? data.estimatedDurationMinutes.value
          : this.estimatedDurationMinutes,
      plannedFor: data.plannedFor.present
          ? data.plannedFor.value
          : this.plannedFor,
      deadline: data.deadline.present ? data.deadline.value : this.deadline,
      assignedMemberId: data.assignedMemberId.present
          ? data.assignedMemberId.value
          : this.assignedMemberId,
      pinnedMemberId: data.pinnedMemberId.present
          ? data.pinnedMemberId.value
          : this.pinnedMemberId,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      priority: data.priority.present ? data.priority.value : this.priority,
      allowedMemberIds: data.allowedMemberIds.present
          ? data.allowedMemberIds.value
          : this.allowedMemberIds,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
      recurrenceType: data.recurrenceType.present
          ? data.recurrenceType.value
          : this.recurrenceType,
      intervalDays: data.intervalDays.present
          ? data.intervalDays.value
          : this.intervalDays,
      weekdays: data.weekdays.present ? data.weekdays.value : this.weekdays,
      recurrenceStartDate: data.recurrenceStartDate.present
          ? data.recurrenceStartDate.value
          : this.recurrenceStartDate,
      recurrenceEndDate: data.recurrenceEndDate.present
          ? data.recurrenceEndDate.value
          : this.recurrenceEndDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskOccurrence(')
          ..write('id: $id, ')
          ..write('householdId: $householdId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('estimatedDurationMinutes: $estimatedDurationMinutes, ')
          ..write('plannedFor: $plannedFor, ')
          ..write('deadline: $deadline, ')
          ..write('assignedMemberId: $assignedMemberId, ')
          ..write('pinnedMemberId: $pinnedMemberId, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('priority: $priority, ')
          ..write('allowedMemberIds: $allowedMemberIds, ')
          ..write('templateId: $templateId, ')
          ..write('recurrenceType: $recurrenceType, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('weekdays: $weekdays, ')
          ..write('recurrenceStartDate: $recurrenceStartDate, ')
          ..write('recurrenceEndDate: $recurrenceEndDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    householdId,
    title,
    description,
    estimatedDurationMinutes,
    plannedFor,
    deadline,
    assignedMemberId,
    pinnedMemberId,
    status,
    createdAt,
    completedAt,
    updatedAt,
    priority,
    allowedMemberIds,
    templateId,
    recurrenceType,
    intervalDays,
    weekdays,
    recurrenceStartDate,
    recurrenceEndDate,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskOccurrence &&
          other.id == this.id &&
          other.householdId == this.householdId &&
          other.title == this.title &&
          other.description == this.description &&
          other.estimatedDurationMinutes == this.estimatedDurationMinutes &&
          other.plannedFor == this.plannedFor &&
          other.deadline == this.deadline &&
          other.assignedMemberId == this.assignedMemberId &&
          other.pinnedMemberId == this.pinnedMemberId &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt &&
          other.updatedAt == this.updatedAt &&
          other.priority == this.priority &&
          other.allowedMemberIds == this.allowedMemberIds &&
          other.templateId == this.templateId &&
          other.recurrenceType == this.recurrenceType &&
          other.intervalDays == this.intervalDays &&
          other.weekdays == this.weekdays &&
          other.recurrenceStartDate == this.recurrenceStartDate &&
          other.recurrenceEndDate == this.recurrenceEndDate);
}

class TaskOccurrencesCompanion extends UpdateCompanion<TaskOccurrence> {
  final Value<String> id;
  final Value<String> householdId;
  final Value<String> title;
  final Value<String?> description;
  final Value<int> estimatedDurationMinutes;
  final Value<String> plannedFor;
  final Value<String?> deadline;
  final Value<String?> assignedMemberId;
  final Value<String?> pinnedMemberId;
  final Value<String> status;
  final Value<String> createdAt;
  final Value<String?> completedAt;
  final Value<String?> updatedAt;
  final Value<int?> priority;
  final Value<String> allowedMemberIds;
  final Value<String?> templateId;
  final Value<String?> recurrenceType;
  final Value<int?> intervalDays;
  final Value<String?> weekdays;
  final Value<String?> recurrenceStartDate;
  final Value<String?> recurrenceEndDate;
  final Value<int> rowid;
  const TaskOccurrencesCompanion({
    this.id = const Value.absent(),
    this.householdId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.estimatedDurationMinutes = const Value.absent(),
    this.plannedFor = const Value.absent(),
    this.deadline = const Value.absent(),
    this.assignedMemberId = const Value.absent(),
    this.pinnedMemberId = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.priority = const Value.absent(),
    this.allowedMemberIds = const Value.absent(),
    this.templateId = const Value.absent(),
    this.recurrenceType = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.weekdays = const Value.absent(),
    this.recurrenceStartDate = const Value.absent(),
    this.recurrenceEndDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskOccurrencesCompanion.insert({
    required String id,
    required String householdId,
    required String title,
    this.description = const Value.absent(),
    required int estimatedDurationMinutes,
    required String plannedFor,
    this.deadline = const Value.absent(),
    this.assignedMemberId = const Value.absent(),
    this.pinnedMemberId = const Value.absent(),
    required String status,
    required String createdAt,
    this.completedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.priority = const Value.absent(),
    required String allowedMemberIds,
    this.templateId = const Value.absent(),
    this.recurrenceType = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.weekdays = const Value.absent(),
    this.recurrenceStartDate = const Value.absent(),
    this.recurrenceEndDate = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       householdId = Value(householdId),
       title = Value(title),
       estimatedDurationMinutes = Value(estimatedDurationMinutes),
       plannedFor = Value(plannedFor),
       status = Value(status),
       createdAt = Value(createdAt),
       allowedMemberIds = Value(allowedMemberIds);
  static Insertable<TaskOccurrence> custom({
    Expression<String>? id,
    Expression<String>? householdId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<int>? estimatedDurationMinutes,
    Expression<String>? plannedFor,
    Expression<String>? deadline,
    Expression<String>? assignedMemberId,
    Expression<String>? pinnedMemberId,
    Expression<String>? status,
    Expression<String>? createdAt,
    Expression<String>? completedAt,
    Expression<String>? updatedAt,
    Expression<int>? priority,
    Expression<String>? allowedMemberIds,
    Expression<String>? templateId,
    Expression<String>? recurrenceType,
    Expression<int>? intervalDays,
    Expression<String>? weekdays,
    Expression<String>? recurrenceStartDate,
    Expression<String>? recurrenceEndDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (householdId != null) 'household_id': householdId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (estimatedDurationMinutes != null)
        'estimated_duration_minutes': estimatedDurationMinutes,
      if (plannedFor != null) 'planned_for': plannedFor,
      if (deadline != null) 'deadline': deadline,
      if (assignedMemberId != null) 'assigned_member_id': assignedMemberId,
      if (pinnedMemberId != null) 'pinned_member_id': pinnedMemberId,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (priority != null) 'priority': priority,
      if (allowedMemberIds != null) 'allowed_member_ids': allowedMemberIds,
      if (templateId != null) 'template_id': templateId,
      if (recurrenceType != null) 'recurrence_type': recurrenceType,
      if (intervalDays != null) 'interval_days': intervalDays,
      if (weekdays != null) 'weekdays': weekdays,
      if (recurrenceStartDate != null)
        'recurrence_start_date': recurrenceStartDate,
      if (recurrenceEndDate != null) 'recurrence_end_date': recurrenceEndDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskOccurrencesCompanion copyWith({
    Value<String>? id,
    Value<String>? householdId,
    Value<String>? title,
    Value<String?>? description,
    Value<int>? estimatedDurationMinutes,
    Value<String>? plannedFor,
    Value<String?>? deadline,
    Value<String?>? assignedMemberId,
    Value<String?>? pinnedMemberId,
    Value<String>? status,
    Value<String>? createdAt,
    Value<String?>? completedAt,
    Value<String?>? updatedAt,
    Value<int?>? priority,
    Value<String>? allowedMemberIds,
    Value<String?>? templateId,
    Value<String?>? recurrenceType,
    Value<int?>? intervalDays,
    Value<String?>? weekdays,
    Value<String?>? recurrenceStartDate,
    Value<String?>? recurrenceEndDate,
    Value<int>? rowid,
  }) {
    return TaskOccurrencesCompanion(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      title: title ?? this.title,
      description: description ?? this.description,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      plannedFor: plannedFor ?? this.plannedFor,
      deadline: deadline ?? this.deadline,
      assignedMemberId: assignedMemberId ?? this.assignedMemberId,
      pinnedMemberId: pinnedMemberId ?? this.pinnedMemberId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      priority: priority ?? this.priority,
      allowedMemberIds: allowedMemberIds ?? this.allowedMemberIds,
      templateId: templateId ?? this.templateId,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      intervalDays: intervalDays ?? this.intervalDays,
      weekdays: weekdays ?? this.weekdays,
      recurrenceStartDate: recurrenceStartDate ?? this.recurrenceStartDate,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (householdId.present) {
      map['household_id'] = Variable<String>(householdId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (estimatedDurationMinutes.present) {
      map['estimated_duration_minutes'] = Variable<int>(
        estimatedDurationMinutes.value,
      );
    }
    if (plannedFor.present) {
      map['planned_for'] = Variable<String>(plannedFor.value);
    }
    if (deadline.present) {
      map['deadline'] = Variable<String>(deadline.value);
    }
    if (assignedMemberId.present) {
      map['assigned_member_id'] = Variable<String>(assignedMemberId.value);
    }
    if (pinnedMemberId.present) {
      map['pinned_member_id'] = Variable<String>(pinnedMemberId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<String>(completedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (allowedMemberIds.present) {
      map['allowed_member_ids'] = Variable<String>(allowedMemberIds.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (recurrenceType.present) {
      map['recurrence_type'] = Variable<String>(recurrenceType.value);
    }
    if (intervalDays.present) {
      map['interval_days'] = Variable<int>(intervalDays.value);
    }
    if (weekdays.present) {
      map['weekdays'] = Variable<String>(weekdays.value);
    }
    if (recurrenceStartDate.present) {
      map['recurrence_start_date'] = Variable<String>(
        recurrenceStartDate.value,
      );
    }
    if (recurrenceEndDate.present) {
      map['recurrence_end_date'] = Variable<String>(recurrenceEndDate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskOccurrencesCompanion(')
          ..write('id: $id, ')
          ..write('householdId: $householdId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('estimatedDurationMinutes: $estimatedDurationMinutes, ')
          ..write('plannedFor: $plannedFor, ')
          ..write('deadline: $deadline, ')
          ..write('assignedMemberId: $assignedMemberId, ')
          ..write('pinnedMemberId: $pinnedMemberId, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('priority: $priority, ')
          ..write('allowedMemberIds: $allowedMemberIds, ')
          ..write('templateId: $templateId, ')
          ..write('recurrenceType: $recurrenceType, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('weekdays: $weekdays, ')
          ..write('recurrenceStartDate: $recurrenceStartDate, ')
          ..write('recurrenceEndDate: $recurrenceEndDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HouseholdMembersTable extends HouseholdMembers
    with TableInfo<$HouseholdMembersTable, HouseholdMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HouseholdMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _householdIdMeta = const VerificationMeta(
    'householdId',
  );
  @override
  late final GeneratedColumn<String> householdId = GeneratedColumn<String>(
    'household_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avatarUrlMeta = const VerificationMeta(
    'avatarUrl',
  );
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
    'avatar_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    profileId,
    householdId,
    displayName,
    avatarUrl,
    role,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'household_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<HouseholdMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('household_id')) {
      context.handle(
        _householdIdMeta,
        householdId.isAcceptableOrUnknown(
          data['household_id']!,
          _householdIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_householdIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('avatar_url')) {
      context.handle(
        _avatarUrlMeta,
        avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, householdId};
  @override
  HouseholdMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HouseholdMember(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      householdId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}household_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      avatarUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_url'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
    );
  }

  @override
  $HouseholdMembersTable createAlias(String alias) {
    return $HouseholdMembersTable(attachedDatabase, alias);
  }
}

class HouseholdMember extends DataClass implements Insertable<HouseholdMember> {
  final String profileId;
  final String householdId;
  final String displayName;
  final String? avatarUrl;
  final String role;
  const HouseholdMember({
    required this.profileId,
    required this.householdId,
    required this.displayName,
    this.avatarUrl,
    required this.role,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['household_id'] = Variable<String>(householdId);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || avatarUrl != null) {
      map['avatar_url'] = Variable<String>(avatarUrl);
    }
    map['role'] = Variable<String>(role);
    return map;
  }

  HouseholdMembersCompanion toCompanion(bool nullToAbsent) {
    return HouseholdMembersCompanion(
      profileId: Value(profileId),
      householdId: Value(householdId),
      displayName: Value(displayName),
      avatarUrl: avatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarUrl),
      role: Value(role),
    );
  }

  factory HouseholdMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HouseholdMember(
      profileId: serializer.fromJson<String>(json['profileId']),
      householdId: serializer.fromJson<String>(json['householdId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      avatarUrl: serializer.fromJson<String?>(json['avatarUrl']),
      role: serializer.fromJson<String>(json['role']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'householdId': serializer.toJson<String>(householdId),
      'displayName': serializer.toJson<String>(displayName),
      'avatarUrl': serializer.toJson<String?>(avatarUrl),
      'role': serializer.toJson<String>(role),
    };
  }

  HouseholdMember copyWith({
    String? profileId,
    String? householdId,
    String? displayName,
    Value<String?> avatarUrl = const Value.absent(),
    String? role,
  }) => HouseholdMember(
    profileId: profileId ?? this.profileId,
    householdId: householdId ?? this.householdId,
    displayName: displayName ?? this.displayName,
    avatarUrl: avatarUrl.present ? avatarUrl.value : this.avatarUrl,
    role: role ?? this.role,
  );
  HouseholdMember copyWithCompanion(HouseholdMembersCompanion data) {
    return HouseholdMember(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      householdId: data.householdId.present
          ? data.householdId.value
          : this.householdId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      role: data.role.present ? data.role.value : this.role,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HouseholdMember(')
          ..write('profileId: $profileId, ')
          ..write('householdId: $householdId, ')
          ..write('displayName: $displayName, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('role: $role')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(profileId, householdId, displayName, avatarUrl, role);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HouseholdMember &&
          other.profileId == this.profileId &&
          other.householdId == this.householdId &&
          other.displayName == this.displayName &&
          other.avatarUrl == this.avatarUrl &&
          other.role == this.role);
}

class HouseholdMembersCompanion extends UpdateCompanion<HouseholdMember> {
  final Value<String> profileId;
  final Value<String> householdId;
  final Value<String> displayName;
  final Value<String?> avatarUrl;
  final Value<String> role;
  final Value<int> rowid;
  const HouseholdMembersCompanion({
    this.profileId = const Value.absent(),
    this.householdId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.role = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HouseholdMembersCompanion.insert({
    required String profileId,
    required String householdId,
    required String displayName,
    this.avatarUrl = const Value.absent(),
    required String role,
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       householdId = Value(householdId),
       displayName = Value(displayName),
       role = Value(role);
  static Insertable<HouseholdMember> custom({
    Expression<String>? profileId,
    Expression<String>? householdId,
    Expression<String>? displayName,
    Expression<String>? avatarUrl,
    Expression<String>? role,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (householdId != null) 'household_id': householdId,
      if (displayName != null) 'display_name': displayName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (role != null) 'role': role,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HouseholdMembersCompanion copyWith({
    Value<String>? profileId,
    Value<String>? householdId,
    Value<String>? displayName,
    Value<String?>? avatarUrl,
    Value<String>? role,
    Value<int>? rowid,
  }) {
    return HouseholdMembersCompanion(
      profileId: profileId ?? this.profileId,
      householdId: householdId ?? this.householdId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (householdId.present) {
      map['household_id'] = Variable<String>(householdId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HouseholdMembersCompanion(')
          ..write('profileId: $profileId, ')
          ..write('householdId: $householdId, ')
          ..write('displayName: $displayName, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('role: $role, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTable extends SyncQueue
    with TableInfo<$SyncQueueTable, SyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _householdIdMeta = const VerificationMeta(
    'householdId',
  );
  @override
  late final GeneratedColumn<String> householdId = GeneratedColumn<String>(
    'household_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityType,
    operation,
    entityId,
    householdId,
    payload,
    retryCount,
    lastError,
    createdAt,
    lastAttemptAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('household_id')) {
      context.handle(
        _householdIdMeta,
        householdId.isAcceptableOrUnknown(
          data['household_id']!,
          _householdIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_householdIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      householdId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}household_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
    );
  }

  @override
  $SyncQueueTable createAlias(String alias) {
    return $SyncQueueTable(attachedDatabase, alias);
  }
}

class SyncQueueData extends DataClass implements Insertable<SyncQueueData> {
  final int id;
  final String entityType;
  final String operation;
  final String entityId;
  final String householdId;
  final String payload;
  final int retryCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  const SyncQueueData({
    required this.id,
    required this.entityType,
    required this.operation,
    required this.entityId,
    required this.householdId,
    required this.payload,
    required this.retryCount,
    this.lastError,
    required this.createdAt,
    this.lastAttemptAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['operation'] = Variable<String>(operation);
    map['entity_id'] = Variable<String>(entityId);
    map['household_id'] = Variable<String>(householdId);
    map['payload'] = Variable<String>(payload);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    return map;
  }

  SyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueCompanion(
      id: Value(id),
      entityType: Value(entityType),
      operation: Value(operation),
      entityId: Value(entityId),
      householdId: Value(householdId),
      payload: Value(payload),
      retryCount: Value(retryCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
    );
  }

  factory SyncQueueData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueData(
      id: serializer.fromJson<int>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      operation: serializer.fromJson<String>(json['operation']),
      entityId: serializer.fromJson<String>(json['entityId']),
      householdId: serializer.fromJson<String>(json['householdId']),
      payload: serializer.fromJson<String>(json['payload']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityType': serializer.toJson<String>(entityType),
      'operation': serializer.toJson<String>(operation),
      'entityId': serializer.toJson<String>(entityId),
      'householdId': serializer.toJson<String>(householdId),
      'payload': serializer.toJson<String>(payload),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
    };
  }

  SyncQueueData copyWith({
    int? id,
    String? entityType,
    String? operation,
    String? entityId,
    String? householdId,
    String? payload,
    int? retryCount,
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
  }) => SyncQueueData(
    id: id ?? this.id,
    entityType: entityType ?? this.entityType,
    operation: operation ?? this.operation,
    entityId: entityId ?? this.entityId,
    householdId: householdId ?? this.householdId,
    payload: payload ?? this.payload,
    retryCount: retryCount ?? this.retryCount,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
  );
  SyncQueueData copyWithCompanion(SyncQueueCompanion data) {
    return SyncQueueData(
      id: data.id.present ? data.id.value : this.id,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      operation: data.operation.present ? data.operation.value : this.operation,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      householdId: data.householdId.present
          ? data.householdId.value
          : this.householdId,
      payload: data.payload.present ? data.payload.value : this.payload,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueData(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('operation: $operation, ')
          ..write('entityId: $entityId, ')
          ..write('householdId: $householdId, ')
          ..write('payload: $payload, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAttemptAt: $lastAttemptAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entityType,
    operation,
    entityId,
    householdId,
    payload,
    retryCount,
    lastError,
    createdAt,
    lastAttemptAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueData &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.operation == this.operation &&
          other.entityId == this.entityId &&
          other.householdId == this.householdId &&
          other.payload == this.payload &&
          other.retryCount == this.retryCount &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.lastAttemptAt == this.lastAttemptAt);
}

class SyncQueueCompanion extends UpdateCompanion<SyncQueueData> {
  final Value<int> id;
  final Value<String> entityType;
  final Value<String> operation;
  final Value<String> entityId;
  final Value<String> householdId;
  final Value<String> payload;
  final Value<int> retryCount;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastAttemptAt;
  const SyncQueueCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.operation = const Value.absent(),
    this.entityId = const Value.absent(),
    this.householdId = const Value.absent(),
    this.payload = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    this.id = const Value.absent(),
    required String entityType,
    required String operation,
    required String entityId,
    required String householdId,
    required String payload,
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime createdAt,
    this.lastAttemptAt = const Value.absent(),
  }) : entityType = Value(entityType),
       operation = Value(operation),
       entityId = Value(entityId),
       householdId = Value(householdId),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<SyncQueueData> custom({
    Expression<int>? id,
    Expression<String>? entityType,
    Expression<String>? operation,
    Expression<String>? entityId,
    Expression<String>? householdId,
    Expression<String>? payload,
    Expression<int>? retryCount,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastAttemptAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (operation != null) 'operation': operation,
      if (entityId != null) 'entity_id': entityId,
      if (householdId != null) 'household_id': householdId,
      if (payload != null) 'payload': payload,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
    });
  }

  SyncQueueCompanion copyWith({
    Value<int>? id,
    Value<String>? entityType,
    Value<String>? operation,
    Value<String>? entityId,
    Value<String>? householdId,
    Value<String>? payload,
    Value<int>? retryCount,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastAttemptAt,
  }) {
    return SyncQueueCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      operation: operation ?? this.operation,
      entityId: entityId ?? this.entityId,
      householdId: householdId ?? this.householdId,
      payload: payload ?? this.payload,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (householdId.present) {
      map['household_id'] = Variable<String>(householdId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('operation: $operation, ')
          ..write('entityId: $entityId, ')
          ..write('householdId: $householdId, ')
          ..write('payload: $payload, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAttemptAt: $lastAttemptAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TaskOccurrencesTable taskOccurrences = $TaskOccurrencesTable(
    this,
  );
  late final $HouseholdMembersTable householdMembers = $HouseholdMembersTable(
    this,
  );
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final TaskDao taskDao = TaskDao(this as AppDatabase);
  late final SyncQueueDao syncQueueDao = SyncQueueDao(this as AppDatabase);
  late final HouseholdMembersDao householdMembersDao = HouseholdMembersDao(
    this as AppDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    taskOccurrences,
    householdMembers,
    syncQueue,
  ];
}

typedef $$TaskOccurrencesTableCreateCompanionBuilder =
    TaskOccurrencesCompanion Function({
      required String id,
      required String householdId,
      required String title,
      Value<String?> description,
      required int estimatedDurationMinutes,
      required String plannedFor,
      Value<String?> deadline,
      Value<String?> assignedMemberId,
      Value<String?> pinnedMemberId,
      required String status,
      required String createdAt,
      Value<String?> completedAt,
      Value<String?> updatedAt,
      Value<int?> priority,
      required String allowedMemberIds,
      Value<String?> templateId,
      Value<String?> recurrenceType,
      Value<int?> intervalDays,
      Value<String?> weekdays,
      Value<String?> recurrenceStartDate,
      Value<String?> recurrenceEndDate,
      Value<int> rowid,
    });
typedef $$TaskOccurrencesTableUpdateCompanionBuilder =
    TaskOccurrencesCompanion Function({
      Value<String> id,
      Value<String> householdId,
      Value<String> title,
      Value<String?> description,
      Value<int> estimatedDurationMinutes,
      Value<String> plannedFor,
      Value<String?> deadline,
      Value<String?> assignedMemberId,
      Value<String?> pinnedMemberId,
      Value<String> status,
      Value<String> createdAt,
      Value<String?> completedAt,
      Value<String?> updatedAt,
      Value<int?> priority,
      Value<String> allowedMemberIds,
      Value<String?> templateId,
      Value<String?> recurrenceType,
      Value<int?> intervalDays,
      Value<String?> weekdays,
      Value<String?> recurrenceStartDate,
      Value<String?> recurrenceEndDate,
      Value<int> rowid,
    });

class $$TaskOccurrencesTableFilterComposer
    extends Composer<_$AppDatabase, $TaskOccurrencesTable> {
  $$TaskOccurrencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get householdId => $composableBuilder(
    column: $table.householdId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estimatedDurationMinutes => $composableBuilder(
    column: $table.estimatedDurationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plannedFor => $composableBuilder(
    column: $table.plannedFor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deadline => $composableBuilder(
    column: $table.deadline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assignedMemberId => $composableBuilder(
    column: $table.assignedMemberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinnedMemberId => $composableBuilder(
    column: $table.pinnedMemberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get allowedMemberIds => $composableBuilder(
    column: $table.allowedMemberIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceType => $composableBuilder(
    column: $table.recurrenceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weekdays => $composableBuilder(
    column: $table.weekdays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceStartDate => $composableBuilder(
    column: $table.recurrenceStartDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceEndDate => $composableBuilder(
    column: $table.recurrenceEndDate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TaskOccurrencesTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskOccurrencesTable> {
  $$TaskOccurrencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get householdId => $composableBuilder(
    column: $table.householdId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimatedDurationMinutes => $composableBuilder(
    column: $table.estimatedDurationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plannedFor => $composableBuilder(
    column: $table.plannedFor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deadline => $composableBuilder(
    column: $table.deadline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assignedMemberId => $composableBuilder(
    column: $table.assignedMemberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinnedMemberId => $composableBuilder(
    column: $table.pinnedMemberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get allowedMemberIds => $composableBuilder(
    column: $table.allowedMemberIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceType => $composableBuilder(
    column: $table.recurrenceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weekdays => $composableBuilder(
    column: $table.weekdays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceStartDate => $composableBuilder(
    column: $table.recurrenceStartDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceEndDate => $composableBuilder(
    column: $table.recurrenceEndDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TaskOccurrencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskOccurrencesTable> {
  $$TaskOccurrencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get householdId => $composableBuilder(
    column: $table.householdId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get estimatedDurationMinutes => $composableBuilder(
    column: $table.estimatedDurationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get plannedFor => $composableBuilder(
    column: $table.plannedFor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deadline =>
      $composableBuilder(column: $table.deadline, builder: (column) => column);

  GeneratedColumn<String> get assignedMemberId => $composableBuilder(
    column: $table.assignedMemberId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pinnedMemberId => $composableBuilder(
    column: $table.pinnedMemberId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get allowedMemberIds => $composableBuilder(
    column: $table.allowedMemberIds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceType => $composableBuilder(
    column: $table.recurrenceType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => column,
  );

  GeneratedColumn<String> get weekdays =>
      $composableBuilder(column: $table.weekdays, builder: (column) => column);

  GeneratedColumn<String> get recurrenceStartDate => $composableBuilder(
    column: $table.recurrenceStartDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceEndDate => $composableBuilder(
    column: $table.recurrenceEndDate,
    builder: (column) => column,
  );
}

class $$TaskOccurrencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskOccurrencesTable,
          TaskOccurrence,
          $$TaskOccurrencesTableFilterComposer,
          $$TaskOccurrencesTableOrderingComposer,
          $$TaskOccurrencesTableAnnotationComposer,
          $$TaskOccurrencesTableCreateCompanionBuilder,
          $$TaskOccurrencesTableUpdateCompanionBuilder,
          (
            TaskOccurrence,
            BaseReferences<
              _$AppDatabase,
              $TaskOccurrencesTable,
              TaskOccurrence
            >,
          ),
          TaskOccurrence,
          PrefetchHooks Function()
        > {
  $$TaskOccurrencesTableTableManager(
    _$AppDatabase db,
    $TaskOccurrencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskOccurrencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskOccurrencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskOccurrencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> householdId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> estimatedDurationMinutes = const Value.absent(),
                Value<String> plannedFor = const Value.absent(),
                Value<String?> deadline = const Value.absent(),
                Value<String?> assignedMemberId = const Value.absent(),
                Value<String?> pinnedMemberId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String?> completedAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int?> priority = const Value.absent(),
                Value<String> allowedMemberIds = const Value.absent(),
                Value<String?> templateId = const Value.absent(),
                Value<String?> recurrenceType = const Value.absent(),
                Value<int?> intervalDays = const Value.absent(),
                Value<String?> weekdays = const Value.absent(),
                Value<String?> recurrenceStartDate = const Value.absent(),
                Value<String?> recurrenceEndDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskOccurrencesCompanion(
                id: id,
                householdId: householdId,
                title: title,
                description: description,
                estimatedDurationMinutes: estimatedDurationMinutes,
                plannedFor: plannedFor,
                deadline: deadline,
                assignedMemberId: assignedMemberId,
                pinnedMemberId: pinnedMemberId,
                status: status,
                createdAt: createdAt,
                completedAt: completedAt,
                updatedAt: updatedAt,
                priority: priority,
                allowedMemberIds: allowedMemberIds,
                templateId: templateId,
                recurrenceType: recurrenceType,
                intervalDays: intervalDays,
                weekdays: weekdays,
                recurrenceStartDate: recurrenceStartDate,
                recurrenceEndDate: recurrenceEndDate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String householdId,
                required String title,
                Value<String?> description = const Value.absent(),
                required int estimatedDurationMinutes,
                required String plannedFor,
                Value<String?> deadline = const Value.absent(),
                Value<String?> assignedMemberId = const Value.absent(),
                Value<String?> pinnedMemberId = const Value.absent(),
                required String status,
                required String createdAt,
                Value<String?> completedAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int?> priority = const Value.absent(),
                required String allowedMemberIds,
                Value<String?> templateId = const Value.absent(),
                Value<String?> recurrenceType = const Value.absent(),
                Value<int?> intervalDays = const Value.absent(),
                Value<String?> weekdays = const Value.absent(),
                Value<String?> recurrenceStartDate = const Value.absent(),
                Value<String?> recurrenceEndDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskOccurrencesCompanion.insert(
                id: id,
                householdId: householdId,
                title: title,
                description: description,
                estimatedDurationMinutes: estimatedDurationMinutes,
                plannedFor: plannedFor,
                deadline: deadline,
                assignedMemberId: assignedMemberId,
                pinnedMemberId: pinnedMemberId,
                status: status,
                createdAt: createdAt,
                completedAt: completedAt,
                updatedAt: updatedAt,
                priority: priority,
                allowedMemberIds: allowedMemberIds,
                templateId: templateId,
                recurrenceType: recurrenceType,
                intervalDays: intervalDays,
                weekdays: weekdays,
                recurrenceStartDate: recurrenceStartDate,
                recurrenceEndDate: recurrenceEndDate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TaskOccurrencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskOccurrencesTable,
      TaskOccurrence,
      $$TaskOccurrencesTableFilterComposer,
      $$TaskOccurrencesTableOrderingComposer,
      $$TaskOccurrencesTableAnnotationComposer,
      $$TaskOccurrencesTableCreateCompanionBuilder,
      $$TaskOccurrencesTableUpdateCompanionBuilder,
      (
        TaskOccurrence,
        BaseReferences<_$AppDatabase, $TaskOccurrencesTable, TaskOccurrence>,
      ),
      TaskOccurrence,
      PrefetchHooks Function()
    >;
typedef $$HouseholdMembersTableCreateCompanionBuilder =
    HouseholdMembersCompanion Function({
      required String profileId,
      required String householdId,
      required String displayName,
      Value<String?> avatarUrl,
      required String role,
      Value<int> rowid,
    });
typedef $$HouseholdMembersTableUpdateCompanionBuilder =
    HouseholdMembersCompanion Function({
      Value<String> profileId,
      Value<String> householdId,
      Value<String> displayName,
      Value<String?> avatarUrl,
      Value<String> role,
      Value<int> rowid,
    });

class $$HouseholdMembersTableFilterComposer
    extends Composer<_$AppDatabase, $HouseholdMembersTable> {
  $$HouseholdMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get householdId => $composableBuilder(
    column: $table.householdId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HouseholdMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $HouseholdMembersTable> {
  $$HouseholdMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get householdId => $composableBuilder(
    column: $table.householdId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HouseholdMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $HouseholdMembersTable> {
  $$HouseholdMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get householdId => $composableBuilder(
    column: $table.householdId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);
}

class $$HouseholdMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HouseholdMembersTable,
          HouseholdMember,
          $$HouseholdMembersTableFilterComposer,
          $$HouseholdMembersTableOrderingComposer,
          $$HouseholdMembersTableAnnotationComposer,
          $$HouseholdMembersTableCreateCompanionBuilder,
          $$HouseholdMembersTableUpdateCompanionBuilder,
          (
            HouseholdMember,
            BaseReferences<
              _$AppDatabase,
              $HouseholdMembersTable,
              HouseholdMember
            >,
          ),
          HouseholdMember,
          PrefetchHooks Function()
        > {
  $$HouseholdMembersTableTableManager(
    _$AppDatabase db,
    $HouseholdMembersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HouseholdMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HouseholdMembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HouseholdMembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String> householdId = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HouseholdMembersCompanion(
                profileId: profileId,
                householdId: householdId,
                displayName: displayName,
                avatarUrl: avatarUrl,
                role: role,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                required String householdId,
                required String displayName,
                Value<String?> avatarUrl = const Value.absent(),
                required String role,
                Value<int> rowid = const Value.absent(),
              }) => HouseholdMembersCompanion.insert(
                profileId: profileId,
                householdId: householdId,
                displayName: displayName,
                avatarUrl: avatarUrl,
                role: role,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HouseholdMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HouseholdMembersTable,
      HouseholdMember,
      $$HouseholdMembersTableFilterComposer,
      $$HouseholdMembersTableOrderingComposer,
      $$HouseholdMembersTableAnnotationComposer,
      $$HouseholdMembersTableCreateCompanionBuilder,
      $$HouseholdMembersTableUpdateCompanionBuilder,
      (
        HouseholdMember,
        BaseReferences<_$AppDatabase, $HouseholdMembersTable, HouseholdMember>,
      ),
      HouseholdMember,
      PrefetchHooks Function()
    >;
typedef $$SyncQueueTableCreateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<int> id,
      required String entityType,
      required String operation,
      required String entityId,
      required String householdId,
      required String payload,
      Value<int> retryCount,
      Value<String?> lastError,
      required DateTime createdAt,
      Value<DateTime?> lastAttemptAt,
    });
typedef $$SyncQueueTableUpdateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<int> id,
      Value<String> entityType,
      Value<String> operation,
      Value<String> entityId,
      Value<String> householdId,
      Value<String> payload,
      Value<int> retryCount,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime?> lastAttemptAt,
    });

class $$SyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get householdId => $composableBuilder(
    column: $table.householdId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get householdId => $composableBuilder(
    column: $table.householdId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get householdId => $composableBuilder(
    column: $table.householdId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );
}

class $$SyncQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueTable,
          SyncQueueData,
          $$SyncQueueTableFilterComposer,
          $$SyncQueueTableOrderingComposer,
          $$SyncQueueTableAnnotationComposer,
          $$SyncQueueTableCreateCompanionBuilder,
          $$SyncQueueTableUpdateCompanionBuilder,
          (
            SyncQueueData,
            BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>,
          ),
          SyncQueueData,
          PrefetchHooks Function()
        > {
  $$SyncQueueTableTableManager(_$AppDatabase db, $SyncQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> householdId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
              }) => SyncQueueCompanion(
                id: id,
                entityType: entityType,
                operation: operation,
                entityId: entityId,
                householdId: householdId,
                payload: payload,
                retryCount: retryCount,
                lastError: lastError,
                createdAt: createdAt,
                lastAttemptAt: lastAttemptAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entityType,
                required String operation,
                required String entityId,
                required String householdId,
                required String payload,
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> lastAttemptAt = const Value.absent(),
              }) => SyncQueueCompanion.insert(
                id: id,
                entityType: entityType,
                operation: operation,
                entityId: entityId,
                householdId: householdId,
                payload: payload,
                retryCount: retryCount,
                lastError: lastError,
                createdAt: createdAt,
                lastAttemptAt: lastAttemptAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueTable,
      SyncQueueData,
      $$SyncQueueTableFilterComposer,
      $$SyncQueueTableOrderingComposer,
      $$SyncQueueTableAnnotationComposer,
      $$SyncQueueTableCreateCompanionBuilder,
      $$SyncQueueTableUpdateCompanionBuilder,
      (
        SyncQueueData,
        BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>,
      ),
      SyncQueueData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TaskOccurrencesTableTableManager get taskOccurrences =>
      $$TaskOccurrencesTableTableManager(_db, _db.taskOccurrences);
  $$HouseholdMembersTableTableManager get householdMembers =>
      $$HouseholdMembersTableTableManager(_db, _db.householdMembers);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
}
