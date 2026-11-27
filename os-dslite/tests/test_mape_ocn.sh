#!/bin/sh
# OCN Virtual Connect MAP-E derivation test.
#
# The prefix below is a made-up example inside OCN's 2400:4052:1000::/36 rule;
# the expected values were computed by a separate implementation. The same
# derivation was also checked against a Buffalo WSR-5400AX6 running OCN VC on a
# live line (IPv4, CE address and all 63 port ranges matched); that line's real
# prefix is deliberately not recorded here.
#
# Run from anywhere with: sh os-dslite/tests/test_mape_ocn.sh
set -u
DIR=$(cd "$(dirname "$0")/../src/opnsense/scripts/OPNsense/dslite" && pwd)
. "${DIR}/lib.sh"
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$2' want '$3'"; fail=1; fi; }

mape_profile_lookup ocn
check "ocn profile BR"     "${MAPE_P_BR}"     "2001:380:a120::9"
check "ocn profile offset" "${MAPE_P_OFFSET}" "6"
check "ocn profile format" "${MAPE_P_CEFMT}"  "draft03"

set -- $(mape_derive 2400:4052:1234:5600::/56 2400:4052:1000::/36 153.134.0.0/18 20 6 draft03)
check "ipv4"       "$1" "153.134.8.209"
check "psid"       "$2" "22"
check "psid len"   "$3" "6"
check "ce address" "$4" "2400:4052:1234:5600:99:8608:d100:1600"
check "ranges"     "$5" "63"
check "ports"      "$6" "1008"

got=$(mape_port_ranges 6 6 22 | awk '{printf "%s%s-%s", (NR>1?",":""), $1, $2}')
want="1376-1391,2400-2415,3424-3439,4448-4463,5472-5487,6496-6511,7520-7535,8544-8559,9568-9583,10592-10607,11616-11631,12640-12655,13664-13679,14688-14703,15712-15727,16736-16751,17760-17775,18784-18799,19808-19823,20832-20847,21856-21871,22880-22895,23904-23919,24928-24943,25952-25967,26976-26991,28000-28015,29024-29039,30048-30063,31072-31087,32096-32111,33120-33135,34144-34159,35168-35183,36192-36207,37216-37231,38240-38255,39264-39279,40288-40303,41312-41327,42336-42351,43360-43375,44384-44399,45408-45423,46432-46447,47456-47471,48480-48495,49504-49519,50528-50543,51552-51567,52576-52591,53600-53615,54624-54639,55648-55663,56672-56687,57696-57711,58720-58735,59744-59759,60768-60783,61792-61807,62816-62831,63840-63855,64864-64879"
check "port ranges" "${got}" "${want}"

# Regressions: default stays RFC 7597, and a prefix outside the rule is refused.
set -- $(mape_derive 2400:4052:1234:5600::/56 2400:4052:1000::/36 153.134.0.0/18 20 6)
check "rfc default ce" "$4" "2400:4052:1234:5600:0:9986:8d1:16"
check "outside rule refused" "$(mape_derive 2400:4052:2234:5600::/56 2400:4052:1000::/36 153.134.0.0/18 20 6 draft03)" ""
check "bad format refused"   "$(mape_derive 2400:4052:1234:5600::/56 2400:4052:1000::/36 153.134.0.0/18 20 6 bogus)" ""

exit ${fail}
