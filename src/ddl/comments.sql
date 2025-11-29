CREATE TABLE `bigquery-public-data.stackoverflow.comments`
(
  id INT64,
  text STRING,
  creation_date TIMESTAMP,
  post_id INT64,
  user_id INT64,
  user_display_name STRING,
  score INT64
);

