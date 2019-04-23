#!/bin/bash -x
#============ pjsub Options ============
#PJM --rsc-list "node=1"
#PJM --rsc-list "elapse=20:00:00"
#PJM --rsc-list "rscgrp=small"
#PJM --mpi "proc=8"
#PJM --stg-transfiles all
#PJM --mpi "use-rankdir"
#PJM --stgin  "rank=* /home/hp160253/k03343/plham_portfolioOACIS3/baselPortfolioFP.out %r:./"
#PJM --stgin  "rank=* /home/hp160253/k03343/plham_portfolioOACIS3/baselV2N800-G3-seed1.json %r:./"
#PJM --stgout-dir "rank=0 %r:./ %j"
#PJM -s 

. /work/system/Env_base

export GC_MARKERS=1
export X10_NTHREADS=1
export X10RT_MPI_THREAD_SERIALIZED=1

mpiexec ./baselPortfolioFP.out ./baselV2N800-G3-seed1.json 1





