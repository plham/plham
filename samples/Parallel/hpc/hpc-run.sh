#!/bin/bash

HOSTS="$@"

for NARB in 0 1; do
for NSPOTS in 31 15 7 3; do
for np in 16 8 4 2 1; do
	echo $np $NSPOTS $NARB
	sed "s/NSPOTS/$NSPOTS/g; s/NARB/$NARB/g;" config-hpc.json > config-${NSPOTS}-${NARB}.json
	mpirun -np $np -host $HOSTS ./a.out config-${NSPOTS}-${NARB}.json >out-$(printf '%02d' $np)-${NSPOTS}-${NARB}.dat
done
done
done

