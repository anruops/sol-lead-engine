"""
Known cases the rubric must keep getting right. Run before changing any rule:
  py -m unittest -v test_rubric
A rule change that breaks one of these fails loudly instead of quietly
re-ranking real leads.
"""
import unittest
from datetime import datetime, timezone

from recon_rubric import RUBRIC_VERSION, score_lead

NOW = datetime(2026, 10, 17, tzinfo=timezone.utc)


def lead(**over):
    base = {"lead_key": "osm:node/1", "business_name": "Test Studio", "country": "US",
            "tags": [], "audit_details": {}}
    base.update(over)
    return base


class NoWebsiteListed(unittest.TestCase):
    def test_unknowns_do_not_score_and_lead_is_held(self):
        r = score_lead(lead(site_status="none", address="1 Main St", city="Austin",
                            tags=["needs_check"]), NOW)
        labels = [x["label"] for x in r["score_reasons"]]
        self.assertIn("No website listed", labels)
        for unknown in ("No online booking", "No contact form", "No email visible anywhere", "No social links"):
            self.assertNotIn(unknown, labels)          # v0.3: an unknown is not a no
        self.assertEqual(r["opportunity_pts"], 20 + 5 + 3)
        self.assertEqual(r["tier"], "needs_check")

    def test_confirmed_no_site_counts_absences_and_skips_hold(self):
        r = score_lead(lead(site_status="none", address="1 Main St", city="Austin",
                            tags=["no_site_confirmed"]), NOW)
        self.assertEqual(r["opportunity_pts"], 20 + 10 + 5 + 5 + 3 + 5 + 3)
        self.assertEqual(r["viability_pts"], 5)
        self.assertEqual(r["tier"], "warm")              # 51 + 5 = 56, no hold


class WorkingSite(unittest.TestCase):
    def test_polished_site_is_cold_growth_prospect(self):
        r = score_lead(lead(site_status="ok", https=True, mobile_ready=True, copyright_year=2026,
                            has_booking=True, has_contact_form=True, emails_found=["hi@studio.com"],
                            phone="+1 512", opening_hours="Mo-Fr", address="1 Main St", city="Austin",
                            audit_details={"socials_found": ["https://instagram.com/studio"]}), NOW)
        self.assertEqual(r["opportunity_pts"], 0)
        self.assertEqual(r["tier"], "cold")
        self.assertIn("growth_prospect", r["tags"])
        self.assertEqual(r["contact_route"], "email")

    def test_no_https_is_worth_8(self):
        r = score_lead(lead(site_status="ok", https=False, mobile_ready=True), NOW)
        pts = {x["label"]: x["pts"] for x in r["score_reasons"]}
        self.assertEqual(pts["No HTTPS"], 8)

    def test_old_copyright_bands(self):
        five = score_lead(lead(site_status="ok", https=True, mobile_ready=True, copyright_year=2020), NOW)
        three = score_lead(lead(site_status="ok", https=True, mobile_ready=True, copyright_year=2023), NOW)
        self.assertIn("Copyright 2020 (5+ years old)", [x["label"] for x in five["score_reasons"]])
        self.assertIn("Copyright 2023 (3-4 years old)", [x["label"] for x in three["score_reasons"]])


class DownAndBlocked(unittest.TestCase):
    def test_dead_domain_is_tagged_and_scored(self):
        r = score_lead(lead(site_status="down", audit_details={"reason": "getaddrinfo ENOTFOUND example.com"}), NOW)
        self.assertIn("Website address no longer exists", [x["label"] for x in r["score_reasons"]])
        self.assertIn("domain_gone", r["tags"])

    def test_blocked_site_counts_as_alive_but_hides_site_signals(self):
        r = score_lead(lead(site_status="blocked"), NOW)
        labels = [x["label"] for x in r["score_reasons"]]
        self.assertIn("Website online (blocks automated visits)", labels)
        self.assertNotIn("No online booking", labels)


class TiersAndCaps(unittest.TestCase):
    def test_hot_needs_score_and_viability(self):
        r = score_lead(lead(site_status="down", phone="+1 512", address="1 Main St", city="Austin",
                            opening_hours="Mo-Fr", osm_last_edit="2026-01-10T00:00:00Z",
                            socials={"instagram": "x"}, nearby=4, nearby_booking=3, nearby_site=3), NOW)
        self.assertGreaterEqual(r["viability_pts"], 15)
        self.assertGreaterEqual(r["final_score"], 70)
        self.assertEqual(r["tier"], "hot")

    def test_caps_hold(self):
        r = score_lead(lead(site_status="down", nearby=5, nearby_booking=5, nearby_site=5), NOW)
        self.assertLessEqual(r["opportunity_pts"], 70)
        self.assertLessEqual(r["viability_pts"], 30)

    def test_old_map_edit_does_not_count(self):
        r = score_lead(lead(site_status="none", osm_last_edit="2022-01-01T00:00:00Z"), NOW)
        self.assertNotIn("Map entry updated in the last 24 months", [x["label"] for x in r["score_reasons"]])

    def test_version_and_uk_email_block(self):
        r = score_lead(lead(site_status="ok", country="GB", emails_found=["a@b.co.uk"]), NOW)
        self.assertEqual(r["rubric_version"], RUBRIC_VERSION)
        self.assertFalse(r["email_allowed"])


if __name__ == "__main__":
    unittest.main()
