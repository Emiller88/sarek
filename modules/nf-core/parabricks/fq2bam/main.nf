process PARABRICKS_FQ2BAM {
    tag "${meta.id}"
    label 'process_high'

    container "nvcr.io/nvidia/clara/clara-parabricks:4.4.0-1"

    input:
    tuple val(meta), path(reads), path(interval_file)
    tuple val(meta2), path(fasta)
    tuple val(meta3), path(index)
    tuple val(meta4), path(known_sites)
    tuple val(meta5), path(known_sites_tbi)

    output:
    tuple val(meta), path("*.bam"), emit: bam, optional: true
    tuple val(meta), path("*.bai"), emit: bai, optional: true
    tuple val(meta), path("*.cram"), emit: cram, optional: true
    tuple val(meta), path("*.crai"), emit: crai, optional: true
    path "versions.yml", emit: versions
    path "qc_metrics", optional: true, emit: qc_metrics
    path ("*.table"), optional: true, emit: bqsr_table
    path ("duplicate-metrics.txt"), optional: true, emit: duplicate_metrics

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Parabricks module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}.bam"
    def in_fq_command = meta.single_end ? "--in-se-fq ${reads}" : "--in-fq ${reads}"
    def known_sites_command = known_sites ? known_sites.collect { "--knownSites ${it}" }.join(' ') : ""
    def known_sites_output = known_sites ? "--out-recal-file ${prefix}.table" : ""
    def interval_file_command = interval_file ? interval_file.collect { "--interval-file ${it}" }.join(' ') : ""
    """

    INDEX=`find -L ./ -name "*.amb" | sed 's/\\.amb\$//'`
    cp ${fasta} \$INDEX

    pbrun \\
        fq2bam \\
        --ref \$INDEX \\
        ${in_fq_command} \\
        --read-group-sm ${meta.id} \\
        --out-bam ${prefix} \\
        ${known_sites_command} \\
        ${known_sites_output} \\
        ${interval_file_command} \\
        --num-gpus ${task.accelerator.request} \\
        --tmp-dir . \\
        ${args} \\
        --monitor-usage \\
        --bwa-cpu-thread-pool 16 \\
        --bwa-nstreams 3

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
            pbrun: \$(echo \$(pbrun version 2>&1) | sed 's/^Please.* //' )
    END_VERSIONS
    """

    stub:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Parabricks module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def in_fq_command = meta.single_end ? "--in-se-fq ${reads}" : "--in-fq ${reads}"
    def known_sites_command = known_sites ? known_sites.collect { "--knownSites ${it}" }.join(' ') : ""
    def known_sites_output = known_sites ? "--out-recal-file ${prefix}.table" : ""
    def interval_file_command = interval_file ? interval_file.collect { "--interval-file ${it}" }.join(' ') : ""
    def metrics_output_command = "--out-duplicate-metrics duplicate-metrics.txt" ? "touch duplicate-metrics.txt" : ""
    def known_sites_output_command = known_sites ? "touch ${prefix}.table" : ""
    def qc_metrics_output_command = "--out-qc-metrics-dir qc_metrics " ? "mkdir qc_metrics && touch qc_metrics/alignment.txt" : ""
    """
    touch ${prefix}.bam
    touch ${prefix}.bam.bai
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
            pbrun: \$(echo \$(pbrun version 2>&1) | sed 's/^Please.* //' )
    END_VERSIONS
    """
}
