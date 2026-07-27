#!/usr/bin/env python3
"""Lightweight structural validator for CfxLua (FiveM Lua 5.4) source files.

Not a full parser. Catches the common structural mistakes:
  * unbalanced block keywords (function/if/for/while/do/repeat ... end/until)
  * unbalanced (), {}, []
  * unterminated strings / long strings / comments
  * `then`/`do` immediately followed by `end` imbalance is naturally covered

Understands Cfx extensions by normalising them first: `+=` and friends,
safe navigation `?.`, backtick hash strings, and vector literals need no
special handling for block balance.
"""
import re
import sys
import pathlib

OPENERS = {"function", "if", "for", "while", "do", "repeat"}
# 'do' that belongs to for/while headers must not double-count: we count the
# header keyword and skip its trailing 'do'.
CLOSERS = {"end", "until"}
MIDS = {"then", "else", "elseif"}

WORD = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def strip_strings_comments(src: str, path: str):
    """Remove string/comment contents, preserving newlines. Errors on unterminated."""
    out = []
    i, n = 0, len(src)
    line = 1
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            out.append(c)
            i += 1
            continue
        # long bracket string or comment
        if src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i:])
            if m:
                eq = m.group(1)
                close = "]" + eq + "]"
                j = src.find(close, i + m.end())
                if j == -1:
                    raise SyntaxError(f"{path}:{line}: unterminated long comment")
                seg = src[i : j + len(close)]
                line += seg.count("\n")
                out.append("\n" * seg.count("\n"))
                i = j + len(close)
            else:
                j = src.find("\n", i)
                i = n if j == -1 else j
            continue
        m = re.match(r"\[(=*)\[", src[i:])
        if m and (not out or not re.search(r"[A-Za-z0-9_\)\]]\s*$", "".join(out[-3:]))):
            eq = m.group(1)
            close = "]" + eq + "]"
            j = src.find(close, i + m.end())
            if j == -1:
                raise SyntaxError(f"{path}:{line}: unterminated long string")
            seg = src[i : j + len(close)]
            line += seg.count("\n")
            out.append('""' + "\n" * seg.count("\n"))
            i = j + len(close)
            continue
        if c in ("'", '"', "`"):
            j = i + 1
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == c:
                    break
                if src[j] == "\n":
                    raise SyntaxError(f"{path}:{line}: unterminated string")
                j += 1
            if j >= n:
                raise SyntaxError(f"{path}:{line}: unterminated string")
            out.append('""')
            i = j + 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


def check(path: pathlib.Path):
    src = path.read_text(encoding="utf-8", errors="replace")
    cleaned = strip_strings_comments(src, str(path))

    # bracket balance
    stack = []
    pairs = {")": "(", "}": "{", "]": "["}
    line = 1
    for ch in cleaned:
        if ch == "\n":
            line += 1
        elif ch in "({[":
            stack.append((ch, line))
        elif ch in ")}]":
            if not stack or stack[-1][0] != pairs[ch]:
                raise SyntaxError(f"{path}:{line}: unbalanced '{ch}'")
            stack.pop()
    if stack:
        ch, ln = stack[-1]
        raise SyntaxError(f"{path}:{ln}: unclosed '{ch}'")

    # block keyword balance
    depth = 0
    expect_do_skip = 0  # pending for/while header: its 'do' is the block opener already counted
    for m in WORD.finditer(cleaned):
        w = m.group(0)
        ln = cleaned.count("\n", 0, m.start()) + 1
        if w in ("for", "while"):
            depth += 1
            expect_do_skip += 1
        elif w == "do":
            if expect_do_skip > 0:
                expect_do_skip -= 1
            else:
                depth += 1
        elif w in ("function", "if"):
            depth += 1
        elif w == "repeat":
            depth += 1
        elif w == "until":
            depth -= 1
        elif w == "end":
            depth -= 1
        if depth < 0:
            raise SyntaxError(f"{path}:{ln}: 'end'/'until' without opener")
    if depth != 0:
        raise SyntaxError(f"{path}: {depth} unclosed block(s) at EOF")
    if expect_do_skip != 0:
        raise SyntaxError(f"{path}: for/while header missing 'do'")


def main(argv):
    targets = []
    for a in argv or ["."]:
        p = pathlib.Path(a)
        if p.is_dir():
            targets += sorted(p.rglob("*.lua"))
        else:
            targets.append(p)
    failed = 0
    for t in targets:
        try:
            check(t)
        except SyntaxError as e:
            print(f"FAIL {e}")
            failed += 1
    print(f"checked {len(targets)} file(s), {failed} failure(s)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
