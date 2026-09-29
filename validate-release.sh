#!/bin/zsh

# 🧬 Project Tribrachidium Release Validation Gatekeeper
# Verifies the design-token registry scaffolding, then bumps the patch version.
# Every check below runs real assertions: the banner "production-ready" is only
# printed once all of them passed, and a missing tool or asset is reported, never
# assumed to be fine.

PROJECT_DIR="/Users/admin/rttss-sahil/inforttsOrg/projects/tribrachidium"
VERSION_FILE="$PROJECT_DIR/.version"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🧬 Launching Tribrachidium Validation Gatekeeper...${NC}"

# Support --test-only (the CI gate): run every check but DO NOT bump .version.
# The Jenkinsfile (Flutter stage) and .github/workflows/ci.yml both call the gate with
# this flag, so an ignored flag meant every CI run churned the version.
TEST_ONLY=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --test-only) TEST_ONLY=1 ;;
        -h|--help)
            echo "Usage: ./validate-release.sh [--test-only]"
            echo "  --test-only  run all checks, do not bump .version (this is what CI calls)"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown argument '$1' — refusing to run with an unparsed command line.${NC}"
            echo "Usage: ./validate-release.sh [--test-only]"
            exit 1
            ;;
    esac
    shift
done

FAILURES=0
ok()   { echo -e "${GREEN}✅ $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; FAILURES=$((FAILURES + 1)); }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# 1. Version bootstrap + strict format gate.
#    ci/jenkins-common.groovy plan() reads .version (the Jenkinsfile passes appDir: '',
#    which is falsy in Groovy, so the pubspec branch is skipped) and derives both the
#    release tag and the Android build number from it. A malformed value used to be
#    accepted silently: "1.0.x" bumped the release BACKWARDS to 1.0.1 and "abc.def.ghi"
#    produced "abc.def.1", so the format is now a release blocker, not cosmetics.
VERSION_FILE=".version"
if [ ! -f "$VERSION_FILE" ]; then
    echo "1.0.0" > "$VERSION_FILE"
fi
CURRENT_VERSION=$(tr -d '[:space:]' < "$VERSION_FILE")
echo -e "${YELLOW}📍 Current Version: $CURRENT_VERSION${NC}"

if [[ "$CURRENT_VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    epoch="${BASH_REMATCH[1]}"
    major="${BASH_REMATCH[2]}"
    patch="${BASH_REMATCH[3]}"
    if [ "$patch" -gt 999 ]; then
        fail ".version patch component must be <= 999 (plan() formats build as %02d): $CURRENT_VERSION"
    else
        ok ".version format valid: $epoch.$major.$patch"
    fi
else
    fail ".version '$CURRENT_VERSION' is not MAJOR.MINOR.PATCH — refusing to release on an unparseable version."
    epoch=""; major=""; patch=""
fi

# 2. Structural check — the registry is a documentation-and-scaffolding product today,
#    so README.md is the only hard structural requirement of the release.
if [ -f "README.md" ]; then
    ok "README.md present"
else
    fail "README.md is missing — structural check failed."
fi

# 3. Shell syntax verification. dev.sh and this gate are executed by Jenkins and by
#    humans; a syntax error in either breaks the release before any check below runs.
for sh_file in dev.sh validate-release.sh; do
    if [ ! -f "$sh_file" ]; then
        fail "$sh_file is missing — local orchestration and the release gate need it."
    elif sh_err=$(bash -n "$sh_file" 2>&1); then
        ok "shell syntax: $sh_file"
    else
        fail "shell syntax error in $sh_file: $(printf '%s' "$sh_err" | head -n 1)"
    fi
done

# 4. CI wiring: the Jenkinsfile loads ci/jenkins-common.groovy, which in turn resolves
#    the HF publisher. A scaffold refresh that drops either file only fails the pipeline
#    at runtime, so the wiring is asserted on every release instead.
if [ -f "Jenkinsfile" ]; then
    missing_loads=""
    for target in $(grep -oE "load '[^']+'" Jenkinsfile 2>/dev/null | sed "s/load '//; s/'\$//" | sort -u); do
        [ -f "$target" ] || missing_loads="$missing_loads $target"
    done
    if [ -n "$missing_loads" ]; then
        fail "Jenkinsfile loads missing file(s):$missing_loads"
    else
        ok "Jenkinsfile load targets present"
    fi
else
    warn "no Jenkinsfile in repo — CI wiring check skipped."
fi

# 5. Secret hygiene. A previous `git add -A` published mobile/android/key.properties
#    (real storePassword/keyPassword) to origin/main, so the guard is permanent: no
#    signing or local-machine file may ever be tracked again.
tracked_secrets=$(git ls-files 2>/dev/null | grep -E '(^|/)(key\.properties|local\.properties|.*\.(jks|keystore|p12|pem))$' || true)
if [ -n "$tracked_secrets" ]; then
    fail "tracked credential/machine-local file(s) must never be committed: $(printf '%s' "$tracked_secrets" | tr '\n' ' ')"
else
    ok "no tracked signing/credential files"
fi

tracked_caches=$(git ls-files 2>/dev/null | grep -E '(^|/)(\.gradle|\.dart_tool|build)/|\.iml$' || true)
if [ -n "$tracked_caches" ]; then
    fail "tracked build cache / IDE file(s) must never be committed: $(printf '%s' "$tracked_caches" | head -n 5 | tr '\n' ' ')"
else
    ok "no tracked build caches or IDE files"
fi

# 6. Design token assets. The gate's stated job is validating the Rocky-Vision tokens,
#    so it is asserted rather than assumed. This used to print three hardcoded "PASS"
#    lines while the repo contained no CSS at all — a green gate for work never done.
#    With no token file committed yet the checks report "not applicable" (honest, and a
#    warning) and activate automatically the moment a stylesheet lands.
mapfile -t token_files < <(find . -name '*.css' -not -path './.git/*' -not -path '*/node_modules/*' -not -path '*/build/*' 2>/dev/null)
if [ "${#token_files[@]}" -eq 0 ]; then
    warn "no design token stylesheet committed yet — Rocky-Vision token checks not applicable (this is why the gate cannot claim a token PASS)."
else
    for css in "${token_files[@]}"; do
        # Every custom property declaration must be closed by a semicolon, and every
        # hsl() palette value must carry a hue plus the two percentage components the
        # README's desaturated-HSL contract requires. Comma and space separators and
        # the deg/rad/grad/turn hue units are all accepted.
        if grep -nE -- '^[[:space:]]*--[A-Za-z0-9_-]+[[:space:]]*:' "$css" 2>/dev/null | grep -vE ';[[:space:]]*$' | head -n 1 | grep -q .; then
            fail "$css: unterminated CSS custom property declaration"
        elif grep -nE 'hsl\(' "$css" 2>/dev/null \
             | grep -vE 'hsl\([[:space:]]*[0-9.]+(deg|rad|grad|turn)?[[:space:]]*,?[[:space:]]*[0-9.]+%[[:space:]]*,?[[:space:]]*[0-9.]+%' \
             | head -n 1 | grep -q .; then
            fail "$css: hsl() token is not a hue + saturation% + lightness% triple (desaturated HSL contract)"
        else
            ok "Rocky-Vision token schema: $css"
        fi
    done
    if grep -rqE 'feTurbulence|SVG\.setAttribute' --include='*.css' --include='*.js' --include='*.html' . 2>/dev/null; then
        ok "SVG noise filters present"
    else
        warn "no SVG noise filter (feTurbulence) committed yet — filter check not applicable."
    fi
    if grep -rqE 'Outfit|Inter' --include='*.css' --include='*.html' . 2>/dev/null; then
        ok "typography standard references Outfit/Inter"
    else
        warn "no Outfit/Inter typography declaration committed yet — typography check not applicable."
    fi
fi

# 7. Python checks. ci/upload_to_hf.py is the only executable code this repo ships and
#    it writes the release manifest every OTA client reads, so it is compiled and
#    contract-tested here. The checks degrade to a warning when python3 is absent (the
#    same toolchain-degrade pattern the sibling repos use for flutter/dart).
UPLOADER="ci/upload_to_hf.py"
if command -v python3 >/dev/null 2>&1; then
    if [ -f "$UPLOADER" ]; then
        if err=$(python3 -m py_compile "$UPLOADER" 2>&1); then
            ok "python syntax: $UPLOADER"
        else
            fail "python syntax error in $UPLOADER: $(printf '%s' "$err" | head -n 1)"
        fi
    else
        fail "$UPLOADER is missing — ci/jenkins-common.groovy publishes releases through it."
    fi

    # Uploader CLI contract + fail-closed behaviour (offline: no CDN calls are made).
    python3 - "$UPLOADER" <<'PY_UPLOADER'
import ast, os, subprocess, sys, tempfile

path = sys.argv[1]
if not os.path.isfile(path):
    print(f"❌ {path} missing", file=sys.stderr)
    sys.exit(1)
tree = ast.parse(open(path, encoding="utf-8").read(), filename=path)

flags, version_code = set(), []
for node in ast.walk(tree):
    if isinstance(node, ast.Call) and getattr(node.func, "attr", "") == "add_argument":
        for arg in node.args:
            if isinstance(arg, ast.Constant) and isinstance(arg.value, str) and arg.value.startswith("--"):
                flags.add(arg.value)
                if arg.value == "--version-code":
                    version_code.append(node)

# ci/jenkins-common.groovy publishHuggingFace() builds its command line from these flags.
required = {"--slug", "--version", "--track", "--repo", "--apk", "--patch", "--version-code"}
missing = sorted(required - flags)
if missing:
    print(f"❌ {path} no longer accepts {' '.join(missing)} — publishHuggingFace() would fail", file=sys.stderr)
    sys.exit(1)
print("✅ uploader CLI contract: all publishHuggingFace() flags present")

# publishHuggingFace() never passes --version-code, so a static default would pin every
# OTA manifest to the same Android versionCode.
if version_code and any(k.arg == "default" for k in version_code[0].keywords):
    print("❌ --version-code has a static default; OTA manifests pin the wrong versionCode", file=sys.stderr)
    sys.exit(1)
print("✅ uploader derives version code from the --version build suffix")

with tempfile.TemporaryDirectory() as td:
    env = {k: v for k, v in os.environ.items()
           if k not in ("HF_TOKEN", "HUGGING_FACE_HUB_TOKEN", "HF_TOKEN_PATH")}
    env["HOME"] = td
    base = [sys.executable, path, "--slug", "tribrachidium", "--version", "1.0.1+10001"]

    # No credentials available -> refuse to publish rather than 500 halfway through.
    rc = subprocess.run(base, env=env, capture_output=True, text=True).returncode
    if rc != 1:
        print(f"❌ uploader exited {rc} with no HF token (expected 1)", file=sys.stderr)
        sys.exit(1)
    print("✅ uploader fails closed without HF credentials (exit 1)")

    # A requested artifact that is not on disk must abort before the manifest is written,
    # otherwise the published manifest advertises a download URL that 404s.
    rc = subprocess.run(base + ["--token", "fake", "--apk", os.path.join(td, "missing.apk")],
                        env=env, capture_output=True, text=True).returncode
    if rc != 2:
        print(f"❌ uploader exited {rc} for a missing --apk (expected 2)", file=sys.stderr)
        sys.exit(1)
    print("✅ uploader refuses to publish a manifest for a missing artifact (exit 2)")
PY_UPLOADER
    if [ $? -eq 0 ]; then
        ok "HF CDN uploader contract verified"
    else
        fail "HF CDN uploader contract check failed (details above)"
    fi

    # Environment declaration drift: every variable the python reads from the environment
    # must be declared in .env.example, so a fresh checkout and a new agent know the
    # contract before a release needs it.
    python3 - "$PWD" <<'PY_ENV'
import os, re, sys

root = sys.argv[1]
used = set()
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in (".git", "__pycache__", "node_modules", "venv", ".venv")]
    for name in filenames:
        if not name.endswith(".py"):
            continue
        src = open(os.path.join(dirpath, name), encoding="utf-8", errors="replace").read()
        for match in re.finditer(r'os\.environ(?:\.get\(|\[)\s*["\']([A-Z][A-Z0-9_]*)["\']', src):
            used.add(match.group(1))

example = os.path.join(root, ".env.example")
if not os.path.isfile(example):
    print(f"❌ .env.example is missing — {len(used)} environment variable(s) are read but undeclared", file=sys.stderr)
    sys.exit(1)
declared = set()
for line in open(example, encoding="utf-8"):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        declared.add(line.split("=", 1)[0].strip())

undeclared = sorted(used - declared)
if undeclared:
    print(f"❌ read by repo code but not declared in .env.example: {', '.join(undeclared)}", file=sys.stderr)
    sys.exit(1)
print(f"✅ .env.example declares all {len(used)} environment variable(s) read by repo code")
PY_ENV
    if [ $? -eq 0 ]; then
        ok "environment declarations complete"
    else
        fail "environment declaration check failed (details above)"
    fi
else
    warn "python3 not on PATH — skipping $UPLOADER compile, uploader contract and env-declaration checks."
fi

# 8. Verdict — the "production-ready" banner is only earned once every check above ran.
if [ "$FAILURES" -ne 0 ]; then
    echo -e "\n===================================================="
    echo -e "${RED}🚫 TRIBRACHIDIUM RELEASE BLOCKED — ${FAILURES} check(s) failed${NC}"
    echo -e "===================================================="
    exit 1
fi

# 9. Bump patch version on successful validation (unless --test-only)
if [ "$TEST_ONLY" -eq 1 ]; then
    echo -e "${YELLOW}⚠️  --test-only: checks passed, .version NOT bumped.${NC}"
    exit 0
fi
if [ -z "$epoch" ]; then
    echo -e "${RED}❌ Refusing to bump an unparseable .version.${NC}"
    exit 1
fi
NEXT_PATCH=$((10#$patch + 1))
NEXT_VERSION="$epoch.$major.$NEXT_PATCH"
if ! echo "$NEXT_VERSION" > "$VERSION_FILE"; then
    echo -e "${RED}❌ Could not write $VERSION_FILE — version bump failed.${NC}"
    exit 1
fi

echo -e "\n===================================================="
echo -e "${GREEN}🚀 TRIBRACHIDIUM DESIGN REGISTRY VALIDATED & LOCKED${NC}"
echo -e "Version bumped: v$CURRENT_VERSION -> v$NEXT_VERSION"
echo -e "===================================================="
exit 0
