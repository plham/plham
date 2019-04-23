#!/bin/sh
#============ pjsub Options ============
#PJM --rsc-list "node=64"
#PJM --rsc-list "elapse=00:03:00"
#PJM --stg-transfiles all
#PJM --mpi "use-rankdir"
#PJM --stgin  "rank=* ./utsg %r:./"

#PJM -s

#============ Shell Script ============

export GC_MARKERS=1
#export X10_STATIC_THREADS=1
export X10_NTHREADS=8
export X10_NPLACES=64
export X10RT_MPI_THREAD_SERIALIZED=true
#export X10RT_MPI_FORCE_COLLECTIVES=true
#export X10RT_MPI_ENABLE_COLLECTIVES=true
#export X10_CONGRUENT_BASE=0x10000000000LL

. /work/system/Env_base
mpiexec ./utsg -d 17 -n 2000 -nA 0 
#mpiexec ./utsgms -d 15 -n 2000 -nA 0 
# -v 8

