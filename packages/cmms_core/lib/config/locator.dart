import 'service_locator.dart';

/// Resolve a registered dependency from GetIt.
T sl<T extends Object>() => getIt<T>();
