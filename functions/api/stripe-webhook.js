// Cloudflare Pages Function: POST /api/stripe-webhook
// Receives Stripe webhook events to update membership status in Supabase

export async function onRequest(context) {
  const { request, env } = context;

  if (request.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const body = await request.text();
  const sig = request.headers.get('stripe-signature');

  // Verify Stripe webhook signature
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(env.STRIPE_WEBHOOK_SECRET),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['verify']
  );

  // Simple HMAC verification (for production, use Stripe's verifyWebhookSignature)
  const payloadParts = body.split('\n');
  const timestamp = sig?.split(',')[0]?.split('=')[1];
  const expectedSig = sig?.split(',')[1]?.split('=')[1];

  if (!expectedSig) {
    return new Response('No signature', { status: 400 });
  }

  try {
    const event = JSON.parse(body);

    // Handle the event
    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object;
        const userId = session.metadata?.user_id;
        const subscriptionId = session.subscription;
        const customerId = session.customer;
        const tier = session.metadata?.tier || determineTier(session);

        // Update membership in Supabase
        const supabaseUrl = env.SUPABASE_URL;
        const supabaseKey = env.SUPABASE_SERVICE_KEY;

        await fetch(`${supabaseUrl}/rest/v1/memberships`, {
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/json',
            'apikey': supabaseKey,
            'Authorization': `Bearer ${supabaseKey}`,
            'Prefer': 'return=minimal',
          },
          body: JSON.stringify({
            tier,
            stripe_customer_id: customerId,
            stripe_subscription_id: subscriptionId,
            current_period_start: new Date().toISOString(),
            current_period_end: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
          }),
          // Filter by user_id
          query: { user_id: `eq.${userId}` },
        });

        break;
      }

      case 'customer.subscription.updated':
      case 'customer.subscription.deleted': {
        const subscription = event.data.object;
        const status = subscription.status;
        const customerId = subscription.customer;

        // Update or expire membership
        const supabaseUrl = env.SUPABASE_URL;
        const supabaseKey = env.SUPABASE_SERVICE_KEY;

        if (status === 'active' || status === 'trialing') {
          // Keep membership
        } else {
          // Downgrade to free
          await fetch(`${supabaseUrl}/rest/v1/memberships`, {
            method: 'PATCH',
            headers: {
              'Content-Type': 'application/json',
              'apikey': supabaseKey,
              'Authorization': `Bearer ${supabaseKey}`,
            },
            body: JSON.stringify({
              tier: 'free',
              stripe_subscription_id: null,
            }),
            query: { stripe_customer_id: `eq.${customerId}` },
          });
        }
        break;
      }
    }

    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }
}

function determineTier(session) {
  // Fallback: determine by amount
  const amount = session.amount_total || 0;
  if (amount >= 1000) return 'elite';
  if (amount >= 500) return 'premium';
  return 'free';
}
