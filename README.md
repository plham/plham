# Plham: Platform for large-scale and high-frequency artificial market

Plham is a platform for artificial market simulations, written in [X10 language](http://x10-lang.org):

  * for large-scale parallel computation
  * as well as standalone sequential computation

Plham is shipped with reusable examples based on recent artirifial market studies on

  * Fundamentalist-chartist agents
  * Single asset simulations
  * Price limit regulation
  * Trading halt regulation
  * Fat finger error
  * Flash Crash shock transfer

The documentation is currently only written in Japanese (the English text will appear soon):

  * [Documentation (Japanese)](http://plham.github.io)

The API is written in English:

  * [API (English)](http://plham.github.io/api)

## Checkout

This repository uses some submodules. You can recursively clone the submodules as follows:

```
git clone --recursive git@github.com:plham/plham.git
```


## Single Thread Version

You can compile and run the sample programs at the top directory of Plham as follows:

```
compile:
% x10c -sourcepath .:cassiaX10lib samples/CI2002/CI2002Main.x10
execution:
% x10 samples.CI2002.CI2002Main samples/CI2002/config.json
```

## Parallel Version

For parallel versions, please use the native version of X10 with MPI runtimes.

Sample Program: samples/Parallel/ParallelDistMain.x10

```
compile:
% x10c++ -x10rt mpi -sourcepath .:cassiaX10lib -O -o paraMain samples/Parallel/ParallelDistMain.x10
parallel execution:
% mpirun -np numHosts -host host0,host1,... ./paraMain samples/Parallel/config-a002.json
```

Execution Environment:

* The parallel version needs some customization of X10.
  * Please take the customized version of X10 from [here](https://gittk.cs.kobe-u.ac.jp/kamada/x10kobecustom) and build it.
* We recommend to use thread-safe MPI.
* You can build the X10 with MPI runtimes with executing the following command at the `x10.dist` directory.

```
ant  -DX10RT_MPI=true -Doptimize=true -DTHREAD_LOCAL=true -DNO_CHECKS=true dist
```

* Please use native version of X10 and set an environment variable as `X10RT_MPI_FORCE_COLLECTIVES=true`. Please set `X10_NTHREADS` to specify the number of worker threads on each computing node.


## License

Currently under [Eclipse Public License 1.0 (read here)](http://choosealicense.com/licenses/epl-1.0/).

## History

* v0.3: April 2019
* v0.1.1: May 2016
* v0.1: April 2016

## Contributors

* Takuma Torii
* Kiyoshi Izumi
* Tomio Kamada
* Hiroto Yonenoh
* Daisuke Fujishima
* Izuru Matsuura
* Masanori Hirano
* Tosiyuki Takahashi


