#!/bin/bash
# File to run RHMC on jlab 21g

rat_path="/volatile/thermo/laltenko/conf/rat_approx/"
rat_files=("rat.out_ml003946ms019730Nfl2Nfs1Npf1" "rat.out_ml003446ms017230Nfl2Nfs1Npf1" "rat.out_ml002408ms012040Nfl2Nfs1Npf1" "rat.out_ml002230ms011150Nfl2Nfs1Npf1")

script_call=$(cat <<DELIM
./run_RHMC.sh \
--code patrick \
--output_base_path /volatile/thermo/laltenko/conf \
--executable_dir /home/laltenko/code_build/patrick/build \
--executable main_rhmc \
--n_sim_steps 1 \
--conftype l6420f21b7570m003946m01973 \
--stream_id _3 \
--Lattice "64 64 64 20" \
--Nodes "1 1 1 1" \
--beta 7.570 --mass_s 0.01973 --mass_ud 0.003946 \
--rat_file ${rat_path}/rat.out_ml003946ms019730Nfl2Nfs1Npf1 \
--seed 382011 --rand_file auto \
--jobname RHMC_cpu_64Nt --mail_user laltenkor@bnl.gov \
--time 48:00:00 --nodes 1 --gpuspernode 8 \
--account thermop --partition phi_test --qos normal \
--sbatch_custom "constraint cache,quad,16p" \
--conf_nr auto \
--custom_cmds "source /dist/intel/parallel_studio_2019/parallel_studio_xe_2019.0.045/bin/psxevars.sh intel64; export LD_LIBRARY_PATH=/dist/gcc/8.4.0/lib:/dist/gcc/8.4.0/lib64:\$LD_LIBRARY_PATH ;" \
--no_updates 1000 \
--rand_flag 0 \
--always_acc 0 \
--write_every 1 --load_conf 2 \
--no_md 20 \
--step_size 0.05 \
--replace_srun "taskset 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
DELIM
)

echo "$script_call"

echo -n "Continue y/n? "
read -r input
if [ "$input" != "y" ]; then
    exit 0
fi

eval $script_call
