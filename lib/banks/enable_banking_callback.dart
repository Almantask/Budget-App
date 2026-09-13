/// Public HTTPS callback hosted on GitHub Pages, plus the in-app custom scheme.
class EnableBankingCallback {
  static const hostedRedirectUri =
      'https://almantask.github.io/Budget-App/enable-banking/callback.html';

  static const appSchemeRedirectUri = 'budgetapp://enable-banking/callback';

  static bool isCallback(Uri uri) {
    if (uri.scheme == 'budgetapp') {
      return uri.host == 'enable-banking';
    }
    final path = uri.path.toLowerCase();
    return path.contains('enable-banking/callback') ||
        path.endsWith('/callback.html') ||
        path.endsWith('/callback') ||
        path.endsWith('/callback/');
  }

  static String? authorizationCode(Uri uri) {
    final query = uri.queryParameters['code'];
    if (query != null && query.isNotEmpty) return query;
    if (uri.hasFragment) {
      final fragment = Uri.splitQueryString(uri.fragment);
      final code = fragment['code'];
      if (code != null && code.isNotEmpty) return code;
    }
    return null;
  }

  static String? oauthState(Uri uri) {
    final query = uri.queryParameters['state'];
    if (query != null && query.isNotEmpty) return query;
    if (uri.hasFragment) {
      final fragment = Uri.splitQueryString(uri.fragment);
      final state = fragment['state'];
      if (state != null && state.isNotEmpty) return state;
    }
    return null;
  }

  static String? errorMessage(Uri uri) {
    final error = uri.queryParameters['error'];
    if (error == null || error.isEmpty) return null;
    final description = uri.queryParameters['error_description'];
    if (description != null && description.isNotEmpty) {
      return '$error: $description';
    }
    return error;
  }
}
