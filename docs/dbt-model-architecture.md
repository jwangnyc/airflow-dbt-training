# The dbt Model Architecure

Organizing dbt models into Staging, Intermediate, and Marts layers is a widely adopted best practice for structuring data transformations. This layered approach provides clear separation of concerns, promotes reusability, and enhances maintainability, guiding data from raw sources to consumption-ready formats.

## 1. Why We Use Three Layers:

The primary motivation is to create a clear, logical flow for data transformation, isolating complexity at each stage:

* **Staging Layer (Raw/Source-aligned Data):**
    * **Purpose:** Perform initial, lightweight transformations on raw source data to bring it into a consistent and usable format. It's a direct, cleaned representation of your source systems.
    * **Key Transformations:** Casting data types, renaming columns for consistency, basic null handling, adding source metadata, light deduplication.
    * **Materialization Strategy:** `view` or `ephemeral`. This saves storage, ensures data freshness, and allows for rapid iteration as these models are generally simple select statements. Use `table` only if extremely complex, costly operations are required at this stage.

* **Intermediate Layer (Core Business Logic/Shared Transformations):**
    * **Purpose:** Contains complex business logic, aggregations, joins, and derivations that are shared across multiple downstream data products. This is where the "hard work" of transforming raw data into meaningful business entities happens.
    * **Key Transformations:** Complex joins across multiple staging tables, applying business rules, building foundational components that are not yet analytical `dim` or `fct` tables but are critical building blocks (e.g., `int_customer_attributes` which might then feed `dim_customers`), temporal logic, consolidating data from multiple sources.
    * **Materialization Strategy:** `table` or `incremental`. These models often involve expensive computations, so materializing them stores the results for efficient querying by downstream models. `incremental` is crucial for large, growing datasets to optimize build times.

* **Marts Layer (Consumption-Ready Data/Specific Use Cases):**
    * **Purpose:** Optimized for specific analytical use cases, reporting, and business intelligence (BI) tools. Models here are typically highly aggregated, denormalized, and user-friendly, tailored for direct consumption by business users.
    * **Key Transformations:** Final aggregations for dashboards, joining intermediate models to create user-specific views, simplifying column names, filtering data for particular audiences.
    * **Materialization Strategy:** `table` or `incremental`. Optimal query performance is key here, so pre-computing results is standard. `incremental` is used for large, continuously growing marts. `view` is generally discouraged unless the mart is very small or needs real-time reflection of changes from already optimized intermediate tables.

## 2. Where do `dim` (Dimension) and `fct` (Fact) Tables Reside?

The best practice is that **`dim` (dimension) and `fct` (fact) tables are built in the **Marts layer**.

* **Rationale:**
    * **Consumption Focus:** `dim` and `fct` tables are the foundational elements of dimensional modeling (star/snowflake schemas), which is specifically designed for analytical consumption by BI tools and end-users. They provide the "who, what, where, when" (dimensions) and "measurements" (facts) that analysts directly query.
    * **Stability and Readability:** By the time data forms a `dim` or `fct` table, it should be clean, validated, and aligned with core business definitions. They represent stable, intuitive interfaces for business users.
    * **Performance Optimization:** `dim` and `fct` tables are almost always materialized as `table` or `incremental`. This pre-computes complex joins and aggregations, ensuring fast query performance for BI tools and end-users, aligning perfectly with the Marts layer's materialization strategy.

* **The Intermediate Layer's Supporting Role:**
    * While `dim` and `fct` tables are in the Marts layer, the **Intermediate layer is crucial for preparing the complex data that feeds into them.** This is where you'd perform:
        * Complex joins across multiple staging tables (e.g., to build a comprehensive customer profile).
        * Advanced deduplication and conflict resolution logic.
        * Calculations of derived metrics or flags.
        * Handling slowly changing dimensions (SCDs) for future dimensions.
    * For example, you might create an `int_customer_360` model in the intermediate layer that combines and cleans data from various sources. This intermediate model then becomes the source for your final `dim_customers` table in the Marts layer. This promotes modularity and prevents duplicating complex logic across different marts.

## 3. Pros and Cons for Assigning Schema to Each Layer vs. One Schema:

This decision significantly impacts organization, security, and maintenance.

**Option A: Assigning Each Layer to a Separate Schema (e.g., `raw`, `intermediate`, `marts`)**

* **Pros:**
    * **Clear Separation and Organization:** Immediately identifies the purpose and lineage of a table/view by its schema.
    * **Improved Security & Permissions:** Enables granular access control. BI tools might only have read access to `marts`, while engineers have broader access.
    * **Easier Maintenance:** Simplifies managing and rebuilding specific layers without impacting others.
    * **Reduced Naming Conflicts:** Less chance of name collisions between similar entities in different layers.
    * **Enforced Layering:** Structurally encourages adherence to the layered architecture.
* **Cons:**
    * **More Verbose SQL/References:** Requires explicit schema prefixes (though dbt's `ref()` function handles this well).
    * **Potential for "Schema Sprawl":** Requires careful management if too many schemas are created.
    * **DBA Overhead:** May require more initial setup or configuration.

**Option B: Keeping All Layers in One Schema (e.g., `dbt_models`)**

* **Pros:**
    * **Simpler SQL/References:** No need for schema prefixes for direct querying.
    * **Simpler Initial Setup:** Less database configuration.
* **Cons:**
    * **Lack of Clear Separation:** Hard to discern a table's purpose or lineage at a glance.
    * **Poor Security & Permissions:** Difficult to grant granular access without exposing unrelated data.
    * **Maintenance Challenges:** Harder to identify and target specific tables for rebuilds or updates.
    * **Increased Naming Conflicts:** Requires strict naming conventions (e.g., `stg_`, `int_`, `fct_` prefixes) to avoid collisions.
    * **No Enforcement of Layering:** Easier for users to bypass the intended structure.

**Recommendation:** In most scenarios, **assigning each layer to a separate schema is strongly recommended.** The benefits in terms of organization, security, and maintainability far outweigh the minor overhead. dbt's configuration options (e.g., `{{ config(schema='my_schema') }}`) and `ref()` function make this seamless in your dbt code.

