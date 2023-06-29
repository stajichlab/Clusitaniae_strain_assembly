#!/usr/bin/bash  -l
#SBATCH -p batch --nodes 1 --ntasks 1 -c 8 --mem 24G --out logs/AAFTF.%a.log --time 18:00:00 -J clusAAFTF

#This script takes a reference genome and a tab delimited sample list of: sample name\tsample_reads_1.fq\tsample_reads_2.fq.
# For each line defined by the number in an array job, this script will align set of reads to a reference genome using bwa mem.
#After, it uses picard to add read groups and mark duplicates. 
module load workspace/scratch
TEMPDIR=$SCRATCH
FASTQDIR=fastq
IFS=,
CONFIG=config.txt
SAMPLESINFO=samples.csv
if [ -f $CONFIG ]; then
    source $CONFIG
fi

module load AAFTF
#ADAPTORS=$(dirname $TRIMMOMATIC)"adaptors/TruSeq3-PE.fa"
#export PATH=$HOME/projects/AAFTF/scripts:$PATH

hostname
CPU=1
if [ $SLURM_CPUS_ON_NODE ]; then
 CPU=$SLURM_CPUS_ON_NODE
fi
N=${SLURM_ARRAY_TASK_ID}

if [ ! $N ]; then
 N=$1
 if [ ! $N ]; then 
    echo "Need a number via slurm --array or cmdline"
    exit
 fi
fi
if [ ! $SAMPLESINFO ]; then
    echo "need to define \$SAMPLESINFO in $CONFIG file"
    exit
fi
ASM=genomes
STAGEDIR=working_AAFTF
mkdir -p $STAGEDIR
mkdir -p $ASM
PHYLUM=Ascomycota
sed -n ${N}p $SAMPLESINFO | while read SAMPLE READ1 READ2 CTR TYPE POPULATION
do
    LEFT_IN=$FASTQDIR/$READ1
    RIGHT_IN=$FASTQDIR/$READ2
    BASE=$SAMPLE
    ASMFILE=$ASM/${BASE}.spades.fasta   
    VECCLEAN=$ASM/${BASE}.vecscreen.fasta
    PURGE=$ASM/${BASE}.sourpurge.fasta
    CLEANDUP=$ASM/${BASE}.rmdup.fasta
    PILON=$ASM/${BASE}.pilon.fasta
    SORTED=$ASM/${BASE}.sorted.fasta
    STATS=$ASM/${BASE}.sorted.stats.txt
    LEFT=$STAGEDIR/${BASE}_filtered_1.fastq.gz
    RIGHT=$STAGEDIR/${BASE}_filtered_2.fastq.gz
    TRIMLEFT=$STAGEDIR/${BASE}_1P.fastq.gz
    TRIMRIGHT=$STAGEDIR/${BASE}_2P.fastq.gz

    echo "$SAMPLE $LEFT_IN $RIGHT_IN $LEFT $RIGHT"
    if [ ! -f $TRIMLEFT ]; then
	AAFTF trim --method bbduk --left $LEFT_IN --right $RIGHT_IN -c $CPU -o $STAGEDIR/${BASE}
    fi
    if [ ! -f $STAGEDIR/${BASE}_filtered_1.fastq.gz ]; then
    	AAFTF filter --aligner bbduk --left $TRIMLEFT --right $TRIMRIGHT -c $CPU -o $STAGEDIR/${BASE}
    fi
    if [ ! -f $ASMFILE ]; then
	    AAFTF assemble -c $CPU --left $LEFT --right $RIGHT -o $ASMFILE -w $STAGEDIR/spades_$BASE
    fi
    if [ -s $ASMFILE ]; then
	rm -rf $STAGEDIR/spades_${BASE}/K?? $STAGEDIR/spades_${BASE}/tmp
    fi

    if [ ! -f $VECCLEAN ]; then 
    	AAFTF vecscreen -i $ASMFILE -c $CPU -o $VECCLEAN 
    fi
    if [ ! -f $PURGE ]; then
	AAFTF sourpurge -i $VECCLEAN -o $PURGE -c $CPU --phylum $PHYLUM --left $LEFT  --right $RIGHT
    fi
    
    COUNT=$(grep -c ">" $PURGE)
    if [ -z $COUNT ]; then
	    echo "Could not get any scaffolds out of the post-processed assembly (sourpurge). Quiting"
	    exit
    fi
    if [ "$COUNT" -gt 20000 ]; then
	echo "too many contigs to run rmdup ($COUNT) skipping that step and jumping to Pilon"
	if [ ! -f $PILON ]; then
	    AAFTF pilon -i $PURGE -o $PILON -c $CPU --left $LEFT --right $RIGHT
	fi
    else
	if [ ! -f $CLEANDUP ]; then
    	    AAFTF rmdup -i $PURGE -o $CLEANDUP -c $CPU
	fi
	if [ ! -f $PILON ]; then
	    echo "pilon -i $CLEANDUP -o $PILON -p $BASE"
    	    AAFTF pilon -i $CLEANDUP -o $PILON -c $CPU --left $LEFT --right $RIGHT
	fi
    fi
    
    if [ ! -f $PILON ]; then
	echo "Error running Pilon, did not create file. Exiting"
	exit
    fi
    
    if [ ! -f $SORTED ]; then
	AAFTF sort -i $PILON -o $SORTED
    fi
    
    if [ ! -f $STATS ]; then
	AAFTF assess -i $SORTED -r $STATS
    fi
done
