// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stac_marquee_text.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StacMarqueeText _$StacMarqueeTextFromJson(Map<String, dynamic> json) =>
    StacMarqueeText(
      data: json['data'] as String,
      style: json['style'] == null
          ? null
          : StacTextStyle.fromJson(json['style']),
      speed: const DoubleConverter().fromJson(json['speed']),
      gap: const DoubleConverter().fromJson(json['gap']),
      enabled: json['enabled'] as bool?,
      maxLines: (json['maxLines'] as num?)?.toInt(),
    );

Map<String, dynamic> _$StacMarqueeTextToJson(StacMarqueeText instance) =>
    <String, dynamic>{
      'data': instance.data,
      'style': instance.style?.toJson(),
      'speed': const DoubleConverter().toJson(instance.speed),
      'gap': const DoubleConverter().toJson(instance.gap),
      'enabled': instance.enabled,
      'maxLines': instance.maxLines,
      'type': instance.type,
    };
