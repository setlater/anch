import 'package:anch/core/service/shipping_address_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShippingAddressParser', () {
    test('解析带字段名的多行地址', () {
      final result = ShippingAddressParser.parse('''
收件人：张三
手机号码：138 0013 8000
所在地区：浙江省杭州市西湖区
详细地址：文三路 90 号 2 幢 301 室
''');

      expect(result.recipientName, '张三');
      expect(result.phoneNumber, '13800138000');
      expect(result.region, '浙江省杭州市西湖区');
      expect(result.detailedAddress, '文三路 90 号 2 幢 301 室');
    });

    test('收货人标签作为收件人解析', () {
      final result = ShippingAddressParser.parse('''
收货人：张三
手机号：13800138000
所在地区：浙江省杭州市西湖区
详细地址：文三路90号
''');

      expect(result.recipientName, '张三');
      expect(
        result.fieldConfidence['recipient_name'],
        ShippingAddressFieldConfidence.confirmed,
      );
    });

    test('解析电商常见的无字段名单行地址', () {
      final result = ShippingAddressParser.parse(
        '张三 13800138000 浙江省杭州市西湖区文三路90号2幢301室',
      );

      expect(result.recipientName, '张三');
      expect(result.phoneNumber, '13800138000');
      expect(result.region, '浙江省杭州市西湖区');
      expect(result.detailedAddress, '文三路90号2幢301室');
    });

    test('解析直辖市地址', () {
      final result = ShippingAddressParser.parse('王五，18600001111，北京市朝阳区建国路88号');

      expect(result.recipientName, '王五');
      expect(result.phoneNumber, '18600001111');
      expect(result.region, '北京市朝阳区');
      expect(result.detailedAddress, '建国路88号');
    });

    test('只有地址标签时仍拆分地区和详细地址', () {
      final result = ShippingAddressParser.parse(
        '收件人：赵六 手机号：13500001111 地址：广东省深圳市南山区科技园1号',
      );

      expect(result.recipientName, '赵六');
      expect(result.phoneNumber, '13500001111');
      expect(result.region, '广东省深圳市南山区');
      expect(result.detailedAddress, '科技园1号');
    });

    test('无法确定地区时不强拆地址', () {
      final result = ShippingAddressParser.parse(
        '李四 13900139000 高新区天府三街 199 号',
      );

      expect(result.recipientName, '');
      expect(result.phoneNumber, '13900139000');
      expect(result.region, '');
      expect(result.detailedAddress, '李四 高新区天府三街 199 号');
    });

    test('省市区省略后缀时按候选树补全标准地区', () {
      final result = ShippingAddressParser.parse('周一 13600001111 浙江杭州西湖文三路90号');

      expect(result.recipientName, '周一');
      expect(result.phoneNumber, '13600001111');
      expect(result.region, '浙江省杭州市西湖区');
      expect(result.detailedAddress, '文三路90号');
    });

    test('自治区和自治州使用完整上下级候选链', () {
      final result = ShippingAddressParser.parse(
        '钱二；+86 137 0000 1111；广西南宁青秀民族大道1号',
      );

      expect(result.recipientName, '钱二');
      expect(result.phoneNumber, '13700001111');
      expect(result.region, '广西壮族自治区南宁市青秀区');
      expect(result.detailedAddress, '民族大道1号');
    });

    test('直辖市省略市辖区时仍按上下级关系识别', () {
      final result = ShippingAddressParser.parse('孙七 18800001111 北京朝阳区建国路88号');

      expect(result.recipientName, '孙七');
      expect(result.phoneNumber, '18800001111');
      expect(result.region, '北京市朝阳区');
      expect(result.detailedAddress, '建国路88号');
    });

    test('只有同名区县时保持待确认，不静默猜测地区', () {
      final result = ShippingAddressParser.parse('吴八 13300001111 朝阳区示例路10号');

      expect(result.recipientName, '');
      expect(result.phoneNumber, '13300001111');
      expect(result.region, '');
      expect(result.detailedAddress, '吴八 朝阳区示例路10号');
    });

    test('字段标签优先且保留字段级确认状态', () {
      final result = ShippingAddressParser.parse('''
详细地址：示例园区A座3层
手机号码：86 135 0000 1111
所在地区：广东省深圳市南山区
联系人：赵九
''');

      expect(result.recipientName, '赵九');
      expect(result.phoneNumber, '13500001111');
      expect(result.region, '广东省深圳市南山区');
      expect(result.detailedAddress, '示例园区A座3层');
      expect(
        result.fieldConfidence['region'],
        ShippingAddressFieldConfidence.confirmed,
      );
    });
  });

  test('复制文本固定包含四个字段名并逐行输出', () {
    final text = ShippingAddressTextBuilder.build({
      'recipient_name': '张三',
      'phone_number': '13800138000',
      'region': '浙江省杭州市西湖区',
      'detailed_address': '文三路90号',
    });

    expect(
      text,
      '收件人：张三\n'
      '手机号码：13800138000\n'
      '所在地区：浙江省杭州市西湖区\n'
      '详细地址：文三路90号',
    );
  });
}
