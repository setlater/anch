import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';

import '../../core/template/field_definition.dart';
import '../../core/template/field_priority.dart';
import '../../core/template/type_definition.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/widgets/anch_adaptive_layout.dart';
import '../../core/widgets/anch_bottom_action_bar.dart';
import 'utils/key_registry.dart';

class ItemEntryFieldInputSection extends StatelessWidget {
  const ItemEntryFieldInputSection({
    super.key,
    required this.selectedType,
    required this.existingItemId,
    required this.showOptionalFields,
    required this.onShowOptionalFieldsChanged,
    required this.isKeyboardVisible,
    required this.scrollBottomPadding,
    required this.fieldBuilder,
    required this.onNext,
    this.identityProfileSuggestion,
    this.genericFieldsLayout,
    this.shippingAddressPasteAction,
  });

  final TypeDefinition selectedType;
  final String? existingItemId;
  final bool showOptionalFields;
  final ValueChanged<bool> onShowOptionalFieldsChanged;
  final bool isKeyboardVisible;
  final double scrollBottomPadding;
  final Widget Function(FieldDefinition field) fieldBuilder;
  final VoidCallback onNext;
  final Widget? identityProfileSuggestion;
  final Widget? genericFieldsLayout;
  final Widget? shippingAddressPasteAction;

  Widget _buildFieldGroupCard(
    BuildContext context,
    List<Widget> children, {
    required Key key,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AnchSpacing.lg),
      child: Container(
        key: key,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.anchColors.divider)),
        ),
        padding: const EdgeInsets.only(bottom: AnchSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [...children],
        ),
      ),
    );
  }

  Widget _buildFallbackExpandSection({
    required BuildContext context,
    required String typeKey,
    required List<FieldDefinition> optionalFields,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => onShowOptionalFieldsChanged(!showOptionalFields),
          borderRadius: BorderRadius.circular(AnchSpacing.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AnchSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showOptionalFields ? '收起更多字段' : '展开更多字段',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.anchColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '可选填写，不影响先保存资料',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.anchColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                AnchIcon(
                  showOptionalFields
                      ? AnchIcons.chevronUp
                      : AnchIcons.chevronDown,
                  color: context.anchColors.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (showOptionalFields) ...[
          const SizedBox(height: AnchSpacing.md),
          _buildFieldGroupCard(
            context,
            optionalFields.map(fieldBuilder).toList(),
            key: Key('item_field_group_${typeKey}_1'),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fields = selectedType.fields;
    final isHouseholdBook = selectedType.typeKey == 'household_book';
    final memberKeys = {
      'page_owner',
      'relation_to_head',
      'id_number',
      'former_name',
      'ethnicity',
      'native_place',
      'birth_place',
    };

    final primaryFields = fields
        .where(
          (f) =>
              (f.required || f.priority == FieldPriority.p0) &&
              !(isHouseholdBook && memberKeys.contains(f.fieldKey)),
        )
        .toList();
    final optionalFields = fields
        .where(
          (f) =>
              (!f.required && f.priority != FieldPriority.p0) &&
              !(isHouseholdBook && memberKeys.contains(f.fieldKey)),
        )
        .toList();

    final isIDCard = selectedType.typeKey == 'id_card';
    final isPassport = selectedType.typeKey == 'passport';
    final isHkMacaoPass = selectedType.typeKey == 'hk_macao_pass';
    final isDrivingLicense = selectedType.typeKey == 'driver_license';
    final isVehicleLicense = selectedType.typeKey == 'vehicle_license';
    final isBirthCertificate = selectedType.typeKey == 'birth_certificate';
    final isMarriageCertificate =
        selectedType.typeKey == 'marriage_certificate';
    final isDebitCard = selectedType.typeKey == 'debit_card';
    final isCreditCard = selectedType.typeKey == 'credit_card';
    final isInsurance = selectedType.typeKey == 'insurance';
    final isPropertyCertificate =
        selectedType.typeKey == 'property_certificate';
    final isEducationCertificate =
        selectedType.typeKey == 'education_certificate';
    final isGeneric = selectedType.typeKey == 'generic';

    Widget idCardFieldsLayout = const SizedBox.shrink();
    Widget passportFieldsLayout = const SizedBox.shrink();
    Widget hkMacaoPassFieldsLayout = const SizedBox.shrink();
    Widget drivingLicenseFieldsLayout = const SizedBox.shrink();
    Widget vehicleLicenseFieldsLayout = const SizedBox.shrink();
    Widget birthCertificateFieldsLayout = const SizedBox.shrink();
    Widget marriageCertificateFieldsLayout = const SizedBox.shrink();
    Widget debitCardFieldsLayout = const SizedBox.shrink();
    Widget creditCardFieldsLayout = const SizedBox.shrink();
    Widget insuranceFieldsLayout = const SizedBox.shrink();
    Widget propertyCertificateFieldsLayout = const SizedBox.shrink();
    Widget educationCertificateFieldsLayout = const SizedBox.shrink();
    Widget genericFieldsLayout = const SizedBox.shrink();
    if (isIDCard) {
      final nameField = fields.firstWhere((f) => f.fieldKey == 'name');
      final idNumberField = fields.firstWhere((f) => f.fieldKey == 'id_number');
      final genderField = fields.firstWhere((f) => f.fieldKey == 'gender');
      final ethnicityField = fields.firstWhere(
        (f) => f.fieldKey == 'ethnicity',
      );
      final birthDateField = fields.firstWhere(
        (f) => f.fieldKey == 'birth_date',
      );
      final addressField = fields.firstWhere((f) => f.fieldKey == 'address');
      final issuingAuthorityField = fields.firstWhere(
        (f) => f.fieldKey == 'issuing_authority',
      );
      final validFromField = fields.firstWhere(
        (f) => f.fieldKey == 'valid_from',
      );
      final validUntilField = fields.firstWhere(
        (f) => f.fieldKey == 'valid_until',
      );
      final isLongTermField = fields.firstWhere(
        (f) => f.fieldKey == 'is_long_term',
      );

      final card0 = [
        fieldBuilder(nameField),
        fieldBuilder(idNumberField),
        fieldBuilder(genderField),
        fieldBuilder(ethnicityField),
        fieldBuilder(birthDateField),
      ];
      final card1 = [fieldBuilder(addressField)];
      final card2 = [
        fieldBuilder(issuingAuthorityField),
        AnchResponsiveColumns(
          minChildWidth: 160,
          spacing: AnchSpacing.md,
          children: [
            fieldBuilder(validFromField),
            fieldBuilder(validUntilField),
          ],
        ),
        fieldBuilder(isLongTermField),
      ];

      final cards = <Widget>[];
      if (card0.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card0,
            key: const Key('item_field_group_id_card_0'),
          ),
        );
      }
      if (card1.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card1,
            key: const Key('item_field_group_id_card_1'),
          ),
        );
      }
      if (card2.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card2,
            key: const Key('item_field_group_id_card_2'),
          ),
        );
      }

      idCardFieldsLayout = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i < cards.length - 1) const SizedBox(height: AnchSpacing.md),
          ],
        ],
      );
    }

    if (isPassport) {
      FieldDefinition? getField(String key) {
        for (final f in fields) {
          if (f.fieldKey == key) return f;
        }
        return null;
      }

      final passportNumberField = getField('passport_number');
      final nameCnField = getField('name_cn');
      final nameEnField = getField('name_en');
      final genderField = getField('gender');
      final birthDateField = getField('birth_date');
      final birthPlaceField = getField('birth_place');
      final nationalityField = getField('nationality');
      final issuePlaceField = getField('issue_place');
      final issuingAuthorityField = getField('issuing_authority');
      final issueDateField = getField('issue_date');
      final validUntilField = getField('valid_until');

      final card0 = [
        if (passportNumberField != null) fieldBuilder(passportNumberField),
      ];
      final card1 = [
        if (nameCnField != null) fieldBuilder(nameCnField),
        if (nameEnField != null) fieldBuilder(nameEnField),
        if (genderField != null) fieldBuilder(genderField),
        if (birthDateField != null) fieldBuilder(birthDateField),
        if (birthPlaceField != null) fieldBuilder(birthPlaceField),
        if (nationalityField != null) fieldBuilder(nationalityField),
      ];
      final card2 = [
        if (issuePlaceField != null) fieldBuilder(issuePlaceField),
        if (issuingAuthorityField != null) fieldBuilder(issuingAuthorityField),
        if (issueDateField != null) fieldBuilder(issueDateField),
        if (validUntilField != null) fieldBuilder(validUntilField),
      ];

      final cards = <Widget>[];
      if (card0.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card0,
            key: const Key('item_field_group_passport_0'),
          ),
        );
      }
      if (card1.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card1,
            key: const Key('item_field_group_passport_1'),
          ),
        );
      }
      if (card2.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card2,
            key: const Key('item_field_group_passport_2'),
          ),
        );
      }

      passportFieldsLayout = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i < cards.length - 1) const SizedBox(height: AnchSpacing.md),
          ],
        ],
      );
    }

    if (isHkMacaoPass) {
      FieldDefinition? getField(String key) {
        for (final f in fields) {
          if (f.fieldKey == key) return f;
        }
        return null;
      }

      final passNumberField = getField('pass_number');
      final nameField = getField('name');
      final genderField = getField('gender');
      final birthDateField = getField('birth_date');
      final issuePlaceField = getField('issue_place');
      final issuingAuthorityField = getField('issuing_authority');
      final issueDateField = getField('issue_date');
      final validUntilField = getField('valid_until');

      final card0 = [
        if (passNumberField != null) fieldBuilder(passNumberField),
        if (nameField != null) fieldBuilder(nameField),
      ];
      final card1 = [
        if (genderField != null) fieldBuilder(genderField),
        if (birthDateField != null) fieldBuilder(birthDateField),
      ];
      final card2 = [
        if (issuePlaceField != null) fieldBuilder(issuePlaceField),
        if (issuingAuthorityField != null) fieldBuilder(issuingAuthorityField),
        if (issueDateField != null) fieldBuilder(issueDateField),
        if (validUntilField != null) fieldBuilder(validUntilField),
      ];

      final cards = <Widget>[];
      if (card0.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card0,
            key: const Key('item_field_group_hk_macao_pass_0'),
          ),
        );
      }
      if (card1.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card1,
            key: const Key('item_field_group_hk_macao_pass_1'),
          ),
        );
      }
      if (card2.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card2,
            key: const Key('item_field_group_hk_macao_pass_2'),
          ),
        );
      }

      hkMacaoPassFieldsLayout = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i < cards.length - 1) const SizedBox(height: AnchSpacing.md),
          ],
        ],
      );
    }

    if (isDrivingLicense) {
      FieldDefinition? getField(String key) {
        for (final f in fields) {
          if (f.fieldKey == key) return f;
        }
        return null;
      }

      final licenseNumberField = getField('license_number');
      final fileNumberField = getField('file_number');
      final nameField = getField('name');
      final genderField = getField('gender');
      final birthDateField = getField('birth_date');
      final addressField = getField('address');
      final vehicleClassField = getField('vehicle_class');
      final issueDateField = getField('issue_date');
      final issuingAuthorityField = getField('issuing_authority');
      final validFromField = getField('valid_from');
      final validUntilField = getField('valid_until');

      final card0 = [
        if (licenseNumberField != null) fieldBuilder(licenseNumberField),
        if (fileNumberField != null) fieldBuilder(fileNumberField),
      ];
      final card1 = [
        if (nameField != null) fieldBuilder(nameField),
        if (genderField != null) fieldBuilder(genderField),
        if (birthDateField != null) fieldBuilder(birthDateField),
        if (addressField != null) fieldBuilder(addressField),
      ];
      final card2 = [
        if (vehicleClassField != null) fieldBuilder(vehicleClassField),
        if (issueDateField != null) fieldBuilder(issueDateField),
      ];
      final card3 = [
        if (issuingAuthorityField != null) fieldBuilder(issuingAuthorityField),
        if (validFromField != null) fieldBuilder(validFromField),
        if (validUntilField != null) fieldBuilder(validUntilField),
      ];

      final cards = <Widget>[];
      if (card0.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card0,
            key: const Key('item_field_group_driver_license_0'),
          ),
        );
      }
      if (card1.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card1,
            key: const Key('item_field_group_driver_license_1'),
          ),
        );
      }
      if (card2.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card2,
            key: const Key('item_field_group_driver_license_2'),
          ),
        );
      }
      if (card3.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card3,
            key: const Key('item_field_group_driver_license_3'),
          ),
        );
      }

      drivingLicenseFieldsLayout = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i < cards.length - 1) const SizedBox(height: AnchSpacing.md),
          ],
        ],
      );
    }

    if (isVehicleLicense) {
      FieldDefinition? getField(String key) {
        for (final f in fields) {
          if (f.fieldKey == key) return f;
        }
        return null;
      }

      final plateNumberField = getField('plate_number');
      final vinField = getField('vin');
      final engineNumberField = getField('engine_number');
      final vehicleTypeField = getField('vehicle_type');
      final modelField = getField('model');
      final useCharacterField = getField('use_character');
      final approvedPassengersField = getField('approved_passengers');
      final ownerNameField = getField('owner_name');
      final addressField = getField('address');
      final registerDateField = getField('register_date');
      final issueDateField = getField('issue_date');
      final issuingAuthorityField = getField('issuing_authority');

      final card0 = [
        if (plateNumberField != null) fieldBuilder(plateNumberField),
        if (vinField != null) fieldBuilder(vinField),
        if (engineNumberField != null) fieldBuilder(engineNumberField),
      ];
      final card1 = [
        if (vehicleTypeField != null) fieldBuilder(vehicleTypeField),
        if (modelField != null) fieldBuilder(modelField),
        if (useCharacterField != null) fieldBuilder(useCharacterField),
        if (approvedPassengersField != null)
          fieldBuilder(approvedPassengersField),
      ];
      final card2 = [
        if (ownerNameField != null) fieldBuilder(ownerNameField),
        if (addressField != null) fieldBuilder(addressField),
      ];
      final card3 = [
        if (registerDateField != null) fieldBuilder(registerDateField),
        if (issueDateField != null) fieldBuilder(issueDateField),
        if (issuingAuthorityField != null) fieldBuilder(issuingAuthorityField),
      ];

      final cards = <Widget>[];
      if (card0.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card0,
            key: const Key('item_field_group_vehicle_license_0'),
          ),
        );
      }
      if (card1.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card1,
            key: const Key('item_field_group_vehicle_license_1'),
          ),
        );
      }
      if (card2.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card2,
            key: const Key('item_field_group_vehicle_license_2'),
          ),
        );
      }
      if (card3.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card3,
            key: const Key('item_field_group_vehicle_license_3'),
          ),
        );
      }

      vehicleLicenseFieldsLayout = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i < cards.length - 1) const SizedBox(height: AnchSpacing.md),
          ],
        ],
      );
    }

    if (isBirthCertificate == true) {
      FieldDefinition? getField(String key) {
        for (final f in fields) {
          if (f.fieldKey == key) return f;
        }
        return null;
      }

      final childNameField = getField('child_name');
      final genderField = getField('gender');
      final birthDateField = getField('birth_date');
      final birthTimeField = getField('birth_time');
      final birthPlaceField = getField('birth_place');
      final fatherNameField = getField('father_name');
      final motherNameField = getField('mother_name');
      final certificateNumberField = getField('certificate_number');
      final issuingAuthorityField = getField('issuing_authority');
      final issueDateField = getField('issue_date');

      final card0 = [
        if (childNameField != null) fieldBuilder(childNameField),
        if (genderField != null) fieldBuilder(genderField),
        if (birthDateField != null) fieldBuilder(birthDateField),
        if (birthTimeField != null) fieldBuilder(birthTimeField),
        if (birthPlaceField != null) fieldBuilder(birthPlaceField),
      ];
      final card1 = [
        if (fatherNameField != null) fieldBuilder(fatherNameField),
        if (motherNameField != null) fieldBuilder(motherNameField),
      ];
      final card2 = [
        if (certificateNumberField != null)
          fieldBuilder(certificateNumberField),
        if (issuingAuthorityField != null) fieldBuilder(issuingAuthorityField),
        if (issueDateField != null) fieldBuilder(issueDateField),
      ];

      final cards = <Widget>[];
      if (card0.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card0,
            key: const Key('item_field_group_birth_certificate_0'),
          ),
        );
      }
      if (card1.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card1,
            key: const Key('item_field_group_birth_certificate_1'),
          ),
        );
      }
      if (card2.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card2,
            key: const Key('item_field_group_birth_certificate_2'),
          ),
        );
      }

      birthCertificateFieldsLayout = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i < cards.length - 1) const SizedBox(height: AnchSpacing.md),
          ],
        ],
      );
    }

    if (isMarriageCertificate == true) {
      FieldDefinition? getField(String key) {
        for (final f in fields) {
          if (f.fieldKey == key) return f;
        }
        return null;
      }

      final holderNameField = getField('holder_name');
      final spouseNameField = getField('spouse_name');
      final certificateNumberField = getField('certificate_number');
      final registerDateField = getField('register_date');
      final issuingAuthorityField = getField('issuing_authority');

      final card0 = [
        if (holderNameField != null) fieldBuilder(holderNameField),
        if (spouseNameField != null) fieldBuilder(spouseNameField),
      ];
      final card1 = [
        if (certificateNumberField != null)
          fieldBuilder(certificateNumberField),
        if (registerDateField != null) fieldBuilder(registerDateField),
        if (issuingAuthorityField != null) fieldBuilder(issuingAuthorityField),
      ];

      final cards = <Widget>[];
      if (card0.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card0,
            key: const Key('item_field_group_marriage_certificate_0'),
          ),
        );
      }
      if (card1.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card1,
            key: const Key('item_field_group_marriage_certificate_1'),
          ),
        );
      }

      marriageCertificateFieldsLayout = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i < cards.length - 1) const SizedBox(height: AnchSpacing.md),
          ],
        ],
      );
    }

    if (isDebitCard == true) {
      FieldDefinition? getField(String key) {
        for (final f in fields) {
          if (f.fieldKey == key) return f;
        }
        return null;
      }

      final bankNameField = getField('bank_name');
      final cardAliasField = getField('card_alias');
      final cardNumberField = getField('card_number');
      final accountNameField = getField('account_name');
      final branchNameField = getField('branch_name');
      final accountTypeField = getField('account_type');
      final usageField = getField('usage');
      final isClosedField = getField('is_closed');

      final card0 = [
        if (bankNameField != null) fieldBuilder(bankNameField),
        if (cardAliasField != null) fieldBuilder(cardAliasField),
        if (cardNumberField != null) fieldBuilder(cardNumberField),
      ];
      final card1 = [
        if (accountNameField != null) fieldBuilder(accountNameField),
        if (branchNameField != null) fieldBuilder(branchNameField),
        if (accountTypeField != null) fieldBuilder(accountTypeField),
      ];
      final card2 = [
        if (usageField != null) fieldBuilder(usageField),
        if (isClosedField != null) fieldBuilder(isClosedField),
      ];

      final cards = <Widget>[];
      if (card0.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card0,
            key: const Key('item_field_group_debit_card_0'),
          ),
        );
      }
      if (card1.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card1,
            key: const Key('item_field_group_debit_card_1'),
          ),
        );
      }
      if (card2.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card2,
            key: const Key('item_field_group_debit_card_2'),
          ),
        );
      }

      debitCardFieldsLayout = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i < cards.length - 1) const SizedBox(height: AnchSpacing.md),
          ],
        ],
      );
    }

    if (isCreditCard == true) {
      FieldDefinition? getField(String key) {
        for (final f in fields) {
          if (f.fieldKey == key) return f;
        }
        return null;
      }

      final bankNameField = getField('bank_name');
      final cardAliasField = getField('card_alias');
      final cardNumberField = getField('card_number');
      final accountNameField = getField('account_name');
      final cardNetworkField = getField('card_network');
      final billDayField = getField('bill_day');
      final repaymentDayField = getField('repayment_day');
      final validUntilField = getField('valid_until');
      final creditLimitField = getField('credit_limit');
      final annualFeeNoteField = getField('annual_fee_note');
      final usageField = getField('usage');
      final isClosedField = getField('is_closed');

      final card0 = [
        if (bankNameField != null) fieldBuilder(bankNameField),
        if (cardAliasField != null) fieldBuilder(cardAliasField),
        if (cardNumberField != null) fieldBuilder(cardNumberField),
        if (cardNetworkField != null) fieldBuilder(cardNetworkField),
        if (accountNameField != null) fieldBuilder(accountNameField),
      ];
      final card1 = [
        if (billDayField != null) fieldBuilder(billDayField),
        if (repaymentDayField != null) fieldBuilder(repaymentDayField),
      ];
      final card2 = [
        if (validUntilField != null) fieldBuilder(validUntilField),
        if (creditLimitField != null) fieldBuilder(creditLimitField),
        if (annualFeeNoteField != null) fieldBuilder(annualFeeNoteField),
        if (usageField != null) fieldBuilder(usageField),
        if (isClosedField != null) fieldBuilder(isClosedField),
      ];

      final cards = <Widget>[];
      if (card0.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card0,
            key: const Key('item_field_group_credit_card_0'),
          ),
        );
      }
      if (card1.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card1,
            key: const Key('item_field_group_credit_card_1'),
          ),
        );
      }
      if (card2.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card2,
            key: const Key('item_field_group_credit_card_2'),
          ),
        );
      }

      creditCardFieldsLayout = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i < cards.length - 1) const SizedBox(height: AnchSpacing.md),
          ],
        ],
      );
    }

    if (isInsurance) {
      FieldDefinition? getField(String key) {
        for (final f in fields) {
          if (f.fieldKey == key) return f;
        }
        return null;
      }

      final insuranceCompanyField = getField('insurance_company');
      final policyNameField = getField('policy_name');
      final policyNumberField = getField('policy_number');
      final insuranceTypeField = getField('insurance_type');
      final applicantField = getField('applicant');
      final insuredPersonField = getField('insured_person');
      final startDateField = getField('start_date');
      final endDateField = getField('end_date');
      final premiumField = getField('premium');
      final coverageAmountField = getField('coverage_amount');
      final servicePhoneField = getField('service_phone');

      final card0 = [
        if (insuranceCompanyField != null) fieldBuilder(insuranceCompanyField),
        if (policyNameField != null) fieldBuilder(policyNameField),
        if (policyNumberField != null) fieldBuilder(policyNumberField),
        if (insuranceTypeField != null) fieldBuilder(insuranceTypeField),
      ];
      final card1 = [
        if (applicantField != null) fieldBuilder(applicantField),
        if (insuredPersonField != null) fieldBuilder(insuredPersonField),
      ];
      final card2 = [
        if (startDateField != null) fieldBuilder(startDateField),
        if (endDateField != null) fieldBuilder(endDateField),
      ];
      final card3 = [
        if (premiumField != null) fieldBuilder(premiumField),
        if (coverageAmountField != null) fieldBuilder(coverageAmountField),
        if (servicePhoneField != null) fieldBuilder(servicePhoneField),
      ];

      final cards = <Widget>[];
      if (card0.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card0,
            key: const Key('item_field_group_insurance_0'),
          ),
        );
      }
      if (card1.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card1,
            key: const Key('item_field_group_insurance_1'),
          ),
        );
      }
      if (card2.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card2,
            key: const Key('item_field_group_insurance_2'),
          ),
        );
      }
      if (card3.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card3,
            key: const Key('item_field_group_insurance_3'),
          ),
        );
      }

      insuranceFieldsLayout = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i < cards.length - 1) const SizedBox(height: AnchSpacing.md),
          ],
        ],
      );
    }

    if (isPropertyCertificate) {
      FieldDefinition? getField(String key) {
        for (final f in fields) {
          if (f.fieldKey == key) return f;
        }
        return null;
      }

      final ownerNameField = getField('owner_name');
      final ownershipStatusField = getField('ownership_status');
      final certificateNumberField = getField('certificate_number');
      final registrationDateField = getField('registration_date');
      final registrationAuthorityField = getField('registration_authority');
      final propertyLocationField = getField('property_location');
      final propertyUsageField = getField('property_usage');
      final buildingAreaField = getField('building_area');
      final landAreaField = getField('land_area');

      final card0 = [
        if (ownerNameField != null) fieldBuilder(ownerNameField),
        if (ownershipStatusField != null) fieldBuilder(ownershipStatusField),
      ];
      final card1 = [
        if (certificateNumberField != null)
          fieldBuilder(certificateNumberField),
        if (registrationDateField != null) fieldBuilder(registrationDateField),
        if (registrationAuthorityField != null)
          fieldBuilder(registrationAuthorityField),
      ];
      final card2 = [
        if (propertyLocationField != null) fieldBuilder(propertyLocationField),
        if (propertyUsageField != null) fieldBuilder(propertyUsageField),
        if (buildingAreaField != null) fieldBuilder(buildingAreaField),
        if (landAreaField != null) fieldBuilder(landAreaField),
      ];

      final cards = <Widget>[];
      if (card0.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card0,
            key: const Key('item_field_group_property_certificate_0'),
          ),
        );
      }
      if (card1.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card1,
            key: const Key('item_field_group_property_certificate_1'),
          ),
        );
      }
      if (card2.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card2,
            key: const Key('item_field_group_property_certificate_2'),
          ),
        );
      }

      propertyCertificateFieldsLayout = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i < cards.length - 1) const SizedBox(height: AnchSpacing.md),
          ],
        ],
      );
    }

    if (isEducationCertificate) {
      FieldDefinition? getField(String key) {
        for (final f in fields) {
          if (f.fieldKey == key) return f;
        }
        return null;
      }

      final certificateTypeField = getField('certificate_type');
      final certificateNumberField = getField('certificate_number');
      final issueDateField = getField('issue_date');
      final schoolNameField = getField('school_name');
      final majorNameField = getField('major_name');
      final degreeLevelField = getField('degree_level');
      final holderNameField = getField('holder_name');
      final enrollmentDateField = getField('enrollment_date');
      final graduationDateField = getField('graduation_date');

      final card0 = [
        if (certificateTypeField != null) fieldBuilder(certificateTypeField),
        if (certificateNumberField != null)
          fieldBuilder(certificateNumberField),
        if (issueDateField != null) fieldBuilder(issueDateField),
      ];
      final card1 = [
        if (schoolNameField != null) fieldBuilder(schoolNameField),
        if (majorNameField != null) fieldBuilder(majorNameField),
        if (degreeLevelField != null) fieldBuilder(degreeLevelField),
      ];
      final card2 = [
        if (holderNameField != null) fieldBuilder(holderNameField),
        if (enrollmentDateField != null) fieldBuilder(enrollmentDateField),
        if (graduationDateField != null) fieldBuilder(graduationDateField),
      ];

      final cards = <Widget>[];
      if (card0.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card0,
            key: const Key('item_field_group_education_certificate_0'),
          ),
        );
      }
      if (card1.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card1,
            key: const Key('item_field_group_education_certificate_1'),
          ),
        );
      }
      if (card2.isNotEmpty) {
        cards.add(
          _buildFieldGroupCard(
            context,
            card2,
            key: const Key('item_field_group_education_certificate_2'),
          ),
        );
      }

      educationCertificateFieldsLayout = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i < cards.length - 1) const SizedBox(height: AnchSpacing.md),
          ],
        ],
      );
    }

    if (isGeneric) {
      FieldDefinition? getField(String key) {
        for (final f in fields) {
          if (f.fieldKey == key) return f;
        }
        return null;
      }

      if (selectedType.version >= 2) {
        if (this.genericFieldsLayout != null) {
          genericFieldsLayout = this.genericFieldsLayout!;
        } else {
          final titleField = getField('title');
          final pairs = <Widget>[];
          for (var index = 1; index <= 3; index++) {
            final labelField = getField('custom_field_label_$index');
            final valueField = getField('custom_field_value_$index');
            if (labelField == null || valueField == null) continue;
            pairs.add(
              _buildFieldGroupCard(context, [
                fieldBuilder(labelField),
                fieldBuilder(valueField),
              ], key: Key('item_field_group_generic_pair_$index')),
            );
          }

          genericFieldsLayout = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (titleField != null)
                _buildFieldGroupCard(context, [
                  fieldBuilder(titleField),
                ], key: const Key('item_field_group_generic_title')),
              for (final pair in pairs) ...[
                const SizedBox(height: AnchSpacing.md),
                pair,
              ],
            ],
          );
        }
      } else {
        final titleField = getField('title');
        final ownerNameField = getField('owner_name');
        final identifierField = getField('identifier');
        final issuerField = getField('issuer');
        final validUntilField = getField('valid_until');

        final card0 = [
          if (titleField != null) fieldBuilder(titleField),
          if (ownerNameField != null) fieldBuilder(ownerNameField),
          if (identifierField != null) fieldBuilder(identifierField),
        ];
        final card1 = [
          if (issuerField != null) fieldBuilder(issuerField),
          if (validUntilField != null) fieldBuilder(validUntilField),
        ];

        final cards = <Widget>[];
        if (card0.isNotEmpty) {
          cards.add(
            _buildFieldGroupCard(
              context,
              card0,
              key: const Key('item_field_group_generic_0'),
            ),
          );
        }
        if (card1.isNotEmpty) {
          cards.add(
            _buildFieldGroupCard(
              context,
              card1,
              key: const Key('item_field_group_generic_1'),
            ),
          );
        }

        genericFieldsLayout = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              cards[i],
              if (i < cards.length - 1) const SizedBox(height: AnchSpacing.md),
            ],
          ],
        );
      }
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AnchSpacing.page,
              AnchSpacing.md,
              AnchSpacing.page,
              scrollBottomPadding,
            ),
            child: Column(
              key: const Key('item_entry_step3_form'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (existingItemId == null && !isKeyboardVisible) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: AnchSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '填写核心信息',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: context.anchColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AnchSpacing.xs),
                        Text(
                          '高敏字段保存后默认隐藏。',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.anchColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (identityProfileSuggestion != null) ...[
                  identityProfileSuggestion!,
                  const SizedBox(height: AnchSpacing.md),
                ],
                if (shippingAddressPasteAction != null) ...[
                  shippingAddressPasteAction!,
                  const SizedBox(height: AnchSpacing.md),
                ],
                if (isIDCard)
                  idCardFieldsLayout
                else if (isPassport)
                  passportFieldsLayout
                else if (isHkMacaoPass)
                  hkMacaoPassFieldsLayout
                else if (isDrivingLicense)
                  drivingLicenseFieldsLayout
                else if (isVehicleLicense)
                  vehicleLicenseFieldsLayout
                else if (isBirthCertificate)
                  birthCertificateFieldsLayout
                else if (isMarriageCertificate)
                  marriageCertificateFieldsLayout
                else if (isDebitCard)
                  debitCardFieldsLayout
                else if (isCreditCard)
                  creditCardFieldsLayout
                else if (isInsurance)
                  insuranceFieldsLayout
                else if (isPropertyCertificate)
                  propertyCertificateFieldsLayout
                else if (isEducationCertificate)
                  educationCertificateFieldsLayout
                else if (isGeneric)
                  genericFieldsLayout
                else ...[
                  if (primaryFields.isNotEmpty)
                    _buildFieldGroupCard(
                      context,
                      primaryFields.map((f) => fieldBuilder(f)).toList(),
                      key: Key('item_field_group_${selectedType.typeKey}_0'),
                    ),
                  if (optionalFields.isNotEmpty) ...[
                    const SizedBox(height: AnchSpacing.md),
                    _buildFallbackExpandSection(
                      context: context,
                      typeKey: selectedType.typeKey,
                      optionalFields: optionalFields,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        AnchBottomActionBar(
          key: KeyRegistry.flowButtonNext,
          primaryLabel: '下一步',
          compactWhenKeyboardVisible: true,
          compactPrimaryLabel: '下一步',
          isKeyboardVisible: isKeyboardVisible,
          flat: true,
          onPrimary: () => onNext(),
        ),
      ],
    );
  }
}
