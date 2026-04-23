import 'package:flutter/material.dart';

import 'project_style.dart';

class ProjectStyles {
  static const Map<String, List<String>> _standardCategories = {
    '🎹 Клавиши': [
      'Пианино',
      'Яркое пианино',
      'Электропианино',
    ],
    '🔔 Колокольчики': [
      'Челеста',
      'Музыкальная шкатулка',
      'Маримба',
      'Ситар',
      'Кристалл',
    ],
    '🏰 Органы': [
      'Орган',
      'Перкуссионный орган',
      'Рок-орган',
      'Церковный орган',
      'Губная гармошка',
    ],
    '🎸 Гитары': [
      'Нейлоновая гитара',
      'Стальная гитара',
      'Джаз-гитара',
      'Чистая гитара',
      'Овердрайв гитара',
      'Дисторшн гитара',
    ],
    '🎸 Басы': [
      'Акустический бас',
      'Звонкий бас',
      'Синт-бас',
    ],
    '🎻 Струнные': [
      'Скрипка',
      'Виолончель',
      'Приглушённые струны',
      'Струнный ансамбль',
      'Терменвокс',
    ],
    '🗣️ Хор': [
      'Хор "Аа"',
      'Хор "Оо"',
    ],
    '🎷 Духовые': [
      'Тромбон',
      'Сопрано саксофон',
      'Кларнет',
      'Флейта',
      'Пан-флейта',
      'Свист',
    ],
    '🎛️ Синтезаторы': [
      'Волна Квадрат',
      'Волна Пила',
      'Полисинт',
      'Моносинт',
    ],
    '🌌 Атмосфера': [
      'Фантазия',
      'Стеклянный смычок',
      'Метал',
    ],
    '🥁 Перкуссия': [
      'Бочка',
      'Бочка 2',
      'Том',
      'Ударные',
    ],
    '🔊 FX звуки': [
      'Шум ладов гитары',
      'Пение птиц',
      'Телефон',
      'Вертолёт',
      'Аплодисменты',
    ],
  };

  static const List<Color> _standardPalette = [
    Colors.red,
    Color.fromARGB(255, 255, 0, 174),
    Colors.purple,
    Color.fromARGB(255, 59, 127, 223),
    Colors.blue,
  ];

  static const List<Color> _rockPalette = [
    Colors.red,
    Color(0xFFFF7043),
    Color(0xFFFF5252),
    Color(0xFFEF5350),
    Color(0xFFFF8A65),
    Color(0xFFE53935),
  ];

  static const List<Color> _electroPalette = [
    Colors.deepPurple,
    Color(0xFF7C4DFF),
    Color(0xFF673AB7),
    Color(0xFF9575CD),
    Color(0xFF512DA8),
    Color(0xFFB388FF),
  ];

  static const List<Color> _classicPalette = [
    Colors.indigo,
    Color(0xFF5C6BC0),
    Color(0xFF7986CB),
    Color(0xFF3949AB),
    Color(0xFF283593),
    Color(0xFF9FA8DA),
  ];

  static const ProjectStyle standard = ProjectStyle(
    type: ProjectStyleType.standard,
    id: 'standard',
    displayName: 'Проект',
    backgroundAsset: 'assets/background_dark.jpg',
    primaryColor: Colors.orangeAccent,
    secondaryColor: Colors.amber,
    trackPalette: _standardPalette,
    instrumentCategories: _standardCategories,
    starterTracks: [],
  );

  static const ProjectStyle rock = ProjectStyle(
    type: ProjectStyleType.rock,
    id: 'rock',
    displayName: 'Rock',
    backgroundAsset: 'assets/rock_background.jpg',
    primaryColor: Colors.red,
    secondaryColor: Colors.orange,
    trackPalette: _rockPalette,
    instrumentCategories: {
      '🎸 Гитары': [
        'Стальная гитара',
        'Чистая гитара',
        'Овердрайв гитара',
        'Дисторшн гитара',
      ],
      '🎸 Басы': [
        'Акустический бас',
        'Звонкий бас',
      ],
      '🏰 Рок и органы': [
        'Рок-орган',
        'Перкуссионный орган',
        'Орган',
        'Губная гармошка',
      ],
      '🥁 Ритм-секция': [
        'Бочка',
        'Бочка 2',
        'Том',
        'Ударные',
      ],
      '🎻 Подложка': [
        'Скрипка',
        'Виолончель',
        'Струнный ансамбль',
        'Хор "Аа"',
      ],
    },
    starterTracks: [
      DefaultTrackTemplate(name: 'Ритм-гитара', instrument: 'Овердрайв гитара'),
      DefaultTrackTemplate(name: 'Соло-гитара', instrument: 'Дисторшн гитара'),
      DefaultTrackTemplate(name: 'Бас', instrument: 'Акустический бас'),
      DefaultTrackTemplate(name: 'Барабаны', instrument: 'Ударные'),
    ],
  );

  static const ProjectStyle electro = ProjectStyle(
    type: ProjectStyleType.electro,
    id: 'electro',
    displayName: 'Electro',
    backgroundAsset: 'assets/electro_background.jpg',
    primaryColor: Colors.deepPurple,
    secondaryColor: Color(0xFFB388FF),
    trackPalette: _electroPalette,
    instrumentCategories: {
      '🎛️ Синты': [
        'Волна Квадрат',
        'Волна Пила',
        'Полисинт',
        'Моносинт',
      ],
      '🎹 Электро-клавиши': [
        'Электропианино',
        'Пианино',
        'Челеста',
        'Кристалл',
      ],
      '🌌 Атмосфера и FX': [
        'Фантазия',
        'Стеклянный смычок',
        'Метал',
        'Телефон',
        'Вертолёт',
      ],
      '🎸 Бас и ритм': [
        'Синт-бас',
        'Звонкий бас',
        'Бочка',
        'Бочка 2',
        'Ударные',
      ],
    },
    starterTracks: [
      DefaultTrackTemplate(name: 'Lead', instrument: 'Полисинт'),
      DefaultTrackTemplate(name: 'Bass', instrument: 'Синт-бас'),
      DefaultTrackTemplate(name: 'Pad', instrument: 'Фантазия'),
      DefaultTrackTemplate(name: 'Beat', instrument: 'Бочка'),
    ],
  );

  static const ProjectStyle classic = ProjectStyle(
    type: ProjectStyleType.classic,
    id: 'classic',
    displayName: 'Classic',
    backgroundAsset: 'assets/background.jpg',
    primaryColor: Colors.indigo,
    secondaryColor: Color(0xFF9FA8DA),
    trackPalette: _classicPalette,
    instrumentCategories: {
      '🎹 Клавиши': [
        'Пианино',
        'Яркое пианино',
        'Орган',
        'Церковный орган',
      ],
      '🎻 Струнные': [
        'Скрипка',
        'Виолончель',
        'Приглушённые струны',
        'Струнный ансамбль',
      ],
      '🎷 Духовые': [
        'Кларнет',
        'Флейта',
        'Пан-флейта',
        'Тромбон',
      ],
      '🗣️ Хор и тембры': [
        'Хор "Аа"',
        'Хор "Оо"',
        'Челеста',
        'Музыкальная шкатулка',
      ],
    },
    starterTracks: [
      DefaultTrackTemplate(name: 'Пианино', instrument: 'Пианино'),
      DefaultTrackTemplate(name: 'Скрипка', instrument: 'Скрипка'),
      DefaultTrackTemplate(name: 'Виолончель', instrument: 'Виолончель'),
      DefaultTrackTemplate(name: 'Флейта', instrument: 'Флейта'),
    ],
  );

  static const List<ProjectStyle> all = [
    standard,
    rock,
    electro,
    classic,
  ];

  static ProjectStyle byType(ProjectStyleType type) {
    switch (type) {
      case ProjectStyleType.rock:
        return rock;
      case ProjectStyleType.electro:
        return electro;
      case ProjectStyleType.classic:
        return classic;
      case ProjectStyleType.standard:
        return standard;
    }
  }

  static ProjectStyle byId(String? id) {
    switch (id) {
      case 'rock':
        return rock;
      case 'electro':
        return electro;
      case 'classic':
        return classic;
      case 'standard':
      default:
        return standard;
    }
  }
}
