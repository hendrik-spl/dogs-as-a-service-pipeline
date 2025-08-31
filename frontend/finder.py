import streamlit as st
import pandas as pd
from typing import Dict, List


def _get_system_prompt() -> str:
    return (
        "You are a helpful assistant that helps users choose an appropriate dog breed. "
        "Your knowledge must be strictly grounded in the provided dataset context."
        "Ask clarifying questions to understand the user's lifestyle, home, activity level, family situation, and constraints. "
        "When proposing breeds, explain the reasoning based on the attributes from the dataset (e.g., size, weight, lifespan, group, temperament traits, family suitability). "
        "If the user asks for information not present in the dataset, say you do not know and suggest what related attributes are available but do not call the exact attribute names. Use natural language instead. For example, don't mention temparament_traits but refer to it as temparament"
        "Prefer concise, structured answers with bullet points. End with 1-2 follow-up questions if uncertainty remains."
    )

def _build_context_dataframe(run_query_df, tables: Dict[str, str], filters_clause: str, temp_clause: str) -> pd.DataFrame:
    table_dim_breeds = tables["dim_breeds"]
    table_dim_temperament = tables["dim_temperament"]
    # Join breeds with temperament traits and family suitability; flatten traits as comma-separated list
    query = f"""
        with base as (
            select b.breed_id, b.breed_name, b.breed_group, b.size_category,
                   b.avg_weight_kg, b.avg_life_span_years
            from {table_dim_breeds} b
            where {filters_clause}
        ), temp as (
            select t.breed_id,
                   t.family_suitability,
                   array_to_string(t.trait_array, ', ') as temperament_traits
            from {table_dim_temperament} t
            where 1=1 {temp_clause.replace('tt.', 't.')}
        )
        select b.breed_name,
               coalesce(b.breed_group, '') as breed_group,
               coalesce(b.size_category, '') as size_category,
               b.avg_weight_kg,
               b.avg_life_span_years,
               coalesce(temp.family_suitability, '') as family_suitability,
               coalesce(temp.temperament_traits, '') as temperament_traits
        from base b
        left join temp on temp.breed_id = b.breed_id
        order by b.breed_name
        limit 300
    """
    df: pd.DataFrame = run_query_df(query)
    return df


def _format_context_text(df: pd.DataFrame) -> str:
    if df.empty:
        return "No rows matched the current filters."
    # Keep columns concise and rename for readability
    display_df = df.rename(
        columns={
            "breed_name": "breed",
            "breed_group": "group",
            "size_category": "size",
            "avg_weight_kg": "avg_weight_kg",
            "avg_life_span_years": "avg_lifespan_years",
            "family_suitability": "family_suitability",
            "temperament_traits": "temperament_traits",
        }
    )
    # Convert to a compact markdown-like table string
    head = [
        "Dataset excerpt for grounding (do not hallucinate beyond this):",
        "Columns: breed | group | size | avg_weight_kg | avg_lifespan_years | family_suitability | temperament_traits",
    ]
    # Limit rows included in the prompt for token safety
    max_rows = 80
    clipped = display_df.head(max_rows)
    lines: List[str] = []
    for _, row in clipped.iterrows():
        line = (
            f"- breed: {row['breed']}; group: {row['group']}; size: {row['size']}; "
            f"avg_weight_kg: {row['avg_weight_kg']}; avg_lifespan_years: {row['avg_lifespan_years']}; "
            f"family_suitability: {row['family_suitability']}; temperament_traits: {row['temperament_traits']}"
        )
        lines.append(line)
    if len(display_df) > max_rows:
        lines.append(f"… and {len(display_df) - max_rows} more rows not shown")
    return "\n".join(head + lines)


def _call_openai(messages: List[Dict[str, str]]) -> str:
    try:
        from openai import OpenAI
    except Exception:
        return "OpenAI SDK is not installed. Please add 'openai' to requirements.txt and restart."

    api_key = st.secrets["OPENAI_API_KEY"]
    if not api_key:
        return "OPENAI_API_KEY not found in secrets. Add it to .streamlit/secrets.toml."

    client = OpenAI(api_key=api_key)
    try:
        completion = client.chat.completions.create(
            model="gpt-5-nano",
            messages=messages,
        )
        return completion.choices[0].message.content or ""
    except Exception as e:
        err_str = str(e)
        if "insufficient_quota" in err_str or "You exceeded your current quota" in err_str:
            return "ERROR_INSUFFICIENT_QUOTA: You exceeded your current quota."
        return f"Failed to get response from OpenAI: {e}"


def _stream_openai(messages: List[Dict[str, str]]):
    try:
        from openai import OpenAI
    except Exception as e:
        raise RuntimeError("OpenAI SDK is not installed.") from e

    api_key = st.secrets.get("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY not found in secrets.")

    client = OpenAI(api_key=api_key)
    # Try streaming; fall back to non-stream if server rejects stream
    try:
        response = client.chat.completions.create(
            model="gpt-5-nano",
            messages=messages,
            stream=True,
        )
        for event in response:
            try:
                delta = event.choices[0].delta
                content = getattr(delta, "content", None)
            except Exception:
                content = None
            if content:
                yield content
    except Exception as e:
        err = str(e)
        if "insufficient_quota" in err or "You exceeded your current quota" in err:
            raise RuntimeError("ERROR_INSUFFICIENT_QUOTA") from e
        # Re-raise for upstream handling
        raise


def _heuristic_suggest(context_df: pd.DataFrame, user_text: str) -> str:
    if context_df.empty:
        return "I cannot suggest breeds because the dataset for the current filters is empty."

    text = user_text.lower()

    size_preference = None
    if any(w in text for w in ["toy", "tiny", "small", "apartment"]):
        size_preference = "small"
    elif "medium" in text:
        size_preference = "medium"
    elif any(w in text for w in ["big", "large", "giant"]):
        size_preference = "large"

    activity_terms = ["active", "run", "running", "hike", "hiking", "energetic", "sport", "agile"]
    calm_terms = ["calm", "relaxed", "low energy", "quiet", "easygoing", "laid-back"]
    wants_active = any(w in text for w in activity_terms)
    wants_calm = any(w in text for w in calm_terms)

    family_terms = ["family", "kids", "children", "child"]
    wants_family_friendly = any(w in text for w in family_terms)

    guard_terms = ["guard", "protect", "watchdog", "protective", "alert"]
    wants_guard = any(w in text for w in guard_terms)

    apartment = "apartment" in text

    scored = []
    for _, r in context_df.iterrows():
        score = 0
        size = (r.get("size_category") or "").lower()
        traits = (r.get("temperament_traits") or "").lower()
        fam = (r.get("family_suitability") or "").lower()
        weight = r.get("avg_weight_kg")

        if size_preference:
            if size_preference in size:
                score += 3
        if apartment:
            if size in ("small", "medium"):
                score += 2
            if pd.notna(weight) and weight <= 15:
                score += 2
        if wants_family_friendly:
            if fam in ("high", "medium"):
                score += 3 if fam == "high" else 2
        if wants_active and any(t in traits for t in ["energetic", "active", "athletic"]):
            score += 2
        if wants_calm and any(t in traits for t in ["calm", "gentle", "laid back", "quiet"]):
            score += 2
        if wants_guard and any(t in traits for t in ["protective", "alert", "confident"]):
            score += 2

        # Light bonus for longer lifespan where comparable
        lifespan = r.get("avg_life_span_years")
        if pd.notna(lifespan) and lifespan >= 12:
            score += 1

        scored.append((score, r))

    scored.sort(key=lambda x: (-x[0], str(x[1].get("breed_name"))))
    top = [r for s, r in scored[:5] if s > 0]
    if not top:
        # If nothing scored above 0, just show a few diverse options
        top = [r for _, r in scored[:5]]

    lines: List[str] = [
        "I couldn't use the AI model due to quota limits. Based on your description, here are heuristic suggestions grounded in the dataset:",
    ]
    for r in top:
        lines.append(
            (
                f"- {r.get('breed_name')}: size={r.get('size_category')}, weight≈{r.get('avg_weight_kg')}kg, "
                f"lifespan≈{r.get('avg_life_span_years')}y, family={r.get('family_suitability')}; "
                f"temperament: {r.get('temperament_traits')}"
            )
        )
    lines.append("If you'd like, refine your preferences (home size, time for exercise, shedding tolerance).")
    return "\n".join(lines)


def render_finder(run_query_df, tables: Dict[str, str], filters_clause: str, temp_clause: str) -> None:
    st.title("🔎 Find Your Own Dog")
    # Caption and right-aligned action buttons on the same row
    cap_col, about_col, reset_col = st.columns([6, 1, 1])
    with cap_col:
        st.caption("Chat with an assistant grounded in the current dataset filters.")

    if "dogfinder_messages" not in st.session_state:
        st.session_state["dogfinder_messages"] = []

    # Build dataset context for this turn (used in the popover menu)
    context_df = _build_context_dataframe(run_query_df, tables, filters_clause, temp_clause)

    # Header with a dialog menu
    @st.dialog("About this assistant")
    def _show_menu_dialog() -> None:
        st.markdown(
            "**What this assistant can do**\n\n"
            "- Helps identify suitable dog breeds based on your needs.\n"
            "- Uses only the dataset context shown to it.\n"
            "- Asks clarifying questions and provides reasons for suggestions."
        )
        st.markdown("**Dataset context (grounding)**")
        st.dataframe(context_df, width='stretch', hide_index=True)

    with about_col:
        if st.button("About", width='stretch'):
            _show_menu_dialog()
    with reset_col:
        if st.button("Reset", width='stretch'):
            st.session_state["dogfinder_messages"] = []
            st.rerun()

    # Sample conversation starters (above chat)
    s1, s2, s3 = st.columns([1, 1, 1])
    selected_sample = None
    with s1:
        if st.button("I live in an apartment and want a calm, small dog. Any suggestions?", width='stretch'):
            selected_sample = "I live in an apartment and want a calm, small dog. Any suggestions?"
    with s2:
        if st.button("We have young kids and enjoy weekend hikes. Which breeds fit?", width='stretch'):
            selected_sample = "We have young kids and enjoy weekend hikes. Which breeds fit?"
    with s3:
        if st.button("Looking for a medium-sized, low-shedding dog with a long lifespan.", width='stretch'):
            selected_sample = "Looking for a medium-sized, low-shedding dog with a long lifespan."

    # Render chat history below the samples
    for msg in st.session_state["dogfinder_messages"]:
        with st.chat_message(msg["role"]):
            st.markdown(msg["content"])

    user_input = selected_sample or st.chat_input("Describe your lifestyle, home, activity level, and preferences…")
    if user_input:
        st.session_state["dogfinder_messages"].append({"role": "user", "content": user_input})

        # Prepare messages with system prompt and context
        messages: List[Dict[str, str]] = [
            {"role": "system", "content": _get_system_prompt()},
            {"role": "system", "content": _format_context_text(context_df)},
        ] + st.session_state["dogfinder_messages"]

        with st.chat_message("assistant"):
            # Stream tokens live; fall back to non-stream + heuristic on quota
            try:
                stream = _stream_openai(messages)
                placeholder = st.empty()
                full_text = ""
                for chunk in stream:
                    full_text += chunk
                    placeholder.markdown(full_text)
                response = full_text
            except RuntimeError as e:
                if "ERROR_INSUFFICIENT_QUOTA" in str(e):
                    st.warning("OpenAI quota exceeded. Showing heuristic suggestions instead.")
                    response = _heuristic_suggest(context_df, user_input)
                    st.markdown(response)
                else:
                    # Unknown runtime error: fall back to non-stream call for safety
                    response = _call_openai(messages)
                    st.markdown(response)
        st.session_state["dogfinder_messages"].append({"role": "assistant", "content": response})

    # Second chat-style input for follow-ups
    follow_up_input = st.chat_input("Ask a follow-up…", key="follow_up_input")
    if follow_up_input:
        st.session_state["dogfinder_messages"].append({"role": "user", "content": follow_up_input})

        messages: List[Dict[str, str]] = [
            {"role": "system", "content": _get_system_prompt()},
            {"role": "system", "content": _format_context_text(context_df)},
        ] + st.session_state["dogfinder_messages"]

        with st.chat_message("assistant"):
            try:
                stream = _stream_openai(messages)
                placeholder = st.empty()
                full_text = ""
                for chunk in stream:
                    full_text += chunk
                    placeholder.markdown(full_text)
                response = full_text
            except RuntimeError as e:
                if "ERROR_INSUFFICIENT_QUOTA" in str(e):
                    st.warning("OpenAI quota exceeded. Showing heuristic suggestions instead.")
                    response = _heuristic_suggest(context_df, follow_up_input)
                    st.markdown(response)
                else:
                    response = _call_openai(messages)
                    st.markdown(response)
        st.session_state["dogfinder_messages"].append({"role": "assistant", "content": response})

