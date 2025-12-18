-- =============================================
-- SHIZLIST DATABASE SCHEMA
-- =============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================
-- USERS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS public.users (
    id BIGSERIAL PRIMARY KEY,
    uid UUID UNIQUE NOT NULL DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    display_name TEXT,
    avatar_url TEXT,
    currency_code TEXT NOT NULL DEFAULT 'GBP',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    
    CONSTRAINT users_uid_key UNIQUE (uid)
);

-- Create index on uid for faster lookups
CREATE INDEX IF NOT EXISTS users_uid_idx ON public.users(uid);

-- Enable RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Users can read their own profile
CREATE POLICY "Users can view own profile" ON public.users
    FOR SELECT USING (auth.uid()::text = uid::text);

-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING (auth.uid()::text = uid::text);

-- Users can insert their own profile (on signup)
-- Allow insert when the uid matches auth.uid OR when it's a new signup (uid not yet in table)
CREATE POLICY "Users can insert own profile" ON public.users
    FOR INSERT WITH CHECK (
        auth.uid() IS NOT NULL 
        AND auth.uid()::text = uid::text
    );

-- Allow users to view other users' basic info (for sharing)
CREATE POLICY "Users can view others basic info" ON public.users
    FOR SELECT USING (true);

-- =============================================
-- LISTS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS public.lists (
    id BIGSERIAL PRIMARY KEY,
    uid UUID UNIQUE NOT NULL DEFAULT uuid_generate_v4(),
    owner_id UUID NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    cover_image_url TEXT,
    visibility TEXT NOT NULL DEFAULT 'private' CHECK (visibility IN ('private', 'public')),
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS lists_uid_idx ON public.lists(uid);
CREATE INDEX IF NOT EXISTS lists_owner_id_idx ON public.lists(owner_id);

ALTER TABLE public.lists ENABLE ROW LEVEL SECURITY;

-- Owners can do anything with their lists
CREATE POLICY "Owners have full access to their lists" ON public.lists
    FOR ALL USING (auth.uid()::text = owner_id::text);

-- Public lists can be viewed by anyone
CREATE POLICY "Public lists are viewable by all" ON public.lists
    FOR SELECT USING (visibility = 'public');

-- =============================================
-- LIST ITEMS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS public.list_items (
    id BIGSERIAL PRIMARY KEY,
    uid UUID UNIQUE NOT NULL DEFAULT uuid_generate_v4(),
    list_id BIGINT NOT NULL REFERENCES public.lists(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    price DECIMAL(10, 2),
    currency TEXT DEFAULT 'USD',
    thumbnail_url TEXT,
    main_image_url TEXT,
    retailer_url TEXT,
    amazon_asin TEXT,
    category TEXT NOT NULL DEFAULT 'other' CHECK (category IN ('stuff', 'events', 'trips', 'homemade', 'meals', 'other')),
    priority TEXT NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
    quantity INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS list_items_uid_idx ON public.list_items(uid);
CREATE INDEX IF NOT EXISTS list_items_list_id_idx ON public.list_items(list_id);

ALTER TABLE public.list_items ENABLE ROW LEVEL SECURITY;

-- List owners can manage their items
CREATE POLICY "List owners can manage items" ON public.list_items
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.lists 
            WHERE lists.id = list_items.list_id 
            AND lists.owner_id::text = auth.uid()::text
        )
    );

-- Anyone can view items in public lists
CREATE POLICY "Anyone can view items in public lists" ON public.list_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.lists 
            WHERE lists.id = list_items.list_id 
            AND lists.visibility = 'public'
        )
    );

-- =============================================
-- CLAIMS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS public.claims (
    id BIGSERIAL PRIMARY KEY,
    uid UUID UNIQUE NOT NULL DEFAULT uuid_generate_v4(),
    item_id BIGINT NOT NULL REFERENCES public.list_items(id) ON DELETE CASCADE,
    claimed_by_user_id UUID NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'expired', 'purchased', 'cancelled')),
    note TEXT,
    expires_at TIMESTAMPTZ,
    purchased_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    
    -- Only one active claim per item
    CONSTRAINT unique_active_claim UNIQUE (item_id, status) 
);

CREATE INDEX IF NOT EXISTS claims_item_id_idx ON public.claims(item_id);
CREATE INDEX IF NOT EXISTS claims_user_id_idx ON public.claims(claimed_by_user_id);

ALTER TABLE public.claims ENABLE ROW LEVEL SECURITY;

-- Users can view claims they made
CREATE POLICY "Users can view own claims" ON public.claims
    FOR SELECT USING (auth.uid()::text = claimed_by_user_id::text);

-- Users can view claims on public lists (but not list owners on their own items)
CREATE POLICY "Gifters can view claims on shared lists" ON public.claims
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.list_items li
            JOIN public.lists l ON l.id = li.list_id
            WHERE li.id = claims.item_id
            AND l.visibility = 'public'
            AND l.owner_id::text != auth.uid()::text  -- Hide from list owner
        )
    );

-- Users can create claims
CREATE POLICY "Users can create claims" ON public.claims
    FOR INSERT WITH CHECK (auth.uid()::text = claimed_by_user_id::text);

-- Users can update their own claims
CREATE POLICY "Users can update own claims" ON public.claims
    FOR UPDATE USING (auth.uid()::text = claimed_by_user_id::text);

-- Users can delete their own claims
CREATE POLICY "Users can delete own claims" ON public.claims
    FOR DELETE USING (auth.uid()::text = claimed_by_user_id::text);

-- =============================================
-- LIST SHARES TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS public.list_shares (
    id BIGSERIAL PRIMARY KEY,
    list_id BIGINT NOT NULL REFERENCES public.lists(id) ON DELETE CASCADE,
    shared_with_user_id UUID NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
    can_edit BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_list_share UNIQUE (list_id, shared_with_user_id)
);

CREATE INDEX IF NOT EXISTS list_shares_list_id_idx ON public.list_shares(list_id);
CREATE INDEX IF NOT EXISTS list_shares_user_id_idx ON public.list_shares(shared_with_user_id);

ALTER TABLE public.list_shares ENABLE ROW LEVEL SECURITY;

-- List owners can manage shares
CREATE POLICY "List owners can manage shares" ON public.list_shares
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.lists 
            WHERE lists.id = list_shares.list_id 
            AND lists.owner_id::text = auth.uid()::text
        )
    );

-- Users can view shares for lists shared with them
CREATE POLICY "Users can view their shares" ON public.list_shares
    FOR SELECT USING (auth.uid()::text = shared_with_user_id::text);

-- =============================================
-- CONVERSATIONS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS public.conversations (
    id BIGSERIAL PRIMARY KEY,
    uid UUID UNIQUE NOT NULL DEFAULT uuid_generate_v4(),
    list_id BIGINT NOT NULL REFERENCES public.lists(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS conversations_list_id_idx ON public.conversations(list_id);

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

-- Users can view conversations for lists they have access to
CREATE POLICY "Users can view accessible conversations" ON public.conversations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.lists l
            WHERE l.id = conversations.list_id
            AND (l.owner_id::text = auth.uid()::text OR l.visibility = 'public')
        )
    );

-- =============================================
-- MESSAGES TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS public.messages (
    id BIGSERIAL PRIMARY KEY,
    uid UUID UNIQUE NOT NULL DEFAULT uuid_generate_v4(),
    conversation_id BIGINT NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    sender_user_id UUID NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
    content TEXT NOT NULL,
    scope TEXT NOT NULL DEFAULT 'everyone' CHECK (scope IN ('all_gifters', 'everyone', 'creator_only', 'selected_gifters')),
    visible_to_user_ids UUID[],
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    edited_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS messages_conversation_id_idx ON public.messages(conversation_id);
CREATE INDEX IF NOT EXISTS messages_sender_id_idx ON public.messages(sender_user_id);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Users can view messages based on scope
CREATE POLICY "Users can view messages" ON public.messages
    FOR SELECT USING (
        -- User is the sender
        auth.uid()::text = sender_user_id::text
        OR
        -- Message scope allows viewing
        EXISTS (
            SELECT 1 FROM public.conversations c
            JOIN public.lists l ON l.id = c.list_id
            WHERE c.id = messages.conversation_id
            AND (
                (messages.scope = 'everyone')
                OR (messages.scope = 'creator_only' AND l.owner_id::text = auth.uid()::text)
                OR (messages.scope = 'all_gifters' AND l.owner_id::text != auth.uid()::text)
                OR (messages.scope = 'selected_gifters' AND auth.uid() = ANY(messages.visible_to_user_ids))
            )
        )
    );

-- Users can send messages
CREATE POLICY "Users can send messages" ON public.messages
    FOR INSERT WITH CHECK (auth.uid()::text = sender_user_id::text);

-- Users can update their own messages
CREATE POLICY "Users can update own messages" ON public.messages
    FOR UPDATE USING (auth.uid()::text = sender_user_id::text);

-- =============================================
-- CONTACTS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS public.contacts (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
    contact_user_id UUID NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
    nickname TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_contact UNIQUE (user_id, contact_user_id),
    CONSTRAINT no_self_contact CHECK (user_id != contact_user_id)
);

CREATE INDEX IF NOT EXISTS contacts_user_id_idx ON public.contacts(user_id);

ALTER TABLE public.contacts ENABLE ROW LEVEL SECURITY;

-- Users can manage their own contacts
CREATE POLICY "Users can manage own contacts" ON public.contacts
    FOR ALL USING (auth.uid()::text = user_id::text);

-- =============================================
-- HELPER FUNCTIONS
-- =============================================

-- Function to claim an item
CREATE OR REPLACE FUNCTION public.claim_item(
    p_item_id BIGINT,
    p_user_id UUID,
    p_expires_at TIMESTAMPTZ DEFAULT NULL,
    p_note TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if item is already claimed
    IF EXISTS (
        SELECT 1 FROM public.claims 
        WHERE item_id = p_item_id AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'Item is already claimed';
    END IF;
    
    -- Create the claim
    INSERT INTO public.claims (item_id, claimed_by_user_id, expires_at, note)
    VALUES (p_item_id, p_user_id, p_expires_at, p_note);
END;
$$;

-- Function to unclaim an item
CREATE OR REPLACE FUNCTION public.unclaim_item(
    p_item_id BIGINT,
    p_user_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.claims
    SET status = 'cancelled', updated_at = NOW()
    WHERE item_id = p_item_id 
    AND claimed_by_user_id = p_user_id
    AND status = 'active';
END;
$$;

-- =============================================
-- VIEW: Public list items with claim status (for gifters)
-- =============================================
CREATE OR REPLACE VIEW public.public_list_items AS
SELECT 
    li.*,
    CASE 
        WHEN c.id IS NOT NULL AND c.status = 'active' THEN true 
        ELSE false 
    END AS is_claimed,
    CASE 
        WHEN c.claimed_by_user_id::text = auth.uid()::text THEN c.claimed_by_user_id 
        ELSE NULL 
    END AS claimed_by_user_id,
    c.created_at AS claimed_at,
    c.expires_at AS claim_expires_at
FROM public.list_items li
LEFT JOIN public.claims c ON c.item_id = li.id AND c.status = 'active';

-- =============================================
-- TRIGGER: Auto-create user profile on signup
-- =============================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    INSERT INTO public.users (uid, email, display_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1))
    );
    RETURN NEW;
END;
$$;

-- Create trigger on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================
-- STORAGE BUCKETS (run separately in Storage settings)
-- =============================================
-- Create buckets: profile-images, item-images
-- Set policies to allow authenticated users to upload to their own folders

