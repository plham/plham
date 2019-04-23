#!/bin/bash -x
#============ pjsub Options ============
#PJM --rsc-list "node=1"
#PJM --rsc-list "elapse=00:05:00"
#PJM --rsc-list "rscgrp=small"
#PJM --mpi "proc=8"
#PJM --stg-transfiles all
#PJM --mpi "use-rankdir"
#PJM --stgin  "rank=* /home/hp160253/k03343/plham_portfolioOACIS3/oacisfile/WriteSETMARKET.out %r:./"
#PJM -s 

. /work/system/Env_base

export GC_MARKERS=1
export X10_NTHREADS=1
export X10RT_MPI_THREAD_SERIALIZED=1

mpiexec /home/hp160253/k03343/plham_portfolioOACIS3/oacisfile/WriteSETMARKET.out 1 5




