#!/bin/bash
# Pergunta blocos IPv4/IPv6 e ajusta ACLs em 52-acls-trusteds.conf

set -e

LOG_FILE="/var/log/unbound_network_blocks.log"
ERROR_LOG="/var/log/unbound_network_blocks_error.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
NC='\033[0m'

mkdir -p /var/log
touch "$LOG_FILE" "$ERROR_LOG"

log() {
  echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
  echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE" "$ERROR_LOG"
}

log_success() {
  echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $1" | tee -a "$LOG_FILE"
}

if [ "$EUID" -ne 0 ]; then
  log_error "Este script deve ser executado como root."
  echo -e "${RED}Este script deve ser executado como root.${NC}"
  exit 1
fi

validate_ipv4_cidr() {
  local ip="$1"
  if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(\/[0-9]{1,2})?$ ]]; then
    IFS='/' read -r base mask <<< "$ip"
    IFS='.' read -r o1 o2 o3 o4 <<< "$base"
    for o in "$o1" "$o2" "$o3" "$o4"; do
      [ "$o" -gt 255 ] && return 1
    done
    if [ -n "$mask" ] && [ "$mask" -gt 32 ]; then
      return 1
    fi
    return 0
  fi
  return 1
}

validate_ipv6_cidr() {
  local ip="$1"
  # Validação simples de formato
  if [[ $ip =~ ^[0-9a-fA-F:]+(\/[0-9]{1,3})?$ ]]; then
    return 0
  fi
  return 1
}

echo -e "\n${BLUE}===== Configuração de ACLs do Unbound (blocos de IP) =====${NC}"

# 1) IPv4 públicos
echo -e "\n${YELLOW}Digite os blocos IPv4 PÚBLICOS (clientes / servidores) que podem usar o DNS.${NC}"
echo -e "${BLUE}Exemplo:${NC} 200.200.200.0/24  201.10.0.0/22"
echo -e "${BLUE}Deixe em branco para não adicionar blocos IPv4 públicos adicionais.${NC}"
read -r IPV4_PUBLIC_INPUT

IPV4_PUBLIC_VALID=()
if [ -n "$IPV4_PUBLIC_INPUT" ]; then
  for ip in $IPV4_PUBLIC_INPUT; do
    if validate_ipv4_cidr "$ip"; then
      IPV4_PUBLIC_VALID+=("$ip")
    else
      echo -e "${YELLOW}IPv4 inválido ignorado: $ip${NC}"
      log_error "IPv4 inválido ignorado: $ip"
    fi
  done
fi

# 2) IPv6 públicos
echo -e "\n${YELLOW}Digite os blocos IPv6 PÚBLICOS (clientes / servidores) que podem usar o DNS.${NC}"
echo -e "${BLUE}Exemplo:${NC} 2804:1234::/48  2804:abcd:1::/64"
echo -e "${BLUE}Deixe em branco se não tiver IPv6 ou não quiser liberar blocos IPv6 públicos agora.${NC}"
read -r IPV6_PUBLIC_INPUT

IPV6_PUBLIC_VALID=()
if [ -n "$IPV6_PUBLIC_INPUT" ]; then
  for ip in $IPV6_PUBLIC_INPUT; do
    if validate_ipv6_cidr "$ip"; then
      IPV6_PUBLIC_VALID+=("$ip")
    else
      echo -e "${YELLOW}IPv6 inválido ignorado: $ip${NC}"
      log_error "IPv6 inválido ignorado: $ip"
    fi
  done
fi

# 3) IPv4 locais extras (além de RFC1918/CGNAT já configurados)
echo -e "\n${YELLOW}Digite blocos IPv4 LOCAIS adicionais (se houver).${NC}"
echo -e "${BLUE}Exemplo:${NC} 192.0.2.0/24  198.51.100.0/24"
echo -e "${BLUE}Deixe em branco se não precisar de faixas extras.${NC}"
read -r IPV4_LOCAL_EXTRA_INPUT

IPV4_LOCAL_EXTRA_VALID=()
if [ -n "$IPV4_LOCAL_EXTRA_INPUT" ]; then
  for ip in $IPV4_LOCAL_EXTRA_INPUT; do
    if validate_ipv4_cidr "$ip"; then
      IPV4_LOCAL_EXTRA_VALID+=("$ip")
    else
      echo -e "${YELLOW}IPv4 local extra inválido ignorado: $ip${NC}"
      log_error "IPv4 local extra inválido ignorado: $ip"
    fi
  done
fi

ACL_FILE="/etc/unbound/unbound.conf.d/52-acls-trusteds.conf"

log "Gravando ACLs em $ACL_FILE..."

{
  echo "server:"
  echo "    # Redes públicas IPv4 autorizadas a usar este resolver"
  if [ "${#IPV4_PUBLIC_VALID[@]}" -gt 0 ]; then
    for ip in "${IPV4_PUBLIC_VALID[@]}"; do
      echo "    access-control: ${ip} allow"
    done
  else
    echo "    # Nenhum bloco IPv4 público adicional configurado aqui."
  fi

  echo
  echo "    # Redes públicas IPv6 autorizadas a usar este resolver"
  if [ "${#IPV6_PUBLIC_VALID[@]}" -gt 0 ]; then
    for ip in "${IPV6_PUBLIC_VALID[@]}"; do
      echo "    access-control: ${ip} allow"
    done
  else
    echo "    # Nenhum bloco IPv6 público adicional configurado aqui."
  fi

  echo
  echo "    # Blocos IPv4 locais extras autorizados"
  if [ "${#IPV4_LOCAL_EXTRA_VALID[@]}" -gt 0 ]; then
    for ip in "${IPV4_LOCAL_EXTRA_VALID[@]}"; do
      echo "    access-control: ${ip} allow"
    done
  else
    echo "    # Nenhum bloco IPv4 local extra configurado aqui."
  fi
} > "$ACL_FILE"

log_success "ACLs salvas em $ACL_FILE."

echo -e "${GREEN}ACLs configuradas com sucesso.${NC}"
echo -e "${BLUE}Você pode editar depois em:${NC} $ACL_FILE"
