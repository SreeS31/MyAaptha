import re
from collections import Counter, defaultdict
from difflib import SequenceMatcher
from fastapi import APIRouter, FastAPI, HTTPException

from ai_service.config import settings
from ai_service.models import (
    DuplicatePair, DuplicateRequest, EnrichmentRequest, EnrichmentSuggestion,
    FamilyInsight, FamilyInsightRequest, HealthResponse, RankedPerson,
    SearchRankRequest, ContactOrganizeRequest, ContactSuggestion,
)

app = FastAPI(title="MyAaptha Agent Service", version="1.0.0", description="Privacy-aware ranking, duplicate detection, and family graph assistance.")
router = APIRouter(prefix=settings.ai_api_prefix)

def norm(value: str | None) -> str:
    return re.sub(r"[^a-z0-9]", "", (value or "").casefold())

@router.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(status="ok", service=settings.ai_service_name, environment=settings.ai_env)

@router.get("/ready", response_model=HealthResponse)
def ready() -> HealthResponse:
    return HealthResponse(status="ready", service=settings.ai_service_name, environment=settings.ai_env)

@router.post("/search/rank", response_model=list[RankedPerson])
def rank_people(request: SearchRankRequest) -> list[RankedPerson]:
    query = norm(request.query)
    ranked: list[RankedPerson] = []
    for person in request.candidates:
        fields = {"name": norm(f"{person.name} {person.surname}"), "location": norm(person.location), "company": norm(person.company), "relationship": norm(person.relationship)}
        best, reasons = 0.0, []
        for label, value in fields.items():
            if not value: continue
            score = 1.0 if query in value else SequenceMatcher(None, query, value).ratio()
            weight = 1.0 if label == "name" else 0.75
            best = max(best, score * weight)
            if score >= .7: reasons.append(f"{label} match")
        if best >= .25: ranked.append(RankedPerson(id=person.id, score=round(best, 4), reasons=reasons or ["partial match"]))
    return sorted(ranked, key=lambda item: (-item.score, str(item.id)))

@router.post("/duplicates", response_model=list[DuplicatePair])
def duplicates(request: DuplicateRequest) -> list[DuplicatePair]:
    result: list[DuplicatePair] = []
    for index, first in enumerate(request.people):
        for second in request.people[index + 1:]:
            reasons, confidence = [], 0.0
            if first.phone and second.phone and norm(first.phone) == norm(second.phone): reasons.append("same mobile number"); confidence = 1.0
            if first.email and second.email and norm(first.email) == norm(second.email): reasons.append("same email address"); confidence = max(confidence, .98)
            name_score = SequenceMatcher(None, norm(f"{first.name}{first.surname}"), norm(f"{second.name}{second.surname}")).ratio()
            if name_score >= .88: reasons.append("very similar name"); confidence = max(confidence, name_score * (.92 if norm(first.location) == norm(second.location) else .78))
            if confidence >= .72: result.append(DuplicatePair(first_id=first.id, second_id=second.id, confidence=round(confidence, 4), reasons=reasons))
    return sorted(result, key=lambda pair: -pair.confidence)

@router.post("/family/insights", response_model=list[FamilyInsight])
def family_insights(request: FamilyInsightRequest) -> list[FamilyInsight]:
    if not request.consent: raise HTTPException(status_code=403, detail="Explicit consent is required for family-tree insights")
    relationship_counts = Counter(edge.relationship.casefold() for edge in request.relationships)
    insights = [FamilyInsight(kind="SUMMARY", title="Family network summary", detail=f"{len(request.people)} people and {len(request.relationships)} relationship links are represented.")]
    if not request.relationships and request.people: insights.append(FamilyInsight(kind="DATA_QUALITY", title="Unconnected profiles", detail="Profiles exist without relationship links. Connect them before accepting tree insights.", related_ids=[p.id for p in request.people], requires_review=True))
    parent_count: dict[int | str, int] = defaultdict(int)
    for edge in request.relationships:
        if edge.relationship.casefold() in {"child", "son", "daughter"}: parent_count[edge.source_id] += 1
    large = [person_id for person_id, count in parent_count.items() if count >= 5]
    if large: insights.append(FamilyInsight(kind="SUGGESTION", title="Review large child groups", detail="These nodes have five or more child links. Confirm that all anchors are correct.", related_ids=large, requires_review=True))
    if relationship_counts.get("spouse", 0) % 2 == 1: insights.append(FamilyInsight(kind="DATA_QUALITY", title="Unpaired spouse link", detail="A spouse relationship may be missing its reciprocal link.", requires_review=True))
    return insights

@router.post("/profiles/enrichment", response_model=list[EnrichmentSuggestion])
def enrichment(request: EnrichmentRequest) -> list[EnrichmentSuggestion]:
    if not request.consent: raise HTTPException(status_code=403, detail="Explicit consent is required for profile enrichment")
    suggestions: list[EnrichmentSuggestion] = []
    if request.person.company and not request.known_fields.get("company"):
        suggestions.append(EnrichmentSuggestion(field="company", suggested_value=request.person.company.strip(), confidence=.75, source="existing relationship context"))
    if request.person.location and not request.known_fields.get("location"):
        suggestions.append(EnrichmentSuggestion(field="location", suggested_value=request.person.location.strip(), confidence=.7, source="existing relationship context"))
    return suggestions

FAMILY_ALIASES = {
    "Mother": {"mother", "mom", "mummy", "amma", "maa"},
    "Father": {"father", "dad", "daddy", "nanna", "papa"},
    "Sister": {"sister", "sis", "akka", "chelli", "didi"},
    "Brother": {"brother", "bro", "anna", "thammudu", "bhai"},
    "Wife": {"wife"},
    "Husband": {"husband"},
    "Son": {"son", "boy"},
    "Daughter": {"daughter", "girl"},
    "Grandfather": {"grandfather", "grandpa"},
    "Grandmother": {"grandmother", "grandma"},
    "Uncle": {"uncle", "mama", "chacha"},
    "Aunt": {"aunt", "aunty", "mami", "chachi"},
    "Nephew": {"nephew"},
    "Niece": {"niece"},
    "Cousin": {"cousin"},
    "Guardian": {"guardian"},
    "Relative": {"relative", "family"},
}
EDUCATION_WORDS = {"school", "college", "university", "ssc", "inter", "intermediate", "degree", "btech", "mba", "class", "batch"}

@router.post("/contacts/organize", response_model=list[ContactSuggestion])
def organize_contacts(request: ContactOrganizeRequest) -> list[ContactSuggestion]:
    if not request.consent:
        raise HTTPException(status_code=403, detail="Explicit consent is required before contacts are analyzed")
    suggestions: list[ContactSuggestion] = []
    for contact in request.contacts:
        searchable = " ".join([contact.display_name, contact.organization, contact.job_title, *contact.labels]).casefold()
        tokens = set(re.findall(r"[a-z0-9]+", searchable))
        relationship, confidence, reasons = "Friend", .48, ["No strong relationship keyword; review as friend"]
        for candidate, aliases in FAMILY_ALIASES.items():
            matches = sorted(tokens.intersection(aliases))
            if matches:
                relationship, confidence, reasons = candidate, .9, [f"Name or label contains '{matches[0]}'"]
                break
        circles: list[str] = []
        if relationship in {"Mother", "Father", "Sister", "Brother", "Wife", "Husband", "Son", "Daughter", "Grandmother", "Grandfather", "Granddaughter", "Grandson", "Aunt", "Uncle", "Niece", "Nephew", "Cousin", "Guardian", "Relative"}:
            circles.append("Family")
        organization = contact.organization.strip()
        if organization:
            circles.append(organization)
            reasons.append("Organization is saved in the contact")
            if relationship == "Friend": relationship, confidence = "Colleague", .72
        education_matches = sorted(tokens.intersection(EDUCATION_WORDS))
        if education_matches:
            label = next((item.strip() for item in contact.labels if item.strip()), "Education friends")
            circles.append(label if any(word in label.casefold() for word in EDUCATION_WORDS) else "Education friends")
            reasons.append(f"Education keyword '{education_matches[0]}' was detected")
        if relationship == "Friend" and not circles: circles.append("Friends")
        suggestions.append(ContactSuggestion(
            contact_key=contact.contact_key, display_name=contact.display_name.strip(),
            phone=contact.phones[0] if contact.phones else None,
            email=contact.emails[0] if contact.emails else None,
            suggested_relationship=relationship, suggested_circles=list(dict.fromkeys(circles)),
            confidence=confidence, reasons=reasons, requires_review=True))
    return suggestions

app.include_router(router)
