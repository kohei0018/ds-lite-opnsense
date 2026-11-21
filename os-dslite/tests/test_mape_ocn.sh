#!/bin/sh
# Ground truth from a Buffalo WSR-5400AX6 running OCN Virtual Connect on this
# line. Run from anywhere with: sh os-dslite/tests/test_mape_ocn.sh
set -u
DIR=$(cd "$(dirname "$0")/../src/opnsense/scripts/OPNsense/dslite" && pwd)
. "${DIR}/lib.sh"
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$2' want '$3'"; fail=1; fi; }

mape_profile_lookup ocn
check "ocn profile BR"     "${MAPE_P_BR}"     "2001:380:a120::9"
check "ocn profile offset" "${MAPE_P_OFFSET}" "6"
check "ocn profile format" "${MAPE_P_CEFMT}"  "draft03"

set -- $(mape_derive 2400:4052:1b84:8f00::/56 2400:4052:1000::/36 153.134.0.0/18 20 6 draft03)
check "ipv4"       "$1" "153.134.46.18"
check "psid"       "$2" "15"
check "psid len"   "$3" "6"
check "ce address" "$4" "2400:4052:1b84:8f00:99:862e:1200:f00"
check "ranges"     "$5" "63"
check "ports"      "$6" "1008"

got=$(mape_port_ranges 6 6 15 | awk '{printf "%s%s-%s", (NR>1?",":""), $1, $2}')
want="1264-1279,2288-2303,3312-3327,4336-4351,5360-5375,6384-6399,7408-7423,8432-8447,9456-9471,10480-10495,11504-11519,12528-12543,13552-13567,14576-14591,15600-15615,16624-16639,17648-17663,18672-18687,19696-19711,20720-20735,21744-21759,22768-22783,23792-23807,24816-24831,25840-25855,26864-26879,27888-27903,28912-28927,29936-29951,30960-30975,31984-31999,33008-33023,34032-34047,35056-35071,36080-36095,37104-37119,38128-38143,39152-39167,40176-40191,41200-41215,42224-42239,43248-43263,44272-44287,45296-45311,46320-46335,47344-47359,48368-48383,49392-49407,50416-50431,51440-51455,52464-52479,53488-53503,54512-54527,55536-55551,56560-56575,57584-57599,58608-58623,59632-59647,60656-60671,61680-61695,62704-62719,63728-63743,64752-64767"
check "port ranges" "${got}" "${want}"

# Regressions: default stays RFC 7597, and a prefix outside the rule is refused.
set -- $(mape_derive 2400:4052:1b84:8f00::/56 2400:4052:1000::/36 153.134.0.0/18 20 6)
check "rfc default ce" "$4" "2400:4052:1b84:8f00:0:9986:2e12:f"
check "outside rule refused" "$(mape_derive 2400:4052:2b84:8f00::/56 2400:4052:1000::/36 153.134.0.0/18 20 6 draft03)" ""
check "bad format refused"   "$(mape_derive 2400:4052:1b84:8f00::/56 2400:4052:1000::/36 153.134.0.0/18 20 6 bogus)" ""

exit ${fail}
