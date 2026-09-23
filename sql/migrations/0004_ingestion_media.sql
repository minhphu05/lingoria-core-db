CREATE SCHEMA IF NOT EXISTS ingestion;
CREATE SCHEMA IF NOT EXISTS media;

CREATE TABLE ingestion.license (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(100) NOT NULL UNIQUE,
  name varchar(200) NOT NULL,
  url text,
  commercial_use_allowed boolean,
  derivatives_allowed boolean,
  attribution_required boolean,
  share_alike_required boolean,
  attribution_template text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE ingestion.data_source (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(100) NOT NULL UNIQUE,
  name varchar(200) NOT NULL,
  source_type varchar(80),
  base_url text,
  owner varchar(300),
  default_license_id uuid REFERENCES ingestion.license(id) ON DELETE RESTRICT,
  status varchar(30) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'retired')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  terms_checked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE ingestion.source_item (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id uuid NOT NULL REFERENCES ingestion.data_source(id) ON DELETE RESTRICT,
  external_id varchar(500),
  canonical_url text,
  license_id uuid REFERENCES ingestion.license(id) ON DELETE RESTRICT,
  source_updated_at timestamptz,
  fetched_at timestamptz NOT NULL DEFAULT now(),
  checksum varchar(200),
  raw_object_key varchar(1000),
  raw_metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE UNIQUE INDEX source_item_external_uidx ON ingestion.source_item (source_id, external_id) WHERE external_id IS NOT NULL;
CREATE INDEX source_item_checksum_idx ON ingestion.source_item (checksum) WHERE checksum IS NOT NULL;

CREATE TABLE ingestion.ingestion_run (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id uuid NOT NULL REFERENCES ingestion.data_source(id) ON DELETE RESTRICT,
  pipeline_name varchar(200) NOT NULL,
  pipeline_version varchar(100),
  status varchar(30) NOT NULL CHECK (status IN ('queued', 'running', 'succeeded', 'failed', 'partial')),
  started_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  items_received bigint NOT NULL DEFAULT 0,
  items_created bigint NOT NULL DEFAULT 0,
  items_updated bigint NOT NULL DEFAULT 0,
  items_failed bigint NOT NULL DEFAULT 0,
  error_summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX ingestion_run_source_idx ON ingestion.ingestion_run (source_id, started_at DESC);

CREATE TABLE ingestion.ingestion_run_item (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ingestion_run_id uuid NOT NULL REFERENCES ingestion.ingestion_run(id) ON DELETE CASCADE,
  source_item_id uuid REFERENCES ingestion.source_item(id) ON DELETE RESTRICT,
  status varchar(30) NOT NULL CHECK (status IN ('received', 'staged', 'normalized', 'reviewing', 'published', 'failed', 'skipped')),
  action varchar(30),
  error_message text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ingestion_run_item_status_idx ON ingestion.ingestion_run_item (ingestion_run_id, status);

CREATE TABLE media.asset (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_type varchar(50) NOT NULL CHECK (asset_type IN ('IMAGE', 'VIDEO', 'AUDIO', 'SVG', 'SUBTITLE', 'DOCUMENT', 'RAW')),
  storage_provider varchar(80),
  bucket varchar(200),
  object_key varchar(1000),
  external_url text,
  mime_type varchar(150),
  size_bytes bigint CHECK (size_bytes IS NULL OR size_bytes >= 0),
  width int CHECK (width IS NULL OR width > 0),
  height int CHECK (height IS NULL OR height > 0),
  duration_ms bigint CHECK (duration_ms IS NULL OR duration_ms >= 0),
  checksum varchar(200),
  license_id uuid REFERENCES ingestion.license(id) ON DELETE RESTRICT,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT asset_location_ck CHECK (object_key IS NOT NULL OR external_url IS NOT NULL)
);
CREATE UNIQUE INDEX asset_object_uidx ON media.asset (storage_provider, bucket, object_key) WHERE object_key IS NOT NULL;
CREATE INDEX asset_checksum_idx ON media.asset (checksum) WHERE checksum IS NOT NULL;
CREATE INDEX asset_type_idx ON media.asset (asset_type);

CREATE TABLE media.speaker (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  display_name varchar(200),
  locale_id uuid REFERENCES catalog.locale(id) ON DELETE SET NULL,
  speaker_type varchar(50) CHECK (speaker_type IS NULL OR speaker_type IN ('human', 'teacher', 'guest', 'licensed_voice', 'ai_voice')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE media.media_type (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(80) NOT NULL UNIQUE,
  name varchar(120) NOT NULL
);

CREATE TABLE media.media_item (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_item_id uuid NOT NULL UNIQUE REFERENCES content.content_item(id) ON DELETE CASCADE,
  media_type_id uuid NOT NULL REFERENCES media.media_type(id) ON DELETE RESTRICT,
  provider varchar(80),
  external_id varchar(500),
  duration_ms bigint CHECK (duration_ms IS NULL OR duration_ms >= 0),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT media_external_id_ck CHECK (external_id IS NULL OR provider IS NOT NULL)
);
CREATE UNIQUE INDEX media_provider_external_uidx ON media.media_item (provider, external_id) WHERE external_id IS NOT NULL;

CREATE TABLE media.media_variant (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  media_item_id uuid NOT NULL REFERENCES media.media_item(id) ON DELETE CASCADE,
  asset_id uuid NOT NULL REFERENCES media.asset(id) ON DELETE RESTRICT,
  role varchar(80) NOT NULL CHECK (role IN ('ORIGINAL', 'VIDEO_1080P', 'VIDEO_720P', 'AUDIO', 'THUMBNAIL', 'COVER', 'SUBTITLE')),
  quality varchar(80),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (media_item_id, role, quality)
);
CREATE INDEX media_variant_asset_idx ON media.media_variant (asset_id);

