# -*- coding: utf-8 -*-
"""Вклеивает items.json в шаблон и пишет готовую страницу."""
import json, os, sys
here = os.path.dirname(os.path.abspath(__file__))
tpl  = open(os.path.join(here, "page.template.html"), encoding="utf-8").read()
data = json.load(open(os.path.join(here, "items.json"), encoding="utf-8"))
blob = json.dumps(data, ensure_ascii=False, separators=(",", ":")) \
         .replace("<", "\u003c").replace("\u2028", "\u2028").replace("\u2029", "\u2029")
assert "/*__DATA__*/" in tpl
out = tpl.replace("/*__DATA__*/", blob)
dest = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "riba-items.html")
open(dest, "w", encoding="utf-8").write(out)
print(dest, round(len(out.encode("utf-8")) / 1024), "KB")
