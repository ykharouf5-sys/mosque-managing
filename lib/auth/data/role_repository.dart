class RoleRepository {
  static Future<Map<String, dynamic>?> verifyRole(String uid) async {
    return {'warehouseId': 'main', 'role': 'warehouse_manager'};
  }
}
