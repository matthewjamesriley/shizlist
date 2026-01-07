-- =============================================
-- MIGRATE INVITE_LINKS TO USE LIST_UIDS ARRAY
-- =============================================
-- This allows sharing multiple specific lists per invite

-- Add list_uids array column
ALTER TABLE invite_links ADD COLUMN IF NOT EXISTS list_uids UUID[] DEFAULT '{}';

-- Migrate existing single list_uid values to the array
UPDATE invite_links 
SET list_uids = ARRAY[list_uid] 
WHERE list_uid IS NOT NULL AND (list_uids IS NULL OR list_uids = '{}');

-- For share_all_lists=true invites, we could optionally populate with all owner's friends lists
-- But we'll leave them empty for backward compatibility and let them work as "all lists" legacy invites

-- Create index on list_uids for faster lookups (GIN index for array)
CREATE INDEX IF NOT EXISTS invite_links_list_uids_idx ON invite_links USING GIN (list_uids);

-- NOTE: We're keeping list_uid and share_all_lists columns for backward compatibility
-- New invites will use list_uids array exclusively
-- Old code paths can still read list_uid if needed


