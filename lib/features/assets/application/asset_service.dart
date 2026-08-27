import '../data/asset_repository.dart';
import '../domain/company_asset.dart';

class AssetService {
  AssetService({AssetRepository? repository})
    : _repository = repository ?? AssetRepository();

  final AssetRepository _repository;

  Future<
    ({bool canManage, String currentEmployeeId, List<CompanyAsset> assets})
  >
  overview() => _repository.overview();

  Future<void> createAsset({
    required String assetTag,
    required String name,
    required String category,
    required String serialNumber,
    String? purchaseDateKey,
    String? warrantyExpiryDateKey,
    required String notes,
  }) => _repository.createAsset(
    assetTag: assetTag,
    name: name,
    category: category,
    serialNumber: serialNumber,
    purchaseDateKey: purchaseDateKey,
    warrantyExpiryDateKey: warrantyExpiryDateKey,
    notes: notes,
  );

  Future<void> assignAsset({
    required String assetId,
    required String employeeId,
  }) => _repository.assignAsset(assetId: assetId, employeeId: employeeId);

  Future<void> returnAsset(String assetId) => _repository.returnAsset(assetId);

  Future<void> updateStatus({
    required String assetId,
    required String status,
  }) => _repository.updateStatus(assetId: assetId, status: status);
}
