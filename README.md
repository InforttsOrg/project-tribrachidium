# 🧬 Project Tribrachidium — App & Project Design System Registry

> **Status:** Scaffolding & Requirements Layer Complete
> **Operational Domain:** `design.infortts.com`
> **Private Container Network Port:** `8045`

---

## 🚀 Overview

Tribrachidium is the centralized design registry, component catalog, and Rocky-Vision™ specification hub for the Infortts Swarm. It publishes desaturated HSL color palettes, SVG noise overlays, typography rules, and cinematic animations to guide developers and autonomous Meeseeks.

**No service is implemented yet.** The repository ships the registry's release
scaffolding and its release gate; the token server and the design catalog are still
planned (see below). `./dev.sh` reports this honestly instead of pretending to start
something.

---

## 📂 Project Directory Structure

```
projects/tribrachidium/
├── .env.example           # Environment contract (HF_TOKEN for the release CDN publisher)
├── .version               # Semantic version tracking
├── README.md              # Project onboarding & setup instructions
├── dev.sh                 # Local dev orchestration script
├── validate-release.sh    # Release verification script
├── Jenkinsfile            # Auto-generated Infortts CI pipeline (do not hand-edit)
└── ci/                    # Shared Jenkins pipeline helpers
    ├── jenkins-common.groovy
    └── upload_to_hf.py    # Hugging Face CDN release publisher

client/                    # (Planned) Static design catalog & token endpoints
├── index.html
├── index.css              # Rocky-Vision base tokens
└── main.js                # Design showcase interactive engine
```

---

## ⚡ Developer Setup & Orchestration

### 1. Requirements Compilation
* **Static Assets:** Serve via Caddy or lightweight NodeJS backend.
* **Environment:** Copy `.env.example` to `.env` and set `HF_TOKEN` before publishing a
  release; the release gate fails if repo code reads an environment variable that
  `.env.example` does not declare.

### 2. Run Local Stack
To run the design registry catalog on local port 9025:
```bash
./dev.sh
```

### 3. Release Verification
To verify the registry and auto-bump the patch version of `.version`:
```bash
./validate-release.sh
```

To run every release check **without** bumping `.version` (this is what CI calls):
```bash
./validate-release.sh --test-only
```

The gate validates, and blocks the release when any check fails:
* `.version` is a parseable `MAJOR.MINOR.PATCH` (CI derives the release tag and the
  Android build number from it),
* `README.md`, `dev.sh` and the Jenkinsfile's `ci/` load targets exist, and both shell
  scripts pass `bash -n`,
* no signing/credential file and no build cache is tracked,
* the Rocky-Vision token stylesheet schema (only once a stylesheet is committed — until
  then the gate reports the check as not applicable instead of claiming a PASS),
* the `ci/upload_to_hf.py` CLI contract, its fail-closed behaviour, and the
  completeness of `.env.example`.
