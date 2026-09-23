CREATE SCHEMA IF NOT EXISTS culture;
CREATE SCHEMA IF NOT EXISTS progress;
CREATE SCHEMA IF NOT EXISTS community;
CREATE SCHEMA IF NOT EXISTS notification;
CREATE SCHEMA IF NOT EXISTS billing;

CREATE TABLE culture.entity_type (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(100) NOT NULL UNIQUE,
  name varchar(150) NOT NULL
);

CREATE TABLE culture.cultural_entity (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_item_id uuid NOT NULL UNIQUE REFERENCES content.content_item(id) ON DELETE CASCADE,
  entity_type_id uuid NOT NULL REFERENCES culture.entity_type(id) ON DELETE RESTRICT,
  country_id uuid REFERENCES catalog.country(id) ON DELETE SET NULL,
  latitude numeric(10, 7),
  longitude numeric(10, 7),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX cultural_entity_type_idx ON culture.cultural_entity (entity_type_id);
CREATE INDEX cultural_entity_country_idx ON culture.cultural_entity (country_id);

CREATE TABLE culture.cultural_entity_text (
  cultural_entity_id uuid NOT NULL REFERENCES culture.cultural_entity(id) ON DELETE CASCADE,
  language_id uuid NOT NULL REFERENCES catalog.language(id) ON DELETE RESTRICT,
  name varchar(400) NOT NULL,
  native_name varchar(400),
  short_description text,
  description text,
  PRIMARY KEY (cultural_entity_id, language_id)
);

CREATE TABLE culture.relation_type (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(100) NOT NULL UNIQUE,
  name varchar(150) NOT NULL
);

CREATE TABLE culture.entity_relation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_entity_id uuid NOT NULL REFERENCES culture.cultural_entity(id) ON DELETE CASCADE,
  target_entity_id uuid NOT NULL REFERENCES culture.cultural_entity(id) ON DELETE CASCADE,
  relation_type_id uuid NOT NULL REFERENCES culture.relation_type(id) ON DELETE RESTRICT,
  weight numeric(8, 4),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (source_entity_id, target_entity_id, relation_type_id),
  CONSTRAINT entity_relation_not_self_ck CHECK (source_entity_id <> target_entity_id)
);

CREATE TABLE culture.article (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_item_id uuid NOT NULL UNIQUE REFERENCES content.content_item(id) ON DELETE CASCADE,
  article_type varchar(100),
  hero_asset_id uuid REFERENCES media.asset(id) ON DELETE SET NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE culture.article_text (
  article_id uuid NOT NULL REFERENCES culture.article(id) ON DELETE CASCADE,
  language_id uuid NOT NULL REFERENCES catalog.language(id) ON DELETE RESTRICT,
  title varchar(500) NOT NULL,
  summary text,
  body_document jsonb NOT NULL,
  PRIMARY KEY (article_id, language_id)
);

CREATE TABLE culture.article_entity (
  article_id uuid NOT NULL REFERENCES culture.article(id) ON DELETE CASCADE,
  cultural_entity_id uuid NOT NULL REFERENCES culture.cultural_entity(id) ON DELETE RESTRICT,
  relation_type varchar(80),
  position int,
  PRIMARY KEY (article_id, cultural_entity_id)
);

CREATE TABLE progress.course_progress (
  user_id uuid NOT NULL,
  course_id uuid NOT NULL REFERENCES learning.course(id) ON DELETE CASCADE,
  status varchar(30) NOT NULL DEFAULT 'started',
  progress_percent numeric(5, 2) NOT NULL DEFAULT 0 CHECK (progress_percent BETWEEN 0 AND 100),
  started_at timestamptz,
  completed_at timestamptz,
  last_accessed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (user_id, course_id)
);
CREATE INDEX course_progress_recent_idx ON progress.course_progress (user_id, last_accessed_at DESC);

CREATE TABLE progress.lesson_progress (
  user_id uuid NOT NULL,
  lesson_id uuid NOT NULL REFERENCES learning.lesson(id) ON DELETE CASCADE,
  status varchar(30) NOT NULL DEFAULT 'started',
  progress_percent numeric(5, 2) NOT NULL DEFAULT 0 CHECK (progress_percent BETWEEN 0 AND 100),
  started_at timestamptz,
  completed_at timestamptz,
  last_position int,
  last_accessed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (user_id, lesson_id)
);

CREATE TABLE progress.content_progress (
  user_id uuid NOT NULL,
  content_item_id uuid NOT NULL REFERENCES content.content_item(id) ON DELETE CASCADE,
  status varchar(30) NOT NULL DEFAULT 'seen',
  progress_percent numeric(5, 2) NOT NULL DEFAULT 0 CHECK (progress_percent BETWEEN 0 AND 100),
  mastery_score numeric(8, 3),
  first_seen_at timestamptz,
  last_seen_at timestamptz,
  completed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (user_id, content_item_id)
);

CREATE TABLE progress.lexeme_state (
  user_id uuid NOT NULL,
  lexeme_id uuid NOT NULL REFERENCES linguistic.lexeme(id) ON DELETE CASCADE,
  state varchar(30) NOT NULL DEFAULT 'NEW' CHECK (state IN ('NEW', 'LEARNING', 'FAMILIAR', 'MASTERED')),
  mastery_score numeric(8, 3),
  correct_count int NOT NULL DEFAULT 0 CHECK (correct_count >= 0),
  incorrect_count int NOT NULL DEFAULT 0 CHECK (incorrect_count >= 0),
  first_seen_at timestamptz,
  last_reviewed_at timestamptz,
  next_review_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (user_id, lexeme_id)
);

CREATE TABLE progress.review_schedule (
  user_id uuid NOT NULL,
  content_item_id uuid NOT NULL REFERENCES content.content_item(id) ON DELETE CASCADE,
  algorithm varchar(80) NOT NULL,
  algorithm_version varchar(80),
  ease_factor numeric,
  interval_days numeric,
  repetition_count int NOT NULL DEFAULT 0,
  stability numeric,
  difficulty numeric,
  last_review_at timestamptz,
  next_review_at timestamptz,
  algorithm_state jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (user_id, content_item_id)
);
CREATE INDEX review_schedule_due_idx ON progress.review_schedule (user_id, next_review_at);

CREATE TABLE progress.review_event (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  content_item_id uuid NOT NULL REFERENCES content.content_item(id) ON DELETE CASCADE,
  reviewed_at timestamptz NOT NULL DEFAULT now(),
  rating int CHECK (rating IS NULL OR rating BETWEEN 0 AND 5),
  response_time_ms int CHECK (response_time_ms IS NULL OR response_time_ms >= 0),
  was_correct boolean,
  previous_state jsonb,
  resulting_state jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX review_event_user_idx ON progress.review_event (user_id, reviewed_at DESC);

CREATE TABLE progress.bookmark (
  user_id uuid NOT NULL,
  content_item_id uuid NOT NULL REFERENCES content.content_item(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  note text,
  PRIMARY KEY (user_id, content_item_id)
);

CREATE TABLE progress.study_session (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  locale_id uuid REFERENCES catalog.locale(id) ON DELETE SET NULL,
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  duration_seconds int CHECK (duration_seconds IS NULL OR duration_seconds >= 0),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX study_session_user_idx ON progress.study_session (user_id, started_at DESC);

CREATE TABLE progress.user_streak (
  user_id uuid PRIMARY KEY,
  current_days int NOT NULL DEFAULT 0 CHECK (current_days >= 0),
  longest_days int NOT NULL DEFAULT 0 CHECK (longest_days >= 0),
  last_study_date date,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE progress.achievement (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(100) NOT NULL UNIQUE,
  name varchar(200) NOT NULL,
  description text,
  criteria jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE progress.user_achievement (
  user_id uuid NOT NULL,
  achievement_id uuid NOT NULL REFERENCES progress.achievement(id) ON DELETE CASCADE,
  awarded_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (user_id, achievement_id)
);

CREATE TABLE community.comment (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  content_item_id uuid NOT NULL REFERENCES content.content_item(id) ON DELETE CASCADE,
  parent_id uuid REFERENCES community.comment(id) ON DELETE CASCADE,
  body text NOT NULL,
  status varchar(30) NOT NULL DEFAULT 'published' CHECK (status IN ('pending', 'published', 'hidden', 'deleted')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX comment_content_idx ON community.comment (content_item_id, created_at DESC);

CREATE TABLE community.reaction (
  user_id uuid NOT NULL,
  content_item_id uuid NOT NULL REFERENCES content.content_item(id) ON DELETE CASCADE,
  reaction_type varchar(50) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, content_item_id, reaction_type)
);

CREATE TABLE community.follow (
  follower_user_id uuid NOT NULL,
  followed_user_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_user_id, followed_user_id),
  CHECK (follower_user_id <> followed_user_id)
);

CREATE TABLE community.report (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_user_id uuid NOT NULL,
  content_item_id uuid REFERENCES content.content_item(id) ON DELETE CASCADE,
  comment_id uuid REFERENCES community.comment(id) ON DELETE CASCADE,
  reason varchar(100) NOT NULL,
  details text,
  status varchar(30) NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'reviewing', 'resolved', 'rejected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (content_item_id IS NOT NULL OR comment_id IS NOT NULL)
);

CREATE TABLE community.moderation_case (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id uuid REFERENCES community.report(id) ON DELETE SET NULL,
  moderator_user_id uuid,
  action varchar(100),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE notification.preference (
  user_id uuid PRIMARY KEY,
  email_enabled boolean NOT NULL DEFAULT true,
  push_enabled boolean NOT NULL DEFAULT true,
  marketing_enabled boolean NOT NULL DEFAULT false,
  quiet_hours jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE notification.delivery (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  channel varchar(30) NOT NULL CHECK (channel IN ('email', 'push', 'in_app')),
  template_code varchar(120) NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  status varchar(30) NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'sent', 'failed', 'cancelled')),
  scheduled_at timestamptz,
  sent_at timestamptz,
  error_message text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX notification_delivery_user_idx ON notification.delivery (user_id, created_at DESC);

CREATE TABLE billing.plan (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(100) NOT NULL UNIQUE,
  name varchar(200) NOT NULL,
  provider varchar(80),
  provider_price_id varchar(200),
  currency varchar(3),
  amount_minor bigint CHECK (amount_minor IS NULL OR amount_minor >= 0),
  interval varchar(30),
  active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE billing.subscription (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  plan_id uuid NOT NULL REFERENCES billing.plan(id) ON DELETE RESTRICT,
  provider varchar(80),
  provider_subscription_id varchar(200),
  status varchar(40) NOT NULL,
  starts_at timestamptz,
  ends_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX subscription_provider_uidx ON billing.subscription (provider, provider_subscription_id) WHERE provider_subscription_id IS NOT NULL;
CREATE INDEX subscription_user_idx ON billing.subscription (user_id, status);

CREATE TABLE billing.entitlement (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  feature_code varchar(120) NOT NULL,
  source_subscription_id uuid REFERENCES billing.subscription(id) ON DELETE SET NULL,
  starts_at timestamptz,
  ends_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (user_id, feature_code, source_subscription_id)
);

