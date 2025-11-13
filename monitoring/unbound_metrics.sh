#!/bin/bash
# Gera métricas do Unbound em formato Prometheus (textfile para node_exporter)

OUTDIR="/var/lib/node_exporter"
OUTFILE="${OUTDIR}/unbound.prom"
TMPFILE="$(mktemp)"

# Se unbound-control não existir, sai silencioso
if ! command -v unbound-control >/dev/null 2>&1; then
  exit 0
fi

mkdir -p "$OUTDIR"

# Coleta estatísticas (sem reset)
if ! unbound-control stats_noreset > "$TMPFILE" 2>/dev/null; then
  rm -f "$TMPFILE"
  exit 0
fi

{
  echo "# HELP unbound_stats Métricas do Unbound via stats_noreset."
  echo "# TYPE unbound_stats gauge"
} > "$OUTFILE"

# Cada linha é key=value
# Exemplo:
#   num.queries=12345
#   num.cachehits=12000
#   num.cachemiss=345
while IFS='=' read -r KEY VAL; do
  [ -z "$KEY" ] && continue
  # Ignora linhas estranhas
  if ! echo "$VAL" | grep -Eq '^[0-9]+(\.[0-9]+)?$'; then
    continue
  fi

  # Normaliza nome da métrica: pontos/hífens viram underscore
  METRIC_NAME=$(echo "$KEY" | tr '.' '_' | tr '-' '_')

  # Exemplo final:
  #   unbound_num_queries 12345
  echo "unbound_${METRIC_NAME} $VAL"
done < "$TMPFILE" >> "$OUTFILE"

rm -f "$TMPFILE"
