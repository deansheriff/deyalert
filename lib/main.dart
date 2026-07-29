import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import 'package:url_launcher/url_launcher.dart';

import 'core/config/app_config.dart';
import 'core/services/advisory_repository.dart';
import 'core/services/api_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/incident_repository.dart';
import 'core/services/location_service.dart';
import 'models/advisory.dart';
import 'models/incident.dart';

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
      home: AuthService().isAuthenticated && !AppConfig.isDemoMode
          ? const HomeShell()
          : const OnboardingScreen(),
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
      );
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
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _api = DeyAlertApi();
  String _state = 'Lagos';
  String _lga = 'Ikeja';
  String _ward = 'Allen';
  String _precision = 'ward';
  double _radius = 5;
  bool _loading = false;
  String? _message;

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
      await _api.saveProfile(
        name: _nameController.text.trim(),
        phone: _optionalPhone,
        state: _state,
        lga: _lga,
        ward: _ward,
        radiusKm: _radius,
        locationPrecision: _precision,
      );
    } catch (_) {
      _message =
          'Profile saved on this device. It will sync when the API is available.';
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up your area'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: LinearProgressIndicator(value: .75, minHeight: 3),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        children: [
          const Text(
            'Complete your profile',
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
            values: const ['Lagos'],
            onChanged: (value) => setState(() => _state = value),
          ),
          const SizedBox(height: 14),
          _ProfileDropdown(
            label: 'LGA',
            value: _lga,
            values: const ['Ikeja'],
            onChanged: (value) => setState(() => _lga = value),
          ),
          const SizedBox(height: 14),
          _ProfileDropdown(
            label: 'Ward',
            value: _ward,
            values: const ['Allen', 'Alausa', 'Opebi'],
            onChanged: (value) => setState(() => _ward = value),
          ),
          const SizedBox(height: 24),
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
            onPressed: _loading ? null : _continue,
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
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  final _repository = IncidentRepository();
  final _advisoryRepository = AdvisoryRepository();
  final _connectivity = ConnectivityService();
  List<Incident> _incidents = List.of(demoIncidents);
  List<SecurityAdvisory> _trendingAdvisories = List.of(demoAdvisories);
  List<SecurityAdvisory> _nearbyAdvisories = List.of(demoAdvisories);
  bool _loading = false;
  bool _newsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadContent();
    _connectivity.listen(() async {
      await _repository.syncPending();
      await _loadContent();
    });
  }

  @override
  void dispose() {
    _connectivity.dispose();
    super.dispose();
  }

  Future<void> _loadIncidents() async {
    if (mounted) setState(() => _loading = true);
    final incidents = await _repository.loadNearby();
    if (!mounted) return;
    setState(() {
      _incidents = incidents;
      _loading = false;
    });
  }

  Future<void> _loadAdvisories() async {
    if (mounted) setState(() => _newsLoading = true);
    final results = await Future.wait([
      _advisoryRepository.loadTrending(),
      _advisoryRepository.loadNearby(),
    ]);
    if (!mounted) return;
    setState(() {
      _trendingAdvisories = results[0];
      _nearbyAdvisories = results[1];
      _newsLoading = false;
    });
  }

  Future<void> _loadContent() async {
    await Future.wait([_loadIncidents(), _loadAdvisories()]);
  }

  Future<void> _openReport() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReportIncidentScreen(repository: _repository),
      ),
    );
    if (submitted == true) await _loadIncidents();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      MapViewScreen(incidents: _incidents, advisories: _nearbyAdvisories),
      IncidentFeedScreen(
        incidents: _incidents,
        loading: _loading,
        onRefresh: _loadIncidents,
      ),
      SecurityNewsScreen(
        advisories: _trendingAdvisories,
        loading: _newsLoading,
        onRefresh: _loadContent,
      ),
      const SosScreen(),
      const ProfileScreen(),
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
    super.key,
  });
  final List<Incident> incidents;
  final List<SecurityAdvisory> advisories;

  @override
  Widget build(BuildContext context) {
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
                  builder: (_) => IncidentDetailScreen(incident: incident),
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
              initialCameraPosition: const CameraPosition(
                target: LatLng(6.6018, 3.3515),
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
                Row(
                  children: [
                    const Text(
                      'Map view',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.search),
                    ),
                  ],
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
          Positioned(
            right: 20,
            bottom: 112,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'locate',
                  onPressed: () {},
                  backgroundColor: _surface,
                  child: const Icon(Icons.my_location, color: _greenBright),
                ),
                const SizedBox(height: 12),
              ],
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
    super.key,
  });
  final List<Incident> incidents;
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
              'Nearby alerts',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on, size: 17, color: _greenBright),
                const SizedBox(width: 4),
                const Text('Ikeja, Lagos', style: TextStyle(color: _muted)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('5 km'),
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
            const SizedBox(height: 18),
            ...incidents.map(
              (incident) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: IncidentCard(incident: incident),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IncidentCard extends StatelessWidget {
  const IncidentCard({required this.incident, super.key});
  final Incident incident;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => IncidentDetailScreen(incident: incident),
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
  const _EmptyNewsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider),
      ),
      child: const Column(
        children: [
          Icon(Icons.newspaper_outlined, size: 42, color: _muted),
          SizedBox(height: 12),
          Text(
            'No reviewed advisories yet',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text('Pull down to check again.', style: TextStyle(color: _muted)),
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
  const ReportIncidentScreen({required this.repository, super.key});
  final IncidentRepository repository;

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  int selected = 2;
  bool anonymous = false;
  bool submitting = false;
  final _descriptionController = TextEditingController();
  final _locationService = LocationService();
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
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => submitting = true);
    var lat = 6.6018;
    var lng = 3.3515;
    try {
      final position = await _locationService.currentPosition();
      lat = position.latitude;
      lng = position.longitude;
    } catch (_) {
      // Approximate Ikeja fallback keeps an offline report queueable.
    }
    final result = await widget.repository.submit({
      'type': types[selected].$2,
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      'location': {'lat': lat, 'lng': lng},
      'location_name': 'Allen Avenue, Ikeja',
      'lga': 'Ikeja',
      'ward': 'Allen',
      'severity': types[selected].$2 == 'kidnapping' ? 'critical' : 'medium',
      'is_anonymous': anonymous,
      'media_urls': <String>[],
    });
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
            onPressed: () {},
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
              suffixIcon: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.mic_none),
              ),
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Allen Avenue, Ikeja',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Using your approximate location',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: () {}, child: const Text('Adjust')),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Add evidence (optional)',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              _Attachment(icon: Icons.camera_alt_outlined, label: 'Camera'),
              SizedBox(width: 10),
              _Attachment(icon: Icons.photo_library_outlined, label: 'Gallery'),
              SizedBox(width: 10),
              _Attachment(icon: Icons.videocam_outlined, label: 'Video'),
            ],
          ),
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
  const IncidentDetailScreen({required this.incident, super.key});
  final Incident incident;

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
          Row(
            children: const [
              _MediaTile(icon: Icons.image_outlined),
              SizedBox(width: 10),
              _MediaTile(icon: Icons.play_circle_outline),
              SizedBox(width: 10),
              _MediaTile(icon: Icons.add_a_photo_outlined),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () async {
              try {
                await DeyAlertApi().corroborate(
                  incident.id,
                  lat: incident.lat,
                  lng: incident.lng,
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
                        'Could not corroborate while the API is offline.',
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
            'Report timeline',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          const _TimelineItem(
            title: 'Corroborated',
            subtitle: '3 neighbors reported the same incident',
            time: '10 mins ago',
            color: _amber,
            last: false,
          ),
          const _TimelineItem(
            title: 'Reported',
            subtitle: 'By a verified neighbor',
            time: '15 mins ago',
            color: _greenBright,
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
                    'Safety tip: Avoid Allen Avenue for now. Consider Opebi or Toyin Street as alternatives.',
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

class SosScreen extends StatelessWidget {
  const SosScreen({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Emergency SOS',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hold for 3 seconds to alert your trusted contacts and local responders.',
            style: TextStyle(color: _muted, height: 1.5),
          ),
          const Spacer(),
          Container(
            height: 230,
            width: 230,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _red.withValues(alpha: .13),
              border: Border.all(color: _red.withValues(alpha: .5), width: 2),
            ),
            child: Center(
              child: Container(
                height: 178,
                width: 178,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _red,
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emergency, size: 50),
                    SizedBox(height: 8),
                    Text(
                      'HOLD SOS',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _divider),
            ),
            child: const Row(
              children: [
                Icon(Icons.my_location, color: _greenBright),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Live location is ready',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.check_circle, color: _greenBright),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.contacts_outlined),
            label: const Text('Manage trusted contacts'),
          ),
        ],
      ),
    ),
  );
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: _green,
                  child: Text(
                    'AO',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adaeze Okafor',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Ikeja, Lagos  ·  Member',
                      style: TextStyle(color: _muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SettingTile(
            icon: Icons.location_on_outlined,
            title: 'Alert area',
            subtitle: 'Within 5 km of Ikeja',
          ),
          const _SettingTile(
            icon: Icons.shield_outlined,
            title: 'Privacy precision',
            subtitle: 'Approximate location',
          ),
          const _SettingTile(
            icon: Icons.people_outline,
            title: 'Trusted contacts',
            subtitle: '2 contacts ready for SOS',
          ),
          const _SettingTile(
            icon: Icons.notifications_none,
            title: 'Notifications',
            subtitle: 'Nearby alerts are on',
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
  const _Attachment({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
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
  );
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    height: 68,
    width: 82,
    decoration: BoxDecoration(
      color: _elevated,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _divider),
    ),
    child: Icon(icon, color: _muted),
  );
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
  });
  final IconData icon;
  final String title, subtitle;
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
