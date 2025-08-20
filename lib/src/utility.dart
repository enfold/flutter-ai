// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart' show BuildContext, CupertinoApp;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_platform/universal_platform.dart';

import 'dialogs/adaptive_snack_bar/adaptive_snack_bar.dart';

bool? _isCupertinoApp;

/// Determines if the current application is a Cupertino-style app.
///
/// This function checks the widget tree for the presence of a [CupertinoApp]
/// widget. If found, it indicates that the app is using Cupertino (iOS-style)
/// widgets.
///
/// Parameters:
///   * [context]: The [BuildContext] used to search the widget tree.
///
/// Returns: A [bool] value. `true` if a [CupertinoApp] is found in the widget
///   tree, `false` otherwise.
bool isCupertinoApp(BuildContext context) {
  // caching the result to avoid recomputing it on every call; it's not likely
  // to change during the lifetime of the app
  _isCupertinoApp ??=
      context.findAncestorWidgetOfExactType<CupertinoApp>() != null;
  return _isCupertinoApp!;
}

/// Determines if the current platform is a mobile device (Android or iOS).
///
/// This constant uses the [UniversalPlatform] package to check the platform.
///
/// Returns:
///   A [bool] value. `true` if the platform is either Android or iOS,
///   `false` otherwise.
final isMobile = UniversalPlatform.isAndroid || UniversalPlatform.isIOS;

/// Copies the given text to the clipboard and shows a confirmation message.
///
/// This function uses the [Clipboard] API to copy the provided [text] to the
/// system clipboard. After copying, it displays a confirmation message using
/// [AdaptiveSnackBar] if the [context] is still mounted.
///
/// Parameters:
///   * [context]: The [BuildContext] used to show the confirmation message.
///   * [text]: The text to be copied to the clipboard.
///
/// Returns: A [Future] that completes when the text has been copied to the
///   clipboard and the confirmation message has been shown.
Future<void> copyToClipboard(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));

  int messageCount = _MessageCounter.instance.messageCount;
  if (messageCount < 3 && context.mounted) {
    messageCount++;
    _MessageCounter.instance.incrementCount();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        showCloseIcon: true,
        content: Text('Message copied to new snackbar clipboard'),
      ),
    );
  }
}

/// Inverts the given color.
///
/// This function takes a [Color] object and returns a new [Color] object
/// with the RGB values inverted. The alpha value remains unchanged.
///
/// Parameters:
///   * [color]: The [Color] to be inverted. This parameter must not be null.
///
/// Returns: A new [Color] object with the inverted RGB values.
Color? invertColor(Color? color) =>
    color != null
        ? Color.from(
          alpha: color.a,
          red: 1 - color.r,
          green: 1 - color.g,
          blue: 1 - color.b,
        )
        : null;

class _MessageCounter {
  // Private constructor
  _MessageCounter._privateConstructor();

  // Singleton instance
  static final _MessageCounter instance = _MessageCounter._privateConstructor();

  // Message count
  int _messageCount = 0;

  // Getter for the message count
  int get messageCount => _messageCount;

  // Method to increment the message count
  void incrementCount() {
    _messageCount++;
  }

  // Method to reset the message count (if needed)
  void resetCount() {
    _messageCount = 0;
  }
}
