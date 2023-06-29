#!/usr/bin/bash -l

#SBATCH --nodes 1 --ntasks 24 --mem 24G -p batch -J readcount --out logs/bbcount.%a.log --time 48:00:00
module load BBMap
hostname
MEM=24
CPU=$SLURM_CPUS_ON_NODE
N=${SLURM_ARRAY_TASK_ID}

if [ ! $N ]; then
    N=$1
    if [ ! $N ]; then
        echo "Need an array id or cmdline val for the job"
        exit
    fi
fi

INDIR=fastq
SAMPLEFILE=samples.csv
EXT=fasta
GENOMEFOLDER=$(realpath genomes)
OUTDIR=$(realpath mapping_report)
mkdir -p $OUTDIR

IFS=, # set the delimiter to be ,
sed -n ${N}p $SAMPLEFILE | while read SAMPLE READ1 READ2 CTR TYPE POPULATION
do
    if [[ $TYPE != "Monoisolate" ]]; then
	echo "skipping $SAMPLE it is a $TYPE"
	continue
    fi
    SORTED=$GENOMEFOLDER/$SAMPLE.sorted.$EXT
    
    LEFTIN=$INDIR/$READ1    
    RIGHTIN=$INDIR/$READ2
    if [ ! -f $LEFTIN ]; then
     	echo "no $LEFTIN file for $ID/$BASE in $FASTQ dir"
     	exit
    fi
    LEFT=$(realpath $LEFTIN)
    RIGHT=$(realpath $RIGHTIN)
    echo "$LEFT $RIGHT"
    REPORTOUT=${SAMPLE}
    if [ -s $SORTED ]; then
	pushd $SCRATCH
	if [ ! -s $OUTDIR/${REPORTOUT}.bbmap_covstats.txt ]; then
	    bbmap.sh -Xmx${MEM}g ref=$SORTED in=$LEFT in2=$RIGHT covstats=$OUTDIR/${REPORTOUT}.bbmap_covstats.txt  statsfile=$OUTDIR/${REPORTOUT}.bbmap_summary.txt
	fi
	popd
    fi
done

