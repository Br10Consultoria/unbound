#!/bin/bash
# Testes avançados de saúde do Unbound (DNS + DNSSEC)

DNS_IP="127.0.0.1"
LOG_FILE="/var/log/unbound_dnssec_test.log"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
NC='\033[0m'

log() {
  echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

echo -e "\n${BLUE}===== Testes avançados de DNS / DNSSEC =====${NC}"
log "Iniciando testes DNS/DNSSEC no servidor $DNS_IP"

RET=0

# 1) Teste A IPv4 (google.com)
echo -e "\n${YELLOW}1) Teste básico A (IPv4) - www.google.com${NC}"
A_ANS=$(dig @"${DNS_IP}" www.google.com A +short 2>/dev/null)
echo "$A_ANS"
if [ -n "$A_ANS" ]; then
  echo -e "${GREEN}[OK] www.google.com (A) resolvido.${NC}"
  log "OK: www.google.com A ($A_ANS)"
else
  echo -e "${RED}[FAIL] Não resolveu www.google.com (A).${NC}"
  log "FAIL: www.google.com A"
  RET=1
fi

# 2) Teste AAAA IPv6 (google.com)
echo -e "\n${YELLOW}2) Teste AAAA (IPv6) - www.google.com${NC}"
AAAA_ANS=$(dig @"${DNS_IP}" www.google.com AAAA +short 2>/dev/null)
echo "$AAAA_ANS"
if [ -n "$AAAA_ANS" ]; then
  echo -e "${GREEN}[OK] www.google.com (AAAA) resolvido.${NC}"
  log "OK: www.google.com AAAA ($AAAA_ANS)"
else
  echo -e "${YELLOW}[WARN] IPv6 AAAA não retornou. Verifique se o host tem IPv6 funcional.${NC}"
  log "WARN: www.google.com AAAA vazio"
fi

# 3) Teste DNSSEC em domínio assinado
echo -e "\n${YELLOW}3) Teste DNSSEC (domínio assinado - cloudflare.com)${NC}"
dig @"${DNS_IP}" cloudflare.com A +dnssec +multi

FLAGS=$(dig @"${DNS_IP}" cloudflare.com A +dnssec +multi +noall +comments 2>/dev/null \
  | sed -n 's/;; flags: \(.*\);.*/\1/p')

if echo "$FLAGS" | grep -q "ad"; then
  echo -e "${GREEN}[OK] DNSSEC: flag AD presente para cloudflare.com.${NC}"
  log "OK: DNSSEC AD em cloudflare.com (flags: $FLAGS)"
else
  echo -e "${YELLOW}[WARN] DNSSEC: flag AD NÃO apareceu em cloudflare.com (flags: $FLAGS).${NC}"
  log "WARN: sem AD em cloudflare.com (flags: $FLAGS)"
fi

# 4) Teste de domínio com DNSSEC quebrado
echo -e "\n${YELLOW}4) Teste domínio com DNSSEC quebrado (dnssec-failed.org)${NC}"
dig @"${DNS_IP}" dnssec-failed.org A +dnssec +multi

STATUS=$(dig @"${DNS_IP}" dnssec-failed.org A +dnssec +multi +noall +comments 2>/dev/null \
  | sed -n 's/;; ->>HEADER<<-.* status: \([A-Z]*\),.*/\1/p')

if [ "$STATUS" = "SERVFAIL" ]; then
  echo -e "${GREEN}[OK] dnssec-failed.org retornou SERVFAIL (esperado com DNSSEC válido).${NC}"
  log "OK: dnssec-failed.org SERVFAIL (DNSSEC funcionando)"
else
  echo -e "${YELLOW}[WARN] dnssec-failed.org NÃO retornou SERVFAIL (status=$STATUS). Verifique validação DNSSEC.${NC}"
  log "WARN: dnssec-failed.org status=$STATUS"
fi

# 5) Teste de recursão + trace (uol.com.br)
echo -e "\n${YELLOW}5) Teste de recursão com +trace (uol.com.br)${NC}"
dig @"${DNS_IP}" www.uol.com.br +trace

# 6) Verifica se auth-zone da raiz está carregada (hyperlocal)
echo -e "\n${YELLOW}6) Verificando auth-zone da raiz (hyperlocal cache)${NC}"
if command -v unbound-control >/dev/null 2>&1; then
  AZ=$(unbound-control list_auth_zones 2>/dev/null | grep -E '^\.\s')
  if [ -n "$AZ" ]; then
    echo -e "${GREEN}[OK] auth-zone \".\" está carregada: ${AZ}${NC}"
    log "OK: auth-zone . -> $AZ"
  else
    echo -e "${YELLOW}[WARN] auth-zone \".\" não encontrada em list_auth_zones.${NC}"
    log "WARN: auth-zone . não encontrada"
  fi
else
  echo -e "${YELLOW}[WARN] unbound-control não encontrado no PATH. Pular teste de auth-zone.${NC}"
  log "WARN: unbound-control ausente"
fi

# 7) Checar se root.key existe
echo -e "\n${YELLOW}7) Verificando root.key (DNSSEC trust anchor)${NC}"
if [ -f /var/lib/unbound/root.key ]; then
  echo -e "${GREEN}[OK] /var/lib/unbound/root.key encontrado.${NC}"
  log "OK: root.key presente."
else
  echo -e "${YELLOW}[WARN] /var/lib/unbound/root.key NÃO encontrado. unbound-anchor pode não ter rodado corretamente.${NC}"
  log "WARN: root.key ausente."
fi

echo -e "\n${BLUE}===== Fim dos testes DNS/DNSSEC =====${NC}"
log "Fim dos testes com retorno=$RET."
exit $RET
