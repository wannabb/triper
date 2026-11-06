import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'api/api.dart';
import 'ledger_page.dart';
import 'my_info_page.dart';

class TripsPage extends StatefulWidget {
  const TripsPage({super.key});

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  static const Color primary = Color(0xFF3478EF);
  static const Color background = Color(0xFFF7F9FD);
  static const Color textColor = Color(0xFF20242D);
  static const Color mutedColor = Color(0xFF8791A3);

  late final Stream<List<Trip>> _trips;

  // 삭제 애니메이션이 끝나고 서버 응답이 반영될 때까지 숨길 여행
  final Set<String> _hiddenTripIds = {};

  @override
  void initState() {
    super.initState();
    _trips = TripApi.watchAll();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _addTrip() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (_) => const AddTripSheet(),
    );

    if (!mounted) return;

    if (result == true) {
      _showMessage('새 여행이 추가되었습니다!');
    }
  }

  Future<void> _editTrip(Trip trip) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (_) => EditTripSheet(trip: trip),
    );

    if (!mounted) return;

    if (result == true) {
      _showMessage('여행 정보가 수정되었습니다.');
    }
  }

  Future<void> _deleteTripFromMenu(Trip trip) async {
    final confirmed = await _confirmDeleteTrip(trip);
    if (!confirmed || !mounted) return;

    await _deleteTrip(trip);
  }

  Future<void> _showGuide() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trip Wallet 사용방법',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 22),
              const _GuideItem(
                icon: Icons.flight_takeoff_rounded,
                title: '1. 여행 추가',
                description: '여행 이름과 예산, 통화, 여행 기간을 입력하세요.',
              ),
              const _GuideItem(
                icon: Icons.receipt_long_rounded,
                title: '2. 소비 기록',
                description: '여행 중 발생한 지출을 기록하세요.',
              ),
              const _GuideItem(
                icon: Icons.currency_exchange_rounded,
                title: '3. 자동 환산',
                description: '현지 통화로 기록한 지출을 원화로 확인할 수 있어요.',
              ),
              const _GuideItem(
                icon: Icons.bar_chart_rounded,
                title: '4. 예산 관리',
                description: '여행 예산과 사용 금액을 비교해 보세요.',
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      await AuthApi.signOut();
    } catch (e) {
      if (!mounted) return;
      _showMessage(AuthApi.errorMessage(e));
    }
  }

  Future<bool> _confirmDeleteTrip(Trip trip) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '여행 기록을 삭제하겠습니까?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          content: Text(
            '"${trip.name}" 여행과 해당 여행의 모든 지출 기록이 삭제됩니다.\n'
            '삭제한 데이터는 복구할 수 없습니다.',
            style: const TextStyle(
              color: mutedColor,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                '취소',
                style: TextStyle(
                  color: Color(0xFF8791A3),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                '삭제',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _deleteTrip(Trip trip) async {
    setState(() => _hiddenTripIds.add(trip.id));

    try {
      await TripApi.delete(trip.id);

      if (!mounted) return;
      _showMessage('여행 기록이 삭제되었습니다.');
    } catch (e) {
      if (!mounted) return;

      setState(() => _hiddenTripIds.remove(trip.id));
      _showMessage(AuthApi.errorMessage(e));
    }
  }

  void _openMyInfo() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MyInfoPage()));
  }

  void _openLedger(Trip trip) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => LedgerPage(tripId: trip.id)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEEF3FF), Color(0xFFF8F9FC), Color(0xFFFFFFFF)],
            stops: [0.0, 0.48, 1.0],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<List<Trip>>(
            stream: _trips,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(AuthApi.errorMessage(snapshot.error!)),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: primary),
                );
              }

              final trips = snapshot.data!
                  .where((trip) => !_hiddenTripIds.contains(trip.id))
                  .toList();

              if (trips.isEmpty) {
                return _buildEmptyPage();
              }

              return _buildTripList(trips);
            },
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // 여행이 하나도 없는 첫 화면
  // --------------------------------------------------

  Widget _buildEmptyPage() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: Column(
                    children: [
                      const Spacer(flex: 4),
                      SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: CustomPaint(painter: FlightPathPainter()),
                            ),
                            Container(
                              width: 116,
                              height: 116,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFDCE7FF),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: primary.withValues(alpha: 0.12),
                                    blurRadius: 35,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.flight_takeoff_rounded,
                                color: primary,
                                size: 43,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        '첫 여행을 추가해 보세요',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '여행 일정과 지출을 한곳에서 관리해요',
                        style: TextStyle(color: mutedColor, fontSize: 13),
                      ),
                      const SizedBox(height: 34),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Row(
                          children: [
                            Expanded(
                              child: _FeatureItem(emoji: '💱', title: '자동 환산'),
                            ),
                            _FeatureDivider(),
                            Expanded(
                              child: _FeatureItem(emoji: '📍', title: '소비 기록'),
                            ),
                            _FeatureDivider(),
                            Expanded(
                              child: _FeatureItem(emoji: '📊', title: '예산 관리'),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(flex: 5),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton.icon(
                  onPressed: _addTrip,
                  icon: const Icon(Icons.add_circle, size: 25),
                  label: const Text(
                    '여행 추가하기',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE8EFFF),
                    foregroundColor: primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(19),
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: _showGuide,
                child: const Text(
                  '사용방법 다시 보기',
                  style: TextStyle(
                    color: primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------
  // 상단 바
  // --------------------------------------------------

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
      child: Row(
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFE7EEFF),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flight_takeoff_rounded, color: primary, size: 15),
                SizedBox(width: 7),
                Text(
                  '환율 걱정 없는 여행 장부',
                  style: TextStyle(
                    color: primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: Color(0xFF343B48),
            ),
            onSelected: (value) {
              if (value == 'my_info') {
                _openMyInfo();
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'my_info',
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 19),
                    SizedBox(width: 10),
                    Text('내 정보'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 19),
                    SizedBox(width: 10),
                    Text('로그아웃'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // 여행 목록
  // --------------------------------------------------

  Widget _buildTripList(List<Trip> trips) {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            children: [
              Text(
                '${AuthApi.displayName}님의 여행',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '여행 일정과 예산을 관리해 보세요.',
                style: TextStyle(color: mutedColor, fontSize: 13),
              ),
              const SizedBox(height: 26),

              for (final trip in trips)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Dismissible(
                    key: ValueKey(trip.id),
                    direction: DismissDirection.startToEnd,
                    confirmDismiss: (_) => _confirmDeleteTrip(trip),
                    onDismissed: (_) => _deleteTrip(trip),
                    background: Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 24),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '삭제',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    child: Card(
                      color: Colors.white,
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: Color(0xFFE9EDF5)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(17),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF0FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.flight_rounded,
                            color: primary,
                          ),
                        ),
                        title: Text(
                          trip.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Text(
                            '${dayOnly(trip.start)} ~ ${dayOnly(trip.end)}\n'
                            '${trip.currency} · 예산 ${won(trip.budget)}',
                            style: const TextStyle(
                              color: mutedColor,
                              fontSize: 12,
                              height: 1.7,
                            ),
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: '여행 관리',
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            color: mutedColor,
                          ),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editTrip(trip);
                            } else if (value == 'delete') {
                              _deleteTripFromMenu(trip);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 19),
                                  SizedBox(width: 10),
                                  Text('수정하기'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline_rounded,
                                    size: 19,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    '삭제하기',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _openLedger(trip),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton.icon(
              onPressed: _addTrip,
              icon: const Icon(Icons.add),
              label: const Text('새 여행 추가하기'),
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ==================================================
// 여행 추가 바텀시트
// ==================================================

class AddTripSheet extends StatefulWidget {
  const AddTripSheet({super.key});

  @override
  State<AddTripSheet> createState() => _AddTripSheetState();
}

class _AddTripSheetState extends State<AddTripSheet> {
  static const Color primary = Color(0xFF3478EF);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();

  late String _currency;

  DateTimeRange _range = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now().add(const Duration(days: 7)),
  );

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _currency = currencies.contains('JPY') ? 'JPY' : currencies.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _range,
      helpText: '여행 기간 선택',
      saveText: '선택 완료',
    );

    if (result == null || !mounted) return;

    setState(() => _range = result);
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    final budget = int.tryParse(
      _budgetController.text.replaceAll(',', '').trim(),
    );

    if (budget == null || budget <= 0) {
      _showMessage('올바른 예산을 입력해 주세요.');
      return;
    }

    setState(() => _busy = true);

    try {
      await TripApi.add(
        name: _nameController.text.trim(),
        budget: budget,
        currency: _currency,
        start: _range.start,
        end: _range.end,
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
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '새 여행 만들기 ✈️',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                '여행 정보를 입력하고 장부를 시작해 보세요.',
                style: TextStyle(color: Color(0xFF8791A3), fontSize: 13),
              ),
              const SizedBox(height: 25),
              const _FieldLabel('여행 이름'),
              TextFormField(
                controller: _nameController,
                maxLength: 30,
                decoration: _inputDecoration(hint: '예: 오사카 3박 4일'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '여행 이름을 입력해 주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              const _FieldLabel('여행 예산 (KRW)'),
              TextFormField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  hint: '예: 1000000',
                  suffix: const Text('원'),
                ),
                validator: (value) {
                  final number = int.tryParse(
                    (value ?? '').replaceAll(',', '').trim(),
                  );
                  if (number == null || number <= 0) {
                    return '올바른 예산을 입력해 주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              const _FieldLabel('현지 통화'),
              DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration: _inputDecoration(),
                items: [
                  for (final currency in currencies)
                    DropdownMenuItem(value: currency, child: Text(currency)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _currency = value);
                  }
                },
              ),
              const SizedBox(height: 20),
              const _FieldLabel('여행 기간'),
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E9F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${dayOnly(_range.start)}  ~  ${dayOnly(_range.end)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
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
                          '여행 만들기',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
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

// ==================================================
// 여행 정보 수정 바텀시트
// ==================================================

class EditTripSheet extends StatefulWidget {
  const EditTripSheet({super.key, required this.trip});

  final Trip trip;

  @override
  State<EditTripSheet> createState() => _EditTripSheetState();
}

class _EditTripSheetState extends State<EditTripSheet> {
  static const Color primary = Color(0xFF3478EF);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _budgetController;
  late DateTimeRange _range;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.trip.name);
    _budgetController = TextEditingController(
      text: widget.trip.budget.toString(),
    );
    _range = DateTimeRange(start: widget.trip.start, end: widget.trip.end);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _range,
      helpText: '여행 기간 수정',
      saveText: '선택 완료',
    );

    if (result == null || !mounted) return;

    setState(() => _range = result);
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    final budget = int.tryParse(
      _budgetController.text.replaceAll(',', '').trim(),
    );

    if (budget == null || budget <= 0) {
      _showMessage('올바른 예산을 입력해 주세요.');
      return;
    }

    setState(() => _busy = true);

    try {
      final updatedTrip = widget.trip.copyWith(
        name: _nameController.text.trim(),
        budget: budget,
        start: _range.start,
        end: _range.end,
      );

      await TripApi.update(updatedTrip);

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
                '여행 정보 수정',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                '여행 이름, 예산, 일정을 변경할 수 있어요.',
                style: TextStyle(color: Color(0xFF8791A3), fontSize: 13),
              ),
              const SizedBox(height: 25),
              const _FieldLabel('여행 이름'),
              TextFormField(
                controller: _nameController,
                maxLength: 30,
                decoration: _inputDecoration(hint: '여행 이름'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '여행 이름을 입력해 주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              const _FieldLabel('여행 예산 (KRW)'),
              TextFormField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  hint: '예: 1000000',
                  suffix: const Text('원'),
                ),
                validator: (value) {
                  final number = int.tryParse(
                    (value ?? '').replaceAll(',', '').trim(),
                  );
                  if (number == null || number <= 0) {
                    return '올바른 예산을 입력해 주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const _FieldLabel('여행 기간'),
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E9F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${dayOnly(_range.start)}  ~  ${dayOnly(_range.end)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '현지 통화는 ${widget.trip.currency}로 유지됩니다. '
                  '기존 지출의 환율 기록을 보호하기 위한 설정입니다.',
                  style: const TextStyle(
                    color: Color(0xFF4268B2),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 25),
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
                          '변경사항 저장',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
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
}

// ==================================================
// 빈 화면 장식
// ==================================================

class FlightPathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9CBDFE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.76)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.32,
        size.width * 0.63,
        size.height * 0.18,
        size.width * 0.95,
        size.height * 0.25,
      );

    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;

      while (distance < metric.length) {
        final segment = metric.extractPath(
          distance,
          math.min(distance + 4, metric.length),
        );
        canvas.drawPath(segment, paint);
        distance += 9;
      }
    }

    final dotPaint = Paint()..color = const Color(0xFF9CBDFE);

    canvas.drawCircle(
      Offset(size.width * 0.08, size.height * 0.76),
      3.5,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant FlightPathPainter oldDelegate) => false;
}

// ==================================================
// 작은 UI 컴포넌트
// ==================================================

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.emoji, required this.title});

  final String emoji;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 19)),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(color: Color(0xFF7D8798), fontSize: 11),
        ),
      ],
    );
  }
}

class _FeatureDivider extends StatelessWidget {
  const _FeatureDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 23, width: 1, color: const Color(0xFFDCE1EA));
  }
}

class _GuideItem extends StatelessWidget {
  const _GuideItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF3478EF), size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF8791A3),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

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
