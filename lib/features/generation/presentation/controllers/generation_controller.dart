import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/generation_outcome.dart';
import '../../domain/entities/generation_request.dart';
import '../providers/generation_providers.dart';

final generationControllerProvider = AutoDisposeAsyncNotifierProvider<
    GenerationController, GenerationOutcome?>(
  GenerationController.new,
);

class GenerationController extends AutoDisposeAsyncNotifier<GenerationOutcome?> {
  @override
  FutureOr<GenerationOutcome?> build() => null;

  Future<void> generate(GenerationRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(generationRepositoryProvider).generate(request),
    );
  }

  void clear() {
    state = const AsyncData(null);
  }
}
