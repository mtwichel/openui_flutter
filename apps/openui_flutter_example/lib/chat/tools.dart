import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:openui_core/openui_core.dart';

Schema _productReviewSchema() => Schema.object(
  properties: {
    'rating': Schema.integer(),
    'comment': Schema.string(),
    'date': Schema.string(
      description: 'ISO-8601 timestamp',
    ),
    'reviewerName': Schema.string(),
    'reviewerEmail': Schema.string(),
  },
);

Schema _productDimensionsSchema() => Schema.object(
  properties: {
    'width': Schema.number(),
    'height': Schema.number(),
    'depth': Schema.number(),
  },
);

Schema _productMetaSchema() => Schema.object(
  properties: {
    'createdAt': Schema.string(),
    'updatedAt': Schema.string(),
    'barcode': Schema.string(),
    'qrCode': Schema.string(),
  },
);

Schema _productSchema() => Schema.object(
  properties: {
    'id': Schema.integer(),
    'title': Schema.string(),
    'description': Schema.string(),
    'category': Schema.string(),
    'price': Schema.number(),
    'discountPercentage': Schema.number(),
    'rating': Schema.number(),
    'stock': Schema.integer(),
    'tags': Schema.list(items: Schema.string()),
    'brand': Schema.string(),
    'sku': Schema.string(),
    'weight': Schema.number(),
    'dimensions': _productDimensionsSchema(),
    'warrantyInformation': Schema.string(),
    'shippingInformation': Schema.string(),
    'availabilityStatus': Schema.string(),
    'reviews': Schema.list(items: _productReviewSchema()),
    'returnPolicy': Schema.string(),
    'minimumOrderQuantity': Schema.integer(),
    'meta': _productMetaSchema(),
    'thumbnail': Schema.string(),
    'images': Schema.list(items: Schema.string()),
  },
);

Schema _fetchProductsResponseSchema() => Schema.object(
  properties: {
    'products': Schema.list(items: _productSchema()),
    'total': Schema.integer(
      description: 'Total matching products in the catalog',
    ),
    'skip': Schema.integer(),
    'limit': Schema.integer(),
  },
  required: ['products', 'total', 'skip', 'limit'],
);

/// {@template snackbar_tool}
/// A tool that shows a snackbar with the given message.
/// {@endtemplate}
class SnackbarTool implements Tool {
  /// {@macro snackbar_tool}
  SnackbarTool();

  @override
  String get name => 'snackbar';

  @override
  String get description => 'Show a snackbar with the given message';

  @override
  Schema? get input => Schema.object(properties: {'message': Schema.string()});

  @override
  Schema? get output => null;

  @override
  Future<ToolResult> callTool(Map<String, Object?> args) async {
    debugPrint(args['message']! as String);
    return const ToolResult(null);
  }
}

class FetchProductsTool implements Tool {
  @override
  String get name => 'fetch_products';

  @override
  String get description =>
      'Fetch product listings from the DummyJSON demo catalog '
      '(https://dummyjson.com/products). Supports pagination via skip/limit.';

  @override
  Schema? get input => Schema.object(
    properties: {
      'limit': Schema.integer(
        description:
            'Max products to return per request (DummyJSON default 30).',
      ),
      'skip': Schema.integer(
        description: 'Offset for pagination.',
      ),
    },
  );

  @override
  Schema? get output => _fetchProductsResponseSchema();

  @override
  Future<ToolResult> callTool(Map<String, Object?> args) async {
    final query = <String, String>{
      if (args['limit'] != null) 'limit': '${args['limit']}',
      if (args['skip'] != null) 'skip': '${args['skip']}',
    };
    final uri = Uri.parse('https://dummyjson.com/products').replace(
      queryParameters: query.isEmpty ? null : query,
    );

    late final http.Response answer;
    try {
      answer = await http.get(uri);
    } on Exception catch (e, st) {
      debugPrint('$e\n$st');
      return ToolResult('Failed to fetch products: $e', isError: true);
    }

    if (answer.statusCode != 200) {
      return ToolResult(
        'Failed to fetch products: HTTP ${answer.statusCode}',
        isError: true,
      );
    }

    try {
      final decoded = jsonDecode(answer.body);
      if (decoded is! Map) {
        return const ToolResult(
          'Failed to fetch products: response was not a JSON object',
          isError: true,
        );
      }
      return ToolResult(decoded);
    } on FormatException catch (e) {
      return ToolResult(
        'Failed to fetch products: invalid JSON (${e.message})',
        isError: true,
      );
    }
  }
}

int? _parseProductId(Object? raw) {
  return switch (raw) {
    final int i => i,
    final num n => n.toInt(),
    final String s => int.tryParse(s.trim()),
    _ => null,
  };
}

/// Fetches one product by numeric id from DummyJSON (`GET /products/:id`).
class FetchProductTool implements Tool {
  @override
  String get name => 'fetch_product';

  @override
  String get description =>
      'Fetch a single product by id from the DummyJSON demo catalog '
      '(https://dummyjson.com/products/:id).';

  @override
  Schema? get input => Schema.object(
    properties: {
      'id': Schema.integer(description: 'DummyJSON product id.'),
    },
    required: ['id'],
  );

  @override
  Schema? get output => _productSchema();

  @override
  Future<ToolResult> callTool(Map<String, Object?> args) async {
    final id = _parseProductId(args['id']);
    if (id == null || id < 1) {
      return const ToolResult(
        'fetch_product requires a positive integer id',
        isError: true,
      );
    }

    final uri = Uri.parse('https://dummyjson.com/products/$id');

    late final http.Response answer;
    try {
      answer = await http.get(uri);
    } on Exception catch (e, st) {
      debugPrint('$e\n$st');
      return ToolResult('Failed to fetch product: $e', isError: true);
    }

    if (answer.statusCode != 200) {
      return ToolResult(
        'Failed to fetch product: HTTP ${answer.statusCode}',
        isError: true,
      );
    }

    try {
      final decoded = jsonDecode(answer.body);
      if (decoded is! Map) {
        return const ToolResult(
          'Failed to fetch product: response was not a JSON object',
          isError: true,
        );
      }
      return ToolResult(decoded);
    } on FormatException catch (e) {
      return ToolResult(
        'Failed to fetch product: invalid JSON (${e.message})',
        isError: true,
      );
    }
  }
}
