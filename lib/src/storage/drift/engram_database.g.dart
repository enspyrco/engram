// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'engram_database.dart';

// ignore_for_file: type=lint
class $DriftConceptsTable extends DriftConcepts
    with TableInfo<$DriftConceptsTable, DriftConcept> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DriftConceptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceDocumentIdMeta = const VerificationMeta(
    'sourceDocumentId',
  );
  @override
  late final GeneratedColumn<String> sourceDocumentId = GeneratedColumn<String>(
    'source_document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<IList<String>, String> tags =
      GeneratedColumn<String>(
        'tags',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<IList<String>>($DriftConceptsTable.$convertertags);
  static const VerificationMeta _parentConceptIdMeta = const VerificationMeta(
    'parentConceptId',
  );
  @override
  late final GeneratedColumn<String> parentConceptId = GeneratedColumn<String>(
    'parent_concept_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _embeddingMeta = const VerificationMeta(
    'embedding',
  );
  @override
  late final GeneratedColumn<Uint8List> embedding = GeneratedColumn<Uint8List>(
    'embedding',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    sourceDocumentId,
    tags,
    parentConceptId,
    embedding,
    hlc,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drift_concepts';
  @override
  VerificationContext validateIntegrity(
    Insertable<DriftConcept> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('source_document_id')) {
      context.handle(
        _sourceDocumentIdMeta,
        sourceDocumentId.isAcceptableOrUnknown(
          data['source_document_id']!,
          _sourceDocumentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceDocumentIdMeta);
    }
    if (data.containsKey('parent_concept_id')) {
      context.handle(
        _parentConceptIdMeta,
        parentConceptId.isAcceptableOrUnknown(
          data['parent_concept_id']!,
          _parentConceptIdMeta,
        ),
      );
    }
    if (data.containsKey('embedding')) {
      context.handle(
        _embeddingMeta,
        embedding.isAcceptableOrUnknown(data['embedding']!, _embeddingMeta),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DriftConcept map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftConcept(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      description:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}description'],
          )!,
      sourceDocumentId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}source_document_id'],
          )!,
      tags: $DriftConceptsTable.$convertertags.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tags'],
        )!,
      ),
      parentConceptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_concept_id'],
      ),
      embedding: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}embedding'],
      ),
      hlc:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}hlc'],
          )!,
      isDeleted:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_deleted'],
          )!,
    );
  }

  @override
  $DriftConceptsTable createAlias(String alias) {
    return $DriftConceptsTable(attachedDatabase, alias);
  }

  static TypeConverter<IList<String>, String> $convertertags =
      const IListStringConverter();
}

class DriftConcept extends DataClass implements Insertable<DriftConcept> {
  final String id;
  final String name;
  final String description;
  final String sourceDocumentId;
  final IList<String> tags;
  final String? parentConceptId;
  final Uint8List? embedding;
  final String hlc;
  final bool isDeleted;
  const DriftConcept({
    required this.id,
    required this.name,
    required this.description,
    required this.sourceDocumentId,
    required this.tags,
    this.parentConceptId,
    this.embedding,
    required this.hlc,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['source_document_id'] = Variable<String>(sourceDocumentId);
    {
      map['tags'] = Variable<String>(
        $DriftConceptsTable.$convertertags.toSql(tags),
      );
    }
    if (!nullToAbsent || parentConceptId != null) {
      map['parent_concept_id'] = Variable<String>(parentConceptId);
    }
    if (!nullToAbsent || embedding != null) {
      map['embedding'] = Variable<Uint8List>(embedding);
    }
    map['hlc'] = Variable<String>(hlc);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  DriftConceptsCompanion toCompanion(bool nullToAbsent) {
    return DriftConceptsCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
      sourceDocumentId: Value(sourceDocumentId),
      tags: Value(tags),
      parentConceptId:
          parentConceptId == null && nullToAbsent
              ? const Value.absent()
              : Value(parentConceptId),
      embedding:
          embedding == null && nullToAbsent
              ? const Value.absent()
              : Value(embedding),
      hlc: Value(hlc),
      isDeleted: Value(isDeleted),
    );
  }

  factory DriftConcept.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftConcept(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      sourceDocumentId: serializer.fromJson<String>(json['sourceDocumentId']),
      tags: serializer.fromJson<IList<String>>(json['tags']),
      parentConceptId: serializer.fromJson<String?>(json['parentConceptId']),
      embedding: serializer.fromJson<Uint8List?>(json['embedding']),
      hlc: serializer.fromJson<String>(json['hlc']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'sourceDocumentId': serializer.toJson<String>(sourceDocumentId),
      'tags': serializer.toJson<IList<String>>(tags),
      'parentConceptId': serializer.toJson<String?>(parentConceptId),
      'embedding': serializer.toJson<Uint8List?>(embedding),
      'hlc': serializer.toJson<String>(hlc),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  DriftConcept copyWith({
    String? id,
    String? name,
    String? description,
    String? sourceDocumentId,
    IList<String>? tags,
    Value<String?> parentConceptId = const Value.absent(),
    Value<Uint8List?> embedding = const Value.absent(),
    String? hlc,
    bool? isDeleted,
  }) => DriftConcept(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    sourceDocumentId: sourceDocumentId ?? this.sourceDocumentId,
    tags: tags ?? this.tags,
    parentConceptId:
        parentConceptId.present ? parentConceptId.value : this.parentConceptId,
    embedding: embedding.present ? embedding.value : this.embedding,
    hlc: hlc ?? this.hlc,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  DriftConcept copyWithCompanion(DriftConceptsCompanion data) {
    return DriftConcept(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      sourceDocumentId:
          data.sourceDocumentId.present
              ? data.sourceDocumentId.value
              : this.sourceDocumentId,
      tags: data.tags.present ? data.tags.value : this.tags,
      parentConceptId:
          data.parentConceptId.present
              ? data.parentConceptId.value
              : this.parentConceptId,
      embedding: data.embedding.present ? data.embedding.value : this.embedding,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriftConcept(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('sourceDocumentId: $sourceDocumentId, ')
          ..write('tags: $tags, ')
          ..write('parentConceptId: $parentConceptId, ')
          ..write('embedding: $embedding, ')
          ..write('hlc: $hlc, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    sourceDocumentId,
    tags,
    parentConceptId,
    $driftBlobEquality.hash(embedding),
    hlc,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftConcept &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.sourceDocumentId == this.sourceDocumentId &&
          other.tags == this.tags &&
          other.parentConceptId == this.parentConceptId &&
          $driftBlobEquality.equals(other.embedding, this.embedding) &&
          other.hlc == this.hlc &&
          other.isDeleted == this.isDeleted);
}

class DriftConceptsCompanion extends UpdateCompanion<DriftConcept> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> description;
  final Value<String> sourceDocumentId;
  final Value<IList<String>> tags;
  final Value<String?> parentConceptId;
  final Value<Uint8List?> embedding;
  final Value<String> hlc;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const DriftConceptsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.sourceDocumentId = const Value.absent(),
    this.tags = const Value.absent(),
    this.parentConceptId = const Value.absent(),
    this.embedding = const Value.absent(),
    this.hlc = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DriftConceptsCompanion.insert({
    required String id,
    required String name,
    required String description,
    required String sourceDocumentId,
    required IList<String> tags,
    this.parentConceptId = const Value.absent(),
    this.embedding = const Value.absent(),
    this.hlc = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       description = Value(description),
       sourceDocumentId = Value(sourceDocumentId),
       tags = Value(tags);
  static Insertable<DriftConcept> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? sourceDocumentId,
    Expression<String>? tags,
    Expression<String>? parentConceptId,
    Expression<Uint8List>? embedding,
    Expression<String>? hlc,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (sourceDocumentId != null) 'source_document_id': sourceDocumentId,
      if (tags != null) 'tags': tags,
      if (parentConceptId != null) 'parent_concept_id': parentConceptId,
      if (embedding != null) 'embedding': embedding,
      if (hlc != null) 'hlc': hlc,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DriftConceptsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? description,
    Value<String>? sourceDocumentId,
    Value<IList<String>>? tags,
    Value<String?>? parentConceptId,
    Value<Uint8List?>? embedding,
    Value<String>? hlc,
    Value<bool>? isDeleted,
    Value<int>? rowid,
  }) {
    return DriftConceptsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      sourceDocumentId: sourceDocumentId ?? this.sourceDocumentId,
      tags: tags ?? this.tags,
      parentConceptId: parentConceptId ?? this.parentConceptId,
      embedding: embedding ?? this.embedding,
      hlc: hlc ?? this.hlc,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (sourceDocumentId.present) {
      map['source_document_id'] = Variable<String>(sourceDocumentId.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(
        $DriftConceptsTable.$convertertags.toSql(tags.value),
      );
    }
    if (parentConceptId.present) {
      map['parent_concept_id'] = Variable<String>(parentConceptId.value);
    }
    if (embedding.present) {
      map['embedding'] = Variable<Uint8List>(embedding.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DriftConceptsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('sourceDocumentId: $sourceDocumentId, ')
          ..write('tags: $tags, ')
          ..write('parentConceptId: $parentConceptId, ')
          ..write('embedding: $embedding, ')
          ..write('hlc: $hlc, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DriftRelationshipsTable extends DriftRelationships
    with TableInfo<$DriftRelationshipsTable, DriftRelationship> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DriftRelationshipsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromConceptIdMeta = const VerificationMeta(
    'fromConceptId',
  );
  @override
  late final GeneratedColumn<String> fromConceptId = GeneratedColumn<String>(
    'from_concept_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toConceptIdMeta = const VerificationMeta(
    'toConceptId',
  );
  @override
  late final GeneratedColumn<String> toConceptId = GeneratedColumn<String>(
    'to_concept_id',
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
  @override
  late final GeneratedColumnWithTypeConverter<RelationshipType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<RelationshipType>(
        $DriftRelationshipsTable.$convertertype,
      );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fromConceptId,
    toConceptId,
    label,
    description,
    type,
    hlc,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drift_relationships';
  @override
  VerificationContext validateIntegrity(
    Insertable<DriftRelationship> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('from_concept_id')) {
      context.handle(
        _fromConceptIdMeta,
        fromConceptId.isAcceptableOrUnknown(
          data['from_concept_id']!,
          _fromConceptIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fromConceptIdMeta);
    }
    if (data.containsKey('to_concept_id')) {
      context.handle(
        _toConceptIdMeta,
        toConceptId.isAcceptableOrUnknown(
          data['to_concept_id']!,
          _toConceptIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_toConceptIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
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
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DriftRelationship map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftRelationship(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      fromConceptId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}from_concept_id'],
          )!,
      toConceptId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}to_concept_id'],
          )!,
      label:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}label'],
          )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      type: $DriftRelationshipsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      hlc:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}hlc'],
          )!,
      isDeleted:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_deleted'],
          )!,
    );
  }

  @override
  $DriftRelationshipsTable createAlias(String alias) {
    return $DriftRelationshipsTable(attachedDatabase, alias);
  }

  static TypeConverter<RelationshipType, String> $convertertype =
      const RelationshipTypeConverter();
}

class DriftRelationship extends DataClass
    implements Insertable<DriftRelationship> {
  final String id;
  final String fromConceptId;
  final String toConceptId;
  final String label;
  final String? description;
  final RelationshipType type;
  final String hlc;
  final bool isDeleted;
  const DriftRelationship({
    required this.id,
    required this.fromConceptId,
    required this.toConceptId,
    required this.label,
    this.description,
    required this.type,
    required this.hlc,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['from_concept_id'] = Variable<String>(fromConceptId);
    map['to_concept_id'] = Variable<String>(toConceptId);
    map['label'] = Variable<String>(label);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    {
      map['type'] = Variable<String>(
        $DriftRelationshipsTable.$convertertype.toSql(type),
      );
    }
    map['hlc'] = Variable<String>(hlc);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  DriftRelationshipsCompanion toCompanion(bool nullToAbsent) {
    return DriftRelationshipsCompanion(
      id: Value(id),
      fromConceptId: Value(fromConceptId),
      toConceptId: Value(toConceptId),
      label: Value(label),
      description:
          description == null && nullToAbsent
              ? const Value.absent()
              : Value(description),
      type: Value(type),
      hlc: Value(hlc),
      isDeleted: Value(isDeleted),
    );
  }

  factory DriftRelationship.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftRelationship(
      id: serializer.fromJson<String>(json['id']),
      fromConceptId: serializer.fromJson<String>(json['fromConceptId']),
      toConceptId: serializer.fromJson<String>(json['toConceptId']),
      label: serializer.fromJson<String>(json['label']),
      description: serializer.fromJson<String?>(json['description']),
      type: serializer.fromJson<RelationshipType>(json['type']),
      hlc: serializer.fromJson<String>(json['hlc']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'fromConceptId': serializer.toJson<String>(fromConceptId),
      'toConceptId': serializer.toJson<String>(toConceptId),
      'label': serializer.toJson<String>(label),
      'description': serializer.toJson<String?>(description),
      'type': serializer.toJson<RelationshipType>(type),
      'hlc': serializer.toJson<String>(hlc),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  DriftRelationship copyWith({
    String? id,
    String? fromConceptId,
    String? toConceptId,
    String? label,
    Value<String?> description = const Value.absent(),
    RelationshipType? type,
    String? hlc,
    bool? isDeleted,
  }) => DriftRelationship(
    id: id ?? this.id,
    fromConceptId: fromConceptId ?? this.fromConceptId,
    toConceptId: toConceptId ?? this.toConceptId,
    label: label ?? this.label,
    description: description.present ? description.value : this.description,
    type: type ?? this.type,
    hlc: hlc ?? this.hlc,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  DriftRelationship copyWithCompanion(DriftRelationshipsCompanion data) {
    return DriftRelationship(
      id: data.id.present ? data.id.value : this.id,
      fromConceptId:
          data.fromConceptId.present
              ? data.fromConceptId.value
              : this.fromConceptId,
      toConceptId:
          data.toConceptId.present ? data.toConceptId.value : this.toConceptId,
      label: data.label.present ? data.label.value : this.label,
      description:
          data.description.present ? data.description.value : this.description,
      type: data.type.present ? data.type.value : this.type,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriftRelationship(')
          ..write('id: $id, ')
          ..write('fromConceptId: $fromConceptId, ')
          ..write('toConceptId: $toConceptId, ')
          ..write('label: $label, ')
          ..write('description: $description, ')
          ..write('type: $type, ')
          ..write('hlc: $hlc, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fromConceptId,
    toConceptId,
    label,
    description,
    type,
    hlc,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftRelationship &&
          other.id == this.id &&
          other.fromConceptId == this.fromConceptId &&
          other.toConceptId == this.toConceptId &&
          other.label == this.label &&
          other.description == this.description &&
          other.type == this.type &&
          other.hlc == this.hlc &&
          other.isDeleted == this.isDeleted);
}

class DriftRelationshipsCompanion extends UpdateCompanion<DriftRelationship> {
  final Value<String> id;
  final Value<String> fromConceptId;
  final Value<String> toConceptId;
  final Value<String> label;
  final Value<String?> description;
  final Value<RelationshipType> type;
  final Value<String> hlc;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const DriftRelationshipsCompanion({
    this.id = const Value.absent(),
    this.fromConceptId = const Value.absent(),
    this.toConceptId = const Value.absent(),
    this.label = const Value.absent(),
    this.description = const Value.absent(),
    this.type = const Value.absent(),
    this.hlc = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DriftRelationshipsCompanion.insert({
    required String id,
    required String fromConceptId,
    required String toConceptId,
    required String label,
    this.description = const Value.absent(),
    required RelationshipType type,
    this.hlc = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       fromConceptId = Value(fromConceptId),
       toConceptId = Value(toConceptId),
       label = Value(label),
       type = Value(type);
  static Insertable<DriftRelationship> custom({
    Expression<String>? id,
    Expression<String>? fromConceptId,
    Expression<String>? toConceptId,
    Expression<String>? label,
    Expression<String>? description,
    Expression<String>? type,
    Expression<String>? hlc,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fromConceptId != null) 'from_concept_id': fromConceptId,
      if (toConceptId != null) 'to_concept_id': toConceptId,
      if (label != null) 'label': label,
      if (description != null) 'description': description,
      if (type != null) 'type': type,
      if (hlc != null) 'hlc': hlc,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DriftRelationshipsCompanion copyWith({
    Value<String>? id,
    Value<String>? fromConceptId,
    Value<String>? toConceptId,
    Value<String>? label,
    Value<String?>? description,
    Value<RelationshipType>? type,
    Value<String>? hlc,
    Value<bool>? isDeleted,
    Value<int>? rowid,
  }) {
    return DriftRelationshipsCompanion(
      id: id ?? this.id,
      fromConceptId: fromConceptId ?? this.fromConceptId,
      toConceptId: toConceptId ?? this.toConceptId,
      label: label ?? this.label,
      description: description ?? this.description,
      type: type ?? this.type,
      hlc: hlc ?? this.hlc,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (fromConceptId.present) {
      map['from_concept_id'] = Variable<String>(fromConceptId.value);
    }
    if (toConceptId.present) {
      map['to_concept_id'] = Variable<String>(toConceptId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $DriftRelationshipsTable.$convertertype.toSql(type.value),
      );
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DriftRelationshipsCompanion(')
          ..write('id: $id, ')
          ..write('fromConceptId: $fromConceptId, ')
          ..write('toConceptId: $toConceptId, ')
          ..write('label: $label, ')
          ..write('description: $description, ')
          ..write('type: $type, ')
          ..write('hlc: $hlc, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DriftQuizItemsTable extends DriftQuizItems
    with TableInfo<$DriftQuizItemsTable, DriftQuizItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DriftQuizItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conceptIdMeta = const VerificationMeta(
    'conceptId',
  );
  @override
  late final GeneratedColumn<String> conceptId = GeneratedColumn<String>(
    'concept_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionMeta = const VerificationMeta(
    'question',
  );
  @override
  late final GeneratedColumn<String> question = GeneratedColumn<String>(
    'question',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answerMeta = const VerificationMeta('answer');
  @override
  late final GeneratedColumn<String> answer = GeneratedColumn<String>(
    'answer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _intervalMeta = const VerificationMeta(
    'interval',
  );
  @override
  late final GeneratedColumn<int> interval = GeneratedColumn<int>(
    'interval',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextReviewMeta = const VerificationMeta(
    'nextReview',
  );
  @override
  late final GeneratedColumn<String> nextReview = GeneratedColumn<String>(
    'next_review',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastReviewMeta = const VerificationMeta(
    'lastReview',
  );
  @override
  late final GeneratedColumn<String> lastReview = GeneratedColumn<String>(
    'last_review',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<double> difficulty = GeneratedColumn<double>(
    'difficulty',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stabilityMeta = const VerificationMeta(
    'stability',
  );
  @override
  late final GeneratedColumn<double> stability = GeneratedColumn<double>(
    'stability',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fsrsStateMeta = const VerificationMeta(
    'fsrsState',
  );
  @override
  late final GeneratedColumn<int> fsrsState = GeneratedColumn<int>(
    'fsrs_state',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lapsesMeta = const VerificationMeta('lapses');
  @override
  late final GeneratedColumn<int> lapses = GeneratedColumn<int>(
    'lapses',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _predictedDifficultyMeta =
      const VerificationMeta('predictedDifficulty');
  @override
  late final GeneratedColumn<double> predictedDifficulty =
      GeneratedColumn<double>(
        'predicted_difficulty',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _reviewCountMeta = const VerificationMeta(
    'reviewCount',
  );
  @override
  late final GeneratedColumn<int> reviewCount = GeneratedColumn<int>(
    'review_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<IList<String>?, String> rubric =
      GeneratedColumn<String>(
        'rubric',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<IList<String>?>($DriftQuizItemsTable.$converterrubricn);
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conceptId,
    question,
    answer,
    interval,
    nextReview,
    lastReview,
    difficulty,
    stability,
    fsrsState,
    lapses,
    predictedDifficulty,
    reviewCount,
    rubric,
    hlc,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drift_quiz_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<DriftQuizItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('concept_id')) {
      context.handle(
        _conceptIdMeta,
        conceptId.isAcceptableOrUnknown(data['concept_id']!, _conceptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_conceptIdMeta);
    }
    if (data.containsKey('question')) {
      context.handle(
        _questionMeta,
        question.isAcceptableOrUnknown(data['question']!, _questionMeta),
      );
    } else if (isInserting) {
      context.missing(_questionMeta);
    }
    if (data.containsKey('answer')) {
      context.handle(
        _answerMeta,
        answer.isAcceptableOrUnknown(data['answer']!, _answerMeta),
      );
    } else if (isInserting) {
      context.missing(_answerMeta);
    }
    if (data.containsKey('interval')) {
      context.handle(
        _intervalMeta,
        interval.isAcceptableOrUnknown(data['interval']!, _intervalMeta),
      );
    } else if (isInserting) {
      context.missing(_intervalMeta);
    }
    if (data.containsKey('next_review')) {
      context.handle(
        _nextReviewMeta,
        nextReview.isAcceptableOrUnknown(data['next_review']!, _nextReviewMeta),
      );
    } else if (isInserting) {
      context.missing(_nextReviewMeta);
    }
    if (data.containsKey('last_review')) {
      context.handle(
        _lastReviewMeta,
        lastReview.isAcceptableOrUnknown(data['last_review']!, _lastReviewMeta),
      );
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    }
    if (data.containsKey('stability')) {
      context.handle(
        _stabilityMeta,
        stability.isAcceptableOrUnknown(data['stability']!, _stabilityMeta),
      );
    }
    if (data.containsKey('fsrs_state')) {
      context.handle(
        _fsrsStateMeta,
        fsrsState.isAcceptableOrUnknown(data['fsrs_state']!, _fsrsStateMeta),
      );
    }
    if (data.containsKey('lapses')) {
      context.handle(
        _lapsesMeta,
        lapses.isAcceptableOrUnknown(data['lapses']!, _lapsesMeta),
      );
    }
    if (data.containsKey('predicted_difficulty')) {
      context.handle(
        _predictedDifficultyMeta,
        predictedDifficulty.isAcceptableOrUnknown(
          data['predicted_difficulty']!,
          _predictedDifficultyMeta,
        ),
      );
    }
    if (data.containsKey('review_count')) {
      context.handle(
        _reviewCountMeta,
        reviewCount.isAcceptableOrUnknown(
          data['review_count']!,
          _reviewCountMeta,
        ),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DriftQuizItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftQuizItem(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      conceptId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}concept_id'],
          )!,
      question:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}question'],
          )!,
      answer:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}answer'],
          )!,
      interval:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}interval'],
          )!,
      nextReview:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}next_review'],
          )!,
      lastReview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_review'],
      ),
      difficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}difficulty'],
      ),
      stability: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stability'],
      ),
      fsrsState: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fsrs_state'],
      ),
      lapses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lapses'],
      ),
      predictedDifficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}predicted_difficulty'],
      ),
      reviewCount:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}review_count'],
          )!,
      rubric: $DriftQuizItemsTable.$converterrubricn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}rubric'],
        ),
      ),
      hlc:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}hlc'],
          )!,
      isDeleted:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_deleted'],
          )!,
    );
  }

  @override
  $DriftQuizItemsTable createAlias(String alias) {
    return $DriftQuizItemsTable(attachedDatabase, alias);
  }

  static TypeConverter<IList<String>, String> $converterrubric =
      const IListStringConverter();
  static TypeConverter<IList<String>?, String?> $converterrubricn =
      NullAwareTypeConverter.wrap($converterrubric);
}

class DriftQuizItem extends DataClass implements Insertable<DriftQuizItem> {
  final String id;
  final String conceptId;
  final String question;
  final String answer;
  final int interval;
  final String nextReview;
  final String? lastReview;
  final double? difficulty;
  final double? stability;
  final int? fsrsState;
  final int? lapses;
  final double? predictedDifficulty;
  final int reviewCount;
  final IList<String>? rubric;
  final String hlc;
  final bool isDeleted;
  const DriftQuizItem({
    required this.id,
    required this.conceptId,
    required this.question,
    required this.answer,
    required this.interval,
    required this.nextReview,
    this.lastReview,
    this.difficulty,
    this.stability,
    this.fsrsState,
    this.lapses,
    this.predictedDifficulty,
    required this.reviewCount,
    this.rubric,
    required this.hlc,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['concept_id'] = Variable<String>(conceptId);
    map['question'] = Variable<String>(question);
    map['answer'] = Variable<String>(answer);
    map['interval'] = Variable<int>(interval);
    map['next_review'] = Variable<String>(nextReview);
    if (!nullToAbsent || lastReview != null) {
      map['last_review'] = Variable<String>(lastReview);
    }
    if (!nullToAbsent || difficulty != null) {
      map['difficulty'] = Variable<double>(difficulty);
    }
    if (!nullToAbsent || stability != null) {
      map['stability'] = Variable<double>(stability);
    }
    if (!nullToAbsent || fsrsState != null) {
      map['fsrs_state'] = Variable<int>(fsrsState);
    }
    if (!nullToAbsent || lapses != null) {
      map['lapses'] = Variable<int>(lapses);
    }
    if (!nullToAbsent || predictedDifficulty != null) {
      map['predicted_difficulty'] = Variable<double>(predictedDifficulty);
    }
    map['review_count'] = Variable<int>(reviewCount);
    if (!nullToAbsent || rubric != null) {
      map['rubric'] = Variable<String>(
        $DriftQuizItemsTable.$converterrubricn.toSql(rubric),
      );
    }
    map['hlc'] = Variable<String>(hlc);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  DriftQuizItemsCompanion toCompanion(bool nullToAbsent) {
    return DriftQuizItemsCompanion(
      id: Value(id),
      conceptId: Value(conceptId),
      question: Value(question),
      answer: Value(answer),
      interval: Value(interval),
      nextReview: Value(nextReview),
      lastReview:
          lastReview == null && nullToAbsent
              ? const Value.absent()
              : Value(lastReview),
      difficulty:
          difficulty == null && nullToAbsent
              ? const Value.absent()
              : Value(difficulty),
      stability:
          stability == null && nullToAbsent
              ? const Value.absent()
              : Value(stability),
      fsrsState:
          fsrsState == null && nullToAbsent
              ? const Value.absent()
              : Value(fsrsState),
      lapses:
          lapses == null && nullToAbsent ? const Value.absent() : Value(lapses),
      predictedDifficulty:
          predictedDifficulty == null && nullToAbsent
              ? const Value.absent()
              : Value(predictedDifficulty),
      reviewCount: Value(reviewCount),
      rubric:
          rubric == null && nullToAbsent ? const Value.absent() : Value(rubric),
      hlc: Value(hlc),
      isDeleted: Value(isDeleted),
    );
  }

  factory DriftQuizItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftQuizItem(
      id: serializer.fromJson<String>(json['id']),
      conceptId: serializer.fromJson<String>(json['conceptId']),
      question: serializer.fromJson<String>(json['question']),
      answer: serializer.fromJson<String>(json['answer']),
      interval: serializer.fromJson<int>(json['interval']),
      nextReview: serializer.fromJson<String>(json['nextReview']),
      lastReview: serializer.fromJson<String?>(json['lastReview']),
      difficulty: serializer.fromJson<double?>(json['difficulty']),
      stability: serializer.fromJson<double?>(json['stability']),
      fsrsState: serializer.fromJson<int?>(json['fsrsState']),
      lapses: serializer.fromJson<int?>(json['lapses']),
      predictedDifficulty: serializer.fromJson<double?>(
        json['predictedDifficulty'],
      ),
      reviewCount: serializer.fromJson<int>(json['reviewCount']),
      rubric: serializer.fromJson<IList<String>?>(json['rubric']),
      hlc: serializer.fromJson<String>(json['hlc']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conceptId': serializer.toJson<String>(conceptId),
      'question': serializer.toJson<String>(question),
      'answer': serializer.toJson<String>(answer),
      'interval': serializer.toJson<int>(interval),
      'nextReview': serializer.toJson<String>(nextReview),
      'lastReview': serializer.toJson<String?>(lastReview),
      'difficulty': serializer.toJson<double?>(difficulty),
      'stability': serializer.toJson<double?>(stability),
      'fsrsState': serializer.toJson<int?>(fsrsState),
      'lapses': serializer.toJson<int?>(lapses),
      'predictedDifficulty': serializer.toJson<double?>(predictedDifficulty),
      'reviewCount': serializer.toJson<int>(reviewCount),
      'rubric': serializer.toJson<IList<String>?>(rubric),
      'hlc': serializer.toJson<String>(hlc),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  DriftQuizItem copyWith({
    String? id,
    String? conceptId,
    String? question,
    String? answer,
    int? interval,
    String? nextReview,
    Value<String?> lastReview = const Value.absent(),
    Value<double?> difficulty = const Value.absent(),
    Value<double?> stability = const Value.absent(),
    Value<int?> fsrsState = const Value.absent(),
    Value<int?> lapses = const Value.absent(),
    Value<double?> predictedDifficulty = const Value.absent(),
    int? reviewCount,
    Value<IList<String>?> rubric = const Value.absent(),
    String? hlc,
    bool? isDeleted,
  }) => DriftQuizItem(
    id: id ?? this.id,
    conceptId: conceptId ?? this.conceptId,
    question: question ?? this.question,
    answer: answer ?? this.answer,
    interval: interval ?? this.interval,
    nextReview: nextReview ?? this.nextReview,
    lastReview: lastReview.present ? lastReview.value : this.lastReview,
    difficulty: difficulty.present ? difficulty.value : this.difficulty,
    stability: stability.present ? stability.value : this.stability,
    fsrsState: fsrsState.present ? fsrsState.value : this.fsrsState,
    lapses: lapses.present ? lapses.value : this.lapses,
    predictedDifficulty:
        predictedDifficulty.present
            ? predictedDifficulty.value
            : this.predictedDifficulty,
    reviewCount: reviewCount ?? this.reviewCount,
    rubric: rubric.present ? rubric.value : this.rubric,
    hlc: hlc ?? this.hlc,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  DriftQuizItem copyWithCompanion(DriftQuizItemsCompanion data) {
    return DriftQuizItem(
      id: data.id.present ? data.id.value : this.id,
      conceptId: data.conceptId.present ? data.conceptId.value : this.conceptId,
      question: data.question.present ? data.question.value : this.question,
      answer: data.answer.present ? data.answer.value : this.answer,
      interval: data.interval.present ? data.interval.value : this.interval,
      nextReview:
          data.nextReview.present ? data.nextReview.value : this.nextReview,
      lastReview:
          data.lastReview.present ? data.lastReview.value : this.lastReview,
      difficulty:
          data.difficulty.present ? data.difficulty.value : this.difficulty,
      stability: data.stability.present ? data.stability.value : this.stability,
      fsrsState: data.fsrsState.present ? data.fsrsState.value : this.fsrsState,
      lapses: data.lapses.present ? data.lapses.value : this.lapses,
      predictedDifficulty:
          data.predictedDifficulty.present
              ? data.predictedDifficulty.value
              : this.predictedDifficulty,
      reviewCount:
          data.reviewCount.present ? data.reviewCount.value : this.reviewCount,
      rubric: data.rubric.present ? data.rubric.value : this.rubric,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriftQuizItem(')
          ..write('id: $id, ')
          ..write('conceptId: $conceptId, ')
          ..write('question: $question, ')
          ..write('answer: $answer, ')
          ..write('interval: $interval, ')
          ..write('nextReview: $nextReview, ')
          ..write('lastReview: $lastReview, ')
          ..write('difficulty: $difficulty, ')
          ..write('stability: $stability, ')
          ..write('fsrsState: $fsrsState, ')
          ..write('lapses: $lapses, ')
          ..write('predictedDifficulty: $predictedDifficulty, ')
          ..write('reviewCount: $reviewCount, ')
          ..write('rubric: $rubric, ')
          ..write('hlc: $hlc, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conceptId,
    question,
    answer,
    interval,
    nextReview,
    lastReview,
    difficulty,
    stability,
    fsrsState,
    lapses,
    predictedDifficulty,
    reviewCount,
    rubric,
    hlc,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftQuizItem &&
          other.id == this.id &&
          other.conceptId == this.conceptId &&
          other.question == this.question &&
          other.answer == this.answer &&
          other.interval == this.interval &&
          other.nextReview == this.nextReview &&
          other.lastReview == this.lastReview &&
          other.difficulty == this.difficulty &&
          other.stability == this.stability &&
          other.fsrsState == this.fsrsState &&
          other.lapses == this.lapses &&
          other.predictedDifficulty == this.predictedDifficulty &&
          other.reviewCount == this.reviewCount &&
          other.rubric == this.rubric &&
          other.hlc == this.hlc &&
          other.isDeleted == this.isDeleted);
}

class DriftQuizItemsCompanion extends UpdateCompanion<DriftQuizItem> {
  final Value<String> id;
  final Value<String> conceptId;
  final Value<String> question;
  final Value<String> answer;
  final Value<int> interval;
  final Value<String> nextReview;
  final Value<String?> lastReview;
  final Value<double?> difficulty;
  final Value<double?> stability;
  final Value<int?> fsrsState;
  final Value<int?> lapses;
  final Value<double?> predictedDifficulty;
  final Value<int> reviewCount;
  final Value<IList<String>?> rubric;
  final Value<String> hlc;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const DriftQuizItemsCompanion({
    this.id = const Value.absent(),
    this.conceptId = const Value.absent(),
    this.question = const Value.absent(),
    this.answer = const Value.absent(),
    this.interval = const Value.absent(),
    this.nextReview = const Value.absent(),
    this.lastReview = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.stability = const Value.absent(),
    this.fsrsState = const Value.absent(),
    this.lapses = const Value.absent(),
    this.predictedDifficulty = const Value.absent(),
    this.reviewCount = const Value.absent(),
    this.rubric = const Value.absent(),
    this.hlc = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DriftQuizItemsCompanion.insert({
    required String id,
    required String conceptId,
    required String question,
    required String answer,
    required int interval,
    required String nextReview,
    this.lastReview = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.stability = const Value.absent(),
    this.fsrsState = const Value.absent(),
    this.lapses = const Value.absent(),
    this.predictedDifficulty = const Value.absent(),
    this.reviewCount = const Value.absent(),
    this.rubric = const Value.absent(),
    this.hlc = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conceptId = Value(conceptId),
       question = Value(question),
       answer = Value(answer),
       interval = Value(interval),
       nextReview = Value(nextReview);
  static Insertable<DriftQuizItem> custom({
    Expression<String>? id,
    Expression<String>? conceptId,
    Expression<String>? question,
    Expression<String>? answer,
    Expression<int>? interval,
    Expression<String>? nextReview,
    Expression<String>? lastReview,
    Expression<double>? difficulty,
    Expression<double>? stability,
    Expression<int>? fsrsState,
    Expression<int>? lapses,
    Expression<double>? predictedDifficulty,
    Expression<int>? reviewCount,
    Expression<String>? rubric,
    Expression<String>? hlc,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conceptId != null) 'concept_id': conceptId,
      if (question != null) 'question': question,
      if (answer != null) 'answer': answer,
      if (interval != null) 'interval': interval,
      if (nextReview != null) 'next_review': nextReview,
      if (lastReview != null) 'last_review': lastReview,
      if (difficulty != null) 'difficulty': difficulty,
      if (stability != null) 'stability': stability,
      if (fsrsState != null) 'fsrs_state': fsrsState,
      if (lapses != null) 'lapses': lapses,
      if (predictedDifficulty != null)
        'predicted_difficulty': predictedDifficulty,
      if (reviewCount != null) 'review_count': reviewCount,
      if (rubric != null) 'rubric': rubric,
      if (hlc != null) 'hlc': hlc,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DriftQuizItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? conceptId,
    Value<String>? question,
    Value<String>? answer,
    Value<int>? interval,
    Value<String>? nextReview,
    Value<String?>? lastReview,
    Value<double?>? difficulty,
    Value<double?>? stability,
    Value<int?>? fsrsState,
    Value<int?>? lapses,
    Value<double?>? predictedDifficulty,
    Value<int>? reviewCount,
    Value<IList<String>?>? rubric,
    Value<String>? hlc,
    Value<bool>? isDeleted,
    Value<int>? rowid,
  }) {
    return DriftQuizItemsCompanion(
      id: id ?? this.id,
      conceptId: conceptId ?? this.conceptId,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      interval: interval ?? this.interval,
      nextReview: nextReview ?? this.nextReview,
      lastReview: lastReview ?? this.lastReview,
      difficulty: difficulty ?? this.difficulty,
      stability: stability ?? this.stability,
      fsrsState: fsrsState ?? this.fsrsState,
      lapses: lapses ?? this.lapses,
      predictedDifficulty: predictedDifficulty ?? this.predictedDifficulty,
      reviewCount: reviewCount ?? this.reviewCount,
      rubric: rubric ?? this.rubric,
      hlc: hlc ?? this.hlc,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conceptId.present) {
      map['concept_id'] = Variable<String>(conceptId.value);
    }
    if (question.present) {
      map['question'] = Variable<String>(question.value);
    }
    if (answer.present) {
      map['answer'] = Variable<String>(answer.value);
    }
    if (interval.present) {
      map['interval'] = Variable<int>(interval.value);
    }
    if (nextReview.present) {
      map['next_review'] = Variable<String>(nextReview.value);
    }
    if (lastReview.present) {
      map['last_review'] = Variable<String>(lastReview.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<double>(difficulty.value);
    }
    if (stability.present) {
      map['stability'] = Variable<double>(stability.value);
    }
    if (fsrsState.present) {
      map['fsrs_state'] = Variable<int>(fsrsState.value);
    }
    if (lapses.present) {
      map['lapses'] = Variable<int>(lapses.value);
    }
    if (predictedDifficulty.present) {
      map['predicted_difficulty'] = Variable<double>(predictedDifficulty.value);
    }
    if (reviewCount.present) {
      map['review_count'] = Variable<int>(reviewCount.value);
    }
    if (rubric.present) {
      map['rubric'] = Variable<String>(
        $DriftQuizItemsTable.$converterrubricn.toSql(rubric.value),
      );
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DriftQuizItemsCompanion(')
          ..write('id: $id, ')
          ..write('conceptId: $conceptId, ')
          ..write('question: $question, ')
          ..write('answer: $answer, ')
          ..write('interval: $interval, ')
          ..write('nextReview: $nextReview, ')
          ..write('lastReview: $lastReview, ')
          ..write('difficulty: $difficulty, ')
          ..write('stability: $stability, ')
          ..write('fsrsState: $fsrsState, ')
          ..write('lapses: $lapses, ')
          ..write('predictedDifficulty: $predictedDifficulty, ')
          ..write('reviewCount: $reviewCount, ')
          ..write('rubric: $rubric, ')
          ..write('hlc: $hlc, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DriftDocumentsTable extends DriftDocuments
    with TableInfo<$DriftDocumentsTable, DriftDocument> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DriftDocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ingestedAtMeta = const VerificationMeta(
    'ingestedAt',
  );
  @override
  late final GeneratedColumn<String> ingestedAt = GeneratedColumn<String>(
    'ingested_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _collectionIdMeta = const VerificationMeta(
    'collectionId',
  );
  @override
  late final GeneratedColumn<String> collectionId = GeneratedColumn<String>(
    'collection_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _collectionNameMeta = const VerificationMeta(
    'collectionName',
  );
  @override
  late final GeneratedColumn<String> collectionName = GeneratedColumn<String>(
    'collection_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ingestedTextMeta = const VerificationMeta(
    'ingestedText',
  );
  @override
  late final GeneratedColumn<String> ingestedText = GeneratedColumn<String>(
    'ingested_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    documentId,
    title,
    updatedAt,
    ingestedAt,
    collectionId,
    collectionName,
    ingestedText,
    hlc,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drift_documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<DriftDocument> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('ingested_at')) {
      context.handle(
        _ingestedAtMeta,
        ingestedAt.isAcceptableOrUnknown(data['ingested_at']!, _ingestedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_ingestedAtMeta);
    }
    if (data.containsKey('collection_id')) {
      context.handle(
        _collectionIdMeta,
        collectionId.isAcceptableOrUnknown(
          data['collection_id']!,
          _collectionIdMeta,
        ),
      );
    }
    if (data.containsKey('collection_name')) {
      context.handle(
        _collectionNameMeta,
        collectionName.isAcceptableOrUnknown(
          data['collection_name']!,
          _collectionNameMeta,
        ),
      );
    }
    if (data.containsKey('ingested_text')) {
      context.handle(
        _ingestedTextMeta,
        ingestedText.isAcceptableOrUnknown(
          data['ingested_text']!,
          _ingestedTextMeta,
        ),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {documentId};
  @override
  DriftDocument map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftDocument(
      documentId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}document_id'],
          )!,
      title:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}title'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}updated_at'],
          )!,
      ingestedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}ingested_at'],
          )!,
      collectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_id'],
      ),
      collectionName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_name'],
      ),
      ingestedText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ingested_text'],
      ),
      hlc:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}hlc'],
          )!,
      isDeleted:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_deleted'],
          )!,
    );
  }

  @override
  $DriftDocumentsTable createAlias(String alias) {
    return $DriftDocumentsTable(attachedDatabase, alias);
  }
}

class DriftDocument extends DataClass implements Insertable<DriftDocument> {
  final String documentId;
  final String title;
  final String updatedAt;
  final String ingestedAt;
  final String? collectionId;
  final String? collectionName;
  final String? ingestedText;
  final String hlc;
  final bool isDeleted;
  const DriftDocument({
    required this.documentId,
    required this.title,
    required this.updatedAt,
    required this.ingestedAt,
    this.collectionId,
    this.collectionName,
    this.ingestedText,
    required this.hlc,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['document_id'] = Variable<String>(documentId);
    map['title'] = Variable<String>(title);
    map['updated_at'] = Variable<String>(updatedAt);
    map['ingested_at'] = Variable<String>(ingestedAt);
    if (!nullToAbsent || collectionId != null) {
      map['collection_id'] = Variable<String>(collectionId);
    }
    if (!nullToAbsent || collectionName != null) {
      map['collection_name'] = Variable<String>(collectionName);
    }
    if (!nullToAbsent || ingestedText != null) {
      map['ingested_text'] = Variable<String>(ingestedText);
    }
    map['hlc'] = Variable<String>(hlc);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  DriftDocumentsCompanion toCompanion(bool nullToAbsent) {
    return DriftDocumentsCompanion(
      documentId: Value(documentId),
      title: Value(title),
      updatedAt: Value(updatedAt),
      ingestedAt: Value(ingestedAt),
      collectionId:
          collectionId == null && nullToAbsent
              ? const Value.absent()
              : Value(collectionId),
      collectionName:
          collectionName == null && nullToAbsent
              ? const Value.absent()
              : Value(collectionName),
      ingestedText:
          ingestedText == null && nullToAbsent
              ? const Value.absent()
              : Value(ingestedText),
      hlc: Value(hlc),
      isDeleted: Value(isDeleted),
    );
  }

  factory DriftDocument.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftDocument(
      documentId: serializer.fromJson<String>(json['documentId']),
      title: serializer.fromJson<String>(json['title']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      ingestedAt: serializer.fromJson<String>(json['ingestedAt']),
      collectionId: serializer.fromJson<String?>(json['collectionId']),
      collectionName: serializer.fromJson<String?>(json['collectionName']),
      ingestedText: serializer.fromJson<String?>(json['ingestedText']),
      hlc: serializer.fromJson<String>(json['hlc']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'documentId': serializer.toJson<String>(documentId),
      'title': serializer.toJson<String>(title),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'ingestedAt': serializer.toJson<String>(ingestedAt),
      'collectionId': serializer.toJson<String?>(collectionId),
      'collectionName': serializer.toJson<String?>(collectionName),
      'ingestedText': serializer.toJson<String?>(ingestedText),
      'hlc': serializer.toJson<String>(hlc),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  DriftDocument copyWith({
    String? documentId,
    String? title,
    String? updatedAt,
    String? ingestedAt,
    Value<String?> collectionId = const Value.absent(),
    Value<String?> collectionName = const Value.absent(),
    Value<String?> ingestedText = const Value.absent(),
    String? hlc,
    bool? isDeleted,
  }) => DriftDocument(
    documentId: documentId ?? this.documentId,
    title: title ?? this.title,
    updatedAt: updatedAt ?? this.updatedAt,
    ingestedAt: ingestedAt ?? this.ingestedAt,
    collectionId: collectionId.present ? collectionId.value : this.collectionId,
    collectionName:
        collectionName.present ? collectionName.value : this.collectionName,
    ingestedText: ingestedText.present ? ingestedText.value : this.ingestedText,
    hlc: hlc ?? this.hlc,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  DriftDocument copyWithCompanion(DriftDocumentsCompanion data) {
    return DriftDocument(
      documentId:
          data.documentId.present ? data.documentId.value : this.documentId,
      title: data.title.present ? data.title.value : this.title,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      ingestedAt:
          data.ingestedAt.present ? data.ingestedAt.value : this.ingestedAt,
      collectionId:
          data.collectionId.present
              ? data.collectionId.value
              : this.collectionId,
      collectionName:
          data.collectionName.present
              ? data.collectionName.value
              : this.collectionName,
      ingestedText:
          data.ingestedText.present
              ? data.ingestedText.value
              : this.ingestedText,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriftDocument(')
          ..write('documentId: $documentId, ')
          ..write('title: $title, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('ingestedAt: $ingestedAt, ')
          ..write('collectionId: $collectionId, ')
          ..write('collectionName: $collectionName, ')
          ..write('ingestedText: $ingestedText, ')
          ..write('hlc: $hlc, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    documentId,
    title,
    updatedAt,
    ingestedAt,
    collectionId,
    collectionName,
    ingestedText,
    hlc,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftDocument &&
          other.documentId == this.documentId &&
          other.title == this.title &&
          other.updatedAt == this.updatedAt &&
          other.ingestedAt == this.ingestedAt &&
          other.collectionId == this.collectionId &&
          other.collectionName == this.collectionName &&
          other.ingestedText == this.ingestedText &&
          other.hlc == this.hlc &&
          other.isDeleted == this.isDeleted);
}

class DriftDocumentsCompanion extends UpdateCompanion<DriftDocument> {
  final Value<String> documentId;
  final Value<String> title;
  final Value<String> updatedAt;
  final Value<String> ingestedAt;
  final Value<String?> collectionId;
  final Value<String?> collectionName;
  final Value<String?> ingestedText;
  final Value<String> hlc;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const DriftDocumentsCompanion({
    this.documentId = const Value.absent(),
    this.title = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.ingestedAt = const Value.absent(),
    this.collectionId = const Value.absent(),
    this.collectionName = const Value.absent(),
    this.ingestedText = const Value.absent(),
    this.hlc = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DriftDocumentsCompanion.insert({
    required String documentId,
    required String title,
    required String updatedAt,
    required String ingestedAt,
    this.collectionId = const Value.absent(),
    this.collectionName = const Value.absent(),
    this.ingestedText = const Value.absent(),
    this.hlc = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : documentId = Value(documentId),
       title = Value(title),
       updatedAt = Value(updatedAt),
       ingestedAt = Value(ingestedAt);
  static Insertable<DriftDocument> custom({
    Expression<String>? documentId,
    Expression<String>? title,
    Expression<String>? updatedAt,
    Expression<String>? ingestedAt,
    Expression<String>? collectionId,
    Expression<String>? collectionName,
    Expression<String>? ingestedText,
    Expression<String>? hlc,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (documentId != null) 'document_id': documentId,
      if (title != null) 'title': title,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (ingestedAt != null) 'ingested_at': ingestedAt,
      if (collectionId != null) 'collection_id': collectionId,
      if (collectionName != null) 'collection_name': collectionName,
      if (ingestedText != null) 'ingested_text': ingestedText,
      if (hlc != null) 'hlc': hlc,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DriftDocumentsCompanion copyWith({
    Value<String>? documentId,
    Value<String>? title,
    Value<String>? updatedAt,
    Value<String>? ingestedAt,
    Value<String?>? collectionId,
    Value<String?>? collectionName,
    Value<String?>? ingestedText,
    Value<String>? hlc,
    Value<bool>? isDeleted,
    Value<int>? rowid,
  }) {
    return DriftDocumentsCompanion(
      documentId: documentId ?? this.documentId,
      title: title ?? this.title,
      updatedAt: updatedAt ?? this.updatedAt,
      ingestedAt: ingestedAt ?? this.ingestedAt,
      collectionId: collectionId ?? this.collectionId,
      collectionName: collectionName ?? this.collectionName,
      ingestedText: ingestedText ?? this.ingestedText,
      hlc: hlc ?? this.hlc,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (ingestedAt.present) {
      map['ingested_at'] = Variable<String>(ingestedAt.value);
    }
    if (collectionId.present) {
      map['collection_id'] = Variable<String>(collectionId.value);
    }
    if (collectionName.present) {
      map['collection_name'] = Variable<String>(collectionName.value);
    }
    if (ingestedText.present) {
      map['ingested_text'] = Variable<String>(ingestedText.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DriftDocumentsCompanion(')
          ..write('documentId: $documentId, ')
          ..write('title: $title, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('ingestedAt: $ingestedAt, ')
          ..write('collectionId: $collectionId, ')
          ..write('collectionName: $collectionName, ')
          ..write('ingestedText: $ingestedText, ')
          ..write('hlc: $hlc, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DriftTopicsTable extends DriftTopics
    with TableInfo<$DriftTopicsTable, DriftTopic> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DriftTopicsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _lastIngestedAtMeta = const VerificationMeta(
    'lastIngestedAt',
  );
  @override
  late final GeneratedColumn<String> lastIngestedAt = GeneratedColumn<String>(
    'last_ingested_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    createdAt,
    lastIngestedAt,
    hlc,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drift_topics';
  @override
  VerificationContext validateIntegrity(
    Insertable<DriftTopic> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
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
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_ingested_at')) {
      context.handle(
        _lastIngestedAtMeta,
        lastIngestedAt.isAcceptableOrUnknown(
          data['last_ingested_at']!,
          _lastIngestedAtMeta,
        ),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DriftTopic map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftTopic(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}created_at'],
          )!,
      lastIngestedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_ingested_at'],
      ),
      hlc:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}hlc'],
          )!,
      isDeleted:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_deleted'],
          )!,
    );
  }

  @override
  $DriftTopicsTable createAlias(String alias) {
    return $DriftTopicsTable(attachedDatabase, alias);
  }
}

class DriftTopic extends DataClass implements Insertable<DriftTopic> {
  final String id;
  final String name;
  final String? description;
  final String createdAt;
  final String? lastIngestedAt;
  final String hlc;
  final bool isDeleted;
  const DriftTopic({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    this.lastIngestedAt,
    required this.hlc,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['created_at'] = Variable<String>(createdAt);
    if (!nullToAbsent || lastIngestedAt != null) {
      map['last_ingested_at'] = Variable<String>(lastIngestedAt);
    }
    map['hlc'] = Variable<String>(hlc);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  DriftTopicsCompanion toCompanion(bool nullToAbsent) {
    return DriftTopicsCompanion(
      id: Value(id),
      name: Value(name),
      description:
          description == null && nullToAbsent
              ? const Value.absent()
              : Value(description),
      createdAt: Value(createdAt),
      lastIngestedAt:
          lastIngestedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(lastIngestedAt),
      hlc: Value(hlc),
      isDeleted: Value(isDeleted),
    );
  }

  factory DriftTopic.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftTopic(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      lastIngestedAt: serializer.fromJson<String?>(json['lastIngestedAt']),
      hlc: serializer.fromJson<String>(json['hlc']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'createdAt': serializer.toJson<String>(createdAt),
      'lastIngestedAt': serializer.toJson<String?>(lastIngestedAt),
      'hlc': serializer.toJson<String>(hlc),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  DriftTopic copyWith({
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    String? createdAt,
    Value<String?> lastIngestedAt = const Value.absent(),
    String? hlc,
    bool? isDeleted,
  }) => DriftTopic(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    createdAt: createdAt ?? this.createdAt,
    lastIngestedAt:
        lastIngestedAt.present ? lastIngestedAt.value : this.lastIngestedAt,
    hlc: hlc ?? this.hlc,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  DriftTopic copyWithCompanion(DriftTopicsCompanion data) {
    return DriftTopic(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastIngestedAt:
          data.lastIngestedAt.present
              ? data.lastIngestedAt.value
              : this.lastIngestedAt,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriftTopic(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastIngestedAt: $lastIngestedAt, ')
          ..write('hlc: $hlc, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    createdAt,
    lastIngestedAt,
    hlc,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftTopic &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.createdAt == this.createdAt &&
          other.lastIngestedAt == this.lastIngestedAt &&
          other.hlc == this.hlc &&
          other.isDeleted == this.isDeleted);
}

class DriftTopicsCompanion extends UpdateCompanion<DriftTopic> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String> createdAt;
  final Value<String?> lastIngestedAt;
  final Value<String> hlc;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const DriftTopicsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastIngestedAt = const Value.absent(),
    this.hlc = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DriftTopicsCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    required String createdAt,
    this.lastIngestedAt = const Value.absent(),
    this.hlc = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<DriftTopic> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? createdAt,
    Expression<String>? lastIngestedAt,
    Expression<String>? hlc,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
      if (lastIngestedAt != null) 'last_ingested_at': lastIngestedAt,
      if (hlc != null) 'hlc': hlc,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DriftTopicsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<String>? createdAt,
    Value<String?>? lastIngestedAt,
    Value<String>? hlc,
    Value<bool>? isDeleted,
    Value<int>? rowid,
  }) {
    return DriftTopicsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      lastIngestedAt: lastIngestedAt ?? this.lastIngestedAt,
      hlc: hlc ?? this.hlc,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (lastIngestedAt.present) {
      map['last_ingested_at'] = Variable<String>(lastIngestedAt.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DriftTopicsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastIngestedAt: $lastIngestedAt, ')
          ..write('hlc: $hlc, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DriftTopicDocumentsTable extends DriftTopicDocuments
    with TableInfo<$DriftTopicDocumentsTable, DriftTopicDocument> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DriftTopicDocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _topicIdMeta = const VerificationMeta(
    'topicId',
  );
  @override
  late final GeneratedColumn<String> topicId = GeneratedColumn<String>(
    'topic_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [topicId, documentId, hlc, isDeleted];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drift_topic_documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<DriftTopicDocument> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('topic_id')) {
      context.handle(
        _topicIdMeta,
        topicId.isAcceptableOrUnknown(data['topic_id']!, _topicIdMeta),
      );
    } else if (isInserting) {
      context.missing(_topicIdMeta);
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {topicId, documentId};
  @override
  DriftTopicDocument map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftTopicDocument(
      topicId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}topic_id'],
          )!,
      documentId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}document_id'],
          )!,
      hlc:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}hlc'],
          )!,
      isDeleted:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_deleted'],
          )!,
    );
  }

  @override
  $DriftTopicDocumentsTable createAlias(String alias) {
    return $DriftTopicDocumentsTable(attachedDatabase, alias);
  }
}

class DriftTopicDocument extends DataClass
    implements Insertable<DriftTopicDocument> {
  final String topicId;
  final String documentId;
  final String hlc;
  final bool isDeleted;
  const DriftTopicDocument({
    required this.topicId,
    required this.documentId,
    required this.hlc,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['topic_id'] = Variable<String>(topicId);
    map['document_id'] = Variable<String>(documentId);
    map['hlc'] = Variable<String>(hlc);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  DriftTopicDocumentsCompanion toCompanion(bool nullToAbsent) {
    return DriftTopicDocumentsCompanion(
      topicId: Value(topicId),
      documentId: Value(documentId),
      hlc: Value(hlc),
      isDeleted: Value(isDeleted),
    );
  }

  factory DriftTopicDocument.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftTopicDocument(
      topicId: serializer.fromJson<String>(json['topicId']),
      documentId: serializer.fromJson<String>(json['documentId']),
      hlc: serializer.fromJson<String>(json['hlc']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'topicId': serializer.toJson<String>(topicId),
      'documentId': serializer.toJson<String>(documentId),
      'hlc': serializer.toJson<String>(hlc),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  DriftTopicDocument copyWith({
    String? topicId,
    String? documentId,
    String? hlc,
    bool? isDeleted,
  }) => DriftTopicDocument(
    topicId: topicId ?? this.topicId,
    documentId: documentId ?? this.documentId,
    hlc: hlc ?? this.hlc,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  DriftTopicDocument copyWithCompanion(DriftTopicDocumentsCompanion data) {
    return DriftTopicDocument(
      topicId: data.topicId.present ? data.topicId.value : this.topicId,
      documentId:
          data.documentId.present ? data.documentId.value : this.documentId,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriftTopicDocument(')
          ..write('topicId: $topicId, ')
          ..write('documentId: $documentId, ')
          ..write('hlc: $hlc, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(topicId, documentId, hlc, isDeleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftTopicDocument &&
          other.topicId == this.topicId &&
          other.documentId == this.documentId &&
          other.hlc == this.hlc &&
          other.isDeleted == this.isDeleted);
}

class DriftTopicDocumentsCompanion extends UpdateCompanion<DriftTopicDocument> {
  final Value<String> topicId;
  final Value<String> documentId;
  final Value<String> hlc;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const DriftTopicDocumentsCompanion({
    this.topicId = const Value.absent(),
    this.documentId = const Value.absent(),
    this.hlc = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DriftTopicDocumentsCompanion.insert({
    required String topicId,
    required String documentId,
    this.hlc = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : topicId = Value(topicId),
       documentId = Value(documentId);
  static Insertable<DriftTopicDocument> custom({
    Expression<String>? topicId,
    Expression<String>? documentId,
    Expression<String>? hlc,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (topicId != null) 'topic_id': topicId,
      if (documentId != null) 'document_id': documentId,
      if (hlc != null) 'hlc': hlc,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DriftTopicDocumentsCompanion copyWith({
    Value<String>? topicId,
    Value<String>? documentId,
    Value<String>? hlc,
    Value<bool>? isDeleted,
    Value<int>? rowid,
  }) {
    return DriftTopicDocumentsCompanion(
      topicId: topicId ?? this.topicId,
      documentId: documentId ?? this.documentId,
      hlc: hlc ?? this.hlc,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (topicId.present) {
      map['topic_id'] = Variable<String>(topicId.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DriftTopicDocumentsCompanion(')
          ..write('topicId: $topicId, ')
          ..write('documentId: $documentId, ')
          ..write('hlc: $hlc, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DriftSyncMetadataTable extends DriftSyncMetadata
    with TableInfo<$DriftSyncMetadataTable, DriftSyncMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DriftSyncMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _peerIdMeta = const VerificationMeta('peerId');
  @override
  late final GeneratedColumn<String> peerId = GeneratedColumn<String>(
    'peer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncedHlcMeta = const VerificationMeta(
    'lastSyncedHlc',
  );
  @override
  late final GeneratedColumn<String> lastSyncedHlc = GeneratedColumn<String>(
    'last_synced_hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [peerId, lastSyncedHlc, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drift_sync_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<DriftSyncMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('peer_id')) {
      context.handle(
        _peerIdMeta,
        peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_peerIdMeta);
    }
    if (data.containsKey('last_synced_hlc')) {
      context.handle(
        _lastSyncedHlcMeta,
        lastSyncedHlc.isAcceptableOrUnknown(
          data['last_synced_hlc']!,
          _lastSyncedHlcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSyncedHlcMeta);
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
  Set<GeneratedColumn> get $primaryKey => {peerId};
  @override
  DriftSyncMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftSyncMetadataData(
      peerId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}peer_id'],
          )!,
      lastSyncedHlc:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}last_synced_hlc'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $DriftSyncMetadataTable createAlias(String alias) {
    return $DriftSyncMetadataTable(attachedDatabase, alias);
  }
}

class DriftSyncMetadataData extends DataClass
    implements Insertable<DriftSyncMetadataData> {
  final String peerId;
  final String lastSyncedHlc;
  final String updatedAt;
  const DriftSyncMetadataData({
    required this.peerId,
    required this.lastSyncedHlc,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['peer_id'] = Variable<String>(peerId);
    map['last_synced_hlc'] = Variable<String>(lastSyncedHlc);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  DriftSyncMetadataCompanion toCompanion(bool nullToAbsent) {
    return DriftSyncMetadataCompanion(
      peerId: Value(peerId),
      lastSyncedHlc: Value(lastSyncedHlc),
      updatedAt: Value(updatedAt),
    );
  }

  factory DriftSyncMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftSyncMetadataData(
      peerId: serializer.fromJson<String>(json['peerId']),
      lastSyncedHlc: serializer.fromJson<String>(json['lastSyncedHlc']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'peerId': serializer.toJson<String>(peerId),
      'lastSyncedHlc': serializer.toJson<String>(lastSyncedHlc),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  DriftSyncMetadataData copyWith({
    String? peerId,
    String? lastSyncedHlc,
    String? updatedAt,
  }) => DriftSyncMetadataData(
    peerId: peerId ?? this.peerId,
    lastSyncedHlc: lastSyncedHlc ?? this.lastSyncedHlc,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DriftSyncMetadataData copyWithCompanion(DriftSyncMetadataCompanion data) {
    return DriftSyncMetadataData(
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      lastSyncedHlc:
          data.lastSyncedHlc.present
              ? data.lastSyncedHlc.value
              : this.lastSyncedHlc,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriftSyncMetadataData(')
          ..write('peerId: $peerId, ')
          ..write('lastSyncedHlc: $lastSyncedHlc, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(peerId, lastSyncedHlc, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftSyncMetadataData &&
          other.peerId == this.peerId &&
          other.lastSyncedHlc == this.lastSyncedHlc &&
          other.updatedAt == this.updatedAt);
}

class DriftSyncMetadataCompanion
    extends UpdateCompanion<DriftSyncMetadataData> {
  final Value<String> peerId;
  final Value<String> lastSyncedHlc;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const DriftSyncMetadataCompanion({
    this.peerId = const Value.absent(),
    this.lastSyncedHlc = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DriftSyncMetadataCompanion.insert({
    required String peerId,
    required String lastSyncedHlc,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : peerId = Value(peerId),
       lastSyncedHlc = Value(lastSyncedHlc),
       updatedAt = Value(updatedAt);
  static Insertable<DriftSyncMetadataData> custom({
    Expression<String>? peerId,
    Expression<String>? lastSyncedHlc,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (peerId != null) 'peer_id': peerId,
      if (lastSyncedHlc != null) 'last_synced_hlc': lastSyncedHlc,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DriftSyncMetadataCompanion copyWith({
    Value<String>? peerId,
    Value<String>? lastSyncedHlc,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return DriftSyncMetadataCompanion(
      peerId: peerId ?? this.peerId,
      lastSyncedHlc: lastSyncedHlc ?? this.lastSyncedHlc,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (lastSyncedHlc.present) {
      map['last_synced_hlc'] = Variable<String>(lastSyncedHlc.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DriftSyncMetadataCompanion(')
          ..write('peerId: $peerId, ')
          ..write('lastSyncedHlc: $lastSyncedHlc, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$EngramDatabase extends GeneratedDatabase {
  _$EngramDatabase(QueryExecutor e) : super(e);
  $EngramDatabaseManager get managers => $EngramDatabaseManager(this);
  late final $DriftConceptsTable driftConcepts = $DriftConceptsTable(this);
  late final $DriftRelationshipsTable driftRelationships =
      $DriftRelationshipsTable(this);
  late final $DriftQuizItemsTable driftQuizItems = $DriftQuizItemsTable(this);
  late final $DriftDocumentsTable driftDocuments = $DriftDocumentsTable(this);
  late final $DriftTopicsTable driftTopics = $DriftTopicsTable(this);
  late final $DriftTopicDocumentsTable driftTopicDocuments =
      $DriftTopicDocumentsTable(this);
  late final $DriftSyncMetadataTable driftSyncMetadata =
      $DriftSyncMetadataTable(this);
  late final Index idxConceptsSourceDocument = Index(
    'idx_concepts_source_document',
    'CREATE INDEX idx_concepts_source_document ON drift_concepts (source_document_id)',
  );
  late final Index idxDriftConceptsHlc = Index(
    'idx_drift_concepts_hlc',
    'CREATE INDEX idx_drift_concepts_hlc ON drift_concepts (hlc)',
  );
  late final Index idxRelationshipsFrom = Index(
    'idx_relationships_from',
    'CREATE INDEX idx_relationships_from ON drift_relationships (from_concept_id)',
  );
  late final Index idxRelationshipsTo = Index(
    'idx_relationships_to',
    'CREATE INDEX idx_relationships_to ON drift_relationships (to_concept_id)',
  );
  late final Index idxDriftRelationshipsHlc = Index(
    'idx_drift_relationships_hlc',
    'CREATE INDEX idx_drift_relationships_hlc ON drift_relationships (hlc)',
  );
  late final Index idxQuizItemsConcept = Index(
    'idx_quiz_items_concept',
    'CREATE INDEX idx_quiz_items_concept ON drift_quiz_items (concept_id)',
  );
  late final Index idxQuizItemsNextReview = Index(
    'idx_quiz_items_next_review',
    'CREATE INDEX idx_quiz_items_next_review ON drift_quiz_items (next_review)',
  );
  late final Index idxDriftQuizItemsHlc = Index(
    'idx_drift_quiz_items_hlc',
    'CREATE INDEX idx_drift_quiz_items_hlc ON drift_quiz_items (hlc)',
  );
  late final Index idxDriftDocumentsHlc = Index(
    'idx_drift_documents_hlc',
    'CREATE INDEX idx_drift_documents_hlc ON drift_documents (hlc)',
  );
  late final Index idxDriftTopicsHlc = Index(
    'idx_drift_topics_hlc',
    'CREATE INDEX idx_drift_topics_hlc ON drift_topics (hlc)',
  );
  late final Index idxDriftTopicDocumentsHlc = Index(
    'idx_drift_topic_documents_hlc',
    'CREATE INDEX idx_drift_topic_documents_hlc ON drift_topic_documents (hlc)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    driftConcepts,
    driftRelationships,
    driftQuizItems,
    driftDocuments,
    driftTopics,
    driftTopicDocuments,
    driftSyncMetadata,
    idxConceptsSourceDocument,
    idxDriftConceptsHlc,
    idxRelationshipsFrom,
    idxRelationshipsTo,
    idxDriftRelationshipsHlc,
    idxQuizItemsConcept,
    idxQuizItemsNextReview,
    idxDriftQuizItemsHlc,
    idxDriftDocumentsHlc,
    idxDriftTopicsHlc,
    idxDriftTopicDocumentsHlc,
  ];
}

typedef $$DriftConceptsTableCreateCompanionBuilder =
    DriftConceptsCompanion Function({
      required String id,
      required String name,
      required String description,
      required String sourceDocumentId,
      required IList<String> tags,
      Value<String?> parentConceptId,
      Value<Uint8List?> embedding,
      Value<String> hlc,
      Value<bool> isDeleted,
      Value<int> rowid,
    });
typedef $$DriftConceptsTableUpdateCompanionBuilder =
    DriftConceptsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> description,
      Value<String> sourceDocumentId,
      Value<IList<String>> tags,
      Value<String?> parentConceptId,
      Value<Uint8List?> embedding,
      Value<String> hlc,
      Value<bool> isDeleted,
      Value<int> rowid,
    });

class $$DriftConceptsTableFilterComposer
    extends Composer<_$EngramDatabase, $DriftConceptsTable> {
  $$DriftConceptsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceDocumentId => $composableBuilder(
    column: $table.sourceDocumentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<IList<String>, IList<String>, String>
  get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get parentConceptId => $composableBuilder(
    column: $table.parentConceptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DriftConceptsTableOrderingComposer
    extends Composer<_$EngramDatabase, $DriftConceptsTable> {
  $$DriftConceptsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceDocumentId => $composableBuilder(
    column: $table.sourceDocumentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentConceptId => $composableBuilder(
    column: $table.parentConceptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DriftConceptsTableAnnotationComposer
    extends Composer<_$EngramDatabase, $DriftConceptsTable> {
  $$DriftConceptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceDocumentId => $composableBuilder(
    column: $table.sourceDocumentId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<IList<String>, String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get parentConceptId => $composableBuilder(
    column: $table.parentConceptId,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get embedding =>
      $composableBuilder(column: $table.embedding, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);
}

class $$DriftConceptsTableTableManager
    extends
        RootTableManager<
          _$EngramDatabase,
          $DriftConceptsTable,
          DriftConcept,
          $$DriftConceptsTableFilterComposer,
          $$DriftConceptsTableOrderingComposer,
          $$DriftConceptsTableAnnotationComposer,
          $$DriftConceptsTableCreateCompanionBuilder,
          $$DriftConceptsTableUpdateCompanionBuilder,
          (
            DriftConcept,
            BaseReferences<_$EngramDatabase, $DriftConceptsTable, DriftConcept>,
          ),
          DriftConcept,
          PrefetchHooks Function()
        > {
  $$DriftConceptsTableTableManager(
    _$EngramDatabase db,
    $DriftConceptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$DriftConceptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$DriftConceptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$DriftConceptsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> sourceDocumentId = const Value.absent(),
                Value<IList<String>> tags = const Value.absent(),
                Value<String?> parentConceptId = const Value.absent(),
                Value<Uint8List?> embedding = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DriftConceptsCompanion(
                id: id,
                name: name,
                description: description,
                sourceDocumentId: sourceDocumentId,
                tags: tags,
                parentConceptId: parentConceptId,
                embedding: embedding,
                hlc: hlc,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String description,
                required String sourceDocumentId,
                required IList<String> tags,
                Value<String?> parentConceptId = const Value.absent(),
                Value<Uint8List?> embedding = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DriftConceptsCompanion.insert(
                id: id,
                name: name,
                description: description,
                sourceDocumentId: sourceDocumentId,
                tags: tags,
                parentConceptId: parentConceptId,
                embedding: embedding,
                hlc: hlc,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable<$DriftConceptsTable, DriftConcept>(table),
                          BaseReferences<
                            _$EngramDatabase,
                            $DriftConceptsTable,
                            DriftConcept
                          >(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DriftConceptsTableProcessedTableManager =
    ProcessedTableManager<
      _$EngramDatabase,
      $DriftConceptsTable,
      DriftConcept,
      $$DriftConceptsTableFilterComposer,
      $$DriftConceptsTableOrderingComposer,
      $$DriftConceptsTableAnnotationComposer,
      $$DriftConceptsTableCreateCompanionBuilder,
      $$DriftConceptsTableUpdateCompanionBuilder,
      (
        DriftConcept,
        BaseReferences<_$EngramDatabase, $DriftConceptsTable, DriftConcept>,
      ),
      DriftConcept,
      PrefetchHooks Function()
    >;
typedef $$DriftRelationshipsTableCreateCompanionBuilder =
    DriftRelationshipsCompanion Function({
      required String id,
      required String fromConceptId,
      required String toConceptId,
      required String label,
      Value<String?> description,
      required RelationshipType type,
      Value<String> hlc,
      Value<bool> isDeleted,
      Value<int> rowid,
    });
typedef $$DriftRelationshipsTableUpdateCompanionBuilder =
    DriftRelationshipsCompanion Function({
      Value<String> id,
      Value<String> fromConceptId,
      Value<String> toConceptId,
      Value<String> label,
      Value<String?> description,
      Value<RelationshipType> type,
      Value<String> hlc,
      Value<bool> isDeleted,
      Value<int> rowid,
    });

class $$DriftRelationshipsTableFilterComposer
    extends Composer<_$EngramDatabase, $DriftRelationshipsTable> {
  $$DriftRelationshipsTableFilterComposer({
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

  ColumnFilters<String> get fromConceptId => $composableBuilder(
    column: $table.fromConceptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toConceptId => $composableBuilder(
    column: $table.toConceptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<RelationshipType, RelationshipType, String>
  get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DriftRelationshipsTableOrderingComposer
    extends Composer<_$EngramDatabase, $DriftRelationshipsTable> {
  $$DriftRelationshipsTableOrderingComposer({
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

  ColumnOrderings<String> get fromConceptId => $composableBuilder(
    column: $table.fromConceptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toConceptId => $composableBuilder(
    column: $table.toConceptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DriftRelationshipsTableAnnotationComposer
    extends Composer<_$EngramDatabase, $DriftRelationshipsTable> {
  $$DriftRelationshipsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fromConceptId => $composableBuilder(
    column: $table.fromConceptId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toConceptId => $composableBuilder(
    column: $table.toConceptId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<RelationshipType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);
}

class $$DriftRelationshipsTableTableManager
    extends
        RootTableManager<
          _$EngramDatabase,
          $DriftRelationshipsTable,
          DriftRelationship,
          $$DriftRelationshipsTableFilterComposer,
          $$DriftRelationshipsTableOrderingComposer,
          $$DriftRelationshipsTableAnnotationComposer,
          $$DriftRelationshipsTableCreateCompanionBuilder,
          $$DriftRelationshipsTableUpdateCompanionBuilder,
          (
            DriftRelationship,
            BaseReferences<
              _$EngramDatabase,
              $DriftRelationshipsTable,
              DriftRelationship
            >,
          ),
          DriftRelationship,
          PrefetchHooks Function()
        > {
  $$DriftRelationshipsTableTableManager(
    _$EngramDatabase db,
    $DriftRelationshipsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$DriftRelationshipsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$DriftRelationshipsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$DriftRelationshipsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> fromConceptId = const Value.absent(),
                Value<String> toConceptId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<RelationshipType> type = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DriftRelationshipsCompanion(
                id: id,
                fromConceptId: fromConceptId,
                toConceptId: toConceptId,
                label: label,
                description: description,
                type: type,
                hlc: hlc,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String fromConceptId,
                required String toConceptId,
                required String label,
                Value<String?> description = const Value.absent(),
                required RelationshipType type,
                Value<String> hlc = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DriftRelationshipsCompanion.insert(
                id: id,
                fromConceptId: fromConceptId,
                toConceptId: toConceptId,
                label: label,
                description: description,
                type: type,
                hlc: hlc,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable<
                            $DriftRelationshipsTable,
                            DriftRelationship
                          >(table),
                          BaseReferences<
                            _$EngramDatabase,
                            $DriftRelationshipsTable,
                            DriftRelationship
                          >(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DriftRelationshipsTableProcessedTableManager =
    ProcessedTableManager<
      _$EngramDatabase,
      $DriftRelationshipsTable,
      DriftRelationship,
      $$DriftRelationshipsTableFilterComposer,
      $$DriftRelationshipsTableOrderingComposer,
      $$DriftRelationshipsTableAnnotationComposer,
      $$DriftRelationshipsTableCreateCompanionBuilder,
      $$DriftRelationshipsTableUpdateCompanionBuilder,
      (
        DriftRelationship,
        BaseReferences<
          _$EngramDatabase,
          $DriftRelationshipsTable,
          DriftRelationship
        >,
      ),
      DriftRelationship,
      PrefetchHooks Function()
    >;
typedef $$DriftQuizItemsTableCreateCompanionBuilder =
    DriftQuizItemsCompanion Function({
      required String id,
      required String conceptId,
      required String question,
      required String answer,
      required int interval,
      required String nextReview,
      Value<String?> lastReview,
      Value<double?> difficulty,
      Value<double?> stability,
      Value<int?> fsrsState,
      Value<int?> lapses,
      Value<double?> predictedDifficulty,
      Value<int> reviewCount,
      Value<IList<String>?> rubric,
      Value<String> hlc,
      Value<bool> isDeleted,
      Value<int> rowid,
    });
typedef $$DriftQuizItemsTableUpdateCompanionBuilder =
    DriftQuizItemsCompanion Function({
      Value<String> id,
      Value<String> conceptId,
      Value<String> question,
      Value<String> answer,
      Value<int> interval,
      Value<String> nextReview,
      Value<String?> lastReview,
      Value<double?> difficulty,
      Value<double?> stability,
      Value<int?> fsrsState,
      Value<int?> lapses,
      Value<double?> predictedDifficulty,
      Value<int> reviewCount,
      Value<IList<String>?> rubric,
      Value<String> hlc,
      Value<bool> isDeleted,
      Value<int> rowid,
    });

class $$DriftQuizItemsTableFilterComposer
    extends Composer<_$EngramDatabase, $DriftQuizItemsTable> {
  $$DriftQuizItemsTableFilterComposer({
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

  ColumnFilters<String> get conceptId => $composableBuilder(
    column: $table.conceptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get interval => $composableBuilder(
    column: $table.interval,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nextReview => $composableBuilder(
    column: $table.nextReview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastReview => $composableBuilder(
    column: $table.lastReview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stability => $composableBuilder(
    column: $table.stability,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fsrsState => $composableBuilder(
    column: $table.fsrsState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get predictedDifficulty => $composableBuilder(
    column: $table.predictedDifficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reviewCount => $composableBuilder(
    column: $table.reviewCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<IList<String>?, IList<String>, String>
  get rubric => $composableBuilder(
    column: $table.rubric,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DriftQuizItemsTableOrderingComposer
    extends Composer<_$EngramDatabase, $DriftQuizItemsTable> {
  $$DriftQuizItemsTableOrderingComposer({
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

  ColumnOrderings<String> get conceptId => $composableBuilder(
    column: $table.conceptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get interval => $composableBuilder(
    column: $table.interval,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nextReview => $composableBuilder(
    column: $table.nextReview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastReview => $composableBuilder(
    column: $table.lastReview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stability => $composableBuilder(
    column: $table.stability,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fsrsState => $composableBuilder(
    column: $table.fsrsState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get predictedDifficulty => $composableBuilder(
    column: $table.predictedDifficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reviewCount => $composableBuilder(
    column: $table.reviewCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rubric => $composableBuilder(
    column: $table.rubric,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DriftQuizItemsTableAnnotationComposer
    extends Composer<_$EngramDatabase, $DriftQuizItemsTable> {
  $$DriftQuizItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conceptId =>
      $composableBuilder(column: $table.conceptId, builder: (column) => column);

  GeneratedColumn<String> get question =>
      $composableBuilder(column: $table.question, builder: (column) => column);

  GeneratedColumn<String> get answer =>
      $composableBuilder(column: $table.answer, builder: (column) => column);

  GeneratedColumn<int> get interval =>
      $composableBuilder(column: $table.interval, builder: (column) => column);

  GeneratedColumn<String> get nextReview => $composableBuilder(
    column: $table.nextReview,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastReview => $composableBuilder(
    column: $table.lastReview,
    builder: (column) => column,
  );

  GeneratedColumn<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<double> get stability =>
      $composableBuilder(column: $table.stability, builder: (column) => column);

  GeneratedColumn<int> get fsrsState =>
      $composableBuilder(column: $table.fsrsState, builder: (column) => column);

  GeneratedColumn<int> get lapses =>
      $composableBuilder(column: $table.lapses, builder: (column) => column);

  GeneratedColumn<double> get predictedDifficulty => $composableBuilder(
    column: $table.predictedDifficulty,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reviewCount => $composableBuilder(
    column: $table.reviewCount,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<IList<String>?, String> get rubric =>
      $composableBuilder(column: $table.rubric, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);
}

class $$DriftQuizItemsTableTableManager
    extends
        RootTableManager<
          _$EngramDatabase,
          $DriftQuizItemsTable,
          DriftQuizItem,
          $$DriftQuizItemsTableFilterComposer,
          $$DriftQuizItemsTableOrderingComposer,
          $$DriftQuizItemsTableAnnotationComposer,
          $$DriftQuizItemsTableCreateCompanionBuilder,
          $$DriftQuizItemsTableUpdateCompanionBuilder,
          (
            DriftQuizItem,
            BaseReferences<
              _$EngramDatabase,
              $DriftQuizItemsTable,
              DriftQuizItem
            >,
          ),
          DriftQuizItem,
          PrefetchHooks Function()
        > {
  $$DriftQuizItemsTableTableManager(
    _$EngramDatabase db,
    $DriftQuizItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$DriftQuizItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$DriftQuizItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$DriftQuizItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conceptId = const Value.absent(),
                Value<String> question = const Value.absent(),
                Value<String> answer = const Value.absent(),
                Value<int> interval = const Value.absent(),
                Value<String> nextReview = const Value.absent(),
                Value<String?> lastReview = const Value.absent(),
                Value<double?> difficulty = const Value.absent(),
                Value<double?> stability = const Value.absent(),
                Value<int?> fsrsState = const Value.absent(),
                Value<int?> lapses = const Value.absent(),
                Value<double?> predictedDifficulty = const Value.absent(),
                Value<int> reviewCount = const Value.absent(),
                Value<IList<String>?> rubric = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DriftQuizItemsCompanion(
                id: id,
                conceptId: conceptId,
                question: question,
                answer: answer,
                interval: interval,
                nextReview: nextReview,
                lastReview: lastReview,
                difficulty: difficulty,
                stability: stability,
                fsrsState: fsrsState,
                lapses: lapses,
                predictedDifficulty: predictedDifficulty,
                reviewCount: reviewCount,
                rubric: rubric,
                hlc: hlc,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conceptId,
                required String question,
                required String answer,
                required int interval,
                required String nextReview,
                Value<String?> lastReview = const Value.absent(),
                Value<double?> difficulty = const Value.absent(),
                Value<double?> stability = const Value.absent(),
                Value<int?> fsrsState = const Value.absent(),
                Value<int?> lapses = const Value.absent(),
                Value<double?> predictedDifficulty = const Value.absent(),
                Value<int> reviewCount = const Value.absent(),
                Value<IList<String>?> rubric = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DriftQuizItemsCompanion.insert(
                id: id,
                conceptId: conceptId,
                question: question,
                answer: answer,
                interval: interval,
                nextReview: nextReview,
                lastReview: lastReview,
                difficulty: difficulty,
                stability: stability,
                fsrsState: fsrsState,
                lapses: lapses,
                predictedDifficulty: predictedDifficulty,
                reviewCount: reviewCount,
                rubric: rubric,
                hlc: hlc,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable<$DriftQuizItemsTable, DriftQuizItem>(
                            table,
                          ),
                          BaseReferences<
                            _$EngramDatabase,
                            $DriftQuizItemsTable,
                            DriftQuizItem
                          >(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DriftQuizItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$EngramDatabase,
      $DriftQuizItemsTable,
      DriftQuizItem,
      $$DriftQuizItemsTableFilterComposer,
      $$DriftQuizItemsTableOrderingComposer,
      $$DriftQuizItemsTableAnnotationComposer,
      $$DriftQuizItemsTableCreateCompanionBuilder,
      $$DriftQuizItemsTableUpdateCompanionBuilder,
      (
        DriftQuizItem,
        BaseReferences<_$EngramDatabase, $DriftQuizItemsTable, DriftQuizItem>,
      ),
      DriftQuizItem,
      PrefetchHooks Function()
    >;
typedef $$DriftDocumentsTableCreateCompanionBuilder =
    DriftDocumentsCompanion Function({
      required String documentId,
      required String title,
      required String updatedAt,
      required String ingestedAt,
      Value<String?> collectionId,
      Value<String?> collectionName,
      Value<String?> ingestedText,
      Value<String> hlc,
      Value<bool> isDeleted,
      Value<int> rowid,
    });
typedef $$DriftDocumentsTableUpdateCompanionBuilder =
    DriftDocumentsCompanion Function({
      Value<String> documentId,
      Value<String> title,
      Value<String> updatedAt,
      Value<String> ingestedAt,
      Value<String?> collectionId,
      Value<String?> collectionName,
      Value<String?> ingestedText,
      Value<String> hlc,
      Value<bool> isDeleted,
      Value<int> rowid,
    });

class $$DriftDocumentsTableFilterComposer
    extends Composer<_$EngramDatabase, $DriftDocumentsTable> {
  $$DriftDocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ingestedAt => $composableBuilder(
    column: $table.ingestedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collectionId => $composableBuilder(
    column: $table.collectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collectionName => $composableBuilder(
    column: $table.collectionName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ingestedText => $composableBuilder(
    column: $table.ingestedText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DriftDocumentsTableOrderingComposer
    extends Composer<_$EngramDatabase, $DriftDocumentsTable> {
  $$DriftDocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ingestedAt => $composableBuilder(
    column: $table.ingestedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collectionId => $composableBuilder(
    column: $table.collectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collectionName => $composableBuilder(
    column: $table.collectionName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ingestedText => $composableBuilder(
    column: $table.ingestedText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DriftDocumentsTableAnnotationComposer
    extends Composer<_$EngramDatabase, $DriftDocumentsTable> {
  $$DriftDocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get ingestedAt => $composableBuilder(
    column: $table.ingestedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get collectionId => $composableBuilder(
    column: $table.collectionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get collectionName => $composableBuilder(
    column: $table.collectionName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ingestedText => $composableBuilder(
    column: $table.ingestedText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);
}

class $$DriftDocumentsTableTableManager
    extends
        RootTableManager<
          _$EngramDatabase,
          $DriftDocumentsTable,
          DriftDocument,
          $$DriftDocumentsTableFilterComposer,
          $$DriftDocumentsTableOrderingComposer,
          $$DriftDocumentsTableAnnotationComposer,
          $$DriftDocumentsTableCreateCompanionBuilder,
          $$DriftDocumentsTableUpdateCompanionBuilder,
          (
            DriftDocument,
            BaseReferences<
              _$EngramDatabase,
              $DriftDocumentsTable,
              DriftDocument
            >,
          ),
          DriftDocument,
          PrefetchHooks Function()
        > {
  $$DriftDocumentsTableTableManager(
    _$EngramDatabase db,
    $DriftDocumentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$DriftDocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$DriftDocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$DriftDocumentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> documentId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String> ingestedAt = const Value.absent(),
                Value<String?> collectionId = const Value.absent(),
                Value<String?> collectionName = const Value.absent(),
                Value<String?> ingestedText = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DriftDocumentsCompanion(
                documentId: documentId,
                title: title,
                updatedAt: updatedAt,
                ingestedAt: ingestedAt,
                collectionId: collectionId,
                collectionName: collectionName,
                ingestedText: ingestedText,
                hlc: hlc,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String documentId,
                required String title,
                required String updatedAt,
                required String ingestedAt,
                Value<String?> collectionId = const Value.absent(),
                Value<String?> collectionName = const Value.absent(),
                Value<String?> ingestedText = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DriftDocumentsCompanion.insert(
                documentId: documentId,
                title: title,
                updatedAt: updatedAt,
                ingestedAt: ingestedAt,
                collectionId: collectionId,
                collectionName: collectionName,
                ingestedText: ingestedText,
                hlc: hlc,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable<$DriftDocumentsTable, DriftDocument>(
                            table,
                          ),
                          BaseReferences<
                            _$EngramDatabase,
                            $DriftDocumentsTable,
                            DriftDocument
                          >(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DriftDocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$EngramDatabase,
      $DriftDocumentsTable,
      DriftDocument,
      $$DriftDocumentsTableFilterComposer,
      $$DriftDocumentsTableOrderingComposer,
      $$DriftDocumentsTableAnnotationComposer,
      $$DriftDocumentsTableCreateCompanionBuilder,
      $$DriftDocumentsTableUpdateCompanionBuilder,
      (
        DriftDocument,
        BaseReferences<_$EngramDatabase, $DriftDocumentsTable, DriftDocument>,
      ),
      DriftDocument,
      PrefetchHooks Function()
    >;
typedef $$DriftTopicsTableCreateCompanionBuilder =
    DriftTopicsCompanion Function({
      required String id,
      required String name,
      Value<String?> description,
      required String createdAt,
      Value<String?> lastIngestedAt,
      Value<String> hlc,
      Value<bool> isDeleted,
      Value<int> rowid,
    });
typedef $$DriftTopicsTableUpdateCompanionBuilder =
    DriftTopicsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> description,
      Value<String> createdAt,
      Value<String?> lastIngestedAt,
      Value<String> hlc,
      Value<bool> isDeleted,
      Value<int> rowid,
    });

class $$DriftTopicsTableFilterComposer
    extends Composer<_$EngramDatabase, $DriftTopicsTable> {
  $$DriftTopicsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastIngestedAt => $composableBuilder(
    column: $table.lastIngestedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DriftTopicsTableOrderingComposer
    extends Composer<_$EngramDatabase, $DriftTopicsTable> {
  $$DriftTopicsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastIngestedAt => $composableBuilder(
    column: $table.lastIngestedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DriftTopicsTableAnnotationComposer
    extends Composer<_$EngramDatabase, $DriftTopicsTable> {
  $$DriftTopicsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get lastIngestedAt => $composableBuilder(
    column: $table.lastIngestedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);
}

class $$DriftTopicsTableTableManager
    extends
        RootTableManager<
          _$EngramDatabase,
          $DriftTopicsTable,
          DriftTopic,
          $$DriftTopicsTableFilterComposer,
          $$DriftTopicsTableOrderingComposer,
          $$DriftTopicsTableAnnotationComposer,
          $$DriftTopicsTableCreateCompanionBuilder,
          $$DriftTopicsTableUpdateCompanionBuilder,
          (
            DriftTopic,
            BaseReferences<_$EngramDatabase, $DriftTopicsTable, DriftTopic>,
          ),
          DriftTopic,
          PrefetchHooks Function()
        > {
  $$DriftTopicsTableTableManager(_$EngramDatabase db, $DriftTopicsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$DriftTopicsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$DriftTopicsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$DriftTopicsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String?> lastIngestedAt = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DriftTopicsCompanion(
                id: id,
                name: name,
                description: description,
                createdAt: createdAt,
                lastIngestedAt: lastIngestedAt,
                hlc: hlc,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> description = const Value.absent(),
                required String createdAt,
                Value<String?> lastIngestedAt = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DriftTopicsCompanion.insert(
                id: id,
                name: name,
                description: description,
                createdAt: createdAt,
                lastIngestedAt: lastIngestedAt,
                hlc: hlc,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable<$DriftTopicsTable, DriftTopic>(table),
                          BaseReferences<
                            _$EngramDatabase,
                            $DriftTopicsTable,
                            DriftTopic
                          >(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DriftTopicsTableProcessedTableManager =
    ProcessedTableManager<
      _$EngramDatabase,
      $DriftTopicsTable,
      DriftTopic,
      $$DriftTopicsTableFilterComposer,
      $$DriftTopicsTableOrderingComposer,
      $$DriftTopicsTableAnnotationComposer,
      $$DriftTopicsTableCreateCompanionBuilder,
      $$DriftTopicsTableUpdateCompanionBuilder,
      (
        DriftTopic,
        BaseReferences<_$EngramDatabase, $DriftTopicsTable, DriftTopic>,
      ),
      DriftTopic,
      PrefetchHooks Function()
    >;
typedef $$DriftTopicDocumentsTableCreateCompanionBuilder =
    DriftTopicDocumentsCompanion Function({
      required String topicId,
      required String documentId,
      Value<String> hlc,
      Value<bool> isDeleted,
      Value<int> rowid,
    });
typedef $$DriftTopicDocumentsTableUpdateCompanionBuilder =
    DriftTopicDocumentsCompanion Function({
      Value<String> topicId,
      Value<String> documentId,
      Value<String> hlc,
      Value<bool> isDeleted,
      Value<int> rowid,
    });

class $$DriftTopicDocumentsTableFilterComposer
    extends Composer<_$EngramDatabase, $DriftTopicDocumentsTable> {
  $$DriftTopicDocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DriftTopicDocumentsTableOrderingComposer
    extends Composer<_$EngramDatabase, $DriftTopicDocumentsTable> {
  $$DriftTopicDocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DriftTopicDocumentsTableAnnotationComposer
    extends Composer<_$EngramDatabase, $DriftTopicDocumentsTable> {
  $$DriftTopicDocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get topicId =>
      $composableBuilder(column: $table.topicId, builder: (column) => column);

  GeneratedColumn<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);
}

class $$DriftTopicDocumentsTableTableManager
    extends
        RootTableManager<
          _$EngramDatabase,
          $DriftTopicDocumentsTable,
          DriftTopicDocument,
          $$DriftTopicDocumentsTableFilterComposer,
          $$DriftTopicDocumentsTableOrderingComposer,
          $$DriftTopicDocumentsTableAnnotationComposer,
          $$DriftTopicDocumentsTableCreateCompanionBuilder,
          $$DriftTopicDocumentsTableUpdateCompanionBuilder,
          (
            DriftTopicDocument,
            BaseReferences<
              _$EngramDatabase,
              $DriftTopicDocumentsTable,
              DriftTopicDocument
            >,
          ),
          DriftTopicDocument,
          PrefetchHooks Function()
        > {
  $$DriftTopicDocumentsTableTableManager(
    _$EngramDatabase db,
    $DriftTopicDocumentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$DriftTopicDocumentsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$DriftTopicDocumentsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$DriftTopicDocumentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> topicId = const Value.absent(),
                Value<String> documentId = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DriftTopicDocumentsCompanion(
                topicId: topicId,
                documentId: documentId,
                hlc: hlc,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String topicId,
                required String documentId,
                Value<String> hlc = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DriftTopicDocumentsCompanion.insert(
                topicId: topicId,
                documentId: documentId,
                hlc: hlc,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable<
                            $DriftTopicDocumentsTable,
                            DriftTopicDocument
                          >(table),
                          BaseReferences<
                            _$EngramDatabase,
                            $DriftTopicDocumentsTable,
                            DriftTopicDocument
                          >(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DriftTopicDocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$EngramDatabase,
      $DriftTopicDocumentsTable,
      DriftTopicDocument,
      $$DriftTopicDocumentsTableFilterComposer,
      $$DriftTopicDocumentsTableOrderingComposer,
      $$DriftTopicDocumentsTableAnnotationComposer,
      $$DriftTopicDocumentsTableCreateCompanionBuilder,
      $$DriftTopicDocumentsTableUpdateCompanionBuilder,
      (
        DriftTopicDocument,
        BaseReferences<
          _$EngramDatabase,
          $DriftTopicDocumentsTable,
          DriftTopicDocument
        >,
      ),
      DriftTopicDocument,
      PrefetchHooks Function()
    >;
typedef $$DriftSyncMetadataTableCreateCompanionBuilder =
    DriftSyncMetadataCompanion Function({
      required String peerId,
      required String lastSyncedHlc,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$DriftSyncMetadataTableUpdateCompanionBuilder =
    DriftSyncMetadataCompanion Function({
      Value<String> peerId,
      Value<String> lastSyncedHlc,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$DriftSyncMetadataTableFilterComposer
    extends Composer<_$EngramDatabase, $DriftSyncMetadataTable> {
  $$DriftSyncMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSyncedHlc => $composableBuilder(
    column: $table.lastSyncedHlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DriftSyncMetadataTableOrderingComposer
    extends Composer<_$EngramDatabase, $DriftSyncMetadataTable> {
  $$DriftSyncMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSyncedHlc => $composableBuilder(
    column: $table.lastSyncedHlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DriftSyncMetadataTableAnnotationComposer
    extends Composer<_$EngramDatabase, $DriftSyncMetadataTable> {
  $$DriftSyncMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get peerId =>
      $composableBuilder(column: $table.peerId, builder: (column) => column);

  GeneratedColumn<String> get lastSyncedHlc => $composableBuilder(
    column: $table.lastSyncedHlc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DriftSyncMetadataTableTableManager
    extends
        RootTableManager<
          _$EngramDatabase,
          $DriftSyncMetadataTable,
          DriftSyncMetadataData,
          $$DriftSyncMetadataTableFilterComposer,
          $$DriftSyncMetadataTableOrderingComposer,
          $$DriftSyncMetadataTableAnnotationComposer,
          $$DriftSyncMetadataTableCreateCompanionBuilder,
          $$DriftSyncMetadataTableUpdateCompanionBuilder,
          (
            DriftSyncMetadataData,
            BaseReferences<
              _$EngramDatabase,
              $DriftSyncMetadataTable,
              DriftSyncMetadataData
            >,
          ),
          DriftSyncMetadataData,
          PrefetchHooks Function()
        > {
  $$DriftSyncMetadataTableTableManager(
    _$EngramDatabase db,
    $DriftSyncMetadataTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$DriftSyncMetadataTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$DriftSyncMetadataTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$DriftSyncMetadataTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> peerId = const Value.absent(),
                Value<String> lastSyncedHlc = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DriftSyncMetadataCompanion(
                peerId: peerId,
                lastSyncedHlc: lastSyncedHlc,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String peerId,
                required String lastSyncedHlc,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DriftSyncMetadataCompanion.insert(
                peerId: peerId,
                lastSyncedHlc: lastSyncedHlc,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable<
                            $DriftSyncMetadataTable,
                            DriftSyncMetadataData
                          >(table),
                          BaseReferences<
                            _$EngramDatabase,
                            $DriftSyncMetadataTable,
                            DriftSyncMetadataData
                          >(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DriftSyncMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$EngramDatabase,
      $DriftSyncMetadataTable,
      DriftSyncMetadataData,
      $$DriftSyncMetadataTableFilterComposer,
      $$DriftSyncMetadataTableOrderingComposer,
      $$DriftSyncMetadataTableAnnotationComposer,
      $$DriftSyncMetadataTableCreateCompanionBuilder,
      $$DriftSyncMetadataTableUpdateCompanionBuilder,
      (
        DriftSyncMetadataData,
        BaseReferences<
          _$EngramDatabase,
          $DriftSyncMetadataTable,
          DriftSyncMetadataData
        >,
      ),
      DriftSyncMetadataData,
      PrefetchHooks Function()
    >;

class $EngramDatabaseManager {
  final _$EngramDatabase _db;
  $EngramDatabaseManager(this._db);
  $$DriftConceptsTableTableManager get driftConcepts =>
      $$DriftConceptsTableTableManager(_db, _db.driftConcepts);
  $$DriftRelationshipsTableTableManager get driftRelationships =>
      $$DriftRelationshipsTableTableManager(_db, _db.driftRelationships);
  $$DriftQuizItemsTableTableManager get driftQuizItems =>
      $$DriftQuizItemsTableTableManager(_db, _db.driftQuizItems);
  $$DriftDocumentsTableTableManager get driftDocuments =>
      $$DriftDocumentsTableTableManager(_db, _db.driftDocuments);
  $$DriftTopicsTableTableManager get driftTopics =>
      $$DriftTopicsTableTableManager(_db, _db.driftTopics);
  $$DriftTopicDocumentsTableTableManager get driftTopicDocuments =>
      $$DriftTopicDocumentsTableTableManager(_db, _db.driftTopicDocuments);
  $$DriftSyncMetadataTableTableManager get driftSyncMetadata =>
      $$DriftSyncMetadataTableTableManager(_db, _db.driftSyncMetadata);
}
