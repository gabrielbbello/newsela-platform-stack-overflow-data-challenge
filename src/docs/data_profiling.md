# Data Profiling & Discovery Report

**Target Dataset:** `bigquery-public-data.stackoverflow`
**Audit Date:** November 2025
**Engineering Verdict:** The dataset is **deprecated** (stale since late 2022).

## 1. Volumetrics & Storage Analysis

| Table Name | Row Count | Column Count | Logical Size (Query Cost) | Physical Size (Storage) | Partition
| :--- | ---: | ---: | ---: | ---: | ---:
| badges | 46,135,386 | 6 | 1.96 GB | 553.17 MB | False |
| comments | 86,754,111 | 7 | 16.03 GB | 6.63 GB | False |
| post_history | 152,435,941 | 8 | 113.18 GB | 32.85 GB | False |
| post_links | 8,395,210 | 5 | 320.25 MB | 134.43 MB | False |
| posts_answers | 34,024,119 | 20 | 28.62 GB | 10.22 GB | False |
| posts_moderator_nomination | 342 | 20 | 470.06 KB | 174.19 KB | False |
| posts_orphaned_tag_wiki | 167 | 20 | 52.09 KB | 23 KB | False |
| posts_privilege_wiki | 2 | 20 | 3.41 KB | 5.51 KB | False |
| posts_questions | 23,020,127 | 20 | 37.17 GB | 12.46 GB | False |
| posts_tag_wiki | 55,113 | 20 | 35.96 MB | 11.79 MB | False |
| posts_tag_wiki_excerpt | 55,115 | 20 | 10.91 MB | 4.25 MB | False |
| posts_wiki_placeholder | 5 | 20 | 5.05 KB | 5.7 KB | False |
| stackoverflow_posts (Deprecated) | 31,017,889 | 19 | 29.36 GB | 10.67 GB | False |
| tags | 63,653 | 5 | 2.48 MB | 978.79 KB | False |
| users | 18,712,212 | 13 | 3.14 GB | 1.12 GB | False |
| votes | 236,452,885 | 4 | 7.05 GB | 1.77 GB | False |

## 2. Data Quality Audit (2022 Scope)

To ensure analytical reliability for the "Current Year" analysis, a dive into the 6 Data Quality Dimensions was conducted specifically on the core `posts_questions` table.

**Audit Query Results:**

| Dimension | Metric | Value | Insight |
| :--- | :--- | :--- | :--- |
| **Volume** | Total Rows | **1,268,788** | Significant sample size for annual analysis. |
| **Completeness** | Tags Fill Rate | **100%** | No cleaning required for null tags. |
| **Completeness** | Accepted Rate | **30.48%** | Only ~30% of questions get a definitive solution. |
| **Uniqueness** | User Cardinality | **631k** | Avg ~2 questions per user. |
| **Integrity** | Logic Violations | **0** | No questions with 0 answers marked as Accepted. |
| **Validity** | Negative Score | **8.32%** | Quality control mechanism is active but not dominant. |
| **Timeliness** | Data Cutoff | **2022-09-25** | Data ends in late Sept, not Nov. Q4 2022 is missing. |

1.  **No Partitioning:**
    * `INFORMATION_SCHEMA.PARTITIONS` returned `NULL` for partition keys on all major tables.
    * **Impact:** Some cost optimization strategies rely on **Column Pruning** (SELECT specific cols) and **Predicate Pushdown** (filtering `creation_date` early).

2.  **High Cardinality in Tags:**
    * Tags are stored as pipe-separated strings (e.g., `python|pandas`).
    * **Impact:** Requires `UNNEST(SPLIT(...))` strategies rather than simple `LIKE` operators for accurate aggregation.