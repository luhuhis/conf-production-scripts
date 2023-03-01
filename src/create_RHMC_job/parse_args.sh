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
parser.add_argument('--CheckConf_path', type=str, help="if provided and conf_nr=auto, then first CheckConf is used to check whether the last conf is ok. if it is not ok, then it will try the second to last one.")
parser.add_argument('--CheckRand_path', type=str, help="if provided and conf_nr=auto, then first CheckRand is used to check whether the last randfile is ok. if it is not ok, then it will try the second to last one.")
parser.add_argument('--module_load', nargs='*', help="modules will be loaded at the start of the sbatch script. example: --module_load gcc8 cmake3 cuda11")
parser.add_argument('--output_base_path', required=True, help="folder that will contain the output")
parser.add_argument('--subfolder_for_logfiles', default="logs", type=str, help="subfolder inside of output_base_path that will contain the high-level log files which report on whether job steps start/complete successfully.")
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
param_arrays.add_argument('--seed', nargs='*', required=True)


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

parser.add_argument('--array', help="use something like 0-99%%1 to let only one instance run simultaneously")

EOF