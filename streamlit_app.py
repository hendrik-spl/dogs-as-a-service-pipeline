import streamlit as st
import pandas as pd
from google.oauth2 import service_account
from google.cloud import bigquery
from frontend.overview import render_overview
from frontend.finder import render_finder
from frontend.filters import render_filters

st.set_page_config(page_title="Dogs as a Service - Explorer", page_icon="🐶", layout="wide")

# Create API client.
credentials = service_account.Credentials.from_service_account_info(
    st.secrets["gcp_service_account"]
)
client = bigquery.Client(credentials=credentials)

# Dataset/table constants
PROJECT_DATASET = "dog-breed-explorer-470208.dog_explorer"
TABLE_FCT = f"`{PROJECT_DATASET}.fct_breed_metrics`"
TABLE_DIM_BREEDS = f"`{PROJECT_DATASET}.dim_breeds`"
TABLE_DIM_TEMPERAMENT = f"`{PROJECT_DATASET}.dim_temperament`"


# Cached query helper
@st.cache_data(ttl=600)
def run_query_df(query: str) -> pd.DataFrame:
    query_job = client.query(query)
    return query_job.to_dataframe()


filters = render_filters(
    run_query_df,
    {"dim_breeds": TABLE_DIM_BREEDS, "dim_temperament": TABLE_DIM_TEMPERAMENT},
)
filters_clause = filters["filters_clause"]
temp_clause = filters["temp_clause"]


tab_overview, tab_finder = st.tabs(["Overview", "Find Your Own Dog"])

with tab_overview:
    render_overview(
        run_query_df,
        {"dim_breeds": TABLE_DIM_BREEDS, "dim_temperament": TABLE_DIM_TEMPERAMENT},
        filters_clause,
        temp_clause,
    )

with tab_finder:
    render_finder(
        run_query_df,
        {"dim_breeds": TABLE_DIM_BREEDS, "dim_temperament": TABLE_DIM_TEMPERAMENT},
        filters_clause,
        temp_clause,
    )
