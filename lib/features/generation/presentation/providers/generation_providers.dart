import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_providers.dart';
import '../../data/repositories/supabase_generation_repository.dart';
import '../../domain/repositories/generation_repository.dart';

final generationRepositoryProvider = Provider<GenerationRepository>(
  (ref) => SupabaseGenerationRepository(ref.watch(supabaseClientProvider)),
);
