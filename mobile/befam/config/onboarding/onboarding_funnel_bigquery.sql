-- Replace `your_project.analytics_XXXXXXXXX.events_*` with the Firebase export table.
-- This query summarizes onboarding flow starts, completions, skips, and drop-off steps.

WITH onboarding_events AS (
  SELECT
    event_date,
    user_pseudo_id,
    event_name,
    (
      SELECT ep.value.string_value
      FROM UNNEST(event_params) ep
      WHERE ep.key = 'flow_id'
    ) AS flow_id,
    (
      SELECT COALESCE(ep.value.int_value, CAST(ep.value.string_value AS INT64))
      FROM UNNEST(event_params) ep
      WHERE ep.key = 'flow_version'
    ) AS flow_version,
    (
      SELECT ep.value.string_value
      FROM UNNEST(event_params) ep
      WHERE ep.key = 'step_id'
    ) AS step_id,
    (
      SELECT COALESCE(ep.value.int_value, CAST(ep.value.string_value AS INT64))
      FROM UNNEST(event_params) ep
      WHERE ep.key = 'step_index'
    ) AS step_index,
    (
      SELECT ep.value.string_value
      FROM UNNEST(event_params) ep
      WHERE ep.key = 'route_id'
    ) AS route_id
  FROM `your_project.analytics_XXXXXXXXX.events_*`
  WHERE event_name IN (
    'onboarding_started',
    'onboarding_step_viewed',
    'onboarding_completed',
    'onboarding_skipped',
    'onboarding_interrupted',
    'onboarding_anchor_missing'
  )
),
flow_level AS (
  SELECT
    flow_id,
    flow_version,
    COUNTIF(event_name = 'onboarding_started') AS starts,
    COUNTIF(event_name = 'onboarding_completed') AS completions,
    COUNTIF(event_name = 'onboarding_skipped') AS skips,
    COUNTIF(event_name = 'onboarding_interrupted') AS interruptions,
    COUNTIF(event_name = 'onboarding_anchor_missing') AS anchor_missing
  FROM onboarding_events
  GROUP BY flow_id, flow_version
),
step_level AS (
  SELECT
    flow_id,
    flow_version,
    step_id,
    step_index,
    COUNTIF(event_name = 'onboarding_step_viewed') AS step_views,
    COUNTIF(event_name = 'onboarding_skipped') AS step_skips,
    COUNTIF(event_name = 'onboarding_anchor_missing') AS step_anchor_missing
  FROM onboarding_events
  GROUP BY flow_id, flow_version, step_id, step_index
)
SELECT
  f.flow_id,
  f.flow_version,
  f.starts,
  f.completions,
  f.skips,
  f.interruptions,
  f.anchor_missing,
  SAFE_DIVIDE(f.completions, NULLIF(f.starts, 0)) AS completion_rate,
  s.step_id,
  s.step_index,
  s.step_views,
  s.step_skips,
  s.step_anchor_missing
FROM flow_level f
LEFT JOIN step_level s
  ON f.flow_id = s.flow_id
 AND f.flow_version = s.flow_version
ORDER BY f.flow_id, s.step_index;
