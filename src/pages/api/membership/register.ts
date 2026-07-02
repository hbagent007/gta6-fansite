import type { APIRoute } from 'astro';
import { createClient } from '@supabase/supabase-js';

/**
 * POST /api/membership/register
 *
 * Fallback/manual endpoint to upsert a user's membership and launch registration.
 * The main flow uses the PostgreSQL trigger on auth.users, but this endpoint
 * exists in case the trigger doesn't fire (e.g. manual account creation).
 *
 * Request body: { userId: string }
 * Response:     { membership: MembershipRow }
 */
export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await request.json();
    const { userId } = body;

    if (!userId) {
      return new Response(JSON.stringify({ error: 'Missing userId' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL;
    const serviceKey = import.meta.env.SUPABASE_SERVICE_KEY;

    if (!supabaseUrl || !serviceKey) {
      return new Response(
        JSON.stringify({ error: 'Supabase not configured' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const supabase = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false },
    });

    // Look up the user
    const { data: user, error: userError } = await supabase.auth.admin.getUserById(userId);
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'User not found' }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // Check for existing membership
    const { data: existing } = await supabase
      .from('memberships')
      .select('*')
      .eq('user_id', userId)
      .single();

    if (existing) {
      return new Response(JSON.stringify({ membership: existing }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // Count current launch registrations to decide Premium tier
    const { count } = await supabase
      .from('launch_registrations')
      .select('*', { count: 'exact', head: true });

    const spotsRemaining = 500 - (count || 0);
    const isPremium = spotsRemaining > 0;

    // Create membership record
    const { data: membership, error: mError } = await supabase
      .from('memberships')
      .insert({
        user_id: userId,
        tier: isPremium ? 'premium' : 'free',
        status: 'active',
      })
      .select()
      .single();

    if (mError) {
      throw new Error(`Failed to create membership: ${mError.message}`);
    }

    // Upsert launch registration
    await supabase.from('launch_registrations').upsert(
      {
        user_id: userId,
        email: user.email,
        claimed_premium: isPremium,
      },
      { onConflict: 'user_id' }
    );

    return new Response(JSON.stringify({ membership }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err: any) {
    console.error('Membership registration error:', err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
};
