#!/bin/bash
conftype=${1:?"Please specify conftype, e.g. s064t64_b0687361, s120t30_b0739400"}
str_id=${2:?"Please specify stream id [a-zA-Z]"}
nconfs=${3:-1000}
output_partition=${4:-temp}
conf_nr=${5} #if you set this parameter, then (un)comment the last 3+3 lines of parameters to resume run at this conf_nr!
nodex=${6:-1}
nodey=${7:-1}
nodez=${8:-1}
nodet=${9:-1}

numberofgpus=$(($nodex * $nodey * $nodez * $nodet))
nodes="$nodex $nodey $nodez $nodet"


if [[ "$output_partition" == temp ]]; then
    output_base_path=/work/temp/altenkort/conf
elif [[ "$output_partition" == conf ]]; then
    output_base_path=/work/conf/altenkort/
fi

if [[ "$str_id" != [a-zA-Z] ]]; then
    echo "error: string id must be single letter a-Z"
    exit -1
fi
echo "$conftype $str_id $nconfs $output_partition $conf_nr $nodes = $numberofgpus"
echo -n "Continue y/n? "
read input
if [ "$input" != "y" ]; then
    echo "Did not start job..."
    exit 
fi
read -p "Really continue? Press enter if you dare..."

jobname=gen_${conftype}_$str_id
logdir=$output_base_path/quenched/${conftype}/logs
paramdir=$output_base_path/quenched/${conftype}/param
paramfile=$paramdir/${conftype}_${str_id}.param
outputdir=$output_base_path/quenched/${conftype}/${conftype}_${str_id}
mkdir -p $outputdir
mkdir -p $logdir
mkdir -p $paramdir


ns=${conftype#s}; ns=${ns%%t*}
nt=${conftype#*t}; nt=${nt%%_b*}
Lattice="$ns $ns $ns $nt"
beta=${conftype#*_b}; beta=`bc <<< "scale=5;$beta/100000"`

parameters="Lattice = $Lattice
Nodes = $nodes
beta = $beta
format = nersc
endianness = auto
stream = $str_id
output_dir = $outputdir
nconfs = $nconfs
nsweeps_ORperHB = 4
nsweeps_HBwithOR = 500
#start = one
#nsweeps_thermal_HB_only = 500
#nsweeps_thermal_HBwithOR = 4000
conf_nr = $conf_nr
prev_conf = $outputdir/conf_${conftype}_${str_id}_U$conf_nr
prev_rand = $outputdir/rand_${conftype}_${str_id}_U$conf_nr"
echo "$parameters" > $paramfile

#--nodelist=$nodelist
sbatch << EOF
#!/bin/bash
#SBATCH --job-name=${jobname}
#SBATCH --output=$logdir/${jobname}_%j.out
#SBATCH --error=$logdir/${jobname}_%j.err
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=altenkort@physik.uni-bielefeld.de
#SBATCH --partition=volta
#SBATCH --ntasks=$numberofgpus
#SBATCH --gpus=$numberofgpus

echo "Starting Job ${jobname} at \$(date) on \$HOSTNAME with JobID \$SLURM_JOB_ID"
mpiexec -np $numberofgpus /work/temp/altenkort/conf/quenched/bin/GenerateQuenched $paramfile
EOF
