import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'package:geocoding/geocoding.dart';

import '../../../application/providers/pin_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../widgets/cosmic/cosmic_background.dart';
import '../../../data/models/pin_model.dart';
import 'pin_success_screen.dart';
import 'steps/step_companions.dart';
import 'steps/step_photo.dart';
import 'steps/step_title.dart';
import 'steps/step_visibility_time.dart';
import 'wizard_state.dart';

/// 핀 생성 위자드 — 4단계 감성 마법사.
///
/// 사용:
/// ```dart
/// Navigator.of(context).push(MaterialPageRoute(
///   fullscreenDialog: true,
///   builder: (_) => PinWizardScreen(location: ...),
/// ));
/// ```
class PinWizardScreen extends ConsumerStatefulWidget {
  final LatLng location;
  final String? locationName;

  const PinWizardScreen({super.key, required this.location, this.locationName});

  @override
  ConsumerState<PinWizardScreen> createState() => _PinWizardScreenState();
}

class _PinWizardScreenState extends ConsumerState<PinWizardScreen> {
  late final PageController _pageCtrl;
  late WizardData _data;
  int _currentStep = 0;

  static const _totalSteps = 4;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _data = WizardData(
      location: widget.location,
      locationName: widget.locationName,
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_currentStep < _totalSteps - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _save();
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _close() {
    Navigator.of(context).pop();
  }

  Future<void> _save() async {
    if (!_data.isTitleValid) return;
    HapticFeedback.mediumImpact();

    // 역지오코딩으로 국가 코드 취득
    String countryCode = '';
    try {
      final marks = await placemarkFromCoordinates(
        _data.location.latitude,
        _data.location.longitude,
      );
      countryCode = marks.firstOrNull?.isoCountryCode?.toUpperCase() ?? '';
    } catch (_) {}

    final pin = PinModel(
      id: const Uuid().v4(),
      title: _data.title.trim(),
      description: '',
      latitude: _data.location.latitude,
      longitude: _data.location.longitude,
      emotion: AppConstants.emotions.first,
      weather: AppConstants.weathers.first,
      companions: List.from(_data.companions),
      intensityLevel: 3,
      pinShape: AppConstants.pinShapes.first,
      visibility: _data.visibility,
      photoPaths: List.from(_data.photoPaths),
      createdAt: _data.createdAt,
      countryCode: countryCode,
    );

    await ref.read(pinsProvider.notifier).add(pin);

    if (!mounted) return;
    final emoji = AppConstants.pinShapeEmojis[pin.pinShape] ?? '📍';
    final name = AppConstants.pinShapeNames[pin.pinShape] ?? pin.pinShape;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PinSuccessScreen(
        pinTitle: pin.title,
        locationLabel: _data.locationName,
        categoryEmoji: emoji,
        categoryName: name,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const CosmicBackground(),
          PageView(
            controller: _pageCtrl,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _currentStep = i),
            children: [
              StepPhoto(
                data: _data,
                totalSteps: _totalSteps,
                currentStep: 0,
                onClose: _close,
                onBack: null,
                onNext: _goNext,
                onSkip: _goNext,
                onChange: () => setState(() {}),
              ),
              StepTitle(
                data: _data,
                totalSteps: _totalSteps,
                currentStep: 1,
                onClose: _close,
                onBack: _goBack,
                onNext: _goNext,
                onChange: () => setState(() {}),
              ),
              StepCompanions(
                data: _data,
                totalSteps: _totalSteps,
                currentStep: 2,
                onClose: _close,
                onBack: _goBack,
                onNext: _goNext,
                onSkip: _goNext,
                onChange: () => setState(() {}),
              ),
              StepVisibilityTime(
                data: _data,
                totalSteps: _totalSteps,
                currentStep: 3,
                onClose: _close,
                onBack: _goBack,
                onSave: _save,
                onChange: () => setState(() {}),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
