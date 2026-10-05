import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

/// Custom loading indicator widget
class LoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;
  final String? text;
  
  const LoadingIndicator({
    super.key,
    this.size = 40,
    this.color,
    this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SpinKitFadingCircle(
          size: size,
          color: effectiveColor,
        ),
        if (text != null) ...[
          const SizedBox(height: 8),
          Text(
            text!,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// Full screen loading overlay
class FullScreenLoading extends StatelessWidget {
  final String? message;
  
  const FullScreenLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: LoadingIndicator(
          size: 60,
          text: message,
        ),
      ),
    );
  }
}

/// Progress indicator with percentage
class ProgressIndicatorWithPercentage extends StatelessWidget {
  final double progress;
  final double height;
  final Color? backgroundColor;
  final Color? progressColor;
  final String? label;
  
  const ProgressIndicatorWithPercentage({
    super.key,
    required this.progress,
    this.height = 6,
    this.backgroundColor,
    this.progressColor,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBackgroundColor = backgroundColor ?? const Color(0xFF333333);
    final effectiveProgressColor = progressColor ?? theme.colorScheme.primary;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: effectiveBackgroundColor,
          valueColor: AlwaysStoppedAnimation<Color>(effectiveProgressColor),
          minHeight: height,
        ),
        if (label != null) ...[
          const SizedBox(height: 4),
          Text(
            label!,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// Circular progress indicator with text
class CircularProgressWithText extends StatelessWidget {
  final double value;
  final String text;
  final double size;
  final double strokeWidth;
  final Color? backgroundColor;
  final Color? progressColor;
  final Color? textColor;
  
  const CircularProgressWithText({
    super.key,
    required this.value,
    required this.text,
    this.size = 100,
    this.strokeWidth = 8,
    this.backgroundColor,
    this.progressColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBackgroundColor = backgroundColor ?? const Color(0xFF333333);
    final effectiveProgressColor = progressColor ?? theme.colorScheme.primary;
    final effectiveTextColor = textColor ?? Colors.white;
    
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value,
            backgroundColor: effectiveBackgroundColor,
            valueColor: AlwaysStoppedAnimation<Color>(effectiveProgressColor),
            strokeWidth: strokeWidth,
          ),
          Text(
            text,
            style: theme.textTheme.titleSmall?.copyWith(
              color: effectiveTextColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
