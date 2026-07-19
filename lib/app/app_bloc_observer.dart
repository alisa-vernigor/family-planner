import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/logging/app_logger.dart';

final class AppBlocObserver extends BlocObserver {
  @override
  void onCreate(BlocBase<dynamic> bloc) {
    super.onCreate(bloc);
    AppLogger.debug('BLoC создан: ${bloc.runtimeType}');
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    AppLogger.debug(
      'BLoC изменился: ${bloc.runtimeType}; '
      'изменение: $change',
    );
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    AppLogger.error(
      'Ошибка в BLoC: ${bloc.runtimeType}',
      error: error,
      stackTrace: stackTrace,
    );
    super.onError(bloc, error, stackTrace);
  }

  @override
  void onClose(BlocBase<dynamic> bloc) {
    AppLogger.debug('BLoC закрыт: ${bloc.runtimeType}');
    super.onClose(bloc);
  }
}
