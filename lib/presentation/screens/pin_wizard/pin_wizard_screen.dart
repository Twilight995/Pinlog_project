import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'package:geocoding/geocoding.dart';

import '../../../application/providers/friends_provider.dart';
import '../../../application/providers/pin_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../../../application/services/storage_service.dart';
import '../../widgets/cosmic/cosmic_background.dart';
import '../../../data/models/pin_model.dart';
import 'steps/step_category.dart';
import 'steps/step_companions.dart';
import 'steps/step_emotion_intensity.dart';
import 'steps/step_photo.dart';
import 'steps/step_title.dart';
import 'steps/step_visibility_time.dart';
import 'wizard_state.dart';
import 'wizard_style.dart';

class PinWizardScreen extends ConsumerStatefulWidget {
  final LatLng location;
  final String? locationName;

  const PinWizardScreen({super.key, required this.location, this.locationName});

  @override
  ConsumerState<PinWizardScreen> createState() => _PinWizardScreenState();
}

class _PinWizardScreenState extends ConsumerState<PinWizardScreen> {
  late WizardData _data;
  int _currentStep = 0;
  bool _goingForward = true;

  static const _totalSteps = 6;

  @override
  void initState() {
    super.initState();
    _data = WizardData(
      location: widget.location,
      locationName: widget.locationName,
    );
  }

  void _goNext() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _goingForward = true;
        _currentStep++;
      });
    } else {
      _save();
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() {
        _goingForward = false;
        _currentStep--;
      });
    }
  }

  void _close() => Navigator.of(context).pop();

  Future<void> _save() async {
    if (!_data.isTitleValid) return;
    HapticFeedback.mediumImpact();

    final pinId = const Uuid().v4();

    // 사진 업로드 (로컬 경로 → Supabase Storage URL)
    final photoPaths = await StorageService.instance
        .uploadPinPhotos(pinId, List.from(_data.photoPaths));

    String countryCode = '';
    try {
      final marks = await placemarkFromCoordinates(
        _data.location.latitude,
        _data.location.longitude,
      );
      countryCode = marks.firstOrNull?.isoCountryCode?.toUpperCase() ?? '';
    } catch (_) {}

    final pin = PinModel(
      id: pinId,
      title: _data.title.trim(),
      description: _data.description,
      latitude: _data.location.latitude,
      longitude: _data.location.longitude,
      emotion: _data.emotion,
      weather: _data.weather,
      companions: List.from(_data.companions),
      taggedFriendCodes: List.from(_data.taggedFriendCodes),
      intensityLevel: _data.intensityLevel,
      pinShape: _data.pinShape,
      visibility: _data.visibility,
      photoPaths: photoPaths,
      createdAt: _data.createdAt,
      countryCode: countryCode,
      pinOuterColor: _data.pinOuterColor,
      pinInnerColor: _data.pinInnerColor,
    );

    await ref.read(pinsProvider.notifier).add(pin);
    if (pin.taggedFriendCodes.isNotEmpty) {
      ref.read(friendsProvider.notifier).notifyPinTag(pin.taggedFriendCodes, pin.title);
    }

    if (!mounted) return;
    // 지도로 복귀 후 해당 위치에 새싹 애니메이션 트리거
    ref.read(newlyCreatedPinProvider.notifier).state = pin;
    Navigator.of(context).pop();
  }

  Widget _buildStepTransition(Widget child, Animation<double> animation) {
    final dir = _goingForward ? 1.0 : -1.0;
    final isEntering = child.key == ValueKey(_currentStep);
    final begin = isEntering ? Offset(0.07 * dir, 0.0) : Offset(-0.07 * dir, 0.0);

    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
      child: SlideTransition(
        position: Tween<Offset>(begin: begin, end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    );
  }

  Widget _buildStep(int step) {
    switch (step) {
      case 0:
        return StepPhoto(
          data: _data,
          totalSteps: _totalSteps,
          currentStep: 0,
          onClose: _close,
          onBack: null,
          onNext: _goNext,
          onSkip: _goNext,
          onChange: () => setState(() {}),
        );
      case 1:
        return StepCategory(
          data: _data,
          totalSteps: _totalSteps,
          currentStep: 1,
          onClose: _close,
          onBack: _goBack,
          onNext: _goNext,
          onChange: () => setState(() {}),
        );
      case 2:
        return StepTitle(
          data: _data,
          totalSteps: _totalSteps,
          currentStep: 2,
          onClose: _close,
          onBack: _goBack,
          onNext: _goNext,
          onChange: () => setState(() {}),
        );
      case 3:
        return StepEmotionIntensity(
          data: _data,
          totalSteps: _totalSteps,
          currentStep: 3,
          onClose: _close,
          onBack: _goBack,
          onNext: _goNext,
          onChange: () => setState(() {}),
        );
      case 4:
        return StepCompanions(
          data: _data,
          totalSteps: _totalSteps,
          currentStep: 4,
          onClose: _close,
          onBack: _goBack,
          onNext: _goNext,
          onSkip: _goNext,
          onChange: () => setState(() {}),
        );
      case 5:
        return StepVisibilityTime(
          data: _data,
          totalSteps: _totalSteps,
          currentStep: 5,
          onClose: _close,
          onBack: _goBack,
          onSave: _save,
          onChange: () => setState(() {}),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themePresetProvider).primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = WizardStyle.fromTheme(themeColor, isDark: isDark);

    return WizardStyleScope(
      style: style,
      child: Scaffold(
        backgroundColor: style.background,
        body: Stack(
          children: [
            if (style.hasCosmic) const CosmicBackground(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 360),
              reverseDuration: const Duration(milliseconds: 360),
              transitionBuilder: _buildStepTransition,
              child: KeyedSubtree(
                key: ValueKey(_currentStep),
                child: _buildStep(_currentStep),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
