import 'package:flutter/material.dart';

import 'api/api.dart';

class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key, required this.tripId});

  final String tripId;

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  static const Color primary = Color(0xFF3478EF);
  static const Color background = Color(0xFFF7F9FD);
  static const Color muted = Color(0xFF8791A3);

  late final Stream<Trip?> _trip;
  late final Stream<List<Expense>> _expenses;

  @override
  void initState() {
    super.initState();

    _trip = TripApi.watch(widget.tripId);
    _expenses = ExpenseApi.watchAll(widget.tripId);
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _addExpense(Trip trip) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (_) => AddExpenseSheet(trip: trip),
    );

    if (!mounted) return;

    if (result == true) {
      _showMessage('지출이 추가되었습니다.');
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            '지출 기록을 삭제할까요?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            '${expense.place} · ${localAmt(expense.amount)} ${expense.currency}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소', style: TextStyle(color: muted)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ExpenseApi.delete(widget.tripId, expense.id);

      if (!mounted) return;
      _showMessage('지출 기록이 삭제되었습니다.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(AuthApi.errorMessage(e));
    }
  }

  // 날짜별로 지출을 그룹화하고 최신 날짜부터 정렬
  Map<DateTime, List<Expense>> _groupExpensesByDate(List<Expense> expenses) {
    final grouped = <DateTime, List<Expense>>{};

    for (final expense in expenses) {
      final date = DateTime(
        expense.date.year,
        expense.date.month,
        expense.date.day,
      );

      grouped.putIfAbsent(date, () => []).add(expense);
    }

    // 같은 날짜 안에서도 최신 지출이 위로 오도록 정렬
    for (final group in grouped.values) {
      group.sort((a, b) => b.date.compareTo(a.date));
    }

    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          '여행 장부',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF20242D),
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<Trip?>(
        stream: _trip,
        builder: (context, tripSnapshot) {
          if (tripSnapshot.hasError) {
            return Center(
              child: Text(AuthApi.errorMessage(tripSnapshot.error!)),
            );
          }

          if (!tripSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: primary),
            );
          }

          final trip = tripSnapshot.data;

          if (trip == null) {
            return const Center(child: Text('여행 정보를 찾을 수 없습니다.'));
          }

          return StreamBuilder<List<Expense>>(
            stream: _expenses,
            builder: (context, expenseSnapshot) {
              if (expenseSnapshot.hasError) {
                return Center(
                  child: Text(AuthApi.errorMessage(expenseSnapshot.error!)),
                );
              }

              if (!expenseSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: primary),
                );
              }

              final expenses = expenseSnapshot.data!;
              final groupedExpenses = _groupExpensesByDate(expenses);
              final sortedDates = groupedExpenses.keys.toList();

              final spent = LedgerCalc.spentKrw(expenses);
              final remaining = LedgerCalc.remainingKrw(trip, expenses);
              final ratio = LedgerCalc.usedRatio(trip, expenses);
              final overBudget = LedgerCalc.isOverBudget(trip, expenses);

              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                      children: [
                        _buildTripHeader(trip),
                        const SizedBox(height: 14),
                        _buildExchangeRateCard(trip),
                        const SizedBox(height: 18),
                        _buildBudgetCard(
                          trip: trip,
                          spent: spent,
                          remaining: remaining,
                          ratio: ratio,
                          overBudget: overBudget,
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '지출 내역',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF20242D),
                                ),
                              ),
                            ),
                            Text(
                              '${expenses.length}건',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 13),

                        if (expenses.isEmpty)
                          _buildEmptyExpenses()
                        else
                          for (final date in sortedDates) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 8,
                                bottom: 12,
                              ),
                              child: Text(
                                dayOnly(date),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF596579),
                                ),
                              ),
                            ),
                            for (final expense in groupedExpenses[date]!)
                              _buildExpenseTile(expense),
                          ],
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: () => _addExpense(trip),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text(
                            '지출 추가하기',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTripHeader(Trip trip) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          trip.name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF20242D),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.calendar_month_rounded, size: 15, color: muted),
            const SizedBox(width: 6),
            Text(
              '${dayOnly(trip.start)} ~ ${dayOnly(trip.end)}',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                trip.currency,
                style: const TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 현재 여행 통화 기준 환율 표시
  Widget _buildExchangeRateCard(Trip trip) {
    final converted = RateApi.fromKrw(1000, trip.currency);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FF),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(Icons.currency_exchange_rounded, color: primary, size: 21),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '현재 환율',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF20242D),
              ),
            ),
          ),
          Text(
            '1,000 KRW ≈ ${localAmt(converted)} ${trip.currency}',
            style: const TextStyle(
              color: primary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard({
    required Trip trip,
    required double spent,
    required double remaining,
    required double ratio,
    required bool overBudget,
  }) {
    final progress = ratio.clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9EDF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '총 여행 예산',
            style: TextStyle(
              color: muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            won(trip.budget),
            style: const TextStyle(
              color: Color(0xFF20242D),
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '예산 사용률',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              Text(
                '${(ratio * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: overBudget ? Colors.red : primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: const Color(0xFFEDF0F6),
              valueColor: AlwaysStoppedAnimation<Color>(
                overBudget ? Colors.red : primary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _BudgetValue(
                  label: '사용 금액',
                  value: won(spent),
                  valueColor: primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BudgetValue(
                  label: overBudget ? '초과 금액' : '남은 예산',
                  value: won(remaining.abs()),
                  valueColor: overBudget ? Colors.red : const Color(0xFF20A477),
                ),
              ),
            ],
          ),
          if (overBudget) ...[
            const SizedBox(height: 14),
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 17),
                SizedBox(width: 6),
                Text(
                  '여행 예산을 초과했습니다.',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyExpenses() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EDF5)),
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_rounded, size: 38, color: Color(0xFFB7C6E5)),
          SizedBox(height: 13),
          Text(
            '아직 기록된 지출이 없습니다.',
            style: TextStyle(
              color: Color(0xFF20242D),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 7),
          Text(
            '첫 지출을 추가해 여행 장부를 시작해 보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseTile(Expense expense) {
    final paymentLabel = expense.paymentMethod == 'card' ? '카드' : '현금';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EDF5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
        leading: Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0FF),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            iconOfCategory(expense.category),
            color: primary,
            size: 21,
          ),
        ),
        title: Text(
          expense.place,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '${expense.category} · $paymentLabel',
            style: const TextStyle(color: muted, fontSize: 11),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${localAmt(expense.amount)} ${expense.currency}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF20242D),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              won(expense.amountKrw),
              style: const TextStyle(color: muted, fontSize: 11),
            ),
          ],
        ),
        onLongPress: () => _deleteExpense(expense),
      ),
    );
  }
}

// ==================================================
// 예산 표시 컴포넌트
// ==================================================

class _BudgetValue extends StatelessWidget {
  const _BudgetValue({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8791A3), fontSize: 11),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ==================================================
// 지출 추가 바텀시트
// ==================================================

class AddExpenseSheet extends StatefulWidget {
  const AddExpenseSheet({super.key, required this.trip});

  final Trip trip;

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  static const Color primary = Color(0xFF3478EF);

  final _formKey = GlobalKey<FormState>();
  final _placeController = TextEditingController();
  final _amountController = TextEditingController();

  late String _category;
  String _paymentMethod = 'cash';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _category = categoryIcons.keys.first;
  }

  @override
  void dispose() {
    _placeController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', ''),
    );

    if (amount == null || amount <= 0) {
      _showMessage('올바른 금액을 입력해 주세요.');
      return;
    }

    setState(() => _busy = true);

    try {
      await ExpenseApi.add(
        widget.trip.id,
        category: _category,
        place: _placeController.text.trim(),
        amount: amount,
        currency: widget.trip.currency,
        paymentMethod: _paymentMethod,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showMessage(AuthApi.errorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        22,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '새 지출 기록하기',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                '금액은 ${widget.trip.currency} 기준으로 입력하세요.',
                style: const TextStyle(color: Color(0xFF8791A3), fontSize: 13),
              ),
              const SizedBox(height: 25),

              const _ExpenseFieldLabel('카테고리'),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: _inputDecoration(),
                items: [
                  for (final category in categoryIcons.keys)
                    DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Icon(iconOfCategory(category), size: 19),
                          const SizedBox(width: 9),
                          Text(category),
                        ],
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _category = value);
                  }
                },
              ),

              const SizedBox(height: 17),
              const _ExpenseFieldLabel('결제수단'),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration: _inputDecoration(),
                items: const [
                  DropdownMenuItem(
                    value: 'cash',
                    child: Row(
                      children: [
                        Icon(Icons.payments_outlined, size: 19),
                        SizedBox(width: 9),
                        Text('현금'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'card',
                    child: Row(
                      children: [
                        Icon(Icons.credit_card_rounded, size: 19),
                        SizedBox(width: 9),
                        Text('카드'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _paymentMethod = value);
                  }
                },
              ),

              const SizedBox(height: 17),
              const _ExpenseFieldLabel('장소 / 사용처'),
              TextFormField(
                controller: _placeController,
                maxLength: 50,
                decoration: _inputDecoration(hint: '예: 편의점, 식당, 지하철'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '사용처를 입력해 주세요.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 13),
              _ExpenseFieldLabel('금액 (${widget.trip.currency})'),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _inputDecoration(
                  hint: '예: 1500',
                  suffix: Text(widget.trip.currency),
                ),
                validator: (value) {
                  final amount = double.tryParse(
                    (value ?? '').trim().replaceAll(',', ''),
                  );

                  if (amount == null || amount <= 0) {
                    return '올바른 금액을 입력해 주세요.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          '지출 저장하기',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      suffix: suffix,
      filled: true,
      fillColor: const Color(0xFFF7F9FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E9F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E9F0)),
      ),
    );
  }
}

class _ExpenseFieldLabel extends StatelessWidget {
  const _ExpenseFieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}
