#!/bin/bash

Lattice=""; Nodes=""; beta=""; mass_s="", mass_ud=""; step_size=""; no_md=""; no_step_sf=""; no_sw=""; residue=""; residue_force=""; residue_meas="";
cgMax=""; always_acc=""; rat_file=""; rand_flag=""; rand_file=""; seed=""; load_conf=""; gauge_file=""; conf_nr=""; no_updates=""; write_every=""
executable_dir=""; executable=""; output_base_path=""; conftype=""; stream_id="";
jobname=""; mail_type=""; mail_user=""; partition=""; qos=""; nodes=""; time=""; account=""; module_load=""; gpuspernode="";
n_sim_steps=""

argparse(){
    #Copyright (c) 2017 Noah Hoffman
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
for arg in [a for a in dir(args) if not a.startswith('_')]:
    key = arg
    value = getattr(args, arg, None)
    if isinstance(value, bool) or value is None:
        print('{0}="{1}";'.format(key, 'yes' if value else ''))
    elif isinstance(value, list):
        print('{0}=({1});'.format(key, ' '.join('"{0}"'.format(s) for s in value)))
    else:
        print('{0}="{1}";'.format(key, value))
EOF

    # Define variables corresponding to the options if the args can be
    # parsed without errors; otherwise, print the text of the error
    # message.
    if python "$argparser" "$@" &> /dev/null; then
        eval $(python "$argparser" "$@")
        retval=0
    else
        python "$argparser" "$@"
        retval=1
    fi

    rm "$argparser"
    return $retval
}
ARGPARSE_DESCRIPTION="Script to run RHMC on large clusters"
argparse "$@" <<EOF || exit 1

# GENERAL PARAMETERS
parser.add_argument('--module_load', nargs='*', help="modules will be loaded at the start of the sbatch script. example: --module_load gcc8 cmake3 cuda11")
parser.add_argument('--output_base_path', required=True, help="folder that will contain the output")
parser.add_argument('--executable_dir', required=True, help="folder that contains the gradientFlow executable")
parser.add_argument('--executable', help="filename of the gradientFlow exectuable inside the folder", default="RHMC")

parser.add_argument('--n_sim_steps', type=int, default=1, help='how many slurm steps can be executed at the same time. useful for multiple single gpu runs on a full node.')
parser.add_argument('--conftype', nargs='*', type=str, required=True, help="used to deduce the input/output file names, e.g. l9636f21b8249m002022m01011")
parser.add_argument('--stream_id', nargs='*', type=str, required=True, help="used to deduce output file names")

# GAUGE CONF PARAMETERS
parser.add_argument('--Lattice', nargs='*', type=str, required=True, help="Lattice dimensions")
parser.add_argument('--Nodes', nargs='*', type=str,  required=True, help="how many times to split the Lattice in each direction (x y z t). this determines the number of GPUs for each job step.")
parser.add_argument('--beta', nargs='*', type=float, required=True)
parser.add_argument('--mass_s', nargs='*', type=float, required=True)
parser.add_argument('--mass_ud', nargs='*', type=float, required=True)
parser.add_argument('--rat_file', nargs='*', type=str, required=True)
parser.add_argument('--rand_file', nargs='*', type=str, default="auto")
parser.add_argument('--seed', nargs='*', type=int, required=True)
parser.add_argument('--conf_nr', nargs='*', default="auto", help="conf number of start configuration")
parser.add_argument('--no_updates', nargs='*', type=int, default=1000, help="number of updates")
parser.add_argument('--load_conf', nargs='*', type=int, required=True, help="0=einhei, 1=random, 2=getconf")
parser.add_argument('--rand_flag', default='*', type=int, required=True, help="0=new random numbers, 1=read in random numbers")
parser.add_argument('--write_every', type=int, nargs='*', default=1, required=True, help="write out configuration after this number of updates.")

parser.add_argument('--step_size', type=float, default=0.05, help="step size of trajectory")
parser.add_argument('--no_md', type=int, default=20, help="number of steps of trajectory")
parser.add_argument('--no_step_sf', type=int, default=5, help="number of steps of strange quark integration")
parser.add_argument('--no_sw', type=int, default=20, help="number of steps of gauge integration")

parser.add_argument('--residue', type=float, default=1e-12, help="for inversions")
parser.add_argument('--residue_force', type=float, default=1e-7)
parser.add_argument('--residue_meas', type=float, default=1e-12)

parser.add_argument('--cgMax', type=int, default=30000, help="max cg steps for multi mass solver")
parser.add_argument('--always_acc', type=int, choices=[0,1], default=0, help="1 = always accept configuration in Metropolis")


# SLURM PARAMETERS
parser.add_argument('--no_srun', action='store_true', help="launch the executable without srun. useful for badly configured systems.")
parser.add_argument('--jobname', required=True, help="slurm job name")
parser.add_argument('--mail_user', required=True)
parser.add_argument('--mail_type', default="FAIL")

parser.add_argument('--time', help="format: DD-HH:MM:SS", required=True)
parser.add_argument('--partition')
parser.add_argument('--qos')
parser.add_argument('--account')
parser.add_argument('--constraint')
parser.add_argument('--sbatch_custom', help='this is appended to "#SBATCH --" in the sbatch script')

parser.add_argument('--nodes', required=True, help='number of nodes')
parser.add_argument('--gpuspernode', required=True)

parser.add_argument('--custom_cmds', nargs='*', type=str, help="commands to execute before job steps. the nth argument is executed before the nth job step. useful to set different CUDA_VISIBLE_DEVICES.")
parser.add_argument('--array', help="use something lik 0-99:1 to let only one instance run simultaneously")

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

# multiply single parameters

parameters=("write_every") #Lattice" "Nodes" "beta" "mass_s" "mass_ud" "rat_file")
for param in "${parameters[@]}" ; do

    param_name=${param}
    declare -n param

    if [ ${#param[@]} -eq 1 ] ; then
        echo "Using single parameter ${param_name} for all ${n_sim_steps} arguments."

        # append n_sim_steps-1 copies of the parameter.
        for ((i=1; i<n_sim_steps; i++)) ; do
            param+=("${param[0]}")
        done
    fi

    if [ ${#param[@]} -ne "$n_sim_steps" ] ; then
        echo "ERROR: $param_name should have either a single or $n_sim_steps (=n_sim_steps) arguments."
    fi
    unset -n param
done

echo "${write_every[@]}"


# parser slurm options
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
#SBATCH --gres=gpu:${gpuspernode}

module load ${module_load[@]}
module list |& cat

# "export" arrays to sub shell
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
custom_cmds=(${custom_cmds[@]@Q})

for ((i = 0 ; i < $n_sim_steps ; i++)); do

    echo "conftype = \${conftype[i]}"

    #create some paths and directories
    gaugedir="${output_base_path}/\${conftype[i]}/\${conftype[i]}\${stream_id[i]}"
    paramdir=${output_base_path}/\${conftype[i]}/param

    mkdir -p "\$gaugedir"
    mkdir -p "\$paramdir"

    gauge_file="\${gaugedir}/\${conftype[i]}\${stream_id[i]}."

    # determine conf_nr and check if gauge_file exists
    if [ "\${conf_nr[i]}" == "auto" ] ; then
        last_conf=\$(find \${gauge_file}* -printf "%f\n" | sort -r | head -n1)
	echo "last conf: \${last_conf}"
	conf_nr=\${last_conf##*.}
        echo "INFO: setting conf_nr = \$conf_nr"
    fi
    echo "INFO: gauge_file = \${gauge_file}\${conf_nr}"
    if [ ! -f "\${gauge_file}\${conf_nr}" ] ; then
        echo "WARN: gauge_file does not exist"
    fi
    # determine rand_file and check if it exists
    if [ "\${rand_file[i]}" == "auto" ] ; then
        this_rand_file="${output_base_path}/\${conftype[i]}/\${conftype[i]}\${stream_id[i]}/\${conftype[i]}\${stream_id[i]}_rand."
    fi
    echo "INFO: rand_file = \${this_rand_file}\$conf_nr"
    if [ ! -f "\${this_rand_file}\${conf_nr}" ] && [ "${rand_flag}" -eq 1 ] ; then
        echo "ERROR: given rand_file does not exist or autodetect failed! (you specified --rand_flag=1)"
        exit 1
    fi

    paramfile=\${paramdir}/\${conftype[i]}_\${stream_id[i]}.\${conf_nr}.param

    parameters="
Lattice = \${Lattice[i]}
Nodes = \${Nodes[i]}
beta    =  \${beta[i]}
mass_s  =  \${mass_s[i]}
mass_ud = \${mass_ud[i]}
rat_file = \${rat_file[i]}
seed = \${seed[i]}
rand_file = \${this_rand_file}
step_size  = ${step_size}
no_md      = ${no_md}
no_step_sf = ${no_step_sf}
no_sw      = ${no_sw}
residue   = ${residue}
residue_force = ${residue_force}
residue_meas = ${residue_meas}
cgMax  = ${cgMax}
always_acc = ${always_acc}
rand_flag = ${rand_flag}
load_conf = ${load_conf}
gauge_file = \${gauge_file}
conf_nr = \${conf_nr}
no_updates = ${no_updates}
write_every = ${write_every}
"
    echo "\$parameters" > "\$paramfile"

    echo -e "\$SLURM_JOB_ID \$SLURM_JOB_NAME | \$(hostname) | \$(pwd) \\n"
    echo -e "Start \$(date +"%F %T")\\n"

    eval \${custom_cmds[i]}

    this_Nodes=(\${Nodes[i]})
    numberofgpus=\$((this_Nodes[0] * this_Nodes[1] * this_Nodes[2] * this_Nodes[3]))
    logdir=${output_base_path}/\${conftype[i]}/logs
    mkdir -p \$logdir

    if [ $no_srun ] ; then
        run_command="stdbuf -i0 -o0 -e0 ${executable_path} \$paramfile"
    else
        run_command="srun --exclusive -n \${numberofgpus} --gres=gpu:\${numberofgpus} -u ${executable_path} \$paramfile"
    fi

    echo "\$ROCR_VISIBLE_DEVICES"
    echo -e "\$run_command \\n"
    ( \$run_command &> \$logdir/\${conftype[i]}\${stream_id[i]}.\${conf_nr}.out ) &

done
wait

echo -e "End \$(date +"%F %T")\\n"
EOF
)

echo -ne "\n===== BEGIN SBATCHSCRIPT ===\n"
echo "$sbatchscript"
echo -ne "===== END   SBATCHSCRIPT ===\n\n"

echo -en "\nSubmit y/n? "
read -r input
if [ "$input" != "y" ]; then
    echo "INFO: Did not submit job..."
    exit
fi

(sbatch <<< "$sbatchscript")

echo "sbatch script submitted" >> prev_calls_"${0##*/}".log
