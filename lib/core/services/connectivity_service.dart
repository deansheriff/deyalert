import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  Stream<List<ConnectivityResult>> get changes =>
      Connectivity().onConnectivityChanged;

  void listen(Future<void> Function() syncPending) {
    _subscription = changes.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none))
        syncPending();
    });
  }

  Future<void> dispose() => _subscription?.cancel() ?? Future.value();
}
