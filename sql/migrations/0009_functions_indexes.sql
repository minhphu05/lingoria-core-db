CREATE OR REPLACE FUNCTION platform.touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DO $$
DECLARE
  target text;
BEGIN
  FOREACH target IN ARRAY ARRAY[
    'catalog.language',
    'catalog.locale',
    'catalog.site',
    'catalog.experience_profile',
    'content.content_item',
    'content.content_text',
    'learning.course',
    'learning.unit',
    'learning.lesson',
    'learning.lesson_block',
    'ingestion.data_source',
    'media.asset',
    'media.media_item',
    'media.transcript',
    'community.comment',
    'notification.preference',
    'billing.subscription',
    'search.search_document'
  ]
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON %s', replace(target, '.', '_') || '_updated_at', target);
    EXECUTE format('CREATE TRIGGER %I BEFORE UPDATE ON %s FOR EACH ROW EXECUTE FUNCTION platform.touch_updated_at()', replace(target, '.', '_') || '_updated_at', target);
  END LOOP;
END;
$$;

ALTER TABLE catalog.experience_profile
  ADD CONSTRAINT experience_profile_hero_asset_fk
  FOREIGN KEY (hero_asset_id) REFERENCES media.asset(id) ON DELETE SET NULL;

CREATE UNIQUE INDEX site_locale_uidx ON catalog.site (locale_id);
CREATE UNIQUE INDEX catalog_default_framework_uidx
  ON catalog.proficiency_framework_locale (locale_id)
  WHERE is_default;
CREATE UNIQUE INDEX catalog_primary_script_uidx
  ON catalog.locale_script (locale_id)
  WHERE is_primary;
CREATE UNIQUE INDEX catalog_primary_country_language_uidx
  ON catalog.country_language (country_id)
  WHERE is_primary;

CREATE OR REPLACE FUNCTION search.refresh_search_vector()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.search_vector := to_tsvector(
    'simple',
    coalesce(NEW.title, '') || ' ' || coalesce(NEW.search_text, '') || ' ' || coalesce(NEW.keywords, '')
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS search_document_vector_trg ON search.search_document;
CREATE TRIGGER search_document_vector_trg
BEFORE INSERT OR UPDATE OF title, search_text, keywords
ON search.search_document
FOR EACH ROW EXECUTE FUNCTION search.refresh_search_vector();

CREATE INDEX content_item_published_idx
  ON content.content_item (primary_locale_id, published_at DESC)
  WHERE status = 'published' AND deleted_at IS NULL;
CREATE INDEX lesson_published_idx
  ON learning.lesson (unit_id, position)
  WHERE status = 'published';
CREATE INDEX content_progress_due_idx
  ON progress.content_progress (user_id, last_seen_at DESC);
CREATE INDEX lexeme_state_due_idx
  ON progress.lexeme_state (user_id, next_review_at);
CREATE INDEX community_report_status_idx
  ON community.report (status, created_at DESC);

