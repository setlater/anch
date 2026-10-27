/// 备份反序列化及校验异常。
class BackupSerializationException implements Exception {
  final String message;
  BackupSerializationException(this.message);

  @override
  String toString() => 'BackupSerializationException: $message';
}

/// 备份 Payload V1 逻辑数据模型。
///
/// ⚠️ 【安全红线 - 必须遵守】
/// 1. 本类 [BackupPayloadV1] 表示的是备份文件未加密前的内存逻辑数据结构。
/// 2. 严禁以明文形式将本模型实例通过任何日志库（如 log, print）输出。
/// 3. 严禁以明文（即未加密的 JSON 文本）形式写入持久化文件系统。
/// 4. 严禁将本类或其子实体直接交给 UI。完成密码验证后，恢复确认页只能从中提取受限的
///    `BackupPackageContentPreview`，且只在当前前台会话短暂展示成员名称、资料标题、类型、状态和附件数量。
/// 5. 必须在完成内存逻辑构建后立即使用派生密钥进行加密处理（如 AES-GCM）。
class BackupPayloadV1 {
  /// 备份格式标识，固定为 "anch.backup.payload"
  final String format;

  /// 备份版本号，固定为 1
  final int version;

  /// 备份导出时间戳（毫秒）
  final int exportedAt;

  /// 导出备份时的 App 版本号
  final String appVersion;

  /// 导出备份时的数据库 Schema 版本号
  final int schemaVersion;

  /// 导出源相关环境信息
  final BackupSourceInfo source;

  /// 备份的实际业务数据
  final BackupDataV1 data;

  BackupPayloadV1({
    this.format = 'anch.backup.payload',
    this.version = 1,
    required this.exportedAt,
    required this.appVersion,
    required this.schemaVersion,
    required this.source,
    required this.data,
  });

  /// 从 Map 进行反序列化并进行严格的类型与合法性校验。
  factory BackupPayloadV1.fromJson(Map<String, dynamic> json) {
    // 1. 基础字段非空及类型校验
    final formatVal = json['format'];
    if (formatVal == null) {
      throw BackupSerializationException("Missing required field: 'format'");
    }
    if (formatVal is! String) {
      throw BackupSerializationException("Field 'format' must be a String");
    }
    if (formatVal != 'anch.backup.payload') {
      throw BackupSerializationException("Unsupported format: '$formatVal'");
    }

    final versionVal = json['version'];
    if (versionVal == null) {
      throw BackupSerializationException("Missing required field: 'version'");
    }
    if (versionVal is! int) {
      throw BackupSerializationException("Field 'version' must be an int");
    }
    if (versionVal != 1) {
      throw BackupSerializationException(
        "Unsupported backup version: $versionVal",
      );
    }

    final exportedAtVal = json['exportedAt'];
    if (exportedAtVal == null) {
      throw BackupSerializationException(
        "Missing required field: 'exportedAt'",
      );
    }
    if (exportedAtVal is! int) {
      throw BackupSerializationException(
        "Field 'exportedAt' must be an int (milliseconds)",
      );
    }

    final appVersionVal = json['appVersion'];
    if (appVersionVal == null) {
      throw BackupSerializationException(
        "Missing required field: 'appVersion'",
      );
    }
    if (appVersionVal is! String) {
      throw BackupSerializationException("Field 'appVersion' must be a String");
    }

    final schemaVersionVal = json['schemaVersion'];
    if (schemaVersionVal == null) {
      throw BackupSerializationException(
        "Missing required field: 'schemaVersion'",
      );
    }
    if (schemaVersionVal is! int) {
      throw BackupSerializationException(
        "Field 'schemaVersion' must be an int",
      );
    }

    // 2. 嵌套结构解析与校验
    final sourceMap = json['source'];
    if (sourceMap == null) {
      throw BackupSerializationException("Missing required field: 'source'");
    }
    if (sourceMap is! Map<String, dynamic>) {
      throw BackupSerializationException(
        "Field 'source' must be a JSON Object",
      );
    }
    final sourceObj = BackupSourceInfo.fromJson(sourceMap);

    final dataMap = json['data'];
    if (dataMap == null) {
      throw BackupSerializationException("Missing required field: 'data'");
    }
    if (dataMap is! Map<String, dynamic>) {
      throw BackupSerializationException("Field 'data' must be a JSON Object");
    }
    final dataObj = BackupDataV1.fromJson(dataMap);

    return BackupPayloadV1(
      format: formatVal,
      version: versionVal,
      exportedAt: exportedAtVal,
      appVersion: appVersionVal,
      schemaVersion: schemaVersionVal,
      source: sourceObj,
      data: dataObj,
    );
  }

  /// 序列化为逻辑明文 JSON 结构。
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'format': format,
      'version': version,
      'exportedAt': exportedAt,
      'appVersion': appVersion,
      'schemaVersion': schemaVersion,
      'source': source.toJson(),
      'data': data.toJson(),
    };
  }

  /// 获得一份已对所有子列表进行了稳定规范化排序后的全新备份 Payload 实例。
  ///
  /// 排序规则：
  /// 1. members 按 sortOrder 升序 -> createdAt 升序 -> id 字母序。
  /// 2. items 按 createdAt 升序 -> id 字母序。（按照最新反馈，不再包含 updatedAt 降序）
  /// 3. itemFields 按 itemId 字母序 -> sortOrder 升序 -> fieldKey 字母序 -> id 字母序。
  /// 4. appSettings 按 key 字母序。
  BackupPayloadV1 normalized() {
    // 1. members 排序
    final sortedMembers = List<BackupMemberV1>.from(data.members)
      ..sort((a, b) {
        int cmp = a.sortOrder.compareTo(b.sortOrder);
        if (cmp != 0) return cmp;
        cmp = a.createdAt.compareTo(b.createdAt);
        if (cmp != 0) return cmp;
        return a.id.compareTo(b.id);
      });

    // 2. items 排序 (根据用户最新修正案：createdAt 升序 -> id 字母序)
    final sortedItems = List<BackupItemV1>.from(data.items)
      ..sort((a, b) {
        int cmp = a.createdAt.compareTo(b.createdAt);
        if (cmp != 0) return cmp;
        return a.id.compareTo(b.id);
      });

    // 3. itemFields 排序
    final sortedFields = List<BackupItemFieldV1>.from(data.itemFields)
      ..sort((a, b) {
        int cmp = a.itemId.compareTo(b.itemId);
        if (cmp != 0) return cmp;
        cmp = a.sortOrder.compareTo(b.sortOrder);
        if (cmp != 0) return cmp;
        cmp = a.fieldKey.compareTo(b.fieldKey);
        if (cmp != 0) return cmp;
        return a.id.compareTo(b.id);
      });

    // 4. appSettings 排序
    final sortedSettings = List<BackupAppSettingV1>.from(data.appSettings)
      ..sort((a, b) => a.key.compareTo(b.key));

    // 5. attachments 排序
    final sortedAttachments = List<BackupAttachmentV1>.from(data.attachments)
      ..sort((a, b) {
        int cmp = a.itemId.compareTo(b.itemId);
        if (cmp != 0) return cmp;
        cmp = a.sortOrder.compareTo(b.sortOrder);
        if (cmp != 0) return cmp;
        return a.id.compareTo(b.id);
      });

    // 6. childEntries 排序
    final sortedChildEntries =
        List<BackupItemChildEntryV1>.from(data.childEntries)..sort((a, b) {
          int cmp = a.itemId.compareTo(b.itemId);
          if (cmp != 0) return cmp;
          cmp = a.sortOrder.compareTo(b.sortOrder);
          if (cmp != 0) return cmp;
          return a.id.compareTo(b.id);
        });

    // 7. childFields 排序
    final sortedChildFields =
        List<BackupItemChildFieldV1>.from(data.childFields)..sort((a, b) {
          int cmp = a.childEntryId.compareTo(b.childEntryId);
          if (cmp != 0) return cmp;
          cmp = a.sortOrder.compareTo(b.sortOrder);
          if (cmp != 0) return cmp;
          cmp = a.fieldKey.compareTo(b.fieldKey);
          if (cmp != 0) return cmp;
          return a.id.compareTo(b.id);
        });

    final sortedItemEvents = List<BackupItemEventV1>.from(data.itemEvents)
      ..sort((a, b) {
        int cmp = a.itemId.compareTo(b.itemId);
        if (cmp != 0) return cmp;
        cmp = a.occurredAt.compareTo(b.occurredAt);
        if (cmp != 0) return cmp;
        return a.id.compareTo(b.id);
      });
    final sortedItemEventChanges =
        List<BackupItemEventChangeV1>.from(data.itemEventChanges)..sort((a, b) {
          int cmp = a.eventId.compareTo(b.eventId);
          if (cmp != 0) return cmp;
          cmp = a.sortOrder.compareTo(b.sortOrder);
          if (cmp != 0) return cmp;
          return a.id.compareTo(b.id);
        });

    return BackupPayloadV1(
      format: format,
      version: version,
      exportedAt: exportedAt,
      appVersion: appVersion,
      schemaVersion: schemaVersion,
      source: source,
      data: BackupDataV1(
        members: sortedMembers,
        items: sortedItems,
        itemFields: sortedFields,
        appSettings: sortedSettings,
        attachments: sortedAttachments,
        childEntries: sortedChildEntries,
        childFields: sortedChildFields,
        itemEvents: sortedItemEvents,
        itemEventChanges: sortedItemEventChanges,
      ),
    );
  }
}

/// 导出源相关环境信息模型。
class BackupSourceInfo {
  final String appId;
  final String platform;
  final String? locale;
  final String exportMode; // 例如: "manual"
  final String? note;

  BackupSourceInfo({
    required this.appId,
    required this.platform,
    this.locale,
    this.exportMode = 'manual',
    this.note,
  });

  factory BackupSourceInfo.fromJson(Map<String, dynamic> json) {
    final appIdVal = json['appId'];
    if (appIdVal == null || appIdVal is! String) {
      throw BackupSerializationException(
        "source.appId is missing or not a String",
      );
    }
    final platformVal = json['platform'];
    if (platformVal == null || platformVal is! String) {
      throw BackupSerializationException(
        "source.platform is missing or not a String",
      );
    }
    final exportModeVal = json['exportMode'];
    if (exportModeVal == null || exportModeVal is! String) {
      throw BackupSerializationException(
        "source.exportMode is missing or not a String",
      );
    }

    final localeVal = json['locale'];
    if (localeVal != null && localeVal is! String) {
      throw BackupSerializationException("source.locale must be a String");
    }

    final noteVal = json['note'];
    if (noteVal != null && noteVal is! String) {
      throw BackupSerializationException("source.note must be a String");
    }

    return BackupSourceInfo(
      appId: appIdVal,
      platform: platformVal,
      locale: localeVal,
      exportMode: exportModeVal,
      note: noteVal,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'appId': appId,
      'platform': platform,
      if (locale != null) 'locale': locale,
      'exportMode': exportMode,
      if (note != null) 'note': note,
    };
  }
}

/// 备份数据载荷容器模型。
class BackupDataV1 {
  final List<BackupMemberV1> members;
  final List<BackupItemV1> items;
  final List<BackupItemFieldV1> itemFields;
  final List<BackupAppSettingV1> appSettings;
  final List<BackupAttachmentV1> attachments;
  final List<BackupItemChildEntryV1> childEntries;
  final List<BackupItemChildFieldV1> childFields;
  final List<BackupItemEventV1> itemEvents;
  final List<BackupItemEventChangeV1> itemEventChanges;

  BackupDataV1({
    required this.members,
    required this.items,
    required this.itemFields,
    required this.appSettings,
    this.attachments = const [],
    this.childEntries = const [],
    this.childFields = const [],
    this.itemEvents = const [],
    this.itemEventChanges = const [],
  });

  factory BackupDataV1.fromJson(Map<String, dynamic> json) {
    final membersList = json['members'];
    if (membersList == null || membersList is! List) {
      throw BackupSerializationException(
        "data.members is missing or not a List",
      );
    }

    final itemsList = json['items'];
    if (itemsList == null || itemsList is! List) {
      throw BackupSerializationException("data.items is missing or not a List");
    }

    final itemFieldsList = json['itemFields'];
    if (itemFieldsList == null || itemFieldsList is! List) {
      throw BackupSerializationException(
        "data.itemFields is missing or not a List",
      );
    }

    final appSettingsList = json['appSettings'];
    if (appSettingsList == null || appSettingsList is! List) {
      throw BackupSerializationException(
        "data.appSettings is missing or not a List",
      );
    }

    final attachmentsList = json['attachments'] ?? const [];
    if (attachmentsList is! List) {
      throw BackupSerializationException("data.attachments must be a List");
    }

    final childEntriesList = json['childEntries'] ?? const [];
    if (childEntriesList is! List) {
      throw BackupSerializationException("data.childEntries must be a List");
    }

    final childFieldsList = json['childFields'] ?? const [];
    if (childFieldsList is! List) {
      throw BackupSerializationException("data.childFields must be a List");
    }

    final itemEventsList = json['itemEvents'] ?? const [];
    if (itemEventsList is! List) {
      throw BackupSerializationException("data.itemEvents must be a List");
    }
    final itemEventChangesList = json['itemEventChanges'] ?? const [];
    if (itemEventChangesList is! List) {
      throw BackupSerializationException(
        "data.itemEventChanges must be a List",
      );
    }

    return BackupDataV1(
      members: membersList
          .map((m) => BackupMemberV1.fromJson(m as Map<String, dynamic>))
          .toList(),
      items: itemsList
          .map((i) => BackupItemV1.fromJson(i as Map<String, dynamic>))
          .toList(),
      itemFields: itemFieldsList
          .map((f) => BackupItemFieldV1.fromJson(f as Map<String, dynamic>))
          .toList(),
      appSettings: appSettingsList
          .map((s) => BackupAppSettingV1.fromJson(s as Map<String, dynamic>))
          .toList(),
      attachments: attachmentsList
          .map((a) => BackupAttachmentV1.fromJson(a as Map<String, dynamic>))
          .toList(),
      childEntries: childEntriesList
          .map(
            (c) => BackupItemChildEntryV1.fromJson(c as Map<String, dynamic>),
          )
          .toList(),
      childFields: childFieldsList
          .map(
            (c) => BackupItemChildFieldV1.fromJson(c as Map<String, dynamic>),
          )
          .toList(),
      itemEvents: itemEventsList
          .map(
            (event) =>
                BackupItemEventV1.fromJson(event as Map<String, dynamic>),
          )
          .toList(),
      itemEventChanges: itemEventChangesList
          .map(
            (change) => BackupItemEventChangeV1.fromJson(
              change as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'members': members.map((m) => m.toJson()).toList(),
      'items': items.map((i) => i.toJson()).toList(),
      'itemFields': itemFields.map((f) => f.toJson()).toList(),
      'appSettings': appSettings.map((s) => s.toJson()).toList(),
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'childEntries': childEntries.map((c) => c.toJson()).toList(),
      'childFields': childFields.map((c) => c.toJson()).toList(),
      'itemEvents': itemEvents.map((event) => event.toJson()).toList(),
      'itemEventChanges': itemEventChanges
          .map((change) => change.toJson())
          .toList(),
    };
  }
}

class BackupItemEventV1 {
  const BackupItemEventV1({
    required this.id,
    required this.itemId,
    required this.eventType,
    required this.occurredAt,
  });

  final String id;
  final String itemId;
  final String eventType;
  final int occurredAt;

  factory BackupItemEventV1.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final itemId = json['itemId'];
    final eventType = json['eventType'];
    final occurredAt = json['occurredAt'];
    if (id is! String ||
        itemId is! String ||
        eventType is! String ||
        occurredAt is! int) {
      throw BackupSerializationException('itemEvent fields are invalid');
    }
    return BackupItemEventV1(
      id: id,
      itemId: itemId,
      eventType: eventType,
      occurredAt: occurredAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'itemId': itemId,
    'eventType': eventType,
    'occurredAt': occurredAt,
  };
}

class BackupItemEventChangeV1 {
  const BackupItemEventChangeV1({
    required this.id,
    required this.eventId,
    required this.changeKind,
    required this.subjectKey,
    required this.subjectLabel,
    required this.oldValue,
    required this.newValue,
    required this.sortOrder,
  });

  final String id;
  final String eventId;
  final String changeKind;
  final String subjectKey;
  final String subjectLabel;
  final String? oldValue;
  final String? newValue;
  final int sortOrder;

  factory BackupItemEventChangeV1.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final eventId = json['eventId'];
    final changeKind = json['changeKind'];
    final subjectKey = json['subjectKey'];
    final subjectLabel = json['subjectLabel'];
    final oldValue = json['oldValue'];
    final newValue = json['newValue'];
    final sortOrder = json['sortOrder'];
    if (id is! String ||
        eventId is! String ||
        changeKind is! String ||
        subjectKey is! String ||
        subjectLabel is! String ||
        (oldValue != null && oldValue is! String) ||
        (newValue != null && newValue is! String) ||
        sortOrder is! int) {
      throw BackupSerializationException('itemEventChange fields are invalid');
    }
    return BackupItemEventChangeV1(
      id: id,
      eventId: eventId,
      changeKind: changeKind,
      subjectKey: subjectKey,
      subjectLabel: subjectLabel,
      oldValue: oldValue as String?,
      newValue: newValue as String?,
      sortOrder: sortOrder,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'eventId': eventId,
    'changeKind': changeKind,
    'subjectKey': subjectKey,
    'subjectLabel': subjectLabel,
    if (oldValue != null) 'oldValue': oldValue,
    if (newValue != null) 'newValue': newValue,
    'sortOrder': sortOrder,
  };
}

/// 子项备份实体
class BackupItemChildEntryV1 {
  final String id;
  final String itemId;
  final String childType;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;

  BackupItemChildEntryV1({
    required this.id,
    required this.itemId,
    required this.childType,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BackupItemChildEntryV1.fromJson(Map<String, dynamic> json) {
    final idVal = json['id'];
    if (idVal == null || idVal is! String) {
      throw BackupSerializationException(
        "childEntry.id is missing or not a String",
      );
    }
    final itemIdVal = json['itemId'];
    if (itemIdVal == null || itemIdVal is! String) {
      throw BackupSerializationException(
        "childEntry.itemId is missing or not a String",
      );
    }
    final childTypeVal = json['childType'];
    if (childTypeVal == null || childTypeVal is! String) {
      throw BackupSerializationException(
        "childEntry.childType is missing or not a String",
      );
    }
    final sortOrderVal = json['sortOrder'];
    if (sortOrderVal == null || sortOrderVal is! int) {
      throw BackupSerializationException(
        "childEntry.sortOrder is missing or not an int",
      );
    }
    final createdAtVal = json['createdAt'];
    if (createdAtVal == null || createdAtVal is! int) {
      throw BackupSerializationException(
        "childEntry.createdAt is missing or not an int",
      );
    }
    final updatedAtVal = json['updatedAt'];
    if (updatedAtVal == null || updatedAtVal is! int) {
      throw BackupSerializationException(
        "childEntry.updatedAt is missing or not an int",
      );
    }

    return BackupItemChildEntryV1(
      id: idVal,
      itemId: itemIdVal,
      childType: childTypeVal,
      sortOrder: sortOrderVal,
      createdAt: createdAtVal,
      updatedAt: updatedAtVal,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'itemId': itemId,
      'childType': childType,
      'sortOrder': sortOrder,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

/// 子属性字段备份实体
class BackupItemChildFieldV1 {
  final String id;
  final String childEntryId;
  final String fieldKey;
  final String label;
  final String? valueText;
  final String valueType;
  final String sensitiveLevel;
  final bool copyable;
  final bool searchable;
  final bool summary;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;

  BackupItemChildFieldV1({
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

  factory BackupItemChildFieldV1.fromJson(Map<String, dynamic> json) {
    final idVal = json['id'];
    if (idVal == null || idVal is! String) {
      throw BackupSerializationException(
        "childField.id is missing or not a String",
      );
    }
    final childEntryIdVal = json['childEntryId'];
    if (childEntryIdVal == null || childEntryIdVal is! String) {
      throw BackupSerializationException(
        "childField.childEntryId is missing or not a String",
      );
    }
    final fieldKeyVal = json['fieldKey'];
    if (fieldKeyVal == null || fieldKeyVal is! String) {
      throw BackupSerializationException(
        "childField.fieldKey is missing or not a String",
      );
    }
    final labelVal = json['label'];
    if (labelVal == null || labelVal is! String) {
      throw BackupSerializationException(
        "childField.label is missing or not a String",
      );
    }
    final valueTypeVal = json['valueType'];
    if (valueTypeVal == null || valueTypeVal is! String) {
      throw BackupSerializationException(
        "childField.valueType is missing or not a String",
      );
    }
    final sensitiveLevelVal = json['sensitiveLevel'];
    if (sensitiveLevelVal == null || sensitiveLevelVal is! String) {
      throw BackupSerializationException(
        "childField.sensitiveLevel is missing or not a String",
      );
    }
    final copyableVal = json['copyable'];
    if (copyableVal == null || copyableVal is! bool) {
      throw BackupSerializationException(
        "childField.copyable is missing or not a bool",
      );
    }
    final searchableVal = json['searchable'];
    if (searchableVal == null || searchableVal is! bool) {
      throw BackupSerializationException(
        "childField.searchable is missing or not a bool",
      );
    }
    final summaryVal = json['summary'];
    if (summaryVal == null || summaryVal is! bool) {
      throw BackupSerializationException(
        "childField.summary is missing or not a bool",
      );
    }
    final sortOrderVal = json['sortOrder'];
    if (sortOrderVal == null || sortOrderVal is! int) {
      throw BackupSerializationException(
        "childField.sortOrder is missing or not an int",
      );
    }
    final createdAtVal = json['createdAt'];
    if (createdAtVal == null || createdAtVal is! int) {
      throw BackupSerializationException(
        "childField.createdAt is missing or not an int",
      );
    }
    final updatedAtVal = json['updatedAt'];
    if (updatedAtVal == null || updatedAtVal is! int) {
      throw BackupSerializationException(
        "childField.updatedAt is missing or not an int",
      );
    }

    final valueTextVal = json['valueText'];
    if (valueTextVal != null && valueTextVal is! String) {
      throw BackupSerializationException(
        "childField.valueText must be a String",
      );
    }

    return BackupItemChildFieldV1(
      id: idVal,
      childEntryId: childEntryIdVal,
      fieldKey: fieldKeyVal,
      label: labelVal,
      valueText: valueTextVal,
      valueType: valueTypeVal,
      sensitiveLevel: sensitiveLevelVal,
      copyable: copyableVal,
      searchable: searchableVal,
      summary: summaryVal,
      sortOrder: sortOrderVal,
      createdAt: createdAtVal,
      updatedAt: updatedAtVal,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'childEntryId': childEntryId,
      'fieldKey': fieldKey,
      'label': label,
      if (valueText != null) 'valueText': valueText,
      'valueType': valueType,
      'sensitiveLevel': sensitiveLevel,
      'copyable': copyable,
      'searchable': searchable,
      'summary': summary,
      'sortOrder': sortOrder,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

/// 成员备份实体。
class BackupMemberV1 {
  final String id;
  final String name;
  final String relationKey;
  final bool isSystem;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;
  final String? note;
  final bool isArchived;

  BackupMemberV1({
    required this.id,
    required this.name,
    required this.relationKey,
    required this.isSystem,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.note,
    required this.isArchived,
  });

  factory BackupMemberV1.fromJson(Map<String, dynamic> json) {
    final idVal = json['id'];
    if (idVal == null || idVal is! String) {
      throw BackupSerializationException(
        "member.id is missing or not a String",
      );
    }
    final nameVal = json['name'];
    if (nameVal == null || nameVal is! String) {
      throw BackupSerializationException(
        "member.name is missing or not a String",
      );
    }
    final relationKeyVal = json['relationKey'] ?? 'other';
    if (relationKeyVal is! String) {
      throw BackupSerializationException("member.relationKey must be a String");
    }
    final isSystemVal = json['isSystem'];
    if (isSystemVal == null || isSystemVal is! bool) {
      throw BackupSerializationException(
        "member.isSystem is missing or not a bool",
      );
    }
    final sortOrderVal = json['sortOrder'];
    if (sortOrderVal == null || sortOrderVal is! int) {
      throw BackupSerializationException(
        "member.sortOrder is missing or not an int",
      );
    }
    final createdAtVal = json['createdAt'];
    if (createdAtVal == null || createdAtVal is! int) {
      throw BackupSerializationException(
        "member.createdAt is missing or not an int",
      );
    }
    final updatedAtVal = json['updatedAt'];
    if (updatedAtVal == null || updatedAtVal is! int) {
      throw BackupSerializationException(
        "member.updatedAt is missing or not an int",
      );
    }
    final isArchivedVal = json['isArchived'];
    if (isArchivedVal == null || isArchivedVal is! bool) {
      throw BackupSerializationException(
        "member.isArchived is missing or not a bool",
      );
    }

    final noteVal = json['note'];
    if (noteVal != null && noteVal is! String) {
      throw BackupSerializationException("member.note must be a String");
    }

    return BackupMemberV1(
      id: idVal,
      name: nameVal,
      relationKey: relationKeyVal,
      isSystem: isSystemVal,
      sortOrder: sortOrderVal,
      createdAt: createdAtVal,
      updatedAt: updatedAtVal,
      note: noteVal,
      isArchived: isArchivedVal,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'relationKey': relationKey,
      'isSystem': isSystem,
      'sortOrder': sortOrder,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      if (note != null) 'note': note,
      'isArchived': isArchived,
    };
  }
}

/// 资料主记录备份实体。
class BackupItemV1 {
  final String id;
  final String originId;
  final String? memberId;
  final String? categoryKey;
  final String? typeKey;
  final int templateVersion;
  final String? title;
  final String? primaryText;
  final String? secondaryText;
  final String? summaryText;
  final String? searchText;
  final String? note;
  final int createdAt;
  final int updatedAt;
  final bool isFavorite;
  final bool isPinned;
  final int? pinnedAt;
  final int sortOrder;
  final String status;
  final int? deletedAt;
  final String? statusBeforeDeletion;

  BackupItemV1({
    required this.id,
    String? originId,
    required this.memberId,
    required this.categoryKey,
    required this.typeKey,
    required this.templateVersion,
    required this.title,
    this.primaryText,
    this.secondaryText,
    this.summaryText,
    this.searchText,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    required this.isFavorite,
    required this.isPinned,
    this.pinnedAt,
    required this.sortOrder,
    required this.status,
    this.deletedAt,
    this.statusBeforeDeletion,
  }) : originId = originId ?? id;

  factory BackupItemV1.fromJson(Map<String, dynamic> json) {
    final idVal = json['id'];
    if (idVal == null || idVal is! String) {
      throw BackupSerializationException("item.id is missing or not a String");
    }
    final originIdVal = json['originId'];
    if (originIdVal != null && originIdVal is! String) {
      throw BackupSerializationException('item.originId must be a String');
    }
    final memberIdVal = json['memberId'];
    if (memberIdVal != null && memberIdVal is! String) {
      throw BackupSerializationException("item.memberId must be a String");
    }
    final categoryKeyVal = json['categoryKey'];
    if (categoryKeyVal != null && categoryKeyVal is! String) {
      throw BackupSerializationException("item.categoryKey must be a String");
    }
    final typeKeyVal = json['typeKey'];
    if (typeKeyVal != null && typeKeyVal is! String) {
      throw BackupSerializationException("item.typeKey must be a String");
    }
    final templateVersionVal = json['templateVersion'];
    if (templateVersionVal == null || templateVersionVal is! int) {
      throw BackupSerializationException(
        "item.templateVersion is missing or not an int",
      );
    }
    final titleVal = json['title'];
    if (titleVal != null && titleVal is! String) {
      throw BackupSerializationException("item.title must be a String");
    }
    final createdAtVal = json['createdAt'];
    if (createdAtVal == null || createdAtVal is! int) {
      throw BackupSerializationException(
        "item.createdAt is missing or not an int",
      );
    }
    final updatedAtVal = json['updatedAt'];
    if (updatedAtVal == null || updatedAtVal is! int) {
      throw BackupSerializationException(
        "item.updatedAt is missing or not an int",
      );
    }
    final isFavoriteVal = json['isFavorite'];
    if (isFavoriteVal == null || isFavoriteVal is! bool) {
      throw BackupSerializationException(
        "item.isFavorite is missing or not a bool",
      );
    }
    final isPinnedVal = json['isPinned'];
    if (isPinnedVal == null || isPinnedVal is! bool) {
      throw BackupSerializationException(
        "item.isPinned is missing or not a bool",
      );
    }
    final pinnedAtVal = json['pinnedAt'];
    if (pinnedAtVal != null && pinnedAtVal is! int) {
      throw BackupSerializationException("item.pinnedAt must be an int");
    }
    final sortOrderVal = json['sortOrder'];
    if (sortOrderVal == null || sortOrderVal is! int) {
      throw BackupSerializationException(
        "item.sortOrder is missing or not an int",
      );
    }
    final statusVal = json['status'];
    if (statusVal == null || statusVal is! String) {
      throw BackupSerializationException(
        "item.status is missing or not a String",
      );
    }
    final deletedAtVal = json['deletedAt'];
    if (deletedAtVal != null && deletedAtVal is! int) {
      throw BackupSerializationException('item.deletedAt must be an int');
    }
    final statusBeforeDeletionVal = json['statusBeforeDeletion'];
    if (statusBeforeDeletionVal != null && statusBeforeDeletionVal is! String) {
      throw BackupSerializationException(
        'item.statusBeforeDeletion must be a String',
      );
    }

    final primaryTextVal = json['primaryText'];
    if (primaryTextVal != null && primaryTextVal is! String) {
      throw BackupSerializationException("item.primaryText must be a String");
    }
    final secondaryTextVal = json['secondaryText'];
    if (secondaryTextVal != null && secondaryTextVal is! String) {
      throw BackupSerializationException("item.secondaryText must be a String");
    }
    final summaryTextVal = json['summaryText'];
    if (summaryTextVal != null && summaryTextVal is! String) {
      throw BackupSerializationException("item.summaryText must be a String");
    }
    final searchTextVal = json['searchText'];
    if (searchTextVal != null && searchTextVal is! String) {
      throw BackupSerializationException("item.searchText must be a String");
    }
    final noteVal = json['note'];
    if (noteVal != null && noteVal is! String) {
      throw BackupSerializationException("item.note must be a String");
    }

    return BackupItemV1(
      id: idVal,
      originId: originIdVal as String?,
      memberId: memberIdVal,
      categoryKey: categoryKeyVal,
      typeKey: typeKeyVal,
      templateVersion: templateVersionVal,
      title: titleVal,
      primaryText: primaryTextVal,
      secondaryText: secondaryTextVal,
      summaryText: summaryTextVal,
      searchText: searchTextVal,
      note: noteVal,
      createdAt: createdAtVal,
      updatedAt: updatedAtVal,
      isFavorite: isFavoriteVal,
      isPinned: isPinnedVal,
      pinnedAt: pinnedAtVal,
      sortOrder: sortOrderVal,
      status: statusVal,
      deletedAt: deletedAtVal,
      statusBeforeDeletion: statusBeforeDeletionVal,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'originId': originId,
      'memberId': memberId,
      'categoryKey': categoryKey,
      'typeKey': typeKey,
      'templateVersion': templateVersion,
      'title': title,
      if (primaryText != null) 'primaryText': primaryText,
      if (secondaryText != null) 'secondaryText': secondaryText,
      if (summaryText != null) 'summaryText': summaryText,
      if (searchText != null) 'searchText': searchText,
      if (note != null) 'note': note,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isFavorite': isFavorite,
      'isPinned': isPinned,
      if (pinnedAt != null) 'pinnedAt': pinnedAt,
      'sortOrder': sortOrder,
      'status': status,
      if (deletedAt != null) 'deletedAt': deletedAt,
      if (statusBeforeDeletion != null)
        'statusBeforeDeletion': statusBeforeDeletion,
    };
  }

  BackupItemV1 withStatusBeforeDeletion(String? value) {
    return BackupItemV1(
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
      createdAt: createdAt,
      updatedAt: updatedAt,
      isFavorite: isFavorite,
      isPinned: isPinned,
      pinnedAt: pinnedAt,
      sortOrder: sortOrder,
      status: status,
      deletedAt: deletedAt,
      statusBeforeDeletion: value,
    );
  }
}

/// 资料单字段属性备份实体。
class BackupItemFieldV1 {
  final String id;
  final String itemId;
  final String fieldKey;
  final String valueType;

  /// ⚠️ 可能包含高敏字段明文值，在内存中必须保持高敏明文以保证完全恢复，但严禁明文持久化
  final String? valueText;
  final String? normalizedValue;
  final String? fieldNote;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;

  BackupItemFieldV1({
    required this.id,
    required this.itemId,
    required this.fieldKey,
    required this.valueType,
    this.valueText,
    this.normalizedValue,
    this.fieldNote,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BackupItemFieldV1.fromJson(Map<String, dynamic> json) {
    final idVal = json['id'];
    if (idVal == null || idVal is! String) {
      throw BackupSerializationException(
        "itemField.id is missing or not a String",
      );
    }
    final itemIdVal = json['itemId'];
    if (itemIdVal == null || itemIdVal is! String) {
      throw BackupSerializationException(
        "itemField.itemId is missing or not a String",
      );
    }
    final fieldKeyVal = json['fieldKey'];
    if (fieldKeyVal == null || fieldKeyVal is! String) {
      throw BackupSerializationException(
        "itemField.fieldKey is missing or not a String",
      );
    }
    final valueTypeVal = json['valueType'];
    if (valueTypeVal == null || valueTypeVal is! String) {
      throw BackupSerializationException(
        "itemField.valueType is missing or not a String",
      );
    }
    final sortOrderVal = json['sortOrder'];
    if (sortOrderVal == null || sortOrderVal is! int) {
      throw BackupSerializationException(
        "itemField.sortOrder is missing or not an int",
      );
    }
    final createdAtVal = json['createdAt'];
    if (createdAtVal == null || createdAtVal is! int) {
      throw BackupSerializationException(
        "itemField.createdAt is missing or not an int",
      );
    }
    final updatedAtVal = json['updatedAt'];
    if (updatedAtVal == null || updatedAtVal is! int) {
      throw BackupSerializationException(
        "itemField.updatedAt is missing or not an int",
      );
    }

    final valueTextVal = json['valueText'];
    if (valueTextVal != null && valueTextVal is! String) {
      throw BackupSerializationException(
        "itemField.valueText must be a String",
      );
    }

    final normalizedValueVal = json['normalizedValue'];
    if (normalizedValueVal != null && normalizedValueVal is! String) {
      throw BackupSerializationException(
        "itemField.normalizedValue must be a String",
      );
    }

    final fieldNoteVal = json['fieldNote'];
    if (fieldNoteVal != null && fieldNoteVal is! String) {
      throw BackupSerializationException(
        "itemField.fieldNote must be a String",
      );
    }

    return BackupItemFieldV1(
      id: idVal,
      itemId: itemIdVal,
      fieldKey: fieldKeyVal,
      valueType: valueTypeVal,
      valueText: valueTextVal,
      normalizedValue: normalizedValueVal,
      fieldNote: fieldNoteVal,
      sortOrder: sortOrderVal,
      createdAt: createdAtVal,
      updatedAt: updatedAtVal,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'itemId': itemId,
      'fieldKey': fieldKey,
      'valueType': valueType,
      if (valueText != null) 'valueText': valueText,
      if (normalizedValue != null) 'normalizedValue': normalizedValue,
      if (fieldNote != null) 'fieldNote': fieldNote,
      'sortOrder': sortOrder,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

/// 本地设置备份实体。
class BackupAppSettingV1 {
  final String key;
  final String? value;
  final String valueType;
  final int updatedAt;

  BackupAppSettingV1({
    required this.key,
    this.value,
    required this.valueType,
    required this.updatedAt,
  });

  factory BackupAppSettingV1.fromJson(Map<String, dynamic> json) {
    final keyVal = json['key'];
    if (keyVal == null || keyVal is! String) {
      throw BackupSerializationException(
        "appSetting.key is missing or not a String",
      );
    }
    final valueTypeVal = json['valueType'];
    if (valueTypeVal == null || valueTypeVal is! String) {
      throw BackupSerializationException(
        "appSetting.valueType is missing or not a String",
      );
    }
    final updatedAtVal = json['updatedAt'];
    if (updatedAtVal == null || updatedAtVal is! int) {
      throw BackupSerializationException(
        "appSetting.updatedAt is missing or not an int",
      );
    }

    final valueVal = json['value'];
    if (valueVal != null && valueVal is! String) {
      throw BackupSerializationException("appSetting.value must be a String");
    }

    return BackupAppSettingV1(
      key: keyVal,
      value: valueVal,
      valueType: valueTypeVal,
      updatedAt: updatedAtVal,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'key': key,
      if (value != null) 'value': value,
      'valueType': valueType,
      'updatedAt': updatedAt,
    };
  }
}

/// 附件备份实体。
class BackupAttachmentV1 {
  final String id;
  final String originAttachmentId;
  final String itemId;
  final String? linkedFieldKey;
  final String attachmentRole;
  final String fileName;
  final String? originalName;
  final String mimeType;
  final int plainSize;
  final int encryptedSize;
  final String? sha256;
  final int sortOrder;
  final String status;
  final int createdAt;
  final int updatedAt;
  final String encryptedData;

  BackupAttachmentV1({
    required this.id,
    String? originAttachmentId,
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
    required this.encryptedData,
  }) : originAttachmentId = originAttachmentId ?? id;

  factory BackupAttachmentV1.fromJson(Map<String, dynamic> json) {
    final idVal = json['id'];
    if (idVal == null || idVal is! String) {
      throw BackupSerializationException(
        "attachment.id is missing or not a String",
      );
    }
    final originAttachmentIdVal = json['originAttachmentId'];
    if (originAttachmentIdVal != null && originAttachmentIdVal is! String) {
      throw BackupSerializationException(
        'attachment.originAttachmentId must be a String',
      );
    }
    final itemIdVal = json['itemId'];
    if (itemIdVal == null || itemIdVal is! String) {
      throw BackupSerializationException(
        "attachment.itemId is missing or not a String",
      );
    }
    final attachmentRoleVal = json['attachmentRole'];
    if (attachmentRoleVal == null || attachmentRoleVal is! String) {
      throw BackupSerializationException(
        "attachment.attachmentRole is missing or not a String",
      );
    }
    final fileNameVal = json['fileName'];
    if (fileNameVal == null || fileNameVal is! String) {
      throw BackupSerializationException(
        "attachment.fileName is missing or not a String",
      );
    }
    final mimeTypeVal = json['mimeType'];
    if (mimeTypeVal == null || mimeTypeVal is! String) {
      throw BackupSerializationException(
        "attachment.mimeType is missing or not a String",
      );
    }
    final plainSizeVal = json['plainSize'];
    if (plainSizeVal == null || plainSizeVal is! int) {
      throw BackupSerializationException(
        "attachment.plainSize is missing or not an int",
      );
    }
    final encryptedSizeVal = json['encryptedSize'];
    if (encryptedSizeVal == null || encryptedSizeVal is! int) {
      throw BackupSerializationException(
        "attachment.encryptedSize is missing or not an int",
      );
    }
    final sortOrderVal = json['sortOrder'];
    if (sortOrderVal == null || sortOrderVal is! int) {
      throw BackupSerializationException(
        "attachment.sortOrder is missing or not an int",
      );
    }
    final statusVal = json['status'];
    if (statusVal == null || statusVal is! String) {
      throw BackupSerializationException(
        "attachment.status is missing or not a String",
      );
    }
    final createdAtVal = json['createdAt'];
    if (createdAtVal == null || createdAtVal is! int) {
      throw BackupSerializationException(
        "attachment.createdAt is missing or not an int",
      );
    }
    final updatedAtVal = json['updatedAt'];
    if (updatedAtVal == null || updatedAtVal is! int) {
      throw BackupSerializationException(
        "attachment.updatedAt is missing or not an int",
      );
    }
    final encryptedDataVal = json['encryptedData'];
    if (encryptedDataVal == null || encryptedDataVal is! String) {
      throw BackupSerializationException(
        "attachment.encryptedData is missing or not a String",
      );
    }

    final linkedFieldKeyVal = json['linkedFieldKey'];
    if (linkedFieldKeyVal != null && linkedFieldKeyVal is! String) {
      throw BackupSerializationException(
        "attachment.linkedFieldKey must be a String",
      );
    }
    final originalNameVal = json['originalName'];
    if (originalNameVal != null && originalNameVal is! String) {
      throw BackupSerializationException(
        "attachment.originalName must be a String",
      );
    }
    final sha256Val = json['sha256'];
    if (sha256Val != null && sha256Val is! String) {
      throw BackupSerializationException("attachment.sha256 must be a String");
    }

    return BackupAttachmentV1(
      id: idVal,
      originAttachmentId: originAttachmentIdVal as String?,
      itemId: itemIdVal,
      linkedFieldKey: linkedFieldKeyVal,
      attachmentRole: attachmentRoleVal,
      fileName: fileNameVal,
      originalName: originalNameVal,
      mimeType: mimeTypeVal,
      plainSize: plainSizeVal,
      encryptedSize: encryptedSizeVal,
      sha256: sha256Val,
      sortOrder: sortOrderVal,
      status: statusVal,
      createdAt: createdAtVal,
      updatedAt: updatedAtVal,
      encryptedData: encryptedDataVal,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'originAttachmentId': originAttachmentId,
      'itemId': itemId,
      if (linkedFieldKey != null) 'linkedFieldKey': linkedFieldKey,
      'attachmentRole': attachmentRole,
      'fileName': fileName,
      if (originalName != null) 'originalName': originalName,
      'mimeType': mimeType,
      'plainSize': plainSize,
      'encryptedSize': encryptedSize,
      if (sha256 != null) 'sha256': sha256,
      'sortOrder': sortOrder,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'encryptedData': encryptedData,
    };
  }
}
