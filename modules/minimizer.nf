#!/usr/bin/env nextflow

// Using DSL-2
nextflow.enable.dsl=2

process minimize_ligand {
    container "${params.container__biobb_amber}"
    publishDir "${params.output_folder}/${params.database}/minimizations/${molecule}_${partial_charge_method}_${model}_${temperature}", mode: 'copy', overwrite: false

    debug false
    input:
    tuple val(molecule), path(prm), path(crd), val(partial_charge_method), val(model), val(temperature), path(xvv) 
    output:
    path("sander.*"), emit: paths
    tuple val(molecule), path(prm), path(crd), val(partial_charge_method), val(model), val(temperature), path(xvv), path("sander.n_min.pdb"), path("sander.n_min.rst7"), emit: minimized_system
    maxRetries 20
    script:
    """
    #!/usr/bin/env python
    print("Hello from ${molecule} ${prm} ${crd} ${model} ${temperature} ${xvv}")
    # Import module
    from biobb_amber.sander.sander_mdrun import sander_mdrun

    # Create prop dict and inputs/outputs
    output_n_min_traj_file = 'sander.n_min.x'
    output_n_min_rst_file = 'sander.n_min.rst7'
    output_n_min_log_file = 'sander.n_min.log'

    # Minimization script from PC_PLUS
    prop = {
        'simulation_type' : "minimization",
        "mdin" : { 
            'imin' : 1, # perform minimization
            'maxcyc' : 500, # The maximum number of cycles of minimization
            'drms' : 1e-3, # RMS force
            'ntmin' : 3, # xmin algorithm
            'ntb' : 0, # no periodic boundary
            'cut' : 999, # non-bonded cutoff
            'ntpr' : 5, # printing frequency
            'ntxo' : 1, # asci formatted rst7
        },
        "dev" : "-xvv {xvv_file}".format(xvv_file="${xvv}"),
    }

    # Create and launch bb
    sander_mdrun(input_top_path="${prm}",
                input_crd_path="${crd}",
                output_traj_path=output_n_min_traj_file,
                output_rst_path=output_n_min_rst_file,
                output_log_path=output_n_min_log_file,
                properties=prop)

    # Import module
    from biobb_amber.process.process_minout import process_minout

    # Create prop dict and inputs/outputs
    output_n_min_dat_file = 'sander.n_min.energy.dat'
    prop = {
        "terms" : ['ENERGY']
    }

    # Create and launch bb
    process_minout(input_log_path=output_n_min_log_file,
                output_dat_path=output_n_min_dat_file,
                properties=prop)

    from biobb_amber.ambpdb.amber_to_pdb import amber_to_pdb
    output_n_min_pdb_file = "sander.n_min.pdb"
    prop = {
        'remove_tmp': True,
        'check_extensions' : False,
    }
    amber_to_pdb(input_top_path="${prm}",
                input_crd_path=output_n_min_rst_file,
                output_pdb_path=output_n_min_pdb_file,
                properties=prop)
    """
}


process add_box {
    container "${params.container__biobb_amber}"
    publishDir "${params.output_folder}/${params.database}/minimizations/${molecule}_${model}_${temperature}", mode: 'copy', overwrite: false

    debug false
    input:
    tuple val(molecule), path(prm), path(crd), val(partial_charge_method), val(model), val(temperature), path(xvv), path(pdb), path(rst)
    output:
    tuple val(molecule), path(prm), path(crd), val(partial_charge_method), val(model), val(temperature), path(xvv), path(pdb), path("sander.n_min.box.rst7"), emit: minimized_system


    shell:
    """
    ChBox -c ${rst} -X 50 -Y 50 -Z 50 -o sander.n_min.box.rst7
    """
}




workflow minimize_ligands {
    take:
    all
    main:
    // Process each JSON file asynchronously
    minimize_ligand(all)
    add_box(minimize_ligand.out.minimized_system)
    emit:
    minimized_system = add_box.out.minimized_system

}