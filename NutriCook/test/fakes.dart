import 'package:nutricook/models/auth_tokens.dart';
import 'package:nutricook/models/auth_user.dart';
import 'package:nutricook/models/browse_filters.dart';
import 'package:nutricook/models/recipe.dart';
import 'package:nutricook/models/user_preferences.dart';
import 'package:nutricook/services/auth_service.dart';
import 'package:nutricook/services/recipe_service.dart';

/// Stands in for the network so flows are exercised without a live backend.
///
/// Every override returns immediately, so nothing in the test suite ever
/// opens a socket — a test that did would be slow and flaky by turns.
class FakeRecipeService extends RecipeService {
  FakeRecipeService({
    this.feed = const [],
    this.generated = const [],
    this.savedOnServer = const [],
    this.browseResults = const [],
    this.cached = false,
    this.pageSize,
  });

  /// Everything the feed holds. Paged out in [pageSize] chunks when set, so
  /// pagination can be tested without a hundred fixtures.
  List<Recipe> feed;
  List<Recipe> generated;
  List<Recipe> savedOnServer;
  List<Recipe> browseResults;

  /// What the next generate call reports as its origin.
  bool cached;

  final int? pageSize;

  int generateCalls = 0;
  int feedCalls = 0;
  int browseCalls = 0;
  GenerateRequest? lastRequest;
  BrowseFilters? lastFilters;
  final List<String> savedIds = [];
  final List<String> unsavedIds = [];
  Map<String, dynamic>? lastPreferences;
  bool? lastOnboardingComplete;

  @override
  Future<FeedPage> fetchFeed({
    String? category,
    String? cursor,
    int limit = 10,
  }) async {
    feedCalls++;
    final size = pageSize ?? feed.length;
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = (start + size).clamp(0, feed.length);
    final slice = feed.sublist(start.clamp(0, feed.length), end);
    final hasMore = end < feed.length;
    return FeedPage(
      recipes: slice,
      nextCursor: hasMore ? '$end' : null,
      hasMore: hasMore,
    );
  }

  @override
  Future<BrowsePage> browse({
    required BrowseFilters filters,
    int page = 1,
    int pageSize = 20,
  }) async {
    browseCalls++;
    lastFilters = filters;
    return BrowsePage(
      recipes: browseResults,
      page: page,
      total: browseResults.length,
      hasMore: false,
    );
  }

  @override
  Future<Recipe> fetchRecipe(String id) async =>
      feed.firstWhere((r) => r.id == id, orElse: () => feed.first);

  @override
  Future<GenerationResult> generateRecipes(GenerateRequest request) async {
    generateCalls++;
    lastRequest = request;
    return GenerationResult(recipes: generated, cached: cached);
  }

  @override
  Future<String?> generateImage(String recipeId) async => null;

  @override
  Future<List<Recipe>> fetchSavedRecipes() async => savedOnServer;

  @override
  Future<void> saveRecipe(String recipeId) async => savedIds.add(recipeId);

  @override
  Future<void> unsaveRecipe(String recipeId) async =>
      unsavedIds.add(recipeId);

  @override
  Future<void> syncPreferences(
    Map<String, dynamic> preferences, {
    bool? onboardingComplete,
  }) async {
    lastPreferences = preferences;
    lastOnboardingComplete = onboardingComplete;
  }
}

/// A preference sync that always fails, for the offline paths.
class OfflineRecipeService extends FakeRecipeService {
  @override
  Future<void> syncPreferences(
    Map<String, dynamic> preferences, {
    bool? onboardingComplete,
  }) async {
    throw Exception('offline');
  }

  @override
  Future<List<Recipe>> fetchSavedRecipes() async {
    throw Exception('offline');
  }
}

/// Stands in for the auth endpoints.
class FakeAuthService extends AuthService {
  FakeAuthService({this.user = const AuthUser(id: 'u1', email: 'a@b.com')});

  AuthUser user;

  /// When set, the next call throws this instead of succeeding.
  Object? failWith;

  int registerCalls = 0;
  int loginCalls = 0;
  int refreshCalls = 0;
  int logoutCalls = 0;
  String? lastEmail;
  UserPreferences? lastPreferences;

  AuthResult _result() => AuthResult(
        accessToken: 'access-${registerCalls + loginCalls + refreshCalls}',
        refreshToken: 'refresh-${registerCalls + loginCalls + refreshCalls}',
        user: user,
      );

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
    String? displayName,
    UserPreferences? preferences,
  }) async {
    registerCalls++;
    lastEmail = email;
    lastPreferences = preferences;
    if (failWith != null) throw failWith!;
    return _result();
  }

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    lastEmail = email;
    if (failWith != null) throw failWith!;
    return _result();
  }

  @override
  Future<AuthResult> refresh(String refreshToken) async {
    refreshCalls++;
    if (failWith != null) throw failWith!;
    return _result();
  }

  @override
  Future<void> logout(String refreshToken) async => logoutCalls++;
}
