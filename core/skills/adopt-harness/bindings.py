"""Which binding commands run a script from the target's hook home (.agents/hooks/).

merge-hook-bindings.py REMOVES on this answer and doctor.py goes RED on it. Two copies of the
rule would drift into a doctor that flags what the merge will not remove, or a merge that
removes what the doctor never saw — so it is defined once, here.

Importers set sys.dont_write_bytecode first. This is the skill's only imported module, so it is
the only thing that could leave a __pycache__/ here — and install.sh publishes core/ byte-for-
byte and inventories ~/.agents/ for drift: the .pyc would travel in one and be flagged by the other.
"""
import re

_HOMED = re.compile(r"""^(?P<root>.*?)\.agents/hooks/(?P<script>[^/\s"']+)["']?\s*$""")


def homed_script(command):
    """Basename X when `command` runs <repo-root>/.agents/hooks/X, else None.

    The hook home must hang off a repo-ROOT expression — a variable or command substitution
    ($CLAUDE_PROJECT_DIR, $(git rev-parse …)), `.`/`..`, or nothing. Under a literal directory
    (packages/sub/.agents/hooks/x.sh) it is some OTHER tree's hook home, and a same-named script
    there is never ours to judge. An absolute literal path is not recognised either: erring
    toward None only ever means "left alone".
    """
    m = _HOMED.match(command.strip())
    if not m:
        return None
    parent = m.group("root").rstrip("/").rsplit("/", 1)[-1]
    if "$" in parent or parent.rstrip("\"'").endswith(")"):
        return m.group("script")
    # No expansion in the last segment: what is left is a bare word, maybe behind `bash `.
    if re.split(r"""[\s"']""", parent)[-1] in ("", ".", ".."):
        return m.group("script")
    return None
