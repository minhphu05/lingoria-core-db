-- Korean source support.
--
-- The canonical language model remains generic. This migration adds the two
-- structures required by Korean source data: source-specific topic aliases
-- and multiple morphemes per surface token.

CREATE TABLE catalog.topic_alias (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  topic_id uuid NOT NULL REFERENCES catalog.topic(id) ON DELETE CASCADE,
  source_id uuid NOT NULL REFERENCES ingestion.data_source(id) ON DELETE RESTRICT,
  locale_id uuid REFERENCES catalog.locale(id) ON DELETE RESTRICT,
  alias_type varchar(50) NOT NULL DEFAULT 'SOURCE_CATEGORY',
  external_code varchar(200),
  external_name varchar(300) NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (source_id, external_code),
  UNIQUE (source_id, locale_id, external_name)
);

CREATE INDEX topic_alias_topic_idx ON catalog.topic_alias (topic_id);
CREATE INDEX topic_alias_source_name_idx ON catalog.topic_alias (source_id, external_name);

COMMENT ON TABLE catalog.topic_alias IS
  'Maps source-specific topic/category labels to Lingoria canonical topics.';

CREATE TABLE linguistic.sentence_token_morpheme (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sentence_token_id uuid NOT NULL REFERENCES linguistic.sentence_token(id) ON DELETE CASCADE,
  analysis_code varchar(100) NOT NULL DEFAULT 'canonical',
  position int NOT NULL CHECK (position > 0),
  surface varchar(500) NOT NULL,
  normalized_surface varchar(500),
  lexeme_id uuid REFERENCES linguistic.lexeme(id) ON DELETE SET NULL,
  inflected_form_id uuid REFERENCES linguistic.inflected_form(id) ON DELETE SET NULL,
  part_of_speech_id uuid REFERENCES linguistic.part_of_speech(id) ON DELETE SET NULL,
  start_offset int,
  end_offset int,
  grammatical_features jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (sentence_token_id, analysis_code, position),
  CONSTRAINT sentence_token_morpheme_offset_ck CHECK (
    end_offset IS NULL OR start_offset IS NULL OR end_offset >= start_offset
  )
);

CREATE INDEX sentence_token_morpheme_lexeme_idx
  ON linguistic.sentence_token_morpheme (lexeme_id);

CREATE INDEX sentence_token_morpheme_pos_idx
  ON linguistic.sentence_token_morpheme (part_of_speech_id);

COMMENT ON TABLE linguistic.sentence_token_morpheme IS
  'Morpheme-level analyses for languages such as Korean; analysis_code allows multiple analyzers or versions.';
