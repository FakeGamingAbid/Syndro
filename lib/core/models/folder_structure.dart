import 'package:equatable/equatable.dart';
import 'transfer.dart';

class FolderStructure extends Equatable {
  final String rootPath;
  final String rootName;
  final List<TransferItem> items;
  final Map<String, List<String>> hierarchy; // parent path -> child paths

  const FolderStructure({
    required this.rootPath,
    required this.rootName,
    required this.items,
    required this.hierarchy,
  });

  int get totalFiles => items.where((item) => !item.isDirectory).length;
  
  int get totalSize => items.fold(0, (sum, item) => sum + item.size);

  // Get all files (excluding directories)
  List<TransferItem> get files => items.where((item) => !item.isDirectory).toList();

  // Get all directories
  List<TransferItem> get directories => items.where((item) => item.isDirectory).toList();

  Map<String, dynamic> toJson() {
    return {
      'rootPath': rootPath,
      'rootName': rootName,
      'items': items.map((item) => item.toJson()).toList(),
      'hierarchy': hierarchy,
    };
  }

  factory FolderStructure.fromJson(Map<String, dynamic> json) {
    return FolderStructure(
      rootPath: json['rootPath'] as String,
      rootName: json['rootName'] as String,
      items: (json['items'] as List)
          .map((item) => TransferItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      hierarchy: Map<String, List<String>>.from(
        (json['hierarchy'] as Map).map(
          (key, value) => MapEntry(key as String, List<String>.from(value as List)),
        ),
      ),
    );
  }

  @override
  List<Object?> get props => [rootPath, rootName, items, hierarchy];
}
