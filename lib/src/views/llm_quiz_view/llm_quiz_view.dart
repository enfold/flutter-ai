// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_ai_toolkit/src/providers/interface/message_origin.dart';
import 'package:flutter_ai_toolkit/src/views/llm_chat_view/llm_response.dart';

import '../../chat_view_model/chat_view_model.dart';
import '../../chat_view_model/chat_view_model_provider.dart';
import '../../dialogs/adaptive_dialog.dart';
import '../../dialogs/adaptive_snack_bar/adaptive_snack_bar.dart';
import '../../llm_exception.dart';
import '../../platform_helper/platform_helper.dart' as ph;
import '../../providers/interface/attachments.dart';
import '../../providers/interface/chat_message.dart';
import '../../providers/interface/llm_provider.dart';
import '../../styles/llm_chat_view_style.dart';
import '../quiz_history_view.dart';
import '../chat_input/chat_input.dart';
import '../response_builder.dart';

/// A widget that displays a chat interface for interacting with an LLM
/// (Language Model).
@immutable
class LlmQuizView extends StatefulWidget {
  /// Creates an [LlmQuizView] widget.
  ///
  /// This widget provides a chat interface for interacting with an LLM
  /// (Language Model). It requires an [LlmProvider] to manage the chat
  /// interactions and can be customized with various style and configuration
  /// options.
  ///
  /// - [provider]: The [LlmProvider] that manages the chat interactions.
  /// - [quiz]: The quiz id with its list of questions.
  /// - [style]: Optional. The [LlmChatViewStyle] to customize the appearance of
  ///   the chat interface.
  /// - [responseBuilder]: Optional. A custom [ResponseBuilder] to handle the
  ///   display of LLM responses.
  /// - [messageSender]: Optional. A custom [LlmStreamGenerator] to handle the
  ///   sending of messages. If provided, this is used instead of the
  ///   `sendMessageStream` method of the provider. It's the responsibility of
  ///   the caller to ensure that the [messageSender] properly streams the
  ///   response. This is useful for augmenting the user's prompt with
  ///   additional information, in the case of prompt engineering or RAG. It's
  ///   also useful for simple logging.
  // XXXXXXXX TEMPORARILY DISABLED XXXXXXXX
  /// - [suggestions]: Optional. A list of predefined suggestions to display
  ///   when the chat history is empty. Defaults to an empty list.
  /// - [welcomeMessage]: Optional. A welcome message to display when the chat
  ///   is first opened.
  /// - [onCancelCallback]: Optional. The action to perform when the user
  ///   cancels a chat operation. By default, a snackbar is displayed with the
  ///   canceled message.
  /// - [onErrorCallback]: Optional. The action to perform when an
  ///   error occurs during a chat operation. By default, an alert dialog is
  ///   displayed with the error message.
  /// - [cancelMessage]: Optional. The message to display when the user cancels
  ///   a chat operation. Defaults to 'CANCEL'.
  /// - [errorMessage]: Optional. The message to display when an error occurs
  ///   during a chat operation. Defaults to 'ERROR'.
  /// - [enableAttachments]: Optional. Whether to enable file and image attachments in the chat input.
  /// - [enableVoiceNotes]: Optional. Whether to enable voice notes in the chat input.
  LlmQuizView({
    required LlmProvider provider,
    required Map<String, dynamic> quiz,
    LlmChatViewStyle? style,
    ResponseBuilder? responseBuilder,
    LlmStreamGenerator? messageSender,
    SpeechToTextConverter? speechToText,
    // XXXXXXXX Temporarily disabled XXXXXXXX
    // List<String> suggestions = const [],
    String? welcomeMessage,
    this.onCancelCallback,
    this.onErrorCallback,
    this.cancelMessage = 'CANCEL',
    this.errorMessage = 'ERROR',
    this.enableAttachments = true,
    this.enableVoiceNotes = true,
    this.autofocus,
    super.key,
  }) : viewModel = ChatViewModel(
         provider: provider,
         responseBuilder: responseBuilder,
         messageSender: messageSender,
         speechToText: speechToText,
         style: style,
         suggestions: [],
         welcomeMessage: welcomeMessage,
         enableAttachments: enableAttachments,
         enableVoiceNotes: enableVoiceNotes,
       ),
       quizId = quiz['id'],
       questions = quiz['questions'];

  /// Whether to enable file and image attachments in the chat input.
  ///
  /// When set to false, the attachment button and related functionality will be
  /// disabled.
  final bool enableAttachments;

  /// Whether to enable voice notes in the chat input.
  ///
  /// When set to false, the voice recording button and related functionality
  /// will be disabled.
  final bool enableVoiceNotes;

  /// The view model containing the chat state and configuration.
  ///
  /// This [ChatViewModel] instance holds the LLM provider, transcript,
  /// response builder, welcome message, and LLM icon for the chat interface.
  /// It encapsulates the core data and functionality needed for the chat view.
  late final ChatViewModel viewModel;

  /// The action to perform when the user cancels a chat operation.
  ///
  /// By default, a snackbar is displayed with the canceled message.
  final void Function(BuildContext context)? onCancelCallback;

  /// The action to perform when an error occurs during a chat operation.
  ///
  /// By default, an alert dialog is displayed with the error message.
  final void Function(BuildContext context, LlmException error)?
  onErrorCallback;

  /// The text message to display when the user cancels a chat operation.
  ///
  /// Defaults to 'CANCEL'.
  final String cancelMessage;

  /// The text message to display when an error occurs during a chat operation.
  ///
  /// Defaults to 'ERROR'.
  final String errorMessage;

  /// Whether to autofocus the chat input field when the view is displayed.
  ///
  /// Defaults to `null`, which means it will be determined based on the
  /// presence of suggestions. If there are no suggestions, the input field
  /// will be focused automatically.
  final bool? autofocus;

  /// Quiz id
  final String quizId;

  /// List of quiz questions
  final List<Map<String, dynamic>> questions;

  @override
  State<LlmQuizView> createState() => _LlmQuizViewState();
}

class _LlmQuizViewState extends State<LlmQuizView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  LlmResponse? _pendingPromptResponse;
  ChatMessage? _initialMessage;
  ChatMessage? _associatedResponse;
  LlmResponse? _pendingSttResponse;

  int _questionIndex = 0;
  bool get _quizFinished => _questionIndex >= widget.questions.length;

  @override
  void initState() {
    super.initState();
    widget.viewModel.provider.addListener(_onHistoryChanged);
    widget.viewModel.suggestions.clear();

    final firstQuestion = widget.questions[_questionIndex];
    final initialHistory = widget.viewModel.provider.history.toList();
    initialHistory.add(
      ChatMessage(
        origin: MessageOrigin.llm,
        text: widget.questions[_questionIndex]['inputs'],
        attachments: [],
      ),
    );
    widget.viewModel.provider.history = initialHistory;
    widget.viewModel.suggestions.addAll(firstQuestion['metadata']['options']);
  }

  @override
  void dispose() {
    super.dispose();
    widget.viewModel.provider.removeListener(_onHistoryChanged);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // for AutomaticKeepAliveClientMixin

    final chatStyle = LlmChatViewStyle.resolve(widget.viewModel.style);
    return ListenableBuilder(
      listenable: widget.viewModel.provider,
      builder:
          (context, child) => ChatViewModelProvider(
            viewModel: widget.viewModel,
            child: GestureDetector(
              onTap: () {
                // Dismiss keyboard when tapping anywhere in the view
                FocusScope.of(context).unfocus();
              },
              child: Container(
                color: chatStyle.backgroundColor,
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          QuizHistoryView(
                            // can only edit if we're not waiting on the LLM or if
                            // we're not already editing an LLM response
                            onEditMessage:
                                _pendingPromptResponse == null &&
                                        _associatedResponse == null
                                    ? _onEditMessage
                                    : null,
                            onSelectSuggestion: _onSelectSuggestion,
                          ),
                        ],
                      ),
                    ),
                    ChatInput(
                      initialMessage: _initialMessage,
                      autofocus:
                          widget.autofocus ??
                          widget.viewModel.suggestions.isEmpty,
                      onCancelEdit:
                          _associatedResponse != null ? _onCancelEdit : null,
                      onSendMessage: _onSendMessage,
                      onCancelMessage:
                          _pendingPromptResponse == null
                              ? null
                              : _onCancelMessage,
                      onTranslateStt: _onTranslateStt,
                      onCancelStt:
                          _pendingSttResponse == null ? null : _onCancelStt,
                      disable: _quizFinished,
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Future<void> _onSendMessage(
    String prompt,
    Iterable<Attachment> attachments,
  ) async {
    _initialMessage = null;
    _associatedResponse = null;
    widget.viewModel.suggestions.clear();

    if (_quizFinished) {
      return;
    }

    // check the viewmodel for a user-provided message sender to use instead
    final sendMessageStream =
        widget.viewModel.messageSender ??
        widget.viewModel.provider.sendMessageStream;

    final message = jsonEncode({
      'quizId': widget.quizId,
      'questionId': widget.questions[_questionIndex]['uuid'],
      'message': prompt,
    });

    _pendingPromptResponse = LlmResponse(
      stream: sendMessageStream(message, attachments: attachments),
      // update during the streaming response input so that the end-user can see
      // the response as it streams in
      onUpdate: (_) => setState(() {}),
      onDone: _onPromptDone,
    );

    setState(() {});
  }

  void _onPromptDone(LlmException? error) {
    setState(() => _pendingPromptResponse = null);
    unawaited(_showLlmException(error));
    _showNextQuestion();
  }

  void _showNextQuestion() {
    setState(() {
      _questionIndex++;
    });
    if (_quizFinished) {
      return;
    }
    final history = widget.viewModel.provider.history.toList();
    final message = ChatMessage(
      origin: MessageOrigin.llm,
      text: widget.questions[_questionIndex]['inputs'],
      attachments: [],
    );
    history.add(message);
    widget.viewModel.provider.history = history;

    widget.viewModel.suggestions.clear();
    widget.viewModel.suggestions.addAll(
      widget.questions[_questionIndex]['metadata']['options'],
    );
  }

  void _onCancelMessage() => _pendingPromptResponse?.cancel();

  void _onEditMessage(ChatMessage message) {
    assert(_pendingPromptResponse == null);

    // remove the last llm message
    final history = widget.viewModel.provider.history.toList();
    assert(history.last.origin.isLlm);
    final llmMessage = history.removeLast();

    // remove the last user message
    assert(history.last.origin.isUser);
    final userMessage = history.removeLast();

    // set the history to the new history
    widget.viewModel.provider.history = history;

    // set the text  to the last userMessage to provide initial prompt and
    // attachments for the user to edit
    setState(() {
      _initialMessage = userMessage;
      _associatedResponse = llmMessage;
    });
  }

  Future<void> _onTranslateStt(
    XFile file,
    Iterable<Attachment> currentAttachments,
  ) async {
    assert(widget.enableVoiceNotes);
    _initialMessage = null;
    _associatedResponse = null;

    final response = StringBuffer();
    _pendingSttResponse = LlmResponse(
      stream:
          widget.viewModel.speechToText?.call(file) ??
          _convertSpeechToText(file),
      onUpdate: (text) => response.write(text),
      onDone:
          (error) async => _onSttDone(
            error,
            response.toString().trim(),
            file,
            currentAttachments,
          ),
    );

    setState(() {});
  }

  Stream<String> _convertSpeechToText(XFile file) async* {
    // use the LLM to translate the attached audio to text
    const prompt =
        'translate the attached audio to text; provide the result of that '
        'translation as just the text of the translation itself. be careful to '
        'separate the background audio from the foreground audio and only '
        'provide the result of translating the foreground audio.';
    final attachments = [await FileAttachment.fromFile(file)];

    yield* widget.viewModel.provider.generateStream(
      prompt,
      attachments: attachments,
    );
  }

  Future<void> _onSttDone(
    LlmException? error,
    String response,
    XFile file,
    Iterable<Attachment> attachments,
  ) async {
    assert(_pendingSttResponse != null);
    setState(() {
      // Preserve any existing attachments from the current input
      _initialMessage = ChatMessage.user(response, attachments);
      _pendingSttResponse = null;
    });

    // delete the file now that the LLM has translated it
    unawaited(ph.deleteFile(file));

    // show any error that occurred
    unawaited(_showLlmException(error));
  }

  void _onCancelStt() => _pendingSttResponse?.cancel();

  Future<void> _showLlmException(LlmException? error) async {
    if (error == null) return;

    // stop from the progress from indicating in case there was a failure
    // before any text response happened; the progress indicator uses a null
    // text message to keep progressing. plus we don't want to just show an
    // empty LLM message.
    final llmMessage = widget.viewModel.provider.history.last;
    if (llmMessage.text == null) {
      llmMessage.append(
        error is LlmCancelException
            ? widget.cancelMessage
            : widget.errorMessage,
      );
    }

    switch (error) {
      case LlmCancelException():
        if (widget.onCancelCallback != null) {
          widget.onCancelCallback!(context);
        } else {
          AdaptiveSnackBar.show(context, 'LLM operation canceled by user');
        }
        break;
      case LlmFailureException():
      case LlmException():
        if (widget.onErrorCallback != null) {
          widget.onErrorCallback!(context, error);
        } else {
          await AdaptiveAlertDialog.show(
            context: context,
            content: Text(error.toString()),
            showOK: true,
          );
        }
    }
  }

  void _onSelectSuggestion(String suggestion) {
    setState(() => _initialMessage = ChatMessage.user(suggestion, []));
    _onSendMessage(suggestion, []);
  }

  void _onHistoryChanged() {
    // if the history is cleared, clear the initial message
    if (widget.viewModel.provider.history.isEmpty) {
      setState(() {
        _initialMessage = null;
        _associatedResponse = null;
      });
    }
  }

  void _onCancelEdit() {
    assert(_initialMessage != null);
    assert(_associatedResponse != null);

    // add the original message and response back to the history
    final history = widget.viewModel.provider.history.toList();
    history.addAll([_initialMessage!, _associatedResponse!]);
    widget.viewModel.provider.history = history;

    setState(() {
      _initialMessage = null;
      _associatedResponse = null;
    });
  }
}
