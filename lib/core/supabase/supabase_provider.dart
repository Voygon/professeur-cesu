import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Émet le User connecté (ou null) à chaque changement d'état d'auth Supabase.
final supabaseUserProvider = StreamProvider<User?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange
      .map((state) => state.session?.user);
});
