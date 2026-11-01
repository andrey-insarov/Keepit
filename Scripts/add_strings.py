#!/usr/bin/env python3
"""Append new keys to every translation table + en.lproj, then regenerate.
Usage: python3 Scripts/add_strings.py new_strings.json
JSON: {"English key": {"ru": "...", "de": "...", ... all 20 codes ...}, ...}"""
import json, sys, os, re, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
T_LANGS = ["ru", "de", "fr", "es", "ja", "zh-Hans"]
T2_LANGS = ["uk", "ar", "it"]
FILE_LANGS = {"pt-BR": "lang_pt_BR.py", "ko": "lang_ko.py", "zh-Hant": "lang_zh_Hant.py", "tr": "lang_tr.py",
              "pl": "lang_pl.py", "nl": "lang_nl.py", "he": "lang_he.py", "cs": "lang_cs.py",
              "lt": "lang_lt.py", "lv": "lang_lv.py", "et": "lang_et.py"}

def esc(s): return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")

def main(path):
    new = json.load(open(path, encoding="utf-8"))
    allcodes = T_LANGS + T2_LANGS + list(FILE_LANGS)
    for k, tr in new.items():
        missing = [c for c in allcodes if c not in tr]
        if missing: raise SystemExit(f"{k!r}: missing {missing}")
    # en.lproj
    with open(os.path.join(HERE, "..", "Sources/Keepit/Resources/en.lproj/Localizable.strings"), "a", encoding="utf-8") as f:
        f.write("\n")
        for k in new: f.write(f'"{esc(k)}" = "{esc(k)}";\n')
    # T (gen_strings.py) and T2 (strings_extra.py)
    def append_table(fname, langs, marker_end):
        p = os.path.join(HERE, fname); s = open(p, encoding="utf-8").read().rstrip("\n")
        add = "".join(f"{k!r}: ({', '.join(repr(new[k][c]) for c in langs)}),\n" for k in new)
        if marker_end:
            s = s.replace("\n}\n\nPH = re.compile", "\n" + add + "}\n\nPH = re.compile", 1)
        else:
            assert s.endswith("}"); s = s[:-1] + add + "}\n"
        open(p, "w", encoding="utf-8").write(s if s.endswith("\n") else s + "\n")
    append_table("gen_strings.py", T_LANGS, True)
    append_table("strings_extra.py", T2_LANGS, False)
    for code, fname in FILE_LANGS.items():
        p = os.path.join(HERE, fname); s = open(p, encoding="utf-8").read().rstrip("\n")
        assert s.endswith("}")
        add = "".join(f"{k!r}: {new[k][code]!r},\n" for k in new)
        open(p, "w", encoding="utf-8").write(s[:-1] + add + "}\n")
    subprocess.check_call([sys.executable, os.path.join(HERE, "gen_strings.py")])

if __name__ == "__main__":
    main(sys.argv[1])
