#!/bin/bash
# File to run RHMC on jlab phi

rat_path="/volatile/thermo/laltenko/conf/rat_approx/"
rat_files=("rat.out_ml003946ms019730Nfl2Nfs1Npf1" "rat.out_ml003446ms017230Nfl2Nfs1Npf1" "rat.out_ml002408ms012040Nfl2Nfs1Npf1" "rat.out_ml002230ms011150Nfl2Nfs1Npf1")

script_call=$(cat <<DELIM
./create_RHMC_job.sh \
--code patrick \
--output_base_path /volatile/thermo/laltenko/conf \
--executable_dir /home/laltenko/code_build/patrick/build \
--executable main_rhmc \
--n_sim_steps 1 \
--conftype l6420f21b7570m003946m01973 \
--stream_id _3 \
--Lattice "64 64 64 20" \
--Nodes "2 1 1 1" \
--beta 7.570 --mass_s 0.01973 --mass_ud 0.003946 \
--rat_file ${rat_path}/rat.out_ml003946ms019730Nfl2Nfs1Npf1 \
--seed 382011 --rand_file auto \
--jobname RHMC_cpu_64Nt --mail_user laltenkor@bnl.gov \
--time 00:30:00 --nodes 2 --gpuspernode 0 \
--account thermop --partition phi --qos debug \
--sbatch_custom "constraint cache,quad,16p --mem=0" \
--conf_nr auto \
--cgMax 10 \
--custom_cmds "source /dist/intel/parallel_studio_xe_2020_update1/parallel_studio_xe_2020.4.912/bin/psxevars.sh intel64; source /dist/intel/parallel_studio_xe_2020_update1/compilers_and_libraries_2020.4.304/linux/mpi/intel64/bin/mpivars.sh release_mt ; source /dist/intel/parallel_studio_xe_2020_update1/compilers_and_libraries_2020.4.304/linux/bin/compilervars.sh intel64 ; export I_MPI_EXTRA_FILESYSTEM=on ; export I_MPI_EXTRA_FILESYSTEM_FORCE=lustre ; export I_MPI_PMI_LIBRARY=/usr/lib64/libpmi.so ; export I_MPI_FABRICS=shm:ofi ; export I_MPI_PIN=1; export I_MPI_PIN_DOMAIN=node ; export LD_LIBRARY_PATH=\\\\\\\$LD_LIBRARY_PATH:/dist/gcc/9.3.0/lib64:/dist/gcc/9.3.0/lib ; env | sort > env_cpu.txt ; " \
--no_updates 2 \
--rand_flag 0 \
--always_acc 0 \
--write_every 1 --load_conf 2 \
--no_md 1 \
--step_size 0.05 \
--replace_srun "srun --ntasks-per-node=1 -N 2 " \
--save_jobscript jobscript.sh
DELIM
)

echo "$script_call"

echo -n "Continue y/n? "
read -r input
if [ "$input" != "y" ]; then
    exit 0
fi

eval $script_call
