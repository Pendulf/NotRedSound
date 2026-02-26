import 'package:flutter/material.dart';

class ScrollSync {
  static void syncHorizontal({
    required ScrollController source,
    required ScrollController target,
    required bool isSyncing,
    required Function(bool) setIsSyncing,
  }) {
    if (isSyncing) return;
    
    if (source.hasClients && target.hasClients) {
      setIsSyncing(true);
      target.jumpTo(source.offset);
      setIsSyncing(false);
    }
  }

  static void setupSync({
    required ScrollController controller1,
    required ScrollController controller2,
    required ValueNotifier<bool> isSyncing,
  }) {
    controller1.addListener(() {
      if (controller1.hasClients && controller2.hasClients && !isSyncing.value) {
        isSyncing.value = true;
        controller2.jumpTo(controller1.offset);
        isSyncing.value = false;
      }
    });

    controller2.addListener(() {
      if (controller1.hasClients && controller2.hasClients && !isSyncing.value) {
        isSyncing.value = true;
        controller1.jumpTo(controller2.offset);
        isSyncing.value = false;
      }
    });
  }
}