import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/result.dart';
import '../../core/settings_storage.dart';
import '../../features/feed/feed_controller.dart';
import '../../models/post.dart';

class PostVoteSection extends ConsumerStatefulWidget {
  const PostVoteSection({
    super.key,
    required this.postId,
    this.rating,
    this.borodaCount,
    this.parsedVote,
    this.parsedBoroda,
    this.onRatingChanged,
  });

  final int postId;
  final PostRating? rating;
  final int? borodaCount;
  final int? parsedVote;
  final bool? parsedBoroda;
  final void Function(PostRating rating, int? borodaCount)? onRatingChanged;

  @override
  ConsumerState<PostVoteSection> createState() => _PostVoteSectionState();
}

class _PostVoteSectionState extends ConsumerState<PostVoteSection> {
  static final _ratingRe = RegExp(r'([+-]?\d+)\|(\d+)\|([+-]?\d+)\s*=\s*([+-]?\d+)%');

  PostRating? _rating;
  int? _borodaCount;
  int? _vote;
  int? _boroda;
  bool _votingVote = false;
  bool _votingBoroda = false;

  String get _vKey => 'v_${widget.postId}';
  String get _bKey => 'b_${widget.postId}';

  @override
  void initState() {
    super.initState();
    _rating = widget.rating;
    _borodaCount = widget.borodaCount;
    final box = ref.read(votesBoxProvider);
    final v = box.get(_vKey);
    final b = box.get(_bKey);
    if (v != null) {
      _vote = int.tryParse(v);
    } else if (widget.parsedVote != null) {
      _vote = widget.parsedVote;
      box.put(_vKey, '${widget.parsedVote}');
    }
    if (widget.parsedBoroda == false) {
      // Server explicitly says not voted — clear stale local entry
      box.delete(_bKey);
    } else if (b != null) {
      _boroda = int.tryParse(b);
    } else if (widget.parsedBoroda == true) {
      _boroda = 0;
      box.put(_bKey, '0');
    }
  }

  Future<void> _doVote(int value) async {
    if (_vote != null || _votingVote) return;
    setState(() => _votingVote = true);
    final result = await ref.read(repositoryProvider).vote(widget.postId, value);
    if (!mounted) return;
    if (result.isOk) await ref.read(votesBoxProvider).put(_vKey, '$value');
    final newRating = result.valueOrNull != null ? _parseRating(result.valueOrNull!) : null;
    setState(() {
      _votingVote = false;
      if (result.isOk) {
        _vote = value;
        if (newRating != null) {
          _rating = newRating;
          widget.onRatingChanged?.call(_rating!, _borodaCount);
        }
      }
    });
  }

  Future<void> _doBoroda(int value) async {
    if (_boroda != null || _votingBoroda) return;
    setState(() => _votingBoroda = true);
    final result = await ref.read(repositoryProvider).boroda(widget.postId, value);
    if (!mounted) return;
    if (result.isOk) await ref.read(votesBoxProvider).put(_bKey, '$value');
    final newCount = int.tryParse(result.valueOrNull?.trim() ?? '');
    setState(() {
      _votingBoroda = false;
      if (result.isOk) {
        _boroda = value;
        if (newCount != null) {
          _borodaCount = newCount;
          if (_rating != null) widget.onRatingChanged?.call(_rating!, _borodaCount);
        }
      }
    });
  }

  PostRating? _parseRating(String s) {
    final m = _ratingRe.firstMatch(s);
    if (m == null) return null;
    return PostRating(
      plus: int.parse(m.group(1)!),
      neutral: int.parse(m.group(2)!),
      minus: int.parse(m.group(3)!),
      percentage: int.parse(m.group(4)!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.outline;
    final primary = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_vote == null) ...[
                _Btn('? я чото п',  null,                        _votingVote ? null : () => _doVote(0),  color),
                _Btn('ЗАЧОТ',       'assets/icons/vote.png',     _votingVote ? null : () => _doVote(1),  color),
                _Btn('КГ/АМ',       'assets/icons/vote.png',     _votingVote ? null : () => _doVote(-1), color),
              ] else
                _VotedChip(_voteLabel(_vote!), _vote != 0 ? 'assets/icons/vote.png' : null, primary),
              const SizedBox(width: 8),
              if (_boroda == null) ...[
                _Btn('борода!',     'assets/icons/boroda.png',    _votingBoroda ? null : () => _doBoroda(0), color),
                _Btn('МЕГАборода!', 'assets/icons/megaboroda.png', _votingBoroda ? null : () => _doBoroda(1), color),
              ] else
                _VotedChip(_borodaLabel(_boroda!), _boroda == 1 ? 'assets/icons/megaboroda.png' : 'assets/icons/boroda.png', primary),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }


  static String _voteLabel(int v) => switch (v) {
        1  => 'зачот',
        -1 => 'КГ/АМ',
        _  => '? я чото п',
      };

  static String _borodaLabel(int v) => v == 1 ? 'МЕГАборода!' : 'борода!';
}

class _VotedChip extends StatelessWidget {
  const _VotedChip(this.label, this.iconAsset, this.color);

  final String label;
  final String? iconAsset;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconAsset != null) ...[
            Image.asset(iconAsset!, width: 14, height: 14),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn(this.label, this.iconAsset, this.onTap, this.color);

  final String label;
  final String? iconAsset;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconAsset != null) ...[
              Opacity(
                opacity: onTap != null ? 1.0 : 0.4,
                child: Image.asset(iconAsset!, width: 12, height: 12),
              ),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: onTap != null ? color : color.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
