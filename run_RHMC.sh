#!/bin/bash
# requires bash 4.4 or greater

argparse(){
    #Copyright (c) 2017 Noah Hoffman
    local argparser
    argparser=$(mktemp 2>/dev/null || mktemp -t argparser)
    cat > "$argparser" <<EOF
from __future__ import print_function
import sys
import argparse
import os
class MyArgumentParser(argparse.ArgumentParser):
    def print_help(self, file=None):
        """Print help and exit with error"""
        super(MyArgumentParser, self).print_help(file=file)
        sys.exit(1)
parser = MyArgumentParser(prog=os.path.basename("$0"),
            description="""$ARGPARSE_DESCRIPTION""")
EOF

    # stdin to this function should contain the parser definition
    cat >> "$argparser"

    cat >> "$argparser" <<EOF
args = parser.parse_args()

for group in parser._action_groups:
    for a in group._group_actions:
        key = a.dest
        value = getattr(args, key, None)
        suffix = ""
        #print("echo "+group.title)
        if group.title == "Parameters with either a single OR n_sim_steps arguments.":
            suffix = "_VAR"
        if isinstance(value, bool) or value is None:
            tmp_str = '{0}="{1}"; ARGS'+suffix+'+=("{0}");'
            print(tmp_str.format(key, 'yes' if value else ''))
        elif isinstance(value, list):
            tmp_str = '{0}=({1}); ARGS'+suffix+'+=("{0}");'
            print(tmp_str.format(key, ' '.join('"{0}"'.format(s) for s in value)))
        else:
            tmp_str = '{0}="{1}"; ARGS'+suffix+'+=("{0}");'
            print(tmp_str.format(key, value))
EOF

    # Define variables corresponding to the options if the args can be
    # parsed without errors; otherwise, print the text of the error
    # message.
    local retval
    if python "$argparser" "$@" &> /dev/null; then
        eval "$(python "$argparser" "$@")"
        retval=0
    else
        python "$argparser" "$@"
        retval=1
    fi

    rm "$argparser"
    return $retval
}
ARGPARSE_DESCRIPTION="Script to run SIMULATeQCD's RHMC on large clusters."
argparse "$@" <<EOF || exit 1

param_single = parser.add_argument_group('Parameters')
param_arrays = parser.add_argument_group('Parameters with either a single OR n_sim_steps arguments.')

# GENERAL PARAMETERS
parser.add_argument('--code', default="SIMULATeQCD", choices=["SIMULATeQCD", "patrick"], help="patrick: change parameter file to use patricks cpu code and do not use GPUs in slurm")
parser.add_argument('--ConfCheck_path', type=str, help="if provided and conf_nr=auto, then first ConfCheck is used to check whether the last conf is ok. \
                                              if it is not ok, then it will try the second to last conf.")
parser.add_argument('--module_load', nargs='*', help="modules will be loaded at the start of the sbatch script. example: --module_load gcc8 cmake3 cuda11")
parser.add_argument('--output_base_path', required=True, help="folder that will contain the output")
parser.add_argument('--executable_dir', required=True, help="folder that contains the gradientFlow executable")
parser.add_argument('--executable', help="filename of the gradientFlow exectuable inside the folder", default="RHMC")
parser.add_argument('--save_jobscript', type=str, help="save the job script to this file")

parser.add_argument('--custom_cmds', nargs='*', type=str, help="commands to execute before job steps. the nth argument is executed before the nth job step. useful to set different CUDA_VISIBLE_DEVICES.")

parser.add_argument('--n_sim_steps', type=int, default=1, help='how many slurm steps can be executed at the same time. useful for multiple single gpu runs on a full node.')
param_arrays.add_argument('--conftype', nargs='*', type=str, required=True, help="used to deduce the input/output file names, e.g. l9636f21b8249m002022m01011")
param_arrays.add_argument('--stream_id', nargs='*', type=str, required=True, help="used to deduce output file names")

# GAUGE CONF PARAMETERS
param_arrays.add_argument('--Lattice', nargs='*', type=str, required=True, help="Lattice dimensions")
param_arrays.add_argument('--Nodes', nargs='*', type=str,  required=True, help="how many times to split the Lattice in each direction (x y z t). this determines the number of GPUs for each job step.")
param_arrays.add_argument('--beta', nargs='*', type=float, required=True)
param_arrays.add_argument('--mass_s', nargs='*', type=float, required=True)
param_arrays.add_argument('--mass_ud', nargs='*', type=float, required=True)
param_arrays.add_argument('--rat_file', nargs='*', type=str, required=True)
param_arrays.add_argument('--conf_nr', nargs='*', default="auto", help="conf number of start configuration")
param_arrays.add_argument('--no_updates', nargs='*', type=int, default=1000, help="number of updates")
param_arrays.add_argument('--load_conf', nargs='*', type=int, required=True, help="0=einhei, 1=random, 2=getconf")
param_arrays.add_argument('--rand_flag', nargs='*', type=int, required=True, help="0=new random numbers, 1=read in random numbers")
param_arrays.add_argument('--write_every', nargs='*', type=int, default=1, required=True, help="write out configuration after this number of updates.")
param_arrays.add_argument('--rand_file', nargs='*', type=str, default="auto")


param_arrays.add_argument('--step_size', nargs='*', type=float, default=0.05, help="step size of trajectory")
param_arrays.add_argument('--no_md', nargs='*', type=int, default=20, help="number of steps of trajectory")
param_arrays.add_argument('--no_step_sf', nargs='*', type=int, default=5, help="number of steps of strange quark integration")
param_arrays.add_argument('--no_sw', nargs='*', type=int, default=20, help="number of steps of gauge integration")

param_arrays.add_argument('--residue', nargs='*', type=float, default=1e-12, help="for inversions")
param_arrays.add_argument('--residue_force', nargs='*', type=float, default=1e-7)
param_arrays.add_argument('--residue_meas', nargs='*', type=float, default=1e-12)

param_arrays.add_argument('--cgMax', nargs='*', type=int, default=30000, help="max cg steps for multi mass solver")
param_arrays.add_argument('--always_acc', nargs='*', type=int, default=0, help="1 = always accept configuration in Metropolis. default=0.")
parser.add_argument('--seed', nargs='*', type=int, required=True)


# SLURM PARAMETERS
parser.add_argument('--replace_srun', type=str, help="launch the executable with some other command, for example mpirun, mpiexec, stdbuf -i0 -o0 -e0, taskset 0xFFFF, etc.")
parser.add_argument('--jobname', required=True, help="slurm job name")
parser.add_argument('--mail_user', type=str, required=True)
parser.add_argument('--mail_type', type=str, default="FAIL")

parser.add_argument('--time', help="format: DD-HH:MM:SS", required=True)
parser.add_argument('--partition', type=str)
parser.add_argument('--qos', type=str)
parser.add_argument('--account', type=str)
parser.add_argument('--constraint', type=str)
parser.add_argument('--sbatch_custom', type=str, help='this is appended to "#SBATCH --" in the sbatch script')

parser.add_argument('--nodes', type=int, required=True, help='number of nodes')
parser.add_argument('--gpuspernode', type=int, required=True)

parser.add_argument('--array', help="use something like 0-99%1 to let only one instance run simultaneously")

EOF

#===========================SAVE SCRIPT CALLS IN FILE==========================
scriptname=${0##*/}
prevcallfile=prev_calls_${scriptname%\.*}.log
echo -e "\n$(date +"%F %T")" >> "$prevcallfile"
echo "${0}" "${@}" >> "$prevcallfile"

# check if parameters make sense

executable_path=$executable_dir/$executable
if [ ! -f "$executable_path" ]; then echo "ERROR: Executable does not exist!"; exit 1; fi

if [ "$rand_flag" -eq 1 ] && [ ! "$rand_file" ] ; then
    echo "ERROR: rand_flag=1 but no --rand_file was given!"
    exit 1
fi

if [ "$load_conf" -eq 2 ] && [ ! "$conf_nr" ] ; then
    echo "ERROR: load_conf=2 but no --conf_nr was given!"
    exit 1
fi

# echo "${ARGS_VAR[@]}"
parameters=("${ARGS_VAR[@]}")

# make all parameters be an array with n_sim_steps entries by appending the single entry n_sim_steps-1 times.
for param in "${parameters[@]}" ; do

    param_name=${param}
    declare -n param

    if [ ${#param[@]} -eq 1 ] ; then
        echo "INFO: Only a single argument was given for ${param_name}. This will be used for all ${n_sim_steps} job steps."

        # append n_sim_steps-1 copies of the parameter.
        for ((i=1; i<n_sim_steps; i++)) ; do
            param+=("${param[0]}")
        done
    fi
    unset -n param
done

parameters+=("seed")  # seeds should always be different

# check if all parameters now have the correct number of entries
for param in "${parameters[@]}" ; do
    param_name=${param}
    declare -n param
    if [ ${#param[@]} -ne "$n_sim_steps" ] ; then
        echo "ERROR: --$param_name should have either a single or $n_sim_steps (=n_sim_steps) arguments."
        exit 1
    fi
    unset -n param
done


# parse slurm options
if [ "$qos" ] ; then
    SBATCH_QOS="#SBATCH --qos=$qos"
fi
if [ "$partition" ] ; then
    SBATCH_PARTITION="#SBATCH --partition=$partition"
fi
if [ "$account" ] ; then
    SBATCH_ACCOUNT="#SBATCH --account=$account"
fi
if [ "$constraint" ] ; then
    SBATCH_CONSTRAINT="#SBATCH --constraint=$constraint"
fi
if [ "$array" ] ; then
    SBATCH_ARRAY="#SBATCH --array=$array"
fi
if [ "$sbatch_custom" ] ; then
    SBATCH_CUSTOM="#SBATCH --$sbatch_custom"
fi
if [ "$code" == "SIMULATeQCD" ] ; then
    SBATCH_GPUS="#SBATCH --gres=gpu:${gpuspernode}"
fi


param_func="set_parameters_SIMULATeQCD"
if [ "$code" == "patrick" ] ; then
    param_func="set_parameters_patrick"
fi


logdir=${output_base_path}/logs
mkdir -p "$logdir"

sbatchscript=$(cat <<EOF
#!/bin/bash
#SBATCH --job-name=${jobname}
#SBATCH --output=$logdir/${jobname}_%j.out
#SBATCH --error=$logdir/${jobname}_%j.err
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
seed = \$7
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
\$(cat patrick.cfg)
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

    # determine rand_file
    if [ "\${rand_file[i]}" == "auto" ] ; then
        this_rand_file="${output_base_path}/\${conftype[i]}/\${conftype[i]}\${stream_id[i]}/\${conftype[i]}\${stream_id[i]}_rand."
        # echo "INFO: rand_file = \${this_rand_file}\$this_conf_nr"
    else
        this_rand_file="\${rand_file[i]}"
    fi

    # check if rand_file exists
    if [ ! -f "\${this_rand_file}\${this_conf_nr}" ] && [ "${rand_flag}" -eq 1 ] ; then
        echo "ERROR: given rand_file does not exist or autodetect of conf_nr failed! (you specified --rand_flag=1)"
    fi

    # check whether last conf is valid. if not, then check the second to last conf and use that one if it is valid.
    if [ "\${conf_nr[i]}" == "auto" ] && [ "${ConfCheck_path}" ] && [ -f "${ConfCheck_path}" ] ; then
        ${ConfCheck_path} EMPTY_FILE format=nersc Lattice="\${Lattice[i]}" Gaugefile="\${gauge_file}\${this_conf_nr}"
        if [ \$? -ne 0 ] ; then
            echo "ERROR: Gaugefile is broken: \${gauge_file}\${this_conf_nr}"
            echo "INFO: Trying second to last one using conf_nr=\${this_conf_nr_second}"
            ${ConfCheck_path} EMPTY_FILE format=nersc Lattice="\${Lattice[i]}" Gaugefile="\${gauge_file}\${this_conf_nr_second}"
            if [ \$? -ne 0 ] ; then
                "ERROR: Second to last gaugefile is also broken: \${gauge_file}\${this_conf_nr_second}"
            else
                this_conf_nr=\${this_conf_nr_second}
            fi
        fi
    fi

    paramfile=\${paramdir}/\${conftype[i]}\${stream_id[i]}.\${this_conf_nr}.param

    $param_func "\${Lattice[i]}" "\${Nodes[i]}" "\${beta[i]}" "\${mass_s[i]}" "\${mass_ud[i]}" "\${rat_file[i]}" "\${seed[i]}" "\${this_rand_file}" "\${step_size[i]}" "\${no_md[i]}" "\${no_step_sf[i]}" "\${no_sw[i]}" "\${residue[i]}" "\${residue_force[i]}" "\${residue_meas[i]}" "\${cgMax[i]}" "\${always_acc[i]}" "\${rand_flag[i]}" "\${load_conf[i]}" "\${gauge_file}" "\${this_conf_nr}" "\${no_updates[i]}" "\${write_every[i]}" 

    echo "\$parameters" > "\$paramfile"

    echo "\${custom_cmds[i]}"
    eval "\${custom_cmds[i]}"

    this_Nodes=(\${Nodes[i]})
    numberofgpus=\$((this_Nodes[0] * this_Nodes[1] * this_Nodes[2] * this_Nodes[3]))
    logdir=${output_base_path}/\${conftype[i]}/logs
    mkdir -p \$logdir

    if [ "${replace_srun}" ] ; then
        run_command="${replace_srun} ${executable_path} \$paramfile"
    else
        run_command="srun --exclusive -n \${numberofgpus} --gres=gpu:\${numberofgpus} -u ${executable_path} \$paramfile"
    fi

    echo -e "\$run_command \\n"
    ( \$run_command &> \$logdir/\${conftype[i]}\${stream_id[i]}.\${this_conf_nr}.out ) &

    arr_pids+=(\$!)

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

echo -ne "\n===== BEGIN SBATCHSCRIPT ===\n"
echo "$sbatchscript"
echo -ne "===== END   SBATCHSCRIPT ===\n\n"

if [ "$save_jobscript" ] ; then
    echo "$sbatchscript" > $save_jobscript
fi

echo -en "\nSubmit y/n? "
read -r input
if [ "$input" != "y" ]; then
    echo "INFO: Did not submit job..."
    exit
fi

(sbatch <<< "$sbatchscript")

echo "sbatch script submitted" >> "$prevcallfile"
