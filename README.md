# 🧬 Project Tribrachidium — App & Project Design System Registry

> **Status:** Scaffolding & Requirements Layer Complete
> **Operational Domain:** `design.infortts.com`
> **Private Container Network Port:** `8045`

---

## 🚀 Overview

Tribrachidium is the centralized design registry, component catalog, and Rocky-Vision™ specification hub for the Infortts Swarm. It publishes desaturated HSL color palettes, SVG noise overlays, typography rules, and cinematic animations to guide developers and autonomous Meeseeks.

---

## 📂 Project Directory Structure

```
projects/tribrachidium/
├── .version               # Semantic version tracking
├── README.md              # Project onboarding & setup instructions
├── task.md                # Core requirements & specifications
├── dev.sh                 # Local dev orchestration script
├── validate-release.sh    # Release verification script
└── client/                # Static design catalog & token endpoints
    ├── index.html
    ├── index.css          # Rocky-Vision base tokens
    └── main.js            # Design showcase interactive engine
```

---

## ⚡ Developer Setup & Orchestration

### 1. Requirements Compilation
* **Static Assets:** Serve via Caddy or lightweight NodeJS backend.

### 2. Run Local Stack
To run the design registry catalog on local port 9025:
```bash
./dev.sh
```

### 3. Release Verification
To verify CSS schema validation and auto-bump the semantic version:
```bash
./validate-release.sh
```
