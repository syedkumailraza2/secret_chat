// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAppSettingsCollection on Isar {
  IsarCollection<AppSettings> get appSettings => this.collection();
}

const AppSettingsSchema = CollectionSchema(
  name: r'AppSettings',
  id: -5633561779022347008,
  properties: {
    r'biometricLockEnabled': PropertySchema(
      id: 0,
      name: r'biometricLockEnabled',
      type: IsarType.bool,
    ),
    r'dailyReminderEnabled': PropertySchema(
      id: 1,
      name: r'dailyReminderEnabled',
      type: IsarType.bool,
    ),
    r'defaultCycleLength': PropertySchema(
      id: 2,
      name: r'defaultCycleLength',
      type: IsarType.long,
    ),
    r'defaultPeriodLength': PropertySchema(
      id: 3,
      name: r'defaultPeriodLength',
      type: IsarType.long,
    ),
    r'onboardingComplete': PropertySchema(
      id: 4,
      name: r'onboardingComplete',
      type: IsarType.bool,
    ),
    r'periodReminderEnabled': PropertySchema(
      id: 5,
      name: r'periodReminderEnabled',
      type: IsarType.bool,
    ),
    r'reminderTime': PropertySchema(
      id: 6,
      name: r'reminderTime',
      type: IsarType.dateTime,
    ),
    r'themeMode': PropertySchema(
      id: 7,
      name: r'themeMode',
      type: IsarType.string,
    ),
  },

  estimateSize: _appSettingsEstimateSize,
  serialize: _appSettingsSerialize,
  deserialize: _appSettingsDeserialize,
  deserializeProp: _appSettingsDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},

  getId: _appSettingsGetId,
  getLinks: _appSettingsGetLinks,
  attach: _appSettingsAttach,
  version: '3.3.2',
);

int _appSettingsEstimateSize(
  AppSettings object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.themeMode.length * 3;
  return bytesCount;
}

void _appSettingsSerialize(
  AppSettings object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.biometricLockEnabled);
  writer.writeBool(offsets[1], object.dailyReminderEnabled);
  writer.writeLong(offsets[2], object.defaultCycleLength);
  writer.writeLong(offsets[3], object.defaultPeriodLength);
  writer.writeBool(offsets[4], object.onboardingComplete);
  writer.writeBool(offsets[5], object.periodReminderEnabled);
  writer.writeDateTime(offsets[6], object.reminderTime);
  writer.writeString(offsets[7], object.themeMode);
}

AppSettings _appSettingsDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AppSettings();
  object.biometricLockEnabled = reader.readBool(offsets[0]);
  object.dailyReminderEnabled = reader.readBool(offsets[1]);
  object.defaultCycleLength = reader.readLong(offsets[2]);
  object.defaultPeriodLength = reader.readLong(offsets[3]);
  object.id = id;
  object.onboardingComplete = reader.readBool(offsets[4]);
  object.periodReminderEnabled = reader.readBool(offsets[5]);
  object.reminderTime = reader.readDateTimeOrNull(offsets[6]);
  object.themeMode = reader.readString(offsets[7]);
  return object;
}

P _appSettingsDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readBool(offset)) as P;
    case 1:
      return (reader.readBool(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _appSettingsGetId(AppSettings object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _appSettingsGetLinks(AppSettings object) {
  return [];
}

void _appSettingsAttach(
  IsarCollection<dynamic> col,
  Id id,
  AppSettings object,
) {
  object.id = id;
}

extension AppSettingsQueryWhereSort
    on QueryBuilder<AppSettings, AppSettings, QWhere> {
  QueryBuilder<AppSettings, AppSettings, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension AppSettingsQueryWhere
    on QueryBuilder<AppSettings, AppSettings, QWhereClause> {
  QueryBuilder<AppSettings, AppSettings, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension AppSettingsQueryFilter
    on QueryBuilder<AppSettings, AppSettings, QFilterCondition> {
  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  biometricLockEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'biometricLockEnabled',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  dailyReminderEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'dailyReminderEnabled',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  defaultCycleLengthEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'defaultCycleLength', value: value),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  defaultCycleLengthGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'defaultCycleLength',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  defaultCycleLengthLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'defaultCycleLength',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  defaultCycleLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'defaultCycleLength',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  defaultPeriodLengthEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'defaultPeriodLength', value: value),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  defaultPeriodLengthGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'defaultPeriodLength',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  defaultPeriodLengthLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'defaultPeriodLength',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  defaultPeriodLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'defaultPeriodLength',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  onboardingCompleteEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'onboardingComplete', value: value),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  periodReminderEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'periodReminderEnabled',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  reminderTimeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'reminderTime'),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  reminderTimeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'reminderTime'),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  reminderTimeEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'reminderTime', value: value),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  reminderTimeGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'reminderTime',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  reminderTimeLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'reminderTime',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  reminderTimeBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'reminderTime',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  themeModeEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'themeMode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  themeModeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'themeMode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  themeModeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'themeMode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  themeModeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'themeMode',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  themeModeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'themeMode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  themeModeEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'themeMode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  themeModeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'themeMode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  themeModeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'themeMode',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  themeModeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'themeMode', value: ''),
      );
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterFilterCondition>
  themeModeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'themeMode', value: ''),
      );
    });
  }
}

extension AppSettingsQueryObject
    on QueryBuilder<AppSettings, AppSettings, QFilterCondition> {}

extension AppSettingsQueryLinks
    on QueryBuilder<AppSettings, AppSettings, QFilterCondition> {}

extension AppSettingsQuerySortBy
    on QueryBuilder<AppSettings, AppSettings, QSortBy> {
  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByBiometricLockEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'biometricLockEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByBiometricLockEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'biometricLockEnabled', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByDailyReminderEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dailyReminderEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByDailyReminderEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dailyReminderEnabled', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByDefaultCycleLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultCycleLength', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByDefaultCycleLengthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultCycleLength', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByDefaultPeriodLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultPeriodLength', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByDefaultPeriodLengthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultPeriodLength', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByOnboardingComplete() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'onboardingComplete', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByOnboardingCompleteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'onboardingComplete', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByPeriodReminderEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'periodReminderEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByPeriodReminderEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'periodReminderEnabled', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByReminderTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reminderTime', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  sortByReminderTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reminderTime', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByThemeMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'themeMode', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> sortByThemeModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'themeMode', Sort.desc);
    });
  }
}

extension AppSettingsQuerySortThenBy
    on QueryBuilder<AppSettings, AppSettings, QSortThenBy> {
  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByBiometricLockEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'biometricLockEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByBiometricLockEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'biometricLockEnabled', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByDailyReminderEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dailyReminderEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByDailyReminderEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dailyReminderEnabled', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByDefaultCycleLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultCycleLength', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByDefaultCycleLengthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultCycleLength', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByDefaultPeriodLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultPeriodLength', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByDefaultPeriodLengthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultPeriodLength', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByOnboardingComplete() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'onboardingComplete', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByOnboardingCompleteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'onboardingComplete', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByPeriodReminderEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'periodReminderEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByPeriodReminderEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'periodReminderEnabled', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByReminderTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reminderTime', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy>
  thenByReminderTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reminderTime', Sort.desc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByThemeMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'themeMode', Sort.asc);
    });
  }

  QueryBuilder<AppSettings, AppSettings, QAfterSortBy> thenByThemeModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'themeMode', Sort.desc);
    });
  }
}

extension AppSettingsQueryWhereDistinct
    on QueryBuilder<AppSettings, AppSettings, QDistinct> {
  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByBiometricLockEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'biometricLockEnabled');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByDailyReminderEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dailyReminderEnabled');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByDefaultCycleLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'defaultCycleLength');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByDefaultPeriodLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'defaultPeriodLength');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByOnboardingComplete() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'onboardingComplete');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct>
  distinctByPeriodReminderEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'periodReminderEnabled');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct> distinctByReminderTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reminderTime');
    });
  }

  QueryBuilder<AppSettings, AppSettings, QDistinct> distinctByThemeMode({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'themeMode', caseSensitive: caseSensitive);
    });
  }
}

extension AppSettingsQueryProperty
    on QueryBuilder<AppSettings, AppSettings, QQueryProperty> {
  QueryBuilder<AppSettings, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AppSettings, bool, QQueryOperations>
  biometricLockEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'biometricLockEnabled');
    });
  }

  QueryBuilder<AppSettings, bool, QQueryOperations>
  dailyReminderEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dailyReminderEnabled');
    });
  }

  QueryBuilder<AppSettings, int, QQueryOperations>
  defaultCycleLengthProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'defaultCycleLength');
    });
  }

  QueryBuilder<AppSettings, int, QQueryOperations>
  defaultPeriodLengthProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'defaultPeriodLength');
    });
  }

  QueryBuilder<AppSettings, bool, QQueryOperations>
  onboardingCompleteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'onboardingComplete');
    });
  }

  QueryBuilder<AppSettings, bool, QQueryOperations>
  periodReminderEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'periodReminderEnabled');
    });
  }

  QueryBuilder<AppSettings, DateTime?, QQueryOperations>
  reminderTimeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reminderTime');
    });
  }

  QueryBuilder<AppSettings, String, QQueryOperations> themeModeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'themeMode');
    });
  }
}
