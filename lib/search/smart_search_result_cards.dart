import 'package:flutter/material.dart';

import '../branding/ghadeer_brand_mark.dart';
import '../models/lab_models.dart';
import '../theme/ghadeer_tokens.dart';
import 'smart_search_models.dart';

/// بطاقات نتائج البحث الحقيقية حسب النوع.
class SmartSearchResultCard extends StatelessWidget {
  const SmartSearchResultCard({
    super.key,
    required this.result,
    required this.onTap,
  });

  final SmartSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    switch (result.type) {
      case SmartSearchResultType.doctor:
        return _DoctorCard(result: result, onTap: onTap);
      case SmartSearchResultType.lab:
        return _LabCard(result: result, onTap: onTap);
      case SmartSearchResultType.radiology:
        return _LabCard(result: result, onTap: onTap);
      case SmartSearchResultType.pharmacy:
        return _LabCard(result: result, onTap: onTap);
      case SmartSearchResultType.physio:
        return _LabCard(result: result, onTap: onTap);
      case SmartSearchResultType.supply:
      case SmartSearchResultType.optics:
      case SmartSearchResultType.beauty:
      case SmartSearchResultType.nursing:
        return _LabCard(result: result, onTap: onTap);
      case SmartSearchResultType.package:
      case SmartSearchResultType.offer:
        return _PackageOfferCard(result: result, onTap: onTap);
      case SmartSearchResultType.analysis:
        return _AnalysisCard(result: result, onTap: onTap);
      case SmartSearchResultType.specialty:
        return _SpecialtyCard(result: result, onTap: onTap);
    }
  }
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({required this.result, required this.onTap});

  final SmartSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GhadeerTokens.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(url: result.imageUrl, fallback: Icons.person_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: GhadeerTokens.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.specialty ?? result.subtitle,
                      style: const TextStyle(
                        color: GhadeerTokens.tealDeep,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    if ((result.bioSnippet ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        result.bioSnippet!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: GhadeerTokens.inkMuted,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (result.isOnLeave &&
                            (result.absenceBadge ?? '').isNotEmpty)
                          _Badge(
                            label: result.absenceBadge!,
                            color: GhadeerTokens.warn,
                            bg: GhadeerTokens.warnWash,
                          )
                        else if ((result.availabilityLabel ?? '').isNotEmpty)
                          _Badge(
                            label: result.availabilityLabel!,
                            color: GhadeerTokens.tealDeep,
                            bg: GhadeerTokens.tealWash,
                          ),
                      ],
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

class _LabCard extends StatelessWidget {
  const _LabCard({required this.result, required this.onTap});

  final SmartSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GhadeerTokens.line),
          ),
          child: Row(
            children: [
              _Avatar(url: result.imageUrl, fallback: Icons.biotech_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: GhadeerTokens.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: GhadeerTokens.inkMuted,
                        fontSize: 12.5,
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

class _PackageOfferCard extends StatelessWidget {
  const _PackageOfferCard({required this.result, required this.onTap});

  final SmartSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isOffer = result.isOffer;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOffer ? const Color(0xFFB7E4C7) : GhadeerTokens.line,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(
                url: result.imageUrl,
                fallback: isOffer
                    ? Icons.local_offer_rounded
                    : Icons.inventory_2_outlined,
                size: 72,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isOffer)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: _Badge(
                          label: 'عرض',
                          color: GhadeerTokens.ok,
                          bg: GhadeerTokens.okWash,
                        ),
                      ),
                    Text(
                      result.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: GhadeerTokens.ink,
                      ),
                    ),
                    if ((result.labName ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        result.labName!,
                        style: const TextStyle(
                          color: GhadeerTokens.tealDeep,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    if ((result.relatedAnalysisTitle ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'تشمل: ${result.relatedAnalysisTitle}',
                        style: const TextStyle(
                          color: GhadeerTokens.inkMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if ((result.bioSnippet ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        result.bioSnippet!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: GhadeerTokens.inkMuted,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (result.discountPercent != null)
                          _Badge(
                            label: '${result.discountPercent}% خصم',
                            color: GhadeerTokens.ok,
                            bg: GhadeerTokens.okWash,
                          ),
                        if (result.newPrice != null)
                          Text(
                            '${formatLabPrice(result.newPrice)} د.ع',
                            style: const TextStyle(
                              color: GhadeerTokens.tealDeep,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        if (result.oldPrice != null &&
                            result.newPrice != null &&
                            result.oldPrice! > result.newPrice!)
                          Text(
                            '${formatLabPrice(result.oldPrice)} د.ع',
                            style: const TextStyle(
                              color: GhadeerTokens.inkFaint,
                              fontSize: 12.5,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                      ],
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

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({required this.result, required this.onTap});

  final SmartSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GhadeerTokens.mist,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GhadeerTokens.line),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: GhadeerTokens.tealWash,
                child: Icon(
                  Icons.science_outlined,
                  color: GhadeerTokens.tealDeep,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: GhadeerTokens.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.subtitle,
                      style: const TextStyle(
                        color: GhadeerTokens.inkMuted,
                        fontSize: 12.5,
                      ),
                    ),
                    if ((result.bioSnippet ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        result.bioSnippet!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: GhadeerTokens.inkMuted,
                          fontSize: 12,
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
}

class _SpecialtyCard extends StatelessWidget {
  const _SpecialtyCard({required this.result, required this.onTap});

  final SmartSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GhadeerTokens.line),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: GhadeerTokens.tealWash,
                child: Icon(
                  Icons.medical_services_outlined,
                  color: GhadeerTokens.tealDeep,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Text(
                      'اضغط لعرض أطباء هذا الاختصاص',
                      style: TextStyle(
                        color: GhadeerTokens.inkMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left_rounded,
                color: GhadeerTokens.tealDeep,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.fallback, this.size = 56});

  final String? url;
  final IconData fallback;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasUrl = (url ?? '').trim().isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: size,
        height: size,
        color: GhadeerTokens.tealWash,
        child: hasUrl
            ? GhadeerResolvedImage(
                url!.trim(),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Icon(fallback, color: GhadeerTokens.tealDeep),
              )
            : Icon(fallback, color: GhadeerTokens.tealDeep),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.bg});

  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
