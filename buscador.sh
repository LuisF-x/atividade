#!/usr/bin/env bash
# buscador.sh - Resultados do TSE por município do Maranhão.
# Mostra os candidatos mais votados por cargo, separados por turno,
# indicando quem foi eleito.

set -Eeuo pipefail

readonly DEFAULT_BASE_URL="https://resultados.tse.jus.br/oficial"

# --- Configuração (variáveis de ambiente; podem ser trocadas por opções) -----
BASE_URL="${TSE_RESULTS_BASE_URL:-$DEFAULT_BASE_URL}"
YEAR="${TSE_RESULTS_YEAR:-2026}"
UF="${TSE_RESULTS_UF:-ma}"
MUNICIPIO="${TSE_RESULTS_MUNICIPALITY:-}"   # vazio = todos os municípios da UF
LIMIT="${TSE_RESULTS_LIMIT:-20}"
TURNO="${TSE_RESULTS_TURN:-all}"            # 1, 2 ou all
COLOR_MODE="${TSE_RESULTS_COLOR:-auto}"

# Códigos de eleição no TSE (1º turno já vinham no script original).
FEDERAL_ELECTION_T1="${TSE_RESULTS_FEDERAL_ELECTION:-6257}"
STATE_ELECTION_T1="${TSE_RESULTS_STATE_ELECTION:-6259}"
# Códigos do 2º turno: informe-os (veja o README, seção "2º turno").
FEDERAL_ELECTION_T2="${TSE_RESULTS_FEDERAL_ELECTION_T2:-}"
STATE_ELECTION_T2="${TSE_RESULTS_STATE_ELECTION_T2:-}"

# Cargos: 1 presidente, 3 governador, 5 senador, 6 dep. federal, 7 dep. estadual.
readonly -a CARGOS_T1=(6 7 5 3 1)
readonly -a CARGOS_T2=(3 1)   # só presidente e governador têm 2º turno

readonly name_header="NOME" number_header="NÚMERO" votes_header="VOTOS" status_header="SITUAÇÃO"

# --- Utilidades ---------------------------------------------------------------
die()  { printf 'Erro: %s\n' "$*" >&2; exit 1; }
warn() { printf 'Aviso: %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Uso: ${0##*/} [-t 1|2|all] [-m CODIGO_MUNICIPIO] [-n LIMITE] [-h]

  -t  turno a consultar: 1, 2 ou all (padrão: all)
  -m  código TSE (5 dígitos) de um único município (padrão: todos da UF)
  -n  máximo de candidatos por cargo (padrão: $LIMIT); eleitos sempre aparecem
  -h  mostra esta ajuda

Variáveis úteis: TSE_RESULTS_UF, TSE_RESULTS_YEAR, TSE_RESULTS_COLOR,
TSE_RESULTS_FEDERAL_ELECTION_T2, TSE_RESULTS_STATE_ELECTION_T2.
EOF
}

while getopts ':t:m:n:h' opt; do
  case "$opt" in
    t) TURNO="$OPTARG" ;;
    m) MUNICIPIO="$OPTARG" ;;
    n) LIMIT="$OPTARG" ;;
    h) usage; exit 0 ;;
    :) die "a opção -$OPTARG exige um valor" ;;
    *) usage >&2; die "opção inválida: -$OPTARG" ;;
  esac
done

command -v curl >/dev/null || die "curl não encontrado (instale com: sudo apt install curl)"
command -v jq   >/dev/null || die "jq não encontrado (instale com: sudo apt install jq)"

[[ "$UF" =~ ^[[:alpha:]]{2}$ ]]              || die "UF deve conter duas letras"
[[ -z "$MUNICIPIO" || "$MUNICIPIO" =~ ^[0-9]{5}$ ]] || die "município deve conter cinco dígitos"
[[ "$YEAR" =~ ^[0-9]{4}$ ]]                  || die "ano deve conter quatro dígitos"
[[ "$LIMIT" =~ ^[1-9][0-9]*$ ]]              || die "limite deve ser um inteiro positivo"
[[ "$TURNO" =~ ^(1|2|all)$ ]]                || die "turno deve ser 1, 2 ou all"
[[ "$COLOR_MODE" =~ ^(auto|always|never)$ ]] || die "TSE_RESULTS_COLOR deve ser auto, always ou never"
for code in "$FEDERAL_ELECTION_T1" "$STATE_ELECTION_T1" "$FEDERAL_ELECTION_T2" "$STATE_ELECTION_T2"; do
  [[ -z "$code" || "$code" =~ ^[0-9]+$ ]] || die "códigos de eleição devem ser numéricos"
done

UF="${UF,,}"
BASE_URL="${BASE_URL%/}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

use_color=false
if [[ "$COLOR_MODE" == always ]] || { [[ "$COLOR_MODE" == auto && -t 1 && "${TERM:-dumb}" != dumb ]] && [[ ! -v NO_COLOR ]]; }; then
  use_color=true
fi

# --- Rede ----------------------------------------------------------------------
fetch() { # fetch URL ARQUIVO
  curl --fail --silent --location \
    --retry 3 --retry-all-errors --connect-timeout 10 --max-time 30 \
    --output "$2" "$1" 2>/dev/null
}

# --- Tabela --------------------------------------------------------------------
print_rule() {
  printf '+-%*s-+-%*s-+-%*s-+-%*s-+\n' "$1" '' "$2" '' "$3" '' "$4" '' | tr ' ' '-'
}

print_table() {
  local -n table_rows="$1"
  local name_w=${#name_header} num_w=${#number_header} votes_w=${#votes_header} st_w=${#status_header}
  local row name number votes status

  for row in "${table_rows[@]}"; do
    IFS=$'\t' read -r name number votes status <<<"$row"
    (( ${#name}   > name_w  )) && name_w=${#name}
    (( ${#number} > num_w   )) && num_w=${#number}
    (( ${#votes}  > votes_w )) && votes_w=${#votes}
    (( ${#status} > st_w    )) && st_w=${#status}
  done

  print_rule "$name_w" "$num_w" "$votes_w" "$st_w"
  printf '| %-*s | %*s | %*s | %-*s |\n' "$name_w" "$name_header" "$num_w" "$number_header" \
    "$votes_w" "$votes_header" "$st_w" "$status_header"
  print_rule "$name_w" "$num_w" "$votes_w" "$st_w"

  for row in "${table_rows[@]}"; do
    IFS=$'\t' read -r name number votes status <<<"$row"
    if $use_color && [[ "$status" == ELEITO* ]]; then
      printf '| \033[1;32m%-*s | %*s | %*s | %-*s\033[0m |\n' "$name_w" "$name" "$num_w" "$number" \
        "$votes_w" "$votes" "$st_w" "$status"
    else
      printf '| %-*s | %*s | %*s | %-*s |\n' "$name_w" "$name" "$num_w" "$number" \
        "$votes_w" "$votes" "$st_w" "$status"
    fi
  done
  print_rule "$name_w" "$num_w" "$votes_w" "$st_w"
}

# --- Regras de negócio -----------------------------------------------------------
election_for_cargo() { # election_for_cargo TURNO CARGO
  local turno="$1" cargo="$2"
  case "$cargo" in
    1)       [[ "$turno" == 1 ]] && printf '%s' "$FEDERAL_ELECTION_T1" || printf '%s' "$FEDERAL_ELECTION_T2" ;;
    3|5|6|7) [[ "$turno" == 1 ]] && printf '%s' "$STATE_ELECTION_T1"   || printf '%s' "$STATE_ELECTION_T2" ;;
    *)       die "cargo não suportado: $cargo" ;;
  esac
}

list_municipios() { # imprime "codigo<TAB>nome" para todos os municípios da UF
  local padded file="$tmp_dir/municipios.json"
  printf -v padded '%06d' "$STATE_ELECTION_T1"
  fetch "$BASE_URL/ele$YEAR/$STATE_ELECTION_T1/config/mun-e$padded-cm.json" "$file" \
    || die "não foi possível obter a lista de municípios; use -m CODIGO para consultar um município"
  jq -r --arg uf "$UF" '
    .abr[] | select((.cd | ascii_downcase) == $uf) | .mu[] | [.cd, .nm] | @tsv
  ' "$file" > "$tmp_dir/municipios.tsv" || die "lista de municípios em formato inesperado"
  [[ -s "$tmp_dir/municipios.tsv" ]] || die "nenhum município encontrado para a UF '$UF'"
  cat "$tmp_dir/municipios.tsv"
}

show_cargo() { # show_cargo TURNO CARGO MUNICIPIO_CODIGO
  local turno="$1" cargo="$2" mun="$3" election padded_c padded_e file url cargo_name
  election="$(election_for_cargo "$turno" "$cargo")"
  if [[ -z "$election" ]]; then
    warn "turno $turno, cargo $cargo ignorado: código de eleição não informado"
    return 0
  fi

  file="$tmp_dir/t$turno-c$cargo-$mun.json"
  printf -v padded_c '%04d' "$cargo"
  printf -v padded_e '%06d' "$election"
  url="$BASE_URL/ele$YEAR/$election/dados/$UF/${UF}${mun}-c${padded_c}-e${padded_e}-u.json"

  if ! fetch "$url" "$file"; then
    printf '\n  Cargo %s: sem dados disponíveis neste turno\n' "$cargo"
    return 0
  fi
  if ! jq -e '.carg | type == "array"' "$file" >/dev/null 2>&1; then
    warn "resposta inválida para o cargo $cargo ($url)"
    return 0
  fi

  cargo_name="$(jq -r --arg cargo "$cargo" '.carg[] | select(.cd == $cargo) | .nmn' "$file" | head -n 1)"
  if [[ -z "$cargo_name" ]]; then
    printf '\n  Cargo %s: sem dados disponíveis neste turno\n' "$cargo"
    return 0
  fi

  printf '\n  %s (cargo %s)\n' "$cargo_name" "$cargo"

  # Top N por votos + todos os eleitos (mesmo fora do top N).
  jq -r --arg cargo "$cargo" --argjson limit "$LIMIT" '
    [
      .carg[] | select(.cd == $cargo)
      | .. | objects | .cand? // empty | .[]
      | select((.nmu // "") != "" and (.n // "") != "")
      | {
          nome: (.nmu | gsub("[[:cntrl:]]"; " ")),
          numero: .n,
          votos: ((.vap // "0") | tonumber),
          eleito: ((((.e // "") | tostring | ascii_downcase) == "s")
                   or (((.st // "") | tostring) | test("^eleito"; "i")))
        }
    ]
    | unique_by(.numero)
    | sort_by([-.votos, (.nome | ascii_downcase), .numero])
    | (.[:$limit] + (.[$limit:] | map(select(.eleito))))[]
    | [.nome, .numero, (.votos | tostring), (if .eleito then "ELEITO" else "-" end)] | @tsv
  ' "$file" >"$tmp_dir/rows.tsv" || { warn "falha ao processar o cargo $cargo"; return 0; }

  mapfile -t rows <"$tmp_dir/rows.tsv"
  if (( ${#rows[@]} == 0 )); then
    printf '  (sem candidatos)\n'
  else
    print_table rows
  fi
}

show_turno() { # show_turno TURNO MUNICIPIO_CODIGO
  local turno="$1" mun="$2" cargo
  local -a cargos
  if [[ "$turno" == 1 ]]; then cargos=("${CARGOS_T1[@]}"); else cargos=("${CARGOS_T2[@]}"); fi
  printf '\n--- %sº TURNO ---\n' "$turno"
  for cargo in "${cargos[@]}"; do
    show_cargo "$turno" "$cargo" "$mun"
  done
}

# --- Execução principal -----------------------------------------------------------
if [[ -n "$MUNICIPIO" ]]; then
  municipios="$MUNICIPIO"$'\t'"$MUNICIPIO"
else
  municipios="$(list_municipios)"
fi

turnos=()
case "$TURNO" in
  all) turnos=(1 2) ;;
  *)   turnos=("$TURNO") ;;
esac

if [[ -z "$FEDERAL_ELECTION_T2$STATE_ELECTION_T2" ]]; then
  [[ "$TURNO" == 2 ]] && die "2º turno: informe TSE_RESULTS_FEDERAL_ELECTION_T2 e/ou TSE_RESULTS_STATE_ELECTION_T2"
  [[ "$TURNO" == all ]] && warn "códigos do 2º turno não informados; consultando apenas o 1º turno"
  turnos=(1)
fi

while IFS=$'\t' read -r mun_code mun_name; do
  [[ -n "$mun_code" ]] || continue
  printf '\n=========================================\n'
  printf 'MUNICÍPIO: %s (%s/%s)\n' "$mun_name" "${UF^^}" "$mun_code"
  printf '=========================================\n'
  for turno in "${turnos[@]}"; do
    show_turno "$turno" "$mun_code"
  done
done <<<"$municipios"
