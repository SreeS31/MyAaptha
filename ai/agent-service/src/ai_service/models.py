from typing import Any, Literal
from pydantic import BaseModel, Field

class HealthResponse(BaseModel):
    status: str
    service: str
    environment: str

class PersonCandidate(BaseModel):
    id: int | str
    name: str = Field(default="", max_length=240)
    surname: str = Field(default="", max_length=240)
    location: str = Field(default="", max_length=240)
    company: str = Field(default="", max_length=240)
    phone: str | None = Field(default=None, max_length=40)
    email: str | None = Field(default=None, max_length=254)
    relationship: str = Field(default="", max_length=80)

class SearchRankRequest(BaseModel):
    query: str = Field(min_length=1, max_length=160)
    candidates: list[PersonCandidate] = Field(max_length=500)

class RankedPerson(BaseModel):
    id: int | str
    score: float
    reasons: list[str]

class DuplicateRequest(BaseModel):
    people: list[PersonCandidate] = Field(min_length=2, max_length=500)

class DuplicatePair(BaseModel):
    first_id: int | str
    second_id: int | str
    confidence: float
    reasons: list[str]
    requires_review: bool = True

class RelationshipEdge(BaseModel):
    source_id: int | str
    target_id: int | str
    relationship: str

class FamilyInsightRequest(BaseModel):
    consent: bool
    people: list[PersonCandidate] = Field(max_length=1000)
    relationships: list[RelationshipEdge] = Field(max_length=2000)

class FamilyInsight(BaseModel):
    kind: Literal["SUMMARY", "DATA_QUALITY", "SUGGESTION"]
    title: str
    detail: str
    related_ids: list[int | str] = Field(default_factory=list)
    requires_review: bool = False

class EnrichmentRequest(BaseModel):
    consent: bool
    person: PersonCandidate
    known_fields: dict[str, Any] = Field(default_factory=dict, max_length=30)

class EnrichmentSuggestion(BaseModel):
    field: str
    suggested_value: str
    confidence: float
    source: str
    requires_review: bool = True

class ImportedContact(BaseModel):
    contact_key: str = Field(min_length=1, max_length=160)
    display_name: str = Field(min_length=1, max_length=240)
    phones: list[str] = Field(default_factory=list, max_length=10)
    emails: list[str] = Field(default_factory=list, max_length=10)
    organization: str = Field(default="", max_length=300)
    job_title: str = Field(default="", max_length=160)
    labels: list[str] = Field(default_factory=list, max_length=20)

class ContactOrganizeRequest(BaseModel):
    consent: bool
    contacts: list[ImportedContact] = Field(min_length=1, max_length=2000)

class ContactSuggestion(BaseModel):
    contact_key: str
    display_name: str
    phone: str | None = None
    email: str | None = None
    suggested_relationship: str
    suggested_circles: list[str]
    confidence: float
    reasons: list[str]
    requires_review: bool = True
