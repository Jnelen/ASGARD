#!/bin/bash
# Inputs: 
# MD Result folder (xtc, tpr, gro,pdb_protein,mol2_ligand)

DIR=$1
bind=$(pwd | cut -d/ -f1-2)/
singularity="${PWD}/singularity/"
gmx=$(echo singularity exec --bind $bind "$singularity"/ASGARD.simg gmx)
echo $gmx
#
#PDB=$2
#MOL2=$3
#
#TRAJ=$1
#TOP=$2 # tpr
#GRO=$3
#PDB=$4
#MOL2=$5
#NAME=$6 # optional
#
#
#
##PARA ONLY TARGET
#
## if NAME is empty
#

############################
echo 'Creating analysis folder...'
###########################

if [[ ${DIR: -1} == / ]]; then
DIR=$(echo $DIR | sed 's/.$//')
fi

ORIGIN=${DIR##*/}
NAME='VS_GR_'${DIR##*/}

#NAME="${f%.*}"
#  NAME=$(echo $TRAJ | cut -f 1 -d '/' | cut -f 1 -d '.')
#fi
RESULTS=$NAME'_results'-"$(date +%Y-%d-%m)"
echo $RESULTS

#if [[ -d $RESULTS ]]; then 
#                while [ "$input" != "Y" ] && [ "$input" != "y" ] && [ "$input" != "N" ] && [ "$input" != "n" ] && [ "$input" != "zz" ] ; do
#                        echo "Analysis folder already exists. Do you want to delete it?"
#                        echo "(Y/y) Delete folder"
#                        echo "(N/n) Exit"
#                        read  input
#                done
#                if [ "$input" == "Y" ] || [ "$input" == "y" ];then
#                        rm -r $RESULTS
#                        echo "Moving files to working folder"
#                elif [ "$input" == "n" ] || [ "$input" == "N" ];then
#                        exit
#                fi  
#fi

mkdir -p "$RESULTS"/{molecules,grids,energies,jobs,results} # better mkdir -p "$RESULTS"-"$(date +%Y-%d-%m-%H:%M:%S)"
#cp $NAME/*.xtc $NAME/*.tpr $NAME/*.top  $RESULTS/molecules

for i in $(ls $ORIGIN/* | cut -d'.' -f2); do
      if [ $i  = 'top' ]; then
            cp $ORIGIN/*.$i $RESULTS/molecules/$NAME'.'$i
      elif [ $i  = 'tpr' ]; then
            cp $ORIGIN/*.$i $RESULTS/molecules/$NAME'_md.'$i
      elif [ $i  = 'xtc' ]; then
            cp $ORIGIN/*.$i $RESULTS/molecules/$NAME'_md.'$i                     
      elif [ $i =  'edr' ]; then
            cp $ORIGIN/*.$i $RESULTS/molecules/$NAME'_md.'$i
      elif [ $i  = 'pdb' ]; then
            cp $ORIGIN/*.$i targets/
            PDB=$(ls $ORIGIN/*.pdb | sed s/^.*\\/\// | cut -d'.' -f1)
      elif [ $i  = 'mdp' ]; then
            cp $ORIGIN/*.$i $RESULTS/grids/$NAME'_md.'mdp
      elif [ $i  = 'mol2' ]; then
            cp $ORIGIN/*.mol2 queries/
            MOL2=$(ls $ORIGIN/*.mol2 | sed s/^.*\\/\// | cut -d'.' -f1)
      elif [ $i  = 'gro' ]; then
            for j in $(ls $ORIGIN/*$i); do
              if [[ $j = *"npt"* ]];then
                cp $j $RESULTS/molecules/$NAME'_npt_1.gro_md.'$i
              else
                cp $j $RESULTS/molecules/$NAME'_md.'$i
              fi
            done
      else
        #cp $ORIGIN/*.$i $RESULTS/molecules/$NAME'_md.'$i
        cp $ORIGIN/*.$i $RESULTS/molecules/
      fi
done

if [ -d $ORIGIN/*'.ff' ]; then
    cp -r $ORIGIN/*.'ff' $RESULTS/molecules/
fi
#cp $NAME/* $RESULTS/molecules
#cp $NAME/*.top $RESULTS/molecules/$NAME.top
mkdir targets/$NAME
cp $ORIGIN/*.pdb targets/$NAME
mkdir queries/$NAME
cp $ORIGIN/*.mol2 queries/$NAME

###########################
echo 'Centering trajectory...'
###########################

CENTER="$RESULTS"/molecules/"$NAME"_center.xtc

echo 1 0 | $gmx trjconv -s $RESULTS/molecules/*.tpr -f $RESULTS/molecules/*.xtc -center -ur compact -pbc mol -o "$RESULTS"/molecules/"$NAME"_ori_tmp.xtc
echo 4 0 | $gmx trjconv -s $RESULTS/molecules/*.tpr -f $RESULTS/molecules/"$NAME"_ori_tmp.xtc -fit rot+trans -o $CENTER

###########################
echo 'Generating pdb file...'
###########################

#echo 0 |$gmx trjconv -f $CENTER -s $RESULTS/molecules/*.tpr -o $RESULTS/molecules/"$NAME".pdb -tu ns -e 100 # last frame

sh ASGARD/login_node/create_pdb.sh $CENTER $RESULTS/molecules/*.tpr $RESULTS/molecules/"$NAME".pdb -1 gmx


#############################
echo 'Generating topology'   
#############################

if [ -z "$(ls -A queries/$NAME)" ]; then
	singularity exec --bind $bind singularity/ASGARD.simg ASGARD/external_sw/gromacs/topology/generate_topology.py -t targets/$NAME/*.pdb -p TARGET
#	cp targets/$NAME/*.top $RESULTS/molecules/$NAME.top
fi


if [ -d $RESULTS/molecules/*"ff" ]; then
  echo "Forcefield included"
else
  singularity exec --bind $bind singularity/ASGARD.simg ASGARD/external_sw/gromacs/topology/generate_topology.py -t targets/$NAME/*.pdb -q queries/$NAME/
  sh ASGARD/login_node/edit_topology.sh $RESULTS/molecules/$NAME queries/$NAME #prefix
  sh ASGARD/login_node/edit_include.sh queries/$NAME
fi

##############################
echo 'Creating index files'
##############################

#echo 'q' | $gmx make_ndx -f $RESULTS/molecules/$NAME'_md.gro' -o $RESULTS/molecules/grids/VS_GR_4ejeB_preprocess_ebolaB_preprocess_complex_index.ndx

sh ASGARD/login_node/generate_index.sh $RESULTS/molecules/$NAME'_md.gro' $RESULTS/grids/"$NAME"_index.ndx queries/$NAME/*query.gro

############################## 
echo 'Creating resume'
##############################

TITLE=$PDB'_'$MOL2

sh ASGARD/login_node/create_resume.sh $(pwd)'/'$RESULTS $TITLE $RESULTS/grids/$NAME'_md.mdp' ${ORIGIN}/${PDB}.pdb ${ORIGIN}/${MOL2}.mol2




