import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/firebase/firebase_services.dart';
import '../domain/company_asset.dart';

class AssetRepository {
  AssetRepository({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseServices.functions;

  final FirebaseFunctions _functions;

  Future<
    ({bool canManage, String currentEmployeeId, List<CompanyAsset> assets})
  >
  overview() async {
    final result = await _functions
        .httpsCallable('getAssetOverview')
        .call<Map<String, dynamic>>();
    final data = Map<String, dynamic>.from(result.data);
    return (
      canManage: data['canManage'] as bool? ?? false,
      currentEmployeeId: data['currentEmployeeId'] as String? ?? '',
      assets: (data['assets'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => CompanyAsset.fromMap(Map<String, dynamic>.from(item)))
          .toList(growable: false),
    );
  }

  Future<void> createAsset({
    required String assetTag,
    required String name,
    required String category,
    required String serialNumber,
    String? purchaseDateKey,
    String? warrantyExpiryDateKey,
    required String notes,
  }) => _functions.httpsCallable('createCompanyAsset').call<void>({
    'assetTag': assetTag,
    'name': name,
    'category': category,
    'serialNumber': serialNumber,
    'purchaseDateKey': ?purchaseDateKey,
    'warrantyExpiryDateKey': ?warrantyExpiryDateKey,
    'notes': notes,
  });

  Future<void> assignAsset({
    required String assetId,
    required String employeeId,
  }) => _functions.httpsCallable('assignCompanyAsset').call<void>({
    'assetId': assetId,
    'employeeId': employeeId,
  });

  Future<void> returnAsset(String assetId) => _functions
      .httpsCallable('returnCompanyAsset')
      .call<void>({'assetId': assetId});

  Future<void> updateStatus({
    required String assetId,
    required String status,
  }) => _functions.httpsCallable('updateCompanyAssetStatus').call<void>({
    'assetId': assetId,
    'status': status,
  });
}
