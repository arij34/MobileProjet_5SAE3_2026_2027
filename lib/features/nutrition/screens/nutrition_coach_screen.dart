import 'package:flutter/material.dart';

import '../models/food.dart';
import '../repositories/food_repository.dart';
import '../repositories/meal_repository.dart';
import '../repositories/nutrition_repository.dart';
import '../services/nutrition_gemini_service.dart';
import '../widgets/chat_message.dart';
import '../widgets/nutrition_ui.dart';
import 'meal_form_screen.dart';

/// Un message affiché dans la conversation.
class _Msg {
  final bool fromUser;
  final String text;
  final ProposedMeal? proposal; // repas proposé (carte avec « Ajouter »)
  final bool isError;
  _Msg(this.fromUser, this.text, {this.proposal, this.isError = false});
}

/// Coach Nutrition IA (Gemini) : conversation personnalisée + génération de repas.
class NutritionCoachScreen extends StatefulWidget {
  const NutritionCoachScreen({super.key});

  @override
  State<NutritionCoachScreen> createState() => _NutritionCoachScreenState();
}

class _NutritionCoachScreenState extends State<NutritionCoachScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _messages = [];
  bool _sending = false;

  static const List<String> _suggestions = [
    'Propose-moi un repas riche en protéines.',
    'Je veux prendre de la masse, que dois-je manger ?',
    'Propose-moi un petit-déjeuner équilibré.',
    'Par quoi remplacer le poulet ?',
    'Analyse mon alimentation aujourd\'hui.',
    'Comment atteindre mon objectif de protéines ?',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(_Msg(false,
        'Bonjour 👋 Je suis votre coach nutrition. Posez-moi une question ou '
        'demandez-moi un repas adapté à vos objectifs.'));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<NutritionContext> _buildContext() async {
    final today = DateTime.now();
    final profile = await NutritionRepository.instance.getProfile();
    final totals = await MealRepository.instance.totalsForDate(today);
    final meals = await MealRepository.instance.getMealsForDate(today);
    return NutritionContext(profile: profile, today: totals, todayMeals: meals);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send(String text) async {
    final question = text.trim();
    if (question.isEmpty || _sending) return;
    _input.clear();
    setState(() {
      _messages.add(_Msg(true, question));
      _sending = true;
    });
    _scrollToEnd();

    try {
      final ctx = await _buildContext();
      // Historique = tours précédents (hors message d'accueil et erreurs).
      final history = _messages
          .where((m) => !m.isError && m.proposal == null)
          .skip(1) // message d'accueil
          .map((m) => ChatTurn(fromUser: m.fromUser, text: m.text))
          .toList();
      // On retire le dernier (la question courante déjà ajoutée) de l'historique.
      if (history.isNotEmpty) history.removeLast();

      final answer = await NutritionGeminiService.instance
          .chat(question: question, context: ctx, history: history);
      if (!mounted) return;
      setState(() => _messages.add(_Msg(false, answer)));
    } on NutritionAiException catch (e) {
      if (mounted) setState(() => _messages.add(_Msg(false, e.message, isError: true)));
    } catch (e) {
      if (mounted) {
        setState(() => _messages
            .add(_Msg(false, 'Une erreur est survenue. Réessayez.', isError: true)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  Future<void> _proposeMeal() async {
    if (_sending) return;
    setState(() {
      _messages.add(_Msg(true, '🍽️ Propose-moi un repas à ajouter.'));
      _sending = true;
    });
    _scrollToEnd();
    try {
      final ctx = await _buildContext();
      final List<Food> catalog = await FoodRepository.instance.getAll();
      final proposal = await NutritionGeminiService.instance.generateMeal(
        request: 'Propose un repas adapté à mon objectif.',
        context: ctx,
        catalog: catalog,
      );
      if (!mounted) return;
      if (proposal == null) {
        setState(() => _messages.add(_Msg(false,
            'Je n\'ai pas pu composer un repas exploitable. Réessayez.',
            isError: true)));
      } else {
        setState(() => _messages.add(_Msg(
            false, 'Voici une proposition de repas :',
            proposal: proposal)));
      }
    } on NutritionAiException catch (e) {
      if (mounted) setState(() => _messages.add(_Msg(false, e.message, isError: true)));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  Future<void> _addProposalToPlan(ProposedMeal proposal) async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MealFormScreen(date: DateTime.now(), proposal: proposal),
      ),
    );
    if (added == true && mounted) {
      showNSnack(context, 'Repas ajouté au journal.', color: NColors.calories);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: const [
              Icon(Icons.smart_toy, color: NColors.primary),
              SizedBox(width: 8),
              Text('Coach Nutrition IA',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: NColors.textDark)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: _messages.length + (_sending ? 1 : 0),
            itemBuilder: (_, i) {
              if (i >= _messages.length) return _typing();
              return _bubble(_messages[i]);
            },
          ),
        ),
        _suggestionsBar(),
        _inputBar(),
      ],
    );
  }

  Widget _bubble(_Msg m) {
    return ChatBubble(
      fromUser: m.fromUser,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m.isError)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 16, color: NColors.danger),
                const SizedBox(width: 6),
                Flexible(
                    child: Text(m.text,
                        style: const TextStyle(color: NColors.danger))),
              ],
            )
          else
            Text(m.text),
          if (m.proposal != null) _proposalCard(m.proposal!),
        ],
      ),
    );
  }

  Widget _proposalCard(ProposedMeal p) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NColors.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: NColors.textDark)),
          Text(p.suggestedType.label,
              style:
                  const TextStyle(color: NColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          ...p.items.map((it) => Text(
              '• ${it.food.name} — ${it.grams.round()} g',
              style: const TextStyle(color: NColors.textDark, fontSize: 13))),
          const SizedBox(height: 8),
          Text(
              '${p.calories.round()} kcal · P ${p.proteins.round()} / '
              'G ${p.carbs.round()} / L ${p.fats.round()}',
              style: const TextStyle(
                  color: NColors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 10),
          NButton(
              text: 'Ajouter au planning',
              icon: Icons.add,
              onPressed: () => _addProposalToPlan(p)),
        ],
      ),
    );
  }

  Widget _typing() => const Padding(
        padding: EdgeInsets.all(8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: NColors.primary)),
              SizedBox(width: 8),
              Text('Le coach réfléchit...',
                  style: TextStyle(color: NColors.textSecondary)),
            ],
          ),
        ),
      );

  Widget _suggestionsBar() => SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            ActionChip(
              avatar: const Icon(Icons.restaurant_menu,
                  size: 16, color: Colors.white),
              label: const Text('Proposer un repas'),
              backgroundColor: NColors.primary,
              labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
              onPressed: _sending ? null : _proposeMeal,
            ),
            const SizedBox(width: 8),
            ..._suggestions.map((s) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(s,
                        style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.white,
                    onPressed: _sending ? null : () => _send(s),
                  ),
                )),
          ],
        ),
      );

  Widget _inputBar() => Container(
        padding: EdgeInsets.fromLTRB(
            12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                decoration: InputDecoration(
                  hintText: 'Votre question...',
                  filled: true,
                  fillColor: NColors.bg,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 24,
              backgroundColor: NColors.primary,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sending ? null : () => _send(_input.text),
              ),
            ),
          ],
        ),
      );
}
