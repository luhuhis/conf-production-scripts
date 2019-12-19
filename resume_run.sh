#!/bin/bash
conftype=$1
streams=$2
for dir in /work/temp/altenkort/conf/quenched/$conftype/${conftype}_$streams ; do
    cd $dir
    conf=`ls -r | grep rand | head -n1`
        conftype=${conf##rand_}; conftype=${conftype%_*}; conftype=${conftype%_*}
        str_id=${conf%_*} ; str_id=${str_id##*_}
        conf_nr=${conf##*_U}
        #nconfs=`bc <<< 1000-$conf_nr/500`
        nconfs=`bc <<< 1999-$conf_nr/500`
    /work/temp/altenkort/conf/quenched/bin/run_GenerateQuenched.sh $conftype $str_id $nconfs temp $conf_nr
    echo ""
done

    #ls -lt | head -n2 | tail -n1
    #for ((i=01;i<=28;i++)) ; do j=`seq -w $i 99 99` ; gpuspernode=`squeue -h -t R -O gres,nodelist | grep gpu | grep v$j | wc -l` ; echo "$gpuspernode/8 GPUs in use on v$j"; done
    #%echo -n "Node to run on (e.g. v01): "
    #read nodelist
