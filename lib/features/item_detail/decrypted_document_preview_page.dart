import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/attachment/attachment_model.dart';
import '../../core/attachment/attachment_payload_reader.dart';
import '../../core/attachment/attachment_preview_policy.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/widgets/anch_subpage_app_bar.dart';
import '../privacy/screen_protection_scope.dart';

class DecryptedDocumentPreviewPage extends StatefulWidget {
  const DecryptedDocumentPreviewPage({super.key, required this.attachment});

  final AttachmentModel attachment;

  @override
  State<DecryptedDocumentPreviewPage> createState() =>
      _DecryptedDocumentPreviewPageState();
}

class _DecryptedDocumentPreviewPageState
    extends State<DecryptedDocumentPreviewPage>
    with WidgetsBindingObserver {
  String? _text;
  String? _errorMessage;
  bool _hasError = false;
  bool _isLoading = true;
  int _loadGeneration = 0;
  bool _dismissAfterForeground = false;
  bool _dismissScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    final loadGeneration = _loadGeneration;
    if (!AttachmentPreviewPolicy.canPreviewTextInApp(widget.attachment)) {
      if (!mounted ||
          loadGeneration != _loadGeneration ||
          _dismissAfterForeground) {
        return;
      }
      setState(() {
        _hasError = true;
        _isLoading = false;
        _errorMessage = '该文本附件较大，无法在应用内预览。请返回后使用其他应用打开。';
      });
      return;
    }

    Uint8List? bytes;
    try {
      bytes = await AttachmentPayloadReader.read(widget.attachment);
      if (!mounted ||
          loadGeneration != _loadGeneration ||
          _dismissAfterForeground) {
        return;
      }
      final text = utf8.decode(bytes);
      if (!mounted ||
          loadGeneration != _loadGeneration ||
          _dismissAfterForeground) {
        return;
      }
      setState(() {
        _text = text;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted &&
          loadGeneration == _loadGeneration &&
          !_dismissAfterForeground) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } finally {
      bytes?.fillRange(0, bytes.length, 0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isActualBackground =
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached;
    if (isActualBackground) {
      _scrubForBackground();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _dismissAfterResumedFrame();
    }
  }

  void _scrubForBackground() {
    if (_dismissAfterForeground) return;
    _loadGeneration++;
    setState(() {
      _dismissAfterForeground = true;
      _text = null;
      _errorMessage = null;
      _hasError = false;
      _isLoading = false;
    });
  }

  void _dismissAfterResumedFrame() {
    if (!_dismissAfterForeground || _dismissScheduled) return;
    _dismissScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loadGeneration++;
    _text = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScreenProtectionScope(child: _buildPage(context));

  Widget _buildPage(BuildContext context) {
    if (_dismissAfterForeground) return const ColoredBox(color: Colors.black);
    return Scaffold(
      backgroundColor: context.anchColors.background,
      appBar: AnchSubpageAppBar(
        title: '文本预览',
        backgroundColor: context.anchColors.background,
        foregroundColor: context.anchColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        onBack: () => Navigator.pop(context),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
          ? _PreviewError(message: _errorMessage)
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _text ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: context.anchColors.textPrimary,
                  ),
                ),
              ),
            ),
    );
  }
}

class _PreviewError extends StatelessWidget {
  const _PreviewError({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message ?? '无法打开该文本附件。你可以返回后使用其他应用打开。',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.anchColors.textSecondary),
        ),
      ),
    );
  }
}
