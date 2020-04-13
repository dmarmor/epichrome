#!/bin/sh

mydir="${BASH_SOURCE[0]%/*}" ; [[ "$mydir" = "${BASH_SOURCE[0]}" ]] && mydir='.'

source "$mydir/../src/core.sh" --noinit
source "$mydir/../src/launch.sh"

unset mydir

if ! vcmp '1.0.0' '<' '2.3.0'  ; then echo "TEST 1 FAILS" ; exit 1 ; fi
if ! vcmp '2.3.0' '>' '1.0.0'  ; then echo "TEST 2 FAILS" ; exit 1 ; fi
if ! vcmp '1.0.0' '<=' '2.3.0' ; then echo "TEST 3 FAILS" ; exit 1 ; fi
if   vcmp '1.0.0' '>=' '2.3.0' ; then echo "TEST 4 FAILS" ; exit 1 ; fi
if   vcmp '1.0.0' '=' '2.3.0'  ; then echo "TEST 5 FAILS" ; exit 1 ; fi
echo "1.0.0 vs 2.3.0 tests succeed"

if ! vcmp '4.99.0' '<' '10.0.0b3'  ; then echo "TEST 6 FAILS" ; exit 1 ; fi
if   vcmp '10.0.0b3' '<' '4.99.0'  ; then echo "TEST 7 FAILS" ; exit 1 ; fi
if   vcmp '4.99.0' '>' '10.0.0b3'  ; then echo "TEST 8 FAILS" ; exit 1 ; fi
if ! vcmp '4.99.0' '<=' '10.0.0b3' ; then echo "TEST 9 FAILS" ; exit 1 ; fi
if   vcmp '4.99.0' '>=' '10.0.0b3' ; then echo "TEST 10 FAILS" ; exit 1 ; fi
if   vcmp '4.99.0' '==' '10.0.0b3' ; then echo "TEST 11 FAILS" ; exit 1 ; fi
echo "4.99.0 vs 10.0.0b3 tests succeed"

if   vcmp '011.2.0026b09[102]' '>' '11.2.26b9[0102]'  ; then echo "TEST 12 FAILS" ; exit 1 ; fi
if   vcmp '11.2.26b9[0102]' '>' '011.2.0026b09[102]'  ; then echo "TEST 13 FAILS" ; exit 1 ; fi
if   vcmp '11.2.26b9[0102]' '<' '011.2.0026b09[102]'  ; then echo "TEST 14 FAILS" ; exit 1 ; fi
if ! vcmp '11.2.26b9[0102]' '<=' '011.2.0026b09[102]' ; then echo "TEST 15 FAILS" ; exit 1 ; fi
if ! vcmp '11.2.26b9[0102]' '>=' '011.2.0026b09[102]' ; then echo "TEST 16 FAILS" ; exit 1 ; fi
if ! vcmp '11.2.26b9[0102]' '=' '011.2.0026b09[102]'  ; then echo "TEST 17 FAILS" ; exit 1 ; fi
echo "11.2.26b9[0102] vs 011.2.0026b09[102] tests succeed"

if   vcmp '3.1.2b3' '>' '03.01.002b003'  ; then echo "TEST 18 FAILS" ; exit 1 ; fi
if   vcmp '3.1.2b3' '<' '03.01.002b003'  ; then echo "TEST 19 FAILS" ; exit 1 ; fi
if ! vcmp '3.1.2b3' '>=' '03.01.002b003' ; then echo "TEST 20 FAILS" ; exit 1 ; fi
if ! vcmp '3.1.2b3' '<=' '03.01.002b003' ; then echo "TEST 21 FAILS" ; exit 1 ; fi
if ! vcmp '3.1.2b3' '==' '03.01.002b003' ; then echo "TEST 22 FAILS" ; exit 1 ; fi
echo "3.1.2b3 vs 03.01.002b00 tests succeed"

if ! vcmp '2.3.0[1032]' '<' '02.003.0000'  ; then echo "TEST 23 FAILS" ; exit 1 ; fi
if   vcmp '2.3.0[1032]' '>' '02.003.0000'  ; then echo "TEST 24 FAILS" ; exit 1 ; fi
if ! vcmp '2.3.0[1032]' '<=' '02.003.0000' ; then echo "TEST 25 FAILS" ; exit 1 ; fi
if   vcmp '2.3.0[1032]' '>=' '02.003.0000' ; then echo "TEST 26 FAILS" ; exit 1 ; fi
if   vcmp '2.3.0[1032]' '=' '02.003.0000'  ; then echo "TEST 27 FAILS" ; exit 1 ; fi
echo "2.3.0[1032] vs 02.003.0000 tests succeed"

if ! vcmp '12.100.020b99' '<' '012.100.20'  ; then echo "TEST 28 FAILS" ; exit 1 ; fi
if   vcmp '12.100.020b99' '>' '012.100.20'  ; then echo "TEST 29 FAILS" ; exit 1 ; fi
if ! vcmp '12.100.020b99' '<=' '012.100.20' ; then echo "TEST 30 FAILS" ; exit 1 ; fi
if   vcmp '12.100.020b99' '>=' '012.100.20' ; then echo "TEST 31 FAILS" ; exit 1 ; fi
if   vcmp '12.100.020b99' '==' '012.100.20' ; then echo "TEST 32 FAILS" ; exit 1 ; fi
echo "12.100.020b99 vs 012.100.20 tests succeed"

if ! vcmp '3.x1.2b3' '<' '03.01.002b003'  ; then echo "TEST 33 FAILS" ; exit 1 ; fi
if   vcmp '03.01.002b003' '<=' '3.x1.2b3' ; then echo "TEST 34 FAILS" ; exit 1 ; fi
if   vcmp '3.x1.2b3' '>' '03.01.002b003'  ; then echo "TEST 35 FAILS" ; exit 1 ; fi
if ! vcmp '3.x1.2b3' '<=' '03.01.002b003' ; then echo "TEST 36 FAILS" ; exit 1 ; fi
if   vcmp '3.x1.2b3' '>=' '03.01.002b003' ; then echo "TEST 37 FAILS" ; exit 1 ; fi
if   vcmp '3.x1.2b3' '=' '03.01.002b003'  ; then echo "TEST 38 FAILS" ; exit 1 ; fi
echo "3.x1.2b3 vs 03.01.002b003 tests succeed"

if   vcmp '13.033.7b12' '<' '0013.33.07b012[100]'  ; then echo "TEST 39 FAILS" ; exit 1 ; fi
if ! vcmp '13.033.7b12' '>' '0013.33.07b012[100]'  ; then echo "TEST 40 FAILS" ; exit 1 ; fi
if   vcmp '13.033.7b12' '<=' '0013.33.07b012[100]' ; then echo "TEST 41 FAILS" ; exit 1 ; fi
if ! vcmp '13.033.7b12' '>=' '0013.33.07b012[100]' ; then echo "TEST 42 FAILS" ; exit 1 ; fi
if   vcmp '13.033.7b12' '==' '0013.33.07b012[100]' ; then echo "TEST 43 FAILS" ; exit 1 ; fi
echo "13.033.7b12 vs 0013.33.07b012[100] tests succeed"

if ! vcmp '04.3.12[1000]' '<' '4.03.12[2938]'  ; then echo "TEST 44 FAILS" ; exit 1 ; fi
if   vcmp '04.3.12[1000]' '>' '4.03.12[2938]'  ; then echo "TEST 45 FAILS" ; exit 1 ; fi
if ! vcmp '04.3.12[1000]' '<=' '4.03.12[2938]' ; then echo "TEST 46 FAILS" ; exit 1 ; fi
if   vcmp '04.3.12[1000]' '>=' '4.03.12[2938]' ; then echo "TEST 47 FAILS" ; exit 1 ; fi
if   vcmp '04.3.12[1000]' '=' '4.03.12[2938]'  ; then echo "TEST 48 FAILS" ; exit 1 ; fi
echo "04.3.12[1000] vs 4.03.12[2938] tests succeed"

if   vcmp '27.013.12b7[16]' '<' '27.13.12b6'   ; then echo "TEST 49 FAILS" ; exit 1 ; fi
if ! vcmp '27.013.12b7[16]' '>' '27.13.12b6'   ; then echo "TEST 50 FAILS" ; exit 1 ; fi
if   vcmp '27.013.12b7[16]' '<=' '27.13.12b6'  ; then echo "TEST 51 FAILS" ; exit 1 ; fi
if ! vcmp '27.013.12b7[16]' '>=' '27.13.12b6'  ; then echo "TEST 52 FAILS" ; exit 1 ; fi
if   vcmp '27.013.12b7[16]' '==' '27.13.12b6'  ; then echo "TEST 53 FAILS" ; exit 1 ; fi
echo "27.013.12b7[16] vs 27.13.12b6 tests succeed"

if   vcmp '01.2.14[4]' '<'  '1.02.014b90' ; then echo "TEST 54 FAILS" ; exit 1 ; fi
if ! vcmp '01.2.14[4]' '>'  '1.02.014b90' ; then echo "TEST 55 FAILS" ; exit 1 ; fi
if   vcmp '01.2.14[4]' '<=' '1.02.014b90' ; then echo "TEST 56 FAILS" ; exit 1 ; fi
if ! vcmp '01.2.14[4]' '>=' '1.02.014b90' ; then echo "TEST 57 FAILS" ; exit 1 ; fi
if   vcmp '01.2.14[4]' '='  '1.02.014b90' ; then echo "TEST 58 FAILS" ; exit 1 ; fi
echo "01.2.14[4] vs 1.02.014b90 tests succeed"
