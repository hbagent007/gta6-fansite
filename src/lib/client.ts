// Client-only Supabase loader — never imported during static build
// This file is only imported inside <script> blocks (runs in browser)

export async function loadSupabase() {
  const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseAnonKey) {
    console.warn('Supabase env vars not set. Auth features disabled.');
    return null;
  }

  const { createClient } = await import('@supabase/supabase-js');
  return createClient(supabaseUrl, supabaseAnonKey);
}

export async function loadStripeClient() {
  const key = import.meta.env.PUBLIC_STRIPE_PUBLISHABLE_KEY;
  if (!key) return null;
  const { loadStripe } = await import('@stripe/stripe-js');
  return loadStripe(key);
}
