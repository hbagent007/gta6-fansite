// Lazy Supabase client — only initializes when env vars are available
// This allows static building without env vars set

let _supabase = null;

export function getSupabase() {
  if (_supabase) return _supabase;

  const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseAnonKey) {
    // Return a mock for static build / dev without env vars
    return null;
  }

  const { createClient } = require('@supabase/supabase-js');
  _supabase = createClient(supabaseUrl, supabaseAnonKey);
  return _supabase;
}

// Stripe — also lazy
let _stripePromise = null;

export function getStripe() {
  if (_stripePromise) return _stripePromise;

  const key = import.meta.env.PUBLIC_STRIPE_PUBLISHABLE_KEY;
  if (!key) return null;

  const { loadStripe } = require('@stripe/stripe-js');
  _stripePromise = loadStripe(key);
  return _stripePromise;
}

// Membership tier definitions
export const TIERS = {
  free: {
    id: 'free',
    name: 'Free',
    price: 0,
    color: 'from-gray-500 to-gray-600',
    features: [
      'Browse public forums',
      'Read public guides',
      'View basic locations',
      'Community events calendar',
    ],
  },
  premium: {
    id: 'premium',
    name: 'Premium',
    price: 5,
    priceLabel: '$5/month',
    stripePriceId: 'price_premium',
    color: 'from-neon-cyan to-blue-600',
    features: [
      'Everything in Free',
      'Full forum posting',
      'Money-making guides',
      'Car & vehicle locations',
      'Secret loot maps',
      'No ads',
      'Premium badge',
    ],
  },
  elite: {
    id: 'elite',
    name: 'Elite',
    price: 10,
    priceLabel: '$10/month',
    stripePriceId: 'price_elite',
    color: 'from-neon-pink to-neon-purple',
    features: [
      'Everything in Premium',
      'Early access to leaks',
      'Exclusive analysis docs',
      'Live map updates feed',
      'Priority support',
      'Elite-only forum',
      'Custom flair',
      'Direct messaging',
    ],
  },
};

// Check if user has access to content tier
export function hasAccess(userTier, requiredTier) {
  const hierarchy = ['free', 'premium', 'elite'];
  const userIdx = hierarchy.indexOf(userTier || 'free');
  const requiredIdx = hierarchy.indexOf(requiredTier);
  return userIdx >= requiredIdx;
}
