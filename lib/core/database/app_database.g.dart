// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MembersTable extends Members with TableInfo<$MembersTable, Member> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memberTypeMeta = const VerificationMeta(
    'memberType',
  );
  @override
  late final GeneratedColumn<String> memberType = GeneratedColumn<String>(
    'member_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avatarKeyMeta = const VerificationMeta(
    'avatarKey',
  );
  @override
  late final GeneratedColumn<String> avatarKey = GeneratedColumn<String>(
    'avatar_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isSystemMeta = const VerificationMeta(
    'isSystem',
  );
  @override
  late final GeneratedColumn<bool> isSystem = GeneratedColumn<bool>(
    'is_system',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_system" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    memberType,
    name,
    avatarKey,
    note,
    sortOrder,
    isSystem,
    isArchived,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'members';
  @override
  VerificationContext validateIntegrity(
    Insertable<Member> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('member_type')) {
      context.handle(
        _memberTypeMeta,
        memberType.isAcceptableOrUnknown(data['member_type']!, _memberTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_memberTypeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('avatar_key')) {
      context.handle(
        _avatarKeyMeta,
        avatarKey.isAcceptableOrUnknown(data['avatar_key']!, _avatarKeyMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_system')) {
      context.handle(
        _isSystemMeta,
        isSystem.isAcceptableOrUnknown(data['is_system']!, _isSystemMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Member map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Member(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      memberType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_type'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      avatarKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_key'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isSystem: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_system'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MembersTable createAlias(String alias) {
    return $MembersTable(attachedDatabase, alias);
  }
}

class Member extends DataClass implements Insertable<Member> {
  /// 主键 UUID
  final String id;

  /// 成员类型：person (真实人) / family (虚拟家庭)
  final String memberType;

  /// 成员显示名称
  final String name;

  /// 头像/图标 Key
  final String? avatarKey;

  /// 成员备注
  final String? note;

  /// 手动排序权重值
  final int sortOrder;

  /// 是否为系统内置成员
  final bool isSystem;

  /// 是否归档
  final bool isArchived;

  /// 创建时间
  final int createdAt;

  /// 更新时间
  final int updatedAt;
  const Member({
    required this.id,
    required this.memberType,
    required this.name,
    this.avatarKey,
    this.note,
    required this.sortOrder,
    required this.isSystem,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['member_type'] = Variable<String>(memberType);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || avatarKey != null) {
      map['avatar_key'] = Variable<String>(avatarKey);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_system'] = Variable<bool>(isSystem);
    map['is_archived'] = Variable<bool>(isArchived);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  MembersCompanion toCompanion(bool nullToAbsent) {
    return MembersCompanion(
      id: Value(id),
      memberType: Value(memberType),
      name: Value(name),
      avatarKey: avatarKey == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarKey),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      sortOrder: Value(sortOrder),
      isSystem: Value(isSystem),
      isArchived: Value(isArchived),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Member.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Member(
      id: serializer.fromJson<String>(json['id']),
      memberType: serializer.fromJson<String>(json['memberType']),
      name: serializer.fromJson<String>(json['name']),
      avatarKey: serializer.fromJson<String?>(json['avatarKey']),
      note: serializer.fromJson<String?>(json['note']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isSystem: serializer.fromJson<bool>(json['isSystem']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'memberType': serializer.toJson<String>(memberType),
      'name': serializer.toJson<String>(name),
      'avatarKey': serializer.toJson<String?>(avatarKey),
      'note': serializer.toJson<String?>(note),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isSystem': serializer.toJson<bool>(isSystem),
      'isArchived': serializer.toJson<bool>(isArchived),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  Member copyWith({
    String? id,
    String? memberType,
    String? name,
    Value<String?> avatarKey = const Value.absent(),
    Value<String?> note = const Value.absent(),
    int? sortOrder,
    bool? isSystem,
    bool? isArchived,
    int? createdAt,
    int? updatedAt,
  }) => Member(
    id: id ?? this.id,
    memberType: memberType ?? this.memberType,
    name: name ?? this.name,
    avatarKey: avatarKey.present ? avatarKey.value : this.avatarKey,
    note: note.present ? note.value : this.note,
    sortOrder: sortOrder ?? this.sortOrder,
    isSystem: isSystem ?? this.isSystem,
    isArchived: isArchived ?? this.isArchived,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Member copyWithCompanion(MembersCompanion data) {
    return Member(
      id: data.id.present ? data.id.value : this.id,
      memberType: data.memberType.present
          ? data.memberType.value
          : this.memberType,
      name: data.name.present ? data.name.value : this.name,
      avatarKey: data.avatarKey.present ? data.avatarKey.value : this.avatarKey,
      note: data.note.present ? data.note.value : this.note,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isSystem: data.isSystem.present ? data.isSystem.value : this.isSystem,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Member(')
          ..write('id: $id, ')
          ..write('memberType: $memberType, ')
          ..write('name: $name, ')
          ..write('avatarKey: $avatarKey, ')
          ..write('note: $note, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isSystem: $isSystem, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    memberType,
    name,
    avatarKey,
    note,
    sortOrder,
    isSystem,
    isArchived,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Member &&
          other.id == this.id &&
          other.memberType == this.memberType &&
          other.name == this.name &&
          other.avatarKey == this.avatarKey &&
          other.note == this.note &&
          other.sortOrder == this.sortOrder &&
          other.isSystem == this.isSystem &&
          other.isArchived == this.isArchived &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MembersCompanion extends UpdateCompanion<Member> {
  final Value<String> id;
  final Value<String> memberType;
  final Value<String> name;
  final Value<String?> avatarKey;
  final Value<String?> note;
  final Value<int> sortOrder;
  final Value<bool> isSystem;
  final Value<bool> isArchived;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const MembersCompanion({
    this.id = const Value.absent(),
    this.memberType = const Value.absent(),
    this.name = const Value.absent(),
    this.avatarKey = const Value.absent(),
    this.note = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isSystem = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MembersCompanion.insert({
    required String id,
    required String memberType,
    required String name,
    this.avatarKey = const Value.absent(),
    this.note = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isSystem = const Value.absent(),
    this.isArchived = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       memberType = Value(memberType),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Member> custom({
    Expression<String>? id,
    Expression<String>? memberType,
    Expression<String>? name,
    Expression<String>? avatarKey,
    Expression<String>? note,
    Expression<int>? sortOrder,
    Expression<bool>? isSystem,
    Expression<bool>? isArchived,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (memberType != null) 'member_type': memberType,
      if (name != null) 'name': name,
      if (avatarKey != null) 'avatar_key': avatarKey,
      if (note != null) 'note': note,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isSystem != null) 'is_system': isSystem,
      if (isArchived != null) 'is_archived': isArchived,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MembersCompanion copyWith({
    Value<String>? id,
    Value<String>? memberType,
    Value<String>? name,
    Value<String?>? avatarKey,
    Value<String?>? note,
    Value<int>? sortOrder,
    Value<bool>? isSystem,
    Value<bool>? isArchived,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return MembersCompanion(
      id: id ?? this.id,
      memberType: memberType ?? this.memberType,
      name: name ?? this.name,
      avatarKey: avatarKey ?? this.avatarKey,
      note: note ?? this.note,
      sortOrder: sortOrder ?? this.sortOrder,
      isSystem: isSystem ?? this.isSystem,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (memberType.present) {
      map['member_type'] = Variable<String>(memberType.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (avatarKey.present) {
      map['avatar_key'] = Variable<String>(avatarKey.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isSystem.present) {
      map['is_system'] = Variable<bool>(isSystem.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MembersCompanion(')
          ..write('id: $id, ')
          ..write('memberType: $memberType, ')
          ..write('name: $name, ')
          ..write('avatarKey: $avatarKey, ')
          ..write('note: $note, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isSystem: $isSystem, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemsTable extends Items with TableInfo<$ItemsTable, Item> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originIdMeta = const VerificationMeta(
    'originId',
  );
  @override
  late final GeneratedColumn<String> originId = GeneratedColumn<String>(
    'origin_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _memberIdMeta = const VerificationMeta(
    'memberId',
  );
  @override
  late final GeneratedColumn<String> memberId = GeneratedColumn<String>(
    'member_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES members (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _categoryKeyMeta = const VerificationMeta(
    'categoryKey',
  );
  @override
  late final GeneratedColumn<String> categoryKey = GeneratedColumn<String>(
    'category_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeKeyMeta = const VerificationMeta(
    'typeKey',
  );
  @override
  late final GeneratedColumn<String> typeKey = GeneratedColumn<String>(
    'type_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _templateVersionMeta = const VerificationMeta(
    'templateVersion',
  );
  @override
  late final GeneratedColumn<int> templateVersion = GeneratedColumn<int>(
    'template_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _primaryTextMeta = const VerificationMeta(
    'primaryText',
  );
  @override
  late final GeneratedColumn<String> primaryText = GeneratedColumn<String>(
    'primary_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _secondaryTextMeta = const VerificationMeta(
    'secondaryText',
  );
  @override
  late final GeneratedColumn<String> secondaryText = GeneratedColumn<String>(
    'secondary_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summaryTextMeta = const VerificationMeta(
    'summaryText',
  );
  @override
  late final GeneratedColumn<String> summaryText = GeneratedColumn<String>(
    'summary_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _searchTextMeta = const VerificationMeta(
    'searchText',
  );
  @override
  late final GeneratedColumn<String> searchText = GeneratedColumn<String>(
    'search_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _pinnedAtMeta = const VerificationMeta(
    'pinnedAt',
  );
  @override
  late final GeneratedColumn<int> pinnedAt = GeneratedColumn<int>(
    'pinned_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>(
      "status IN ('active', 'archived', 'deleted')",
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusBeforeDeletionMeta =
      const VerificationMeta('statusBeforeDeletion');
  @override
  late final GeneratedColumn<String>
  statusBeforeDeletion = GeneratedColumn<String>(
    'status_before_deletion',
    aliasedName,
    true,
    check: () => const CustomExpression<bool>(
      "status_before_deletion IS NULL OR status_before_deletion IN ('active', 'archived')",
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastViewedAtMeta = const VerificationMeta(
    'lastViewedAt',
  );
  @override
  late final GeneratedColumn<int> lastViewedAt = GeneratedColumn<int>(
    'last_viewed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    originId,
    memberId,
    categoryKey,
    typeKey,
    templateVersion,
    title,
    primaryText,
    secondaryText,
    summaryText,
    searchText,
    note,
    isFavorite,
    isPinned,
    pinnedAt,
    sortOrder,
    status,
    deletedAt,
    statusBeforeDeletion,
    createdAt,
    updatedAt,
    lastViewedAt,
    metadata,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'items';
  @override
  VerificationContext validateIntegrity(
    Insertable<Item> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('origin_id')) {
      context.handle(
        _originIdMeta,
        originId.isAcceptableOrUnknown(data['origin_id']!, _originIdMeta),
      );
    } else if (isInserting) {
      context.missing(_originIdMeta);
    }
    if (data.containsKey('member_id')) {
      context.handle(
        _memberIdMeta,
        memberId.isAcceptableOrUnknown(data['member_id']!, _memberIdMeta),
      );
    }
    if (data.containsKey('category_key')) {
      context.handle(
        _categoryKeyMeta,
        categoryKey.isAcceptableOrUnknown(
          data['category_key']!,
          _categoryKeyMeta,
        ),
      );
    }
    if (data.containsKey('type_key')) {
      context.handle(
        _typeKeyMeta,
        typeKey.isAcceptableOrUnknown(data['type_key']!, _typeKeyMeta),
      );
    }
    if (data.containsKey('template_version')) {
      context.handle(
        _templateVersionMeta,
        templateVersion.isAcceptableOrUnknown(
          data['template_version']!,
          _templateVersionMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('primary_text')) {
      context.handle(
        _primaryTextMeta,
        primaryText.isAcceptableOrUnknown(
          data['primary_text']!,
          _primaryTextMeta,
        ),
      );
    }
    if (data.containsKey('secondary_text')) {
      context.handle(
        _secondaryTextMeta,
        secondaryText.isAcceptableOrUnknown(
          data['secondary_text']!,
          _secondaryTextMeta,
        ),
      );
    }
    if (data.containsKey('summary_text')) {
      context.handle(
        _summaryTextMeta,
        summaryText.isAcceptableOrUnknown(
          data['summary_text']!,
          _summaryTextMeta,
        ),
      );
    }
    if (data.containsKey('search_text')) {
      context.handle(
        _searchTextMeta,
        searchText.isAcceptableOrUnknown(data['search_text']!, _searchTextMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('pinned_at')) {
      context.handle(
        _pinnedAtMeta,
        pinnedAt.isAcceptableOrUnknown(data['pinned_at']!, _pinnedAtMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('status_before_deletion')) {
      context.handle(
        _statusBeforeDeletionMeta,
        statusBeforeDeletion.isAcceptableOrUnknown(
          data['status_before_deletion']!,
          _statusBeforeDeletionMeta,
        ),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('last_viewed_at')) {
      context.handle(
        _lastViewedAtMeta,
        lastViewedAt.isAcceptableOrUnknown(
          data['last_viewed_at']!,
          _lastViewedAtMeta,
        ),
      );
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Item map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Item(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      originId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_id'],
      )!,
      memberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_id'],
      ),
      categoryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_key'],
      ),
      typeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type_key'],
      ),
      templateVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}template_version'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      primaryText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primary_text'],
      ),
      secondaryText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secondary_text'],
      ),
      summaryText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_text'],
      ),
      searchText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_text'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      pinnedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pinned_at'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      statusBeforeDeletion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status_before_deletion'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      lastViewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_viewed_at'],
      ),
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      ),
    );
  }

  @override
  $ItemsTable createAlias(String alias) {
    return $ItemsTable(attachedDatabase, alias);
  }
}

class Item extends DataClass implements Insertable<Item> {
  /// 主键 UUID
  final String id;

  /// 跨设备复制时保持稳定的随机来源标识。
  final String originId;

  /// 所属成员 ID，外键级联拦截
  final String? memberId;

  /// 大类 Key：certificate / card / insurance / vehicle / other
  final String? categoryKey;

  /// 子类型 Key：如 id_card / debit_card / credit_card 等
  final String? typeKey;

  /// 资料创建/适配时所使用的内置模板版本号
  final int templateVersion;

  /// 资料标题
  final String? title;

  /// 列表主展示文本（低敏脱敏数据）
  final String? primaryText;

  /// 列表副展示文本（低敏脱敏数据）
  final String? secondaryText;

  /// 汇总摘要文本（低敏预览）
  final String? summaryText;

  /// 低敏模糊搜索文本
  final String? searchText;

  /// 资料整体备注信息
  final String? note;

  /// 是否常用
  final bool isFavorite;

  /// 是否置顶
  final bool isPinned;

  /// 最近一次设为置顶的时间；取消置顶后清空，编辑资料不改变该值。
  final int? pinnedAt;

  /// 手动排序权重
  final int sortOrder;

  /// 状态：active / archived / deleted
  final String status;

  /// 移入最近删除的时间；活跃或归档资料为 null。
  final int? deletedAt;

  /// 最近删除前的收纳状态；仅删除中的资料保存 active / archived。
  final String? statusBeforeDeletion;

  /// 创建时间
  final int createdAt;

  /// 更新时间
  final int updatedAt;

  /// 最近查看时间（本机行为，不备份）
  final int? lastViewedAt;

  /// 结构化 JSON metadata (包含 warnings 和 derived)
  final String? metadata;
  const Item({
    required this.id,
    required this.originId,
    this.memberId,
    this.categoryKey,
    this.typeKey,
    required this.templateVersion,
    this.title,
    this.primaryText,
    this.secondaryText,
    this.summaryText,
    this.searchText,
    this.note,
    required this.isFavorite,
    required this.isPinned,
    this.pinnedAt,
    required this.sortOrder,
    required this.status,
    this.deletedAt,
    this.statusBeforeDeletion,
    required this.createdAt,
    required this.updatedAt,
    this.lastViewedAt,
    this.metadata,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['origin_id'] = Variable<String>(originId);
    if (!nullToAbsent || memberId != null) {
      map['member_id'] = Variable<String>(memberId);
    }
    if (!nullToAbsent || categoryKey != null) {
      map['category_key'] = Variable<String>(categoryKey);
    }
    if (!nullToAbsent || typeKey != null) {
      map['type_key'] = Variable<String>(typeKey);
    }
    map['template_version'] = Variable<int>(templateVersion);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || primaryText != null) {
      map['primary_text'] = Variable<String>(primaryText);
    }
    if (!nullToAbsent || secondaryText != null) {
      map['secondary_text'] = Variable<String>(secondaryText);
    }
    if (!nullToAbsent || summaryText != null) {
      map['summary_text'] = Variable<String>(summaryText);
    }
    if (!nullToAbsent || searchText != null) {
      map['search_text'] = Variable<String>(searchText);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['is_pinned'] = Variable<bool>(isPinned);
    if (!nullToAbsent || pinnedAt != null) {
      map['pinned_at'] = Variable<int>(pinnedAt);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    if (!nullToAbsent || statusBeforeDeletion != null) {
      map['status_before_deletion'] = Variable<String>(statusBeforeDeletion);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || lastViewedAt != null) {
      map['last_viewed_at'] = Variable<int>(lastViewedAt);
    }
    if (!nullToAbsent || metadata != null) {
      map['metadata'] = Variable<String>(metadata);
    }
    return map;
  }

  ItemsCompanion toCompanion(bool nullToAbsent) {
    return ItemsCompanion(
      id: Value(id),
      originId: Value(originId),
      memberId: memberId == null && nullToAbsent
          ? const Value.absent()
          : Value(memberId),
      categoryKey: categoryKey == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryKey),
      typeKey: typeKey == null && nullToAbsent
          ? const Value.absent()
          : Value(typeKey),
      templateVersion: Value(templateVersion),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      primaryText: primaryText == null && nullToAbsent
          ? const Value.absent()
          : Value(primaryText),
      secondaryText: secondaryText == null && nullToAbsent
          ? const Value.absent()
          : Value(secondaryText),
      summaryText: summaryText == null && nullToAbsent
          ? const Value.absent()
          : Value(summaryText),
      searchText: searchText == null && nullToAbsent
          ? const Value.absent()
          : Value(searchText),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      isFavorite: Value(isFavorite),
      isPinned: Value(isPinned),
      pinnedAt: pinnedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(pinnedAt),
      sortOrder: Value(sortOrder),
      status: Value(status),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      statusBeforeDeletion: statusBeforeDeletion == null && nullToAbsent
          ? const Value.absent()
          : Value(statusBeforeDeletion),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastViewedAt: lastViewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastViewedAt),
      metadata: metadata == null && nullToAbsent
          ? const Value.absent()
          : Value(metadata),
    );
  }

  factory Item.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Item(
      id: serializer.fromJson<String>(json['id']),
      originId: serializer.fromJson<String>(json['originId']),
      memberId: serializer.fromJson<String?>(json['memberId']),
      categoryKey: serializer.fromJson<String?>(json['categoryKey']),
      typeKey: serializer.fromJson<String?>(json['typeKey']),
      templateVersion: serializer.fromJson<int>(json['templateVersion']),
      title: serializer.fromJson<String?>(json['title']),
      primaryText: serializer.fromJson<String?>(json['primaryText']),
      secondaryText: serializer.fromJson<String?>(json['secondaryText']),
      summaryText: serializer.fromJson<String?>(json['summaryText']),
      searchText: serializer.fromJson<String?>(json['searchText']),
      note: serializer.fromJson<String?>(json['note']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      pinnedAt: serializer.fromJson<int?>(json['pinnedAt']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      status: serializer.fromJson<String>(json['status']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      statusBeforeDeletion: serializer.fromJson<String?>(
        json['statusBeforeDeletion'],
      ),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      lastViewedAt: serializer.fromJson<int?>(json['lastViewedAt']),
      metadata: serializer.fromJson<String?>(json['metadata']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'originId': serializer.toJson<String>(originId),
      'memberId': serializer.toJson<String?>(memberId),
      'categoryKey': serializer.toJson<String?>(categoryKey),
      'typeKey': serializer.toJson<String?>(typeKey),
      'templateVersion': serializer.toJson<int>(templateVersion),
      'title': serializer.toJson<String?>(title),
      'primaryText': serializer.toJson<String?>(primaryText),
      'secondaryText': serializer.toJson<String?>(secondaryText),
      'summaryText': serializer.toJson<String?>(summaryText),
      'searchText': serializer.toJson<String?>(searchText),
      'note': serializer.toJson<String?>(note),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'isPinned': serializer.toJson<bool>(isPinned),
      'pinnedAt': serializer.toJson<int?>(pinnedAt),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'status': serializer.toJson<String>(status),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'statusBeforeDeletion': serializer.toJson<String?>(statusBeforeDeletion),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'lastViewedAt': serializer.toJson<int?>(lastViewedAt),
      'metadata': serializer.toJson<String?>(metadata),
    };
  }

  Item copyWith({
    String? id,
    String? originId,
    Value<String?> memberId = const Value.absent(),
    Value<String?> categoryKey = const Value.absent(),
    Value<String?> typeKey = const Value.absent(),
    int? templateVersion,
    Value<String?> title = const Value.absent(),
    Value<String?> primaryText = const Value.absent(),
    Value<String?> secondaryText = const Value.absent(),
    Value<String?> summaryText = const Value.absent(),
    Value<String?> searchText = const Value.absent(),
    Value<String?> note = const Value.absent(),
    bool? isFavorite,
    bool? isPinned,
    Value<int?> pinnedAt = const Value.absent(),
    int? sortOrder,
    String? status,
    Value<int?> deletedAt = const Value.absent(),
    Value<String?> statusBeforeDeletion = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> lastViewedAt = const Value.absent(),
    Value<String?> metadata = const Value.absent(),
  }) => Item(
    id: id ?? this.id,
    originId: originId ?? this.originId,
    memberId: memberId.present ? memberId.value : this.memberId,
    categoryKey: categoryKey.present ? categoryKey.value : this.categoryKey,
    typeKey: typeKey.present ? typeKey.value : this.typeKey,
    templateVersion: templateVersion ?? this.templateVersion,
    title: title.present ? title.value : this.title,
    primaryText: primaryText.present ? primaryText.value : this.primaryText,
    secondaryText: secondaryText.present
        ? secondaryText.value
        : this.secondaryText,
    summaryText: summaryText.present ? summaryText.value : this.summaryText,
    searchText: searchText.present ? searchText.value : this.searchText,
    note: note.present ? note.value : this.note,
    isFavorite: isFavorite ?? this.isFavorite,
    isPinned: isPinned ?? this.isPinned,
    pinnedAt: pinnedAt.present ? pinnedAt.value : this.pinnedAt,
    sortOrder: sortOrder ?? this.sortOrder,
    status: status ?? this.status,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    statusBeforeDeletion: statusBeforeDeletion.present
        ? statusBeforeDeletion.value
        : this.statusBeforeDeletion,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastViewedAt: lastViewedAt.present ? lastViewedAt.value : this.lastViewedAt,
    metadata: metadata.present ? metadata.value : this.metadata,
  );
  Item copyWithCompanion(ItemsCompanion data) {
    return Item(
      id: data.id.present ? data.id.value : this.id,
      originId: data.originId.present ? data.originId.value : this.originId,
      memberId: data.memberId.present ? data.memberId.value : this.memberId,
      categoryKey: data.categoryKey.present
          ? data.categoryKey.value
          : this.categoryKey,
      typeKey: data.typeKey.present ? data.typeKey.value : this.typeKey,
      templateVersion: data.templateVersion.present
          ? data.templateVersion.value
          : this.templateVersion,
      title: data.title.present ? data.title.value : this.title,
      primaryText: data.primaryText.present
          ? data.primaryText.value
          : this.primaryText,
      secondaryText: data.secondaryText.present
          ? data.secondaryText.value
          : this.secondaryText,
      summaryText: data.summaryText.present
          ? data.summaryText.value
          : this.summaryText,
      searchText: data.searchText.present
          ? data.searchText.value
          : this.searchText,
      note: data.note.present ? data.note.value : this.note,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      pinnedAt: data.pinnedAt.present ? data.pinnedAt.value : this.pinnedAt,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      status: data.status.present ? data.status.value : this.status,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      statusBeforeDeletion: data.statusBeforeDeletion.present
          ? data.statusBeforeDeletion.value
          : this.statusBeforeDeletion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastViewedAt: data.lastViewedAt.present
          ? data.lastViewedAt.value
          : this.lastViewedAt,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Item(')
          ..write('id: $id, ')
          ..write('originId: $originId, ')
          ..write('memberId: $memberId, ')
          ..write('categoryKey: $categoryKey, ')
          ..write('typeKey: $typeKey, ')
          ..write('templateVersion: $templateVersion, ')
          ..write('title: $title, ')
          ..write('primaryText: $primaryText, ')
          ..write('secondaryText: $secondaryText, ')
          ..write('summaryText: $summaryText, ')
          ..write('searchText: $searchText, ')
          ..write('note: $note, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('isPinned: $isPinned, ')
          ..write('pinnedAt: $pinnedAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('status: $status, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('statusBeforeDeletion: $statusBeforeDeletion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastViewedAt: $lastViewedAt, ')
          ..write('metadata: $metadata')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    originId,
    memberId,
    categoryKey,
    typeKey,
    templateVersion,
    title,
    primaryText,
    secondaryText,
    summaryText,
    searchText,
    note,
    isFavorite,
    isPinned,
    pinnedAt,
    sortOrder,
    status,
    deletedAt,
    statusBeforeDeletion,
    createdAt,
    updatedAt,
    lastViewedAt,
    metadata,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Item &&
          other.id == this.id &&
          other.originId == this.originId &&
          other.memberId == this.memberId &&
          other.categoryKey == this.categoryKey &&
          other.typeKey == this.typeKey &&
          other.templateVersion == this.templateVersion &&
          other.title == this.title &&
          other.primaryText == this.primaryText &&
          other.secondaryText == this.secondaryText &&
          other.summaryText == this.summaryText &&
          other.searchText == this.searchText &&
          other.note == this.note &&
          other.isFavorite == this.isFavorite &&
          other.isPinned == this.isPinned &&
          other.pinnedAt == this.pinnedAt &&
          other.sortOrder == this.sortOrder &&
          other.status == this.status &&
          other.deletedAt == this.deletedAt &&
          other.statusBeforeDeletion == this.statusBeforeDeletion &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastViewedAt == this.lastViewedAt &&
          other.metadata == this.metadata);
}

class ItemsCompanion extends UpdateCompanion<Item> {
  final Value<String> id;
  final Value<String> originId;
  final Value<String?> memberId;
  final Value<String?> categoryKey;
  final Value<String?> typeKey;
  final Value<int> templateVersion;
  final Value<String?> title;
  final Value<String?> primaryText;
  final Value<String?> secondaryText;
  final Value<String?> summaryText;
  final Value<String?> searchText;
  final Value<String?> note;
  final Value<bool> isFavorite;
  final Value<bool> isPinned;
  final Value<int?> pinnedAt;
  final Value<int> sortOrder;
  final Value<String> status;
  final Value<int?> deletedAt;
  final Value<String?> statusBeforeDeletion;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> lastViewedAt;
  final Value<String?> metadata;
  final Value<int> rowid;
  const ItemsCompanion({
    this.id = const Value.absent(),
    this.originId = const Value.absent(),
    this.memberId = const Value.absent(),
    this.categoryKey = const Value.absent(),
    this.typeKey = const Value.absent(),
    this.templateVersion = const Value.absent(),
    this.title = const Value.absent(),
    this.primaryText = const Value.absent(),
    this.secondaryText = const Value.absent(),
    this.summaryText = const Value.absent(),
    this.searchText = const Value.absent(),
    this.note = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.pinnedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.status = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.statusBeforeDeletion = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastViewedAt = const Value.absent(),
    this.metadata = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemsCompanion.insert({
    required String id,
    required String originId,
    this.memberId = const Value.absent(),
    this.categoryKey = const Value.absent(),
    this.typeKey = const Value.absent(),
    this.templateVersion = const Value.absent(),
    this.title = const Value.absent(),
    this.primaryText = const Value.absent(),
    this.secondaryText = const Value.absent(),
    this.summaryText = const Value.absent(),
    this.searchText = const Value.absent(),
    this.note = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.pinnedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.status = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.statusBeforeDeletion = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.lastViewedAt = const Value.absent(),
    this.metadata = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       originId = Value(originId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Item> custom({
    Expression<String>? id,
    Expression<String>? originId,
    Expression<String>? memberId,
    Expression<String>? categoryKey,
    Expression<String>? typeKey,
    Expression<int>? templateVersion,
    Expression<String>? title,
    Expression<String>? primaryText,
    Expression<String>? secondaryText,
    Expression<String>? summaryText,
    Expression<String>? searchText,
    Expression<String>? note,
    Expression<bool>? isFavorite,
    Expression<bool>? isPinned,
    Expression<int>? pinnedAt,
    Expression<int>? sortOrder,
    Expression<String>? status,
    Expression<int>? deletedAt,
    Expression<String>? statusBeforeDeletion,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? lastViewedAt,
    Expression<String>? metadata,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (originId != null) 'origin_id': originId,
      if (memberId != null) 'member_id': memberId,
      if (categoryKey != null) 'category_key': categoryKey,
      if (typeKey != null) 'type_key': typeKey,
      if (templateVersion != null) 'template_version': templateVersion,
      if (title != null) 'title': title,
      if (primaryText != null) 'primary_text': primaryText,
      if (secondaryText != null) 'secondary_text': secondaryText,
      if (summaryText != null) 'summary_text': summaryText,
      if (searchText != null) 'search_text': searchText,
      if (note != null) 'note': note,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (isPinned != null) 'is_pinned': isPinned,
      if (pinnedAt != null) 'pinned_at': pinnedAt,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (status != null) 'status': status,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (statusBeforeDeletion != null)
        'status_before_deletion': statusBeforeDeletion,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastViewedAt != null) 'last_viewed_at': lastViewedAt,
      if (metadata != null) 'metadata': metadata,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? originId,
    Value<String?>? memberId,
    Value<String?>? categoryKey,
    Value<String?>? typeKey,
    Value<int>? templateVersion,
    Value<String?>? title,
    Value<String?>? primaryText,
    Value<String?>? secondaryText,
    Value<String?>? summaryText,
    Value<String?>? searchText,
    Value<String?>? note,
    Value<bool>? isFavorite,
    Value<bool>? isPinned,
    Value<int?>? pinnedAt,
    Value<int>? sortOrder,
    Value<String>? status,
    Value<int?>? deletedAt,
    Value<String?>? statusBeforeDeletion,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? lastViewedAt,
    Value<String?>? metadata,
    Value<int>? rowid,
  }) {
    return ItemsCompanion(
      id: id ?? this.id,
      originId: originId ?? this.originId,
      memberId: memberId ?? this.memberId,
      categoryKey: categoryKey ?? this.categoryKey,
      typeKey: typeKey ?? this.typeKey,
      templateVersion: templateVersion ?? this.templateVersion,
      title: title ?? this.title,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      summaryText: summaryText ?? this.summaryText,
      searchText: searchText ?? this.searchText,
      note: note ?? this.note,
      isFavorite: isFavorite ?? this.isFavorite,
      isPinned: isPinned ?? this.isPinned,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      status: status ?? this.status,
      deletedAt: deletedAt ?? this.deletedAt,
      statusBeforeDeletion: statusBeforeDeletion ?? this.statusBeforeDeletion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
      metadata: metadata ?? this.metadata,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (originId.present) {
      map['origin_id'] = Variable<String>(originId.value);
    }
    if (memberId.present) {
      map['member_id'] = Variable<String>(memberId.value);
    }
    if (categoryKey.present) {
      map['category_key'] = Variable<String>(categoryKey.value);
    }
    if (typeKey.present) {
      map['type_key'] = Variable<String>(typeKey.value);
    }
    if (templateVersion.present) {
      map['template_version'] = Variable<int>(templateVersion.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (primaryText.present) {
      map['primary_text'] = Variable<String>(primaryText.value);
    }
    if (secondaryText.present) {
      map['secondary_text'] = Variable<String>(secondaryText.value);
    }
    if (summaryText.present) {
      map['summary_text'] = Variable<String>(summaryText.value);
    }
    if (searchText.present) {
      map['search_text'] = Variable<String>(searchText.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (pinnedAt.present) {
      map['pinned_at'] = Variable<int>(pinnedAt.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (statusBeforeDeletion.present) {
      map['status_before_deletion'] = Variable<String>(
        statusBeforeDeletion.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (lastViewedAt.present) {
      map['last_viewed_at'] = Variable<int>(lastViewedAt.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemsCompanion(')
          ..write('id: $id, ')
          ..write('originId: $originId, ')
          ..write('memberId: $memberId, ')
          ..write('categoryKey: $categoryKey, ')
          ..write('typeKey: $typeKey, ')
          ..write('templateVersion: $templateVersion, ')
          ..write('title: $title, ')
          ..write('primaryText: $primaryText, ')
          ..write('secondaryText: $secondaryText, ')
          ..write('summaryText: $summaryText, ')
          ..write('searchText: $searchText, ')
          ..write('note: $note, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('isPinned: $isPinned, ')
          ..write('pinnedAt: $pinnedAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('status: $status, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('statusBeforeDeletion: $statusBeforeDeletion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastViewedAt: $lastViewedAt, ')
          ..write('metadata: $metadata, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemFieldsTable extends ItemFields
    with TableInfo<$ItemFieldsTable, ItemField> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemFieldsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _fieldKeyMeta = const VerificationMeta(
    'fieldKey',
  );
  @override
  late final GeneratedColumn<String> fieldKey = GeneratedColumn<String>(
    'field_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueTypeMeta = const VerificationMeta(
    'valueType',
  );
  @override
  late final GeneratedColumn<String> valueType = GeneratedColumn<String>(
    'value_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueTextMeta = const VerificationMeta(
    'valueText',
  );
  @override
  late final GeneratedColumn<String> valueText = GeneratedColumn<String>(
    'value_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _normalizedValueMeta = const VerificationMeta(
    'normalizedValue',
  );
  @override
  late final GeneratedColumn<String> normalizedValue = GeneratedColumn<String>(
    'normalized_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fieldNoteMeta = const VerificationMeta(
    'fieldNote',
  );
  @override
  late final GeneratedColumn<String> fieldNote = GeneratedColumn<String>(
    'field_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawFieldLabelMeta = const VerificationMeta(
    'rawFieldLabel',
  );
  @override
  late final GeneratedColumn<String> rawFieldLabel = GeneratedColumn<String>(
    'raw_field_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    itemId,
    fieldKey,
    valueType,
    valueText,
    normalizedValue,
    fieldNote,
    rawFieldLabel,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'item_fields';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemField> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('field_key')) {
      context.handle(
        _fieldKeyMeta,
        fieldKey.isAcceptableOrUnknown(data['field_key']!, _fieldKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldKeyMeta);
    }
    if (data.containsKey('value_type')) {
      context.handle(
        _valueTypeMeta,
        valueType.isAcceptableOrUnknown(data['value_type']!, _valueTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_valueTypeMeta);
    }
    if (data.containsKey('value_text')) {
      context.handle(
        _valueTextMeta,
        valueText.isAcceptableOrUnknown(data['value_text']!, _valueTextMeta),
      );
    }
    if (data.containsKey('normalized_value')) {
      context.handle(
        _normalizedValueMeta,
        normalizedValue.isAcceptableOrUnknown(
          data['normalized_value']!,
          _normalizedValueMeta,
        ),
      );
    }
    if (data.containsKey('field_note')) {
      context.handle(
        _fieldNoteMeta,
        fieldNote.isAcceptableOrUnknown(data['field_note']!, _fieldNoteMeta),
      );
    }
    if (data.containsKey('raw_field_label')) {
      context.handle(
        _rawFieldLabelMeta,
        rawFieldLabel.isAcceptableOrUnknown(
          data['raw_field_label']!,
          _rawFieldLabelMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {itemId, fieldKey},
  ];
  @override
  ItemField map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemField(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      fieldKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_key'],
      )!,
      valueType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_type'],
      )!,
      valueText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_text'],
      ),
      normalizedValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_value'],
      ),
      fieldNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_note'],
      ),
      rawFieldLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_field_label'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ItemFieldsTable createAlias(String alias) {
    return $ItemFieldsTable(attachedDatabase, alias);
  }
}

class ItemField extends DataClass implements Insertable<ItemField> {
  /// 主键 UUID
  final String id;

  /// 所属资料 ID，外键级联删除
  final String itemId;

  /// 字段 Key
  final String fieldKey;

  /// 字段值类型
  final String valueType;

  /// 原始展示明文
  final String? valueText;

  /// 标准化值（低敏）
  final String? normalizedValue;

  /// 字段级备注
  final String? fieldNote;

  /// 恢复旧备份时的字段中文名
  final String? rawFieldLabel;

  /// 字段显示顺序
  final int sortOrder;

  /// 创建时间
  final int createdAt;

  /// 更新时间
  final int updatedAt;
  const ItemField({
    required this.id,
    required this.itemId,
    required this.fieldKey,
    required this.valueType,
    this.valueText,
    this.normalizedValue,
    this.fieldNote,
    this.rawFieldLabel,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<String>(itemId);
    map['field_key'] = Variable<String>(fieldKey);
    map['value_type'] = Variable<String>(valueType);
    if (!nullToAbsent || valueText != null) {
      map['value_text'] = Variable<String>(valueText);
    }
    if (!nullToAbsent || normalizedValue != null) {
      map['normalized_value'] = Variable<String>(normalizedValue);
    }
    if (!nullToAbsent || fieldNote != null) {
      map['field_note'] = Variable<String>(fieldNote);
    }
    if (!nullToAbsent || rawFieldLabel != null) {
      map['raw_field_label'] = Variable<String>(rawFieldLabel);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ItemFieldsCompanion toCompanion(bool nullToAbsent) {
    return ItemFieldsCompanion(
      id: Value(id),
      itemId: Value(itemId),
      fieldKey: Value(fieldKey),
      valueType: Value(valueType),
      valueText: valueText == null && nullToAbsent
          ? const Value.absent()
          : Value(valueText),
      normalizedValue: normalizedValue == null && nullToAbsent
          ? const Value.absent()
          : Value(normalizedValue),
      fieldNote: fieldNote == null && nullToAbsent
          ? const Value.absent()
          : Value(fieldNote),
      rawFieldLabel: rawFieldLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(rawFieldLabel),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ItemField.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemField(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      fieldKey: serializer.fromJson<String>(json['fieldKey']),
      valueType: serializer.fromJson<String>(json['valueType']),
      valueText: serializer.fromJson<String?>(json['valueText']),
      normalizedValue: serializer.fromJson<String?>(json['normalizedValue']),
      fieldNote: serializer.fromJson<String?>(json['fieldNote']),
      rawFieldLabel: serializer.fromJson<String?>(json['rawFieldLabel']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<String>(itemId),
      'fieldKey': serializer.toJson<String>(fieldKey),
      'valueType': serializer.toJson<String>(valueType),
      'valueText': serializer.toJson<String?>(valueText),
      'normalizedValue': serializer.toJson<String?>(normalizedValue),
      'fieldNote': serializer.toJson<String?>(fieldNote),
      'rawFieldLabel': serializer.toJson<String?>(rawFieldLabel),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ItemField copyWith({
    String? id,
    String? itemId,
    String? fieldKey,
    String? valueType,
    Value<String?> valueText = const Value.absent(),
    Value<String?> normalizedValue = const Value.absent(),
    Value<String?> fieldNote = const Value.absent(),
    Value<String?> rawFieldLabel = const Value.absent(),
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
  }) => ItemField(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    fieldKey: fieldKey ?? this.fieldKey,
    valueType: valueType ?? this.valueType,
    valueText: valueText.present ? valueText.value : this.valueText,
    normalizedValue: normalizedValue.present
        ? normalizedValue.value
        : this.normalizedValue,
    fieldNote: fieldNote.present ? fieldNote.value : this.fieldNote,
    rawFieldLabel: rawFieldLabel.present
        ? rawFieldLabel.value
        : this.rawFieldLabel,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ItemField copyWithCompanion(ItemFieldsCompanion data) {
    return ItemField(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      fieldKey: data.fieldKey.present ? data.fieldKey.value : this.fieldKey,
      valueType: data.valueType.present ? data.valueType.value : this.valueType,
      valueText: data.valueText.present ? data.valueText.value : this.valueText,
      normalizedValue: data.normalizedValue.present
          ? data.normalizedValue.value
          : this.normalizedValue,
      fieldNote: data.fieldNote.present ? data.fieldNote.value : this.fieldNote,
      rawFieldLabel: data.rawFieldLabel.present
          ? data.rawFieldLabel.value
          : this.rawFieldLabel,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemField(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('fieldKey: $fieldKey, ')
          ..write('valueType: $valueType, ')
          ..write('valueText: $valueText, ')
          ..write('normalizedValue: $normalizedValue, ')
          ..write('fieldNote: $fieldNote, ')
          ..write('rawFieldLabel: $rawFieldLabel, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    itemId,
    fieldKey,
    valueType,
    valueText,
    normalizedValue,
    fieldNote,
    rawFieldLabel,
    sortOrder,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemField &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.fieldKey == this.fieldKey &&
          other.valueType == this.valueType &&
          other.valueText == this.valueText &&
          other.normalizedValue == this.normalizedValue &&
          other.fieldNote == this.fieldNote &&
          other.rawFieldLabel == this.rawFieldLabel &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ItemFieldsCompanion extends UpdateCompanion<ItemField> {
  final Value<String> id;
  final Value<String> itemId;
  final Value<String> fieldKey;
  final Value<String> valueType;
  final Value<String?> valueText;
  final Value<String?> normalizedValue;
  final Value<String?> fieldNote;
  final Value<String?> rawFieldLabel;
  final Value<int> sortOrder;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ItemFieldsCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.fieldKey = const Value.absent(),
    this.valueType = const Value.absent(),
    this.valueText = const Value.absent(),
    this.normalizedValue = const Value.absent(),
    this.fieldNote = const Value.absent(),
    this.rawFieldLabel = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemFieldsCompanion.insert({
    required String id,
    required String itemId,
    required String fieldKey,
    required String valueType,
    this.valueText = const Value.absent(),
    this.normalizedValue = const Value.absent(),
    this.fieldNote = const Value.absent(),
    this.rawFieldLabel = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       itemId = Value(itemId),
       fieldKey = Value(fieldKey),
       valueType = Value(valueType),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ItemField> custom({
    Expression<String>? id,
    Expression<String>? itemId,
    Expression<String>? fieldKey,
    Expression<String>? valueType,
    Expression<String>? valueText,
    Expression<String>? normalizedValue,
    Expression<String>? fieldNote,
    Expression<String>? rawFieldLabel,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (fieldKey != null) 'field_key': fieldKey,
      if (valueType != null) 'value_type': valueType,
      if (valueText != null) 'value_text': valueText,
      if (normalizedValue != null) 'normalized_value': normalizedValue,
      if (fieldNote != null) 'field_note': fieldNote,
      if (rawFieldLabel != null) 'raw_field_label': rawFieldLabel,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemFieldsCompanion copyWith({
    Value<String>? id,
    Value<String>? itemId,
    Value<String>? fieldKey,
    Value<String>? valueType,
    Value<String?>? valueText,
    Value<String?>? normalizedValue,
    Value<String?>? fieldNote,
    Value<String?>? rawFieldLabel,
    Value<int>? sortOrder,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ItemFieldsCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      fieldKey: fieldKey ?? this.fieldKey,
      valueType: valueType ?? this.valueType,
      valueText: valueText ?? this.valueText,
      normalizedValue: normalizedValue ?? this.normalizedValue,
      fieldNote: fieldNote ?? this.fieldNote,
      rawFieldLabel: rawFieldLabel ?? this.rawFieldLabel,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (fieldKey.present) {
      map['field_key'] = Variable<String>(fieldKey.value);
    }
    if (valueType.present) {
      map['value_type'] = Variable<String>(valueType.value);
    }
    if (valueText.present) {
      map['value_text'] = Variable<String>(valueText.value);
    }
    if (normalizedValue.present) {
      map['normalized_value'] = Variable<String>(normalizedValue.value);
    }
    if (fieldNote.present) {
      map['field_note'] = Variable<String>(fieldNote.value);
    }
    if (rawFieldLabel.present) {
      map['raw_field_label'] = Variable<String>(rawFieldLabel.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemFieldsCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('fieldKey: $fieldKey, ')
          ..write('valueType: $valueType, ')
          ..write('valueText: $valueText, ')
          ..write('normalizedValue: $normalizedValue, ')
          ..write('fieldNote: $fieldNote, ')
          ..write('rawFieldLabel: $rawFieldLabel, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTable extends Attachments
    with TableInfo<$AttachmentsTable, Attachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originAttachmentIdMeta =
      const VerificationMeta('originAttachmentId');
  @override
  late final GeneratedColumn<String> originAttachmentId =
      GeneratedColumn<String>(
        'origin_attachment_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
      );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _linkedFieldKeyMeta = const VerificationMeta(
    'linkedFieldKey',
  );
  @override
  late final GeneratedColumn<String> linkedFieldKey = GeneratedColumn<String>(
    'linked_field_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attachmentRoleMeta = const VerificationMeta(
    'attachmentRole',
  );
  @override
  late final GeneratedColumn<String> attachmentRole = GeneratedColumn<String>(
    'attachment_role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalNameMeta = const VerificationMeta(
    'originalName',
  );
  @override
  late final GeneratedColumn<String> originalName = GeneratedColumn<String>(
    'original_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plainSizeMeta = const VerificationMeta(
    'plainSize',
  );
  @override
  late final GeneratedColumn<int> plainSize = GeneratedColumn<int>(
    'plain_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _encryptedSizeMeta = const VerificationMeta(
    'encryptedSize',
  );
  @override
  late final GeneratedColumn<int> encryptedSize = GeneratedColumn<int>(
    'encrypted_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    check: () =>
        const CustomExpression<bool>("status IN ('active', 'deleted')"),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    originAttachmentId,
    itemId,
    linkedFieldKey,
    attachmentRole,
    fileName,
    originalName,
    mimeType,
    plainSize,
    encryptedSize,
    sha256,
    sortOrder,
    status,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Attachment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('origin_attachment_id')) {
      context.handle(
        _originAttachmentIdMeta,
        originAttachmentId.isAcceptableOrUnknown(
          data['origin_attachment_id']!,
          _originAttachmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originAttachmentIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('linked_field_key')) {
      context.handle(
        _linkedFieldKeyMeta,
        linkedFieldKey.isAcceptableOrUnknown(
          data['linked_field_key']!,
          _linkedFieldKeyMeta,
        ),
      );
    }
    if (data.containsKey('attachment_role')) {
      context.handle(
        _attachmentRoleMeta,
        attachmentRole.isAcceptableOrUnknown(
          data['attachment_role']!,
          _attachmentRoleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attachmentRoleMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('original_name')) {
      context.handle(
        _originalNameMeta,
        originalName.isAcceptableOrUnknown(
          data['original_name']!,
          _originalNameMeta,
        ),
      );
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('plain_size')) {
      context.handle(
        _plainSizeMeta,
        plainSize.isAcceptableOrUnknown(data['plain_size']!, _plainSizeMeta),
      );
    }
    if (data.containsKey('encrypted_size')) {
      context.handle(
        _encryptedSizeMeta,
        encryptedSize.isAcceptableOrUnknown(
          data['encrypted_size']!,
          _encryptedSizeMeta,
        ),
      );
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Attachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Attachment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      originAttachmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_attachment_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      linkedFieldKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_field_key'],
      ),
      attachmentRole: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_role'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      originalName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_name'],
      ),
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      plainSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plain_size'],
      )!,
      encryptedSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}encrypted_size'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AttachmentsTable createAlias(String alias) {
    return $AttachmentsTable(attachedDatabase, alias);
  }
}

class Attachment extends DataClass implements Insertable<Attachment> {
  /// 主键 UUID
  final String id;

  /// 跨设备复制时保持稳定的随机来源标识。
  final String originAttachmentId;

  /// 所属资料 ID，外键级联删除
  final String itemId;

  /// 关联的字段 Key
  final String? linkedFieldKey;

  /// 附件角色
  final String attachmentRole;

  /// 物理加密存储的随机 UUID 文件名
  final String fileName;

  /// 原始文件名
  final String? originalName;

  /// 媒体类型
  final String mimeType;

  /// 文件解密前的大小
  final int plainSize;

  /// 文件加密后物理占据的大小
  final int encryptedSize;

  /// 加密文件内容的 SHA-256
  final String? sha256;

  /// 排序权重
  final int sortOrder;

  /// 状态：active / deleted
  final String status;

  /// 创建时间
  final int createdAt;

  /// 更新时间
  final int updatedAt;
  const Attachment({
    required this.id,
    required this.originAttachmentId,
    required this.itemId,
    this.linkedFieldKey,
    required this.attachmentRole,
    required this.fileName,
    this.originalName,
    required this.mimeType,
    required this.plainSize,
    required this.encryptedSize,
    this.sha256,
    required this.sortOrder,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['origin_attachment_id'] = Variable<String>(originAttachmentId);
    map['item_id'] = Variable<String>(itemId);
    if (!nullToAbsent || linkedFieldKey != null) {
      map['linked_field_key'] = Variable<String>(linkedFieldKey);
    }
    map['attachment_role'] = Variable<String>(attachmentRole);
    map['file_name'] = Variable<String>(fileName);
    if (!nullToAbsent || originalName != null) {
      map['original_name'] = Variable<String>(originalName);
    }
    map['mime_type'] = Variable<String>(mimeType);
    map['plain_size'] = Variable<int>(plainSize);
    map['encrypted_size'] = Variable<int>(encryptedSize);
    if (!nullToAbsent || sha256 != null) {
      map['sha256'] = Variable<String>(sha256);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  AttachmentsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsCompanion(
      id: Value(id),
      originAttachmentId: Value(originAttachmentId),
      itemId: Value(itemId),
      linkedFieldKey: linkedFieldKey == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedFieldKey),
      attachmentRole: Value(attachmentRole),
      fileName: Value(fileName),
      originalName: originalName == null && nullToAbsent
          ? const Value.absent()
          : Value(originalName),
      mimeType: Value(mimeType),
      plainSize: Value(plainSize),
      encryptedSize: Value(encryptedSize),
      sha256: sha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(sha256),
      sortOrder: Value(sortOrder),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Attachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Attachment(
      id: serializer.fromJson<String>(json['id']),
      originAttachmentId: serializer.fromJson<String>(
        json['originAttachmentId'],
      ),
      itemId: serializer.fromJson<String>(json['itemId']),
      linkedFieldKey: serializer.fromJson<String?>(json['linkedFieldKey']),
      attachmentRole: serializer.fromJson<String>(json['attachmentRole']),
      fileName: serializer.fromJson<String>(json['fileName']),
      originalName: serializer.fromJson<String?>(json['originalName']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      plainSize: serializer.fromJson<int>(json['plainSize']),
      encryptedSize: serializer.fromJson<int>(json['encryptedSize']),
      sha256: serializer.fromJson<String?>(json['sha256']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'originAttachmentId': serializer.toJson<String>(originAttachmentId),
      'itemId': serializer.toJson<String>(itemId),
      'linkedFieldKey': serializer.toJson<String?>(linkedFieldKey),
      'attachmentRole': serializer.toJson<String>(attachmentRole),
      'fileName': serializer.toJson<String>(fileName),
      'originalName': serializer.toJson<String?>(originalName),
      'mimeType': serializer.toJson<String>(mimeType),
      'plainSize': serializer.toJson<int>(plainSize),
      'encryptedSize': serializer.toJson<int>(encryptedSize),
      'sha256': serializer.toJson<String?>(sha256),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  Attachment copyWith({
    String? id,
    String? originAttachmentId,
    String? itemId,
    Value<String?> linkedFieldKey = const Value.absent(),
    String? attachmentRole,
    String? fileName,
    Value<String?> originalName = const Value.absent(),
    String? mimeType,
    int? plainSize,
    int? encryptedSize,
    Value<String?> sha256 = const Value.absent(),
    int? sortOrder,
    String? status,
    int? createdAt,
    int? updatedAt,
  }) => Attachment(
    id: id ?? this.id,
    originAttachmentId: originAttachmentId ?? this.originAttachmentId,
    itemId: itemId ?? this.itemId,
    linkedFieldKey: linkedFieldKey.present
        ? linkedFieldKey.value
        : this.linkedFieldKey,
    attachmentRole: attachmentRole ?? this.attachmentRole,
    fileName: fileName ?? this.fileName,
    originalName: originalName.present ? originalName.value : this.originalName,
    mimeType: mimeType ?? this.mimeType,
    plainSize: plainSize ?? this.plainSize,
    encryptedSize: encryptedSize ?? this.encryptedSize,
    sha256: sha256.present ? sha256.value : this.sha256,
    sortOrder: sortOrder ?? this.sortOrder,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Attachment copyWithCompanion(AttachmentsCompanion data) {
    return Attachment(
      id: data.id.present ? data.id.value : this.id,
      originAttachmentId: data.originAttachmentId.present
          ? data.originAttachmentId.value
          : this.originAttachmentId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      linkedFieldKey: data.linkedFieldKey.present
          ? data.linkedFieldKey.value
          : this.linkedFieldKey,
      attachmentRole: data.attachmentRole.present
          ? data.attachmentRole.value
          : this.attachmentRole,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      originalName: data.originalName.present
          ? data.originalName.value
          : this.originalName,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      plainSize: data.plainSize.present ? data.plainSize.value : this.plainSize,
      encryptedSize: data.encryptedSize.present
          ? data.encryptedSize.value
          : this.encryptedSize,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Attachment(')
          ..write('id: $id, ')
          ..write('originAttachmentId: $originAttachmentId, ')
          ..write('itemId: $itemId, ')
          ..write('linkedFieldKey: $linkedFieldKey, ')
          ..write('attachmentRole: $attachmentRole, ')
          ..write('fileName: $fileName, ')
          ..write('originalName: $originalName, ')
          ..write('mimeType: $mimeType, ')
          ..write('plainSize: $plainSize, ')
          ..write('encryptedSize: $encryptedSize, ')
          ..write('sha256: $sha256, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    originAttachmentId,
    itemId,
    linkedFieldKey,
    attachmentRole,
    fileName,
    originalName,
    mimeType,
    plainSize,
    encryptedSize,
    sha256,
    sortOrder,
    status,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attachment &&
          other.id == this.id &&
          other.originAttachmentId == this.originAttachmentId &&
          other.itemId == this.itemId &&
          other.linkedFieldKey == this.linkedFieldKey &&
          other.attachmentRole == this.attachmentRole &&
          other.fileName == this.fileName &&
          other.originalName == this.originalName &&
          other.mimeType == this.mimeType &&
          other.plainSize == this.plainSize &&
          other.encryptedSize == this.encryptedSize &&
          other.sha256 == this.sha256 &&
          other.sortOrder == this.sortOrder &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AttachmentsCompanion extends UpdateCompanion<Attachment> {
  final Value<String> id;
  final Value<String> originAttachmentId;
  final Value<String> itemId;
  final Value<String?> linkedFieldKey;
  final Value<String> attachmentRole;
  final Value<String> fileName;
  final Value<String?> originalName;
  final Value<String> mimeType;
  final Value<int> plainSize;
  final Value<int> encryptedSize;
  final Value<String?> sha256;
  final Value<int> sortOrder;
  final Value<String> status;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const AttachmentsCompanion({
    this.id = const Value.absent(),
    this.originAttachmentId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.linkedFieldKey = const Value.absent(),
    this.attachmentRole = const Value.absent(),
    this.fileName = const Value.absent(),
    this.originalName = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.plainSize = const Value.absent(),
    this.encryptedSize = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentsCompanion.insert({
    required String id,
    required String originAttachmentId,
    required String itemId,
    this.linkedFieldKey = const Value.absent(),
    required String attachmentRole,
    required String fileName,
    this.originalName = const Value.absent(),
    required String mimeType,
    this.plainSize = const Value.absent(),
    this.encryptedSize = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.status = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       originAttachmentId = Value(originAttachmentId),
       itemId = Value(itemId),
       attachmentRole = Value(attachmentRole),
       fileName = Value(fileName),
       mimeType = Value(mimeType),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Attachment> custom({
    Expression<String>? id,
    Expression<String>? originAttachmentId,
    Expression<String>? itemId,
    Expression<String>? linkedFieldKey,
    Expression<String>? attachmentRole,
    Expression<String>? fileName,
    Expression<String>? originalName,
    Expression<String>? mimeType,
    Expression<int>? plainSize,
    Expression<int>? encryptedSize,
    Expression<String>? sha256,
    Expression<int>? sortOrder,
    Expression<String>? status,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (originAttachmentId != null)
        'origin_attachment_id': originAttachmentId,
      if (itemId != null) 'item_id': itemId,
      if (linkedFieldKey != null) 'linked_field_key': linkedFieldKey,
      if (attachmentRole != null) 'attachment_role': attachmentRole,
      if (fileName != null) 'file_name': fileName,
      if (originalName != null) 'original_name': originalName,
      if (mimeType != null) 'mime_type': mimeType,
      if (plainSize != null) 'plain_size': plainSize,
      if (encryptedSize != null) 'encrypted_size': encryptedSize,
      if (sha256 != null) 'sha256': sha256,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttachmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? originAttachmentId,
    Value<String>? itemId,
    Value<String?>? linkedFieldKey,
    Value<String>? attachmentRole,
    Value<String>? fileName,
    Value<String?>? originalName,
    Value<String>? mimeType,
    Value<int>? plainSize,
    Value<int>? encryptedSize,
    Value<String?>? sha256,
    Value<int>? sortOrder,
    Value<String>? status,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return AttachmentsCompanion(
      id: id ?? this.id,
      originAttachmentId: originAttachmentId ?? this.originAttachmentId,
      itemId: itemId ?? this.itemId,
      linkedFieldKey: linkedFieldKey ?? this.linkedFieldKey,
      attachmentRole: attachmentRole ?? this.attachmentRole,
      fileName: fileName ?? this.fileName,
      originalName: originalName ?? this.originalName,
      mimeType: mimeType ?? this.mimeType,
      plainSize: plainSize ?? this.plainSize,
      encryptedSize: encryptedSize ?? this.encryptedSize,
      sha256: sha256 ?? this.sha256,
      sortOrder: sortOrder ?? this.sortOrder,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (originAttachmentId.present) {
      map['origin_attachment_id'] = Variable<String>(originAttachmentId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (linkedFieldKey.present) {
      map['linked_field_key'] = Variable<String>(linkedFieldKey.value);
    }
    if (attachmentRole.present) {
      map['attachment_role'] = Variable<String>(attachmentRole.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (originalName.present) {
      map['original_name'] = Variable<String>(originalName.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (plainSize.present) {
      map['plain_size'] = Variable<int>(plainSize.value);
    }
    if (encryptedSize.present) {
      map['encrypted_size'] = Variable<int>(encryptedSize.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('originAttachmentId: $originAttachmentId, ')
          ..write('itemId: $itemId, ')
          ..write('linkedFieldKey: $linkedFieldKey, ')
          ..write('attachmentRole: $attachmentRole, ')
          ..write('fileName: $fileName, ')
          ..write('originalName: $originalName, ')
          ..write('mimeType: $mimeType, ')
          ..write('plainSize: $plainSize, ')
          ..write('encryptedSize: $encryptedSize, ')
          ..write('sha256: $sha256, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RemindersTable extends Reminders
    with TableInfo<$RemindersTable, Reminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _fieldKeyMeta = const VerificationMeta(
    'fieldKey',
  );
  @override
  late final GeneratedColumn<String> fieldKey = GeneratedColumn<String>(
    'field_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderTypeMeta = const VerificationMeta(
    'reminderType',
  );
  @override
  late final GeneratedColumn<String> reminderType = GeneratedColumn<String>(
    'reminder_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceValueMeta = const VerificationMeta(
    'sourceValue',
  );
  @override
  late final GeneratedColumn<String> sourceValue = GeneratedColumn<String>(
    'source_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceValueTypeMeta = const VerificationMeta(
    'sourceValueType',
  );
  @override
  late final GeneratedColumn<String> sourceValueType = GeneratedColumn<String>(
    'source_value_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remindAtMeta = const VerificationMeta(
    'remindAt',
  );
  @override
  late final GeneratedColumn<int> remindAt = GeneratedColumn<int>(
    'remind_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _advanceDaysMeta = const VerificationMeta(
    'advanceDays',
  );
  @override
  late final GeneratedColumn<int> advanceDays = GeneratedColumn<int>(
    'advance_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _repeatRuleMeta = const VerificationMeta(
    'repeatRule',
  );
  @override
  late final GeneratedColumn<String> repeatRule = GeneratedColumn<String>(
    'repeat_rule',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _lastTriggeredAtMeta = const VerificationMeta(
    'lastTriggeredAt',
  );
  @override
  late final GeneratedColumn<int> lastTriggeredAt = GeneratedColumn<int>(
    'last_triggered_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextTriggerAtMeta = const VerificationMeta(
    'nextTriggerAt',
  );
  @override
  late final GeneratedColumn<int> nextTriggerAt = GeneratedColumn<int>(
    'next_trigger_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snoozedUntilMeta = const VerificationMeta(
    'snoozedUntil',
  );
  @override
  late final GeneratedColumn<int> snoozedUntil = GeneratedColumn<int>(
    'snoozed_until',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dismissedAtMeta = const VerificationMeta(
    'dismissedAt',
  );
  @override
  late final GeneratedColumn<int> dismissedAt = GeneratedColumn<int>(
    'dismissed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notificationLocalIdMeta =
      const VerificationMeta('notificationLocalId');
  @override
  late final GeneratedColumn<int> notificationLocalId = GeneratedColumn<int>(
    'notification_local_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    itemId,
    fieldKey,
    reminderType,
    sourceValue,
    sourceValueType,
    remindAt,
    advanceDays,
    repeatRule,
    enabled,
    lastTriggeredAt,
    nextTriggerAt,
    snoozedUntil,
    dismissedAt,
    notificationLocalId,
    note,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Reminder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('field_key')) {
      context.handle(
        _fieldKeyMeta,
        fieldKey.isAcceptableOrUnknown(data['field_key']!, _fieldKeyMeta),
      );
    }
    if (data.containsKey('reminder_type')) {
      context.handle(
        _reminderTypeMeta,
        reminderType.isAcceptableOrUnknown(
          data['reminder_type']!,
          _reminderTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_reminderTypeMeta);
    }
    if (data.containsKey('source_value')) {
      context.handle(
        _sourceValueMeta,
        sourceValue.isAcceptableOrUnknown(
          data['source_value']!,
          _sourceValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceValueMeta);
    }
    if (data.containsKey('source_value_type')) {
      context.handle(
        _sourceValueTypeMeta,
        sourceValueType.isAcceptableOrUnknown(
          data['source_value_type']!,
          _sourceValueTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceValueTypeMeta);
    }
    if (data.containsKey('remind_at')) {
      context.handle(
        _remindAtMeta,
        remindAt.isAcceptableOrUnknown(data['remind_at']!, _remindAtMeta),
      );
    } else if (isInserting) {
      context.missing(_remindAtMeta);
    }
    if (data.containsKey('advance_days')) {
      context.handle(
        _advanceDaysMeta,
        advanceDays.isAcceptableOrUnknown(
          data['advance_days']!,
          _advanceDaysMeta,
        ),
      );
    }
    if (data.containsKey('repeat_rule')) {
      context.handle(
        _repeatRuleMeta,
        repeatRule.isAcceptableOrUnknown(data['repeat_rule']!, _repeatRuleMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('last_triggered_at')) {
      context.handle(
        _lastTriggeredAtMeta,
        lastTriggeredAt.isAcceptableOrUnknown(
          data['last_triggered_at']!,
          _lastTriggeredAtMeta,
        ),
      );
    }
    if (data.containsKey('next_trigger_at')) {
      context.handle(
        _nextTriggerAtMeta,
        nextTriggerAt.isAcceptableOrUnknown(
          data['next_trigger_at']!,
          _nextTriggerAtMeta,
        ),
      );
    }
    if (data.containsKey('snoozed_until')) {
      context.handle(
        _snoozedUntilMeta,
        snoozedUntil.isAcceptableOrUnknown(
          data['snoozed_until']!,
          _snoozedUntilMeta,
        ),
      );
    }
    if (data.containsKey('dismissed_at')) {
      context.handle(
        _dismissedAtMeta,
        dismissedAt.isAcceptableOrUnknown(
          data['dismissed_at']!,
          _dismissedAtMeta,
        ),
      );
    }
    if (data.containsKey('notification_local_id')) {
      context.handle(
        _notificationLocalIdMeta,
        notificationLocalId.isAcceptableOrUnknown(
          data['notification_local_id']!,
          _notificationLocalIdMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Reminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reminder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      fieldKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_key'],
      ),
      reminderType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_type'],
      )!,
      sourceValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_value'],
      )!,
      sourceValueType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_value_type'],
      )!,
      remindAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remind_at'],
      )!,
      advanceDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}advance_days'],
      )!,
      repeatRule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_rule'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      lastTriggeredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_triggered_at'],
      ),
      nextTriggerAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_trigger_at'],
      ),
      snoozedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snoozed_until'],
      ),
      dismissedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dismissed_at'],
      ),
      notificationLocalId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notification_local_id'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RemindersTable createAlias(String alias) {
    return $RemindersTable(attachedDatabase, alias);
  }
}

class Reminder extends DataClass implements Insertable<Reminder> {
  /// 主键 UUID
  final String id;

  /// 所属资料 ID，外键级联删除
  final String itemId;

  /// 关联的字段 Key
  final String? fieldKey;

  /// 提醒类型
  final String reminderType;

  /// 触发日期源值
  final String sourceValue;

  /// 触发值类型分类：date / month_day / day_of_month
  final String sourceValueType;

  /// 触发绝对毫秒时间戳
  final int remindAt;

  /// 提前几天提醒
  final int advanceDays;

  /// 周期重复配置
  final String? repeatRule;

  /// 提醒总开关
  final bool enabled;

  /// 上次触发报警时间
  final int? lastTriggeredAt;

  /// 下次触发时间戳
  final int? nextTriggerAt;

  /// 稍后提醒挂起时间
  final int? snoozedUntil;

  /// 用户忽略警报时间戳
  final int? dismissedAt;

  /// 操作系统通知注册 ID
  final int? notificationLocalId;

  /// 备注说明
  final String? note;

  /// 创建时间
  final int createdAt;

  /// 更新时间
  final int updatedAt;
  const Reminder({
    required this.id,
    required this.itemId,
    this.fieldKey,
    required this.reminderType,
    required this.sourceValue,
    required this.sourceValueType,
    required this.remindAt,
    required this.advanceDays,
    this.repeatRule,
    required this.enabled,
    this.lastTriggeredAt,
    this.nextTriggerAt,
    this.snoozedUntil,
    this.dismissedAt,
    this.notificationLocalId,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<String>(itemId);
    if (!nullToAbsent || fieldKey != null) {
      map['field_key'] = Variable<String>(fieldKey);
    }
    map['reminder_type'] = Variable<String>(reminderType);
    map['source_value'] = Variable<String>(sourceValue);
    map['source_value_type'] = Variable<String>(sourceValueType);
    map['remind_at'] = Variable<int>(remindAt);
    map['advance_days'] = Variable<int>(advanceDays);
    if (!nullToAbsent || repeatRule != null) {
      map['repeat_rule'] = Variable<String>(repeatRule);
    }
    map['enabled'] = Variable<bool>(enabled);
    if (!nullToAbsent || lastTriggeredAt != null) {
      map['last_triggered_at'] = Variable<int>(lastTriggeredAt);
    }
    if (!nullToAbsent || nextTriggerAt != null) {
      map['next_trigger_at'] = Variable<int>(nextTriggerAt);
    }
    if (!nullToAbsent || snoozedUntil != null) {
      map['snoozed_until'] = Variable<int>(snoozedUntil);
    }
    if (!nullToAbsent || dismissedAt != null) {
      map['dismissed_at'] = Variable<int>(dismissedAt);
    }
    if (!nullToAbsent || notificationLocalId != null) {
      map['notification_local_id'] = Variable<int>(notificationLocalId);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  RemindersCompanion toCompanion(bool nullToAbsent) {
    return RemindersCompanion(
      id: Value(id),
      itemId: Value(itemId),
      fieldKey: fieldKey == null && nullToAbsent
          ? const Value.absent()
          : Value(fieldKey),
      reminderType: Value(reminderType),
      sourceValue: Value(sourceValue),
      sourceValueType: Value(sourceValueType),
      remindAt: Value(remindAt),
      advanceDays: Value(advanceDays),
      repeatRule: repeatRule == null && nullToAbsent
          ? const Value.absent()
          : Value(repeatRule),
      enabled: Value(enabled),
      lastTriggeredAt: lastTriggeredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastTriggeredAt),
      nextTriggerAt: nextTriggerAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextTriggerAt),
      snoozedUntil: snoozedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozedUntil),
      dismissedAt: dismissedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dismissedAt),
      notificationLocalId: notificationLocalId == null && nullToAbsent
          ? const Value.absent()
          : Value(notificationLocalId),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Reminder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Reminder(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      fieldKey: serializer.fromJson<String?>(json['fieldKey']),
      reminderType: serializer.fromJson<String>(json['reminderType']),
      sourceValue: serializer.fromJson<String>(json['sourceValue']),
      sourceValueType: serializer.fromJson<String>(json['sourceValueType']),
      remindAt: serializer.fromJson<int>(json['remindAt']),
      advanceDays: serializer.fromJson<int>(json['advanceDays']),
      repeatRule: serializer.fromJson<String?>(json['repeatRule']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      lastTriggeredAt: serializer.fromJson<int?>(json['lastTriggeredAt']),
      nextTriggerAt: serializer.fromJson<int?>(json['nextTriggerAt']),
      snoozedUntil: serializer.fromJson<int?>(json['snoozedUntil']),
      dismissedAt: serializer.fromJson<int?>(json['dismissedAt']),
      notificationLocalId: serializer.fromJson<int?>(
        json['notificationLocalId'],
      ),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<String>(itemId),
      'fieldKey': serializer.toJson<String?>(fieldKey),
      'reminderType': serializer.toJson<String>(reminderType),
      'sourceValue': serializer.toJson<String>(sourceValue),
      'sourceValueType': serializer.toJson<String>(sourceValueType),
      'remindAt': serializer.toJson<int>(remindAt),
      'advanceDays': serializer.toJson<int>(advanceDays),
      'repeatRule': serializer.toJson<String?>(repeatRule),
      'enabled': serializer.toJson<bool>(enabled),
      'lastTriggeredAt': serializer.toJson<int?>(lastTriggeredAt),
      'nextTriggerAt': serializer.toJson<int?>(nextTriggerAt),
      'snoozedUntil': serializer.toJson<int?>(snoozedUntil),
      'dismissedAt': serializer.toJson<int?>(dismissedAt),
      'notificationLocalId': serializer.toJson<int?>(notificationLocalId),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  Reminder copyWith({
    String? id,
    String? itemId,
    Value<String?> fieldKey = const Value.absent(),
    String? reminderType,
    String? sourceValue,
    String? sourceValueType,
    int? remindAt,
    int? advanceDays,
    Value<String?> repeatRule = const Value.absent(),
    bool? enabled,
    Value<int?> lastTriggeredAt = const Value.absent(),
    Value<int?> nextTriggerAt = const Value.absent(),
    Value<int?> snoozedUntil = const Value.absent(),
    Value<int?> dismissedAt = const Value.absent(),
    Value<int?> notificationLocalId = const Value.absent(),
    Value<String?> note = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => Reminder(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    fieldKey: fieldKey.present ? fieldKey.value : this.fieldKey,
    reminderType: reminderType ?? this.reminderType,
    sourceValue: sourceValue ?? this.sourceValue,
    sourceValueType: sourceValueType ?? this.sourceValueType,
    remindAt: remindAt ?? this.remindAt,
    advanceDays: advanceDays ?? this.advanceDays,
    repeatRule: repeatRule.present ? repeatRule.value : this.repeatRule,
    enabled: enabled ?? this.enabled,
    lastTriggeredAt: lastTriggeredAt.present
        ? lastTriggeredAt.value
        : this.lastTriggeredAt,
    nextTriggerAt: nextTriggerAt.present
        ? nextTriggerAt.value
        : this.nextTriggerAt,
    snoozedUntil: snoozedUntil.present ? snoozedUntil.value : this.snoozedUntil,
    dismissedAt: dismissedAt.present ? dismissedAt.value : this.dismissedAt,
    notificationLocalId: notificationLocalId.present
        ? notificationLocalId.value
        : this.notificationLocalId,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Reminder copyWithCompanion(RemindersCompanion data) {
    return Reminder(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      fieldKey: data.fieldKey.present ? data.fieldKey.value : this.fieldKey,
      reminderType: data.reminderType.present
          ? data.reminderType.value
          : this.reminderType,
      sourceValue: data.sourceValue.present
          ? data.sourceValue.value
          : this.sourceValue,
      sourceValueType: data.sourceValueType.present
          ? data.sourceValueType.value
          : this.sourceValueType,
      remindAt: data.remindAt.present ? data.remindAt.value : this.remindAt,
      advanceDays: data.advanceDays.present
          ? data.advanceDays.value
          : this.advanceDays,
      repeatRule: data.repeatRule.present
          ? data.repeatRule.value
          : this.repeatRule,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      lastTriggeredAt: data.lastTriggeredAt.present
          ? data.lastTriggeredAt.value
          : this.lastTriggeredAt,
      nextTriggerAt: data.nextTriggerAt.present
          ? data.nextTriggerAt.value
          : this.nextTriggerAt,
      snoozedUntil: data.snoozedUntil.present
          ? data.snoozedUntil.value
          : this.snoozedUntil,
      dismissedAt: data.dismissedAt.present
          ? data.dismissedAt.value
          : this.dismissedAt,
      notificationLocalId: data.notificationLocalId.present
          ? data.notificationLocalId.value
          : this.notificationLocalId,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reminder(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('fieldKey: $fieldKey, ')
          ..write('reminderType: $reminderType, ')
          ..write('sourceValue: $sourceValue, ')
          ..write('sourceValueType: $sourceValueType, ')
          ..write('remindAt: $remindAt, ')
          ..write('advanceDays: $advanceDays, ')
          ..write('repeatRule: $repeatRule, ')
          ..write('enabled: $enabled, ')
          ..write('lastTriggeredAt: $lastTriggeredAt, ')
          ..write('nextTriggerAt: $nextTriggerAt, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('dismissedAt: $dismissedAt, ')
          ..write('notificationLocalId: $notificationLocalId, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    itemId,
    fieldKey,
    reminderType,
    sourceValue,
    sourceValueType,
    remindAt,
    advanceDays,
    repeatRule,
    enabled,
    lastTriggeredAt,
    nextTriggerAt,
    snoozedUntil,
    dismissedAt,
    notificationLocalId,
    note,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reminder &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.fieldKey == this.fieldKey &&
          other.reminderType == this.reminderType &&
          other.sourceValue == this.sourceValue &&
          other.sourceValueType == this.sourceValueType &&
          other.remindAt == this.remindAt &&
          other.advanceDays == this.advanceDays &&
          other.repeatRule == this.repeatRule &&
          other.enabled == this.enabled &&
          other.lastTriggeredAt == this.lastTriggeredAt &&
          other.nextTriggerAt == this.nextTriggerAt &&
          other.snoozedUntil == this.snoozedUntil &&
          other.dismissedAt == this.dismissedAt &&
          other.notificationLocalId == this.notificationLocalId &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RemindersCompanion extends UpdateCompanion<Reminder> {
  final Value<String> id;
  final Value<String> itemId;
  final Value<String?> fieldKey;
  final Value<String> reminderType;
  final Value<String> sourceValue;
  final Value<String> sourceValueType;
  final Value<int> remindAt;
  final Value<int> advanceDays;
  final Value<String?> repeatRule;
  final Value<bool> enabled;
  final Value<int?> lastTriggeredAt;
  final Value<int?> nextTriggerAt;
  final Value<int?> snoozedUntil;
  final Value<int?> dismissedAt;
  final Value<int?> notificationLocalId;
  final Value<String?> note;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const RemindersCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.fieldKey = const Value.absent(),
    this.reminderType = const Value.absent(),
    this.sourceValue = const Value.absent(),
    this.sourceValueType = const Value.absent(),
    this.remindAt = const Value.absent(),
    this.advanceDays = const Value.absent(),
    this.repeatRule = const Value.absent(),
    this.enabled = const Value.absent(),
    this.lastTriggeredAt = const Value.absent(),
    this.nextTriggerAt = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.dismissedAt = const Value.absent(),
    this.notificationLocalId = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RemindersCompanion.insert({
    required String id,
    required String itemId,
    this.fieldKey = const Value.absent(),
    required String reminderType,
    required String sourceValue,
    required String sourceValueType,
    required int remindAt,
    this.advanceDays = const Value.absent(),
    this.repeatRule = const Value.absent(),
    this.enabled = const Value.absent(),
    this.lastTriggeredAt = const Value.absent(),
    this.nextTriggerAt = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.dismissedAt = const Value.absent(),
    this.notificationLocalId = const Value.absent(),
    this.note = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       itemId = Value(itemId),
       reminderType = Value(reminderType),
       sourceValue = Value(sourceValue),
       sourceValueType = Value(sourceValueType),
       remindAt = Value(remindAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Reminder> custom({
    Expression<String>? id,
    Expression<String>? itemId,
    Expression<String>? fieldKey,
    Expression<String>? reminderType,
    Expression<String>? sourceValue,
    Expression<String>? sourceValueType,
    Expression<int>? remindAt,
    Expression<int>? advanceDays,
    Expression<String>? repeatRule,
    Expression<bool>? enabled,
    Expression<int>? lastTriggeredAt,
    Expression<int>? nextTriggerAt,
    Expression<int>? snoozedUntil,
    Expression<int>? dismissedAt,
    Expression<int>? notificationLocalId,
    Expression<String>? note,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (fieldKey != null) 'field_key': fieldKey,
      if (reminderType != null) 'reminder_type': reminderType,
      if (sourceValue != null) 'source_value': sourceValue,
      if (sourceValueType != null) 'source_value_type': sourceValueType,
      if (remindAt != null) 'remind_at': remindAt,
      if (advanceDays != null) 'advance_days': advanceDays,
      if (repeatRule != null) 'repeat_rule': repeatRule,
      if (enabled != null) 'enabled': enabled,
      if (lastTriggeredAt != null) 'last_triggered_at': lastTriggeredAt,
      if (nextTriggerAt != null) 'next_trigger_at': nextTriggerAt,
      if (snoozedUntil != null) 'snoozed_until': snoozedUntil,
      if (dismissedAt != null) 'dismissed_at': dismissedAt,
      if (notificationLocalId != null)
        'notification_local_id': notificationLocalId,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RemindersCompanion copyWith({
    Value<String>? id,
    Value<String>? itemId,
    Value<String?>? fieldKey,
    Value<String>? reminderType,
    Value<String>? sourceValue,
    Value<String>? sourceValueType,
    Value<int>? remindAt,
    Value<int>? advanceDays,
    Value<String?>? repeatRule,
    Value<bool>? enabled,
    Value<int?>? lastTriggeredAt,
    Value<int?>? nextTriggerAt,
    Value<int?>? snoozedUntil,
    Value<int?>? dismissedAt,
    Value<int?>? notificationLocalId,
    Value<String?>? note,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return RemindersCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      fieldKey: fieldKey ?? this.fieldKey,
      reminderType: reminderType ?? this.reminderType,
      sourceValue: sourceValue ?? this.sourceValue,
      sourceValueType: sourceValueType ?? this.sourceValueType,
      remindAt: remindAt ?? this.remindAt,
      advanceDays: advanceDays ?? this.advanceDays,
      repeatRule: repeatRule ?? this.repeatRule,
      enabled: enabled ?? this.enabled,
      lastTriggeredAt: lastTriggeredAt ?? this.lastTriggeredAt,
      nextTriggerAt: nextTriggerAt ?? this.nextTriggerAt,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      dismissedAt: dismissedAt ?? this.dismissedAt,
      notificationLocalId: notificationLocalId ?? this.notificationLocalId,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (fieldKey.present) {
      map['field_key'] = Variable<String>(fieldKey.value);
    }
    if (reminderType.present) {
      map['reminder_type'] = Variable<String>(reminderType.value);
    }
    if (sourceValue.present) {
      map['source_value'] = Variable<String>(sourceValue.value);
    }
    if (sourceValueType.present) {
      map['source_value_type'] = Variable<String>(sourceValueType.value);
    }
    if (remindAt.present) {
      map['remind_at'] = Variable<int>(remindAt.value);
    }
    if (advanceDays.present) {
      map['advance_days'] = Variable<int>(advanceDays.value);
    }
    if (repeatRule.present) {
      map['repeat_rule'] = Variable<String>(repeatRule.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (lastTriggeredAt.present) {
      map['last_triggered_at'] = Variable<int>(lastTriggeredAt.value);
    }
    if (nextTriggerAt.present) {
      map['next_trigger_at'] = Variable<int>(nextTriggerAt.value);
    }
    if (snoozedUntil.present) {
      map['snoozed_until'] = Variable<int>(snoozedUntil.value);
    }
    if (dismissedAt.present) {
      map['dismissed_at'] = Variable<int>(dismissedAt.value);
    }
    if (notificationLocalId.present) {
      map['notification_local_id'] = Variable<int>(notificationLocalId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemindersCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('fieldKey: $fieldKey, ')
          ..write('reminderType: $reminderType, ')
          ..write('sourceValue: $sourceValue, ')
          ..write('sourceValueType: $sourceValueType, ')
          ..write('remindAt: $remindAt, ')
          ..write('advanceDays: $advanceDays, ')
          ..write('repeatRule: $repeatRule, ')
          ..write('enabled: $enabled, ')
          ..write('lastTriggeredAt: $lastTriggeredAt, ')
          ..write('nextTriggerAt: $nextTriggerAt, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('dismissedAt: $dismissedAt, ')
          ..write('notificationLocalId: $notificationLocalId, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valueTypeMeta = const VerificationMeta(
    'valueType',
  );
  @override
  late final GeneratedColumn<String> valueType = GeneratedColumn<String>(
    'value_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, valueType, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('value_type')) {
      context.handle(
        _valueTypeMeta,
        valueType.isAcceptableOrUnknown(data['value_type']!, _valueTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_valueTypeMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
      valueType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_type'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  /// 设置 key
  final String key;

  /// 序列化后的设置值
  final String? value;

  /// 设置值类型
  final String valueType;

  /// 更新时间
  final int updatedAt;
  const AppSetting({
    required this.key,
    this.value,
    required this.valueType,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    map['value_type'] = Variable<String>(valueType);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      valueType: Value(valueType),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
      valueType: serializer.fromJson<String>(json['valueType']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
      'valueType': serializer.toJson<String>(valueType),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  AppSetting copyWith({
    String? key,
    Value<String?> value = const Value.absent(),
    String? valueType,
    int? updatedAt,
  }) => AppSetting(
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
    valueType: valueType ?? this.valueType,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      valueType: data.valueType.present ? data.valueType.value : this.valueType,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('valueType: $valueType, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, valueType, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value &&
          other.valueType == this.valueType &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String?> value;
  final Value<String> valueType;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.valueType = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    required String valueType,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       valueType = Value(valueType),
       updatedAt = Value(updatedAt);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<String>? valueType,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (valueType != null) 'value_type': valueType,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String?>? value,
    Value<String>? valueType,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      valueType: valueType ?? this.valueType,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (valueType.present) {
      map['value_type'] = Variable<String>(valueType.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('valueType: $valueType, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LicenseStateTable extends LicenseState
    with TableInfo<$LicenseStateTable, LicenseStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LicenseStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _licenseTypeMeta = const VerificationMeta(
    'licenseType',
  );
  @override
  late final GeneratedColumn<String> licenseType = GeneratedColumn<String>(
    'license_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('free'),
  );
  static const VerificationMeta _activatedAtMeta = const VerificationMeta(
    'activatedAt',
  );
  @override
  late final GeneratedColumn<int> activatedAt = GeneratedColumn<int>(
    'activated_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<int> expiresAt = GeneratedColumn<int>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _licensePayloadHashMeta =
      const VerificationMeta('licensePayloadHash');
  @override
  late final GeneratedColumn<String> licensePayloadHash =
      GeneratedColumn<String>(
        'license_payload_hash',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastVerifiedAtMeta = const VerificationMeta(
    'lastVerifiedAt',
  );
  @override
  late final GeneratedColumn<int> lastVerifiedAt = GeneratedColumn<int>(
    'last_verified_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('invalid'),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    licenseType,
    activatedAt,
    expiresAt,
    licensePayloadHash,
    lastVerifiedAt,
    status,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'license_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<LicenseStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('license_type')) {
      context.handle(
        _licenseTypeMeta,
        licenseType.isAcceptableOrUnknown(
          data['license_type']!,
          _licenseTypeMeta,
        ),
      );
    }
    if (data.containsKey('activated_at')) {
      context.handle(
        _activatedAtMeta,
        activatedAt.isAcceptableOrUnknown(
          data['activated_at']!,
          _activatedAtMeta,
        ),
      );
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    if (data.containsKey('license_payload_hash')) {
      context.handle(
        _licensePayloadHashMeta,
        licensePayloadHash.isAcceptableOrUnknown(
          data['license_payload_hash']!,
          _licensePayloadHashMeta,
        ),
      );
    }
    if (data.containsKey('last_verified_at')) {
      context.handle(
        _lastVerifiedAtMeta,
        lastVerifiedAt.isAcceptableOrUnknown(
          data['last_verified_at']!,
          _lastVerifiedAtMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LicenseStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LicenseStateData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      licenseType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}license_type'],
      )!,
      activatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}activated_at'],
      ),
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expires_at'],
      ),
      licensePayloadHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}license_payload_hash'],
      ),
      lastVerifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_verified_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LicenseStateTable createAlias(String alias) {
    return $LicenseStateTable(attachedDatabase, alias);
  }
}

class LicenseStateData extends DataClass
    implements Insertable<LicenseStateData> {
  /// 固定单行 ID: current_license_state
  final String id;

  /// 激活状态：free (免费) / pro (专业版)
  final String licenseType;

  /// 激活完成时间戳
  final int? activatedAt;

  /// 离线激活有效期截止时间
  final int? expiresAt;

  /// 激活数据的特征签名值
  final String? licensePayloadHash;

  /// 最近一次本地策略验证的时间
  final int? lastVerifiedAt;

  /// 状态：active (活跃) / expired (已过期) / invalid (失效)
  final String status;

  /// 更新时间
  final int updatedAt;
  const LicenseStateData({
    required this.id,
    required this.licenseType,
    this.activatedAt,
    this.expiresAt,
    this.licensePayloadHash,
    this.lastVerifiedAt,
    required this.status,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['license_type'] = Variable<String>(licenseType);
    if (!nullToAbsent || activatedAt != null) {
      map['activated_at'] = Variable<int>(activatedAt);
    }
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<int>(expiresAt);
    }
    if (!nullToAbsent || licensePayloadHash != null) {
      map['license_payload_hash'] = Variable<String>(licensePayloadHash);
    }
    if (!nullToAbsent || lastVerifiedAt != null) {
      map['last_verified_at'] = Variable<int>(lastVerifiedAt);
    }
    map['status'] = Variable<String>(status);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  LicenseStateCompanion toCompanion(bool nullToAbsent) {
    return LicenseStateCompanion(
      id: Value(id),
      licenseType: Value(licenseType),
      activatedAt: activatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(activatedAt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      licensePayloadHash: licensePayloadHash == null && nullToAbsent
          ? const Value.absent()
          : Value(licensePayloadHash),
      lastVerifiedAt: lastVerifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastVerifiedAt),
      status: Value(status),
      updatedAt: Value(updatedAt),
    );
  }

  factory LicenseStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LicenseStateData(
      id: serializer.fromJson<String>(json['id']),
      licenseType: serializer.fromJson<String>(json['licenseType']),
      activatedAt: serializer.fromJson<int?>(json['activatedAt']),
      expiresAt: serializer.fromJson<int?>(json['expiresAt']),
      licensePayloadHash: serializer.fromJson<String?>(
        json['licensePayloadHash'],
      ),
      lastVerifiedAt: serializer.fromJson<int?>(json['lastVerifiedAt']),
      status: serializer.fromJson<String>(json['status']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'licenseType': serializer.toJson<String>(licenseType),
      'activatedAt': serializer.toJson<int?>(activatedAt),
      'expiresAt': serializer.toJson<int?>(expiresAt),
      'licensePayloadHash': serializer.toJson<String?>(licensePayloadHash),
      'lastVerifiedAt': serializer.toJson<int?>(lastVerifiedAt),
      'status': serializer.toJson<String>(status),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  LicenseStateData copyWith({
    String? id,
    String? licenseType,
    Value<int?> activatedAt = const Value.absent(),
    Value<int?> expiresAt = const Value.absent(),
    Value<String?> licensePayloadHash = const Value.absent(),
    Value<int?> lastVerifiedAt = const Value.absent(),
    String? status,
    int? updatedAt,
  }) => LicenseStateData(
    id: id ?? this.id,
    licenseType: licenseType ?? this.licenseType,
    activatedAt: activatedAt.present ? activatedAt.value : this.activatedAt,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
    licensePayloadHash: licensePayloadHash.present
        ? licensePayloadHash.value
        : this.licensePayloadHash,
    lastVerifiedAt: lastVerifiedAt.present
        ? lastVerifiedAt.value
        : this.lastVerifiedAt,
    status: status ?? this.status,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LicenseStateData copyWithCompanion(LicenseStateCompanion data) {
    return LicenseStateData(
      id: data.id.present ? data.id.value : this.id,
      licenseType: data.licenseType.present
          ? data.licenseType.value
          : this.licenseType,
      activatedAt: data.activatedAt.present
          ? data.activatedAt.value
          : this.activatedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      licensePayloadHash: data.licensePayloadHash.present
          ? data.licensePayloadHash.value
          : this.licensePayloadHash,
      lastVerifiedAt: data.lastVerifiedAt.present
          ? data.lastVerifiedAt.value
          : this.lastVerifiedAt,
      status: data.status.present ? data.status.value : this.status,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LicenseStateData(')
          ..write('id: $id, ')
          ..write('licenseType: $licenseType, ')
          ..write('activatedAt: $activatedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('licensePayloadHash: $licensePayloadHash, ')
          ..write('lastVerifiedAt: $lastVerifiedAt, ')
          ..write('status: $status, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    licenseType,
    activatedAt,
    expiresAt,
    licensePayloadHash,
    lastVerifiedAt,
    status,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LicenseStateData &&
          other.id == this.id &&
          other.licenseType == this.licenseType &&
          other.activatedAt == this.activatedAt &&
          other.expiresAt == this.expiresAt &&
          other.licensePayloadHash == this.licensePayloadHash &&
          other.lastVerifiedAt == this.lastVerifiedAt &&
          other.status == this.status &&
          other.updatedAt == this.updatedAt);
}

class LicenseStateCompanion extends UpdateCompanion<LicenseStateData> {
  final Value<String> id;
  final Value<String> licenseType;
  final Value<int?> activatedAt;
  final Value<int?> expiresAt;
  final Value<String?> licensePayloadHash;
  final Value<int?> lastVerifiedAt;
  final Value<String> status;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const LicenseStateCompanion({
    this.id = const Value.absent(),
    this.licenseType = const Value.absent(),
    this.activatedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.licensePayloadHash = const Value.absent(),
    this.lastVerifiedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LicenseStateCompanion.insert({
    required String id,
    this.licenseType = const Value.absent(),
    this.activatedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.licensePayloadHash = const Value.absent(),
    this.lastVerifiedAt = const Value.absent(),
    this.status = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt);
  static Insertable<LicenseStateData> custom({
    Expression<String>? id,
    Expression<String>? licenseType,
    Expression<int>? activatedAt,
    Expression<int>? expiresAt,
    Expression<String>? licensePayloadHash,
    Expression<int>? lastVerifiedAt,
    Expression<String>? status,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (licenseType != null) 'license_type': licenseType,
      if (activatedAt != null) 'activated_at': activatedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (licensePayloadHash != null)
        'license_payload_hash': licensePayloadHash,
      if (lastVerifiedAt != null) 'last_verified_at': lastVerifiedAt,
      if (status != null) 'status': status,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LicenseStateCompanion copyWith({
    Value<String>? id,
    Value<String>? licenseType,
    Value<int?>? activatedAt,
    Value<int?>? expiresAt,
    Value<String?>? licensePayloadHash,
    Value<int?>? lastVerifiedAt,
    Value<String>? status,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return LicenseStateCompanion(
      id: id ?? this.id,
      licenseType: licenseType ?? this.licenseType,
      activatedAt: activatedAt ?? this.activatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      licensePayloadHash: licensePayloadHash ?? this.licensePayloadHash,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (licenseType.present) {
      map['license_type'] = Variable<String>(licenseType.value);
    }
    if (activatedAt.present) {
      map['activated_at'] = Variable<int>(activatedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<int>(expiresAt.value);
    }
    if (licensePayloadHash.present) {
      map['license_payload_hash'] = Variable<String>(licensePayloadHash.value);
    }
    if (lastVerifiedAt.present) {
      map['last_verified_at'] = Variable<int>(lastVerifiedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LicenseStateCompanion(')
          ..write('id: $id, ')
          ..write('licenseType: $licenseType, ')
          ..write('activatedAt: $activatedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('licensePayloadHash: $licensePayloadHash, ')
          ..write('lastVerifiedAt: $lastVerifiedAt, ')
          ..write('status: $status, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemChildEntriesTable extends ItemChildEntries
    with TableInfo<$ItemChildEntriesTable, ItemChildEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemChildEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _childTypeMeta = const VerificationMeta(
    'childType',
  );
  @override
  late final GeneratedColumn<String> childType = GeneratedColumn<String>(
    'child_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    itemId,
    childType,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'item_child_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemChildEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('child_type')) {
      context.handle(
        _childTypeMeta,
        childType.isAcceptableOrUnknown(data['child_type']!, _childTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_childTypeMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {itemId, childType, sortOrder},
  ];
  @override
  ItemChildEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemChildEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      childType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}child_type'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ItemChildEntriesTable createAlias(String alias) {
    return $ItemChildEntriesTable(attachedDatabase, alias);
  }
}

class ItemChildEntry extends DataClass implements Insertable<ItemChildEntry> {
  /// 主键 UUID
  final String id;

  /// 所属资料 ID，外键级联删除
  final String itemId;

  /// 子项类型（例如 'household_member'）
  final String childType;

  /// 字段显示顺序
  final int sortOrder;

  /// 创建时间
  final int createdAt;

  /// 更新时间
  final int updatedAt;
  const ItemChildEntry({
    required this.id,
    required this.itemId,
    required this.childType,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<String>(itemId);
    map['child_type'] = Variable<String>(childType);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ItemChildEntriesCompanion toCompanion(bool nullToAbsent) {
    return ItemChildEntriesCompanion(
      id: Value(id),
      itemId: Value(itemId),
      childType: Value(childType),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ItemChildEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemChildEntry(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      childType: serializer.fromJson<String>(json['childType']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<String>(itemId),
      'childType': serializer.toJson<String>(childType),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ItemChildEntry copyWith({
    String? id,
    String? itemId,
    String? childType,
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
  }) => ItemChildEntry(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    childType: childType ?? this.childType,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ItemChildEntry copyWithCompanion(ItemChildEntriesCompanion data) {
    return ItemChildEntry(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      childType: data.childType.present ? data.childType.value : this.childType,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemChildEntry(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('childType: $childType, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, itemId, childType, sortOrder, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemChildEntry &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.childType == this.childType &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ItemChildEntriesCompanion extends UpdateCompanion<ItemChildEntry> {
  final Value<String> id;
  final Value<String> itemId;
  final Value<String> childType;
  final Value<int> sortOrder;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ItemChildEntriesCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.childType = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemChildEntriesCompanion.insert({
    required String id,
    required String itemId,
    required String childType,
    this.sortOrder = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       itemId = Value(itemId),
       childType = Value(childType),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ItemChildEntry> custom({
    Expression<String>? id,
    Expression<String>? itemId,
    Expression<String>? childType,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (childType != null) 'child_type': childType,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemChildEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? itemId,
    Value<String>? childType,
    Value<int>? sortOrder,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ItemChildEntriesCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      childType: childType ?? this.childType,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (childType.present) {
      map['child_type'] = Variable<String>(childType.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemChildEntriesCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('childType: $childType, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemChildFieldsTable extends ItemChildFields
    with TableInfo<$ItemChildFieldsTable, ItemChildField> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemChildFieldsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _childEntryIdMeta = const VerificationMeta(
    'childEntryId',
  );
  @override
  late final GeneratedColumn<String> childEntryId = GeneratedColumn<String>(
    'child_entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES item_child_entries (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _fieldKeyMeta = const VerificationMeta(
    'fieldKey',
  );
  @override
  late final GeneratedColumn<String> fieldKey = GeneratedColumn<String>(
    'field_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueTextMeta = const VerificationMeta(
    'valueText',
  );
  @override
  late final GeneratedColumn<String> valueText = GeneratedColumn<String>(
    'value_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valueTypeMeta = const VerificationMeta(
    'valueType',
  );
  @override
  late final GeneratedColumn<String> valueType = GeneratedColumn<String>(
    'value_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sensitiveLevelMeta = const VerificationMeta(
    'sensitiveLevel',
  );
  @override
  late final GeneratedColumn<String> sensitiveLevel = GeneratedColumn<String>(
    'sensitive_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _copyableMeta = const VerificationMeta(
    'copyable',
  );
  @override
  late final GeneratedColumn<bool> copyable = GeneratedColumn<bool>(
    'copyable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("copyable" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _searchableMeta = const VerificationMeta(
    'searchable',
  );
  @override
  late final GeneratedColumn<bool> searchable = GeneratedColumn<bool>(
    'searchable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("searchable" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<bool> summary = GeneratedColumn<bool>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("summary" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    childEntryId,
    fieldKey,
    label,
    valueText,
    valueType,
    sensitiveLevel,
    copyable,
    searchable,
    summary,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'item_child_fields';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemChildField> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('child_entry_id')) {
      context.handle(
        _childEntryIdMeta,
        childEntryId.isAcceptableOrUnknown(
          data['child_entry_id']!,
          _childEntryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_childEntryIdMeta);
    }
    if (data.containsKey('field_key')) {
      context.handle(
        _fieldKeyMeta,
        fieldKey.isAcceptableOrUnknown(data['field_key']!, _fieldKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldKeyMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('value_text')) {
      context.handle(
        _valueTextMeta,
        valueText.isAcceptableOrUnknown(data['value_text']!, _valueTextMeta),
      );
    }
    if (data.containsKey('value_type')) {
      context.handle(
        _valueTypeMeta,
        valueType.isAcceptableOrUnknown(data['value_type']!, _valueTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_valueTypeMeta);
    }
    if (data.containsKey('sensitive_level')) {
      context.handle(
        _sensitiveLevelMeta,
        sensitiveLevel.isAcceptableOrUnknown(
          data['sensitive_level']!,
          _sensitiveLevelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sensitiveLevelMeta);
    }
    if (data.containsKey('copyable')) {
      context.handle(
        _copyableMeta,
        copyable.isAcceptableOrUnknown(data['copyable']!, _copyableMeta),
      );
    }
    if (data.containsKey('searchable')) {
      context.handle(
        _searchableMeta,
        searchable.isAcceptableOrUnknown(data['searchable']!, _searchableMeta),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {childEntryId, fieldKey},
  ];
  @override
  ItemChildField map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemChildField(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      childEntryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}child_entry_id'],
      )!,
      fieldKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_key'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      valueText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_text'],
      ),
      valueType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_type'],
      )!,
      sensitiveLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sensitive_level'],
      )!,
      copyable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}copyable'],
      )!,
      searchable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}searchable'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}summary'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ItemChildFieldsTable createAlias(String alias) {
    return $ItemChildFieldsTable(attachedDatabase, alias);
  }
}

class ItemChildField extends DataClass implements Insertable<ItemChildField> {
  /// 主键 UUID
  final String id;

  /// 所属子项 ID，外键级联删除
  final String childEntryId;

  /// 字段 Key
  final String fieldKey;

  /// 字段展示中文名
  final String label;

  /// 原始展示明文值
  final String? valueText;

  /// 字段值格式类型
  final String valueType;

  /// 敏感级别
  final String sensitiveLevel;

  /// 是否可复制
  final bool copyable;

  /// 是否可被搜索索引
  final bool searchable;

  /// 是否作为摘要展现的来源之一
  final bool summary;

  /// 字段显示顺序
  final int sortOrder;

  /// 创建时间
  final int createdAt;

  /// 更新时间
  final int updatedAt;
  const ItemChildField({
    required this.id,
    required this.childEntryId,
    required this.fieldKey,
    required this.label,
    this.valueText,
    required this.valueType,
    required this.sensitiveLevel,
    required this.copyable,
    required this.searchable,
    required this.summary,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['child_entry_id'] = Variable<String>(childEntryId);
    map['field_key'] = Variable<String>(fieldKey);
    map['label'] = Variable<String>(label);
    if (!nullToAbsent || valueText != null) {
      map['value_text'] = Variable<String>(valueText);
    }
    map['value_type'] = Variable<String>(valueType);
    map['sensitive_level'] = Variable<String>(sensitiveLevel);
    map['copyable'] = Variable<bool>(copyable);
    map['searchable'] = Variable<bool>(searchable);
    map['summary'] = Variable<bool>(summary);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ItemChildFieldsCompanion toCompanion(bool nullToAbsent) {
    return ItemChildFieldsCompanion(
      id: Value(id),
      childEntryId: Value(childEntryId),
      fieldKey: Value(fieldKey),
      label: Value(label),
      valueText: valueText == null && nullToAbsent
          ? const Value.absent()
          : Value(valueText),
      valueType: Value(valueType),
      sensitiveLevel: Value(sensitiveLevel),
      copyable: Value(copyable),
      searchable: Value(searchable),
      summary: Value(summary),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ItemChildField.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemChildField(
      id: serializer.fromJson<String>(json['id']),
      childEntryId: serializer.fromJson<String>(json['childEntryId']),
      fieldKey: serializer.fromJson<String>(json['fieldKey']),
      label: serializer.fromJson<String>(json['label']),
      valueText: serializer.fromJson<String?>(json['valueText']),
      valueType: serializer.fromJson<String>(json['valueType']),
      sensitiveLevel: serializer.fromJson<String>(json['sensitiveLevel']),
      copyable: serializer.fromJson<bool>(json['copyable']),
      searchable: serializer.fromJson<bool>(json['searchable']),
      summary: serializer.fromJson<bool>(json['summary']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'childEntryId': serializer.toJson<String>(childEntryId),
      'fieldKey': serializer.toJson<String>(fieldKey),
      'label': serializer.toJson<String>(label),
      'valueText': serializer.toJson<String?>(valueText),
      'valueType': serializer.toJson<String>(valueType),
      'sensitiveLevel': serializer.toJson<String>(sensitiveLevel),
      'copyable': serializer.toJson<bool>(copyable),
      'searchable': serializer.toJson<bool>(searchable),
      'summary': serializer.toJson<bool>(summary),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ItemChildField copyWith({
    String? id,
    String? childEntryId,
    String? fieldKey,
    String? label,
    Value<String?> valueText = const Value.absent(),
    String? valueType,
    String? sensitiveLevel,
    bool? copyable,
    bool? searchable,
    bool? summary,
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
  }) => ItemChildField(
    id: id ?? this.id,
    childEntryId: childEntryId ?? this.childEntryId,
    fieldKey: fieldKey ?? this.fieldKey,
    label: label ?? this.label,
    valueText: valueText.present ? valueText.value : this.valueText,
    valueType: valueType ?? this.valueType,
    sensitiveLevel: sensitiveLevel ?? this.sensitiveLevel,
    copyable: copyable ?? this.copyable,
    searchable: searchable ?? this.searchable,
    summary: summary ?? this.summary,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ItemChildField copyWithCompanion(ItemChildFieldsCompanion data) {
    return ItemChildField(
      id: data.id.present ? data.id.value : this.id,
      childEntryId: data.childEntryId.present
          ? data.childEntryId.value
          : this.childEntryId,
      fieldKey: data.fieldKey.present ? data.fieldKey.value : this.fieldKey,
      label: data.label.present ? data.label.value : this.label,
      valueText: data.valueText.present ? data.valueText.value : this.valueText,
      valueType: data.valueType.present ? data.valueType.value : this.valueType,
      sensitiveLevel: data.sensitiveLevel.present
          ? data.sensitiveLevel.value
          : this.sensitiveLevel,
      copyable: data.copyable.present ? data.copyable.value : this.copyable,
      searchable: data.searchable.present
          ? data.searchable.value
          : this.searchable,
      summary: data.summary.present ? data.summary.value : this.summary,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemChildField(')
          ..write('id: $id, ')
          ..write('childEntryId: $childEntryId, ')
          ..write('fieldKey: $fieldKey, ')
          ..write('label: $label, ')
          ..write('valueText: $valueText, ')
          ..write('valueType: $valueType, ')
          ..write('sensitiveLevel: $sensitiveLevel, ')
          ..write('copyable: $copyable, ')
          ..write('searchable: $searchable, ')
          ..write('summary: $summary, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    childEntryId,
    fieldKey,
    label,
    valueText,
    valueType,
    sensitiveLevel,
    copyable,
    searchable,
    summary,
    sortOrder,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemChildField &&
          other.id == this.id &&
          other.childEntryId == this.childEntryId &&
          other.fieldKey == this.fieldKey &&
          other.label == this.label &&
          other.valueText == this.valueText &&
          other.valueType == this.valueType &&
          other.sensitiveLevel == this.sensitiveLevel &&
          other.copyable == this.copyable &&
          other.searchable == this.searchable &&
          other.summary == this.summary &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ItemChildFieldsCompanion extends UpdateCompanion<ItemChildField> {
  final Value<String> id;
  final Value<String> childEntryId;
  final Value<String> fieldKey;
  final Value<String> label;
  final Value<String?> valueText;
  final Value<String> valueType;
  final Value<String> sensitiveLevel;
  final Value<bool> copyable;
  final Value<bool> searchable;
  final Value<bool> summary;
  final Value<int> sortOrder;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ItemChildFieldsCompanion({
    this.id = const Value.absent(),
    this.childEntryId = const Value.absent(),
    this.fieldKey = const Value.absent(),
    this.label = const Value.absent(),
    this.valueText = const Value.absent(),
    this.valueType = const Value.absent(),
    this.sensitiveLevel = const Value.absent(),
    this.copyable = const Value.absent(),
    this.searchable = const Value.absent(),
    this.summary = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemChildFieldsCompanion.insert({
    required String id,
    required String childEntryId,
    required String fieldKey,
    required String label,
    this.valueText = const Value.absent(),
    required String valueType,
    required String sensitiveLevel,
    this.copyable = const Value.absent(),
    this.searchable = const Value.absent(),
    this.summary = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       childEntryId = Value(childEntryId),
       fieldKey = Value(fieldKey),
       label = Value(label),
       valueType = Value(valueType),
       sensitiveLevel = Value(sensitiveLevel),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ItemChildField> custom({
    Expression<String>? id,
    Expression<String>? childEntryId,
    Expression<String>? fieldKey,
    Expression<String>? label,
    Expression<String>? valueText,
    Expression<String>? valueType,
    Expression<String>? sensitiveLevel,
    Expression<bool>? copyable,
    Expression<bool>? searchable,
    Expression<bool>? summary,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (childEntryId != null) 'child_entry_id': childEntryId,
      if (fieldKey != null) 'field_key': fieldKey,
      if (label != null) 'label': label,
      if (valueText != null) 'value_text': valueText,
      if (valueType != null) 'value_type': valueType,
      if (sensitiveLevel != null) 'sensitive_level': sensitiveLevel,
      if (copyable != null) 'copyable': copyable,
      if (searchable != null) 'searchable': searchable,
      if (summary != null) 'summary': summary,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemChildFieldsCompanion copyWith({
    Value<String>? id,
    Value<String>? childEntryId,
    Value<String>? fieldKey,
    Value<String>? label,
    Value<String?>? valueText,
    Value<String>? valueType,
    Value<String>? sensitiveLevel,
    Value<bool>? copyable,
    Value<bool>? searchable,
    Value<bool>? summary,
    Value<int>? sortOrder,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ItemChildFieldsCompanion(
      id: id ?? this.id,
      childEntryId: childEntryId ?? this.childEntryId,
      fieldKey: fieldKey ?? this.fieldKey,
      label: label ?? this.label,
      valueText: valueText ?? this.valueText,
      valueType: valueType ?? this.valueType,
      sensitiveLevel: sensitiveLevel ?? this.sensitiveLevel,
      copyable: copyable ?? this.copyable,
      searchable: searchable ?? this.searchable,
      summary: summary ?? this.summary,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (childEntryId.present) {
      map['child_entry_id'] = Variable<String>(childEntryId.value);
    }
    if (fieldKey.present) {
      map['field_key'] = Variable<String>(fieldKey.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (valueText.present) {
      map['value_text'] = Variable<String>(valueText.value);
    }
    if (valueType.present) {
      map['value_type'] = Variable<String>(valueType.value);
    }
    if (sensitiveLevel.present) {
      map['sensitive_level'] = Variable<String>(sensitiveLevel.value);
    }
    if (copyable.present) {
      map['copyable'] = Variable<bool>(copyable.value);
    }
    if (searchable.present) {
      map['searchable'] = Variable<bool>(searchable.value);
    }
    if (summary.present) {
      map['summary'] = Variable<bool>(summary.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemChildFieldsCompanion(')
          ..write('id: $id, ')
          ..write('childEntryId: $childEntryId, ')
          ..write('fieldKey: $fieldKey, ')
          ..write('label: $label, ')
          ..write('valueText: $valueText, ')
          ..write('valueType: $valueType, ')
          ..write('sensitiveLevel: $sensitiveLevel, ')
          ..write('copyable: $copyable, ')
          ..write('searchable: $searchable, ')
          ..write('summary: $summary, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemEventsTable extends ItemEvents
    with TableInfo<$ItemEventsTable, ItemEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>(
      "event_type IN ('created', 'updated', 'archived', 'unarchived', 'moved_to_trash', 'restored', 'imported')",
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<int> occurredAt = GeneratedColumn<int>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, itemId, eventType, occurredAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'item_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ItemEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurred_at'],
      )!,
    );
  }

  @override
  $ItemEventsTable createAlias(String alias) {
    return $ItemEventsTable(attachedDatabase, alias);
  }
}

class ItemEvent extends DataClass implements Insertable<ItemEvent> {
  final String id;
  final String itemId;
  final String eventType;
  final int occurredAt;
  const ItemEvent({
    required this.id,
    required this.itemId,
    required this.eventType,
    required this.occurredAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<String>(itemId);
    map['event_type'] = Variable<String>(eventType);
    map['occurred_at'] = Variable<int>(occurredAt);
    return map;
  }

  ItemEventsCompanion toCompanion(bool nullToAbsent) {
    return ItemEventsCompanion(
      id: Value(id),
      itemId: Value(itemId),
      eventType: Value(eventType),
      occurredAt: Value(occurredAt),
    );
  }

  factory ItemEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemEvent(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      eventType: serializer.fromJson<String>(json['eventType']),
      occurredAt: serializer.fromJson<int>(json['occurredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<String>(itemId),
      'eventType': serializer.toJson<String>(eventType),
      'occurredAt': serializer.toJson<int>(occurredAt),
    };
  }

  ItemEvent copyWith({
    String? id,
    String? itemId,
    String? eventType,
    int? occurredAt,
  }) => ItemEvent(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    eventType: eventType ?? this.eventType,
    occurredAt: occurredAt ?? this.occurredAt,
  );
  ItemEvent copyWithCompanion(ItemEventsCompanion data) {
    return ItemEvent(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemEvent(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('eventType: $eventType, ')
          ..write('occurredAt: $occurredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, itemId, eventType, occurredAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemEvent &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.eventType == this.eventType &&
          other.occurredAt == this.occurredAt);
}

class ItemEventsCompanion extends UpdateCompanion<ItemEvent> {
  final Value<String> id;
  final Value<String> itemId;
  final Value<String> eventType;
  final Value<int> occurredAt;
  final Value<int> rowid;
  const ItemEventsCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.eventType = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemEventsCompanion.insert({
    required String id,
    required String itemId,
    required String eventType,
    required int occurredAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       itemId = Value(itemId),
       eventType = Value(eventType),
       occurredAt = Value(occurredAt);
  static Insertable<ItemEvent> custom({
    Expression<String>? id,
    Expression<String>? itemId,
    Expression<String>? eventType,
    Expression<int>? occurredAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (eventType != null) 'event_type': eventType,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? itemId,
    Value<String>? eventType,
    Value<int>? occurredAt,
    Value<int>? rowid,
  }) {
    return ItemEventsCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      eventType: eventType ?? this.eventType,
      occurredAt: occurredAt ?? this.occurredAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<int>(occurredAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemEventsCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('eventType: $eventType, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemEventChangesTable extends ItemEventChanges
    with TableInfo<$ItemEventChangesTable, ItemEventChange> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemEventChangesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES item_events (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _changeKindMeta = const VerificationMeta(
    'changeKind',
  );
  @override
  late final GeneratedColumn<String> changeKind = GeneratedColumn<String>(
    'change_kind',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>(
      "change_kind IN ('value_changed', 'field_changed', 'attachment_count_changed')",
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectKeyMeta = const VerificationMeta(
    'subjectKey',
  );
  @override
  late final GeneratedColumn<String> subjectKey = GeneratedColumn<String>(
    'subject_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectLabelMeta = const VerificationMeta(
    'subjectLabel',
  );
  @override
  late final GeneratedColumn<String> subjectLabel = GeneratedColumn<String>(
    'subject_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _oldValueMeta = const VerificationMeta(
    'oldValue',
  );
  @override
  late final GeneratedColumn<String> oldValue = GeneratedColumn<String>(
    'old_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _newValueMeta = const VerificationMeta(
    'newValue',
  );
  @override
  late final GeneratedColumn<String> newValue = GeneratedColumn<String>(
    'new_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventId,
    changeKind,
    subjectKey,
    subjectLabel,
    oldValue,
    newValue,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'item_event_changes';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemEventChange> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('change_kind')) {
      context.handle(
        _changeKindMeta,
        changeKind.isAcceptableOrUnknown(data['change_kind']!, _changeKindMeta),
      );
    } else if (isInserting) {
      context.missing(_changeKindMeta);
    }
    if (data.containsKey('subject_key')) {
      context.handle(
        _subjectKeyMeta,
        subjectKey.isAcceptableOrUnknown(data['subject_key']!, _subjectKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectKeyMeta);
    }
    if (data.containsKey('subject_label')) {
      context.handle(
        _subjectLabelMeta,
        subjectLabel.isAcceptableOrUnknown(
          data['subject_label']!,
          _subjectLabelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subjectLabelMeta);
    }
    if (data.containsKey('old_value')) {
      context.handle(
        _oldValueMeta,
        oldValue.isAcceptableOrUnknown(data['old_value']!, _oldValueMeta),
      );
    }
    if (data.containsKey('new_value')) {
      context.handle(
        _newValueMeta,
        newValue.isAcceptableOrUnknown(data['new_value']!, _newValueMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ItemEventChange map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemEventChange(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      changeKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}change_kind'],
      )!,
      subjectKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_key'],
      )!,
      subjectLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_label'],
      )!,
      oldValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}old_value'],
      ),
      newValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}new_value'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $ItemEventChangesTable createAlias(String alias) {
    return $ItemEventChangesTable(attachedDatabase, alias);
  }
}

class ItemEventChange extends DataClass implements Insertable<ItemEventChange> {
  final String id;
  final String eventId;
  final String changeKind;
  final String subjectKey;
  final String subjectLabel;
  final String? oldValue;
  final String? newValue;
  final int sortOrder;
  const ItemEventChange({
    required this.id,
    required this.eventId,
    required this.changeKind,
    required this.subjectKey,
    required this.subjectLabel,
    this.oldValue,
    this.newValue,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['event_id'] = Variable<String>(eventId);
    map['change_kind'] = Variable<String>(changeKind);
    map['subject_key'] = Variable<String>(subjectKey);
    map['subject_label'] = Variable<String>(subjectLabel);
    if (!nullToAbsent || oldValue != null) {
      map['old_value'] = Variable<String>(oldValue);
    }
    if (!nullToAbsent || newValue != null) {
      map['new_value'] = Variable<String>(newValue);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  ItemEventChangesCompanion toCompanion(bool nullToAbsent) {
    return ItemEventChangesCompanion(
      id: Value(id),
      eventId: Value(eventId),
      changeKind: Value(changeKind),
      subjectKey: Value(subjectKey),
      subjectLabel: Value(subjectLabel),
      oldValue: oldValue == null && nullToAbsent
          ? const Value.absent()
          : Value(oldValue),
      newValue: newValue == null && nullToAbsent
          ? const Value.absent()
          : Value(newValue),
      sortOrder: Value(sortOrder),
    );
  }

  factory ItemEventChange.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemEventChange(
      id: serializer.fromJson<String>(json['id']),
      eventId: serializer.fromJson<String>(json['eventId']),
      changeKind: serializer.fromJson<String>(json['changeKind']),
      subjectKey: serializer.fromJson<String>(json['subjectKey']),
      subjectLabel: serializer.fromJson<String>(json['subjectLabel']),
      oldValue: serializer.fromJson<String?>(json['oldValue']),
      newValue: serializer.fromJson<String?>(json['newValue']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'eventId': serializer.toJson<String>(eventId),
      'changeKind': serializer.toJson<String>(changeKind),
      'subjectKey': serializer.toJson<String>(subjectKey),
      'subjectLabel': serializer.toJson<String>(subjectLabel),
      'oldValue': serializer.toJson<String?>(oldValue),
      'newValue': serializer.toJson<String?>(newValue),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  ItemEventChange copyWith({
    String? id,
    String? eventId,
    String? changeKind,
    String? subjectKey,
    String? subjectLabel,
    Value<String?> oldValue = const Value.absent(),
    Value<String?> newValue = const Value.absent(),
    int? sortOrder,
  }) => ItemEventChange(
    id: id ?? this.id,
    eventId: eventId ?? this.eventId,
    changeKind: changeKind ?? this.changeKind,
    subjectKey: subjectKey ?? this.subjectKey,
    subjectLabel: subjectLabel ?? this.subjectLabel,
    oldValue: oldValue.present ? oldValue.value : this.oldValue,
    newValue: newValue.present ? newValue.value : this.newValue,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  ItemEventChange copyWithCompanion(ItemEventChangesCompanion data) {
    return ItemEventChange(
      id: data.id.present ? data.id.value : this.id,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      changeKind: data.changeKind.present
          ? data.changeKind.value
          : this.changeKind,
      subjectKey: data.subjectKey.present
          ? data.subjectKey.value
          : this.subjectKey,
      subjectLabel: data.subjectLabel.present
          ? data.subjectLabel.value
          : this.subjectLabel,
      oldValue: data.oldValue.present ? data.oldValue.value : this.oldValue,
      newValue: data.newValue.present ? data.newValue.value : this.newValue,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemEventChange(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('changeKind: $changeKind, ')
          ..write('subjectKey: $subjectKey, ')
          ..write('subjectLabel: $subjectLabel, ')
          ..write('oldValue: $oldValue, ')
          ..write('newValue: $newValue, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    eventId,
    changeKind,
    subjectKey,
    subjectLabel,
    oldValue,
    newValue,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemEventChange &&
          other.id == this.id &&
          other.eventId == this.eventId &&
          other.changeKind == this.changeKind &&
          other.subjectKey == this.subjectKey &&
          other.subjectLabel == this.subjectLabel &&
          other.oldValue == this.oldValue &&
          other.newValue == this.newValue &&
          other.sortOrder == this.sortOrder);
}

class ItemEventChangesCompanion extends UpdateCompanion<ItemEventChange> {
  final Value<String> id;
  final Value<String> eventId;
  final Value<String> changeKind;
  final Value<String> subjectKey;
  final Value<String> subjectLabel;
  final Value<String?> oldValue;
  final Value<String?> newValue;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const ItemEventChangesCompanion({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    this.changeKind = const Value.absent(),
    this.subjectKey = const Value.absent(),
    this.subjectLabel = const Value.absent(),
    this.oldValue = const Value.absent(),
    this.newValue = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemEventChangesCompanion.insert({
    required String id,
    required String eventId,
    required String changeKind,
    required String subjectKey,
    required String subjectLabel,
    this.oldValue = const Value.absent(),
    this.newValue = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       eventId = Value(eventId),
       changeKind = Value(changeKind),
       subjectKey = Value(subjectKey),
       subjectLabel = Value(subjectLabel);
  static Insertable<ItemEventChange> custom({
    Expression<String>? id,
    Expression<String>? eventId,
    Expression<String>? changeKind,
    Expression<String>? subjectKey,
    Expression<String>? subjectLabel,
    Expression<String>? oldValue,
    Expression<String>? newValue,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventId != null) 'event_id': eventId,
      if (changeKind != null) 'change_kind': changeKind,
      if (subjectKey != null) 'subject_key': subjectKey,
      if (subjectLabel != null) 'subject_label': subjectLabel,
      if (oldValue != null) 'old_value': oldValue,
      if (newValue != null) 'new_value': newValue,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemEventChangesCompanion copyWith({
    Value<String>? id,
    Value<String>? eventId,
    Value<String>? changeKind,
    Value<String>? subjectKey,
    Value<String>? subjectLabel,
    Value<String?>? oldValue,
    Value<String?>? newValue,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return ItemEventChangesCompanion(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      changeKind: changeKind ?? this.changeKind,
      subjectKey: subjectKey ?? this.subjectKey,
      subjectLabel: subjectLabel ?? this.subjectLabel,
      oldValue: oldValue ?? this.oldValue,
      newValue: newValue ?? this.newValue,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (changeKind.present) {
      map['change_kind'] = Variable<String>(changeKind.value);
    }
    if (subjectKey.present) {
      map['subject_key'] = Variable<String>(subjectKey.value);
    }
    if (subjectLabel.present) {
      map['subject_label'] = Variable<String>(subjectLabel.value);
    }
    if (oldValue.present) {
      map['old_value'] = Variable<String>(oldValue.value);
    }
    if (newValue.present) {
      map['new_value'] = Variable<String>(newValue.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemEventChangesCompanion(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('changeKind: $changeKind, ')
          ..write('subjectKey: $subjectKey, ')
          ..write('subjectLabel: $subjectLabel, ')
          ..write('oldValue: $oldValue, ')
          ..write('newValue: $newValue, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MembersTable members = $MembersTable(this);
  late final $ItemsTable items = $ItemsTable(this);
  late final $ItemFieldsTable itemFields = $ItemFieldsTable(this);
  late final $AttachmentsTable attachments = $AttachmentsTable(this);
  late final $RemindersTable reminders = $RemindersTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $LicenseStateTable licenseState = $LicenseStateTable(this);
  late final $ItemChildEntriesTable itemChildEntries = $ItemChildEntriesTable(
    this,
  );
  late final $ItemChildFieldsTable itemChildFields = $ItemChildFieldsTable(
    this,
  );
  late final $ItemEventsTable itemEvents = $ItemEventsTable(this);
  late final $ItemEventChangesTable itemEventChanges = $ItemEventChangesTable(
    this,
  );
  late final Index idxMembersTypeSort = Index(
    'idx_members_type_sort',
    'CREATE INDEX idx_members_type_sort ON members (member_type, sort_order)',
  );
  late final Index idxMembersArchived = Index(
    'idx_members_archived',
    'CREATE INDEX idx_members_archived ON members (is_archived)',
  );
  late final Index idxItemsMemberStatus = Index(
    'idx_items_member_status',
    'CREATE INDEX idx_items_member_status ON items (member_id, status)',
  );
  late final Index idxItemsCategoryType = Index(
    'idx_items_category_type',
    'CREATE INDEX idx_items_category_type ON items (category_key, type_key)',
  );
  late final Index idxItemsActivePinnedAt = Index(
    'idx_items_active_pinned_at',
    'CREATE INDEX idx_items_active_pinned_at ON items (status, is_pinned, pinned_at)',
  );
  late final Index idxItemsStatusDeletedAt = Index(
    'idx_items_status_deleted_at',
    'CREATE INDEX idx_items_status_deleted_at ON items (status, deleted_at)',
  );
  late final Index idxFieldsItemSort = Index(
    'idx_fields_item_sort',
    'CREATE INDEX idx_fields_item_sort ON item_fields (item_id, sort_order)',
  );
  late final Index idxFieldsNormalized = Index(
    'idx_fields_normalized',
    'CREATE INDEX idx_fields_normalized ON item_fields (field_key, normalized_value)',
  );
  late final Index idxAttachmentsItem = Index(
    'idx_attachments_item',
    'CREATE INDEX idx_attachments_item ON attachments (item_id)',
  );
  late final Index idxAttachmentsLinked = Index(
    'idx_attachments_linked',
    'CREATE INDEX idx_attachments_linked ON attachments (item_id, linked_field_key)',
  );
  late final Index idxRemindersSchedule = Index(
    'idx_reminders_schedule',
    'CREATE INDEX idx_reminders_schedule ON reminders (enabled, next_trigger_at)',
  );
  late final Index idxRemindersItem = Index(
    'idx_reminders_item',
    'CREATE INDEX idx_reminders_item ON reminders (item_id)',
  );
  late final Index idxChildEntriesItemSort = Index(
    'idx_child_entries_item_sort',
    'CREATE INDEX idx_child_entries_item_sort ON item_child_entries (item_id, child_type, sort_order)',
  );
  late final Index idxChildFieldsEntrySort = Index(
    'idx_child_fields_entry_sort',
    'CREATE INDEX idx_child_fields_entry_sort ON item_child_fields (child_entry_id, sort_order)',
  );
  late final Index idxItemEventsItemOccurred = Index(
    'idx_item_events_item_occurred',
    'CREATE INDEX idx_item_events_item_occurred ON item_events (item_id, occurred_at)',
  );
  late final Index idxItemEventChangesEventSort = Index(
    'idx_item_event_changes_event_sort',
    'CREATE INDEX idx_item_event_changes_event_sort ON item_event_changes (event_id, sort_order)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    members,
    items,
    itemFields,
    attachments,
    reminders,
    appSettings,
    licenseState,
    itemChildEntries,
    itemChildFields,
    itemEvents,
    itemEventChanges,
    idxMembersTypeSort,
    idxMembersArchived,
    idxItemsMemberStatus,
    idxItemsCategoryType,
    idxItemsActivePinnedAt,
    idxItemsStatusDeletedAt,
    idxFieldsItemSort,
    idxFieldsNormalized,
    idxAttachmentsItem,
    idxAttachmentsLinked,
    idxRemindersSchedule,
    idxRemindersItem,
    idxChildEntriesItemSort,
    idxChildFieldsEntrySort,
    idxItemEventsItemOccurred,
    idxItemEventChangesEventSort,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('item_fields', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('attachments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('reminders', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('item_child_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'item_child_entries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('item_child_fields', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('item_events', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'item_events',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('item_event_changes', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$MembersTableCreateCompanionBuilder =
    MembersCompanion Function({
      required String id,
      required String memberType,
      required String name,
      Value<String?> avatarKey,
      Value<String?> note,
      Value<int> sortOrder,
      Value<bool> isSystem,
      Value<bool> isArchived,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$MembersTableUpdateCompanionBuilder =
    MembersCompanion Function({
      Value<String> id,
      Value<String> memberType,
      Value<String> name,
      Value<String?> avatarKey,
      Value<String?> note,
      Value<int> sortOrder,
      Value<bool> isSystem,
      Value<bool> isArchived,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$MembersTableReferences
    extends BaseReferences<_$AppDatabase, $MembersTable, Member> {
  $$MembersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ItemsTable, List<Item>> _itemsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.items,
    aliasName: $_aliasNameGenerator(db.members.id, db.items.memberId),
  );

  $$ItemsTableProcessedTableManager get itemsRefs {
    final manager = $$ItemsTableTableManager(
      $_db,
      $_db.items,
    ).filter((f) => f.memberId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_itemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MembersTableFilterComposer
    extends Composer<_$AppDatabase, $MembersTable> {
  $$MembersTableFilterComposer({
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

  ColumnFilters<String> get memberType => $composableBuilder(
    column: $table.memberType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarKey => $composableBuilder(
    column: $table.avatarKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> itemsRefs(
    Expression<bool> Function($$ItemsTableFilterComposer f) f,
  ) {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.memberId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableFilterComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MembersTableOrderingComposer
    extends Composer<_$AppDatabase, $MembersTable> {
  $$MembersTableOrderingComposer({
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

  ColumnOrderings<String> get memberType => $composableBuilder(
    column: $table.memberType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarKey => $composableBuilder(
    column: $table.avatarKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $MembersTable> {
  $$MembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get memberType => $composableBuilder(
    column: $table.memberType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get avatarKey =>
      $composableBuilder(column: $table.avatarKey, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isSystem =>
      $composableBuilder(column: $table.isSystem, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> itemsRefs<T extends Object>(
    Expression<T> Function($$ItemsTableAnnotationComposer a) f,
  ) {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.memberId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MembersTable,
          Member,
          $$MembersTableFilterComposer,
          $$MembersTableOrderingComposer,
          $$MembersTableAnnotationComposer,
          $$MembersTableCreateCompanionBuilder,
          $$MembersTableUpdateCompanionBuilder,
          (Member, $$MembersTableReferences),
          Member,
          PrefetchHooks Function({bool itemsRefs})
        > {
  $$MembersTableTableManager(_$AppDatabase db, $MembersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> memberType = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> avatarKey = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isSystem = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MembersCompanion(
                id: id,
                memberType: memberType,
                name: name,
                avatarKey: avatarKey,
                note: note,
                sortOrder: sortOrder,
                isSystem: isSystem,
                isArchived: isArchived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String memberType,
                required String name,
                Value<String?> avatarKey = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isSystem = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MembersCompanion.insert(
                id: id,
                memberType: memberType,
                name: name,
                avatarKey: avatarKey,
                note: note,
                sortOrder: sortOrder,
                isSystem: isSystem,
                isArchived: isArchived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MembersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (itemsRefs) db.items],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (itemsRefs)
                    await $_getPrefetchedData<Member, $MembersTable, Item>(
                      currentTable: table,
                      referencedTable: $$MembersTableReferences._itemsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$MembersTableReferences(db, table, p0).itemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.memberId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MembersTable,
      Member,
      $$MembersTableFilterComposer,
      $$MembersTableOrderingComposer,
      $$MembersTableAnnotationComposer,
      $$MembersTableCreateCompanionBuilder,
      $$MembersTableUpdateCompanionBuilder,
      (Member, $$MembersTableReferences),
      Member,
      PrefetchHooks Function({bool itemsRefs})
    >;
typedef $$ItemsTableCreateCompanionBuilder =
    ItemsCompanion Function({
      required String id,
      required String originId,
      Value<String?> memberId,
      Value<String?> categoryKey,
      Value<String?> typeKey,
      Value<int> templateVersion,
      Value<String?> title,
      Value<String?> primaryText,
      Value<String?> secondaryText,
      Value<String?> summaryText,
      Value<String?> searchText,
      Value<String?> note,
      Value<bool> isFavorite,
      Value<bool> isPinned,
      Value<int?> pinnedAt,
      Value<int> sortOrder,
      Value<String> status,
      Value<int?> deletedAt,
      Value<String?> statusBeforeDeletion,
      required int createdAt,
      required int updatedAt,
      Value<int?> lastViewedAt,
      Value<String?> metadata,
      Value<int> rowid,
    });
typedef $$ItemsTableUpdateCompanionBuilder =
    ItemsCompanion Function({
      Value<String> id,
      Value<String> originId,
      Value<String?> memberId,
      Value<String?> categoryKey,
      Value<String?> typeKey,
      Value<int> templateVersion,
      Value<String?> title,
      Value<String?> primaryText,
      Value<String?> secondaryText,
      Value<String?> summaryText,
      Value<String?> searchText,
      Value<String?> note,
      Value<bool> isFavorite,
      Value<bool> isPinned,
      Value<int?> pinnedAt,
      Value<int> sortOrder,
      Value<String> status,
      Value<int?> deletedAt,
      Value<String?> statusBeforeDeletion,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> lastViewedAt,
      Value<String?> metadata,
      Value<int> rowid,
    });

final class $$ItemsTableReferences
    extends BaseReferences<_$AppDatabase, $ItemsTable, Item> {
  $$ItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MembersTable _memberIdTable(_$AppDatabase db) => db.members
      .createAlias($_aliasNameGenerator(db.items.memberId, db.members.id));

  $$MembersTableProcessedTableManager? get memberId {
    final $_column = $_itemColumn<String>('member_id');
    if ($_column == null) return null;
    final manager = $$MembersTableTableManager(
      $_db,
      $_db.members,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_memberIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ItemFieldsTable, List<ItemField>>
  _itemFieldsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.itemFields,
    aliasName: $_aliasNameGenerator(db.items.id, db.itemFields.itemId),
  );

  $$ItemFieldsTableProcessedTableManager get itemFieldsRefs {
    final manager = $$ItemFieldsTableTableManager(
      $_db,
      $_db.itemFields,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_itemFieldsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AttachmentsTable, List<Attachment>>
  _attachmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.attachments,
    aliasName: $_aliasNameGenerator(db.items.id, db.attachments.itemId),
  );

  $$AttachmentsTableProcessedTableManager get attachmentsRefs {
    final manager = $$AttachmentsTableTableManager(
      $_db,
      $_db.attachments,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_attachmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RemindersTable, List<Reminder>>
  _remindersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.reminders,
    aliasName: $_aliasNameGenerator(db.items.id, db.reminders.itemId),
  );

  $$RemindersTableProcessedTableManager get remindersRefs {
    final manager = $$RemindersTableTableManager(
      $_db,
      $_db.reminders,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_remindersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ItemChildEntriesTable, List<ItemChildEntry>>
  _itemChildEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.itemChildEntries,
    aliasName: $_aliasNameGenerator(db.items.id, db.itemChildEntries.itemId),
  );

  $$ItemChildEntriesTableProcessedTableManager get itemChildEntriesRefs {
    final manager = $$ItemChildEntriesTableTableManager(
      $_db,
      $_db.itemChildEntries,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _itemChildEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ItemEventsTable, List<ItemEvent>>
  _itemEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.itemEvents,
    aliasName: $_aliasNameGenerator(db.items.id, db.itemEvents.itemId),
  );

  $$ItemEventsTableProcessedTableManager get itemEventsRefs {
    final manager = $$ItemEventsTableTableManager(
      $_db,
      $_db.itemEvents,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_itemEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ItemsTableFilterComposer extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableFilterComposer({
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

  ColumnFilters<String> get originId => $composableBuilder(
    column: $table.originId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryKey => $composableBuilder(
    column: $table.categoryKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get typeKey => $composableBuilder(
    column: $table.typeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get templateVersion => $composableBuilder(
    column: $table.templateVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get primaryText => $composableBuilder(
    column: $table.primaryText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get secondaryText => $composableBuilder(
    column: $table.secondaryText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryText => $composableBuilder(
    column: $table.summaryText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pinnedAt => $composableBuilder(
    column: $table.pinnedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statusBeforeDeletion => $composableBuilder(
    column: $table.statusBeforeDeletion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastViewedAt => $composableBuilder(
    column: $table.lastViewedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );

  $$MembersTableFilterComposer get memberId {
    final $$MembersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memberId,
      referencedTable: $db.members,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MembersTableFilterComposer(
            $db: $db,
            $table: $db.members,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> itemFieldsRefs(
    Expression<bool> Function($$ItemFieldsTableFilterComposer f) f,
  ) {
    final $$ItemFieldsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itemFields,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemFieldsTableFilterComposer(
            $db: $db,
            $table: $db.itemFields,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> attachmentsRefs(
    Expression<bool> Function($$AttachmentsTableFilterComposer f) f,
  ) {
    final $$AttachmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableFilterComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> remindersRefs(
    Expression<bool> Function($$RemindersTableFilterComposer f) f,
  ) {
    final $$RemindersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableFilterComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> itemChildEntriesRefs(
    Expression<bool> Function($$ItemChildEntriesTableFilterComposer f) f,
  ) {
    final $$ItemChildEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itemChildEntries,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemChildEntriesTableFilterComposer(
            $db: $db,
            $table: $db.itemChildEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> itemEventsRefs(
    Expression<bool> Function($$ItemEventsTableFilterComposer f) f,
  ) {
    final $$ItemEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itemEvents,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemEventsTableFilterComposer(
            $db: $db,
            $table: $db.itemEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableOrderingComposer({
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

  ColumnOrderings<String> get originId => $composableBuilder(
    column: $table.originId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryKey => $composableBuilder(
    column: $table.categoryKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get typeKey => $composableBuilder(
    column: $table.typeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get templateVersion => $composableBuilder(
    column: $table.templateVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get primaryText => $composableBuilder(
    column: $table.primaryText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get secondaryText => $composableBuilder(
    column: $table.secondaryText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryText => $composableBuilder(
    column: $table.summaryText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pinnedAt => $composableBuilder(
    column: $table.pinnedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statusBeforeDeletion => $composableBuilder(
    column: $table.statusBeforeDeletion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastViewedAt => $composableBuilder(
    column: $table.lastViewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );

  $$MembersTableOrderingComposer get memberId {
    final $$MembersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memberId,
      referencedTable: $db.members,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MembersTableOrderingComposer(
            $db: $db,
            $table: $db.members,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get originId =>
      $composableBuilder(column: $table.originId, builder: (column) => column);

  GeneratedColumn<String> get categoryKey => $composableBuilder(
    column: $table.categoryKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get typeKey =>
      $composableBuilder(column: $table.typeKey, builder: (column) => column);

  GeneratedColumn<int> get templateVersion => $composableBuilder(
    column: $table.templateVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get primaryText => $composableBuilder(
    column: $table.primaryText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get secondaryText => $composableBuilder(
    column: $table.secondaryText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summaryText => $composableBuilder(
    column: $table.summaryText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<int> get pinnedAt =>
      $composableBuilder(column: $table.pinnedAt, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get statusBeforeDeletion => $composableBuilder(
    column: $table.statusBeforeDeletion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get lastViewedAt => $composableBuilder(
    column: $table.lastViewedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  $$MembersTableAnnotationComposer get memberId {
    final $$MembersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.memberId,
      referencedTable: $db.members,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MembersTableAnnotationComposer(
            $db: $db,
            $table: $db.members,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> itemFieldsRefs<T extends Object>(
    Expression<T> Function($$ItemFieldsTableAnnotationComposer a) f,
  ) {
    final $$ItemFieldsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itemFields,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemFieldsTableAnnotationComposer(
            $db: $db,
            $table: $db.itemFields,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> attachmentsRefs<T extends Object>(
    Expression<T> Function($$AttachmentsTableAnnotationComposer a) f,
  ) {
    final $$AttachmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> remindersRefs<T extends Object>(
    Expression<T> Function($$RemindersTableAnnotationComposer a) f,
  ) {
    final $$RemindersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableAnnotationComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> itemChildEntriesRefs<T extends Object>(
    Expression<T> Function($$ItemChildEntriesTableAnnotationComposer a) f,
  ) {
    final $$ItemChildEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itemChildEntries,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemChildEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.itemChildEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> itemEventsRefs<T extends Object>(
    Expression<T> Function($$ItemEventsTableAnnotationComposer a) f,
  ) {
    final $$ItemEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itemEvents,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.itemEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItemsTable,
          Item,
          $$ItemsTableFilterComposer,
          $$ItemsTableOrderingComposer,
          $$ItemsTableAnnotationComposer,
          $$ItemsTableCreateCompanionBuilder,
          $$ItemsTableUpdateCompanionBuilder,
          (Item, $$ItemsTableReferences),
          Item,
          PrefetchHooks Function({
            bool memberId,
            bool itemFieldsRefs,
            bool attachmentsRefs,
            bool remindersRefs,
            bool itemChildEntriesRefs,
            bool itemEventsRefs,
          })
        > {
  $$ItemsTableTableManager(_$AppDatabase db, $ItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> originId = const Value.absent(),
                Value<String?> memberId = const Value.absent(),
                Value<String?> categoryKey = const Value.absent(),
                Value<String?> typeKey = const Value.absent(),
                Value<int> templateVersion = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> primaryText = const Value.absent(),
                Value<String?> secondaryText = const Value.absent(),
                Value<String?> summaryText = const Value.absent(),
                Value<String?> searchText = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<int?> pinnedAt = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String?> statusBeforeDeletion = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> lastViewedAt = const Value.absent(),
                Value<String?> metadata = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemsCompanion(
                id: id,
                originId: originId,
                memberId: memberId,
                categoryKey: categoryKey,
                typeKey: typeKey,
                templateVersion: templateVersion,
                title: title,
                primaryText: primaryText,
                secondaryText: secondaryText,
                summaryText: summaryText,
                searchText: searchText,
                note: note,
                isFavorite: isFavorite,
                isPinned: isPinned,
                pinnedAt: pinnedAt,
                sortOrder: sortOrder,
                status: status,
                deletedAt: deletedAt,
                statusBeforeDeletion: statusBeforeDeletion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastViewedAt: lastViewedAt,
                metadata: metadata,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String originId,
                Value<String?> memberId = const Value.absent(),
                Value<String?> categoryKey = const Value.absent(),
                Value<String?> typeKey = const Value.absent(),
                Value<int> templateVersion = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> primaryText = const Value.absent(),
                Value<String?> secondaryText = const Value.absent(),
                Value<String?> summaryText = const Value.absent(),
                Value<String?> searchText = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<int?> pinnedAt = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String?> statusBeforeDeletion = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> lastViewedAt = const Value.absent(),
                Value<String?> metadata = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemsCompanion.insert(
                id: id,
                originId: originId,
                memberId: memberId,
                categoryKey: categoryKey,
                typeKey: typeKey,
                templateVersion: templateVersion,
                title: title,
                primaryText: primaryText,
                secondaryText: secondaryText,
                summaryText: summaryText,
                searchText: searchText,
                note: note,
                isFavorite: isFavorite,
                isPinned: isPinned,
                pinnedAt: pinnedAt,
                sortOrder: sortOrder,
                status: status,
                deletedAt: deletedAt,
                statusBeforeDeletion: statusBeforeDeletion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastViewedAt: lastViewedAt,
                metadata: metadata,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$ItemsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                memberId = false,
                itemFieldsRefs = false,
                attachmentsRefs = false,
                remindersRefs = false,
                itemChildEntriesRefs = false,
                itemEventsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (itemFieldsRefs) db.itemFields,
                    if (attachmentsRefs) db.attachments,
                    if (remindersRefs) db.reminders,
                    if (itemChildEntriesRefs) db.itemChildEntries,
                    if (itemEventsRefs) db.itemEvents,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (memberId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.memberId,
                                    referencedTable: $$ItemsTableReferences
                                        ._memberIdTable(db),
                                    referencedColumn: $$ItemsTableReferences
                                        ._memberIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (itemFieldsRefs)
                        await $_getPrefetchedData<Item, $ItemsTable, ItemField>(
                          currentTable: table,
                          referencedTable: $$ItemsTableReferences
                              ._itemFieldsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).itemFieldsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (attachmentsRefs)
                        await $_getPrefetchedData<
                          Item,
                          $ItemsTable,
                          Attachment
                        >(
                          currentTable: table,
                          referencedTable: $$ItemsTableReferences
                              ._attachmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).attachmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (remindersRefs)
                        await $_getPrefetchedData<Item, $ItemsTable, Reminder>(
                          currentTable: table,
                          referencedTable: $$ItemsTableReferences
                              ._remindersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).remindersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (itemChildEntriesRefs)
                        await $_getPrefetchedData<
                          Item,
                          $ItemsTable,
                          ItemChildEntry
                        >(
                          currentTable: table,
                          referencedTable: $$ItemsTableReferences
                              ._itemChildEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).itemChildEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (itemEventsRefs)
                        await $_getPrefetchedData<Item, $ItemsTable, ItemEvent>(
                          currentTable: table,
                          referencedTable: $$ItemsTableReferences
                              ._itemEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).itemEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItemsTable,
      Item,
      $$ItemsTableFilterComposer,
      $$ItemsTableOrderingComposer,
      $$ItemsTableAnnotationComposer,
      $$ItemsTableCreateCompanionBuilder,
      $$ItemsTableUpdateCompanionBuilder,
      (Item, $$ItemsTableReferences),
      Item,
      PrefetchHooks Function({
        bool memberId,
        bool itemFieldsRefs,
        bool attachmentsRefs,
        bool remindersRefs,
        bool itemChildEntriesRefs,
        bool itemEventsRefs,
      })
    >;
typedef $$ItemFieldsTableCreateCompanionBuilder =
    ItemFieldsCompanion Function({
      required String id,
      required String itemId,
      required String fieldKey,
      required String valueType,
      Value<String?> valueText,
      Value<String?> normalizedValue,
      Value<String?> fieldNote,
      Value<String?> rawFieldLabel,
      Value<int> sortOrder,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$ItemFieldsTableUpdateCompanionBuilder =
    ItemFieldsCompanion Function({
      Value<String> id,
      Value<String> itemId,
      Value<String> fieldKey,
      Value<String> valueType,
      Value<String?> valueText,
      Value<String?> normalizedValue,
      Value<String?> fieldNote,
      Value<String?> rawFieldLabel,
      Value<int> sortOrder,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$ItemFieldsTableReferences
    extends BaseReferences<_$AppDatabase, $ItemFieldsTable, ItemField> {
  $$ItemFieldsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ItemsTable _itemIdTable(_$AppDatabase db) => db.items.createAlias(
    $_aliasNameGenerator(db.itemFields.itemId, db.items.id),
  );

  $$ItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$ItemsTableTableManager(
      $_db,
      $_db.items,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ItemFieldsTableFilterComposer
    extends Composer<_$AppDatabase, $ItemFieldsTable> {
  $$ItemFieldsTableFilterComposer({
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

  ColumnFilters<String> get fieldKey => $composableBuilder(
    column: $table.fieldKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueType => $composableBuilder(
    column: $table.valueType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueText => $composableBuilder(
    column: $table.valueText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedValue => $composableBuilder(
    column: $table.normalizedValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldNote => $composableBuilder(
    column: $table.fieldNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawFieldLabel => $composableBuilder(
    column: $table.rawFieldLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ItemsTableFilterComposer get itemId {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableFilterComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemFieldsTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemFieldsTable> {
  $$ItemFieldsTableOrderingComposer({
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

  ColumnOrderings<String> get fieldKey => $composableBuilder(
    column: $table.fieldKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueType => $composableBuilder(
    column: $table.valueType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueText => $composableBuilder(
    column: $table.valueText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedValue => $composableBuilder(
    column: $table.normalizedValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldNote => $composableBuilder(
    column: $table.fieldNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawFieldLabel => $composableBuilder(
    column: $table.rawFieldLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ItemsTableOrderingComposer get itemId {
    final $$ItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableOrderingComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemFieldsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemFieldsTable> {
  $$ItemFieldsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fieldKey =>
      $composableBuilder(column: $table.fieldKey, builder: (column) => column);

  GeneratedColumn<String> get valueType =>
      $composableBuilder(column: $table.valueType, builder: (column) => column);

  GeneratedColumn<String> get valueText =>
      $composableBuilder(column: $table.valueText, builder: (column) => column);

  GeneratedColumn<String> get normalizedValue => $composableBuilder(
    column: $table.normalizedValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fieldNote =>
      $composableBuilder(column: $table.fieldNote, builder: (column) => column);

  GeneratedColumn<String> get rawFieldLabel => $composableBuilder(
    column: $table.rawFieldLabel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ItemsTableAnnotationComposer get itemId {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemFieldsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItemFieldsTable,
          ItemField,
          $$ItemFieldsTableFilterComposer,
          $$ItemFieldsTableOrderingComposer,
          $$ItemFieldsTableAnnotationComposer,
          $$ItemFieldsTableCreateCompanionBuilder,
          $$ItemFieldsTableUpdateCompanionBuilder,
          (ItemField, $$ItemFieldsTableReferences),
          ItemField,
          PrefetchHooks Function({bool itemId})
        > {
  $$ItemFieldsTableTableManager(_$AppDatabase db, $ItemFieldsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemFieldsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemFieldsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemFieldsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> fieldKey = const Value.absent(),
                Value<String> valueType = const Value.absent(),
                Value<String?> valueText = const Value.absent(),
                Value<String?> normalizedValue = const Value.absent(),
                Value<String?> fieldNote = const Value.absent(),
                Value<String?> rawFieldLabel = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemFieldsCompanion(
                id: id,
                itemId: itemId,
                fieldKey: fieldKey,
                valueType: valueType,
                valueText: valueText,
                normalizedValue: normalizedValue,
                fieldNote: fieldNote,
                rawFieldLabel: rawFieldLabel,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String itemId,
                required String fieldKey,
                required String valueType,
                Value<String?> valueText = const Value.absent(),
                Value<String?> normalizedValue = const Value.absent(),
                Value<String?> fieldNote = const Value.absent(),
                Value<String?> rawFieldLabel = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ItemFieldsCompanion.insert(
                id: id,
                itemId: itemId,
                fieldKey: fieldKey,
                valueType: valueType,
                valueText: valueText,
                normalizedValue: normalizedValue,
                fieldNote: fieldNote,
                rawFieldLabel: rawFieldLabel,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ItemFieldsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable: $$ItemFieldsTableReferences
                                    ._itemIdTable(db),
                                referencedColumn: $$ItemFieldsTableReferences
                                    ._itemIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ItemFieldsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItemFieldsTable,
      ItemField,
      $$ItemFieldsTableFilterComposer,
      $$ItemFieldsTableOrderingComposer,
      $$ItemFieldsTableAnnotationComposer,
      $$ItemFieldsTableCreateCompanionBuilder,
      $$ItemFieldsTableUpdateCompanionBuilder,
      (ItemField, $$ItemFieldsTableReferences),
      ItemField,
      PrefetchHooks Function({bool itemId})
    >;
typedef $$AttachmentsTableCreateCompanionBuilder =
    AttachmentsCompanion Function({
      required String id,
      required String originAttachmentId,
      required String itemId,
      Value<String?> linkedFieldKey,
      required String attachmentRole,
      required String fileName,
      Value<String?> originalName,
      required String mimeType,
      Value<int> plainSize,
      Value<int> encryptedSize,
      Value<String?> sha256,
      Value<int> sortOrder,
      Value<String> status,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$AttachmentsTableUpdateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<String> id,
      Value<String> originAttachmentId,
      Value<String> itemId,
      Value<String?> linkedFieldKey,
      Value<String> attachmentRole,
      Value<String> fileName,
      Value<String?> originalName,
      Value<String> mimeType,
      Value<int> plainSize,
      Value<int> encryptedSize,
      Value<String?> sha256,
      Value<int> sortOrder,
      Value<String> status,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$AttachmentsTableReferences
    extends BaseReferences<_$AppDatabase, $AttachmentsTable, Attachment> {
  $$AttachmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ItemsTable _itemIdTable(_$AppDatabase db) => db.items.createAlias(
    $_aliasNameGenerator(db.attachments.itemId, db.items.id),
  );

  $$ItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$ItemsTableTableManager(
      $_db,
      $_db.items,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableFilterComposer({
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

  ColumnFilters<String> get originAttachmentId => $composableBuilder(
    column: $table.originAttachmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedFieldKey => $composableBuilder(
    column: $table.linkedFieldKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentRole => $composableBuilder(
    column: $table.attachmentRole,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalName => $composableBuilder(
    column: $table.originalName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plainSize => $composableBuilder(
    column: $table.plainSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get encryptedSize => $composableBuilder(
    column: $table.encryptedSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ItemsTableFilterComposer get itemId {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableFilterComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableOrderingComposer({
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

  ColumnOrderings<String> get originAttachmentId => $composableBuilder(
    column: $table.originAttachmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedFieldKey => $composableBuilder(
    column: $table.linkedFieldKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentRole => $composableBuilder(
    column: $table.attachmentRole,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalName => $composableBuilder(
    column: $table.originalName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plainSize => $composableBuilder(
    column: $table.plainSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get encryptedSize => $composableBuilder(
    column: $table.encryptedSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ItemsTableOrderingComposer get itemId {
    final $$ItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableOrderingComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get originAttachmentId => $composableBuilder(
    column: $table.originAttachmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get linkedFieldKey => $composableBuilder(
    column: $table.linkedFieldKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attachmentRole => $composableBuilder(
    column: $table.attachmentRole,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get originalName => $composableBuilder(
    column: $table.originalName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get plainSize =>
      $composableBuilder(column: $table.plainSize, builder: (column) => column);

  GeneratedColumn<int> get encryptedSize => $composableBuilder(
    column: $table.encryptedSize,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ItemsTableAnnotationComposer get itemId {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttachmentsTable,
          Attachment,
          $$AttachmentsTableFilterComposer,
          $$AttachmentsTableOrderingComposer,
          $$AttachmentsTableAnnotationComposer,
          $$AttachmentsTableCreateCompanionBuilder,
          $$AttachmentsTableUpdateCompanionBuilder,
          (Attachment, $$AttachmentsTableReferences),
          Attachment,
          PrefetchHooks Function({bool itemId})
        > {
  $$AttachmentsTableTableManager(_$AppDatabase db, $AttachmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> originAttachmentId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String?> linkedFieldKey = const Value.absent(),
                Value<String> attachmentRole = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String?> originalName = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int> plainSize = const Value.absent(),
                Value<int> encryptedSize = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion(
                id: id,
                originAttachmentId: originAttachmentId,
                itemId: itemId,
                linkedFieldKey: linkedFieldKey,
                attachmentRole: attachmentRole,
                fileName: fileName,
                originalName: originalName,
                mimeType: mimeType,
                plainSize: plainSize,
                encryptedSize: encryptedSize,
                sha256: sha256,
                sortOrder: sortOrder,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String originAttachmentId,
                required String itemId,
                Value<String?> linkedFieldKey = const Value.absent(),
                required String attachmentRole,
                required String fileName,
                Value<String?> originalName = const Value.absent(),
                required String mimeType,
                Value<int> plainSize = const Value.absent(),
                Value<int> encryptedSize = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> status = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion.insert(
                id: id,
                originAttachmentId: originAttachmentId,
                itemId: itemId,
                linkedFieldKey: linkedFieldKey,
                attachmentRole: attachmentRole,
                fileName: fileName,
                originalName: originalName,
                mimeType: mimeType,
                plainSize: plainSize,
                encryptedSize: encryptedSize,
                sha256: sha256,
                sortOrder: sortOrder,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AttachmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable: $$AttachmentsTableReferences
                                    ._itemIdTable(db),
                                referencedColumn: $$AttachmentsTableReferences
                                    ._itemIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttachmentsTable,
      Attachment,
      $$AttachmentsTableFilterComposer,
      $$AttachmentsTableOrderingComposer,
      $$AttachmentsTableAnnotationComposer,
      $$AttachmentsTableCreateCompanionBuilder,
      $$AttachmentsTableUpdateCompanionBuilder,
      (Attachment, $$AttachmentsTableReferences),
      Attachment,
      PrefetchHooks Function({bool itemId})
    >;
typedef $$RemindersTableCreateCompanionBuilder =
    RemindersCompanion Function({
      required String id,
      required String itemId,
      Value<String?> fieldKey,
      required String reminderType,
      required String sourceValue,
      required String sourceValueType,
      required int remindAt,
      Value<int> advanceDays,
      Value<String?> repeatRule,
      Value<bool> enabled,
      Value<int?> lastTriggeredAt,
      Value<int?> nextTriggerAt,
      Value<int?> snoozedUntil,
      Value<int?> dismissedAt,
      Value<int?> notificationLocalId,
      Value<String?> note,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$RemindersTableUpdateCompanionBuilder =
    RemindersCompanion Function({
      Value<String> id,
      Value<String> itemId,
      Value<String?> fieldKey,
      Value<String> reminderType,
      Value<String> sourceValue,
      Value<String> sourceValueType,
      Value<int> remindAt,
      Value<int> advanceDays,
      Value<String?> repeatRule,
      Value<bool> enabled,
      Value<int?> lastTriggeredAt,
      Value<int?> nextTriggerAt,
      Value<int?> snoozedUntil,
      Value<int?> dismissedAt,
      Value<int?> notificationLocalId,
      Value<String?> note,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$RemindersTableReferences
    extends BaseReferences<_$AppDatabase, $RemindersTable, Reminder> {
  $$RemindersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ItemsTable _itemIdTable(_$AppDatabase db) => db.items.createAlias(
    $_aliasNameGenerator(db.reminders.itemId, db.items.id),
  );

  $$ItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$ItemsTableTableManager(
      $_db,
      $_db.items,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RemindersTableFilterComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableFilterComposer({
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

  ColumnFilters<String> get fieldKey => $composableBuilder(
    column: $table.fieldKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminderType => $composableBuilder(
    column: $table.reminderType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceValue => $composableBuilder(
    column: $table.sourceValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceValueType => $composableBuilder(
    column: $table.sourceValueType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remindAt => $composableBuilder(
    column: $table.remindAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get advanceDays => $composableBuilder(
    column: $table.advanceDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatRule => $composableBuilder(
    column: $table.repeatRule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastTriggeredAt => $composableBuilder(
    column: $table.lastTriggeredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextTriggerAt => $composableBuilder(
    column: $table.nextTriggerAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dismissedAt => $composableBuilder(
    column: $table.dismissedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notificationLocalId => $composableBuilder(
    column: $table.notificationLocalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ItemsTableFilterComposer get itemId {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableFilterComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableOrderingComposer({
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

  ColumnOrderings<String> get fieldKey => $composableBuilder(
    column: $table.fieldKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderType => $composableBuilder(
    column: $table.reminderType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceValue => $composableBuilder(
    column: $table.sourceValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceValueType => $composableBuilder(
    column: $table.sourceValueType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remindAt => $composableBuilder(
    column: $table.remindAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get advanceDays => $composableBuilder(
    column: $table.advanceDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatRule => $composableBuilder(
    column: $table.repeatRule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastTriggeredAt => $composableBuilder(
    column: $table.lastTriggeredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextTriggerAt => $composableBuilder(
    column: $table.nextTriggerAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dismissedAt => $composableBuilder(
    column: $table.dismissedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notificationLocalId => $composableBuilder(
    column: $table.notificationLocalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ItemsTableOrderingComposer get itemId {
    final $$ItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableOrderingComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fieldKey =>
      $composableBuilder(column: $table.fieldKey, builder: (column) => column);

  GeneratedColumn<String> get reminderType => $composableBuilder(
    column: $table.reminderType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceValue => $composableBuilder(
    column: $table.sourceValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceValueType => $composableBuilder(
    column: $table.sourceValueType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remindAt =>
      $composableBuilder(column: $table.remindAt, builder: (column) => column);

  GeneratedColumn<int> get advanceDays => $composableBuilder(
    column: $table.advanceDays,
    builder: (column) => column,
  );

  GeneratedColumn<String> get repeatRule => $composableBuilder(
    column: $table.repeatRule,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get lastTriggeredAt => $composableBuilder(
    column: $table.lastTriggeredAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextTriggerAt => $composableBuilder(
    column: $table.nextTriggerAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dismissedAt => $composableBuilder(
    column: $table.dismissedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get notificationLocalId => $composableBuilder(
    column: $table.notificationLocalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ItemsTableAnnotationComposer get itemId {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RemindersTable,
          Reminder,
          $$RemindersTableFilterComposer,
          $$RemindersTableOrderingComposer,
          $$RemindersTableAnnotationComposer,
          $$RemindersTableCreateCompanionBuilder,
          $$RemindersTableUpdateCompanionBuilder,
          (Reminder, $$RemindersTableReferences),
          Reminder,
          PrefetchHooks Function({bool itemId})
        > {
  $$RemindersTableTableManager(_$AppDatabase db, $RemindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String?> fieldKey = const Value.absent(),
                Value<String> reminderType = const Value.absent(),
                Value<String> sourceValue = const Value.absent(),
                Value<String> sourceValueType = const Value.absent(),
                Value<int> remindAt = const Value.absent(),
                Value<int> advanceDays = const Value.absent(),
                Value<String?> repeatRule = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int?> lastTriggeredAt = const Value.absent(),
                Value<int?> nextTriggerAt = const Value.absent(),
                Value<int?> snoozedUntil = const Value.absent(),
                Value<int?> dismissedAt = const Value.absent(),
                Value<int?> notificationLocalId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion(
                id: id,
                itemId: itemId,
                fieldKey: fieldKey,
                reminderType: reminderType,
                sourceValue: sourceValue,
                sourceValueType: sourceValueType,
                remindAt: remindAt,
                advanceDays: advanceDays,
                repeatRule: repeatRule,
                enabled: enabled,
                lastTriggeredAt: lastTriggeredAt,
                nextTriggerAt: nextTriggerAt,
                snoozedUntil: snoozedUntil,
                dismissedAt: dismissedAt,
                notificationLocalId: notificationLocalId,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String itemId,
                Value<String?> fieldKey = const Value.absent(),
                required String reminderType,
                required String sourceValue,
                required String sourceValueType,
                required int remindAt,
                Value<int> advanceDays = const Value.absent(),
                Value<String?> repeatRule = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int?> lastTriggeredAt = const Value.absent(),
                Value<int?> nextTriggerAt = const Value.absent(),
                Value<int?> snoozedUntil = const Value.absent(),
                Value<int?> dismissedAt = const Value.absent(),
                Value<int?> notificationLocalId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion.insert(
                id: id,
                itemId: itemId,
                fieldKey: fieldKey,
                reminderType: reminderType,
                sourceValue: sourceValue,
                sourceValueType: sourceValueType,
                remindAt: remindAt,
                advanceDays: advanceDays,
                repeatRule: repeatRule,
                enabled: enabled,
                lastTriggeredAt: lastTriggeredAt,
                nextTriggerAt: nextTriggerAt,
                snoozedUntil: snoozedUntil,
                dismissedAt: dismissedAt,
                notificationLocalId: notificationLocalId,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RemindersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable: $$RemindersTableReferences
                                    ._itemIdTable(db),
                                referencedColumn: $$RemindersTableReferences
                                    ._itemIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RemindersTable,
      Reminder,
      $$RemindersTableFilterComposer,
      $$RemindersTableOrderingComposer,
      $$RemindersTableAnnotationComposer,
      $$RemindersTableCreateCompanionBuilder,
      $$RemindersTableUpdateCompanionBuilder,
      (Reminder, $$RemindersTableReferences),
      Reminder,
      PrefetchHooks Function({bool itemId})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      Value<String?> value,
      required String valueType,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String?> value,
      Value<String> valueType,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueType => $composableBuilder(
    column: $table.valueType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueType => $composableBuilder(
    column: $table.valueType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get valueType =>
      $composableBuilder(column: $table.valueType, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String> valueType = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(
                key: key,
                value: value,
                valueType: valueType,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> value = const Value.absent(),
                required String valueType,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                valueType: valueType,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$LicenseStateTableCreateCompanionBuilder =
    LicenseStateCompanion Function({
      required String id,
      Value<String> licenseType,
      Value<int?> activatedAt,
      Value<int?> expiresAt,
      Value<String?> licensePayloadHash,
      Value<int?> lastVerifiedAt,
      Value<String> status,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$LicenseStateTableUpdateCompanionBuilder =
    LicenseStateCompanion Function({
      Value<String> id,
      Value<String> licenseType,
      Value<int?> activatedAt,
      Value<int?> expiresAt,
      Value<String?> licensePayloadHash,
      Value<int?> lastVerifiedAt,
      Value<String> status,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$LicenseStateTableFilterComposer
    extends Composer<_$AppDatabase, $LicenseStateTable> {
  $$LicenseStateTableFilterComposer({
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

  ColumnFilters<String> get licenseType => $composableBuilder(
    column: $table.licenseType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activatedAt => $composableBuilder(
    column: $table.activatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get licensePayloadHash => $composableBuilder(
    column: $table.licensePayloadHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastVerifiedAt => $composableBuilder(
    column: $table.lastVerifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LicenseStateTableOrderingComposer
    extends Composer<_$AppDatabase, $LicenseStateTable> {
  $$LicenseStateTableOrderingComposer({
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

  ColumnOrderings<String> get licenseType => $composableBuilder(
    column: $table.licenseType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activatedAt => $composableBuilder(
    column: $table.activatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get licensePayloadHash => $composableBuilder(
    column: $table.licensePayloadHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastVerifiedAt => $composableBuilder(
    column: $table.lastVerifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LicenseStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $LicenseStateTable> {
  $$LicenseStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get licenseType => $composableBuilder(
    column: $table.licenseType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get activatedAt => $composableBuilder(
    column: $table.activatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<String> get licensePayloadHash => $composableBuilder(
    column: $table.licensePayloadHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastVerifiedAt => $composableBuilder(
    column: $table.lastVerifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LicenseStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LicenseStateTable,
          LicenseStateData,
          $$LicenseStateTableFilterComposer,
          $$LicenseStateTableOrderingComposer,
          $$LicenseStateTableAnnotationComposer,
          $$LicenseStateTableCreateCompanionBuilder,
          $$LicenseStateTableUpdateCompanionBuilder,
          (
            LicenseStateData,
            BaseReferences<_$AppDatabase, $LicenseStateTable, LicenseStateData>,
          ),
          LicenseStateData,
          PrefetchHooks Function()
        > {
  $$LicenseStateTableTableManager(_$AppDatabase db, $LicenseStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LicenseStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LicenseStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LicenseStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> licenseType = const Value.absent(),
                Value<int?> activatedAt = const Value.absent(),
                Value<int?> expiresAt = const Value.absent(),
                Value<String?> licensePayloadHash = const Value.absent(),
                Value<int?> lastVerifiedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LicenseStateCompanion(
                id: id,
                licenseType: licenseType,
                activatedAt: activatedAt,
                expiresAt: expiresAt,
                licensePayloadHash: licensePayloadHash,
                lastVerifiedAt: lastVerifiedAt,
                status: status,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> licenseType = const Value.absent(),
                Value<int?> activatedAt = const Value.absent(),
                Value<int?> expiresAt = const Value.absent(),
                Value<String?> licensePayloadHash = const Value.absent(),
                Value<int?> lastVerifiedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LicenseStateCompanion.insert(
                id: id,
                licenseType: licenseType,
                activatedAt: activatedAt,
                expiresAt: expiresAt,
                licensePayloadHash: licensePayloadHash,
                lastVerifiedAt: lastVerifiedAt,
                status: status,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LicenseStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LicenseStateTable,
      LicenseStateData,
      $$LicenseStateTableFilterComposer,
      $$LicenseStateTableOrderingComposer,
      $$LicenseStateTableAnnotationComposer,
      $$LicenseStateTableCreateCompanionBuilder,
      $$LicenseStateTableUpdateCompanionBuilder,
      (
        LicenseStateData,
        BaseReferences<_$AppDatabase, $LicenseStateTable, LicenseStateData>,
      ),
      LicenseStateData,
      PrefetchHooks Function()
    >;
typedef $$ItemChildEntriesTableCreateCompanionBuilder =
    ItemChildEntriesCompanion Function({
      required String id,
      required String itemId,
      required String childType,
      Value<int> sortOrder,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$ItemChildEntriesTableUpdateCompanionBuilder =
    ItemChildEntriesCompanion Function({
      Value<String> id,
      Value<String> itemId,
      Value<String> childType,
      Value<int> sortOrder,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$ItemChildEntriesTableReferences
    extends
        BaseReferences<_$AppDatabase, $ItemChildEntriesTable, ItemChildEntry> {
  $$ItemChildEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ItemsTable _itemIdTable(_$AppDatabase db) => db.items.createAlias(
    $_aliasNameGenerator(db.itemChildEntries.itemId, db.items.id),
  );

  $$ItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$ItemsTableTableManager(
      $_db,
      $_db.items,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ItemChildFieldsTable, List<ItemChildField>>
  _itemChildFieldsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.itemChildFields,
    aliasName: $_aliasNameGenerator(
      db.itemChildEntries.id,
      db.itemChildFields.childEntryId,
    ),
  );

  $$ItemChildFieldsTableProcessedTableManager get itemChildFieldsRefs {
    final manager = $$ItemChildFieldsTableTableManager(
      $_db,
      $_db.itemChildFields,
    ).filter((f) => f.childEntryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _itemChildFieldsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ItemChildEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ItemChildEntriesTable> {
  $$ItemChildEntriesTableFilterComposer({
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

  ColumnFilters<String> get childType => $composableBuilder(
    column: $table.childType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ItemsTableFilterComposer get itemId {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableFilterComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> itemChildFieldsRefs(
    Expression<bool> Function($$ItemChildFieldsTableFilterComposer f) f,
  ) {
    final $$ItemChildFieldsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itemChildFields,
      getReferencedColumn: (t) => t.childEntryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemChildFieldsTableFilterComposer(
            $db: $db,
            $table: $db.itemChildFields,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ItemChildEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemChildEntriesTable> {
  $$ItemChildEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get childType => $composableBuilder(
    column: $table.childType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ItemsTableOrderingComposer get itemId {
    final $$ItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableOrderingComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemChildEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemChildEntriesTable> {
  $$ItemChildEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get childType =>
      $composableBuilder(column: $table.childType, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ItemsTableAnnotationComposer get itemId {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> itemChildFieldsRefs<T extends Object>(
    Expression<T> Function($$ItemChildFieldsTableAnnotationComposer a) f,
  ) {
    final $$ItemChildFieldsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itemChildFields,
      getReferencedColumn: (t) => t.childEntryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemChildFieldsTableAnnotationComposer(
            $db: $db,
            $table: $db.itemChildFields,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ItemChildEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItemChildEntriesTable,
          ItemChildEntry,
          $$ItemChildEntriesTableFilterComposer,
          $$ItemChildEntriesTableOrderingComposer,
          $$ItemChildEntriesTableAnnotationComposer,
          $$ItemChildEntriesTableCreateCompanionBuilder,
          $$ItemChildEntriesTableUpdateCompanionBuilder,
          (ItemChildEntry, $$ItemChildEntriesTableReferences),
          ItemChildEntry,
          PrefetchHooks Function({bool itemId, bool itemChildFieldsRefs})
        > {
  $$ItemChildEntriesTableTableManager(
    _$AppDatabase db,
    $ItemChildEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemChildEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemChildEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemChildEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> childType = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemChildEntriesCompanion(
                id: id,
                itemId: itemId,
                childType: childType,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String itemId,
                required String childType,
                Value<int> sortOrder = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ItemChildEntriesCompanion.insert(
                id: id,
                itemId: itemId,
                childType: childType,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ItemChildEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({itemId = false, itemChildFieldsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (itemChildFieldsRefs) db.itemChildFields,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (itemId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.itemId,
                                    referencedTable:
                                        $$ItemChildEntriesTableReferences
                                            ._itemIdTable(db),
                                    referencedColumn:
                                        $$ItemChildEntriesTableReferences
                                            ._itemIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (itemChildFieldsRefs)
                        await $_getPrefetchedData<
                          ItemChildEntry,
                          $ItemChildEntriesTable,
                          ItemChildField
                        >(
                          currentTable: table,
                          referencedTable: $$ItemChildEntriesTableReferences
                              ._itemChildFieldsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ItemChildEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).itemChildFieldsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.childEntryId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ItemChildEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItemChildEntriesTable,
      ItemChildEntry,
      $$ItemChildEntriesTableFilterComposer,
      $$ItemChildEntriesTableOrderingComposer,
      $$ItemChildEntriesTableAnnotationComposer,
      $$ItemChildEntriesTableCreateCompanionBuilder,
      $$ItemChildEntriesTableUpdateCompanionBuilder,
      (ItemChildEntry, $$ItemChildEntriesTableReferences),
      ItemChildEntry,
      PrefetchHooks Function({bool itemId, bool itemChildFieldsRefs})
    >;
typedef $$ItemChildFieldsTableCreateCompanionBuilder =
    ItemChildFieldsCompanion Function({
      required String id,
      required String childEntryId,
      required String fieldKey,
      required String label,
      Value<String?> valueText,
      required String valueType,
      required String sensitiveLevel,
      Value<bool> copyable,
      Value<bool> searchable,
      Value<bool> summary,
      Value<int> sortOrder,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$ItemChildFieldsTableUpdateCompanionBuilder =
    ItemChildFieldsCompanion Function({
      Value<String> id,
      Value<String> childEntryId,
      Value<String> fieldKey,
      Value<String> label,
      Value<String?> valueText,
      Value<String> valueType,
      Value<String> sensitiveLevel,
      Value<bool> copyable,
      Value<bool> searchable,
      Value<bool> summary,
      Value<int> sortOrder,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$ItemChildFieldsTableReferences
    extends
        BaseReferences<_$AppDatabase, $ItemChildFieldsTable, ItemChildField> {
  $$ItemChildFieldsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ItemChildEntriesTable _childEntryIdTable(_$AppDatabase db) =>
      db.itemChildEntries.createAlias(
        $_aliasNameGenerator(
          db.itemChildFields.childEntryId,
          db.itemChildEntries.id,
        ),
      );

  $$ItemChildEntriesTableProcessedTableManager get childEntryId {
    final $_column = $_itemColumn<String>('child_entry_id')!;

    final manager = $$ItemChildEntriesTableTableManager(
      $_db,
      $_db.itemChildEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_childEntryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ItemChildFieldsTableFilterComposer
    extends Composer<_$AppDatabase, $ItemChildFieldsTable> {
  $$ItemChildFieldsTableFilterComposer({
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

  ColumnFilters<String> get fieldKey => $composableBuilder(
    column: $table.fieldKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueText => $composableBuilder(
    column: $table.valueText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueType => $composableBuilder(
    column: $table.valueType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sensitiveLevel => $composableBuilder(
    column: $table.sensitiveLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get copyable => $composableBuilder(
    column: $table.copyable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get searchable => $composableBuilder(
    column: $table.searchable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ItemChildEntriesTableFilterComposer get childEntryId {
    final $$ItemChildEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childEntryId,
      referencedTable: $db.itemChildEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemChildEntriesTableFilterComposer(
            $db: $db,
            $table: $db.itemChildEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemChildFieldsTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemChildFieldsTable> {
  $$ItemChildFieldsTableOrderingComposer({
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

  ColumnOrderings<String> get fieldKey => $composableBuilder(
    column: $table.fieldKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueText => $composableBuilder(
    column: $table.valueText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueType => $composableBuilder(
    column: $table.valueType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sensitiveLevel => $composableBuilder(
    column: $table.sensitiveLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get copyable => $composableBuilder(
    column: $table.copyable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get searchable => $composableBuilder(
    column: $table.searchable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ItemChildEntriesTableOrderingComposer get childEntryId {
    final $$ItemChildEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childEntryId,
      referencedTable: $db.itemChildEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemChildEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.itemChildEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemChildFieldsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemChildFieldsTable> {
  $$ItemChildFieldsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fieldKey =>
      $composableBuilder(column: $table.fieldKey, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get valueText =>
      $composableBuilder(column: $table.valueText, builder: (column) => column);

  GeneratedColumn<String> get valueType =>
      $composableBuilder(column: $table.valueType, builder: (column) => column);

  GeneratedColumn<String> get sensitiveLevel => $composableBuilder(
    column: $table.sensitiveLevel,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get copyable =>
      $composableBuilder(column: $table.copyable, builder: (column) => column);

  GeneratedColumn<bool> get searchable => $composableBuilder(
    column: $table.searchable,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ItemChildEntriesTableAnnotationComposer get childEntryId {
    final $$ItemChildEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childEntryId,
      referencedTable: $db.itemChildEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemChildEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.itemChildEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemChildFieldsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItemChildFieldsTable,
          ItemChildField,
          $$ItemChildFieldsTableFilterComposer,
          $$ItemChildFieldsTableOrderingComposer,
          $$ItemChildFieldsTableAnnotationComposer,
          $$ItemChildFieldsTableCreateCompanionBuilder,
          $$ItemChildFieldsTableUpdateCompanionBuilder,
          (ItemChildField, $$ItemChildFieldsTableReferences),
          ItemChildField,
          PrefetchHooks Function({bool childEntryId})
        > {
  $$ItemChildFieldsTableTableManager(
    _$AppDatabase db,
    $ItemChildFieldsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemChildFieldsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemChildFieldsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemChildFieldsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> childEntryId = const Value.absent(),
                Value<String> fieldKey = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String?> valueText = const Value.absent(),
                Value<String> valueType = const Value.absent(),
                Value<String> sensitiveLevel = const Value.absent(),
                Value<bool> copyable = const Value.absent(),
                Value<bool> searchable = const Value.absent(),
                Value<bool> summary = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemChildFieldsCompanion(
                id: id,
                childEntryId: childEntryId,
                fieldKey: fieldKey,
                label: label,
                valueText: valueText,
                valueType: valueType,
                sensitiveLevel: sensitiveLevel,
                copyable: copyable,
                searchable: searchable,
                summary: summary,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String childEntryId,
                required String fieldKey,
                required String label,
                Value<String?> valueText = const Value.absent(),
                required String valueType,
                required String sensitiveLevel,
                Value<bool> copyable = const Value.absent(),
                Value<bool> searchable = const Value.absent(),
                Value<bool> summary = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ItemChildFieldsCompanion.insert(
                id: id,
                childEntryId: childEntryId,
                fieldKey: fieldKey,
                label: label,
                valueText: valueText,
                valueType: valueType,
                sensitiveLevel: sensitiveLevel,
                copyable: copyable,
                searchable: searchable,
                summary: summary,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ItemChildFieldsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({childEntryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (childEntryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.childEntryId,
                                referencedTable:
                                    $$ItemChildFieldsTableReferences
                                        ._childEntryIdTable(db),
                                referencedColumn:
                                    $$ItemChildFieldsTableReferences
                                        ._childEntryIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ItemChildFieldsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItemChildFieldsTable,
      ItemChildField,
      $$ItemChildFieldsTableFilterComposer,
      $$ItemChildFieldsTableOrderingComposer,
      $$ItemChildFieldsTableAnnotationComposer,
      $$ItemChildFieldsTableCreateCompanionBuilder,
      $$ItemChildFieldsTableUpdateCompanionBuilder,
      (ItemChildField, $$ItemChildFieldsTableReferences),
      ItemChildField,
      PrefetchHooks Function({bool childEntryId})
    >;
typedef $$ItemEventsTableCreateCompanionBuilder =
    ItemEventsCompanion Function({
      required String id,
      required String itemId,
      required String eventType,
      required int occurredAt,
      Value<int> rowid,
    });
typedef $$ItemEventsTableUpdateCompanionBuilder =
    ItemEventsCompanion Function({
      Value<String> id,
      Value<String> itemId,
      Value<String> eventType,
      Value<int> occurredAt,
      Value<int> rowid,
    });

final class $$ItemEventsTableReferences
    extends BaseReferences<_$AppDatabase, $ItemEventsTable, ItemEvent> {
  $$ItemEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ItemsTable _itemIdTable(_$AppDatabase db) => db.items.createAlias(
    $_aliasNameGenerator(db.itemEvents.itemId, db.items.id),
  );

  $$ItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$ItemsTableTableManager(
      $_db,
      $_db.items,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ItemEventChangesTable, List<ItemEventChange>>
  _itemEventChangesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.itemEventChanges,
    aliasName: $_aliasNameGenerator(
      db.itemEvents.id,
      db.itemEventChanges.eventId,
    ),
  );

  $$ItemEventChangesTableProcessedTableManager get itemEventChangesRefs {
    final manager = $$ItemEventChangesTableTableManager(
      $_db,
      $_db.itemEventChanges,
    ).filter((f) => f.eventId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _itemEventChangesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ItemEventsTableFilterComposer
    extends Composer<_$AppDatabase, $ItemEventsTable> {
  $$ItemEventsTableFilterComposer({
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

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ItemsTableFilterComposer get itemId {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableFilterComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> itemEventChangesRefs(
    Expression<bool> Function($$ItemEventChangesTableFilterComposer f) f,
  ) {
    final $$ItemEventChangesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itemEventChanges,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemEventChangesTableFilterComposer(
            $db: $db,
            $table: $db.itemEventChanges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ItemEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemEventsTable> {
  $$ItemEventsTableOrderingComposer({
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

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ItemsTableOrderingComposer get itemId {
    final $$ItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableOrderingComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemEventsTable> {
  $$ItemEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  $$ItemsTableAnnotationComposer get itemId {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> itemEventChangesRefs<T extends Object>(
    Expression<T> Function($$ItemEventChangesTableAnnotationComposer a) f,
  ) {
    final $$ItemEventChangesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itemEventChanges,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemEventChangesTableAnnotationComposer(
            $db: $db,
            $table: $db.itemEventChanges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ItemEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItemEventsTable,
          ItemEvent,
          $$ItemEventsTableFilterComposer,
          $$ItemEventsTableOrderingComposer,
          $$ItemEventsTableAnnotationComposer,
          $$ItemEventsTableCreateCompanionBuilder,
          $$ItemEventsTableUpdateCompanionBuilder,
          (ItemEvent, $$ItemEventsTableReferences),
          ItemEvent,
          PrefetchHooks Function({bool itemId, bool itemEventChangesRefs})
        > {
  $$ItemEventsTableTableManager(_$AppDatabase db, $ItemEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<int> occurredAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemEventsCompanion(
                id: id,
                itemId: itemId,
                eventType: eventType,
                occurredAt: occurredAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String itemId,
                required String eventType,
                required int occurredAt,
                Value<int> rowid = const Value.absent(),
              }) => ItemEventsCompanion.insert(
                id: id,
                itemId: itemId,
                eventType: eventType,
                occurredAt: occurredAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ItemEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({itemId = false, itemEventChangesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (itemEventChangesRefs) db.itemEventChanges,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (itemId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.itemId,
                                    referencedTable: $$ItemEventsTableReferences
                                        ._itemIdTable(db),
                                    referencedColumn:
                                        $$ItemEventsTableReferences
                                            ._itemIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (itemEventChangesRefs)
                        await $_getPrefetchedData<
                          ItemEvent,
                          $ItemEventsTable,
                          ItemEventChange
                        >(
                          currentTable: table,
                          referencedTable: $$ItemEventsTableReferences
                              ._itemEventChangesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ItemEventsTableReferences(
                                db,
                                table,
                                p0,
                              ).itemEventChangesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.eventId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ItemEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItemEventsTable,
      ItemEvent,
      $$ItemEventsTableFilterComposer,
      $$ItemEventsTableOrderingComposer,
      $$ItemEventsTableAnnotationComposer,
      $$ItemEventsTableCreateCompanionBuilder,
      $$ItemEventsTableUpdateCompanionBuilder,
      (ItemEvent, $$ItemEventsTableReferences),
      ItemEvent,
      PrefetchHooks Function({bool itemId, bool itemEventChangesRefs})
    >;
typedef $$ItemEventChangesTableCreateCompanionBuilder =
    ItemEventChangesCompanion Function({
      required String id,
      required String eventId,
      required String changeKind,
      required String subjectKey,
      required String subjectLabel,
      Value<String?> oldValue,
      Value<String?> newValue,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$ItemEventChangesTableUpdateCompanionBuilder =
    ItemEventChangesCompanion Function({
      Value<String> id,
      Value<String> eventId,
      Value<String> changeKind,
      Value<String> subjectKey,
      Value<String> subjectLabel,
      Value<String?> oldValue,
      Value<String?> newValue,
      Value<int> sortOrder,
      Value<int> rowid,
    });

final class $$ItemEventChangesTableReferences
    extends
        BaseReferences<_$AppDatabase, $ItemEventChangesTable, ItemEventChange> {
  $$ItemEventChangesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ItemEventsTable _eventIdTable(_$AppDatabase db) =>
      db.itemEvents.createAlias(
        $_aliasNameGenerator(db.itemEventChanges.eventId, db.itemEvents.id),
      );

  $$ItemEventsTableProcessedTableManager get eventId {
    final $_column = $_itemColumn<String>('event_id')!;

    final manager = $$ItemEventsTableTableManager(
      $_db,
      $_db.itemEvents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_eventIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ItemEventChangesTableFilterComposer
    extends Composer<_$AppDatabase, $ItemEventChangesTable> {
  $$ItemEventChangesTableFilterComposer({
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

  ColumnFilters<String> get changeKind => $composableBuilder(
    column: $table.changeKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectKey => $composableBuilder(
    column: $table.subjectKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectLabel => $composableBuilder(
    column: $table.subjectLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oldValue => $composableBuilder(
    column: $table.oldValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get newValue => $composableBuilder(
    column: $table.newValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$ItemEventsTableFilterComposer get eventId {
    final $$ItemEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.itemEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemEventsTableFilterComposer(
            $db: $db,
            $table: $db.itemEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemEventChangesTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemEventChangesTable> {
  $$ItemEventChangesTableOrderingComposer({
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

  ColumnOrderings<String> get changeKind => $composableBuilder(
    column: $table.changeKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectKey => $composableBuilder(
    column: $table.subjectKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectLabel => $composableBuilder(
    column: $table.subjectLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oldValue => $composableBuilder(
    column: $table.oldValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get newValue => $composableBuilder(
    column: $table.newValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$ItemEventsTableOrderingComposer get eventId {
    final $$ItemEventsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.itemEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemEventsTableOrderingComposer(
            $db: $db,
            $table: $db.itemEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemEventChangesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemEventChangesTable> {
  $$ItemEventChangesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get changeKind => $composableBuilder(
    column: $table.changeKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subjectKey => $composableBuilder(
    column: $table.subjectKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subjectLabel => $composableBuilder(
    column: $table.subjectLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get oldValue =>
      $composableBuilder(column: $table.oldValue, builder: (column) => column);

  GeneratedColumn<String> get newValue =>
      $composableBuilder(column: $table.newValue, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$ItemEventsTableAnnotationComposer get eventId {
    final $$ItemEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.itemEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.itemEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemEventChangesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItemEventChangesTable,
          ItemEventChange,
          $$ItemEventChangesTableFilterComposer,
          $$ItemEventChangesTableOrderingComposer,
          $$ItemEventChangesTableAnnotationComposer,
          $$ItemEventChangesTableCreateCompanionBuilder,
          $$ItemEventChangesTableUpdateCompanionBuilder,
          (ItemEventChange, $$ItemEventChangesTableReferences),
          ItemEventChange,
          PrefetchHooks Function({bool eventId})
        > {
  $$ItemEventChangesTableTableManager(
    _$AppDatabase db,
    $ItemEventChangesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemEventChangesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemEventChangesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemEventChangesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<String> changeKind = const Value.absent(),
                Value<String> subjectKey = const Value.absent(),
                Value<String> subjectLabel = const Value.absent(),
                Value<String?> oldValue = const Value.absent(),
                Value<String?> newValue = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemEventChangesCompanion(
                id: id,
                eventId: eventId,
                changeKind: changeKind,
                subjectKey: subjectKey,
                subjectLabel: subjectLabel,
                oldValue: oldValue,
                newValue: newValue,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String eventId,
                required String changeKind,
                required String subjectKey,
                required String subjectLabel,
                Value<String?> oldValue = const Value.absent(),
                Value<String?> newValue = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemEventChangesCompanion.insert(
                id: id,
                eventId: eventId,
                changeKind: changeKind,
                subjectKey: subjectKey,
                subjectLabel: subjectLabel,
                oldValue: oldValue,
                newValue: newValue,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ItemEventChangesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({eventId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (eventId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.eventId,
                                referencedTable:
                                    $$ItemEventChangesTableReferences
                                        ._eventIdTable(db),
                                referencedColumn:
                                    $$ItemEventChangesTableReferences
                                        ._eventIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ItemEventChangesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItemEventChangesTable,
      ItemEventChange,
      $$ItemEventChangesTableFilterComposer,
      $$ItemEventChangesTableOrderingComposer,
      $$ItemEventChangesTableAnnotationComposer,
      $$ItemEventChangesTableCreateCompanionBuilder,
      $$ItemEventChangesTableUpdateCompanionBuilder,
      (ItemEventChange, $$ItemEventChangesTableReferences),
      ItemEventChange,
      PrefetchHooks Function({bool eventId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MembersTableTableManager get members =>
      $$MembersTableTableManager(_db, _db.members);
  $$ItemsTableTableManager get items =>
      $$ItemsTableTableManager(_db, _db.items);
  $$ItemFieldsTableTableManager get itemFields =>
      $$ItemFieldsTableTableManager(_db, _db.itemFields);
  $$AttachmentsTableTableManager get attachments =>
      $$AttachmentsTableTableManager(_db, _db.attachments);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db, _db.reminders);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$LicenseStateTableTableManager get licenseState =>
      $$LicenseStateTableTableManager(_db, _db.licenseState);
  $$ItemChildEntriesTableTableManager get itemChildEntries =>
      $$ItemChildEntriesTableTableManager(_db, _db.itemChildEntries);
  $$ItemChildFieldsTableTableManager get itemChildFields =>
      $$ItemChildFieldsTableTableManager(_db, _db.itemChildFields);
  $$ItemEventsTableTableManager get itemEvents =>
      $$ItemEventsTableTableManager(_db, _db.itemEvents);
  $$ItemEventChangesTableTableManager get itemEventChanges =>
      $$ItemEventChangesTableTableManager(_db, _db.itemEventChanges);
}
