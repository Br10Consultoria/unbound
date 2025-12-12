#!/bin/bash
# Orquestrador completo: Unbound + Monitoramento

set -e

BLUE='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Este script deve ser executado como root.${NC}"
    exit 1
  fi
}

run_step() {
  local title="$1"
  local script="$2"

  echo -e "\n${BLUE}==========================================================${NC}"
  echo -e "${YELLOW}>>> $title${NC}"
  echo -e "${BLUE}==========================================================${NC}\n"

  if [ ! -f "$BASE_DIR/$script" ]; then
    echo -e "${RED}ERRO: Script não encontrado: $script${NC}"
    exit 1
  fi

  bash "$BASE_DIR/$script"
}

check_root

echo -e "${GREEN}==========================================================${NC}"
echo -e "${GREEN}   INSTALAÇÃO COMPLETA DO STACK UNBOUND + MONITORAMENTO   ${NC}"
echo -e "${GREEN}==========================================================${NC}"

# --- DNS ---
run_step "Instalação e configuração do Unbound" "setup_unbound.sh"

# --- Monitoramento ---
run_step "Instalação do Unbound Exporter" "monitoring/install_unbound_exporter.sh"
run_step "Instalação Prometheus + Grafana" "monitoring/install_prometheus_grafana.sh"

# --- Validação final ---
echo -e "\n${BLUE}Validando serviços...${NC}"
systemctl status unbound --no-pager || true
systemctl status unbound_exporter --no-pager || true
systemctl status prometheus --no-pager || true
systemctl status grafana-server --no-pager || true

echo -e "\n${BLUE}Testando métricas...${NC}"
curl -s http://127.0.0.1:9167/metrics | head || true
curl -s http://127.0.0.1:9100/metrics | head || true

echo -e "\n${GREEN}Stack instalado e validado com sucesso.${NC}"
