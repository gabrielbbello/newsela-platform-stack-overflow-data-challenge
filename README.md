# newsela-platform-stack-overflow-data-challenge

## Table of Contents

- [1. Infrastructure and architecture](#1-infrastructure-and-architecture)
    - [1.1 Repository structure](#11-repository-structure)
    - [1.2 Design decisions and governance](#12-design-decisions-and-governance)
    - [1.3 Development flow (developer experience)](#13-development-flow-developer-experience)
- [2. Feature analysis: solution details](#2-feature-analysis-solution-details)
    - [2.1 Prompt 1: performance and tag ranking](#21-prompt-1-performance-and-tag-ranking)
        - [2.1.1 Top individual tags (top performers)](#211-top-individual-tags-top-performers)
        - [2.1.2 Lowest performing tags (bottlenecks)](#212-lowest-performing-tags-bottlenecks)
        - [2.1.3 Impact of tag combinations](#213-impact-of-tag-combinations)
    - [2.2 Prompt 2: Temporal trends and tech comparison (Python vs dbt)](#22-prompt-2-temporal-trends-and-tech-comparison-python-vs-dbt)
        - [2.2.1 Growth and saturation (volume & ratio YoY)](#221-growth-and-saturation-volume--ratio-yoy)
        - [2.2.2 Quality evolution (success rate YoY)](#222-quality-evolution-success-rate-yoy)
        - [2.2.3 Direct comparison (Head-to-Head 2020-2022)](#223-direct-comparison-head-to-head-2020-2022)
    - [2.3 Prompt 3: Success factors and behavior (beyond tags)](#23-prompt-3-success-factors-and-behavior-beyond-tags)
        - [2.3.1 Content attributes and curation](#231-content-attributes-and-curation)
        - [2.3.2 Weekly seasonality (weekend paradox)](#232-weekly-seasonality-weekend-paradox)
        - [2.3.3 Response latency (first hour importance)](#233-response-latency-first-hour-importance)
- [3. Engineering best practices for production](#3-engineering-best-practices-for-production)

# 1. Infrastructure and architecture

This project was architected following **Platform Engineering** principles, prioritizing component modularity, code governance (Linting), and explicit data contracts.

## 1.1 Repository structure

The directory organization clearly separates physical definitions (DDL), logical contracts (Schemas), and analytical execution (SQL), facilitating navigation and code review.

```text
.
├── Dockerfile
├── Makefile
├── README.md
├── requirements.txt
└── src
    ├── ddl                
    │   ├── badges.sql
    │   ├── comments.sql
    │   ├── post_history.sql
    │   ├── post_links.sql
    │   ├── posts_answers.sql
    │   ├── posts_moderator_nomination.sql
    │   ├── posts_orphaned_tag_wiki.sql
    │   ├── posts_privilege_wiki.sql
    │   ├── posts_questions.sql
    │   ├── posts_tag_wiki_excerpt.sql
    │   ├── posts_tag_wiki.sql
    │   ├── posts_wiki_placeholder.sql
    │   ├── stackoverflow_posts.sql
    │   ├── tags.sql
    │   ├── users.sql
    │   └── votes.sql
    ├── docs
    │   └── data_profiling.md
    ├── queries
    │   ├── 1a_tags_rank_by_acceptance_desc.sql
    │   ├── 1b_tags_rank_by_acceptance_asc.sql
    │   ├── 1c_tags_cardinality_comparative.sql
    │   ├── 2a_python_dbt_time_series_volume_ratio_yoy.sql
    │   ├── 2b_python_dbt_time_series_acceptance_rate_yoy.sql
    │   ├── 2c_python_dbt_comparative_cohort_analysis.sql
    │   ├── 3a_feature_correlation_content_attributes.sql
    │   ├── 3b_temporal_distribution_day_of_week.sql
    │   └── 3c_latency_time_to_first_answer.sql
    └── schemas
        └── stackoverflow.yml
```

### 1.2 Design decisions and governance

The architecture was guided by three fundamental pillars to ensure scalability and solution integrity:

| Pillar | Component | Technical Decision & Justification |
| :--- | :--- | :--- |
| **Code Governance** | **CI/CD Tooling** | Implementation of **Docker** and **Makefile** to ensure reproducibility. The linter (`sqlfluff`) runs in a container, eliminating local dependency issues and standardizing SQL style (Upper Keywords, Lower Identifiers). |
| **Data Contracts** | **`src/schemas/`** | Adoption of YAML files to explicitly define data types and expectations (primary key tests), acting as a lightweight **Schema Registry** and living documentation. |
| **FinOps** | **Query Design** | Based on *Data Profiling* (`docs/`), the lack of partitioning was identified. Queries use aggressive **Predicate Pushdown** on the `creation_date` column and **Column Pruning** to minimize *bytes processed* costs in BigQuery. |
| **Auditability** | **`src/ddl/`** | Versioning of raw DDLs (`CREATE TABLE`) to ensure a historical snapshot of the source infrastructure, facilitating future migrations or local environment recreation. |

## 1.3 Development flow (developer experience)

To ensure agility and standardization, the project exposes a simplified command interface via Makefile:

* `make docker-lint`: Executes static code analysis in an isolated environment.
* `make docker-fix`: Applies automatic style corrections to SQL queries.
* `make clean_venv`: Ensures cleaning of local artifacts.

# 2. Feature analysis: solution details

This section details how each challenge prompt was addressed, highlighting engineering decisions (performance/cost) and extracted business insights.

## 2.1 Prompt 1: performance and tag ranking

> "What tags on a Stack Overflow question lead to the most answers and the highest rate of approved answers for the current year? What tags lead to the least? How about combinations of tags?"

To answer this multifaceted question, the analysis was decomposed into three distinct vectors (**Best**, **Worst**, and **Combinations**) to avoid mixing different statistical populations.

### 2.1.1 Top individual tags (top performers)
- **File:** `src/sql/1a_tags_rank_by_acceptance_desc.sql`

**Technical Approach:**
* **Optimized Parsing:** Utilization of `CROSS JOIN UNNEST(SPLIT(tags, '|'))` instead of Regex operations, ensuring lower CPU consumption (*slot time*).
* **FinOps (Predicate Pushdown):** Strict filter `EXTRACT(YEAR) = 2022` applied in the first CTE (`daily_questions`) to ensure *unnesting* occurs only on the subset of interest, reducing processed bytes.
* **Robust Statistics (P90):** Application of a `HAVING question_volume >= 75` filter. Distribution analyses (*Approx Quantiles*) showed this value corresponds to the **90th Percentile**, ensuring the ranking displays consolidated trends rather than fluctuations from small samples.

**Analytical Insights:**
* **Niche Focus:** The ranking top is not dominated by popular languages, but by specific tools. `Google Query Language` (90% acceptance) and `jq` (75%) show that smaller, focused communities are more efficient.
* **Atomic Functions:** Tags describing a specific action (`flatten`, `textjoin`) perform better than ecosystem tags (`android`, `ios`), suggesting well-defined "How-to" questions are more solvable than architectural questions.

### 2.1.2 Lowest performing tags (bottlenecks)
- **File:** `src/sql/1b_tags_rank_by_acceptance_asc.sql`

**Technical Approach:**
* **Reuse:** Utilization of the CTE architecture from query 1.1 for consistency (*Conceptual DRY*).
* **Maintenance of P90 filter (>= 75):** To ensure "worst tags" represent real systemic community issues, not just isolated poor-quality questions.

**Analytical Insights:**
* **Proprietary APIs:** Tags like `linkedin-api` (5.8%), `amz-sp-api`, and `onelogin` lead the failure rate. Support depends on external documentation and closed environments, making error reproduction by third parties difficult.
* **Infrastructure Challenges:** `remote-desktop` has the worst absolute rate (2.3%). Network/physical environment issues lack logs and context, making remote resolution nearly impossible.
* **CMS Complexity:** Complex platforms like `magento` and `joomla` appear with very low resolution (<7%), indicating high debugging complexity.

### 2.1.3 Impact of tag combinations
- **File:** `src/sql/1c_tags_cardinality_comparative.sql`

**Technical Approach:**
* **Cardinality Analysis:** Use of `ARRAY_LENGTH(SPLIT(tags))` to filter only posts with multiple tags.
* **Statistical Adjustment (Stability):** Unlike individual tags, the combination P99 is very low (13). To avoid volatility, a **Stability Threshold (N=20)** was applied. This sacrifices the long tail to ensure *Top Performers* are repeatable patterns.

**Analytical Insights:**
* **Specificity Impact:** Compound tags have a significantly higher average success rate. The Top 1 (`r|regex|stringr`) reaches **92% acceptance**.
* **Context Importance:** The combination `python|pandas|dataframe` (87.5%) proves that adding context (Language + Lib + Object) transforms a generic Python question (noise) into a tractable problem.
* **High Cohesion in R:** The R ecosystem is highly present in the combination ranking, suggesting an academic community that is highly collaborative on data manipulation problems (`dplyr`, `tidyr`).

## 2.2 Prompt 2: Temporal trends and tech comparison (Python vs dbt)

> "For posts which are tagged with only ‘python’ or ‘dbt’, what is the year over year change of question-to-answer ratio for the last 10 years? How about the rate of approved answers on questions for the same time period? How do posts tagged with only ‘python’ compare to posts only tagged with ‘dbt’?"

The analysis was divided into three components: **Volume Growth (YoY)**, **Success Rate Evolution (YoY)**, and **Cohort Comparison (Head-to-Head)**.

### 2.2.1 Growth and saturation (volume & ratio YoY)
- **File:** `src/sql/2a_python_dbt_time_series_volume_ratio_yoy.sql`

**Technical Approach:**
* **Exclusivity Filter:** Utilization of the clause `WHERE tags IN ('python', 'dbt')` to isolate pure posts.
* **Engineering Note:** This filter excludes ~75% of total `dbt` volume (often appearing as `dbt|sql`) but ensures strict adherence to the prompt's *"tagged with only"* restriction.
* **Window Functions:** Use of `LAG(metric) OVER(PARTITION BY tag ORDER BY year)` to calculate the year-over-year percentage delta in a single pass (*single scan*).

**Analytical Insights:**
* **Platform Fatigue:** The Python community shows clear signs of saturation. The *Answer Ratio* dropped from **2.63 (2012)** to **1.26 (2022)** — a 50% degradation in community responsiveness.
* **dbt Growth:** The volume of questions regarding `dbt` doubled consistently year over year (31 → 58 → 79), validating it as a technology in a *breakout* phase, though still niche compared to Python.

### 2.2.2 Quality evolution (success rate YoY)
- **File:** `src/sql/2b_python_dbt_time_series_acceptance_rate_yoy.sql`

**Technical Approach:**
* **Normalized Metric:** Focus on `accepted_rate` (Accepted / Total) rather than absolute count, allowing fair comparison between technologies of different scales (Thousands vs Tens).
* **Null Handling:** Use of `SAFE_DIVIDE` to avoid division-by-zero errors in early `dbt` years (2019-2020).

**Analytical Insights:**
* **Python Adoption Factors:** Python's success rate dropped from **72% (2012)** to **35% (2022)**. The massive influx of beginners (Bootcamps/Data Science) likely diluted average question quality, hindering resolution.
* **Initial Instability:** `dbt` presented high initial volatility (drop from 41% to 25% in 2021), typical of technologies where adoption grows faster than expert training (*Skill Gap*).

### 2.2.3 Direct comparison (Head-to-Head 2020-2022)
- **File:** `src/sql/2c_python_dbt_comparative_cohort_analysis.sql`

**Technical Approach:**
* **Comparison Window:** Restriction of analysis to the **2020-2022** period, where both technologies actively coexisted, avoiding historical distortions.
* **Sentiment Metrics:** Inclusion of `avg_score` (Perceived Quality) and `avg_views` (Passive Reach) to qualify volume.

**Analytical Insights:**
* **Quality Challenges:** Python has a **Negative Average Score (-0.15)**. The community actively *downvotes* new content, indicating a noisy environment for beginners.
* **The dbt Paradox:** `dbt` has high perceived quality (Score **+1.29**) but low resolution (29%).
* **Diagnosis:** Data Engineering problems (architecture, warehouse) are inherently complex and difficult to reproduce, generating the **Lurker Phenomenon**: many view (1097 views/question) to learn, but few have the seniority to respond.

## 2.3 Prompt 3: Success factors and behavior (beyond tags)

> "Other than tags, what qualities on a post correlate with the highest rate of answer and approved answer? Feel free to get creative."

The analysis sought to identify correlations between behavioral metadata and success rates, testing four main hypotheses: **Verbosity**, **Curation**, **Weekly Seasonality**, and **Response Latency**.

### 2.3.1 Content attributes and curation
- **File:** `src/sql/3a_feature_correlation_content_attributes.sql`

**Technical Approach:**
* **Feature Engineering:** Creation of *buckets* to normalize continuous distributions (`LENGTH(body)` and `score`).
* **Optimized Join:** Pre-aggregation of the massive `post_history` table (152M rows) in a lightweight CTE before joining with `questions`, avoiding cardinality explosion.

**Analytical Insights:**
* **Curation Impact (Top Factor):** Questions that were actively edited (>2 times) have a success rate of **37.9%**, versus **27.6%** for originals.
* **Conclusion:** Post maintenance ("Gardening") is the single largest predictor of success. 55% of users abandon the post without editing ("Fire and Forget"), generating platform noise.
* **Ideal Length:** There is an optimal size. Medium questions (500-1500 characters) perform best (**~32%**). Very short questions (<500) fail due to lack of context (23%).

### 2.3.2 Weekly seasonality (weekend paradox)
- **File:** `src/sql/3b_temporal_distribution_day_of_week.sql`

**Technical Approach:**
* **Time Intelligence:** Use of `EXTRACT(DAYOFWEEK)` to segment traffic between "Business Days" and "Weekends".

**Analytical Insights:**
* **The Weekend Paradox:** Although question volume drops by half on the weekend, the **Acceptance Rate rises to 32.3%** (vs 30.1% during the week).
* **Interpretation:** During the week, volume is inflated by urgent, poorly formulated queries ("Panic Driven Development"). On the weekend, traffic is lower but composed of enthusiasts and students with more time to formulate and respond with quality.

### 2.3.3 Response latency (first hour importance)
- **File:** `src/sql/3c_latency_time_to_first_answer.sql`

**Technical Approach:**
* **Latency Calculation:** Use of `TIMESTAMP_DIFF` between question creation and the *first* answer (identified via Window Function `RANK()`).
* **Time Bucketing:** Segmentation into critical windows (<15min, 1h, 24h).

**Analytical Insights:**
* **Value Decay:** The probability of success drops linearly with wait time.
    * Answer in **< 15 min**: 56.4% acceptance.
    * Answer in **> 24 hours**: 37.5% acceptance.
* **Operational Efficiency:** Stack Overflow's architecture is optimized for *Near Real-Time*. The first hour concentrates the majority of successful resolutions. For education platforms (Newsela), this indicates feedback SLA should be measured in minutes, not days.

---

### Note on Generative AI impact
It is important to note that with the advent of Generative AI tools (e.g., ChatGPT, Copilot), direct traffic to Stack Overflow has decreased substantially. This behavioral shift may have negatively impacted both the volume of new questions and the resolution rates in the most recent data cohorts, as users increasingly solve initial queries via AI before resorting to community support.

---

# 3. Engineering best practices for production

While this solution focuses on optimized analysis for the take-home scope, a production-grade implementation at Newsela would leverage the following architectural evolutions:

* **Architecture Upgrade (dbt & Modeling):**
    Transition from raw SQL scripts to a modular `dbt project`. Implementation of **Incremental Models** to process only new daily data (T-1), reducing BigQuery scan costs by ~99%. Introduction of **Dimensional Modeling (Star Schema)** in the Gold layer to optimize performance for BI tools.

* **Orchestration (Airflow):**
    Implementation of an Airflow DAG to automate the pipeline. Utilization of `Sensors` (`BigQueryTableExistenceSensor`) to detect upstream data arrival and **Circuit Breakers** to prevent processing if source freshness lags significantly.

* **Automated Data Quality:**
    Move from manual profiling to automated enforcement using `Great Expectations` or `dbt tests`. Implementation of checks covering the **6 Dimensions of Data Quality** (e.g., Validity tests for negative scores, Consistency tests for referential integrity between Questions/Answers) directly in the CI/CD pipeline.

* **FinOps & Storage Optimization:**
    Restructuring of target tables with **Partitioning** (by `creation_date`) and **Clustering** (by `tags`). This changes the access pattern from *full-scans* to *pruned-scans*, ensuring scalability as the dataset grows to Petabyte scale.