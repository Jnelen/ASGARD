#
#Genera los ficheros necesarios de configuracion necesarios para la simulacion
#
#
#	Genera los ficheros necesarias de configuracion para la DM
#	1º topologia
#	2º Equlibracion
#	3º Equilibracion
#	4º Smilulacion
#
#     chuleta
# 50.000		; 2 * 50000 = 100 ps     (0.1ns)
# 500.000		; 2 * 500000 = 1000 ps     (1ns)
# 4.000.000		; 2 * 4000000 = 8000 ps    (8ns)
# 5.000.000	    ; 2 * 5.000.000 = 10000 ps   (10 ns)
#
#
#   Segun el protocolo de hugo las etapas de equilibracion mas optima es de (1 ns)
#   0.2 ns nvt
#   0.2 ns npt * 4
#
#!/usr/bin/env bash
path_config_files=${path_external_sw}gromacs/config_files/

ejecutar()
{
   generateFilesConf
}

generateFilesConf()
{
	# simulacion estandar
	# For proper integration of the Nose-Hoover thermostat, tau-t (0.4) should
  	# be at least 20 times larger than nsttcouple*dt (0.04)
  	# For proper integration of the Nose-Hoover thermostat, tau-t (0.1) should
    # be at least 20 times larger than nsttcouple*dt (0.02)

 	#
    #	Transpasamos el nombre de los queries
    #
	for query in "${name_queries[@]}"; do
	    first_query=
		queries="$queries $query"
	done
	#tc_grps="Protein Non-Protein"
	#energy_grps="protein SOL $queries"

	#comm_grps="Protein" #para centrar la simu alrededor del sistema
	#queries=`echo $queries | xargs`
	#tc_grps="DNA Water_and_ions_$queries"
	#energy_grps="DNA SOL $queries"
	#comm_grps="Dna" #para centrar la simu alrededor del sistema


	nstlist="20"
    num_ions=${system_charge%.*}
    num_ions=1
    tau_t="0.9 0.9"
    ref_t="$temp $temp"
    num_ions=${system_charge%.*}
    if [ "${mode_gr}" == "DNA_QUERY" ]; then
	    queries=`echo $queries | xargs`
	    tc_grps="DNA Water_and_ions_$queries"
	    comm_grps="DNA"
	    energy_grps="DNA SOL $queries"
	elif [ "${mode_gr}" == "QUERIES" ] || [ "${mode_gr}" == "BIPHSIC_SYSTEMS" ]; then #si es solo query e sobresscriben los parametros anteriores

		if [ ${num_ions} -gt 0 ];then
		    name_solv="CL"
		elif [ ${num_ions} -lt 0 ];then
		    name_solv="NA"
		else
		    name_solv=""
		fi
		if [ $num_ions -eq 0 ];then
			tc_grps="SOL $queries"
			comm_grps=${queries}
			energy_grps=${queries}
		else
			tc_grps="SOL $name_solv $queries"
			energy_grps=${tc_grps}
			comm_grps=${queries}
		fi
		tau_t="0.9" #0.9
        ref_t="300" #300

        for word in $energy_grps
        do
            tau_t="$tau_t 0.9"
            ref_t="$ref_t $temp"
        done
    else
        tc_grps="Protein Non-Protein"
	    energy_grps="protein SOL $queries"
	    comm_grps="Protein" #para centrar la simu alrededor del sistema
	fi




    file_conf_tpr=${out_grid}_tpr.mdp
 	source ${path_config_files}tpr.sh

    file_conf_min=${out_grid}_min.mdp
	source ${path_config_files}minimization.sh

	file_conf_nvt=${out_grid}_nvt.mdp
	source  ${path_config_files}nvt.sh

	step_step=`expr $step_nvt`
	file_conf_npt=${out_grid}_npt_${step_step}.mdp
	source ${path_config_files}npt.sh

    step_step=`expr $step_step + $step_npt`
	file_conf_npt=${out_grid}_npt_${step_step}.mdp
	source ${path_config_files}npt.sh

    step_step=`expr $step_step + $step_npt`
	file_conf_npt=${out_grid}_npt_${step_step}.mdp
	source ${path_config_files}npt.sh

    step_step=`expr $step_step + $step_npt`
	file_conf_npt=${out_grid}_npt_${step_step}.mdp
	source ${path_config_files}npt.sh
	file_conf_npt=${out_grid}_npt_

    file_conf_md=${out_grid}_md.mdp
    int_md=0
	source ${path_config_files}simulation.sh

}
