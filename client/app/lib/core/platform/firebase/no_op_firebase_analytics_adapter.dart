import "package:firebase_analytics/firebase_analytics.dart";
import "package:firebase_core/firebase_core.dart";

/// Type-compatible Firebase Analytics implementation for Firebase-disabled builds.
class NoOpFirebaseAnalyticsAdapter implements FirebaseAnalytics {
  NoOpFirebaseAnalyticsAdapter({required FirebaseApp app}) : _app = app;

  FirebaseApp _app;

  @override
  FirebaseApp get app => _app;

  @override
  set app(FirebaseApp value) => _app = value;

  @override
  Map<String, dynamic>? get webOptions => null;

  @override
  Map<dynamic, dynamic> get pluginConstants => const {};

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<String?> get appInstanceId async => null;

  @override
  Future<int?> getSessionId() async => null;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
    List<AnalyticsEventItem>? items,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> setConsent({
    bool? adStorageConsentGranted,
    bool? analyticsStorageConsentGranted,
    bool? adPersonalizationSignalsConsentGranted,
    bool? adUserDataConsentGranted,
    bool? functionalityStorageConsentGranted,
    bool? personalizationStorageConsentGranted,
    bool? securityStorageConsentGranted,
  }) async {}

  @override
  Future<void> setDefaultEventParameters(
    Map<String, Object?>? defaultParameters,
  ) async {}

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setUserId({
    String? id,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> resetAnalyticsData() async {}

  @override
  Future<void> logAddPaymentInfo({
    String? coupon,
    String? currency,
    String? paymentType,
    double? value,
    List<AnalyticsEventItem>? items,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logAddShippingInfo({
    String? coupon,
    String? currency,
    double? value,
    String? shippingTier,
    List<AnalyticsEventItem>? items,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logAddToCart({
    List<AnalyticsEventItem>? items,
    double? value,
    String? currency,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logAddToWishlist({
    List<AnalyticsEventItem>? items,
    double? value,
    String? currency,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logAdImpression({
    String? adPlatform,
    String? adSource,
    String? adFormat,
    String? adUnitName,
    double? value,
    String? currency,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logAppOpen({
    AnalyticsCallOptions? callOptions,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> logBeginCheckout({
    double? value,
    String? currency,
    List<AnalyticsEventItem>? items,
    String? coupon,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logCampaignDetails({
    required String source,
    required String medium,
    required String campaign,
    String? term,
    String? content,
    String? aclid,
    String? cp1,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logEarnVirtualCurrency({
    required String virtualCurrencyName,
    required num value,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logGenerateLead({
    String? currency,
    double? value,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logJoinGroup({
    required String groupId,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logLevelUp({
    required int level,
    String? character,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logLevelStart({
    required String levelName,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logLevelEnd({
    required String levelName,
    int? success,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logLogin({
    String? loginMethod,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logPostScore({
    required int score,
    int? level,
    String? character,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logPurchase({
    String? currency,
    String? coupon,
    double? value,
    List<AnalyticsEventItem>? items,
    double? tax,
    double? shipping,
    String? transactionId,
    String? affiliation,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logRemoveFromCart({
    String? currency,
    double? value,
    List<AnalyticsEventItem>? items,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logSelectItem({
    String? itemListId,
    String? itemListName,
    List<AnalyticsEventItem>? items,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logSelectPromotion({
    String? creativeName,
    String? creativeSlot,
    List<AnalyticsEventItem>? items,
    String? locationId,
    String? promotionId,
    String? promotionName,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logViewCart({
    String? currency,
    double? value,
    List<AnalyticsEventItem>? items,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logSearch({
    required String searchTerm,
    int? numberOfNights,
    int? numberOfRooms,
    int? numberOfPassengers,
    String? origin,
    String? destination,
    String? startDate,
    String? endDate,
    String? travelClass,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logSelectContent({
    required String contentType,
    required String itemId,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> logShare({
    required String contentType,
    required String itemId,
    required String method,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> logSignUp({
    required String signUpMethod,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> logSpendVirtualCurrency({
    required String itemName,
    required String virtualCurrencyName,
    required num value,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> logTutorialBegin({
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> logTutorialComplete({
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> logUnlockAchievement({
    required String id,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> logViewItem({
    String? currency,
    double? value,
    List<AnalyticsEventItem>? items,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> logViewItemList({
    List<AnalyticsEventItem>? items,
    String? itemListId,
    String? itemListName,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> logViewPromotion({
    String? creativeName,
    String? creativeSlot,
    List<AnalyticsEventItem>? items,
    String? locationId,
    String? promotionId,
    String? promotionName,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> logViewSearchResults({
    required String searchTerm,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> logRefund({
    String? currency,
    String? coupon,
    double? value,
    double? tax,
    double? shipping,
    String? transactionId,
    String? affiliation,
    List<AnalyticsEventItem>? items,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> logInAppPurchase({
    String? currency,
    bool? freeTrial,
    double? price,
    bool? priceIsDiscounted,
    String? productID,
    String? productName,
    int? quantity,
    bool? subscription,
    num? value,
  }) async {}

  @override
  Future<void> logTransaction(String transactionId) async {}

  @override
  Future<void> setSessionTimeoutDuration(Duration timeout) async {}

  @override
  Future<void> initiateOnDeviceConversionMeasurementWithEmailAddress(
    String emailAddress,
  ) async {}

  @override
  Future<void> initiateOnDeviceConversionMeasurementWithPhoneNumber(
    String phoneNumber,
  ) async {}

  @override
  Future<void> initiateOnDeviceConversionMeasurementWithHashedEmailAddress(
    String hashedEmailAddress,
  ) async {}

  @override
  Future<void> initiateOnDeviceConversionMeasurementWithHashedPhoneNumber(
    String hashedPhoneNumber,
  ) async {}
}
