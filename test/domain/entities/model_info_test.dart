import 'package:aios/domain/entities/model_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModelInfo', () {
    test('constructor_withRequiredFields_createsSuccessfully', () {
      final model = ModelInfo(
        name: 'gemma-2b-it',
        size: 5400000000,
        path: '/data/models/gemma-2b-it.gguf',
      );

      expect(model.name, 'gemma-2b-it');
      expect(model.size, 5400000000);
      expect(model.path, '/data/models/gemma-2b-it.gguf');
    });

    test('toJson_returnsCorrectMap', () {
      final model = ModelInfo(
        name: 'gemma-2b-it',
        size: 5400000000,
        path: '/data/models/gemma-2b-it.gguf',
      );

      final json = model.toJson();

      expect(json['name'], 'gemma-2b-it');
      expect(json['size'], 5400000000);
      expect(json['path'], '/data/models/gemma-2b-it.gguf');
    });

    test('fromJson_returnsCorrectInstance', () {
      final json = {
        'name': 'llama-7b',
        'size': 13000000000,
        'path': '/models/llama-7b.gguf',
      };

      final model = ModelInfo.fromJson(json);

      expect(model.name, 'llama-7b');
      expect(model.size, 13000000000);
      expect(model.path, '/models/llama-7b.gguf');
    });

    test('equality_sameValues_areEqual', () {
      final a = ModelInfo(
        name: 'gemma-2b-it',
        size: 5400000000,
        path: '/data/models/gemma-2b-it.gguf',
      );
      final b = ModelInfo(
        name: 'gemma-2b-it',
        size: 5400000000,
        path: '/data/models/gemma-2b-it.gguf',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('copyWith_returnsUpdatedCopy', () {
      final original = ModelInfo(
        name: 'gemma-2b-it',
        size: 5400000000,
        path: '/data/models/gemma-2b-it.gguf',
      );

      final copied = original.copyWith(name: 'gemma-7b-it');

      expect(copied.name, 'gemma-7b-it');
      expect(copied.size, 5400000000);
      expect(original.name, 'gemma-2b-it');
    });
  });
}
