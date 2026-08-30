#!/usr/bin/env bash
# Despliegue automatizado en Railway mediante Railway CLI (ya autenticado).
# Uso: ./scripts/deploy-railway.sh <AGENT_TOKEN> [PROJECT_NAME]
set -euo pipefail

AGENT_TOKEN="${1:?Uso: $0 <AGENT_TOKEN> [PROJECT_NAME]}"
PROJECT_NAME="${2:-cloud-gaming}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "== 1/8 Creando proyecto Railway '$PROJECT_NAME' =="
(cd "$ROOT" && railway init --name "$PROJECT_NAME")

echo "== 2/8 Creando servicio backend =="
(cd "$ROOT" && railway add --service backend)

echo "== 3/8 Creando servicio frontend =="
(cd "$ROOT" && railway add --service frontend)

echo "== 4/8 Linkeando backend =="
(cd "$ROOT/backend" && railway link --project "$PROJECT_NAME" --service backend)

echo "== 5/8 Linkeando frontend =="
(cd "$ROOT/frontend" && railway link --project "$PROJECT_NAME" --service frontend)

echo "== 6/8 Desplegando backend =="
(cd "$ROOT/backend" && railway variables --set "AGENT_TOKEN=$AGENT_TOKEN" --set "CORS_ORIGIN=*")
(cd "$ROOT/backend" && railway up --detach)
BACKEND_DOMAIN="$(cd "$ROOT/backend" && railway domain)"
BACKEND_URL="https://${BACKEND_DOMAIN}"
echo "Backend URL: ${BACKEND_URL}"

echo "== 7/8 Desplegando frontend =="
(cd "$ROOT/frontend" && railway variables --set "VITE_BACKEND_URL=${BACKEND_URL}")
(cd "$ROOT/frontend" && railway up --detach)
FRONTEND_DOMAIN="$(cd "$ROOT/frontend" && railway domain)"
FRONTEND_URL="https://${FRONTEND_DOMAIN}"

echo ""
echo "== 8/8 Despliegue completado =="
echo "======================================================"
echo "  URL PÚBLICA:  ${FRONTEND_URL}"
echo "  Backend:      ${BACKEND_URL}"
echo "======================================================"
echo ""
echo "Configura agent/.env con:"
echo "  BACKEND_URL=${BACKEND_URL}"
echo "  AGENT_TOKEN=${AGENT_TOKEN}"
