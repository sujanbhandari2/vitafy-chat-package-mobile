import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/messenger_theme.dart';
import '../utils/messenger_media_url.dart';
import 'messenger_media_cache.dart';
import 'messenger_media_cache_scope.dart';

/// Network-cached image with fixed-size placeholder loader, fade-in, and
/// [Image.network] fallback when the disk cache is unavailable.
class MessengerCachedImage extends StatefulWidget {
  const MessengerCachedImage({
    super.key,
    required this.source,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.placeholderColor,
    this.loaderColor,
    this.errorMessage = 'Unable to load image',
    this.fadeDuration = const Duration(milliseconds: 200),
    this.loaderStrokeWidth = 2,
    this.containFit = false,
    this.showLoader = true,
  });

  final String source;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final Color? placeholderColor;
  final Color? loaderColor;
  final String errorMessage;
  final Duration fadeDuration;
  final double loaderStrokeWidth;
  final bool containFit;
  /// When false, shows placeholder only (no spinner). Use for stacked images
  /// behind the front card so only one loader is visible.
  final bool showLoader;

  @override
  State<MessengerCachedImage> createState() => _MessengerCachedImageState();
}

class _MessengerCachedImageState extends State<MessengerCachedImage> {
  File? _file;
  bool _loading = true;
  bool _failed = false;
  bool _useNetworkFallback = false;
  String _resolvedUrl = '';
  Map<String, String> _networkHeaders = const {};
  int _loadGeneration = 0;
  String? _lastResolvedSource;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleResolve();
  }

  @override
  void didUpdateWidget(MessengerCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _scheduleResolve();
    }
  }

  void _scheduleResolve() {
    final raw = widget.source.trim();
    if (raw == _lastResolvedSource && !_loading && !_failed) {
      return;
    }
    _loadGeneration++;
    _resolve(_loadGeneration);
  }

  Future<void> _resolve(int generation) async {
    final raw = widget.source.trim();
    if (raw.isEmpty) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _loading = false;
        _failed = true;
        _file = null;
        _useNetworkFallback = false;
      });
      return;
    }

    final resolved = MessengerMediaCacheScope.maybeOf(context) != null
        ? MessengerMediaCacheScope.resolveMediaUrl(context, raw)
        : messengerAbsoluteMediaUrl(raw);
    _lastResolvedSource = raw;

    if (!messengerMediaSourceIsNetwork(resolved)) {
      final file = File(resolved);
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      if (await file.exists()) {
        setState(() {
          _file = file;
          _loading = false;
          _failed = false;
          _useNetworkFallback = false;
          _resolvedUrl = resolved;
        });
      } else {
        setState(() {
          _loading = false;
          _failed = true;
          _file = null;
          _useNetworkFallback = false;
        });
      }
      return;
    }

    if (mounted && generation == _loadGeneration) {
      setState(() {
        _loading = true;
        _failed = false;
        _file = null;
        _useNetworkFallback = false;
        _resolvedUrl = resolved;
      });
    }

    final scope = MessengerMediaCacheScope.maybeOf(context);
    final headers = scope != null
        ? await MessengerMediaCacheScope.resolveHeaders(context, resolved)
        : const <String, String>{};

    if (!mounted || generation != _loadGeneration) {
      return;
    }

    File? cached;
    if (scope != null) {
      try {
        cached = await scope.cache.getFile(resolved, headers: headers);
      } catch (_) {
        cached = null;
      }
    }

    if (!mounted || generation != _loadGeneration) {
      return;
    }

    if (cached != null && await cached.exists()) {
      setState(() {
        _file = cached;
        _loading = false;
        _failed = false;
        _useNetworkFallback = false;
        _networkHeaders = headers;
        _resolvedUrl = resolved;
      });
      return;
    }

    setState(() {
      _loading = false;
      _failed = false;
      _file = null;
      _useNetworkFallback = true;
      _networkHeaders = headers;
      _resolvedUrl = resolved;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    final placeholder = widget.placeholderColor ??
        theme.mediaPlaceholderBackground ??
        theme.mutedText.withValues(alpha: 0.15);
    final loader = widget.loaderColor ?? theme.mediaLoaderColor ?? theme.mutedText;

    if (_failed) {
      return _frame(
        placeholder: placeholder,
        child: Center(
          child: Text(
            widget.errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.mutedText, fontSize: 12),
          ),
        ),
      );
    }

    if (_loading) {
      return _frame(
        placeholder: placeholder,
        child: widget.showLoader
            ? Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: widget.loaderStrokeWidth,
                    color: loader,
                  ),
                ),
              )
            : const SizedBox.shrink(),
      );
    }

    if (_useNetworkFallback) {
      return _frame(
        placeholder: placeholder,
        child: Image.network(
          _resolvedUrl,
          headers: _networkHeaders,
          width: widget.containFit ? null : widget.width,
          height: widget.containFit ? null : widget.height,
          fit: widget.containFit ? BoxFit.contain : widget.fit,
          loadingBuilder: (context, child, progress) {
            if (progress == null) {
              return child;
            }
            if (!widget.showLoader) {
              return const SizedBox.shrink();
            }
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: widget.loaderStrokeWidth,
                color: loader,
                value: progress.expectedTotalBytes == null
                    ? null
                    : progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!,
              ),
            );
          },
          errorBuilder: (_, __, ___) => Center(
            child: Text(
              widget.errorMessage,
              style: TextStyle(color: theme.mutedText, fontSize: 12),
            ),
          ),
        ),
      );
    }

    final image = Image.file(
      _file!,
      width: widget.containFit ? null : widget.width,
      height: widget.containFit ? null : widget.height,
      fit: widget.containFit ? BoxFit.contain : widget.fit,
      errorBuilder: (_, __, ___) {
        if (!_useNetworkFallback && _resolvedUrl.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _useNetworkFallback = true;
              _file = null;
            });
          });
        }
        return Center(
          child: Text(
            widget.errorMessage,
            style: TextStyle(color: theme.mutedText, fontSize: 12),
          ),
        );
      },
    );

    return _frame(
      placeholder: placeholder,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: widget.fadeDuration,
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity, child: child),
        child: image,
      ),
    );
  }

  Widget _frame({required Color placeholder, required Widget child}) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: ColoredBox(
          color: placeholder,
          child: child,
        ),
      ),
    );
  }
}
