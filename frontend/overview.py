import streamlit as st
import altair as alt
import pandas as pd


def render_overview(run_query_df, tables, filters_clause: str, temp_clause: str) -> None:
    st.title("📊 Overview")
    st.caption("Insights powered by BigQuery")

    table_dim_breeds = tables["dim_breeds"]
    table_dim_temperament = tables["dim_temperament"]

    col1, col2 = st.columns(2)

    with col1:
        st.subheader("Breeds with the longest predicted lifespan")
        long_life_df: pd.DataFrame = run_query_df(
            f"""
            select b.breed_name, b.avg_life_span_years
            from {table_dim_breeds} b
            where {filters_clause} and b.avg_life_span_years is not null
            order by b.avg_life_span_years desc, b.breed_name
            limit 10
            """
        )
        if long_life_df.empty:
            st.info("No data for current filters.")
        else:
            chart = (
                alt.Chart(long_life_df)
                .mark_bar()
                .encode(
                    x=alt.X("avg_life_span_years:Q", title="Avg lifespan (years)"),
                    y=alt.Y("breed_name:N", sort="-x", title="Breed"),
                    tooltip=["breed_name", alt.Tooltip("avg_life_span_years", format=".1f")],
                )
                .properties(height=420)
            )
            st.altair_chart(chart, use_container_width=True)

    with col2:
        st.subheader("Distribution by size category")
        weight_class_df: pd.DataFrame = run_query_df(
            f"""
            select b.size_category, count(*) as breed_count
            from {table_dim_breeds} b
            where {filters_clause}
            group by b.size_category
            order by breed_count desc
            """
        )
        if weight_class_df.empty:
            st.info("No data for current filters.")
        else:
            chart = (
                alt.Chart(weight_class_df)
                .mark_bar()
                .encode(
                    x=alt.X("size_category:N", title="Size category"),
                    y=alt.Y("breed_count:Q", title="# of breeds"),
                    tooltip=["size_category", "breed_count"],
                )
                .properties(height=420)
            )
            st.altair_chart(chart, use_container_width=True)

    st.divider()

    st.subheader("Top temperaments among family-friendly breeds")
    temperaments_df: pd.DataFrame = run_query_df(
        f"""
        with base as (
            select b.breed_id
            from {table_dim_breeds} b
            where {filters_clause}
        ), traits as (
            select tt.breed_id, trait
            from {table_dim_temperament} tt
            join base using (breed_id),
            unnest(tt.trait_array) as trait
            where tt.total_traits > 0 {temp_clause.replace('t.', 'tt.')}
        )
        select lower(trim(trait)) as temperament_trait, count(*) as occurrences
        from traits
        group by temperament_trait
        order by occurrences desc
        limit 15
        """
    )
    if temperaments_df.empty:
        st.info("No data for current filters.")
    else:
        chart = (
            alt.Chart(temperaments_df)
            .mark_bar()
            .encode(
                x=alt.X("occurrences:Q", title="# of mentions across breeds"),
                y=alt.Y("temperament_trait:N", sort="-x", title="Temperament trait"),
                tooltip=["temperament_trait", "occurrences"],
            )
            .properties(height=520)
        )
        st.altair_chart(chart, use_container_width=True)


