// ============================================================
// MARK: — Build-time secrets (CI-injected)
// ============================================================
//
// This file is COMMITTED EMPTY and OVERWRITTEN in CI (codemagic.yaml →
// "Inject Perfect Corp API secrets") from secure environment variables.
// NEVER put real values here — anything committed to git is public.
// Empty values ⇒ EngineFactory serves the mock engines, so local builds
// and builds without the Codemagic variables keep working end-to-end.

enum DermiqSecrets {
    /// Perfect Corp YouCam AI API key (yce.perfectcorp.com → API Keys).
    /// Codemagic variable: PERFECTCORP_API_KEY
    static let perfectCorpAPIKey = ""

    /// The RSA public key that pairs with the API key — the base64 block the
    /// YCE console shows once as "Geheimschlüssel"/"Secret key" when the key
    /// is generated (an X.509/SPKI RSA public key, no PEM header lines).
    /// Codemagic variable: PERFECTCORP_RSA_KEY
    static let perfectCorpRSAPublicKey = ""

    /// Google Gemini API key (Google AI Studio) for the "Potential" face
    /// enhancement (gemini-2.5-flash-image). Codemagic variable: GEMINI_API_KEY
    static let geminiAPIKey = ""

    /// Supabase project URL, e.g. https://xxxx.supabase.co
    /// Codemagic variable: SUPABASE_URL
    static let supabaseURL = ""

    /// Supabase anon/public key (Project Settings → API).
    /// Codemagic variable: SUPABASE_ANON_KEY
    static let supabaseAnonKey = ""
}
