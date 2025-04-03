import { createClient } from '@supabase/supabase-js';

// Log environment variables (without exposing sensitive data)
console.log('Supabase URL exists:', !!import.meta.env.VITE_SUPABASE_URL);
console.log('Supabase Anon Key exists:', !!import.meta.env.VITE_SUPABASE_ANON_KEY);

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('Environment variables not loaded:', {
    hasUrl: !!supabaseUrl,
    hasKey: !!supabaseAnonKey,
    envKeys: Object.keys(import.meta.env)
  });
  throw new Error('Missing Supabase environment variables. Please check your .env file and ensure it contains VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY.');
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true,
    storage: window.localStorage,
    onAuthStateChange: (event, session) => {
      if (event === 'SIGNED_OUT' || event === 'USER_DELETED') {
        // Clear any user data from localStorage
        localStorage.removeItem('employeeId');
        localStorage.removeItem('supabase.auth.token');
        // Redirect to login
        window.location.href = '/login/empleado';
      }
    }
  },
  global: {
    headers: {
      'x-client-info': 'controlaltsup@1.0.0'
    }
  },
  db: {
    schema: 'public'
  }
});

// Test connection and log auth state
supabase.auth.getSession().then(({ data, error }) => {
  if (error) {
    console.error('Error connecting to Supabase:', error.message);
  } else {
    console.log('Supabase connection successful, auth state:', {
      hasSession: !!data.session,
      user: data.session?.user?.email || 'No user'
    });
  }
}).catch(err => {
  console.error('Failed to connect to Supabase:', err);
});