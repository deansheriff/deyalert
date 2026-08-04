import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import 'package:url_launcher/url_launcher.dart';

import 'core/config/app_config.dart';
import 'core/services/advisory_repository.dart';
import 'core/services/api_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/incident_repository.dart';
import 'core/services/location_service.dart';
import 'core/services/notification_service.dart';
import 'models/advisory.dart';
import 'models/incident.dart';
import 'models/user_profile.dart';
import 'models/sos.dart';
import 'models/app_notification.dart';
import 'models/verifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.initialize();
  runApp(const DeyAlertApp());
}

const _bg = Color(0xFF101815);
const _surface = Color(0xFF18221E);
const _elevated = Color(0xFF223029);
const _green = Color(0xFF008751);
const _greenBright = Color(0xFF27B878);
const _amber = Color(0xFFF5A623);
const _red = Color(0xFFD64545);
const _text = Color(0xFFF4F7F5);
const _muted = Color(0xFF9AAEA4);
const _divider = Color(0xFF2E4037);

LatLng _applyLocationPrecision(LatLng location, String precision) {
  final factor = switch (precision) {
    'lga' => 10.0,
    'ward' => 100.0,
    _ => 0.0,
  };
  if (factor == 0) return location;
  return LatLng(
    (location.latitude * factor).round() / factor,
    (location.longitude * factor).round() / factor,
  );
}

class DeyAlertApp extends StatelessWidget {
  const DeyAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _green,
      brightness: Brightness.dark,
      surface: _surface,
    );
    return MaterialApp(
      title: 'Dey Alert',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: _bg,
        fontFamily: 'Inter',
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: _bg,
          foregroundColor: _text,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _greenBright, width: 2),
          ),
          hintStyle: const TextStyle(color: _muted),
        ),
      ),
      home: const AppEntry(),
    );
  }
}

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  Future<UserProfile>? _profile;

  @override
  void initState() {
    super.initState();
    if (AuthService().isAuthenticated && !AppConfig.isDemoMode) {
      _profile = DeyAlertApi().currentProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService().isAuthenticated || AppConfig.isDemoMode) {
      return const OnboardingScreen();
    }
    return FutureBuilder<UserProfile>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) return HomeShell(profile: snapshot.data!);
        final error = snapshot.error;
        if (error is DioException && error.response?.statusCode == 404) {
          return const ProfileSetupScreen();
        }
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 44, color: _amber),
                    const SizedBox(height: 12),
                    const Text(
                      'Could not load your profile',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Check your connection and try again.',
                      style: TextStyle(color: _muted),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () => setState(
                        () => _profile = DeyAlertApi().currentProfile(),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int page = 0;
  final slides = const [
    (
      'Report incidents in seconds',
      'Alert your community about security concerns instantly. Fast, reliable, and verified by neighbors you trust.',
      Icons.campaign_outlined,
    ),
    (
      'Stay alert, stay informed',
      'Get nearby updates for your community, with clear status labels so you can make calm decisions.',
      Icons.map_outlined,
    ),
    (
      'Protect your community',
      'Corroborate what you see and help your neighbors separate real alerts from rumors.',
      Icons.groups_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final slide = slides[page];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const BrandMark(),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _openApp(context),
                      child: const Text('Skip'),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Container(
                  height: 260,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _divider),
                  ),
                  child: CustomPaint(
                    painter: NeighborhoodPainter(
                      accent: page == 1 ? _amber : _green,
                    ),
                    child: Center(
                      child: _IconBubble(
                        icon: slide.$3,
                        color: page == 1 ? _amber : _greenBright,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                Text(
                  slide.$1,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  slide.$2,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 16,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      height: 8,
                      width: i == page ? 24 : 8,
                      decoration: BoxDecoration(
                        color: i == page ? _greenBright : _divider,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () =>
                      page == 2 ? _openApp(context) : setState(() => page++),
                  style: _buttonStyle(_green),
                  child: Text(page == 2 ? 'Get started' : 'Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openApp(BuildContext context) => Navigator.of(
    context,
  ).pushReplacement(MaterialPageRoute(builder: (_) => const EmailAuthScreen()));
}

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthService();
  bool _createAccount = false;
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });
    try {
      if (_createAccount) {
        final sessionReady = await _auth.signUp(
          email: email,
          password: password,
        );
        if (!sessionReady) {
          if (mounted) {
            setState(() {
              _notice =
                  'Check your email to confirm your account, then return here to sign in.';
              _createAccount = false;
            });
          }
          return;
        }
      } else {
        await _auth.signIn(email: email, password: password);
      }
      if (!mounted) return;
      if (AppConfig.isDemoMode) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        );
        return;
      }
      try {
        final profile = await DeyAlertApi().currentProfile();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeShell(profile: profile)),
        );
      } on DioException catch (error) {
        if (!mounted) return;
        if (error.response?.statusCode == 404) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
          );
        } else {
          rethrow;
        }
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is AuthException
              ? error.message
              : 'Could not sign in. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          children: [
            const BrandMark(),
            const SizedBox(height: 52),
            const Icon(Icons.alternate_email, size: 46, color: _greenBright),
            const SizedBox(height: 22),
            Text(
              _createAccount ? 'Create your account' : 'Welcome back',
              style: const TextStyle(
                fontSize: 30,
                height: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _createAccount
                  ? 'Create a secure login for community alerts and incident reporting.'
                  : 'Sign in to report incidents and receive trusted local security updates.',
              style: const TextStyle(color: _muted, fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Email address',
                hintText: 'you@example.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _loading ? null : _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: _red)),
            ],
            if (_notice != null) ...[
              const SizedBox(height: 12),
              Text(_notice!, style: const TextStyle(color: _greenBright)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              style: _buttonStyle(_green),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _createAccount ? 'Create account' : 'Sign in & continue',
                    ),
            ),
            if (AppConfig.allowEmailSignUp) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => setState(() {
                        _createAccount = !_createAccount;
                        _error = null;
                        _notice = null;
                      }),
                child: Text(
                  _createAccount
                      ? 'Already have an account? Sign in'
                      : 'Need an account? Create one',
                ),
              ),
            ] else ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _green.withValues(alpha: .28)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.group_outlined, size: 18, color: _greenBright),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Dey Alert is currently invite-only. Ask your community administrator for an account.',
                        style: TextStyle(color: _muted, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 15, color: _muted),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Your password is handled securely by Supabase Auth.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
              ],
            ),
            if (_auth.isDemoMode) ...[
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _amber.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _amber.withValues(alpha: .28)),
                ),
                child: const Text(
                  'Demo mode: use demo@deyalert.local and password123.',
                  style: TextStyle(color: _amber, height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({this.initialProfile, super.key});

  final UserProfile? initialProfile;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _api = DeyAlertApi();
  String _state = 'Lagos';
  String _lga = 'Ikeja';
  String _ward = 'Anifowoshe/Ikeja';
  List<String> _states = const ['Lagos'];
  List<String> _lgas = const ['Ikeja'];
  List<String> _wards = const ['Anifowoshe/Ikeja'];
  bool _areasLoading = true;
  String _precision = 'ward';
  double _radius = 5;
  bool _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    if (profile != null) {
      _nameController.text = profile.name;
      _phoneController.text = (profile.phone ?? '').replaceFirst(
        RegExp(r'^\+?234'),
        '',
      );
      _state = profile.state;
      _lga = profile.lga;
      _ward = profile.ward;
      _precision = profile.locationPrecision;
      _radius = profile.alertRadiusKm.clamp(1, 20).toDouble();
    }
    _loadAreas();
  }

  Future<void> _loadAreas() async {
    try {
      final states = await _api.areaStates();
      if (states.isEmpty) throw StateError('No pilot areas configured');
      final state = states.contains(_state) ? _state : states.first;
      final lgas = await _api.areaLgas(state);
      final lga = lgas.contains(_lga) ? _lga : lgas.first;
      final wards = await _api.areaWards(state, lga);
      if (!mounted) return;
      setState(() {
        _states = states;
        _state = state;
        _lgas = lgas;
        _lga = lga;
        _wards = wards;
        _ward = wards.contains(_ward) ? _ward : wards.first;
        _areasLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _areasLoading = false;
          _message = 'Could not load pilot areas. Check your connection.';
        });
      }
    }
  }

  Future<void> _selectState(String value) async {
    setState(() => _areasLoading = true);
    final lgas = await _api.areaLgas(value);
    final wards = await _api.areaWards(value, lgas.first);
    if (!mounted) return;
    setState(() {
      _state = value;
      _lgas = lgas;
      _lga = lgas.first;
      _wards = wards;
      _ward = wards.first;
      _areasLoading = false;
    });
  }

  Future<void> _selectLga(String value) async {
    setState(() => _areasLoading = true);
    final wards = await _api.areaWards(_state, value);
    if (!mounted) return;
    setState(() {
      _lga = value;
      _wards = wards;
      _ward = wards.first;
      _areasLoading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? get _optionalPhone {
    var value = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (value.isEmpty) return null;
    if (value.startsWith('0')) value = value.substring(1);
    if (value.startsWith('234')) return '+$value';
    return '+234$value';
  }

  Future<void> _continue() async {
    if (_nameController.text.trim().length < 2) {
      setState(() => _message = 'Enter your name to continue.');
      return;
    }
    final phoneDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (phoneDigits.isNotEmpty && phoneDigits.length < 10) {
      setState(
        () => _message = 'Enter a complete phone number or leave it blank.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final profile = await _api.updateProfile(
        name: _nameController.text.trim(),
        phone: _optionalPhone,
        state: _state,
        lga: _lga,
        ward: _ward,
        radiusKm: _radius,
        locationPrecision: _precision,
      );
      if (!mounted) return;
      if (widget.initialProfile != null) {
        Navigator.pop(context, profile);
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomeShell(profile: profile)),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message =
            'Could not save your profile. Check your connection and retry.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialProfile == null ? 'Set up your area' : 'Edit profile',
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: LinearProgressIndicator(value: .75, minHeight: 3),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        children: [
          Text(
            widget.initialProfile == null
                ? 'Complete your profile'
                : 'Update your profile',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your area keeps alerts relevant without asking for your exact home address.',
            style: TextStyle(color: _muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number (optional)',
              prefixText: '+234  ',
              hintText: '801 234 5678',
              prefixIcon: Icon(Icons.phone_outlined),
              helperText:
                  'Verification will be introduced before public launch.',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 14),
          _ProfileDropdown(
            label: 'State',
            value: _state,
            values: _states,
            onChanged: _selectState,
          ),
          const SizedBox(height: 14),
          _ProfileDropdown(
            label: 'LGA',
            value: _lga,
            values: _lgas,
            onChanged: _selectLga,
          ),
          const SizedBox(height: 14),
          _ProfileDropdown(
            label: 'Ward',
            value: _ward,
            values: _wards,
            onChanged: (value) => setState(() => _ward = value),
          ),
          const SizedBox(height: 24),
          if (_areasLoading) const LinearProgressIndicator(),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Alert radius',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${_radius.round()} km',
                style: const TextStyle(
                  color: _greenBright,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Slider(
            value: _radius,
            min: 1,
            max: 20,
            divisions: 19,
            onChanged: (value) => setState(() => _radius = value),
          ),
          const SizedBox(height: 12),
          const Text(
            'Location precision',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'ward',
                icon: Icon(Icons.shield_outlined),
                label: Text('Ward level'),
              ),
              ButtonSegment(
                value: 'exact',
                icon: Icon(Icons.my_location),
                label: Text('Precise'),
              ),
            ],
            selected: {_precision},
            onSelectionChanged: (values) =>
                setState(() => _precision = values.first),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_message!, style: const TextStyle(color: _amber)),
            ),
          FilledButton(
            onPressed: _loading || _areasLoading ? null : _continue,
            style: _buttonStyle(_green),
            child: _loading
                ? const CircularProgressIndicator(strokeWidth: 2)
                : const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

class _ProfileDropdown extends StatelessWidget {
  const _ProfileDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.location_on_outlined),
      ),
      items: values
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (item) {
        if (item != null) onChanged(item);
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({required this.profile, super.key});
  final UserProfile profile;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  late UserProfile _profile = widget.profile;
  final _repository = IncidentRepository();
  final _advisoryRepository = AdvisoryRepository();
  final _connectivity = ConnectivityService();
  final _notifications = NotificationService();
  List<Incident> _incidents = [];
  List<SecurityAdvisory> _trendingAdvisories = [];
  List<SecurityAdvisory> _nearbyAdvisories = [];
  LatLng? _center;
  String? _loadError;
  bool _loading = false;
  bool _newsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadContent();
    _notifications.initialize().then((_) {
      _notifications.subscribeToIncidents(
        lga: _profile.lga,
        onIncident: _handleRealtimeIncident,
      );
    });
    _connectivity.listen(() async {
      await _repository.syncPending();
      await _loadContent();
    });
  }

  @override
  void dispose() {
    _connectivity.dispose();
    _notifications.dispose();
    super.dispose();
  }

  Future<void> _loadIncidents() async {
    if (mounted) setState(() => _loading = true);
    if (_center == null) {
      try {
        final position = await LocationService().currentPosition();
        _center = LatLng(position.latitude, position.longitude);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _loadError = 'Location is required to load nearby safety reports.';
        });
        return;
      }
    }
    final center = _center;
    if (center == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final incidents = await _repository.loadNearby(
        lat: center.latitude,
        lng: center.longitude,
        radiusKm: _profile.alertRadiusKm,
      );
      if (!mounted) return;
      setState(() {
        _incidents = incidents;
        _loading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not refresh nearby reports.';
      });
    }
  }

  Future<void> _loadAdvisories() async {
    if (mounted) setState(() => _newsLoading = true);
    final center = _center;
    try {
      final trending = await _advisoryRepository.loadTrending();
      final nearby = center == null
          ? <SecurityAdvisory>[]
          : await _advisoryRepository.loadNearby(
              lat: center.latitude,
              lng: center.longitude,
            );
      if (!mounted) return;
      setState(() {
        _trendingAdvisories = trending;
        _nearbyAdvisories = nearby;
        _newsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _newsLoading = false);
    }
  }

  Future<void> _loadContent() async {
    await _loadIncidents();
    await _loadAdvisories();
  }

  Future<void> _handleRealtimeIncident() async {
    final existingIds = _incidents.map((item) => item.id).toSet();
    await _loadIncidents();
    if (_incidents.any((item) => !existingIds.contains(item.id))) {
      await _notifications.showNearbyIncident();
    }
  }

  Future<void> _applyProfile(UserProfile profile) async {
    setState(() => _profile = profile);
    await _notifications.dispose();
    _notifications.subscribeToIncidents(
      lga: profile.lga,
      onIncident: _handleRealtimeIncident,
    );
    await _loadContent();
  }

  Future<void> _openReport() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReportIncidentScreen(
          repository: _repository,
          profile: _profile,
          initialLocation: _center,
        ),
      ),
    );
    if (submitted == true) await _loadIncidents();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      MapViewScreen(
        incidents: _incidents,
        advisories: _nearbyAdvisories,
        center: _center,
        error: _loadError,
        canVerify: _profile.role == 'verifier' || _profile.role == 'admin',
      ),
      IncidentFeedScreen(
        incidents: _incidents,
        loading: _loading,
        onRefresh: _loadIncidents,
        error: _loadError,
        areaLabel: '${_profile.ward}, ${_profile.lga}',
        radiusKm: _profile.alertRadiusKm,
        canVerify: _profile.role == 'verifier' || _profile.role == 'admin',
      ),
      SecurityNewsScreen(
        advisories: _trendingAdvisories,
        loading: _newsLoading,
        onRefresh: _loadContent,
      ),
      SosScreen(profile: _profile),
      ProfileScreen(profile: _profile, onProfileChanged: _applyProfile),
    ];
    return Scaffold(
      body: pages[index],
      floatingActionButton: index < 2
          ? FloatingActionButton.extended(
              onPressed: _openReport,
              backgroundColor: _red,
              foregroundColor: _text,
              icon: const Icon(Icons.add_alert),
              label: const Text('Report'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        backgroundColor: _surface,
        indicatorColor: _green.withValues(alpha: .22),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map, color: _greenBright),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_list_outlined),
            selectedIcon: Icon(Icons.view_list, color: _greenBright),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.newspaper_outlined),
            selectedIcon: Icon(Icons.newspaper, color: Color(0xFF4DA3FF)),
            label: 'News',
          ),
          NavigationDestination(
            icon: Icon(Icons.emergency_outlined),
            selectedIcon: Icon(Icons.emergency, color: _red),
            label: 'SOS',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: _greenBright),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class MapViewScreen extends StatelessWidget {
  const MapViewScreen({
    required this.incidents,
    required this.advisories,
    required this.center,
    required this.error,
    required this.canVerify,
    super.key,
  });
  final List<Incident> incidents;
  final List<SecurityAdvisory> advisories;
  final LatLng? center;
  final String? error;
  final bool canVerify;

  @override
  Widget build(BuildContext context) {
    if (center == null) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_off_outlined,
                  size: 52,
                  color: _amber,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Location unavailable',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  error ??
                      'Enable location permission to view nearby incidents and advisories.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (AppConfig.hasGoogleMaps) {
      final incidentMarkers = incidents
          .map(
            (incident) => Marker(
              markerId: MarkerId(incident.id),
              position: LatLng(incident.lat, incident.lng),
              infoWindow: InfoWindow(
                title: incident.displayType,
                snippet: incident.displayStatus,
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                incident.status == 'confirmed'
                    ? BitmapDescriptor.hueGreen
                    : incident.status == 'corroborated'
                    ? BitmapDescriptor.hueOrange
                    : BitmapDescriptor.hueRed,
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => IncidentDetailScreen(
                    incident: incident,
                    canVerify: canVerify,
                  ),
                ),
              ),
            ),
          )
          .toSet();
      final advisoryMarkers = advisories
          .where((advisory) => advisory.hasLocation)
          .map(
            (advisory) => Marker(
              markerId: MarkerId('advisory-${advisory.id}'),
              position: LatLng(advisory.lat!, advisory.lng!),
              infoWindow: InfoWindow(
                title: 'Media advisory: ${advisory.title}',
                snippet: '${advisory.locationName} · ${advisory.sourceLabel}',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdvisoryDetailScreen(advisory: advisory),
                ),
              ),
            ),
          )
          .toSet();
      return SafeArea(
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: center!,
                zoom: 13.8,
              ),
              markers: {...incidentMarkers, ...advisoryMarkers},
              myLocationButtonEnabled: true,
              myLocationEnabled: true,
              mapToolbarEnabled: false,
              padding: const EdgeInsets.only(top: 145, bottom: 90),
            ),
            _MapHeader(
              incidentCount: incidents.length,
              advisoryCount: advisories
                  .where((item) => item.hasLocation)
                  .length,
            ),
            if (error != null)
              Positioned(
                left: 20,
                right: 20,
                bottom: 110,
                child: _InlineError(message: error!),
              ),
          ],
        ),
      );
    }
    return SafeArea(
      child: Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: NeighborhoodPainter(accent: _green),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Map view',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: const [
                      _FilterChip(label: 'All', selected: true),
                      _FilterChip(label: 'Kidnapping'),
                      _FilterChip(label: 'Robbery'),
                      _FilterChip(label: 'Fire'),
                      _FilterChip(label: 'Confirmed'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _divider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.radar, size: 18, color: _greenBright),
                      const SizedBox(width: 8),
                      Text(
                        '${incidents.length} reports · ${advisories.length} media advisories',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (incidents.isNotEmpty)
            Positioned(
              left: 38,
              top: 280,
              child: _MapPin(
                label: incidents.first.displayType,
                color: incidents.first.statusColor,
              ),
            ),
          if (incidents.length > 1)
            Positioned(
              right: 46,
              top: 380,
              child: _MapPin(
                label: incidents[1].displayType,
                color: incidents[1].statusColor,
              ),
            ),
          if (incidents.length > 2)
            Positioned(
              left: 120,
              top: 500,
              child: _MapPin(
                label: incidents[2].displayType,
                color: incidents[2].statusColor,
              ),
            ),
          if (advisories.isNotEmpty)
            Positioned(
              right: 34,
              top: 510,
              child: _MapPin(
                label: 'Media: ${advisories.first.locationName}',
                color: advisories.first.markerColor,
              ),
            ),
        ],
      ),
    );
  }
}

class IncidentFeedScreen extends StatelessWidget {
  const IncidentFeedScreen({
    required this.incidents,
    required this.loading,
    required this.onRefresh,
    required this.error,
    required this.areaLabel,
    required this.radiusKm,
    required this.canVerify,
    super.key,
  });
  final List<Incident> incidents;
  final bool loading;
  final Future<void> Function() onRefresh;
  final String? error;
  final String areaLabel;
  final double radiusKm;
  final bool canVerify;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
          children: [
            const Text(
              'Nearby alerts',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on, size: 17, color: _greenBright),
                const SizedBox(width: 4),
                Text(areaLabel, style: const TextStyle(color: _muted)),
                const Spacer(),
                TextButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.tune, size: 16),
                  label: Text('${radiusKm.round()} km'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: const [
                  _FilterChip(label: 'All', selected: true),
                  _FilterChip(label: 'Security'),
                  _FilterChip(label: 'Fire'),
                  _FilterChip(label: 'Traffic'),
                ],
              ),
            ),
            if (loading) const LinearProgressIndicator(minHeight: 2),
            if (error != null) ...[
              const SizedBox(height: 12),
              _InlineError(message: error!),
            ],
            const SizedBox(height: 18),
            ...incidents.map(
              (incident) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: IncidentCard(incident: incident, canVerify: canVerify),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IncidentCard extends StatelessWidget {
  const IncidentCard({
    required this.incident,
    this.canVerify = false,
    super.key,
  });
  final Incident incident;
  final bool canVerify;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              IncidentDetailScreen(incident: incident, canVerify: canVerify),
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: incident.statusColor.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(incident.icon, color: incident.statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        incident.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        incident.location,
                        style: const TextStyle(color: _muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(
                  label: incident.displayStatus,
                  color: incident.statusColor,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              incident.description,
              style: const TextStyle(color: _muted, height: 1.45),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.schedule, size: 15, color: _muted),
                const SizedBox(width: 4),
                Text(
                  incident.time,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(width: 18),
                Icon(Icons.near_me, size: 15, color: _muted),
                const SizedBox(width: 4),
                Text(
                  incident.distance,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: _muted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SecurityNewsScreen extends StatelessWidget {
  const SecurityNewsScreen({
    required this.advisories,
    required this.loading,
    required this.onRefresh,
    super.key,
  });

  final List<SecurityAdvisory> advisories;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
          children: [
            const Text(
              'Security news',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Trending, location-aware coverage from configured Nigerian news outlets.',
              style: TextStyle(color: _muted, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF4DA3FF).withValues(alpha: .1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF4DA3FF).withValues(alpha: .35),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF4DA3FF)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Blue items are reviewed media advisories, not eyewitness community reports. Always open the original sources before acting.',
                      style: TextStyle(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            if (loading) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: 18),
            if (advisories.isEmpty)
              const _EmptyNewsState()
            else
              ...advisories.map(
                (advisory) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AdvisoryCard(advisory: advisory),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNewsState extends StatelessWidget {
  const _EmptyNewsState({
    this.title = 'No reviewed advisories yet',
    this.message = 'Pull down to check again.',
    this.icon = Icons.newspaper_outlined,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: _muted),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: _muted)),
        ],
      ),
    );
  }
}

class AdvisoryCard extends StatelessWidget {
  const AdvisoryCard({required this.advisory, super.key});

  final SecurityAdvisory advisory;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdvisoryDetailScreen(advisory: advisory),
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: advisory.markerColor.withValues(alpha: .4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: advisory.markerColor.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'MEDIA ADVISORY',
                    style: TextStyle(
                      color: Color(0xFF78BAFF),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .6,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  advisory.time,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              advisory.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              advisory.summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, height: 1.45),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 17,
                  color: advisory.markerColor,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${advisory.locationName} · ${advisory.confidenceLabel}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  advisory.sourceLabel,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AdvisoryDetailScreen extends StatelessWidget {
  const AdvisoryDetailScreen({required this.advisory, super.key});

  final SecurityAdvisory advisory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Media advisory')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          Row(
            children: [
              Icon(Icons.newspaper, color: advisory.markerColor),
              const SizedBox(width: 8),
              Text(
                'Reviewed media coverage',
                style: TextStyle(
                  color: advisory.markerColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            advisory.title,
            style: const TextStyle(
              fontSize: 26,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            advisory.summary,
            style: const TextStyle(color: _muted, fontSize: 16, height: 1.55),
          ),
          const SizedBox(height: 18),
          _DetailRow(
            icon: Icons.location_on_outlined,
            label: advisory.locationName,
            value: advisory.confidenceLabel,
            color: advisory.markerColor,
          ),
          _DetailRow(
            icon: Icons.fact_check_outlined,
            label: advisory.sourceLabel,
            value: '${advisory.articleCount} linked reports',
            color: advisory.markerColor,
          ),
          _DetailRow(
            icon: Icons.schedule,
            label: 'Updated ${advisory.time}',
            value: 'Advisories expire automatically',
            color: advisory.markerColor,
          ),
          const SizedBox(height: 18),
          const Text(
            'Original reporting',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...advisory.sources.map(
            (source) => Card(
              color: _surface,
              child: ListTile(
                title: Text(source.sourceName),
                subtitle: Text(
                  source.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _openArticle(context, source.url),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'This item summarizes external reporting. Dey Alert does not treat it as an eyewitness report or emergency instruction.',
            style: TextStyle(color: _muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  value,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openArticle(BuildContext context, String value) async {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !{'http', 'https'}.contains(uri.scheme) ||
      !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this news source.')),
      );
    }
  }
}

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({
    required this.repository,
    required this.profile,
    this.initialLocation,
    super.key,
  });
  final IncidentRepository repository;
  final UserProfile profile;
  final LatLng? initialLocation;

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  int selected = 2;
  bool anonymous = false;
  bool submitting = false;
  final _descriptionController = TextEditingController();
  final _locationService = LocationService();
  final _picker = ImagePicker();
  final _mediaApi = DeyAlertApi();
  final List<XFile> _attachments = [];
  LatLng? _selectedLocation;
  String? _locationError;
  final types = const [
    ('Kidnapping', 'kidnapping', Icons.person_search),
    ('Armed robbery', 'armed_robbery', Icons.local_police_outlined),
    ('Roadblock', 'roadblock', Icons.traffic),
    ('Cult clash', 'cult_clash', Icons.groups_2_outlined),
    ('Banditry', 'banditry', Icons.warning_amber),
    ('Fire outbreak', 'fire_outbreak', Icons.local_fire_department_outlined),
    ('Suspicious activity', 'suspicious_activity', Icons.visibility_outlined),
    ('Other', 'other', Icons.more_horiz),
  ];

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  Future<bool> _refreshLocation() async {
    try {
      final position = await _locationService.currentPosition();
      if (!mounted) return false;
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _locationError = null;
      });
      return true;
    } catch (_) {
      if (!mounted) return false;
      setState(() {
        _locationError =
            'Enable location access before submitting this safety report.';
      });
      return false;
    }
  }

  Future<void> _pickMedia(ImageSource source, {required bool video}) async {
    final file = video
        ? await _picker.pickVideo(
            source: source,
            maxDuration: const Duration(seconds: 30),
          )
        : await _picker.pickImage(
            source: source,
            imageQuality: 75,
            maxWidth: 1600,
          );
    if (file == null || !mounted) return;
    if (_attachments.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can attach up to 3 files.')),
      );
      return;
    }
    setState(() => _attachments.add(file));
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => submitting = true);
    if (!await _refreshLocation()) {
      if (mounted) setState(() => submitting = false);
      return;
    }
    final location = _applyLocationPrecision(
      _selectedLocation!,
      widget.profile.locationPrecision,
    );
    final mediaUrls = <String>[];
    try {
      for (final attachment in _attachments) {
        mediaUrls.add(await _mediaApi.uploadMedia(attachment));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        submitting = false;
        _locationError =
            'Could not upload the selected evidence. Retry online or remove it.';
      });
      return;
    }
    late final SubmissionResult result;
    try {
      result = await widget.repository.submit({
        'type': types[selected].$2,
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'location': {'lat': location.latitude, 'lng': location.longitude},
        'location_name': '${widget.profile.ward}, ${widget.profile.lga}',
        'lga': widget.profile.lga,
        'ward': widget.profile.ward,
        'severity': types[selected].$2 == 'kidnapping' ? 'critical' : 'medium',
        'is_anonymous': anonymous,
        'media_urls': mediaUrls,
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        submitting = false;
        _locationError =
            'The report was not accepted. Review the details and try again.';
      });
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.queued
              ? 'You are offline. The report is queued and will sync automatically.'
              : 'Report submitted to your community.',
        ),
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        title: const Text(
          'Report incident',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (context) => const SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report safely',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Do not confront anyone or put yourself at risk. Move to safety first, avoid sharing victims\' identities, and call local emergency services when there is immediate danger.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            icon: const Icon(Icons.shield_outlined, size: 17),
            label: const Text('Safety'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const Text(
            'What are you seeing?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'A few details help neighbors respond safely.',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 24),
          const Text(
            'Incident type',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: types.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: .86,
            ),
            itemBuilder: (_, i) => InkWell(
              onTap: () => setState(() => selected = i),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                decoration: BoxDecoration(
                  color: selected == i
                      ? _green.withValues(alpha: .2)
                      : _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected == i ? _greenBright : _divider,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      types[i].$3,
                      size: 23,
                      color: selected == i ? _greenBright : _muted,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      types[i].$1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: selected == i
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: "What's happening?",
              alignLabelWithHint: true,
              hintText: 'Describe what you saw, if it is safe to do so.',
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _divider),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: _greenBright),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.profile.ward}, ${widget.profile.lga}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 3),
                      const Text(
                        'Using your current device location',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: submitting ? null : _refreshLocation,
                  child: Text(
                    _selectedLocation == null ? 'Set location' : 'Refresh',
                  ),
                ),
              ],
            ),
          ),
          if (_locationError != null) ...[
            const SizedBox(height: 10),
            Text(_locationError!, style: const TextStyle(color: _red)),
          ],
          const SizedBox(height: 18),
          const Text(
            'Add evidence (optional)',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Attachment(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                onTap: () => _pickMedia(ImageSource.camera, video: false),
              ),
              const SizedBox(width: 10),
              _Attachment(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: () => _pickMedia(ImageSource.gallery, video: false),
              ),
              const SizedBox(width: 10),
              _Attachment(
                icon: Icons.videocam_outlined,
                label: 'Video',
                onTap: () => _pickMedia(ImageSource.gallery, video: true),
              ),
            ],
          ),
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${_attachments.length} attachment${_attachments.length == 1 ? '' : 's'} selected',
              style: const TextStyle(color: _greenBright, fontSize: 12),
            ),
            TextButton(
              onPressed: () => setState(_attachments.clear),
              child: const Text('Remove attachments'),
            ),
          ],
          const SizedBox(height: 18),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: anonymous,
            onChanged: (value) => setState(() => anonymous = value),
            activeThumbColor: _greenBright,
            title: const Text(
              'Report anonymously',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Your identity will be hidden from the community.',
              style: TextStyle(color: _muted),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: submitting ? null : _submit,
            style: _buttonStyle(_red),
            icon: submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(submitting ? 'Submitting…' : 'Submit report'),
          ),
        ],
      ),
    );
  }
}

class IncidentDetailScreen extends StatelessWidget {
  const IncidentDetailScreen({
    required this.incident,
    this.canVerify = false,
    super.key,
  });
  final Incident incident;
  final bool canVerify;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Incident detail',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Container(
            height: 190,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _divider),
            ),
            child: CustomPaint(
              painter: NeighborhoodPainter(accent: incident.statusColor),
              child: const Center(
                child: Icon(Icons.location_on, color: _text, size: 46),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatusBadge(
                label:
                    '${incident.displayStatus} · ${incident.corroborationCount} reports',
                color: incident.statusColor,
              ),
              const Spacer(),
              const Icon(Icons.share_outlined, color: _muted),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            incident.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(
            '${incident.time}  ·  ${incident.distance}',
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 18),
          Text(
            incident.description,
            style: const TextStyle(color: _muted, height: 1.55),
          ),
          const SizedBox(height: 20),
          if (incident.mediaUrls.isNotEmpty) ...[
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: incident.mediaUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, index) =>
                    _MediaTile(url: incident.mediaUrls[index]),
              ),
            ),
            const SizedBox(height: 20),
          ],
          FilledButton.icon(
            onPressed: () async {
              try {
                final position = await LocationService().currentPosition();
                await DeyAlertApi().corroborate(
                  incident.id,
                  lat: position.latitude,
                  lng: position.longitude,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Corroboration recorded.')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not corroborate. Confirm location access and that you are near the report.',
                      ),
                    ),
                  );
                }
              }
            },
            style: _buttonStyle(_green),
            icon: const Icon(Icons.verified_outlined),
            label: const Text('I can corroborate'),
          ),
          if (canVerify && incident.status != 'confirmed') ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () async {
                try {
                  await DeyAlertApi().verifyIncident(incident.id);
                  if (context.mounted) Navigator.pop(context, true);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'This report is outside your verifier scope.',
                        ),
                      ),
                    );
                  }
                }
              },
              style: _buttonStyle(_green),
              icon: const Icon(Icons.verified),
              label: const Text('Confirm as verifier'),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await DeyAlertApi().flag(incident.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report flagged for review.')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not submit the flag right now.'),
                    ),
                  );
                }
              }
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              foregroundColor: _muted,
              side: const BorderSide(color: _divider),
            ),
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Flag report'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Report status',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _TimelineItem(
            title: incident.displayStatus,
            subtitle: incident.corroborationCount == 0
                ? 'No corroborations have been recorded yet.'
                : '${incident.corroborationCount} corroboration${incident.corroborationCount == 1 ? '' : 's'} recorded.',
            time: 'Reported ${incident.time.toLowerCase()}',
            color: incident.statusColor,
            last: true,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _amber.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _amber.withValues(alpha: .28)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, color: _amber),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Safety reminder: Do not approach an active incident. Use the mapped report as an advisory and follow instructions from verified emergency authorities.',
                    style: TextStyle(height: 1.45),
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

class SosScreen extends StatefulWidget {
  const SosScreen({required this.profile, super.key});
  final UserProfile profile;

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  final _api = DeyAlertApi();
  final _location = LocationService();
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  SosReadiness? _readiness;
  bool _sending = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadReadiness();
    _hold.addStatusListener((status) {
      if (status == AnimationStatus.completed) _trigger();
    });
  }

  Future<void> _loadReadiness() async {
    try {
      final readiness = await _api.sosReadiness();
      if (mounted) setState(() => _readiness = readiness);
    } catch (_) {
      if (mounted) setState(() => _status = 'Could not check SOS readiness.');
    }
  }

  Future<void> _trigger() async {
    if (_readiness?.ready != true || _sending) return;
    setState(() {
      _sending = true;
      _status = 'Getting your verified location…';
    });
    try {
      final position = await _location.currentPosition();
      final result = await _api.triggerSos(
        lat: position.latitude,
        lng: position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _status = result.deliveredTo > 0
            ? 'SOS delivered to ${result.deliveredTo} trusted contact${result.deliveredTo == 1 ? '' : 's'}.'
            : 'SOS was not confirmed. No SMS delivery succeeded.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _status =
              'SOS was not confirmed. Please call emergency services directly.',
        );
      }
    } finally {
      _hold.reset();
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _readiness?.ready == true;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        children: [
          const Text(
            'Emergency SOS',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Press and hold for 3 seconds. An alert is confirmed only after server delivery.',
            style: TextStyle(color: _muted, height: 1.5),
          ),
          const SizedBox(height: 34),
          Center(
            child: GestureDetector(
              onTapDown: ready && !_sending ? (_) => _hold.forward() : null,
              onTapUp: (_) {
                if (!_hold.isCompleted) _hold.reset();
              },
              onTapCancel: _hold.reset,
              child: AnimatedBuilder(
                animation: _hold,
                builder: (_, child) => SizedBox(
                  height: 230,
                  width: 230,
                  child: CircularProgressIndicator(
                    value: _hold.value,
                    strokeWidth: 8,
                    color: _red,
                    backgroundColor: _red.withValues(alpha: .16),
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -204),
            child: Center(
              child: IgnorePointer(
                child: Container(
                  width: 178,
                  height: 178,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ready ? _red : _divider,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.emergency, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        _sending
                            ? 'SENDING…'
                            : ready
                            ? 'HOLD SOS'
                            : 'NOT READY',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -155),
            child: Column(
              children: [
                _SosStatusRow(
                  icon: Icons.my_location,
                  label: '${widget.profile.ward}, ${widget.profile.lga}',
                  value: 'Location checked when sending',
                  ready: true,
                ),
                _SosStatusRow(
                  icon: Icons.people_outline,
                  label: '${_readiness?.contactCount ?? 0} trusted contacts',
                  value: _readiness?.message ?? 'Checking readiness…',
                  ready: ready,
                ),
                if (_status != null) ...[
                  const SizedBox(height: 12),
                  _InlineError(message: _status!),
                ],
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TrustedContactsScreen(),
                      ),
                    );
                    await _loadReadiness();
                  },
                  icon: const Icon(Icons.contacts_outlined),
                  label: const Text('Manage trusted contacts'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SosStatusRow extends StatelessWidget {
  const _SosStatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.ready,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool ready;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _divider),
    ),
    child: Row(
      children: [
        Icon(icon, color: ready ? _greenBright : _amber),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(value, style: const TextStyle(color: _muted, fontSize: 12)),
            ],
          ),
        ),
      ],
    ),
  );
}

class TrustedContactsScreen extends StatefulWidget {
  const TrustedContactsScreen({super.key});

  @override
  State<TrustedContactsScreen> createState() => _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends State<TrustedContactsScreen> {
  final _api = DeyAlertApi();
  List<TrustedContact> _contacts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final contacts = await _api.trustedContacts();
      if (mounted) setState(() => _contacts = contacts);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load trusted contacts.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Trusted contacts')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      children: [
        const Text(
          'These contacts receive your location by SMS when a confirmed SOS is sent.',
          style: TextStyle(color: _muted, height: 1.5),
        ),
        if (_loading) ...[
          const SizedBox(height: 14),
          const LinearProgressIndicator(),
        ],
        if (_error != null) ...[
          const SizedBox(height: 14),
          _InlineError(message: _error!),
        ],
        if (!_loading && _contacts.isEmpty) ...[
          const SizedBox(height: 18),
          const _InlineError(
            message:
                'SOS alerts are unavailable until you add at least one trusted contact.',
          ),
        ],
        const SizedBox(height: 16),
        ..._contacts.map(
          (contact) => Card(
            color: _surface,
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: _elevated,
                child: Icon(Icons.person_outline),
              ),
              title: Text(contact.name),
              subtitle: Text(
                '${contact.relationship ?? 'Trusted contact'} · ${contact.maskedPhone}',
              ),
              trailing: IconButton(
                tooltip: 'Delete contact',
                icon: const Icon(Icons.delete_outline, color: _red),
                onPressed: () async {
                  await _api.deleteTrustedContact(contact.id);
                  await _load();
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () async {
            final saved = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => const AddTrustedContactScreen(),
              ),
            );
            if (saved == true) await _load();
          },
          style: _buttonStyle(_green),
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Add trusted contact'),
        ),
      ],
    ),
  );
}

class AddTrustedContactScreen extends StatefulWidget {
  const AddTrustedContactScreen({super.key});

  @override
  State<AddTrustedContactScreen> createState() =>
      _AddTrustedContactScreenState();
}

class _AddTrustedContactScreenState extends State<AddTrustedContactScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _relationship = TextEditingController();
  final _api = DeyAlertApi();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _relationship.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    var digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (!digits.startsWith('234')) digits = '234$digits';
    if (_name.text.trim().length < 2 || digits.length < 12) {
      setState(
        () => _error = 'Enter a name and complete Nigerian phone number.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _api.addTrustedContact(
        name: _name.text.trim(),
        phone: '+$digits',
        relationship: _relationship.text.trim().isEmpty
            ? null
            : _relationship.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Unable to save contact. Check your connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add trusted contact')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Full name'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            prefixText: '+234 ',
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _relationship,
          decoration: const InputDecoration(
            labelText: 'Relationship (optional)',
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _elevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'By adding this contact, you confirm they agreed to receive emergency SMS alerts.',
            style: TextStyle(color: _muted, height: 1.4),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _InlineError(message: _error!),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: _buttonStyle(_green),
          child: Text(_saving ? 'Saving…' : 'Save contact'),
        ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = DeyAlertApi();
  List<AppNotification> _items = [];
  int _unread = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await _api.notifications();
      if (mounted) {
        setState(() {
          _items = result.items;
          _unread = result.unread;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        if (_unread > 0)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$_unread new',
                style: const TextStyle(
                  color: _greenBright,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (!_loading && _items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: _EmptyNewsState(
                title: 'No notifications yet',
                message: 'Nearby alerts will appear here.',
                icon: Icons.notifications_none,
              ),
            ),
          ..._items.map(
            (item) => Card(
              color: item.isUnread ? _elevated : _surface,
              child: ListTile(
                leading: Icon(
                  Icons.notifications_active_outlined,
                  color: item.severity == 'critical' ? _red : _greenBright,
                ),
                title: Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: item.isUnread
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
                subtitle: Text('${item.body}\n${item.time}'),
                isThreeLine: true,
                trailing: item.isUnread
                    ? const Icon(Icons.circle, color: _greenBright, size: 10)
                    : null,
                onTap: () async {
                  if (item.isUnread) {
                    await _api.markNotificationRead(item.id);
                    await _load();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  final _api = DeyAlertApi();
  List<Incident> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _api.moderationQueue();
      if (mounted) setState(() => _items = items);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _moderate(Incident incident, String status) async {
    await _api.moderateIncident(incident.id, status);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Moderation')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          Row(
            children: [
              _AdminStat(label: 'Flagged', value: _items.length, color: _red),
              const SizedBox(width: 8),
              _AdminStat(
                label: 'Hidden',
                value: _items.where((item) => item.flagCount >= 5).length,
                color: _muted,
              ),
            ],
          ),
          if (_loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 16),
          if (!_loading && _items.isEmpty)
            const _EmptyNewsState(
              title: 'Moderation queue is clear',
              message: 'Flagged reports will appear here for review.',
              icon: Icons.gavel_outlined,
            ),
          ..._items.map(
            (incident) => Card(
              color: _surface,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            incident.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          '${incident.flagCount} flags',
                          style: const TextStyle(color: _red),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      incident.description,
                      style: const TextStyle(color: _muted),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => _moderate(incident, 'false_report'),
                          child: const Text('False report'),
                        ),
                        OutlinedButton(
                          onPressed: () => _moderate(incident, 'resolved'),
                          child: const Text('Resolve'),
                        ),
                        FilledButton(
                          onPressed: () => _moderate(incident, 'confirmed'),
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AdminStat extends StatelessWidget {
  const _AdminStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .5)),
      ),
      child: Column(
        children: [
          Text('$value', style: TextStyle(fontSize: 22, color: color)),
          Text(label, style: const TextStyle(color: _muted)),
        ],
      ),
    ),
  );
}

class VerifierManagementScreen extends StatefulWidget {
  const VerifierManagementScreen({super.key});

  @override
  State<VerifierManagementScreen> createState() =>
      _VerifierManagementScreenState();
}

class _VerifierManagementScreenState extends State<VerifierManagementScreen> {
  final _api = DeyAlertApi();
  List<VerifierRecord> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _api.verifiers();
    if (mounted) setState(() => _items = items);
  }

  Future<void> _add() async {
    final userId = TextEditingController();
    final lga = TextEditingController();
    final ward = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add verifier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userId,
              decoration: const InputDecoration(labelText: 'User ID'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: lga,
              decoration: const InputDecoration(labelText: 'LGA'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ward,
              decoration: const InputDecoration(labelText: 'Ward (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await _api.addVerifier(
        userId: userId.text.trim(),
        state: 'Lagos',
        lga: lga.text.trim(),
        ward: ward.text.trim().isEmpty ? null : ward.text.trim(),
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Community verifiers')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _add,
      icon: const Icon(Icons.person_add),
      label: const Text('Add verifier'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: _items
          .map(
            (item) => Card(
              color: _surface,
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.verified_user)),
                title: Text(item.title ?? 'Community verifier'),
                subtitle: Text(
                  '${item.lga}${item.ward == null ? '' : ' · ${item.ward}'}',
                ),
                trailing: TextButton(
                  onPressed: () async {
                    await _api.revokeVerifier(item.userId);
                    await _load();
                  },
                  child: const Text('Revoke', style: TextStyle(color: _red)),
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.profile,
    required this.onProfileChanged,
    super.key,
  });
  final UserProfile profile;
  final Future<void> Function(UserProfile profile) onProfileChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 100),
        children: [
          const Text(
            'Your profile',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _divider),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: _green,
                  child: Text(
                    profile.name
                        .split(' ')
                        .where((part) => part.isNotEmpty)
                        .take(2)
                        .map((part) => part[0].toUpperCase())
                        .join(),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profile.lga}, ${profile.state} · ${profile.role}',
                      style: const TextStyle(color: _muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SettingTile(
            icon: Icons.edit_outlined,
            title: 'Edit profile',
            subtitle: 'Update your name, area, radius, or location precision',
            onTap: () async {
              final updated = await Navigator.of(context).push<UserProfile>(
                MaterialPageRoute(
                  builder: (_) => ProfileSetupScreen(initialProfile: profile),
                ),
              );
              if (updated != null) await onProfileChanged(updated);
            },
          ),
          _SettingTile(
            icon: Icons.location_on_outlined,
            title: 'Alert area',
            subtitle:
                'Within ${profile.alertRadiusKm.round()} km of ${profile.lga}',
          ),
          if (profile.role == 'admin') ...[
            _SettingTile(
              icon: Icons.gavel_outlined,
              title: 'Moderation queue',
              subtitle: 'Review flagged community reports',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ModerationScreen()),
              ),
            ),
            _SettingTile(
              icon: Icons.verified_user_outlined,
              title: 'Community verifiers',
              subtitle: 'Assign and revoke geographic scopes',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const VerifierManagementScreen(),
                ),
              ),
            ),
          ],
          _SettingTile(
            icon: Icons.shield_outlined,
            title: 'Privacy precision',
            subtitle: profile.locationPrecision,
          ),
          _SettingTile(
            icon: Icons.people_outline,
            title: 'Trusted contacts',
            subtitle: 'Manage emergency SMS recipients',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TrustedContactsScreen()),
            ),
          ),
          _SettingTile(
            icon: Icons.notifications_none,
            title: 'Notifications',
            subtitle: 'Nearby alerts are on',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await AuthService().signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const EmailAuthScreen()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({required this.incidentCount, required this.advisoryCount});
  final int incidentCount;
  final int advisoryCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _bg.withValues(alpha: .92),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _divider),
            ),
            child: Row(
              children: [
                const Text(
                  'Map view',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  '$incidentCount reports · $advisoryCount media',
                  style: const TextStyle(color: _muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                _FilterChip(label: 'All', selected: true),
                _FilterChip(label: 'Kidnapping'),
                _FilterChip(label: 'Robbery'),
                _FilterChip(label: 'Confirmed'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _red.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _red.withValues(alpha: .35)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: _red),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});
  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Icon(Icons.shield_rounded, color: _greenBright, size: 27),
      SizedBox(width: 8),
      Text(
        'dey alert',
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          letterSpacing: -.5,
        ),
      ),
    ],
  );
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .16),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: color, size: 48),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.selected = false});
  final String label;
  final bool selected;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Chip(
      label: Text(label),
      backgroundColor: selected ? _green : _surface,
      side: BorderSide(color: selected ? _green : _divider),
      labelStyle: TextStyle(
        color: selected ? _text : _muted,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      Icon(Icons.location_on, color: color, size: 34),
    ],
  );
}

class _Attachment extends StatelessWidget {
  const _Attachment({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 78,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _muted),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url);
    final isVideo =
        uri != null &&
        RegExp(r'\.(mp4|mov)(\?|$)', caseSensitive: false).hasMatch(url);
    return InkWell(
      onTap: uri == null
          ? null
          : () => launchUrl(uri, mode: LaunchMode.externalApplication),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 112,
        width: 132,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _elevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _divider),
        ),
        child: isVideo
            ? const Icon(Icons.play_circle_outline, color: _muted, size: 38)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined, color: _muted),
              ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
    required this.last,
  });
  final String title, subtitle, time;
  final Color color;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              height: 14,
              width: 14,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            if (!last) Container(height: 48, width: 2, color: _divider),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      time,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 6),
    leading: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: _greenBright),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle, style: const TextStyle(color: _muted)),
    trailing: const Icon(Icons.chevron_right, color: _muted),
    onTap: onTap,
  );
}

ButtonStyle _buttonStyle(Color color) => FilledButton.styleFrom(
  backgroundColor: color,
  foregroundColor: _text,
  minimumSize: const Size.fromHeight(54),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  textStyle: const TextStyle(fontWeight: FontWeight.w700),
);

class NeighborhoodPainter extends CustomPainter {
  NeighborhoodPainter({required this.accent});
  final Color accent;
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = _divider
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final minor = Paint()
      ..color = _elevated
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (var i = -2; i < 12; i++) {
      canvas.drawLine(
        Offset(size.width * .08, size.height * (i / 10)),
        Offset(size.width * .92, size.height * ((i + 3) / 10)),
        i % 3 == 0 ? road : minor,
      );
    }
    for (var i = 0; i < 8; i++) {
      canvas.drawLine(
        Offset(size.width * (i / 7), size.height * .08),
        Offset(size.width * ((i + 2) / 8), size.height * .9),
        i % 2 == 0 ? road : minor,
      );
    }
    final block = Paint()
      ..color = accent.withValues(alpha: .08)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * .2, size.height * .25), 58, block);
    canvas.drawCircle(Offset(size.width * .8, size.height * .7), 82, block);
  }

  @override
  bool shouldRepaint(covariant NeighborhoodPainter oldDelegate) =>
      oldDelegate.accent != accent;
}
