#!/usr/bin/env nextflow

// Using DSL-2
nextflow.enable.dsl=2

// All of the default parameters are being set in `nextflow.config`

// Import sub-workflows
include { validate_manifest } from './modules/manifest'
include { quality_wf } from './modules/quality'
include { align_wf } from './modules/align'
include { extract_database } from './modules/database_reader'
include { build_ligands } from './modules/system_builder'
include { build_solvents } from './modules/system_builder'

//include { minimize_ligands } from './modules/minimizer'


// Function which prints help message text
def helpMessage() {
    log.info"""
Usage:

nextflow run -profile docker . --fastq_folder test_data/fastq \
--genome_fasta test_data/genome_fasta/NC_001422.1.fasta \
--output_folder schwing --param_name nextflow.config

Required Arguments:

  Input Data:
  --fastq_folder        Folder containing paired-end FASTQ files ending with .fastq.gz,
                        containing either "_R1" or "_R2" in the filename.
  or
  --manifest            Single file with the location of all input data. Must be formatted
                        as a CSV with columns: sample,R1,R2

  Reference Data:
  --genome_fasta        Reference genome to use for alignment, in FASTA format

  Output Location:
  --output_folder       Folder for output files

Optional Arguments:
  --min_qvalue          Minimum quality score used to trim data (default: ${params.min_qvalue})
  --min_align_score     Minimum alignment score (default: ${params.min_align_score})
    """.stripIndent()
}


// Main workflow
workflow {

    // Show help message if the user specifies the --help flag at runtime
    // or if any required params are not provided
    if ( params.help || params.output_folder == false || params.genome_fasta == false ){
        // Invoke the function above which prints the help message
        helpMessage()
        // Exit out and do not run anything else
        exit 1
    }

def myString = """ 
.----------------.  .----------------.  .----------------.  .----------------. 
| .--------------. || .--------------. || .--------------. || .--------------. |
| |  _______     | || |     _____    | || |   ________   | || |   ________   | |
| | |_   __ \\    | || |    |_   _|   | || |  |  __   _|  | || |  |  __   _|  | |
| |   | |__) |   | || |      | |     | || |  |_/  / /    | || |  |_/  / /    | |
| |   |  __ /    | || |      | |     | || |     .'.' _   | || |     .'.' _   | |
| |  _| |  \\ \\_  | || |     _| |_    | || |   _/ /__/ |  | || |   _/ /__/ |  | |
| | |____| |___| | || |    |_____|   | || |  |________|  | || |  |________|  | |
| |              | || |              | || |              | || |              | |
| '--------------' || '--------------' || '--------------' || '--------------' |
 '----------------'  '----------------'  '----------------'  '----------------' """





log.info """\
         ${myString}
=============================================================================
         output_dir          : ${params.output_dir}
         database            : ${params.database}

         """
         .stripIndent()

    if ( params.database ){

        // Set up a channel from the pairs of files found with that pattern

        pathToDataBase = ""
        if (params.database == "FreeSolv"){
            pathToDataBase = "$projectDir/databases/FreeSolv/database.pickle"
        }


        database = Channel
            .fromPath( pathToDataBase )

        extract_database(
            database
        )
        nc = extract_database.out.json.flatten()
        build_ligands(nc)
        build_ligands.out.prm.view()
        build_ligands.out.crd.view()
        solvent = Channel.from( [["cSPCE","298.15"]] )
        build_solvents(solvent)
        build_solvents.out.xvv.view()
    }
    if (false){
        // If the --fastq_folder input option was provided
        if ( params.fastq_folder ){

            // Make a channel with the input FASTQ read pairs from the --fastq_folder
            // After calling `fromFilePairs`, the structure must be changed from
            // [specimen, [R1, R2]]
            // to
            // [specimen, R1, R2]
            // with the map{} expression

            // Define the pattern which will be used to find the FASTQ files
            fastq_pattern = "${params.fastq_folder}/*_R{1,2}*fastq.gz"

            // Set up a channel from the pairs of files found with that pattern
            fastq_ch = Channel
                .fromFilePairs(fastq_pattern)
                .ifEmpty { error "No files found matching the pattern ${fastq_pattern}" }
                .map{
                    [it[0], it[1][0], it[1][1]]
                }

        // Otherwise, they must have provided --manifest
        } else {

            // Parse the CSV file which was provided by the user
            // and make sure that it has the expected set of columns
            // (this is the most common user error with manifest files)
            validate_manifest(
                Channel.fromPath(params.manifest)
            )

            // Make a channel which includes
            // The sample name from the first column
            // The file which is referenced in the R1 column
            // The file which is referenced in the R2 column
            fastq_ch = validate_manifest
                .out
                .splitCsv(header: true)
                .flatten()
                .map {row -> [row.sample, file(row.R1), file(row.R2)]}

            // The code above is an example of how we can take a flat file
            // (the manifest), split it into each row, and then parse
            // the location of the files which are pointed to by their
            // paths in two of the columns (but not the first one, which
            // is just a string)

        }

        // Perform quality trimming on the input 
        quality_wf(
            fastq_ch
        )
        // output:
        //   reads:
        //     tuple val(specimen), path(read_1), path(read_2)

        // Align the quality-trimmed reads to the reference genome
        align_wf(
            quality_wf.out.reads,
            file(params.genome_fasta)
        )
        // output:
        //   bam:
        //     tuple val(specimen), path(bam)
    }
}