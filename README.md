# conf-production-scripts

This is a collection of scripts to run SIMULATeQCD's RHMC and GenerateQuenched as well as Patrick's CPU RHMC on different HPC clusters. 

## create_RHMC_job.sh 
- requires bash version >=4.4
- Usage examples for create_RHMC_job.sh can be found in the wrapper scripts. These are real production run examples, which is why they may be a bit complicated. Inside of these scripts there is usually first some definition of sets of RHMC paramaters for the different gauge ensembles, followed by a loop of over these sets, in which create_RHMC_job.sh is then called with the corresponding parameters.

This script accepts a lot of parameters which you can see by calling it with the --help option. The parameters can take care of almost any slurm configuration, and can translate its RHMC parameters to both Patrick's CPU RHMC as well as SIMULATeQCD's parameters.

Some notable features include:
- TODO
