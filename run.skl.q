#!/bin/bash --login
#SBATCH -J mt-dgemm-icc
#SBATCH -o o.%x.skl.%j
#SBATCH -e e.%x.skl.%j
#SBATCH --ntasks=40
#SBATCH --ntasks-per-node=40 # tasks to run per node
#SBATCH -p compute
#SBATCH --time=00:15:00
#SBATCH --exclusive
#SBATCH -A scw1001

set -eu

buildflavors[0]="compiler/intel/2018/2 mkl/2018/2" 
buildflavors[1]="compiler/intel/2020/0 mkl/2020/0" 
buildflavors[2]="compiler/intel/2020/1 mkl/2020/1" 

for i in `seq 1 ${#buildflavors[@]}`;
do
    flavor=${buildflavors[$((i-1))]}
    module purge
    module load $flavor
    module list
    echo "Using modules: " $flavor
    MKL_VERSION=`echo $MKLROOT | cut -d/ -f5`
    echo "MKL Version: " $MKL_VERSION

    export OMP_NUM_THREADS=1
    
    env | grep SCW
    env | grep MKL
    env
    
    ######################
    #    setup paths     #
    ######################
    input_dir=$HOME/mkl-test/mt-dgemm/src
    output_dir=$SLURM_SUBMIT_DIR/output.skl
    code_src=mt-dgemm.c
    code_exe=mt-dgemm-icc
    make_file=Makefile.intel.hawk
    
    mkdir -p $output_dir
    
    ######################
    # remove older files #
    # if present         #
    ######################
    rm -f mt-dgemm-icc
    rm -f libfakeintel.so
    
    ########################
    # compile bench test   #
    ########################
    cp $input_dir/$make_file .
    cp $input_dir/$code_src .
    make -f $make_file clean
    make -f $make_file $code_exe
    
    ########################
    # compile fake lib and #
    # add to path      #
    ########################
    #gcc -shared -fPIC -o libfakeintel.so fakeintel.c
    #root=`pwd`
    #export LD_PRELOAD=$root/libfakeintel.so
    
    ########################
    # run bench test       #
    ########################
    for omp in 1 2 4 8 16 32 64;
    do
        export OMP_NUM_THREADS=$omp
        echo OMP_NUM_THREADS=$OMP_NUM_THREADS
    
        perf record -e cpu-cycles -o $output_dir/perf.data.omp$omp ./$code_exe 4000
        perf report --stdio -i $output_dir/perf.data.omp$omp > $output_dir/perf.report.omp$omp
    done

done
