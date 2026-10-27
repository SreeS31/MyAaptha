from fastapi.testclient import TestClient
from ai_service.main import app

client = TestClient(app)


def test_empty_normalized_search_is_rejected() -> None:
    for query in ("   ", "---"):
        response = client.post("/api/v1/search/rank", json={"query": query, "candidates": [{"id": 1, "name": "Ravi"}]})
        assert response.status_code == 422


def test_similarity_inputs_have_bounded_field_lengths() -> None:
    response = client.post("/api/v1/duplicates", json={"people": [
        {"id": 1, "name": "x" * 241}, {"id": 2, "name": "Valid"},
    ]})
    assert response.status_code == 422


def test_missing_names_and_distinct_email_punctuation_are_not_duplicates() -> None:
    response = client.post("/api/v1/duplicates", json={"people": [
        {"id": 1, "email": "a.b@example.com"},
        {"id": 2, "email": "ab@example.com"},
        {"id": 3},
    ]})
    assert response.status_code == 200
    assert response.json() == []


def test_even_number_of_unrelated_spouse_links_still_needs_review() -> None:
    relationships = [
        {"source_id": 1, "target_id": 2, "relationship": "spouse"},
        {"source_id": 3, "target_id": 4, "relationship": "spouse"},
    ]
    response = client.post("/api/v1/family/insights", json={"consent": True, "people": [], "relationships": relationships})
    assert any(item["title"] == "Unpaired spouse link" for item in response.json())
    relationships += [{"source_id": edge["target_id"], "target_id": edge["source_id"], "relationship": "spouse"} for edge in relationships[:]]
    response = client.post("/api/v1/family/insights", json={"consent": True, "people": [], "relationships": relationships})
    assert not any(item["title"] == "Unpaired spouse link" for item in response.json())

def test_search_ranking_and_duplicates_require_human_review() -> None:
    people = [
        {"id": 1, "name": "S P Jayadev", "location": "Hyderabad", "phone": "+919000000001"},
        {"id": 2, "name": "SP Jayadev", "location": "Hyderabad", "phone": "+919000000001"},
        {"id": 3, "name": "Rambabu", "location": "Chennai"},
    ]
    ranked = client.post("/api/v1/search/rank", json={"query": "Jayadev", "candidates": people})
    assert ranked.status_code == 200
    assert ranked.json()[0]["id"] in (1, 2)
    duplicate = client.post("/api/v1/duplicates", json={"people": people})
    assert duplicate.status_code == 200
    assert duplicate.json()[0]["confidence"] == 1.0
    assert duplicate.json()[0]["requires_review"] is True

def test_family_insights_require_explicit_consent() -> None:
    denied = client.post("/api/v1/family/insights", json={"consent": False, "people": [], "relationships": []})
    assert denied.status_code == 403
    allowed = client.post("/api/v1/family/insights", json={"consent": True, "people": [{"id": 1, "name": "One"}], "relationships": []})
    assert allowed.status_code == 200
    assert any(item["requires_review"] for item in allowed.json())

def test_enrichment_never_changes_profile_automatically() -> None:
    response = client.post("/api/v1/profiles/enrichment", json={"consent": True, "person": {"id": 1, "name": "One", "company": "INCOIS"}, "known_fields": {}})
    assert response.status_code == 200
    assert response.json()[0]["requires_review"] is True

def test_contact_organizer_suggests_family_and_company_circles() -> None:
    response = client.post("/api/v1/contacts/organize", json={
        "consent": True,
        "contacts": [
            {"contact_key": "1", "display_name": "Lakshmi Akka", "phones": ["+919999999999"]},
            {"contact_key": "2", "display_name": "Ravi Office", "phones": ["+918888888888"], "organization": "INCOIS"}
        ]
    })
    assert response.status_code == 200
    result = response.json()
    assert result[0]["suggested_relationship"] == "Sister"
    assert "Family" in result[0]["suggested_circles"]
    assert result[1]["suggested_relationship"] == "Colleague"
    assert "INCOIS" in result[1]["suggested_circles"]
    assert all(item["requires_review"] for item in result)


def test_contact_groups_are_preserved_and_unknown_people_are_not_guessed_as_friends() -> None:
    response = client.post("/api/v1/contacts/organize", json={"consent": True, "contacts": [
        {"contact_key": "1", "display_name": "Jane", "labels": ["College batch 2005", "Customers", "mobile"]},
        {"contact_key": "2", "display_name": "Unknown Person"},
        {"contact_key": "3", "display_name": "Best Friend"}
    ]})
    assert response.status_code == 200
    result = response.json()
    assert "Customers" in result[0]["suggested_circles"]
    assert "College batch 2005" in result[0]["suggested_circles"]
    assert "mobile" not in result[0]["suggested_circles"]
    assert result[1]["suggested_circles"] == ["Imported contacts"]
    assert result[2]["suggested_circles"] == ["Friends"]
