import 'package:aios/domain/repositories/update_repository.dart';
import 'package:aios/presentation/providers/update_notifier.dart';
import 'package:aios/presentation/providers/update_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final updateRepositoryProvider = Provider<UpdateRepository>((ref) {
  throw UnimplementedError('updateRepositoryProvider must be overridden');
});

final currentVersionProvider = Provider<String>((ref) {
  throw UnimplementedError('currentVersionProvider must be overridden');
});

final updateProvider =
    StateNotifierProvider<UpdateNotifier, UpdateState>((ref) {
  final updateRepo = ref.watch(updateRepositoryProvider);
  final currentVersion = ref.watch(currentVersionProvider);
  return UpdateNotifier(updateRepo, currentVersion);
});
