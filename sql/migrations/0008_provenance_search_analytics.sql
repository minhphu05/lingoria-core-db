CREATE SCHEMA IF NOT EXISTS search;
CREATE SCHEMA IF NOT EXISTS analytics;

CREATE TABLE ingestion.content_provenance (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_item_id uuid NOT NULL REFERENCES content.content_item(id) ON DELETE CASCADE,
  source_item_id uuid NOT NULL REFERENCES ingestion.source_item(id) ON DELETE RESTRICT,
  provenance_type varchar(50) NOT NULL CHECK (provenance_type IN ('DIRECT_IMPORT', 'DERIVED', 'REFERENCE', 'EDITORIAL', 'AI_GENERATED', 'HUMAN_REVIEWED')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (content_item_id, source_item_id, provenance_type)
);
CREATE INDEX content_provenance_source_idx ON ingestion.content_provenance (source_item_id);

CREATE TABLE ingestion.asset_provenance (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id uuid NOT NULL REFERENCES media.asset(id) ON DELETE CASCADE,
  source_item_id uuid NOT NULL REFERENCES ingestion.source_item(id) ON DELETE RESTRICT,
  provenance_type varchar(50) NOT NULL CHECK (provenance_type IN ('DIRECT_IMPORT', 'DERIVED', 'REFERENCE', 'EDITORIAL', 'AI_GENERATED', 'HUMAN_REVIEWED')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (asset_id, source_item_id, provenance_type)
);

CREATE TABLE search.search_document (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_item_id uuid NOT NULL REFERENCES content.content_item(id) ON DELETE CASCADE,
  language_id uuid NOT NULL REFERENCES catalog.language(id) ON DELETE RESTRICT,
  title text,
  search_text text NOT NULL,
  keywords text,
  search_vector tsvector,
  embedding vector(1536),
  embedding_model varchar(150),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (content_item_id, language_id),
  CONSTRAINT embedding_model_ck CHECK (embedding IS NULL OR embedding_model IS NOT NULL)
);
CREATE INDEX search_document_vector_idx ON search.search_document USING gin (search_vector);
CREATE INDEX search_document_trgm_idx ON search.search_document USING gin (search_text gin_trgm_ops);
CREATE INDEX search_document_embedding_idx ON search.search_document USING hnsw (embedding vector_cosine_ops) WHERE embedding IS NOT NULL;

CREATE TABLE analytics.event (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid,
  session_id uuid REFERENCES progress.study_session(id) ON DELETE SET NULL,
  locale_id uuid REFERENCES catalog.locale(id) ON DELETE SET NULL,
  event_name varchar(160) NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX analytics_event_time_idx ON analytics.event (occurred_at DESC);
CREATE INDEX analytics_event_user_idx ON analytics.event (user_id, occurred_at DESC);
CREATE INDEX analytics_event_name_idx ON analytics.event (event_name, occurred_at DESC);

