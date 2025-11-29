CREATE TABLE `bigquery-public-data.stackoverflow.stackoverflow_posts`
(
  id INT64 NOT NULL,
  title STRING,
  body STRING,
  accepted_answer_id INT64,
  answer_count INT64,
  comment_count INT64,
  community_owned_date TIMESTAMP,
  creation_date TIMESTAMP,
  favorite_count INT64,
  last_activity_date TIMESTAMP,
  last_edit_date TIMESTAMP,
  last_editor_display_name STRING,
  last_editor_user_id INT64,
  owner_display_name STRING,
  owner_user_id INT64,
  parent_id INT64,
  post_type_id INT64,
  score INT64,
  tags STRING,
  view_count INT64
)
OPTIONS(
  description="Don't use this table - use posts_* instead"
);

