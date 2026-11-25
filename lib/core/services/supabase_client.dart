import 'package:supabase_flutter/supabase_flutter.dart';

/// The Supabase client, available anywhere after Supabase.initialize().
SupabaseClient get supabase => Supabase.instance.client;
