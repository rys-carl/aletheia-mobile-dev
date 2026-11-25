/// App-wide constants and environment configuration.
abstract final class AppConfig {
  static const appName = 'Aletheia';

  // Replace the 'sample' defaults with your real values, OR leave them and
  // pass them at run time instead (keeps them out of source control):
  //   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  //               --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const supabaseKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  /// Name of the private storage bucket that holds your photos.
  static const photoBucket = 'memories';

  /// Identifies your app to the OpenStreetMap tile server.
  /// Change this if your Android package name is different.
  static const mapUserAgent = 'com.example.aletheia_dev';

  /// Identifies your app to OpenStreetMap's search service (Nominatim), which
  /// requires it. Adding a contact email here is recommended by their policy.
  static const searchUserAgent = 'AletheiaPersonalApp/1.0';

  static const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
}