part of '../../main.dart';

class _WorkCharacter {
  final String id;
  final String name;
  final String role;
  final String intro;
  final String appearance;
  final String personality;
  final String background;
  final String goal;
  final String firstAppearance;
  final String image;

  const _WorkCharacter({
    required this.id,
    required this.name,
    required this.role,
    required this.intro,
    this.appearance = '',
    this.personality = '',
    this.background = '',
    this.goal = '',
    this.firstAppearance = '',
    this.image = 'assets/ai_portrait.png',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role,
    'intro': intro,
    'appearance': appearance,
    'personality': personality,
    'background': background,
    'goal': goal,
    'first_appearance': firstAppearance,
    'image': image,
  };

  factory _WorkCharacter.fromJson(Map<String, dynamic> json) => _WorkCharacter(
    id:
        json['id']?.toString() ??
        DateTime.now().microsecondsSinceEpoch.toString(),
    name: json['name']?.toString() ?? '未命名角色',
    role: json['role']?.toString() ?? '角色',
    intro: json['intro']?.toString() ?? '',
    appearance: json['appearance']?.toString() ?? '',
    personality: json['personality']?.toString() ?? '',
    background: json['background']?.toString() ?? '',
    goal: json['goal']?.toString() ?? '',
    firstAppearance: json['first_appearance']?.toString() ?? '',
    image: json['image']?.toString() ?? 'assets/ai_portrait.png',
  );
}
