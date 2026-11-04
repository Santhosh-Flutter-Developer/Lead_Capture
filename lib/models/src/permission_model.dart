class PermissionModel {
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;
  final bool canView;
  final bool canExport;
  final bool canImport;

  PermissionModel({
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
    required this.canView,
    this.canExport = false,
    this.canImport = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'canCreate': canCreate,
      'canEdit': canEdit,
      'canDelete': canDelete,
      'canView': canView,
      'canExport': canExport,
      'canImport': canImport,
    };
  }
}
