// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../chat_view_model/chat_view_model_client.dart';
import '../../providers/interface/chat_message.dart';
import '../../styles/llm_chat_view_style.dart';
import '../../styles/llm_message_style.dart';
import '../jumping_dots_progress_indicator/jumping_dots_progress_indicator.dart';
import 'adaptive_copy_text.dart';
import 'hovering_buttons.dart';

/// A widget that displays an LLM (Language Model) message in a chat interface.
@immutable
class LlmMessageView extends StatelessWidget {
  /// Creates an [LlmMessageView].
  ///
  /// The [message] parameter is required and represents the LLM chat message to
  /// be displayed.
  const LlmMessageView(
    this.message, {
    this.isWelcomeMessage = false,
    super.key,
  });

  /// The LLM chat message to be displayed.
  final ChatMessage message;

  /// Whether the message is the welcome message.
  final bool isWelcomeMessage;

  @override
  Widget build(BuildContext context) {
    // TEMPORARY MEASURES to decide whether to display message as map.
    late final bool isGisCoordinate;

    try {
      final decodedMessage = jsonDecode(message.text ?? '{}');
      isGisCoordinate = decodedMessage['coords'] != null;
    } catch (e) {
      isGisCoordinate = false;
    }

    return Row(
      children: [
        Flexible(
          flex: 6,
          child: Column(
            children: [
              ChatViewModelClient(
                builder: (context, viewModel, child) {
                  final text = message.text;
                  final chatStyle = LlmChatViewStyle.resolve(viewModel.style);
                  final llmStyle = LlmMessageStyle.resolve(
                    chatStyle.llmMessageStyle,
                  );

                  return Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          height: 20,
                          width: 20,
                          decoration: llmStyle.iconDecoration,
                          child: Icon(
                            llmStyle.icon,
                            color: llmStyle.iconColor,
                            size: 12,
                          ),
                        ),
                      ),
                      HoveringButtons(
                        isUserMessage: false,
                        chatStyle: chatStyle,
                        clipboardText: text,
                        child: Container(
                          decoration: llmStyle.decoration,
                          margin: const EdgeInsets.only(left: 28),
                          padding: const EdgeInsets.all(8),
                          child:
                              (text == null || text.isEmpty)
                                  ? SizedBox(
                                    width: 32,
                                    child: JumpingDotsProgressIndicator(
                                      fontSize: 24,
                                      color: chatStyle.progressIndicatorColor!,
                                    ),
                                  )
                                  : (isGisCoordinate &&
                                          viewModel.mapBuilder != null
                                      ? viewModel.mapBuilder!(
                                        context,
                                        message.text!,
                                      )
                                      : AdaptiveCopyText(
                                        clipboardText: text,
                                        chatStyle: chatStyle,
                                        child:
                                            isWelcomeMessage ||
                                                    viewModel.responseBuilder ==
                                                        null
                                                ? MarkdownBody(
                                                  data: text,
                                                  selectable: false,
                                                  styleSheet:
                                                      llmStyle.markdownStyle,
                                                  imageBuilder: _imageBuilder,
                                                  onTapLink: (
                                                    text,
                                                    href,
                                                    title,
                                                  ) async {
                                                    if (href == null) {
                                                      return;
                                                    }
                                                    await launchUrl(
                                                      Uri.parse(href),
                                                      webOnlyWindowName:
                                                          '_blank',
                                                    );
                                                  },
                                                )
                                                : viewModel.responseBuilder!(
                                                  context,
                                                  text,
                                                ),
                                      )),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const Flexible(flex: 2, child: SizedBox()),
      ],
    );
  }

  Widget _imageBuilder(
    Uri uri,
    String? title,
    String? alt,
    Widget Function(Uri, String?, double?, double?)? defaultImageBuilder,
  ) {
    return Row(
      children: [
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const double percentage = 0.5;
            const double minHeight = 50;
            const double minWidth = 50;
            const double maxHeight = 400;
            final double maxWidth =
                MediaQuery.of(context).size.width * percentage;
            return ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: minWidth,
                minHeight: minHeight,
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<Widget>(
                        builder: (_) {
                          return Scaffold(
                            appBar: AppBar(
                              leading: IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.arrow_back),
                              ),
                            ),
                            body: InteractiveViewer(
                              child: defaultImageBuilder(uri, null, null, null),
                            ),
                            extendBody: true,
                          );
                        },
                      ),
                    );
                  },
                  child: defaultImageBuilder!(uri, null, null, null),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
