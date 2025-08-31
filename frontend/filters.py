import streamlit as st
import pandas as pd


def sql_str(val: str) -> str:
    return "'" + str(val).replace("'", "\\'") + "'"


def render_filters(run_query_df, tables) -> dict:
    """Render sidebar filters and return a dict with filter clauses and selections.

    Returns keys:
      - filters_clause: SQL WHERE clause for dim_breeds alias b
      - temp_clause: optional SQL fragment for dim_temperament alias t/tt
      - selections: dict with raw selected values
    """

    table_dim_breeds = tables["dim_breeds"]
    table_dim_temperament = tables["dim_temperament"]

    with st.sidebar:
        st.title("🐕 Dog Explorer")
        st.subheader("Filters")

        breed_groups_df = run_query_df(
            f"""
            select distinct breed_group
            from {table_dim_breeds}
            where breed_group is not null and breed_group != ''
            order by breed_group
            """
        )
        size_categories_df = run_query_df(
            f"""
            select distinct size_category
            from {table_dim_breeds}
            where size_category is not null and size_category != ''
            order by size_category
            """
        )
        family_suitability_df = run_query_df(
            f"""
            select distinct family_suitability
            from {table_dim_temperament}
            where family_suitability is not null and family_suitability != ''
            order by family_suitability
            """
        )

        breed_groups = st.multiselect(
            "Breed group",
            options=breed_groups_df["breed_group"].tolist(),
        )
        size_categories = st.multiselect(
            "Size category",
            options=size_categories_df["size_category"].tolist(),
        )
        family_suitability = st.multiselect(
            "Family suitability",
            options=family_suitability_df["family_suitability"].tolist(),
        )

        # Weight filter (metric)
        weight_stats = run_query_df(
            f"""
            select min(avg_weight_kg) as min_w, max(avg_weight_kg) as max_w
            from {table_dim_breeds}
            where avg_weight_kg is not null
            """
        )
        if weight_stats.empty:
            min_w, max_w = 0.0, 100.0
        else:
            min_raw = weight_stats.iloc[0]["min_w"]
            max_raw = weight_stats.iloc[0]["max_w"]
            min_w = float(min_raw) if pd.notna(min_raw) else 0.0
            max_w = float(max_raw) if pd.notna(max_raw) else 100.0
        if not (isinstance(min_w, (int, float)) and isinstance(max_w, (int, float))):
            min_w, max_w = 0.0, 100.0
        if min_w > max_w:
            min_w, max_w = max_w, min_w
        if min_w == max_w:
            min_w = max(0.0, min_w - 1.0)
            max_w = max_w + 1.0
        slider_max = max(max_w, 1.0)
        weight_range = st.slider("Avg weight (kg)", min_value=0.0, max_value=slider_max, value=(min_w, max_w))

    # Build clauses
    clauses = []
    if breed_groups:
        vals = ",".join([sql_str(v) for v in breed_groups])
        clauses.append(f"b.breed_group in ({vals})")
    if size_categories:
        vals = ",".join([sql_str(v) for v in size_categories])
        clauses.append(f"b.size_category in ({vals})")
    clauses.append(f"b.avg_weight_kg between {weight_range[0]} and {weight_range[1]}")
    filters_clause = (" and ".join(clauses)) if clauses else "1=1"

    temp_clause = ""
    if family_suitability:
        vals = ",".join([sql_str(v) for v in family_suitability])
        temp_clause = f"and tt.family_suitability in ({vals})"

    return {
        "filters_clause": filters_clause,
        "temp_clause": temp_clause,
        "selections": {
            "breed_groups": breed_groups,
            "size_categories": size_categories,
            "family_suitability": family_suitability,
            "weight_range": weight_range,
        },
    }


