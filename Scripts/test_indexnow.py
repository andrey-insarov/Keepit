#!/usr/bin/env python3
"""Tests for the pure parts of Scripts/indexnow.py (no network, no git).
Run: python3 Scripts/test_indexnow.py"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import indexnow  # noqa: E402

BASE = "https://keep.it.com/"


class PageURL(unittest.TestCase):
    def test_landing_and_pages(self):
        self.assertEqual(indexnow.page_url("index.html", BASE), BASE)
        self.assertEqual(indexnow.page_url("guide.html", BASE), BASE + "guide")
        self.assertEqual(indexnow.page_url("ru/index.html", BASE), BASE + "ru/")
        self.assertEqual(indexnow.page_url("pt-br/support.html", BASE), BASE + "pt-br/support")

    def test_not_a_page(self):
        for rel in ("sitemap.xml", "_headers", "img/guide/x.png", "robots.txt"):
            self.assertIsNone(indexnow.page_url(rel, BASE))


class Sitemap(unittest.TestCase):
    def test_locs_in_order_and_unescaped(self):
        xml = "<urlset><url><loc>https://keep.it.com/</loc></url><url><loc> https://keep.it.com/a?x=1&amp;y=2 </loc></url></urlset>"
        self.assertEqual(indexnow.sitemap_urls(xml), [BASE, BASE + "a?x=1&y=2"])

    def test_every_listed_page_has_a_file(self):
        # The mapping file -> URL and the generator's sitemap must agree, or pages are skipped silently.
        listed = set(indexnow.sitemap_urls((indexnow.site / "sitemap.xml").read_text(encoding="utf-8")))
        files = {indexnow.page_url(p.relative_to(indexnow.site).as_posix(), BASE)
                 for p in indexnow.site.rglob("*.html")}
        self.assertTrue(listed)
        self.assertEqual(listed - files, set())


class Changed(unittest.TestCase):
    now = {BASE, BASE + "guide", BASE + "ru/"}
    before = now | {BASE + "old"}

    def urls(self, *lines):
        return indexnow.changed_urls(list(lines), BASE, self.now, self.before)

    def test_modified_and_added_pages_in_the_sitemap(self):
        self.assertEqual(self.urls("M\tindex.html", "A\tru/index.html", "M\tguide.html"),
                         [BASE, BASE + "ru/", BASE + "guide"])

    def test_pages_outside_the_sitemap_are_skipped(self):
        self.assertEqual(self.urls("M\t404.html", "M\tv2/guide.html", "M\tsitemap.xml", "M\timg/a.png"), [])

    def test_deleted_page_goes_out_only_if_it_was_listed(self):
        self.assertEqual(self.urls("D\told.html", "D\tv2/support.html"), [BASE + "old"])

    def test_no_duplicates(self):
        self.assertEqual(self.urls("M\tindex.html", "M\tindex.html"), [BASE])


class Key(unittest.TestCase):
    def test_one_key_file_and_it_is_well_formed(self):
        key = indexnow.find_key()
        self.assertRegex(key, r"\A[A-Za-z0-9-]{8,128}\Z")


if __name__ == "__main__":
    unittest.main()
