#!/bin/bash
# Usage: $ bash samples/Parallel/run.sh ./a.out samples/Parallel/config-a002.json

X10_NPLACES=3
X10_NTHREADS=4
X10RT_MPI_THREAD_SERIALIZED=true

BS_WORKLOAD=true
BS_NSAMPLES=10
BS_NSTEPS=10
ORDER_RATE=0.1

mpirun -np $X10_NPLACES $@
