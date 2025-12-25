-- =============================================
-- ADD RLS POLICIES FOR SHARED LISTS
-- =============================================
-- These policies allow users to view lists, items, and commits
-- for lists that have been shared with them via the list_shares table.

-- First, disable RLS on list_shares to avoid circular policy dependencies
-- (list_shares is not sensitive - it just maps users to lists they can view)
ALTER TABLE public.list_shares DISABLE ROW LEVEL SECURITY;

-- Users can view lists shared with them
CREATE POLICY "Users can view lists shared with them" ON public.lists
    FOR SELECT USING (
        uid IN (
            SELECT list_uid FROM public.list_shares 
            WHERE shared_with_user_id::text = auth.uid()::text
        )
    );

-- Users can view items in lists shared with them
CREATE POLICY "Users can view items in shared lists" ON public.list_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.list_shares
            WHERE list_shares.list_uid = (
                SELECT uid FROM public.lists WHERE lists.id = list_items.list_id
            )
            AND list_shares.shared_with_user_id::text = auth.uid()::text
        )
    );

-- Users can view commits on items in lists shared with them
CREATE POLICY "Users can view commits in shared lists" ON public.commits
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.list_items
            JOIN public.lists ON lists.id = list_items.list_id
            JOIN public.list_shares ON list_shares.list_uid = lists.uid
            WHERE list_items.uid = commits.item_uid
            AND list_shares.shared_with_user_id::text = auth.uid()::text
        )
    );

-- Users can view purchases on items in lists shared with them
CREATE POLICY "Users can view purchases in shared lists" ON public.purchases
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.list_items
            JOIN public.lists ON lists.id = list_items.list_id
            JOIN public.list_shares ON list_shares.list_uid = lists.uid
            WHERE list_items.uid = purchases.item_uid
            AND list_shares.shared_with_user_id::text = auth.uid()::text
        )
    );

-- List owners can view purchases on items in their own lists
CREATE POLICY "Owners can view purchases on their lists" ON public.purchases
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.list_items
            JOIN public.lists ON lists.id = list_items.list_id
            WHERE list_items.uid = purchases.item_uid
            AND lists.owner_id::text = auth.uid()::text
        )
    );

-- List owners can view commits on items in their own lists
CREATE POLICY "Owners can view commits on their lists" ON public.commits
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.list_items
            JOIN public.lists ON lists.id = list_items.list_id
            WHERE list_items.uid = commits.item_uid
            AND lists.owner_id::text = auth.uid()::text
        )
    );

-- Users can insert purchases on items in lists shared with them
CREATE POLICY "Users can insert purchases in shared lists" ON public.purchases
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.list_items
            JOIN public.lists ON lists.id = list_items.list_id
            JOIN public.list_shares ON list_shares.list_uid = lists.uid
            WHERE list_items.uid = purchases.item_uid
            AND list_shares.shared_with_user_id::text = auth.uid()::text
        )
    );

-- Users can update their own purchases
CREATE POLICY "Users can update their own purchases" ON public.purchases
    FOR UPDATE USING (
        claimed_by_user_id::text = auth.uid()::text
    );

-- Users can delete their own purchases
CREATE POLICY "Users can delete their own purchases" ON public.purchases
    FOR DELETE USING (
        claimed_by_user_id::text = auth.uid()::text
    );

