#!/bin/bash
# Orquestrador da instalação do Unbound
# Agora com verificação automática de dependências

set -e

BLUE='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

REQUIRED_PACKAGES=(
  curl
  wget
  ca-certificates
  dnsutils
  net-tools
  systemd
)

check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Este script deve ser executado como root.${NC}"
    echo -e "Use: ${YELLOW}sudo $0${NC}"
    exit 1
  fi
}

check_dependencies() {
  echo -e "\n${BLUE}=== Verificando dependências do sistema ===${NC}"

  apt-get update -y >/dev/null 2>&1

  for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      echo -e "${YELLOW}Pacote ausente: $pkg — instalando...${NC}"
      apt-get install -y "$pkg" >/dev/null 2>&1
    else
      echo -e "${GREEN}OK:${NC} $pkg instalado."
    fi
  done

  echo -e "${GREEN}Todas as dependências foram verificadas.${NC}"
}

run_step() {
  local title="$1"
  local script="$2"

  echo -e "\n${BLUE}==========================================================${NC}"
  echo -e "${YELLOW}>>> $title${NC}"
  echo -e "${BLUE}==========================================================${NC}\n"

  bash "$BASE_DIR/$script"
}

# ---------- Execução ----------
check_root
check_dependencies

echo -e "\n${GREEN}==========================================================${NC}"
echo -e "${GREEN}  INSTALAÇÃO E CONFIGURAÇÃO DO UNBOUND (RESOLVER DNS)     ${NC}"
echo -e "${GREEN}  SEM AnaBlock / SEM UFW / TUNING AUTOMÁTICO              ${NC}"
echo -e "${GREEN}==========================================================${NC}\n"

run_step "Instalação base do Unbound" "install_unbound.sh"
run_step "Tuning automático do Unbound" "tuning_unbound.sh"
run_step "Configuração das ACLs (blocos IPv4/IPv6)" "configure_network_blocks.sh"

echo -e "\n${BLUE}Reiniciando serviço unbound (final)...${NC}"
systemctl restart unbound || true
sleep 2

echo -e "\n${BLUE}Status do serviço:${NC}"
systemctl status unbound --no-pager || true

echo -e "\n${BLUE}Testes DNS:${NC}"
nslookup www.google.com 127.0.0.1 || true
host www.google.com 127.0.0.1 || true
dig @127.0.0.1 www.google.com || true

echo -e "\n${GREEN}Instalação finalizada com sucesso.${NC}"
