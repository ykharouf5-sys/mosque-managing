import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

class ColorConverter extends JsonConverter<Color, String> {
  const ColorConverter();

  @override
  Color fromJson(String json) {
    final hex = json.replaceFirst('#', '');
    return Color(int.parse(hex, radix: 16));
  }

  @override
  String toJson(Color object) {
    return '#${object.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }
}
