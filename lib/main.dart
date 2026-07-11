import 'package:flutter/material.dart';

void main() => runApp(const DeyAlertApp());

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

class Incident {
  const Incident({
    required this.title,
    required this.type,
    required this.location,
    required this.description,
    required this.time,
    required this.distance,
    required this.status,
    required this.statusColor,
    required this.icon,
  });

  final String title;
  final String type;
  final String location;
  final String description;
  final String time;
  final String distance;
  final String status;
  final Color statusColor;
  final IconData icon;
}

const _incidents = <Incident>[
  Incident(
    title: 'Roadblock on Allen Avenue',
    type: 'Roadblock',
    location: 'Allen Avenue, Ikeja',
    description:
        'Police checkpoint causing heavy traffic buildup. Use Opebi Road as an alternative.',
    time: '15 mins ago',
    distance: '1.2 km',
    status: 'Corroborated',
    statusColor: _amber,
    icon: Icons.traffic,
  ),
  Incident(
    title: 'Suspicious activity near Computer Village',
    type: 'Suspicious activity',
    location: 'Computer Village, Ikeja',
    description:
        'Two people seen following commuters near the west entrance. Stay in groups.',
    time: '45 mins ago',
    distance: '2.4 km',
    status: 'Unconfirmed',
    statusColor: _red,
    icon: Icons.visibility_outlined,
  ),
  Incident(
    title: 'Fire outbreak at Ikeja Market',
    type: 'Fire outbreak',
    location: 'Ikeja Market',
    description:
        'Fire service is on the scene. Avoid the market road until the area is cleared.',
    time: '2 hrs ago',
    distance: '3.1 km',
    status: 'Confirmed',
    statusColor: _greenBright,
    icon: Icons.local_fire_department_outlined,
  ),
];

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
      home: const OnboardingScreen(),
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
  ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell()));
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  final pages = const [
    MapViewScreen(),
    IncidentFeedScreen(),
    SosScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],
      floatingActionButton: index < 2
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReportIncidentScreen()),
              ),
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
        indicatorColor: _green.withOpacity(.22),
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
  const MapViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.radar, size: 18, color: _greenBright),
                      SizedBox(width: 8),
                      Text(
                        '12 incidents within 5 km',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 38,
            top: 280,
            child: _MapPin(label: 'Robbery', color: _red),
          ),
          const Positioned(
            right: 46,
            top: 380,
            child: _MapPin(label: 'Roadblock', color: _greenBright),
          ),
          const Positioned(
            left: 120,
            top: 500,
            child: _MapPin(label: 'Suspicious', color: _amber),
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
  const IncidentFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
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
          const SizedBox(height: 18),
          ..._incidents.map(
            (incident) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: IncidentCard(incident: incident),
            ),
          ),
        ],
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
                    color: incident.statusColor.withOpacity(.16),
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
                  label: incident.status,
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

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  int selected = 2;
  bool anonymous = false;
  final types = const [
    ('Kidnapping', Icons.person_search),
    ('Armed robbery', Icons.local_police_outlined),
    ('Roadblock', Icons.traffic),
    ('Cult clash', Icons.groups_2_outlined),
    ('Banditry', Icons.warning_amber),
    ('Fire outbreak', Icons.local_fire_department_outlined),
    ('Suspicious activity', Icons.visibility_outlined),
    ('Other', Icons.more_horiz),
  ];

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
                  color: selected == i ? _green.withOpacity(.2) : _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected == i ? _greenBright : _divider,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      types[i].$2,
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
            activeColor: _greenBright,
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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Report saved. It will sync when you are online.',
                  ),
                ),
              );
              Navigator.pop(context);
            },
            style: _buttonStyle(_red),
            icon: const Icon(Icons.send_outlined),
            label: const Text('Submit report'),
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
                label: '${incident.status} · 3 reports',
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
            onPressed: () {},
            style: _buttonStyle(_green),
            icon: const Icon(Icons.verified_outlined),
            label: const Text('I can corroborate'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {},
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
              color: _amber.withOpacity(.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _amber.withOpacity(.28)),
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
              color: _red.withOpacity(.13),
              border: Border.all(color: _red.withOpacity(.5), width: 2),
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
      color: color.withOpacity(.16),
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
      color: color.withOpacity(.14),
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
      ..color = accent.withOpacity(.08)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * .2, size.height * .25), 58, block);
    canvas.drawCircle(Offset(size.width * .8, size.height * .7), 82, block);
  }

  @override
  bool shouldRepaint(covariant NeighborhoodPainter oldDelegate) =>
      oldDelegate.accent != accent;
}
