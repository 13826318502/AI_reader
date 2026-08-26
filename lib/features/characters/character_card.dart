part of '../../main.dart';

class CharacterCard extends StatelessWidget {
  final String name;
  final String role;
  final String intro;
  final String image;
  final String? workTitle;
  final String? characterId;
  final String appearance;
  final String personality;
  final String background;
  final String goal;
  final String firstAppearance;
  const CharacterCard({
    required this.name,
    required this.role,
    required this.image,
    this.intro = '故事中的重要角色。',
    this.workTitle,
    this.characterId,
    this.appearance = '',
    this.personality = '',
    this.background = '',
    this.goal = '',
    this.firstAppearance = '',
    super.key,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Color(0xFFE5D8C2)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CharacterDetailPage(
            name: name,
            role: role,
            image: image,
            intro: intro,
            workTitle: workTitle,
            characterId: characterId,
            appearance: appearance,
            personality: personality,
            characterBackground: background,
            goal: goal,
            firstAppearance: firstAppearance,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 72,
                height: 96,
                child: AiImagePreview(image: image),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primaryText,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (intro.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      intro,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: mutedText,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
