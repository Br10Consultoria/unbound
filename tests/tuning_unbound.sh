#!/bin/bash
# Aplica tuning automático no Unbound com base em CPU/RAM
# e (opcionalmente) ajustes de kernel.

set -e

LOG_FILE="/var/log/unbound_tuning.log"
ERROR_LOG="/var/log/unbound_tuning_error.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
NC='\033[0m'

# Se quiser habilitar tuning de kernel, altere para "true"
ENABLE_KERNEL_TUNING="false"

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

detect_system_resources() {
  log "Detectando recursos do sistema..."

  NUM_CPUS=$(nproc)
  TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  TOTAL_MEM=$((TOTAL_MEM_KB / 1024))

  log "CPUs: $NUM_CPUS | Memória: ${TOTAL_MEM}MB"

  if [ "$NUM_CPUS" -gt 4 ]; then
    UNBOUND_THREADS=4
  else
    UNBOUND_THREADS="$NUM_CPUS"
  fi
  [ "$UNBOUND_THREADS" -lt 1 ] && UNBOUND_THREADS=1

  MSG_CACHE_SIZE=$((TOTAL_MEM / 4))
  [ "$MSG_CACHE_SIZE" -gt 4096 ] && MSG_CACHE_SIZE=4096
  [ "$MSG_CACHE_SIZE" -lt 64 ] && MSG_CACHE_SIZE=64

  RRSET_CACHE_SIZE=$((TOTAL_MEM / 8))
  [ "$RRSET_CACHE_SIZE" -gt 2048 ] && RRSET_CACHE_SIZE=2048
  [ "$RRSET_CACHE_SIZE" -lt 32 ] && RRSET_CACHE_SIZE=32

  if [ "$TOTAL_MEM" -gt 8192 ]; then
    QUERIES_PER_THREAD=4096
  elif [ "$TOTAL_MEM" -gt 4096 ]; then
    QUERIES_PER_THREAD=2048
  elif [ "$TOTAL_MEM" -gt 2048 ]; then
    QUERIES_PER_THREAD=1024
  else
    QUERIES_PER_THREAD=512
  fi

  if [ "$UNBOUND_THREADS" -gt 1 ]; then
    NUM_SLABS="$UNBOUND_THREADS"
  else
    NUM_SLABS=2
  fi

  log "Tuning calculado -> threads=$UNBOUND_THREADS, msg_cache=${MSG_CACHE_SIZE}m, rrset_cache=${RRSET_CACHE_SIZE}m, qpt=$QUERIES_PER_THREAD, slabs=$NUM_SLABS"
}

apply_unbound_tuning() {
  log "Aplicando tuning em /etc/unbound/unbound.conf.d/61-configs.conf..."

  cat << EOF > /etc/unbound/unbound.conf.d/61-configs.conf
server:
    outgoing-range: 8192
    outgoing-port-avoid: 0-1024
    outgoing-port-permit: 1025-65535
    num-threads: ${UNBOUND_THREADS}
    num-queries-per-thread: ${QUERIES_PER_THREAD}
    msg-cache-size: ${MSG_CACHE_SIZE}m
    msg-cache-slabs: ${NUM_SLABS}
    rrset-cache-size: ${RRSET_CACHE_SIZE}m
    rrset-cache-slabs: ${NUM_SLABS}
    cache-min-ttl: 60
    cache-max-ttl: 7200
    infra-host-ttl: 60
    infra-lame-ttl: 120
    infra-cache-numhosts: 10000
    infra-cache-lame-size: 10k
    infra-cache-slabs: ${NUM_SLABS}
    key-cache-slabs: ${NUM_SLABS}
    rrset-roundrobin: yes

    hide-identity: yes
    hide-version: yes
    harden-glue: yes
    harden-algo-downgrade: yes
    harden-below-nxdomain: yes
    harden-dnssec-stripped: yes
    harden-large-queries: yes
    harden-referral-path: no
    harden-short-bufsize: yes
    do-not-query-address: 127.0.0.1/8
    do-not-query-localhost: yes
    edns-buffer-size: 1472
    aggressive-nsec: yes
    delay-close: 10000
    neg-cache-size: 4M
    qname-minimisation: yes
    deny-any: yes
    ratelimit: 1000
    unwanted-reply-threshold: 10000
    use-caps-for-id: yes
    val-clean-additional: yes
    minimal-responses: yes
    prefetch: yes
    prefetch-key: yes
    serve-expired: yes
    so-reuseport: yes
EOF

  log_success "Tuning gravado em 61-configs.conf."
}

optimize_kernel() {
  log "Otimização de kernel habilitada. Ajustando /etc/sysctl.conf..."

  SYSCTL_BACKUP="/etc/sysctl.conf.bak.$(date +%Y%m%d%H%M%S)"
  cp /etc/sysctl.conf "$SYSCTL_BACKUP" 2>/dev/null || true
  log "Backup criado em $SYSCTL_BACKUP"

  cat << 'EOF' >> /etc/sysctl.conf

# Ajustes para servidor DNS / rede - adicionados pelo tuning_unbound.sh
vm.swappiness = 5
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5

net.core.somaxconn = 65535
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_mem = 4096 87380 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_fin_timeout = 15
net.core.netdev_max_backlog = 8192
net.ipv4.ip_local_port_range = 1024 65535

net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF

  sysctl -p >>"$LOG_FILE" 2>>"$ERROR_LOG" || true
  log_success "Parâmetros de kernel aplicados (sysctl -p)."
}

detect_system_resources
apply_unbound_tuning

if [ "$ENABLE_KERNEL_TUNING" = "true" ]; then
  optimize_kernel
else
  log "Tuning de kernel desabilitado (ENABLE_KERNEL_TUNING=false)."
fi

log "Reiniciando serviço unbound..."
systemctl restart unbound >>"$LOG_FILE" 2>>"$ERROR_LOG" || true
sleep 2

if systemctl.is-active unbound >/dev/null 2>&1; then
  log_success "Unbound reiniciado com sucesso após tuning."
else
  log_error "Unbound não está ativo após tuning. Verifique logs."
fi

echo -e "${GREEN}Tuning automático do Unbound aplicado.${NC}"
