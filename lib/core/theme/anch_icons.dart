import 'package:flutter/foundation.dart';

/// 安册语义图标。
///
/// 资源名称和路径只允许在本文件中声明。页面与组件只消费 [AnchIcons] 暴露的
/// 语义名称，不接触 Solar 原始名称。
@immutable
class AnchIconData {
  const AnchIconData._(this._resourceName);

  static const String _assetRoot = 'assets/icons/solar/1.2.5';

  final String _resourceName;

  String get assetPath => '$_assetRoot/$_resourceName.svg';
}

@immutable
class AnchNavigationIconData {
  const AnchNavigationIconData({required this.normal, required this.selected});

  final AnchIconData normal;
  final AnchIconData selected;
}

/// 应用内唯一的 Solar 图标声明入口。
abstract final class AnchIcons {
  // 通用操作与反馈。
  static const add = AnchIconData._('add-linear');
  static const archive = AnchIconData._('archive-linear');
  static const attachment = AnchIconData._('paperclip-linear');
  static const back = AnchIconData._('alt-arrow-left-linear');
  static const backup = AnchIconData._('upload-linear');
  static const bank = AnchIconData._('banknote-2-linear');
  static const brokenImage = AnchIconData._('gallery-remove-linear');
  static const box = AnchIconData._('box-linear');
  static const calendar = AnchIconData._('calendar-linear');
  static const camera = AnchIconData._('camera-linear');
  static const cancel = AnchIconData._('close-circle-linear');
  static const check = AnchIconData._('check-read-linear');
  static const chevronDown = AnchIconData._('alt-arrow-down-linear');
  static const chevronLeft = AnchIconData._('alt-arrow-left-linear');
  static const chevronRight = AnchIconData._('alt-arrow-right-linear');
  static const chevronUp = AnchIconData._('alt-arrow-up-linear');
  static const close = AnchIconData._('close-linear');
  static const copy = AnchIconData._('copy-linear');
  static const code = AnchIconData._('code-square-linear');
  static const crop = AnchIconData._('crop-linear');
  static const danger = AnchIconData._('shield-warning-linear');
  static const delete = AnchIconData._('trash-bin-trash-linear');
  static const document = AnchIconData._('document-text-linear');
  static const download = AnchIconData._('download-linear');
  static const edit = AnchIconData._('pen-linear');
  static const empty = AnchIconData._('folder-with-files-linear');
  static const error = AnchIconData._('danger-circle-linear');
  static const file = AnchIconData._('file-linear');
  static const filter = AnchIconData._('filter-linear');
  static const folder = AnchIconData._('folder-linear');
  static const folderOpen = AnchIconData._('folder-open-linear');
  static const help = AnchIconData._('question-circle-linear');
  static const home = AnchIconData._('home-2-linear');
  static const image = AnchIconData._('gallery-linear');
  static const info = AnchIconData._('info-circle-linear');
  static const key = AnchIconData._('key-linear');
  static const lightbulb = AnchIconData._('lightbulb-linear');
  static const listRemove = AnchIconData._('list-cross-linear');
  static const lock = AnchIconData._('lock-linear');
  static const lockOpen = AnchIconData._('lock-unlocked-linear');
  static const member = AnchIconData._('user-rounded-linear');
  static const members = AnchIconData._('users-group-rounded-linear');
  static const more = AnchIconData._('menu-dots-linear');
  static const notification = AnchIconData._('bell-linear');
  static const offline = AnchIconData._('cloud-cross-linear');
  static const pdf = AnchIconData._('file-text-linear');
  static const phone = AnchIconData._('smartphone-linear');
  static const photoLibrary = AnchIconData._('gallery-wide-linear');
  static const radioUnchecked = AnchIconData._('record-circle-linear');
  static const remove = AnchIconData._('minus-circle-linear');
  static const reset = AnchIconData._('restart-circle-linear');
  static const restore = AnchIconData._('restart-linear');
  static const rotate = AnchIconData._('restart-linear');
  static const screenshot = AnchIconData._('screencast-linear');
  static const search = AnchIconData._('magnifer-linear');
  static const security = AnchIconData._('shield-user-linear');
  static const settings = AnchIconData._('settings-linear');
  static const success = AnchIconData._('check-circle-linear');
  static const time = AnchIconData._('clock-circle-linear');
  static const visibility = AnchIconData._('eye-linear');
  static const visibilityOff = AnchIconData._('eye-closed-linear');
  static const warning = AnchIconData._('clock-circle-linear');

  // 资料类型：统一使用 Bold Duotone。
  static const idCard = AnchIconData._('user-id-bold-duotone');
  static const householdBook = AnchIconData._('notebook-bold-duotone');
  static const passport = AnchIconData._('passport-bold-duotone');
  static const hkMacaoPass = AnchIconData._(
    'passport-minimalistic-bold-duotone',
  );
  static const driverLicense = AnchIconData._('card-2-bold-duotone');
  static const vehicleLicense = AnchIconData._('document-text-bold-duotone');
  static const birthCertificate = AnchIconData._(
    'document-medicine-bold-duotone',
  );
  static const marriageCertificate = AnchIconData._(
    'clipboard-heart-bold-duotone',
  );
  static const debitCard = AnchIconData._('wallet-money-bold-duotone');
  static const creditCard = AnchIconData._('card-bold-duotone');
  static const insurance = AnchIconData._('shield-user-bold-duotone');
  static const propertyCertificate = AnchIconData._('buildings-3-bold-duotone');
  static const educationCertificate = AnchIconData._(
    'diploma-verified-bold-duotone',
  );
  static const generic = AnchIconData._('documents-minimalistic-bold-duotone');
  static const shippingAddress = AnchIconData._('map-point-bold-duotone');

  static const Map<String, AnchIconData> _typeIcons = {
    'id_card': idCard,
    'household_book': householdBook,
    'passport': passport,
    'hk_macao_pass': hkMacaoPass,
    'driver_license': driverLicense,
    'vehicle_license': vehicleLicense,
    'birth_certificate': birthCertificate,
    'marriage_certificate': marriageCertificate,
    'debit_card': debitCard,
    'credit_card': creditCard,
    'insurance': insurance,
    'property_certificate': propertyCertificate,
    'education_certificate': educationCertificate,
    'generic': generic,
    'shipping_address': shippingAddress,
  };

  static const List<AnchIconData> allTypeIcons = [
    idCard,
    householdBook,
    passport,
    hkMacaoPass,
    driverLicense,
    vehicleLicense,
    birthCertificate,
    marriageCertificate,
    debitCard,
    creditCard,
    insurance,
    propertyCertificate,
    educationCertificate,
    generic,
    shippingAddress,
  ];

  static AnchIconData forTypeKey(String? typeKey) =>
      _typeIcons[typeKey] ?? generic;

  static AnchIconData forCategoryKey(String? categoryKey) {
    switch (categoryKey) {
      case 'certificate':
        return generic;
      case 'card':
        return debitCard;
      case 'insurance':
        return insurance;
      default:
        return folder;
    }
  }

  static AnchIconData forMember({required bool isFamily}) =>
      isFamily ? members : member;

  // 底部导航：默认 Linear，选中切换同图形 Bold。
  static const homeNavigation = AnchNavigationIconData(
    normal: AnchIconData._('home-2-linear'),
    selected: AnchIconData._('home-2-bold'),
  );
  static const memberNavigation = AnchNavigationIconData(
    normal: AnchIconData._('users-group-rounded-linear'),
    selected: AnchIconData._('users-group-rounded-bold'),
  );
  static const documentNavigation = AnchNavigationIconData(
    normal: AnchIconData._('folder-with-files-linear'),
    selected: AnchIconData._('folder-with-files-bold'),
  );
  static const settingsNavigation = AnchNavigationIconData(
    normal: AnchIconData._('settings-minimalistic-linear'),
    selected: AnchIconData._('settings-minimalistic-bold'),
  );
}
