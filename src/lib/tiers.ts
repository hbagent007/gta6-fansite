// Static tier definitions — safe to import anywhere
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

export function hasAccess(userTier, requiredTier) {
  const hierarchy = ['free', 'premium', 'elite'];
  const userIdx = hierarchy.indexOf(userTier || 'free');
  const requiredIdx = hierarchy.indexOf(requiredTier);
  return userIdx >= requiredIdx;
}
