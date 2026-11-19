#!/usr/bin/env python3
"""
autobump.py [--check] [--push] [--distdir DIR] [category/package ...]

Keep the overlay's ebuilds on their upstream's newest version, as
packages.json describes it for each package.

- "release" packages (the FreedomNAS components and modules) follow the
  vX.Y.Z tags of their Codeberg repository: a new tag gets a copy of the
  9999 ebuild, and the newest "keep" releases (default 2) stay.
- Every other package gets a copy of its newest ebuild at the new version,
  and only the newest "keep" (default 1) stays.

Each bump updates Manifest (and md5-cache, if the repository tracks it),
and pkgcheck must report nothing the package did not have before; packages
marked "prepare" must also get through src_prepare. For "cargo" packages
pycargoebuild rewrites CRATES, GIT_CRATES and the crate licenses from the
new sources, and "prepare" also resolves every crate offline. A "pypi"
package whose upstream changed its dependencies since the version the
ebuild was copied from is not bumped (the ebuild needs a hand), except
for the dependencies listed under "pins": upstream pins those to one
version (name==X), so that package is bumped to X first and the ebuild's
~category/package-X follows. One commit per package. Without --push it commits
locally only; with --push it pushes the current branch and opens an issue
on the Forgejo repository for every bump that failed. --check only prints
what is outdated.
"""

import argparse
import functools
import json
import os
import re
import subprocess
import sys
import tarfile
import tempfile
import urllib.parse
import urllib.request
from pathlib import Path

from portage.versions import vercmp

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
VERSION_RE = re.compile(r"^v?(\d+(?:\.\d+)*)$")


def log(msg):
    print(msg, flush=True)


def run(*cmd, cwd=REPO, env=None, capture=False, check=True):
    full_env = dict(os.environ, **(env or {}))
    res = subprocess.run(cmd, cwd=cwd, env=full_env, text=True,
                         stdout=subprocess.PIPE if capture else None,
                         stderr=subprocess.STDOUT if capture else None)
    if check and res.returncode != 0:
        out = res.stdout or ""
        raise RuntimeError(f"{' '.join(map(str, cmd))} failed ({res.returncode})\n{out[-4000:]}")
    return res.stdout


def fetch(url, data=None, headers=None):
    req = urllib.request.Request(url, data=data,
                                 headers={"User-Agent": "freedomnas-overlay-autobump",
                                          **(headers or {})})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read()


def newest(versions):
    best = None
    for v in versions:
        if best is None or vercmp(v, best) > 0:
            best = v
    return best


def git_tags(url):
    out = run("git", "ls-remote", "--tags", "--refs", url, capture=True)
    tags = (line.split("refs/tags/", 1)[1] for line in out.splitlines() if "refs/tags/" in line)
    return newest(m.group(1) for t in tags if (m := VERSION_RE.match(t)))


def upstream_release(cfg):
    return git_tags(f"https://github.com/{cfg['repo']}.git")


def upstream_git_tag(cfg):
    return git_tags(cfg["url"])


def upstream_github_release(cfg):
    release = json.loads(fetch(f"https://api.github.com/repos/{cfg['repo']}/releases/latest"))
    m = VERSION_RE.match(release["tag_name"])
    return m.group(1) if m else None


def upstream_listing(cfg):
    listing = fetch(cfg["url"]).decode()
    names = {urllib.parse.unquote(n) for n in re.findall(r'href="([^"]+)"', listing)}
    pattern = re.compile(cfg["pattern"] + "$")
    return newest(m.group(1) for n in names if (m := pattern.match(n)))


def upstream_pypi(cfg):
    return json.loads(fetch(f"https://pypi.org/pypi/{cfg['project']}/json"))["info"]["version"]


def pypi_requires(project, version):
    info = json.loads(fetch(f"https://pypi.org/pypi/{project}/{version}/json"))["info"]
    return {r.split(";")[0].replace(" ", "") for r in info.get("requires_dist") or []
            if "extra ==" not in r}


def requirement_name(requirement):
    return re.split(r"[<>=!~\[]", requirement, maxsplit=1)[0].lower().replace("_", "-")


def follow_requires(cfg, old, new, text, distdir):
    before = pypi_requires(cfg["project"], old)
    after = pypi_requires(cfg["project"], new)
    pins = cfg.get("pins", {})
    names_before = {requirement_name(r) for r in before}
    names_after = {requirement_name(r) for r in after}
    changed = before ^ after
    unknown = sorted(r for r in changed if requirement_name(r) not in pins
                     and requirement_name(r) in names_after)
    if unknown:
        raise RuntimeError(f"upstream added or changed dependencies since {old}, "
                           f"the ebuild needs them by hand: {', '.join(unknown)}")
    for name in sorted(names_before - names_after - set(pins)):
        text, count = re.subn(rf"^[ \t]*[<>=~]*dev-python/{re.escape(name)}(?:-[0-9][^\s\"]*)?(?:\[[^\]]*\])?[ \t]*\n",
                              "", text, flags=re.M)
        if not count:
            raise RuntimeError(f"upstream dropped {name} since {old} but the ebuild has no dev-python/{name}")
        log(f"  dropped dev-python/{name}: upstream no longer depends on it")
    for requirement in sorted(after):
        name = requirement_name(requirement)
        if name not in pins or "==" not in requirement:
            continue
        pinned_cp, version = pins[name], requirement.split("==", 1)[1]
        if version not in releases(pinned_cp):
            pinned_old = (releases(pinned_cp) or [None])[-1]
            log(f"  {pinned_cp}: {pinned_old or 'none'} -> {version} (pinned by {cfg['project']})")
            bump(pinned_cp, {"type": "pypi", "project": name, "prepare": True, "keep": 2,
                             "allow": ["RedundantVersion"]},
                 pinned_old, version, distdir)
        text, count = re.subn(rf"~{re.escape(pinned_cp)}-[0-9][^\[\s\"]*", f"~{pinned_cp}-{version}", text)
        if not count:
            raise RuntimeError(f"{name}=={version} is pinned upstream but the ebuild has no ~{pinned_cp}")
    return text


UPSTREAMS = {
    "release": upstream_release,
    "git-tag": upstream_git_tag,
    "github-release": upstream_github_release,
    "listing": upstream_listing,
    "pypi": upstream_pypi,
}


def releases(cp):
    pn = cp.split("/")[1]
    versions = [p.name[len(pn) + 1:-len(".ebuild")] for p in (REPO / cp).glob(f"{pn}-*.ebuild")]
    return sorted((v for v in versions if not v.startswith("9999")),
                  key=functools.cmp_to_key(vercmp))


def pkgcheck_keywords(cp):
    out = run("pkgcheck", "scan", "-R", "FormatReporter", "--format", "{name}", cp,
              capture=True, check=False)
    return {line.strip() for line in out.splitlines() if line.strip()}


def drop(cp, version):
    pn = cp.split("/")[1]
    run("git", "rm", "-qf", REPO / cp / f"{pn}-{version}.ebuild")
    cache = REPO / "metadata" / "md5-cache" / cp.split("/")[0] / f"{pn}-{version}"
    if run("git", "ls-files", cache, capture=True).strip():
        run("git", "rm", "-qf", cache)


def bump(cp, cfg, old, new, distdir):
    pn = cp.split("/")[1]
    before = pkgcheck_keywords(cp)
    new_path = REPO / cp / f"{pn}-{new}.ebuild"
    release = cfg["type"] == "release"
    source = f"{pn}-9999.ebuild" if release else f"{pn}-{old}.ebuild"
    text = (REPO / cp / source).read_text()
    if cfg["type"] == "pypi" and old:
        text = follow_requires(cfg, old, new, text, distdir)
    new_path.write_text(text)
    dropped = releases(cp)[:-cfg.get("keep", 2 if release else 1)]
    for version in dropped:
        drop(cp, version)

    cargo = cfg.get("cargo")
    if cargo:
        with tempfile.TemporaryDirectory() as tmp:
            tarball = Path(tmp) / "src.tar.gz"
            tarball.write_bytes(fetch(cargo["url"].format(ver=new)))
            with tarfile.open(tarball) as tar:
                tar.extractall(tmp, filter="data")
            run("pycargoebuild", "-C", "-M", "-d", distdir, "-i", new_path,
                Path(tmp) / cargo["dir"].format(ver=new))

    run("ebuild", new_path, "manifest", env={"DISTDIR": distdir})
    if cfg.get("prepare"):
        try:
            run("ebuild", new_path, "clean", "prepare", env={"DISTDIR": distdir})
            if cargo:
                tmpdir = run("portageq", "envvar", "PORTAGE_TMPDIR", capture=True).strip()
                work = Path(tmpdir) / "portage" / f"{cp}-{new}" / "work"
                run("cargo", "metadata", "--offline", "--format-version", "1",
                    cwd=work / cargo["dir"].format(ver=new),
                    env={"CARGO_HOME": str(work / "cargo_home")}, capture=True)
        finally:
            run("ebuild", new_path, "clean", env={"DISTDIR": distdir})

    cache_tracked = bool(run("git", "ls-files", "metadata/md5-cache", capture=True).strip())
    if cache_tracked:
        repo_name = (REPO / "profiles" / "repo_name").read_text().strip()
        gentoo = run("portageq", "get_repo_path", "/", "gentoo", capture=True).strip()
        repos_conf = (f"[DEFAULT]\nmain-repo = gentoo\n[gentoo]\nlocation = {gentoo}\n"
                      f"[{repo_name}]\nlocation = {REPO}\nmasters = gentoo\n")
        with tempfile.TemporaryDirectory() as cache_dir:
            run("egencache", "--update", "--repo", repo_name, "--cache-dir", cache_dir,
                "--repositories-configuration", repos_conf, cp)

    new_problems = pkgcheck_keywords(cp) - before - set(cfg.get("allow", []))
    if new_problems:
        out = run("pkgcheck", "scan", cp, capture=True, check=False)
        raise RuntimeError(f"pkgcheck reports new problems: {', '.join(sorted(new_problems))}\n{out}")

    run("git", "add", "-A", cp)
    if cache_tracked:
        run("git", "add", "-A", f":(glob)metadata/md5-cache/{cp}-[0-9]*")
    message = f"{cp}: add {new}" + (f", drop {', '.join(dropped)}" if dropped else "")
    run("git", "commit", "-q", "-m", message)


def restore(cp):
    run("git", "reset", "-q", "--hard", "HEAD")
    run("git", "clean", "-qfd", cp)


def report_failure(cp, new, error):
    api = f"{os.environ.get('GITHUB_API_URL', 'https://api.github.com')}/repos/{os.environ['GITHUB_REPOSITORY']}/issues"
    headers = {"Authorization": f"Bearer {os.environ['GH_TOKEN']}",
               "Accept": "application/vnd.github+json",
               "Content-Type": "application/json"}
    title = f"autobump: {cp} {new} failed"
    existing = json.loads(fetch(f"{api}?state=open&per_page=100", headers=headers))
    if any(issue["title"] == title for issue in existing):
        return
    body = f"The automatic bump of `{cp}` to {new} failed:\n\n```\n{error[-6000:]}\n```\n"
    fetch(api, data=json.dumps({"title": title, "body": body}).encode(), headers=headers)


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="only print outdated packages")
    parser.add_argument("--push", action="store_true", help="push, and open issues for failures")
    parser.add_argument("--distdir", default=os.environ.get("DISTDIR"),
                        help="where to download distfiles (default: a temporary dir)")
    parser.add_argument("packages", nargs="*", help="limit to these category/package")
    args = parser.parse_args()

    config = json.loads((HERE / "packages.json").read_text())
    selected = args.packages or list(config)
    distdir = args.distdir or tempfile.mkdtemp(prefix="autobump-distfiles-")
    base = run("git", "branch", "--show-current", capture=True).strip()
    if not args.check and run("git", "status", "--porcelain", capture=True).strip():
        sys.exit("the working tree has uncommitted changes, commit or stash them first")
    failures = 0

    for cp in selected:
        cfg = config[cp]
        old = (releases(cp) or [None])[-1]
        try:
            new = UPSTREAMS[cfg["type"]](cfg)
        except Exception as e:
            log(f"{cp}: cannot read upstream: {e}")
            failures += 1
            continue
        if new is None:
            log(f"{cp}: no upstream release yet")
            continue
        if old is not None and vercmp(new, old) <= 0:
            log(f"{cp}: {old} is up to date")
            continue
        log(f"{cp}: {old or 'none'} -> {new}")
        if args.check:
            continue
        try:
            bump(cp, cfg, old, new, distdir)
        except Exception as e:
            failures += 1
            log(f"  FAILED: {e}")
            restore(cp)
            if args.push:
                report_failure(cp, new, str(e))

    if args.push and not args.check:
        run("git", "push", "-q", "origin", base)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
