set -o errexit

mkdir -p script/orig

make libsms && make eleg_scriptdmp
./eleg_scriptdmp eleg.gg script/orig/
