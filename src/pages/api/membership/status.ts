import type { APIRoute } from 'astro';
import { createClient } from '@supabase/supabase-js';

/**
 * GET /api/membership/status?userId=xxx
 *
 * Returns the current user's membership status.
 * Used by the dashboard and membership pages to display tier info.
 *
 * Query params: userId (required), token (optional Supabase access token)
 * Response: { tier, status, started_at, expires_at } or { error, membership: null }
 */
export const GET: APIRoute = async ({ url }) => {
  try {
    const userId = url.searchParams.get('userId');

    if (!userId) {
      return new Response(
        JSON.stringify({ error: 'Missing userId query parameter' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL;
    const anonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;

    if (!supabaseUrl || !anonKey) {
      return new Response(
        JSON.stringify({ error: 'Supabase not configured', membership: null }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Use anon key + the access_token from the request header if available
    const authHeader = url.searchParams.get('token')
      ? { Authorization: `Bearer ${url.searchParams.get('token')}` }
      : {};

    const supabase = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false },
      global: { headers: authHeader },
    });

    // Verify the requesting user matches or use service role fallback
    const { data: { user } } = await supabase.auth.getUser(
      authHeader.Authorization?.replace('Bearer ', '')
    );

    // If caller is authenticated as the same user, use RLS
    if (user && user.id === userId) {
      const { data: membership, error } = await supabase
        .from('memberships')
        .select('*')
        .eq('user_id', userId)
        .single();

      if (error && error.code !== 'PGRST116') {
        return new Response(
          JSON.stringify({ error: error.message, membership: null }),
          { status: 200, headers: { 'Content-Type': 'application/json' } }
        );
      }

      return new Response(
        JSON.stringify({
          membership: membership || { tier: 'free', status: 'active' },
          spots_remaining: null, // client can fetch this separately
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Fallback: use service role to fetch
    const serviceKey = import.meta.env.SUPABASE_SERVICE_KEY;
    if (serviceKey) {
      const adminClient = createClient(supabaseUrl, serviceKey, {
        auth: { persistSession: false },
      });

      const { data: membership, error } = await adminClient
        .from('memberships')
        .select('*')
        .eq('user_id', userId)
        .single();

      if (error && error.code !== 'PGRST116') {
        return new Response(
          JSON.stringify({ error: error.message, membership: null }),
          { status: 200, headers: { 'Content-Type': 'application/json' } }
        );
      }

      return new Response(
        JSON.stringify({
          membership: membership || { tier: 'free', status: 'active' },
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // No auth available — return default free tier
    return new Response(
      JSON.stringify({ membership: { tier: 'free', status: 'active' }, notice: 'Unauthenticated' }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    );
  } catch (err: any) {
    console.error('Membership status error:', err);
    return new Response(JSON.stringify({ error: err.message, membership: null }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }
};
