sbatchscript=$(cat <<EOF
#!/bin/bash
#SBATCH --job-name=${jobname}
#SBATCH --output=$logdir/${jobname}_%A_%a.out
#SBATCH --error=$logdir/${jobname}_%A_%a.err
#SBATCH --mail-type=$mail_type
#SBATCH --mail-user=$mail_user
$SBATCH_PARTITION
$SBATCH_QOS
$SBATCH_ACCOUNT
$SBATCH_CONSTRAINT
$SBATCH_ARRAY
$SBATCH_CUSTOM
#SBATCH --nodes=$nodes
#SBATCH --time=$time
$SBATCH_GPUS


set_parameters_SIMULATeQCD () {
parameters="Lattice = \$1
Nodes = \$2
beta    = \$3
mass_s  =  \$4
mass_ud = \$5
rat_file = \$6
seed = \$7
rand_file = \$8
step_size  = \$9
no_md      = \${10}
no_step_sf = \${11}
no_sw      = \${12}
residue   = \${13}
residue_force = \${14}
residue_meas = \${15}
cgMax  = \${16}
always_acc = \${17}
rand_flag = \${18}
load_conf = \${19}
gauge_file = \${20}
conf_nr = \${21}
no_updates = \${22}
write_every = \${23}"
}

set_parameters_patrick () {
lx=\${1%% *}
lt=\${1##* }
b=(\$2)
parameters="write_stdout_to_file = 0
stdout_file = /path/stdout
beta = \$3
lx   = \$lx
ly   = \$lx
lz   = \$lx
lt   = \$lt
lat_precision_flag = 0
lat_read_flag = \${19}
lat_file      = \${20}
lat_number    = \${21}
seed = \$7  # ignored unless read_random_state=0
mass_ud = \$5
mass_s  = \$4
step_size = \$9
no_steps_md      = \${10}
no_steps_1f      = \${11}
no_steps_gluonic = \${12}
cg_break_residual_ud        = \${13}
cg_break_residual_s         = \${13}
cg_break_residual_ud_update = \${13}
cg_break_residual_s_update  = \${13}
cg_max_iterations_rhmc = \${16}
always_accept = \${17}
no_updates = \${22}
write_conf_every_nth = \${23}
rnd_file = \$8
read_random_state = \${18}
no_sources_pbp_ud = 4
cg_break_residual_pbp_ud = \${15}
max_rat_degree = 14
bx = \${b[0]}
by = \${b[1]}
bz = \${b[2]}
bt = \${b[3]}
#
sfx = 1
sfy = 1
sfz = 8  # 8 for single, 4 for double.
sft = 1
#
r_inv_1f_degree = 14
r_inv_2f_degree = 14
r_1f_degree = 14
r_2f_degree = 14
r_bar_1f_degree = 12
r_bar_2f_degree = 12
#
\$(cat \$6)

"
}


if [ "${module_load[@]}" ] ; then
    module load ${module_load[@]}
    module list |& cat
fi

echo -e "Start \$(date +"%F %T")\\n"
echo -e "\$SLURM_JOB_ID \$SLURM_JOB_NAME | \$(hostname) | \$(pwd) \\n"


# "export" arrays to sub shell. unfortunately we need to hardcode this (see https://www.mail-archive.com/bug-bash@gnu.org/msg01774.html)
conftype=(${conftype[@]})
stream_id=(${stream_id[@]})
conf_nr=(${conf_nr[@]})
Lattice=(${Lattice[@]@Q})
Nodes=(${Nodes[@]@Q})
rand_file=(${rand_file[@]})
beta=(${beta[@]})
mass_ud=(${mass_ud[@]})
mass_s=(${mass_s[@]})
seed=(${seed[@]})
rat_file=(${rat_file[@]})
no_updates=(${no_updates[@]})
load_conf=(${load_conf[@]})
rand_flag=(${rand_flag[@]})
write_every=(${write_every[@]})
step_size=(${step_size[@]})
no_md=(${no_md[@]})
no_step_sf=(${no_step_sf[@]})
no_sw=(${no_sw[@]})
residue=(${residue[@]})
residue_force=(${residue_force[@]})
residue_meas=(${residue_meas[@]})
cgMax=(${cgMax[@]})
always_acc=(${always_acc[@]})
custom_cmds=(${custom_cmds[@]@Q})

arr_pids=()


for ((i = 0 ; i < $n_sim_steps ; i++)); do

    # execute custom commands (e.g. to modify the environment)
    echo "\${custom_cmds[i]}"
    eval "\${custom_cmds[i]}"

    #create some paths and directories
    gaugedir="${output_base_path}/\${conftype[i]}/\${conftype[i]}\${stream_id[i]}"
    paramdir="${output_base_path}/\${conftype[i]}/param"

    mkdir -p "\$gaugedir"
    mkdir -p "\$paramdir"

    gauge_file="\${gaugedir}/\${conftype[i]}\${stream_id[i]}."

    # determine conf_nr
    if [ \${load_conf[i]} -ne 2 ] ; then
        this_conf_nr=0
    elif [ "\${conf_nr[i]}" == "auto" ] ; then
	    last_conf=\$(find \${gauge_file}[0-9]* -printf "%f\n" | sort -t '.' -k 2n | tac | head -n1 )
	    second_to_last_conf=\$(find \${gauge_file}[0-9]* -printf "%f\n" | sort -t '.' -k 2n | tac | head -n2 | tail -n1 )
        this_conf_nr=\${last_conf##*.}
        this_conf_nr_second=\${second_to_last_conf##*.}
    else
        this_conf_nr="\${conf_nr[i]}"
    fi

    # check if gauge_file exists
    if [ ! -f "\${gauge_file}\${this_conf_nr}" ] && [ \${load_conf[i]} -eq 2 ] ; then
        echo "ERROR: gauge_file \${gauge_file}\${this_conf_nr} does not exist"
    fi

    skip=""

    # check whether gaugefile is a valid conf. if not, then check the second to gaugefile and use that one if it is valid.
    if [ \${load_conf[i]} -eq 2 ] && [ "\${conf_nr[i]}" == "auto" ] && [ "${CheckConf_path}" ] ; then
        ${CheckConf_path} EMPTY_FILE format=nersc Lattice="\${Lattice[i]}" Gaugefile="\${gauge_file}\${this_conf_nr}"
        if [ \$? -ne 0 ] ; then
            echo "ERROR: Gaugefile is broken: \${gauge_file}\${this_conf_nr}"
            echo "INFO: Trying second to last one using conf_nr=\${this_conf_nr_second}"
            ${CheckConf_path} EMPTY_FILE format=nersc Lattice="\${Lattice[i]}" Gaugefile="\${gauge_file}\${this_conf_nr_second}"
            if [ \$? -ne 0 ] ; then
                "ERROR: Second to last gaugefile is also broken: \${gauge_file}\${this_conf_nr_second}"
                skip=true
            else
                this_conf_nr=\${this_conf_nr_second}
            fi
        fi
    fi

    # determine rand_file
    if [ "\${rand_file[i]}" == "auto" ] ; then
        this_rand_file="${output_base_path}/\${conftype[i]}/\${conftype[i]}\${stream_id[i]}/\${conftype[i]}\${stream_id[i]}_rand."
    else
        this_rand_file="\${rand_file[i]}"
    fi

    # determine seed
    if [ "\${seed[i]}" == "random" ] ; then
        this_seed="\$(date +%N)"
    else
        this_seed="\${seed[i]}"
    fi

    this_rand_flag="\${rand_flag[i]}"

    # check if rand_file exists. if not, then just start from different seed, if rand_file==auto.
    if [ ! -f "\${this_rand_file}\${this_conf_nr}" ] && [ "${rand_flag}" -eq 1 ] ; then
        echo "WARN: rand_file does not exist (although you specified --rand_flag=1)"
        if [ "\${rand_file[i]}" == "auto" ] ; then
            this_rand_flag="0"
            echo "WARN: but, since rand_file=auto, I will set rand_flag=0 and thus generate a new random number state from this seed: \${this_seed}"
        fi
    elif [ -f "\${this_rand_file}\${this_conf_nr}" ] ; then
        # check whether Randfile is a valid. if not, start from differen seed
        if [ "${CheckRand_path}" ] ; then
            ${CheckRand_path} EMPTY_FILE Lattice="\${Lattice[i]}" Randfile="\${this_rand_file}\${this_conf_nr}"
            if [ \$? -ne 0 ] ; then
                echo "ERROR: Randfile is broken: \${this_rand_file}\${this_conf_nr}"
                this_seed="\$(date +%N)"
                this_rand_flag="0"
                echo "INFO: Generating new random number state from seed \${this_seed}"
            fi
        fi
    fi

    paramfile=\${paramdir}/\${conftype[i]}\${stream_id[i]}.\${this_conf_nr}.param

    $param_func "\${Lattice[i]}" "\${Nodes[i]}" "\${beta[i]}" "\${mass_s[i]}" "\${mass_ud[i]}" "\${rat_file[i]}" "\${this_seed}" "\${this_rand_file}" "\${step_size[i]}" "\${no_md[i]}" "\${no_step_sf[i]}" "\${no_sw[i]}" "\${residue[i]}" "\${residue_force[i]}" "\${residue_meas[i]}" "\${cgMax[i]}" "\${always_acc[i]}" "\${this_rand_flag}" "\${load_conf[i]}" "\${gauge_file}" "\${this_conf_nr}" "\${no_updates[i]}" "\${write_every[i]}"

    echo "\$parameters" > "\$paramfile"

    this_Nodes=(\${Nodes[i]})
    numberofranks=\$((this_Nodes[0] * this_Nodes[1] * this_Nodes[2] * this_Nodes[3]))

    if [ \${numberofranks} -gt ${gpuspernode} ] ; then
        numberofgpus=${gpuspernode}
    else
        numberofgpus=\${numberofranks}
    fi

    logdir=${output_base_path}/\${conftype[i]}/logs
    mkdir -p \$logdir

    bare_command="${executable_path} \$paramfile"
    logfile="\$logdir/\${conftype[i]}\${stream_id[i]}.\${this_conf_nr}.out"
    if [ "${replace_srun}" ] ; then
        run_command="${replace_srun} \${bare_command}"
    else
        run_command="srun --exclusive -n \${numberofranks} --gres=gpu:\${numberofgpus} -u \${bare_command}"
    fi

    if [ "\$skip" ] ; then
        echo "INFO: Skipping this job step because no valid gaugefile could be found!"
        arr_pids+=(dummy_pid)
    else
        echo -e "\$run_command &> \$logfile \\n"
        # this is where the program is actually executed:
        ( \$run_command &> \$logfile ) &
        arr_pids+=(\$!)
    fi
done

# get and check the exit codes of all parallel job steps
for ((i=0;i<${n_sim_steps} ;i++)); do

    pid="\${arr_pids[i]}"
    if [ -z \${arr_pids[i]} ] ; then
        continue
    fi
    if wait \$pid ; then
        echo "SUCCESS: \${conftype[i]}\${stream_id[i]}"
    else
        echo "ERROR: \${conftype[i]}\${stream_id[i]}"
    fi
done


echo -e "End \$(date +"%F %T")\\n"
EOF
)
