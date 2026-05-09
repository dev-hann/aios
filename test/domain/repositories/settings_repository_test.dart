import 'package:aios/domain/repositories/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockSettingsRepository implements SettingsRepository {
  int _contextSize = SettingsRepository.defaultContextSize;
  int _maxTokens = SettingsRepository.defaultMaxTokens;
  double _temperature = SettingsRepository.defaultTemperature;
  int _topK = SettingsRepository.defaultTopK;
  double _topP = SettingsRepository.defaultTopP;
  double _repeatPenalty = SettingsRepository.defaultRepeatPenalty;
  int _agentMaxIterations = SettingsRepository.defaultAgentMaxIterations;
  String? _lastModelPath;
  bool _onboardingCompleted = false;


  @override
  int get contextSize => _contextSize;

  @override
  int get maxTokens => _maxTokens;

  @override
  double get temperature => _temperature;

  @override
  int get topK => _topK;

  @override
  double get topP => _topP;

  @override
  double get repeatPenalty => _repeatPenalty;

  @override
  int get agentMaxIterations => _agentMaxIterations;

  @override
  String? get lastModelPath => _lastModelPath;

  @override
  bool get onboardingCompleted => _onboardingCompleted;


  @override
  Future<void> setContextSize(int value) async => _contextSize = value;

  @override
  Future<void> setMaxTokens(int value) async => _maxTokens = value;

  @override
  Future<void> setTemperature(double value) async => _temperature = value;

  @override
  Future<void> setTopK(int value) async => _topK = value;

  @override
  Future<void> setTopP(double value) async => _topP = value;

  @override
  Future<void> setRepeatPenalty(double value) async => _repeatPenalty = value;

  @override
  Future<void> setAgentMaxIterations(int value) async =>
      _agentMaxIterations = value;

  @override
  Future<void> setLastModelPath(String path) async => _lastModelPath = path;

  @override
  Future<void> clearLastModelPath() async => _lastModelPath = null;

  @override
  Future<void> setOnboardingCompleted() async =>
      _onboardingCompleted = true;

}

void main() {
  group('SettingsRepository', () {
    late _MockSettingsRepository repository;

    setUp(() {
      repository = _MockSettingsRepository();
    });

    test('defaults_matchConstants', () {
      expect(repository.contextSize, SettingsRepository.defaultContextSize);
      expect(repository.maxTokens, SettingsRepository.defaultMaxTokens);
      expect(repository.temperature, SettingsRepository.defaultTemperature);
      expect(repository.topK, SettingsRepository.defaultTopK);
      expect(repository.topP, SettingsRepository.defaultTopP);
      expect(
        repository.repeatPenalty,
        SettingsRepository.defaultRepeatPenalty,
      );
      expect(
        repository.agentMaxIterations,
        SettingsRepository.defaultAgentMaxIterations,
      );
    });

    test('last_model_path_initiallyNull', () {
      expect(repository.lastModelPath, isNull);
    });

    test('set_contextSize_updatesValue', () async {
      await repository.setContextSize(4096);

      expect(repository.contextSize, 4096);
    });

    test('set_maxTokens_updatesValue', () async {
      await repository.setMaxTokens(1024);

      expect(repository.maxTokens, 1024);
    });

    test('set_temperature_updatesValue', () async {
      await repository.setTemperature(0.5);

      expect(repository.temperature, 0.5);
    });

    test('set_topK_updatesValue', () async {
      await repository.setTopK(20);

      expect(repository.topK, 20);
    });

    test('set_topP_updatesValue', () async {
      await repository.setTopP(0.8);

      expect(repository.topP, 0.8);
    });

    test('set_repeatPenalty_updatesValue', () async {
      await repository.setRepeatPenalty(1.2);

      expect(repository.repeatPenalty, 1.2);
    });

    test('set_agentMaxIterations_updatesValue', () async {
      await repository.setAgentMaxIterations(12);

      expect(repository.agentMaxIterations, 12);
    });

    test('set_lastModelPath_updatesValue', () async {
      await repository.setLastModelPath('/path/to/model.gguf');

      expect(repository.lastModelPath, '/path/to/model.gguf');
    });

    test('clear_lastModelPath_setsNull', () async {
      await repository.setLastModelPath('/path/to/model.gguf');
      expect(repository.lastModelPath, isNotNull);

      await repository.clearLastModelPath();

      expect(repository.lastModelPath, isNull);
    });

    test('onboardingCompleted_defaultIsFalse', () {
      expect(repository.onboardingCompleted, isFalse);
    });

    test('setOnboardingCompleted_setsTrue', () async {
      await repository.setOnboardingCompleted();

      expect(repository.onboardingCompleted, isTrue);
    });
  });

  group('SettingsRepository constants', () {
    test('default_values_areExpected', () {

      expect(SettingsRepository.defaultContextSize, 2048);
      expect(SettingsRepository.defaultMaxTokens, 512);
      expect(SettingsRepository.defaultTemperature, 0.7);
      expect(SettingsRepository.defaultTopK, 40);
      expect(SettingsRepository.defaultTopP, 0.9);
      expect(SettingsRepository.defaultRepeatPenalty, 1.1);
      expect(SettingsRepository.defaultAgentMaxIterations, 8);
    });
  });
}
