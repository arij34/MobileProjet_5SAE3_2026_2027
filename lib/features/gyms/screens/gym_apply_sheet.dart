import 'package:flutter/material.dart';

import '../../users/services/user_service.dart' show AuthException;
import '../models/gym.dart';
import '../services/membership_service.dart';

/// Ouvre la fenêtre "Postuler". Renvoie true si la demande a été envoyée.
Future<bool> showApplySheet(BuildContext context, Gym gym) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ApplySheet(gym: gym),
  );
  return ok == true;
}

class _ApplySheet extends StatefulWidget {
  final Gym gym;
  const _ApplySheet({required this.gym});

  @override
  State<_ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends State<_ApplySheet> {
  static const _violetDark = Color(0xFF4C378E);
  static const _pink = Color(0xFFD43DA7);
  static const _lilac = Color(0xFFE8D8FC);
  static const _violet = Color(0xFFA86BEE);
  static const _textSecondary = Color(0xFF7A7390);

  int _months = 1;
  bool _sending = false;

  String _dt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await MembershipService.instance
          .apply(gymId: widget.gym.id!, months: _months);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Une erreur est survenue. Réessayez.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: _violetDark, content: Text(message)),
    );
  }

  Widget _option(int months) {
    final selected = _months == months;
    final discount = MembershipPricing.discountFor(months);
    final full = MembershipPricing.fullPrice(widget.gym.priceMonthly, months);
    final total = MembershipPricing.total(widget.gym.priceMonthly, months);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _sending ? null : () => setState(() => _months = months),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? _lilac : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? _violet : const Color(0xFFE2DDEA),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? _pink : _textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      months == 1 ? '1 mois' : '$months mois',
                      style: const TextStyle(
                          color: _violetDark, fontWeight: FontWeight.bold),
                    ),
                    if (discount > 0)
                      Text(
                        'Réduction de ${(discount * 100).round()} %',
                        style: const TextStyle(
                            color: Color(0xFF2E9E6B), fontSize: 12),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_dt(total)} DT',
                    style: const TextStyle(
                        color: _pink,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  if (discount > 0)
                    Text(
                      '${_dt(full)} DT',
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Color(0xFFEFEDF5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Postuler à ${widget.gym.name}',
                style: const TextStyle(
                    color: _violetDark,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.gym.city} · ${_dt(widget.gym.priceMonthly)} DT / mois',
                style: const TextStyle(color: _textSecondary),
              ),
              const SizedBox(height: 16),
              for (final m in MembershipPricing.durations) _option(m),
              const SizedBox(height: 4),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: _textSecondary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Le responsable de la salle examine votre demande. '
                      'Le paiement se fait sur place.',
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _sending ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: _sending
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Envoyer la demande'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
