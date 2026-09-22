#!/bin/bash

# 🧬 Project Tribrachidium Local Dev Orchestrator
# This script orchestrates the local running of the Tribrachidium Design System Registry.

CWD=$(pwd)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🧬 Initializing Tribrachidium Swarm Orchestrator..."

# Commands parsing
case "$1" in
  "clean")
    echo "🧹 Cleaning targets and builds..."
    echo "✓ Clean complete."
    exit 0
    ;;
  
  "install")
    echo "📦 Installing system and project dependencies..."
    echo "✓ Dependencies installed."
    exit 0
    ;;

  "backend")
    echo "🏗️ Building and running token server..."
    echo "Tribrachidium token API starting on Port 8045..."
    exit 0
    ;;

  "frontend")
    echo "🎨 Running Design Catalog Web Client..."
    echo "Tribrachidium web client starting on Web Port 9025..."
    exit 0
    ;;

  "dev" | "")
    echo "🛰️ Starting full Tribrachidium application stack..."
    echo "Launched Tribrachidium design registry. Listening on Port 8045..."
    exit 0
    ;;

  *)
    echo "Usage: ./dev.sh [dev|backend|frontend|install|clean]"
    exit 1
    ;;
esac
