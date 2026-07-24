/// SignSense AI — DEPRECATED: ApiService
///
/// Phase A: All callers have been migrated to [ApiClient] in core/network/.
///
/// This file is kept as a compile-time tombstone so that any accidental
/// re-import causes a clear deprecation warning rather than a 404 at runtime.
///
/// DO NOT add new functionality here.
/// DO NOT import this in any new code.
///
/// Migration map:
///   ApiService.extractText()    → ApiClient.uploadImageFile('/api/ocr/read', …)
///   ApiService.describeScene()  → ApiClient.uploadImageFile('/api/scene/describe', …)
///   ApiService.detectCurrency() → ApiClient.uploadImageFile('/api/currency/detect', …)
///   ApiService.getRoute()       → NavigationService.getRoute() (delegates to backend)
///   ApiService.isBackendAlive() → ApiClient.isServerAlive()
///
/// This file will be deleted after Phase F sign-off.

@Deprecated('Use ApiClient from core/network/api_client.dart instead.')
// ignore_for_file: deprecated_member_use_from_same_package
library;
