class DefaultTemplateCategory {
  final String id;
  final String name;
  final String colorHex;
  final String emoji;
  final int order;
  final List<DefaultTemplateSubCategory> subCategories;

  const DefaultTemplateCategory({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.emoji,
    required this.order,
    required this.subCategories,
  });
}

class DefaultTemplateSubCategory {
  final String id;
  final String name;
  final String emoji;
  final int order;

  const DefaultTemplateSubCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.order,
  });
}

class DefaultCategoriesData {
  static const List<DefaultTemplateCategory> defaultList = [
    DefaultTemplateCategory(
      id: 'cat_living',
      name: 'การใช้ชีวิต & ที่พักอาศัย (Living)',
      colorHex: '#FF5722',
      emoji: '🏠',
      order: 1,
      subCategories: [
        DefaultTemplateSubCategory(id: 'sub_food_regular', name: 'อาหารมื้อปกติ', emoji: '🍱', order: 1),
        DefaultTemplateSubCategory(id: 'sub_drink_snack', name: 'ค่าน้ำ / ชา / กาแฟ / ขนม', emoji: '🧋', order: 2),
        DefaultTemplateSubCategory(id: 'sub_rent_mortgage', name: 'ค่าเช่าห้อง / ค่าผ่อนบ้าน', emoji: '🏡', order: 3),
        DefaultTemplateSubCategory(id: 'sub_utilities', name: 'ค่าน้ำ / ค่าไฟ / อินเทอร์เน็ต', emoji: '💡', order: 4),
        DefaultTemplateSubCategory(id: 'sub_groceries', name: 'ของใช้ในบ้าน / ซูเปอร์มาร์เก็ต', emoji: '🛒', order: 5),
      ],
    ),
    DefaultTemplateCategory(
      id: 'cat_transport',
      name: 'การเดินทาง (Transport)',
      colorHex: '#FF9800',
      emoji: '🚗',
      order: 2,
      subCategories: [
        DefaultTemplateSubCategory(id: 'sub_fuel', name: 'ค่าน้ำมันรถ', emoji: '⛽', order: 1),
        DefaultTemplateSubCategory(id: 'sub_public_transit', name: 'รถไฟฟ้า / รถเมล์ / Taxi', emoji: '🚇', order: 2),
        DefaultTemplateSubCategory(id: 'sub_toll_parking', name: 'ค่าทางด่วน / ที่จอดรถ', emoji: '🛣️', order: 3),
        DefaultTemplateSubCategory(id: 'sub_car_maintenance', name: 'ซ่อมบำรุง / พ.ร.บ. / ประกันรถ', emoji: '🔧', order: 4),
      ],
    ),
    DefaultTemplateCategory(
      id: 'cat_work_income',
      name: 'รายได้ & เงินเดือน (Income)',
      colorHex: '#4CAF50',
      emoji: '💰',
      order: 3,
      subCategories: [
        DefaultTemplateSubCategory(id: 'sub_salary', name: 'เงินเดือนประจำ', emoji: '💵', order: 1),
        DefaultTemplateSubCategory(id: 'sub_bonus', name: 'โบนัส / เงินพิเศษ', emoji: '🎁', order: 2),
        DefaultTemplateSubCategory(id: 'sub_freelance', name: 'ฟรีแลนซ์ / รายได้เสริม', emoji: '💻', order: 3),
        DefaultTemplateSubCategory(id: 'sub_dividends', name: 'เงินปันผล / กำไรจากการลงทุน', emoji: '📈', order: 4),
        DefaultTemplateSubCategory(id: 'sub_other_income', name: 'รายรับอื่นๆ', emoji: '✨', order: 5),
      ],
    ),
    DefaultTemplateCategory(
      id: 'cat_shopping',
      name: 'ช้อปปิ้ง & ของส่วนตัว (Shopping)',
      colorHex: '#9C27B0',
      emoji: '🛍️',
      order: 4,
      subCategories: [
        DefaultTemplateSubCategory(id: 'sub_clothes', name: 'เสื้อผ้า / เครื่องแต่งกาย', emoji: '👗', order: 1),
        DefaultTemplateSubCategory(id: 'sub_gadgets', name: 'อุปกรณ์ไอที / แกดเจ็ต', emoji: '📱', order: 2),
        DefaultTemplateSubCategory(id: 'sub_beauty', name: 'เครื่องสำอาง / สกินแคร์', emoji: '💄', order: 3),
        DefaultTemplateSubCategory(id: 'sub_books_courses', name: 'หนังสือ / คอร์สเรียน', emoji: '📚', order: 4),
      ],
    ),
    DefaultTemplateCategory(
      id: 'cat_entertainment',
      name: 'สันทนาการ & ความบันเทิง (Leisure)',
      colorHex: '#E91E63',
      emoji: '🎉',
      order: 5,
      subCategories: [
        DefaultTemplateSubCategory(id: 'sub_dining_party', name: 'สังสรรค์ / บุฟเฟต์ / มื้อพิเศษ', emoji: '🍻', order: 1),
        DefaultTemplateSubCategory(id: 'sub_travel', name: 'ท่องเที่ยว / โรงแรม / ตั๋วเครื่องบิน', emoji: '✈️', order: 2),
        DefaultTemplateSubCategory(id: 'sub_streaming_games', name: 'Netflix / Spotify / เติมเกม', emoji: '🎮', order: 3),
        DefaultTemplateSubCategory(id: 'sub_movies_events', name: 'ดูหนัง / คอนเสิร์ต / อีเวนต์', emoji: '🎬', order: 4),
      ],
    ),
    DefaultTemplateCategory(
      id: 'cat_health',
      name: 'สุขภาพ & การแพทย์ (Health)',
      colorHex: '#00BCD4',
      emoji: '🏥',
      order: 6,
      subCategories: [
        DefaultTemplateSubCategory(id: 'sub_doctor_med', name: 'ค่ายา / พบแพทย์ / คลินิก', emoji: '💊', order: 1),
        DefaultTemplateSubCategory(id: 'sub_health_insurance', name: 'เบี้ยประกันสุขภาพ (ลดหย่อนภาษี)', emoji: '🛡️', order: 2),
        DefaultTemplateSubCategory(id: 'sub_fitness', name: 'ฟิตเนส / กีฬา / อาหารเสริม', emoji: '🏋️', order: 3),
      ],
    ),
    DefaultTemplateCategory(
      id: 'cat_tax_investment',
      name: 'การออม & กองทุนลดหย่อนภาษี (Tax & Invest)',
      colorHex: '#7B1FA2',
      emoji: '📊',
      order: 7,
      subCategories: [
        DefaultTemplateSubCategory(id: 'sub_tax_ssf_rmf', name: 'กองทุน SSF / RMF / ThaiESG', emoji: '🏛️', order: 1),
        DefaultTemplateSubCategory(id: 'sub_life_insurance', name: 'เบี้ยประกันชีวิต / ประกันบำนาญ', emoji: '📄', order: 2),
        DefaultTemplateSubCategory(id: 'sub_donation', name: 'เงินบริจาค (วัด/โรงพยาบาล/การศึกษา)', emoji: '🙏', order: 3),
        DefaultTemplateSubCategory(id: 'sub_savings', name: 'เงินฝากประจำ / สลากออมทรัพย์', emoji: '🏦', order: 4),
      ],
    ),
  ];

  static const List<Map<String, dynamic>> defaultWallets = [
    {
      'id': 'wallet_kbank',
      'name': 'KBank (กสิกรไทย)',
      'color': '#00A950',
      'icon': 'account_balance',
      'startingBalance': 0.0,
    },
    {
      'id': 'wallet_scb',
      'name': 'SCB (ไทยพาณิชย์)',
      'color': '#4E2A84',
      'icon': 'account_balance',
      'startingBalance': 0.0,
    },
    {
      'id': 'wallet_cash',
      'name': 'เงินสด (Cash)',
      'color': '#2E7D32',
      'icon': 'payments',
      'startingBalance': 0.0,
    },
    {
      'id': 'wallet_credit_card',
      'name': 'บัตรเครดิต (Credit Card)',
      'color': '#1565C0',
      'icon': 'credit_card',
      'startingBalance': 0.0,
    },
  ];
}
