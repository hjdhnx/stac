// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stac_lazy_grid.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StacLazyGrid _$StacLazyGridFromJson(Map<String, dynamic> json) => StacLazyGrid(
  crossAxisCount: (json['crossAxisCount'] as num?)?.toInt(),
  mainAxisSpacing: const DoubleConverter().fromJson(json['mainAxisSpacing']),
  crossAxisSpacing: const DoubleConverter().fromJson(json['crossAxisSpacing']),
  childAspectRatio: const DoubleConverter().fromJson(json['childAspectRatio']),
  mainAxisExtent: const DoubleConverter().fromJson(json['mainAxisExtent']),
  padding: json['padding'] == null
      ? null
      : StacEdgeInsets.fromJson(json['padding']),
  header: json['header'] == null
      ? null
      : StacWidget.fromJson(json['header'] as Map<String, dynamic>),
  footer: json['footer'] == null
      ? null
      : StacWidget.fromJson(json['footer'] as Map<String, dynamic>),
  items: json['items'] as List<dynamic>?,
  itemTemplate: json['itemTemplate'] == null
      ? null
      : StacWidget.fromJson(json['itemTemplate'] as Map<String, dynamic>),
  empty: json['empty'] == null
      ? null
      : StacWidget.fromJson(json['empty'] as Map<String, dynamic>),
  hasMore: json['hasMore'] as bool?,
  loadingMore: json['loadingMore'] as bool?,
  onEndReached: json['onEndReached'] == null
      ? null
      : StacAction.fromJson(json['onEndReached'] as Map<String, dynamic>),
  endReachedThreshold: const DoubleConverter().fromJson(
    json['endReachedThreshold'],
  ),
);

Map<String, dynamic> _$StacLazyGridToJson(StacLazyGrid instance) =>
    <String, dynamic>{
      'crossAxisCount': instance.crossAxisCount,
      'mainAxisSpacing': const DoubleConverter().toJson(
        instance.mainAxisSpacing,
      ),
      'crossAxisSpacing': const DoubleConverter().toJson(
        instance.crossAxisSpacing,
      ),
      'childAspectRatio': const DoubleConverter().toJson(
        instance.childAspectRatio,
      ),
      'mainAxisExtent': const DoubleConverter().toJson(instance.mainAxisExtent),
      'padding': instance.padding?.toJson(),
      'header': instance.header?.toJson(),
      'footer': instance.footer?.toJson(),
      'items': instance.items,
      'itemTemplate': instance.itemTemplate?.toJson(),
      'empty': instance.empty?.toJson(),
      'hasMore': instance.hasMore,
      'loadingMore': instance.loadingMore,
      'onEndReached': instance.onEndReached?.toJson(),
      'endReachedThreshold': const DoubleConverter().toJson(
        instance.endReachedThreshold,
      ),
    };
