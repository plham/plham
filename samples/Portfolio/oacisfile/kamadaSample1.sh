#!/bin/sh
#============ pjsub Options ============
#PJM --rsc-list "node=576"
#PJM --rsc-list "elapse=00:05:00"
#PJM --rsc-list "rscgrp=large"
#PJM --mpi "proc=4608"
#PJM --stg-transfiles all
#PJM --mpi "use-rankdir"
#PJM --stgin  "rank=* ./build/a.out %r:./"
#PJM --stgout-dir "rank=0 %r:./ %j"
#PJM -s

. /work/system/Env_base

export GC_MARKERS=1
export X10_NTHREADS=1
export X10RT_MPI_THREAD_SERIALIZED=1
mpiexec ./a.out 138240 0 0.25 4 3.0 2.0 570 384

