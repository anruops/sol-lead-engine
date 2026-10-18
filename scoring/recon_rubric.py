"""
RECON rubric: deterministic lead scoring (rules, no AI).

Final score = Opportunity (up to 70) + Viability (up to 30).
  Opportunity: what a frustrated customer runs into.
  Viability:   is the business alive and worth saving.
Reach is never scored; it only decides the contact route.

v0.3 rules:
  * An unknown is not a no. Booking, contact form, email and social points
    only count when we actually know (site loaded, site down, or you confirmed
    there is no website). A lead with no listed website does not collect them.
  * No HTTPS is worth 8.
  * A lead you confirmed has no website skips the needs_check hold.

score_lead(lead) takes one row from Score Batch and returns the fields
Save Score writes. Pure function: same input, same output, nothing stored.
"""
from __future__ import annotations

import re
from datetime import datetime, timezone

RUBRIC_VERSION = "v0.3"
OPPORTUNITY_CAP = 70
VIABILITY_CAP = 30
MAP_EDIT_FRESH_DAYS = 730  # 24 months


def _years_since_edit(value, now: datetime) -> float | None:
    if not value:
        return None
    try:
        edited = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None
    if edited.tzinfo is None:
        edited = edited.replace(tzinfo=timezone.utc)
    return (now - edited).days


def score_lead(lead: dict, now: datetime | None = None) -> dict:
    now = now or datetime.now(timezone.utc)
    audit = lead.get("audit_details") or {}
    reasons: list[dict] = []
    totals = {"opportunity": 0, "viability": 0}

    def add(side: str, pts: int, label: str) -> None:
        reasons.append({"side": side, "pts": pts, "label": label})
        totals[side] += pts

    site = lead.get("site_status")                 # none | ok | down | blocked
    site_ok = site == "ok"
    domain_gone = bool(re.search(r"ENOTFOUND", str(audit.get("reason") or ""), re.I))
    social_count = len(lead.get("socials") or {}) + len(audit.get("socials_found") or [])
    emails = list(lead.get("emails_found") or []) + ([lead["email"]] if lead.get("email") else [])
    has_phone = bool(lead.get("phone")) or bool(audit.get("click_to_call"))
    has_hours = bool(lead.get("opening_hours"))
    tags_in = list(lead.get("tags") or [])
    confirmed_no_site = "no_site_confirmed" in tags_in

    # ---- Opportunity: what a frustrated customer runs into ----
    if site == "none":
        add("opportunity", 20, "No website listed")
    if site == "down":
        add("opportunity", 20, "Website address no longer exists" if domain_gone else "Website not loading")
    if site_ok:
        if not lead.get("mobile_ready"):
            add("opportunity", 8, "Not mobile-friendly")
        if not lead.get("https"):
            add("opportunity", 8, "No HTTPS")
        year = lead.get("copyright_year")
        if year:
            age = now.year - int(year)
            if age >= 5:
                add("opportunity", 8, f"Copyright {year} (5+ years old)")
            elif age >= 3:
                add("opportunity", 4, f"Copyright {year} (3-4 years old)")
    if site_ok or site == "down" or confirmed_no_site:   # only absences we actually know about
        if not lead.get("has_booking"):
            add("opportunity", 10, "No online booking (schedule page only)"
                if audit.get("clicks_to_book") == 2 else "No online booking")
        if not lead.get("has_contact_form"):
            add("opportunity", 5, "No contact form")
        if not emails:
            add("opportunity", 5, "No email visible anywhere")
        if not social_count:
            add("opportunity", 3, "No social links")
    if not has_phone:
        add("opportunity", 5, "No phone listed")
    if not has_hours:
        add("opportunity", 3, "No opening hours listed")

    nearby = int(lead.get("nearby") or 0)
    if nearby >= 2:
        nb_booking = int(lead.get("nearby_booking") or 0)
        nb_site = int(lead.get("nearby_site") or 0)
        if not lead.get("has_booking") and nb_booking / nearby > 0.5:
            add("opportunity", 4, f"{nb_booking} of {nearby} audited studios within 10 km take online bookings")
        if not site_ok and nb_site / nearby > 0.5:
            add("opportunity", 4, f"{nb_site} of {nearby} audited studios within 10 km have a working website")
    opp = min(totals["opportunity"], OPPORTUNITY_CAP)

    # ---- Viability: is it alive and worth saving ----
    if has_phone:
        add("viability", 7, "Phone listed")
    if lead.get("address") and (lead.get("postcode") or lead.get("city")):
        add("viability", 5, "Full street address")
    if site_ok:
        add("viability", 6, "Working website")
    elif site == "blocked":
        add("viability", 6, "Website online (blocks automated visits)")
    if has_hours:
        add("viability", 4, "Opening hours listed")
    days = _years_since_edit(lead.get("osm_last_edit"), now)
    if days is not None and days < MAP_EDIT_FRESH_DAYS:
        add("viability", 4, "Map entry updated in the last 24 months")
    if social_count:
        add("viability", 4, "Social profile found")
    via = min(totals["viability"], VIABILITY_CAP)

    # ---- Tier, tags, contact route ----
    final = opp + via
    if final >= 70 and via >= 15:
        tier = "hot"
    elif final >= 45:
        tier = "warm"
    else:
        tier = "cold"
    if via < 10 and not confirmed_no_site:
        tier = "needs_check" if site == "none" else "check_alive"

    tags = list(dict.fromkeys(tags_in))
    def tag(t: str) -> None:
        if t not in tags:
            tags.append(t)
    if domain_gone:
        tag("domain_gone")
    if lead.get("multi_location"):
        tag("multi_location")
    if opp <= 15 and site_ok and lead.get("has_booking") and emails:
        tag("growth_prospect")

    email_allowed = bool(emails) and str(lead.get("country") or "US").upper() == "US"
    if email_allowed:
        route = "email"
    elif has_phone:
        route = "phone"
    elif lead.get("has_contact_form"):
        route = "contact_form"
    else:
        route = "visit"

    return {
        "lead_key": lead.get("lead_key"),
        "business_name": lead.get("business_name"),
        "opportunity_pts": opp,
        "viability_pts": via,
        "final_score": final,
        "tier": tier,
        "tags": tags,
        "score_reasons": reasons,
        "rubric_version": RUBRIC_VERSION,
        "contact_route": route,
        "email_allowed": email_allowed,
    }
