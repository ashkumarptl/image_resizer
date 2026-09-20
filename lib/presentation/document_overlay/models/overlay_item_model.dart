import 'dart:io';
import 'package:flutter/material.dart';

enum OverlayItemType {
  photo,
  signature,
  idFront,
  idBack,
}

/// Represents an individual movable, resizable, and rotatable layer on a document canvas.
class OverlayItemModel {
  final String id;
  final File file;
  final OverlayItemType type;
  final String label;

  /// Center X position on canvas in normalized coordinates [0.0 to 1.0].
  final double normalizedX;

  /// Center Y position on canvas in normalized coordinates [0.0 to 1.0].
  final double normalizedY;

  /// Width in normalized coordinates relative to canvas width [0.0 to 1.0].
  final double normalizedWidth;

  /// Height in normalized coordinates relative to canvas height [0.0 to 1.0].
  final double normalizedHeight;

  /// Rotation in radians.
  final double rotation;

  /// Opacity [0.0 to 1.0].
  final double opacity;

  /// Whether to render a subtle cutting border (useful for ID cards on A4).
  final bool hasBorder;

  /// Border color in ARGB 32-bit int.
  final int borderColorValue;

  /// Border stroke width in points.
  final double borderWidth;

  /// Intrinsic aspect ratio of the underlying image (width / height).
  final double aspectRatio;

  const OverlayItemModel({
    required this.id,
    required this.file,
    this.type = OverlayItemType.photo,
    this.label = 'Layer',
    this.normalizedX = 0.5,
    this.normalizedY = 0.5,
    this.normalizedWidth = 0.4,
    this.normalizedHeight = 0.25,
    this.rotation = 0.0,
    this.opacity = 1.0,
    this.hasBorder = false,
    this.borderColorValue = 0xFFCCCCCC,
    this.borderWidth = 1.5,
    this.aspectRatio = 1.0,
  });

  Color get borderColor => Color(borderColorValue);

  OverlayItemModel copyWith({
    String? id,
    File? file,
    OverlayItemType? type,
    String? label,
    double? normalizedX,
    double? normalizedY,
    double? normalizedWidth,
    double? normalizedHeight,
    double? rotation,
    double? opacity,
    bool? hasBorder,
    int? borderColorValue,
    double? borderWidth,
    double? aspectRatio,
  }) {
    return OverlayItemModel(
      id: id ?? this.id,
      file: file ?? this.file,
      type: type ?? this.type,
      label: label ?? this.label,
      normalizedX: normalizedX ?? this.normalizedX,
      normalizedY: normalizedY ?? this.normalizedY,
      normalizedWidth: normalizedWidth ?? this.normalizedWidth,
      normalizedHeight: normalizedHeight ?? this.normalizedHeight,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      hasBorder: hasBorder ?? this.hasBorder,
      borderColorValue: borderColorValue ?? this.borderColorValue,
      borderWidth: borderWidth ?? this.borderWidth,
      aspectRatio: aspectRatio ?? this.aspectRatio,
    );
  }
}
