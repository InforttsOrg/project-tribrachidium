#!/bin/bash

# 🧬 Project Tribrachidium Local Dev Orchestrator
# This script orchestrates the local running of the Tribrachidium Design System Registry.
# Every branch reports what actually happened: the registry is a scaffolding product
# today, so a branch with nothing to do says so instead of printing a green tick.

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR" || exit 1

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🧬 Initializing Tribrachidium Swarm Orchestrator...${NC}"

# Commands parsing
case "$1" in
  "clean")
    echo -e "${BLUE}🧹 Cleaning targets and builds...${NC}"
    # Only real build outputs are removed; the gitignore covers .dart_tool/ and build/,
    # so report the actual result rather than an unconditional success line.
    if [ -d build ] || [ -d dist ] || [ -d client ]; then
        rm -rf build dist
        echo -e "${GREEN}✓ Removed build/ and dist/ outputs.${NC}"
    else
        echo -e "${YELLOW}⚠️  No build outputs present in this repo yet — nothing was removed.${NC}"
    fi
    exit 0
    ;;

  "install")
    echo -e "${BLUE}📦 Installing system and project dependencies...${NC}"
    # The HF CDN publisher is the only dependency-managed component; it installs
    # huggingface_hub on demand at first publish. Report the real result instead of
    # claiming success unconditionally.
    if command -v python3 >/dev/null 2>&1; then
        if [ ! -f requirements.txt ]; then
            echo -e "${YELLOW}⚠️  No requirements.txt in this repo yet — using system Python packages.${NC}"
        elif python3 -m pip install -q -r requirements.txt; then
            echo -e "${GREEN}✓ Dependencies installed from requirements.txt.${NC}"
        else
            echo -e "${RED}❌ Dependency installation failed — see pip output above.${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ python3 not on PATH — ci/upload_to_hf.py cannot run.${NC}"
        exit 1
    fi
    exit 0
    ;;

  "backend")
    echo -e "${BLUE}🏗️ Building and running token server...${NC}"
    # The token server (private container port 8045) is specified in README.md but is
    # not committed. Do not print a "starting on Port 8045" line for a process that
    # does not exist — a caller cannot distinguish it from a real launch.
    echo -e "${YELLOW}⚠️  No token server is implemented in this repo yet — nothing was started.${NC}"
    echo -e "${YELLOW}   README.md scopes it: 'Static Assets: serve via Caddy or lightweight NodeJS backend'.${NC}"
    exit 1
    ;;

  "frontend")
    echo -e "${BLUE}🎨 Running Design Catalog Web Client...${NC}"
    # client/ (index.html + index.css + main.js) is specified in README.md but is not
    # committed, so there is nothing to serve on Web Port 9025 yet.
    echo -e "${YELLOW}⚠️  No client/ directory is committed yet — the design catalog is not implemented.${NC}"
    echo -e "${YELLOW}   Nothing was started on Web Port 9025.${NC}"
    exit 1
    ;;

  "dev" | "")
    echo -e "${BLUE}🛰️ Starting full Tribrachidium application stack...${NC}"
    echo -e "${YELLOW}⚠️  No service is implemented in this repo yet — nothing was started.${NC}"
    echo -e "${YELLOW}   Tribrachidium currently ships the Rocky-Vision design registry scaffolding only.${NC}"
    exit 0
    ;;

  *)
    echo "Usage: ./dev.sh [dev|backend|frontend|install|clean]"
    exit 1
    ;;
esac
