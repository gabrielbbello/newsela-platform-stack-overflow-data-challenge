CREATE TABLE `bigquery-public-data.stackoverflow.post_history`
(
  id INT64,
  creation_date TIMESTAMP,
  post_id INT64,
  post_history_type_id INT64,
  revision_guid STRING,
  user_id INT64,
  text STRING,
  comment STRING
);

