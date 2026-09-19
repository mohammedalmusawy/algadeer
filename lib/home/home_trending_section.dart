import 'package:flutter/material.dart';

import 'trending_entity.dart';

/// قسم أفقي: الأكثر طلبًا (أطباء أو مختبرات).
class HomeTrendingSection extends StatelessWidget {
  const HomeTrendingSection({
    super.key,
    required this.title,
    required this.items,
    required this.onOpen,
    this.loading = false,
    this.emptyHint = 'لا توجد بيانات طلب كافية بعد',
  });

  final String title;
  final List<TrendingEntity> items;
  final ValueChanged<TrendingEntity> onOpen;
  final bool loading;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    if (!loading && items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 18,
                  color: Color(0xFFE11D48),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF123B42),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (loading)
            const SizedBox(
              height: 96,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            )
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                emptyHint,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF6B7C80),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _TrendingChip(
                    rank: index + 1,
                    item: item,
                    onTap: () => onOpen(item),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TrendingChip extends StatelessWidget {
  const _TrendingChip({
    required this.rank,
    required this.item,
    required this.onTap,
  });

  final int rank;
  final TrendingEntity item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = item.imageUrl?.trim() ?? '';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 210,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4EEEE)),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: image.isEmpty
                          ? ColoredBox(
                              color: const Color(0xFFE8F7F5),
                              child: Icon(
                                item.kind == 'lab'
                                    ? Icons.science_outlined
                                    : item.kind == 'package'
                                        ? Icons.card_giftcard_rounded
                                        : Icons.person_outline_rounded,
                                color: const Color(0xFF0FAFA3),
                              ),
                            )
                          : Image.network(
                              image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const ColoredBox(
                                color: Color(0xFFE8F7F5),
                                child: Icon(
                                  Icons.person_outline_rounded,
                                  color: Color(0xFF0FAFA3),
                                ),
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE11D48),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$rank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF123B42),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5B6C70),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.profileViews} مشاهدة',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0FAFA3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
