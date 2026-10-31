import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studentry/patients/data/patient_data.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:studentry/shared/widgets/studentry_brand.dart';

/// Tokens are local to the reference dashboard; other screens retain their theme.
class HomePalette {
  static const teal = AppColors.primary;
  static const tint = Color(0xFFE8F6F7);
  static const brandInk = Color(0xFF0C6F7D);
  final bool dark;
  const HomePalette(this.dark);
  factory HomePalette.of(BuildContext context) =>
      HomePalette(Theme.of(context).brightness == Brightness.dark);
  Color get background => dark ? const Color(0xFF101F25) : AppColors.background;
  Color get surface => dark ? const Color(0xFF192934) : Colors.white;
  Color get text => dark ? const Color(0xFFF0F6FA) : AppColors.textDark;
  Color get muted => dark ? const Color(0xFFB0C8CE) : const Color(0xFF57737C);
  Color get border => dark ? const Color(0xFF2C4952) : const Color(0xFFDCEEF0);
}

class HomeAddPatientButton extends StatelessWidget {
  const HomeAddPatientButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 380 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.1) {
      return FloatingActionButton(
        key: const ValueKey('home-add-patient'),
        tooltip: 'إضافة مريض',
        onPressed: onPressed,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 3,
        shape: const CircleBorder(),
        child: const Icon(Icons.person_add_rounded),
      );
    }
    return FloatingActionButton.extended(
      key: const ValueKey('home-add-patient'),
      tooltip: 'إضافة مريض',
      onPressed: onPressed,
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 3,
      shape: const StadiumBorder(),
      extendedPadding: const EdgeInsets.symmetric(horizontal: 8),
      extendedIconLabelSpacing: 6,
      extendedTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w700,
      ),
      icon: const Icon(Icons.person_add_rounded, size: 21),
      label: const Text('إضافة مريض'),
    );
  }
}

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.reminders,
    required this.onProfile,
    required this.onNotifications,
    required this.onMenu,
  });
  final String name;
  final String? avatarUrl;
  final int reminders;
  final VoidCallback onProfile, onNotifications, onMenu;

  @override
  Widget build(BuildContext context) {
    final p = HomePalette.of(context);
    final title = name.trim().isEmpty ? 'حسابي' : name.trim();
    return Row(
      key: const ValueKey('home-header'),
      children: [
        SizedBox(
          width: 88,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: IconButton(
              tooltip: 'القائمة الجانبية',
              onPressed: onMenu,
              icon: Icon(Icons.menu_rounded, color: p.text, size: 28),
            ),
          ),
        ),
        Expanded(
          child: Tooltip(
            message: title,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  key: const ValueKey('home-doctor-name'),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 21,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'طبيب أسنان',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: p.muted),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 88,
          child: Row(
            children: [
              IconButton(
                tooltip: 'الإشعارات والمواعيد',
                onPressed: onNotifications,
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 48),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 48),
                padding: const EdgeInsets.all(8),
                icon: Badge(
                  isLabelVisible: reminders > 0,
                  label: Text(reminders > 99 ? '99+' : '$reminders'),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: p.text,
                    size: 27,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'الإعدادات',
                child: InkWell(
                  onTap: onProfile,
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    width: 44,
                    height: 48,
                    child: Center(
                      child: avatarUrl?.isNotEmpty == true
                          ? CircleAvatar(
                              radius: 20,
                              backgroundColor: p.surface,
                              child: ClipOval(
                                child: Image.network(
                                  avatarUrl!,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, error, stack) =>
                                      _brandMark(),
                                ),
                              ),
                            )
                          : _brandMark(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _brandMark() => const StudentryBrandMark(size: 40);
}

class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({
    super.key,
    required this.onSearch,
    required this.onFilter,
  });
  final VoidCallback onSearch, onFilter;
  @override
  Widget build(BuildContext context) {
    final p = HomePalette.of(context);
    return Row(
      children: [
        Material(
          color: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: p.border),
          ),
          child: IconButton(
            tooltip: 'تحديد نوع البحث',
            onPressed: onFilter,
            icon: const Icon(Icons.tune_rounded, color: HomePalette.brandInk),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Material(
            color: p.surface,
            elevation: 1.5,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: p.border),
            ),
            child: InkWell(
              onTap: onSearch,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ابحث عن مريض، موعد، مادة أو منتج...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.muted, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.search_rounded, size: 24, color: p.muted),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Draws the exact tooth/instruments pixels from the supplied screenshot.
/// No generated replacement, text pixels or stretched proportions are used.
class ReferenceDentalArt extends StatefulWidget {
  const ReferenceDentalArt({super.key});
  @override
  State<ReferenceDentalArt> createState() => _ReferenceDentalArtState();
}

class _ReferenceDentalArtState extends State<ReferenceDentalArt> {
  ui.Image? _image;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await rootBundle.load(
      'assets/image/home_dental_reference.jpg',
    );
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() => _image = frame.image);
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(painter: _ReferencePainter(_image), size: Size.infinite),
  );
}

class _ReferencePainter extends CustomPainter {
  const _ReferencePainter(this.image);
  final ui.Image? image;
  @override
  void paint(Canvas canvas, Size size) {
    final img = image;
    if (img == null) return;
    final source = Rect.fromLTRB(
      img.width * 475 / 852,
      img.height * 296 / 1846,
      img.width * 820 / 852,
      img.height * 638 / 1846,
    );
    final scale = size.height / source.height;
    final target = Rect.fromLTWH(
      size.width - source.width * scale,
      0,
      source.width * scale,
      size.height,
    );
    canvas.drawImageRect(
      img,
      source,
      target,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(_ReferencePainter oldDelegate) =>
      image != oldDelegate.image;
}

class HomeBannerCarousel extends StatefulWidget {
  const HomeBannerCarousel({
    super.key,
    required this.banners,
    required this.onAction,
  });
  final List<PromoBanner> banners;
  final ValueChanged<PromoBanner?> onAction;
  @override
  State<HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<HomeBannerCarousel> {
  int _page = 0;
  @override
  void didUpdateWidget(covariant HomeBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.map((b) => b.id).join(',') !=
        widget.banners.map((b) => b.id).join(',')) {
      _page = 0;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final height =
          (constraints.maxWidth / 2.2).clamp(170.0, 280.0) +
          (scale > 1.15 ? (scale - 1) * 120 : 0);
      final items = widget.banners;
      final count = items.isEmpty ? 1 : items.length;
      return SizedBox(
        height: height,
        child: Stack(
          children: [
            PageView.builder(
              key: ValueKey(items.map((b) => b.id).join(',')),
              itemCount: count,
              onPageChanged: (index) => setState(() => _page = index),
              itemBuilder: (context, index) {
                final banner = items.isEmpty ? null : items[index];
                final image = banner?.imageUrl ?? '';
                return ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [HomePalette.tint, Color(0xFFD9EFF1)],
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (image.isEmpty)
                          const ReferenceDentalArt()
                        else
                          Align(
                            alignment: Alignment.centerRight,
                            child: FractionallySizedBox(
                              widthFactor: .48,
                              child: Image.network(
                                image,
                                fit: BoxFit.cover,
                                height: height,
                                errorBuilder: (_, error, stack) =>
                                    const ReferenceDentalArt(),
                              ),
                            ),
                          ),
                        // The fade blends only the photographed background, keeping the tooth intact.
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                HomePalette.tint,
                                HomePalette.tint,
                                Color(0x00E8F6F7),
                              ],
                              stops: [0, .49, .69],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          top: 16,
                          bottom: 15,
                          width: constraints.maxWidth * .51,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                banner?.title ??
                                    'نظّم دراستك وممارستك لطب الأسنان',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.45,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF102534),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: Text(
                                  banner?.subtitle ??
                                      'إدارة المرضى، المواعيد، المحاضرات، المنتجات والمالية بسهولة.',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    height: 1.6,
                                    color: Color(0xFF253E4C),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FilledButton.icon(
                                  onPressed: () => widget.onAction(banner),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: HomePalette.teal,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(90, 34),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 5,
                                    ),
                                    tapTargetSize: MaterialTapTargetSize.padded,
                                    shape: const StadiumBorder(),
                                  ),
                                  icon: const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 17,
                                  ),
                                  label: Text(
                                    banner?.ctaText.isNotEmpty == true
                                        ? banner!.ctaText
                                        : 'ابدأ الآن',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (count > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    count,
                    (index) => Semantics(
                      label: 'البانر ${index + 1} من $count',
                      selected: index == _page,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == _page
                              ? HomePalette.teal
                              : const Color(0xFFC9DEE2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class HomeStatisticsGrid extends StatelessWidget {
  const HomeStatisticsGrid({super.key, required this.stats})
    : assert(stats.length == 4);
  final List<HomeStat> stats;
  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('home-statistics-grid'),
    children: [
      for (var row = 0; row < 2; row++) ...[
        if (row > 0) const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: stats[row * 2]),
              const SizedBox(width: 12),
              Expanded(child: stats[row * 2 + 1]),
            ],
          ),
        ),
      ],
    ],
  );
}

class HomeStat extends StatelessWidget {
  const HomeStat({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
    this.explanation,
  });
  final String title, value;
  final String? explanation;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = HomePalette.of(context);
    return Tooltip(
      message: '$title: $value${explanation == null ? '' : '\n$explanation'}',
      child: Material(
        color: p.dark ? const Color(0xFF173D43) : HomePalette.tint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: p.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, size: 27, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          value,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.4,
                            color: p.text,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.5,
                          color: p.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeTodayCard extends StatelessWidget {
  const HomeTodayCard({
    super.key,
    required this.appointments,
    required this.onAdd,
    required this.onAppointment,
    this.showAddButton = true,
  });
  final bool showAddButton;
  final List<Appointment> appointments;
  final VoidCallback onAdd;
  final ValueChanged<Appointment> onAppointment;
  @override
  Widget build(BuildContext context) {
    final p = HomePalette.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: appointments.isEmpty ? p.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: appointments.isEmpty ? Border.all(color: p.border) : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: appointments.isEmpty
              ? const EdgeInsets.all(20)
              : EdgeInsets.zero,
          child: appointments.isEmpty
              ? Column(
                  children: [
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: HomePalette.teal.withValues(alpha: .08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.calendar_month_outlined,
                        color: HomePalette.teal,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'لا يوجد مواعيد اليوم',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'استمتع بيومك',
                      style: TextStyle(fontSize: 12, color: p.muted),
                    ),
                    const SizedBox(height: 10),
                    if (showAddButton) _addButton(),
                    const SizedBox(height: 2),
                  ],
                )
              : Column(
                  children: [
                    ...appointments.map(
                      (appointment) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: p.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(color: p.border),
                          ),
                          elevation: 1,
                          shadowColor: Colors.black.withValues(alpha: .04),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            onTap: () => onAppointment(appointment),
                            leading: Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: HomePalette.teal.withValues(alpha: .09),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.event_available_outlined,
                                color: HomePalette.teal,
                              ),
                            ),
                            title: Text(
                              appointment.patientName,
                              style: TextStyle(
                                color: p.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${appointment.time} · ${appointment.treatment}',
                              style: TextStyle(color: p.muted, fontSize: 12),
                            ),
                            trailing: const Icon(
                              Icons.chevron_left_rounded,
                              color: HomePalette.teal,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (showAddButton) _addButton(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _addButton() => FilledButton.icon(
    onPressed: onAdd,
    style: FilledButton.styleFrom(
      backgroundColor: HomePalette.teal,
      foregroundColor: Colors.white,
      shape: const StadiumBorder(),
      minimumSize: const Size(126, 38),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
    ),
    icon: const Icon(Icons.add_rounded, size: 19),
    label: const Text(
      'إضافة موعد',
      style: TextStyle(fontSize: 12, height: 1.5),
    ),
  );
}

/// The same two actions are visible in both embedded and standalone Home screens.
class HomeDashboardActions extends StatelessWidget {
  const HomeDashboardActions({
    super.key,
    required this.onAddAppointment,
    required this.onAddPatient,
  });
  final VoidCallback onAddAppointment, onAddPatient;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final vertical =
          box.maxWidth < 300 || MediaQuery.textScalerOf(context).scale(1) > 1.4;
      final buttons = [
        FilledButton.icon(
          key: const ValueKey('home-add-appointment'),
          onPressed: onAddAppointment,
          style: FilledButton.styleFrom(
            backgroundColor: HomePalette.teal,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          icon: const Icon(Icons.calendar_month_outlined, size: 21),
          label: const Text(
            'إضافة موعد',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
        OutlinedButton.icon(
          key: const ValueKey('home-add-patient'),
          onPressed: onAddPatient,
          style: OutlinedButton.styleFrom(
            foregroundColor: HomePalette.teal,
            minimumSize: const Size.fromHeight(48),
            side: BorderSide(color: HomePalette.of(context).border),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 21),
          label: const Text(
            'إضافة مريض',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
      ];
      return vertical
          ? Column(
              children: [buttons[0], const SizedBox(height: 10), buttons[1]],
            )
          : Row(
              children: [
                Expanded(child: buttons[0]),
                const SizedBox(width: 12),
                Expanded(child: buttons[1]),
              ],
            );
    },
  );
}
