version 1.0
# Bedtools tools

task intersect {
    input {
        File fileA
        File fileB
        Boolean nooverlap = false
        Boolean countoverlap = false
        Boolean sorted = false

        String outputfile = sub(basename(fileA), '.bam$', '')
        String suffixname = if (nooverlap) then '.bklist.bam' else '.sorted.bed'
        String default_location = "."
        
        Int memory_gb = 10
        Int max_retries = 1
        Int ncpu = 1
    }
    command <<<
        mkdir -p ~{default_location} && cd ~{default_location}

        if [[ "~{fileA}" == *"gz" ]]; then
            gunzip -c ~{fileA} > ~{sub(basename(fileA),'.gz','')}
        else
           ln -s ~{fileA} ~{sub(basename(fileA),'.gz','')}
        fi

        if [[ "~{fileB}" == *"gz" ]]; then
            gunzip -c ~{fileB} > ~{sub(basename(fileB),'.gz','')}
        else
           ln -s ~{fileB} ~{sub(basename(fileB),'.gz','')}
        fi

        line_count=$(cat ~{sub(basename(fileA),'.gz','')} | wc -l)
        if [ $line_count -le 1 ]; then 
            cp ~{sub(basename(fileA),'.gz','')} ~{outputfile}~{suffixname}
        else
            intersectBed \
                ~{true="-v" false="" nooverlap} \
                -a ~{sub(basename(fileA),'.gz','')} \
                -b ~{sub(basename(fileB),'.gz','')} \
                ~{true="-c" false="" countoverlap} \
                ~{true="-sorted" false="" sorted} \
                > ~{outputfile}~{suffixname}
        fi
    >>> 
    runtime {
        memory: ceil(memory_gb * ncpu) + " GB"
        maxRetries: max_retries
        docker: 'ghcr.io/stjude/abralab/bedtools:v2.25.0'
        cpu: ncpu
    }
    output {
        File intersect_out = "~{default_location}/~{outputfile}~{suffixname}" 
    }
}

task bamtobed {
    input {
        File bamfile
        String outputfile = basename(bamfile) + "2bed.bed"

        Int memory_gb = 5
        Int max_retries = 1
        Int ncpu = 1
    }
    command {
        bamToBed \
            -i ~{bamfile} \
            > ~{outputfile}
    }
    runtime {
        memory: ceil(memory_gb * ncpu) + " GB"
        maxRetries: max_retries
        docker: 'ghcr.io/stjude/abralab/bedtools:v2.25.0'
        cpu: ncpu
    }
    output {
        File bedfile = "~{outputfile}"
    }
}

task bedfasta {
    input {
        File bedfile
        String outputfile = basename(bedfile,'.bed') + ".fa"
        File reference
        File reference_index

        Int memory_gb = 5
        Int max_retries = 1
        Int ncpu = 1
    }
    command {
        if [[ "~{reference}" == *"gz" ]]; then
            gunzip -c ~{reference} > ~{sub(basename(reference),'.gz','')}
        else
           ln -s ~{reference} ~{sub(basename(reference),'.gz','')}
        fi

        ln -s ~{reference_index} ~{basename(reference_index)}

        bedtools \
            getfasta \
            -fi ~{sub(basename(reference),'.gz','')} \
            -bed ~{bedfile} \
            -fo ~{outputfile}
    }
    runtime {
        memory: ceil(memory_gb * ncpu) + " GB"
        maxRetries: max_retries
        docker: 'ghcr.io/stjude/abralab/bedtools:v2.25.0'
        cpu: ncpu
    }
    output {
        File fastafile = "~{outputfile}"
    }
}

task pairtobed {
    input {
        File fileA
        File fileB

        String outputfile = sub(basename(fileA), '.fixmate.bam', '.sorted.bklist.bam')
        String default_location = "."
        
        Int memory_gb = 10
        Int max_retries = 1
        Int ncpu = 1
    }
    command <<<
        mkdir -p ~{default_location} && cd ~{default_location}

        ln -s ~{fileA} ~{basename(fileA)}

        if [[ "~{fileB}" == *"gz" ]]; then
            gunzip -c ~{fileB} > ~{sub(basename(fileB),'.gz','')}
        else
           ln -s ~{fileB} ~{sub(basename(fileB),'.gz','')}
        fi

        pairToBed \
            -abam ~{basename(fileA)} \
            -b ~{sub(basename(fileB),'.gz','')} \
            -type neither \
            > ~{sub(basename(fileA), '.b..$', '.bklist.bam')}
        
        samtools sort \
            ~{sub(basename(fileA), '.b..$', '.bklist.bam')} \
            -o ~{outputfile}
        
    >>> 
    runtime {
        memory: ceil(memory_gb * ncpu) + " GB"
        maxRetries: max_retries
        docker: 'ghcr.io/stjude/seaseq/data_processing:v1.0.0'
        cpu: ncpu
    }
    output {
        File pairtobed_out = "~{default_location}/~{outputfile}" 
    }
}
