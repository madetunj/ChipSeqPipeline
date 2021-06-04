version 1.0
import "workflows/tasks/fastqc.wdl"
import "workflows/tasks/bedtools.wdl"
import "workflows/tasks/bowtie.wdl"
import "workflows/tasks/bowtie2.wdl"
import "workflows/tasks/samtools.wdl"
import "workflows/tasks/macs.wdl"
import "workflows/tasks/bamtogff.wdl"
import "workflows/tasks/sicer.wdl"
import "workflows/workflows/motifs.wdl"
import "workflows/tasks/rose.wdl"
import "workflows/tasks/util.wdl"
import "workflows/workflows/visualization.wdl" as viz
import "workflows/tasks/runspp.wdl"
import "workflows/tasks/sortbed.wdl"
import "workflows/tasks/sratoolkit.wdl" as sra

workflow seaseq {
    String pipeline_ver = 'v1.0.0'

    meta {
        title: 'SEAseq Analysis'
        summary: 'Single-End Antibody Sequencing (SEAseq) Pipeline'
        description: 'A comprehensive automated computational pipeline for all ChIP-Seq/CUT&RUN data analysis.'
        version: '1.0.0'
        details: {
            citation: 'pending',
            contactEmail: 'modupeore.adetunji@stjude.org',
            contactOrg: "St Jude Children's Research Hospital",
            contactUrl: "",
            upstreamLicenses: "MIT",
            upstreamUrl: 'https://github.com/stjude/seaseq',
            whatsNew: [
                {
                    version: "1.0",
                    changes: ["Initial release"]
                }
            ]
        }
        parameter_group: {
            reference_genome: {
                title: 'Reference genome',
                description: 'Genome specific files. e.g. reference FASTA, GTF, blacklist, motif databases, FASTA index, bowtie index .',
                help: 'Input reference genome files as defined. If some genome data are missing then analyses using such data will be skipped.'
            },
            input_genomic_data: {
                title: 'Input FASTQ data',
                description: 'Genomic input files for experiment.',
                help: 'Input one or more sample data and/or SRA identifiers.'
            },
            analysis_parameter: {
                title: 'Analysis parameter',
                description: 'Analysis settings needed for experiment.',
                help: 'Analysis settings; such output analysis file name.'
            }
        }
    }
    input {
        # group: reference_genome
        File reference
        File? blacklist
        File gtf
        Array[File]? bowtie_index
        Array[File]? motif_databases

        # group: input_genomic_data
        Array[String]? sra_id
        Array[File]? fastqfile

        # group: analysis_parameter
        String? filename_prefix
        Boolean run_bowtie2 = false

    }

    parameter_meta {
        reference: {
            description: 'Reference FASTA file',
            group: 'reference_genome',
            patterns: ["*.fa", "*.fasta", "*.fa.gz", "*.fasta.gz"]
        }
        blacklist: {
            description: 'Blacklist file in BED format',
            group: 'reference_genome',
            help: 'If defined, blacklist regions listed are excluded after reference alignment.',
            patterns: ["*.bed", "*.bed.gz"]
        }
        gtf: {
            description: 'gene annotation file (.gtf)',
            group: 'reference_genome',
            help: 'Input gene annotation file from RefSeq or GENCODE (.gtf).',
            patterns: ["*.gtf", "*.gtf.gz", "*.gff", "*.gff.gz", "*.gff3", "*.gff3.gz"]
        }
        bowtie_index: {
            description: 'bowtie v1 index files (*.ebwt)',
            group: 'reference_genome',
            help: 'If not defined, bowtie v1 index files are generated, will take a longer compute time.',
            patterns: ["*.ebwt"]
        }
        motif_databases: {
            description: 'One or more of the MEME suite motif databases (*.meme)',
            group: 'reference_genome',
            help: 'Input one or more motif databases available from the MEME suite (https://meme-suite.org/meme/db/motifs).',
            patterns: ["*.meme"]
        }
        sra_id: {
            description: 'One or more SRA (Sequence Read Archive) run identifiers',
            group: 'input_genomic_data',
            help: 'Input publicly available FASTQs (SRRs). Multiple SRRs are separated by commas (,).',
            example: 'SRR12345678'
        }
        fastqfile: {
            description: 'One or more FASTQs',
            group: 'input_genomic_data',
            help: 'Upload zipped FASTQ files.',
            patterns: ["*fq", "*.fq.gz", "*.fastq", "*.fastq.gz"]
        }
        filename_prefix: {
            description: 'Results output name prefix',
            group: 'analysis_parameter',
            help: 'Input preferred analysis results file name prefix (recommended if multiple FASTQs are provided).',
            example: 'AllMerge_mapped'
        }
    }

### ---------------------------------------- ###
### ------------ S E C T I O N 1 ----------- ###
### ------ pre-process analysis files ------ ###
### ---------------------------------------- ###

    if ( defined(sra_id) ) {
        # Download sample file(s) from SRA database
        # outputs:
        #    fastqdump.fastqfile : downloaded sample files in fastq.gz format
        Array[String] string_sra = [1] #buffer to allow for sra_id optionality
        Array[String] sra_id_ = select_first([sra_id, string_sra])
        scatter (eachsra in sra_id_) {
            call sra.fastqdump {
                input :
                    sra_id=eachsra,
                    cloud="false"
            }
        }

        Array[File] fastqfile_ = flatten(fastqdump.fastqfile)
    }

    if ( !run_bowtie2 ) {
        # using bowtie1
        if ( !defined(bowtie_index) ) {
            # create bowtie index when not provided
            call bowtie.index as bowtie_idx {
                input :
                    reference=reference
            }
        }

        if ( defined(bowtie_index) ) {
            # check total number of bowtie indexes provided
            Array[String] string_bowtie_index = [1] #buffer to allow for bowtie_index optionality
            Array[File] int_bowtie_index = select_first([bowtie_index, string_bowtie_index])
            if ( length(int_bowtie_index) != 6 ) {
                # create bowtie index if 6 index files aren't provided
                call bowtie.index as bowtie_idx_2 {
                    input :
                        reference=reference
                }
            }
        }
    } # end if NOT bowtie2

    if ( run_bowtie2 ) {
        # using bowtie2
        if ( !defined(bowtie_index) ) {
            # create bowtie index when not provided
            call bowtie2.index as bowtie2_idx {
                input :
                    reference=reference
            }
        }

        if ( defined(bowtie_index) ) {
            # check total number of bowtie indexes provided
            Array[String] string_bowtie2_index = [1] #buffer to allow for bowtie_index optionality
            Array[File] int_bowtie2_index = select_first([bowtie_index, string_bowtie2_index])
            if ( length(int_bowtie2_index) != 6 ) {
                # create bowtie index if 6 index files aren't provided
                call bowtie2.index as bowtie2_idx_2 {
                    input :
                        reference=reference
                }
            }
        }
    } # end if bowtie2

    call samtools.faidx as samtools_faidx {
        # create FASTA index and chrom sizes files
        input :
            reference=reference
    }


    Array[File] bowtie_index_ = select_first([bowtie_idx_2.bowtie_indexes, bowtie_idx.bowtie_indexes, bowtie2_idx_2.bowtie_indexes, bowtie2_idx.bowtie_indexes, bowtie_index])
    Array[File] fastqfiles = flatten(select_all([fastqfile, fastqfile_]))

### ---------------------------------------- ###
### ------------ S E C T I O N 2 ----------- ###
### ---- A: analysis of FASTQs provided ---- ###
### ---------------------------------------- ###

    # if multiple fastqfiles are provided
    Boolean multi_fastq = if length(fastqfiles) > 1 then true else false
    Boolean one_fastq = if length(fastqfiles) == 1 then true else false
    if ( multi_fastq ) {
        scatter (eachfastq in fastqfiles) {
            # Execute analysis on each fastq file provided
            # Analysis executed:
            #   FastQC
            #   FASTQ read length distribution
            #   Reference Alignment using Bowtie (-k2 -m2)
            #   Convert SAM to BAM
            #   FastQC on BAM files
            #   Remove Blacklists (if provided)
            #   Remove read duplicates
            #   Summary statistics on FASTQs
            #   Combine html files into one for easy viewing
            call fastqc.fastqc as fastqc {
                input :
                    inputfile=eachfastq,
                    default_location='EACH_FASTQ/' + sub(basename(eachfastq),'\.f.*q\.gz','') + '/QC/FastQC'
            }

            call util.basicfastqstats as bfs {
                input :
                    fastqfile=eachfastq,
                    default_location='EACH_FASTQ/' + sub(basename(eachfastq),'\.f.*q\.gz','') + '/QC/SummaryStats'
            }

            if ( !run_bowtie2 ) {
                call bowtie.bowtie {
                    input :
                        fastqfile=eachfastq,
                        index_files=bowtie_index_,
                        metricsfile=bfs.metrics_out
                }
            }
            if ( run_bowtie2 ) {
                call bowtie2.bowtie2 {
                    input :
                        fastqfile=eachfastq,
                        index_files=bowtie_index_
                }
            }

            File bowtie_samfile = select_first(flatten(select_all([bowtie.samfile, bowtie2.samfile])))

            call samtools.viewsort {
                input :
                    samfile=bowtie_samfile,
                    default_location='EACH_FASTQ/' + sub(basename(eachfastq),'\.f.*q\.gz','') + '/BAM_files'
            }

            call fastqc.fastqc as bamfqc {
                input :
                    inputfile=viewsort.sortedbam,
                    default_location='EACH_FASTQ/' + sub(basename(eachfastq),'\.f.*q\.gz','') + '/QC/FastQC'
            }

            call samtools.indexstats {
                input :
                    bamfile=viewsort.sortedbam,
                    default_location='EACH_FASTQ/' + sub(basename(eachfastq),'\.f.*q\.gz','') + '/BAM_files'
            }

            if ( defined(blacklist) ) {
                # remove blacklist regions
                String string_indv_blacklist = "" #buffer to allow for blacklist optionality
                File indv_blacklist_ = select_first([blacklist, string_indv_blacklist])
                call bedtools.intersect as indv_rmblklist {
                    input :
                        fileA=viewsort.sortedbam,
                        fileB=indv_blacklist_,
                        default_location='EACH_FASTQ/' + sub(basename(eachfastq),'\.f.*q\.gz','')+'/BAM_files',
                        nooverlap=true
                }
                call samtools.indexstats as indv_bklist {
                    input :
                        bamfile=indv_rmblklist.intersect_out,
                        default_location='EACH_FASTQ/' + sub(basename(eachfastq),'\.f.*q\.gz','')+'/BAM_files'
                }
            } # end if (blacklist provided)

            File indv_afterbklist = select_first([indv_rmblklist.intersect_out, viewsort.sortedbam])
            File indv_indexbam = select_first([indv_bklist.indexbam, indexstats.indexbam])

            call samtools.markdup as indv_markdup {
                input :
                    bamfile=indv_afterbklist,
                    default_location='EACH_FASTQ/' + sub(basename(eachfastq),'\.f.*q\.gz','')+'/BAM_files'
            }

            call samtools.indexstats as indv_mkdup {
                input :
                    bamfile=indv_markdup.mkdupbam,
                    default_location='EACH_FASTQ/' + sub(basename(eachfastq),'\.f.*q\.gz','')+'/BAM_files'
            }

            call runspp.runspp as indv_runspp {
                input:
                    bamfile=indv_afterbklist
            }

            call util.summarystats {
                input:
                    sppfile=indv_runspp.spp_out,
                    bamflag=indexstats.flagstats,
                    rmdupflag=indv_mkdup.flagstats,
                    bkflag=indv_bklist.flagstats,
                    fastqczip=fastqc.zipfile,
                    fastqmetrics=bfs.metrics_out,
                    default_location='EACH_FASTQ/' + sub(basename(eachfastq),'\.f.*q\.gz','') + '/QC/SummaryStats'
            }
        } # end scatter (for each fastq)

        # MERGE BAM FILES
        # Execute analysis on merge bam file
        # Analysis executed:
        #   Merge BAM (if more than 1 fastq is provided)
        #   FastQC on Merge BAM (AllMerge_<number>_mapped)

        # merge bam files and perform fasTQC if more than one is provided
        call util.mergehtml {
            input:
                htmlfiles=summarystats.htmlfile,
                default_location='EACH_FASTQ',
                outputfile = if defined(filename_prefix) then filename_prefix + '_seaseq-summary-stats.html' else 'AllMapped_' + length(fastqfiles) + '_seaseq-summary-stats.html'
        }

        call samtools.mergebam {
            input:
                bamfiles=viewsort.sortedbam,
                default_location = if defined(filename_prefix) then filename_prefix + '/BAM_files' else 'AllMerge_' + length(viewsort.sortedbam) + '_mapped' + '/BAM_files',
                outputfile = if defined(filename_prefix) then filename_prefix + '.sorted.bam' else 'AllMerge_' + length(fastqfiles) + '_mapped.sorted.bam'
        }

        call fastqc.fastqc as mergebamfqc {
            input:
	        inputfile=mergebam.mergebam,
                default_location=sub(basename(mergebam.mergebam),'\.sorted\.b.*$','') + '/QC/FastQC'
        }

        call samtools.indexstats as mergeindexstats {
            input:
                bamfile=mergebam.mergebam,
                default_location=sub(basename(mergebam.mergebam),'\.sorted\.b.*$','') + '/BAM_files'
        }

        if ( defined(blacklist) ) {
            # remove blacklist regions
            String string_blacklist = "" #buffer to allow for blacklist optionality
            File blacklist_ = select_first([blacklist, string_blacklist])
            call bedtools.intersect as rmblklist {
                input :
                    fileA=mergebam.mergebam,
                    fileB=blacklist_,
                    default_location=sub(basename(mergebam.mergebam),'\.sorted\.b.*$','') + '/BAM_files',
                    nooverlap=true
            }
            call samtools.indexstats as bklist {
                input :
                    bamfile=rmblklist.intersect_out,
                    default_location=sub(basename(mergebam.mergebam),'\.sorted\.b.*$','') + '/BAM_files'
            }
        } # end if blacklist provided

        File mergebam_afterbklist = select_first([rmblklist.intersect_out, mergebam.mergebam])
        File merge_indexbam = select_first([bklist.indexbam, mergeindexstats.indexbam])

        call samtools.markdup {
            input :
                bamfile=mergebam_afterbklist,
                default_location=sub(basename(mergebam_afterbklist),'\.sorted\.b.*$','') + '/BAM_files'
        }

        call samtools.indexstats as mkdup {
            input :
                bamfile=markdup.mkdupbam,
                default_location=sub(basename(mergebam_afterbklist),'\.sorted\.b.*$','') + '/BAM_files'
        }

        call bedtools.bamtobed as tobed {
            input :
                bamfile=mergebam_afterbklist
        }

        call runspp.runspp as runspp {
            input:
                bamfile=mergebam_afterbklist
        }
    } # end if length(fastqfiles) > 1: multi_fastq

### ---------------------------------------- ###
### ------------ S E C T I O N 2 ----------- ###
### -- B: analysis of one FASTQ provided --- ###
### ---------------------------------------- ###

    # if only one fastqfile is provided
    if ( one_fastq ) {
        # Execute analysis on each fastq file provided
        # Analysis executed:
        #   FastQC
        #   FASTQ read length distribution
        #   Reference Alignment using Bowtie (-k2 -m2)
        #   Convert SAM to BAM
        #   FastQC on BAM files
        #   Remove Blacklists (if provided)
        #   Remove read duplicates
        #   Summary statistics on FASTQs
        #   Combine html files into one for easy viewing
        if ( defined(filename_prefix) ) {
            String string_prefix = "" #buffer to allow for filename_prefix optionality
            String filename_prefix_ = select_first([filename_prefix, string_prefix])
            call util.linkname {
                input:
                    prefix=filename_prefix_,
                    in_fastq=fastqfiles[0]
            }
        }

        File uno_fastqfile = select_first([linkname.out_fastq, fastqfiles[0]])

        call fastqc.fastqc as uno_fastqc {
            input :
                inputfile=uno_fastqfile,
                default_location=sub(basename(uno_fastqfile),'\.f.*q\.gz','') + '/QC/FastQC'
        }

        call util.basicfastqstats as uno_bfs {
            input :
                fastqfile=uno_fastqfile,
                default_location=sub(basename(uno_fastqfile),'\.f.*q\.gz','') + '/QC/SummaryStats'
        }

        if ( !run_bowtie2 ) {
            call bowtie.bowtie as uno_bowtie {
                input :
                    fastqfile=uno_fastqfile,
                    index_files=bowtie_index_,
                    metricsfile=uno_bfs.metrics_out
            }
        }
        if ( run_bowtie2 ) {
            call bowtie2.bowtie2 as uno_bowtie2 {
                input :
                    fastqfile=uno_fastqfile,
                    index_files=bowtie_index_
            }
        }

        File uno_bowtie_samfile = select_first(flatten(select_all([uno_bowtie.samfile, uno_bowtie2.samfile])))

        call samtools.viewsort as uno_viewsort {
            input :
                samfile=uno_bowtie_samfile,
                default_location=sub(basename(uno_fastqfile),'\.f.*q\.gz','') + '/BAM_files'
        }

        call fastqc.fastqc as uno_bamfqc {
            input :
                inputfile=uno_viewsort.sortedbam,
                default_location=sub(basename(uno_fastqfile),'\.f.*q\.gz','') + '/QC/FastQC'
        }

        call samtools.indexstats as uno_indexstats {
        input :
            bamfile=uno_viewsort.sortedbam,
            default_location=sub(basename(uno_fastqfile),'\.f.*q\.gz','') + '/BAM_files'
        }

        if ( defined(blacklist) ) {
            # remove blacklist regions
            String string_uno_blacklist = "" #buffer to allow for blacklist optionality
            File uno_blacklist_ = select_first([blacklist, string_uno_blacklist])
            call bedtools.intersect as uno_rmblklist {
                input :
                    fileA=uno_viewsort.sortedbam,
                    fileB=uno_blacklist_,
                    default_location=sub(basename(uno_fastqfile),'\.f.*q\.gz','')+'/BAM_files',
                    nooverlap=true
            }
            call samtools.indexstats as uno_bklist {
                input :
                    bamfile=uno_rmblklist.intersect_out,
                    default_location=sub(basename(uno_fastqfile),'\.f.*q\.gz','')+'/BAM_files'
            }
        } # end if (blacklist provided)

        File uno_afterbklist = select_first([uno_rmblklist.intersect_out, uno_viewsort.sortedbam])
        File uno_indexbam = select_first([uno_bklist.indexbam, uno_indexstats.indexbam])

        call samtools.markdup as uno_markdup {
            input :
                bamfile=uno_afterbklist,
                default_location=sub(basename(uno_fastqfile),'\.f.*q\.gz','')+'/BAM_files'
        }

        call samtools.indexstats as uno_mkdup {
            input :
                bamfile=uno_markdup.mkdupbam,
                default_location=sub(basename(uno_fastqfile),'\.f.*q\.gz','')+'/BAM_files'
        }

        call bedtools.bamtobed as uno_tobed {
            input :
                bamfile=uno_afterbklist
        }

        call runspp.runspp as uno_runspp {
            input:
                bamfile=uno_afterbklist
        }
    } # end if length(fastqfiles) == 1: one_fastq

### ---------------------------------------- ###
### ------------ S E C T I O N 3 ----------- ###
### ----------- ChIP-seq analysis ---------- ###
### ---------------------------------------- ###

    # ChIP-seq and downstream analysis
    # Execute analysis on merge bam file
    # Analysis executed:
    #   FIRST: Check if reads are mapped
    #   Peaks identification (SICER, MACS, ROSE)
    #   Motif analysis
    #   Complete Summary statistics

    #collate correct files for downstream analysis
    File downstream_bam = select_first([mergebam_afterbklist, uno_afterbklist])

    call macs.macs {
        input :
            bamfile=downstream_bam,
            pvalue = "1e-9",
            keep_dup="auto",
            default_location=sub(basename(downstream_bam),'\.sorted\.b.*$','') + '/PEAKS/NARROW_peaks' + '/' + basename(downstream_bam,'\.bam') + '-p9_kd-auto'
    }

    call util.peaksanno {
        input :
            gtffile=gtf,
            bedfile=macs.peakbedfile,
            chromsizes=samtools_faidx.chromsizes,
            summitfile=macs.summitsfile,
            default_location=sub(basename(downstream_bam),'\.sorted\.b.*$','') + '/PEAKS_Annotation/NARROW_peaks' + '/' + sub(basename(macs.peakbedfile),'\_peaks.bed','')
    }

    call macs.macs as all {
        input :
            bamfile=downstream_bam,
            pvalue = "1e-9",
            keep_dup="all",
            default_location=sub(basename(downstream_bam),'\.sorted\.b.*$','') + '/PEAKS/NARROW_peaks' + '/' + basename(downstream_bam,'\.bam') + '-p9_kd-all'
    }

    call util.peaksanno as all_peaksanno {
        input :
            gtffile=gtf,
            bedfile=all.peakbedfile,
            chromsizes=samtools_faidx.chromsizes,
            summitfile=all.summitsfile,
            default_location=sub(basename(downstream_bam),'\.sorted\.b.*$','') + '/PEAKS_Annotation/NARROW_peaks' + '/' + sub(basename(all.peakbedfile),'\_peaks.bed','')
    }

    call macs.macs as nomodel {
        input :
            bamfile=downstream_bam,
            nomodel=true,
            default_location=sub(basename(downstream_bam),'\.sorted\.b.*$','') + '/PEAKS/NARROW_peaks' + '/' + basename(downstream_bam,'\.bam') + '-nm'
    }

    call util.peaksanno as nomodel_peaksanno {
        input :
            gtffile=gtf,
            bedfile=nomodel.peakbedfile,
            chromsizes=samtools_faidx.chromsizes,
            summitfile=nomodel.summitsfile,
            default_location=sub(basename(downstream_bam),'\.sorted\.b.*$','') + '/PEAKS_Annotation/NARROW_peaks' + '/' + sub(basename(nomodel.peakbedfile),'\_peaks.bed','')
    }

    call bamtogff.bamtogff {
        input :
            gtffile=gtf,
            chromsizes=samtools_faidx.chromsizes,
            bamfile=select_first([markdup.mkdupbam, uno_markdup.mkdupbam]),
            bamindex=select_first([mkdup.indexbam, uno_mkdup.indexbam]),
            default_location=sub(basename(downstream_bam),'\.sorted\.b.*$','') + '/BAM_Density'
    }

    call bedtools.bamtobed {
        input :
            bamfile=select_first([markdup.mkdupbam, uno_markdup.mkdupbam])
    }

    call sicer.sicer {
        input :
            bedfile=bamtobed.bedfile,
            chromsizes=samtools_faidx.chromsizes,
            default_location=sub(basename(downstream_bam),'\.sorted\.b.*$','') + '/PEAKS/BROAD_peaks'
    }

    call util.peaksanno as sicer_peaksanno {
        input :
            gtffile=gtf,
            bedfile=sicer.scoreisland,
            chromsizes=samtools_faidx.chromsizes,
            default_location=sub(basename(downstream_bam),'\.sorted\.b.*$','') + '/PEAKS_Annotation/BROAD_peaks'
    }

    # Motif Analysis
    call motifs.motifs {
        input:
            reference=reference,
            reference_index=samtools_faidx.faidx_file,
            bedfile=macs.peakbedfile,
            motif_databases=motif_databases,
            default_location=sub(basename(downstream_bam),'\.sorted\.b.*$','') + '/MOTIFS'
    }

    call util.flankbed {
        input :
            bedfile=macs.summitsfile,
            default_location=sub(basename(downstream_bam),'\.sorted\.b.*$','') + '/MOTIFS'
    }

    call motifs.motifs as flank {
        input:
            reference=reference,
            reference_index=samtools_faidx.faidx_file,
            bedfile=flankbed.flankbedfile,
            motif_databases=motif_databases,
            default_location=sub(basename(downstream_bam),'\.sorted\.b.*$','') + '/MOTIFS'
    }

    call rose.rose {
        input :
            gtffile=gtf,
            bamfile=downstream_bam,
            bamindex=select_first([merge_indexbam, uno_indexbam]),
            bedfile_auto=macs.peakbedfile,
            bedfile_all=all.peakbedfile,
            default_location=sub(basename(downstream_bam),'\.sorted\.b.*$','') + '/PEAKS/STITCHED_peaks'
    }

    call viz.visualization {
        input:
            wigfile=macs.wigfile,
            chromsizes=samtools_faidx.chromsizes,
            xlsfile=macs.peakxlsfile,
            default_location=sub(basename(downstream_bam),'\.sorted\.b.*$','') + '/COVERAGE_files/NARROW_peaks'
    }

    call viz.visualization as vizall {
        input:
            wigfile=all.wigfile,
            chromsizes=samtools_faidx.chromsizes,
            xlsfile=all.peakxlsfile,
            default_location=sub(basename(downstream_bam),'\.sorted\.b.*$','') + '/COVERAGE_files/NARROW_peaks'
    }

    call viz.visualization as viznomodel {
        input:
            wigfile=nomodel.wigfile,
            chromsizes=samtools_faidx.chromsizes,
            xlsfile=nomodel.peakxlsfile,
            default_location=sub(basename(downstream_bam),'\.sorted\.b.*$','') + '/COVERAGE_files/NARROW_peaks'
    }

     call viz.visualization as vizsicer {
        input:
            wigfile=sicer.wigfile,
            chromsizes=samtools_faidx.chromsizes,
            default_location=sub(basename(downstream_bam),'\.sorted\.b.*$','') + '/COVERAGE_files/BROAD_peaks'
    }

    call sortbed.sortbed {
        input:
            bedfile=select_first([tobed.bedfile, uno_tobed.bedfile])
    }

    call bedtools.intersect {
        input:
            fileA=macs.peakbedfile,
            fileB=sortbed.sortbed_out,
            countoverlap=true,
            sorted=true
    }

### ---------------------------------------- ###
### ------------ S E C T I O N 4 ----------- ###
### ---------- Summary Statistics ---------- ###
### ---------------------------------------- ###

    #SUMMARY STATISTICS
    String string_fzip = "" #buffer to allow for fastqczip optionality
    if ( one_fastq ) {
        call util.summarystats as uno_summarystats {
            # SUMMARY STATISTICS of sample file (only 1 sample file provided)
            input:
                bambed=uno_tobed.bedfile,
                fastqmetrics=uno_bfs.metrics_out,
                sppfile=uno_runspp.spp_out,
                bamflag=uno_indexstats.flagstats,
                rmdupflag=uno_mkdup.flagstats,
                bkflag=uno_bklist.flagstats,
                fastqczip=select_first([uno_fastqc.zipfile, string_fzip]),
                countsfile=intersect.intersect_out,
                peaksxls=macs.peakxlsfile,
                enhancers=rose.enhancers,
                superenhancers=rose.super_enhancers,
                default_location=sub(basename(downstream_bam),'\.sorted\.b.*$','') + '/QC/SummaryStats'
        }
    } # end if one_fastq

    if ( multi_fastq ) {
        call util.summarystats as merge_summarystats {
            # SUMMARY STATISTICS of all samples files (more than 1 sample file provided)
            input:
                bambed=tobed.bedfile,
                sppfile=runspp.spp_out,
                bamflag=mergeindexstats.flagstats,
                rmdupflag=mkdup.flagstats,
                bkflag=bklist.flagstats,
                fastqczip=select_first([mergebamfqc.zipfile, string_fzip]),
                countsfile=intersect.intersect_out,
                peaksxls=macs.peakxlsfile,
                enhancers=rose.enhancers,
                superenhancers=rose.super_enhancers,
                default_location=sub(basename(downstream_bam),'\.sorted\.b.*$','') + '/QC/SummaryStats'
        }
    } # end if multi_fastq

    output {
        #FASTQC
        Array[File?]? htmlfile = fastqc.htmlfile
        Array[File?]? zipfile = fastqc.zipfile
        Array[File?]? bam_htmlfile = bamfqc.htmlfile
        Array[File?]? bam_zipfile = bamfqc.zipfile
        File? mergebam_htmlfile = mergebamfqc.htmlfile
        File? mergebam_zipfile = mergebamfqc.zipfile
        File? uno_htmlfile = uno_fastqc.htmlfile
        File? uno_zipfile = uno_fastqc.zipfile
        File? uno_bam_htmlfile = uno_bamfqc.htmlfile
        File? uno_bam_zipfile = uno_bamfqc.zipfile

        #BASICMETRICS
        Array[File?]? metrics_out = bfs.metrics_out
        File? uno_metrics_out = uno_bfs.metrics_out

        #BAMFILES
        Array[File?]? sortedbam = viewsort.sortedbam
        Array[File?]? indexbam = indexstats.indexbam
        Array[File?]? indv_bkbam = indv_rmblklist.intersect_out
        Array[File?]? indv_bkindexbam = indv_bklist.indexbam
        Array[File?]? indv_rmbam = indv_markdup.mkdupbam
        Array[File?]? indv_rmindexbam = indv_mkdup.indexbam

        File? uno_sortedbam = uno_viewsort.sortedbam
        File? uno_indexstatsbam = uno_indexstats.indexbam
        File? uno_bkbam = uno_rmblklist.intersect_out
        File? uno_bkindexbam = uno_bklist.indexbam
        File? uno_rmbam = uno_markdup.mkdupbam
        File? uno_rmindexbam = uno_mkdup.indexbam

        File? mergebamfile = mergebam.mergebam
        File? mergebamindex = mergeindexstats.indexbam
        File? bkbam = rmblklist.intersect_out
        File? bkindexbam = bklist.indexbam
        File? rmbam = markdup.mkdupbam
        File? rmindexbam = mkdup.indexbam

        #MACS
        File? peakbedfile = macs.peakbedfile
        File? peakxlsfile = macs.peakxlsfile
        File? summitsfile = macs.summitsfile
        File? wigfile = macs.wigfile

        File? all_peakbedfile = all.peakbedfile
        File? all_peakxlsfile = all.peakxlsfile
        File? all_summitsfile = all.summitsfile
        File? all_wigfile = all.wigfile

        File? nm_peakbedfile = nomodel.peakbedfile
        File? nm_peakxlsfile = nomodel.peakxlsfile
        File? nm_summitsfile = nomodel.summitsfile
        File? nm_wigfile = nomodel.wigfile

        #SICER
        File? scoreisland = sicer.scoreisland
        File? sicer_wigfile = sicer.wigfile

        #ROSE
        File? pngfile = rose.pngfile
        File? mapped_union = rose.mapped_union
        File? mapped_stitch = rose.mapped_stitch
        File? enhancers = rose.enhancers
        File? super_enhancers = rose.super_enhancers
        File? gff_file = rose.gff_file
        File? gff_union = rose.gff_union
        File? union_enhancers = rose.union_enhancers
        File? stitch_enhancers = rose.stitch_enhancers
        File? e_to_g_enhancers = rose.e_to_g_enhancers
        File? g_to_e_enhancers = rose.g_to_e_enhancers
        File? e_to_g_super_enhancers = rose.e_to_g_super_enhancers
        File? g_to_e_super_enhancers = rose.g_to_e_super_enhancers

        #MOTIFS
        File? flankbedfile = flankbed.flankbedfile

        File? ame_tsv = motifs.ame_tsv
        File? ame_html = motifs.ame_html
        File? ame_seq = motifs.ame_seq
        File? meme = motifs.meme_out
        File? meme_summary = motifs.meme_summary

        File? summit_ame_tsv = flank.ame_tsv
        File? summit_ame_html = flank.ame_html
        File? summit_ame_seq = flank.ame_seq
        File? summit_meme = flank.meme_out
        File? summit_meme_summary = flank.meme_summary

        #BAM2GFF
        File? m_downstream = bamtogff.m_downstream
        File? m_upstream = bamtogff.m_upstream
        File? m_genebody = bamtogff.m_genebody
        File? m_promoters = bamtogff.m_promoters
        File? densityplot = bamtogff.densityplot
        File? pdf_gene = bamtogff.pdf_gene
        File? pdf_h_gene = bamtogff.pdf_h_gene
        File? png_h_gene = bamtogff.png_h_gene
        File? pdf_promoters = bamtogff.pdf_promoters
        File? pdf_h_promoters = bamtogff.pdf_h_promoters
        File? png_h_promoters = bamtogff.png_h_promoters

        #PEAKS-ANNOTATION
        File? peak_promoters = peaksanno.peak_promoters
        File? peak_genebody = peaksanno.peak_genebody
        File? peak_window = peaksanno.peak_window
        File? peak_closest = peaksanno.peak_closest
        File? peak_comparison = peaksanno.peak_comparison
        File? gene_comparison = peaksanno.gene_comparison
        File? pdf_comparison = peaksanno.pdf_comparison

        File? all_peak_promoters = all_peaksanno.peak_promoters
        File? all_peak_genebody = all_peaksanno.peak_genebody
        File? all_peak_window = all_peaksanno.peak_window
        File? all_peak_closest = all_peaksanno.peak_closest
        File? all_peak_comparison = all_peaksanno.peak_comparison
        File? all_gene_comparison = all_peaksanno.gene_comparison
        File? all_pdf_comparison = all_peaksanno.pdf_comparison

        File? nomodel_peak_promoters = nomodel_peaksanno.peak_promoters
        File? nomodel_peak_genebody = nomodel_peaksanno.peak_genebody
        File? nomodel_peak_window = nomodel_peaksanno.peak_window
        File? nomodel_peak_closest = nomodel_peaksanno.peak_closest
        File? nomodel_peak_comparison = nomodel_peaksanno.peak_comparison
        File? nomodel_gene_comparison = nomodel_peaksanno.gene_comparison
        File? nomodel_pdf_comparison = nomodel_peaksanno.pdf_comparison

        File? sicer_peak_promoters = sicer_peaksanno.peak_promoters
        File? sicer_peak_genebody = sicer_peaksanno.peak_genebody
        File? sicer_peak_window = sicer_peaksanno.peak_window
        File? sicer_peak_closest = sicer_peaksanno.peak_closest
        File? sicer_peak_comparison = sicer_peaksanno.peak_comparison
        File? sicer_gene_comparison = sicer_peaksanno.gene_comparison
        File? sicer_pdf_comparison = sicer_peaksanno.pdf_comparison

        #VISUALIZATION
        File? bigwig = visualization.bigwig
        File? norm_wig = visualization.norm_wig
        File? tdffile = visualization.tdffile
        File? n_bigwig = viznomodel.bigwig
        File? n_norm_wig = viznomodel.norm_wig
        File? n_tdffile = viznomodel.tdffile
        File? a_bigwig = vizall.bigwig
        File? a_norm_wig = vizall.norm_wig
        File? a_tdffile = vizall.tdffile
        File? s_bigwig = vizsicer.bigwig
        File? s_norm_wig = vizsicer.norm_wig
        File? s_tdffile = vizsicer.tdffile

        #QC-STATS
        Array[File?]? qc_statsfile = summarystats.statsfile
        Array[File?]? qc_htmlfile = summarystats.htmlfile
        Array[File?]? qc_textfile = summarystats.textfile
        File? qc_mergehtml = mergehtml.mergefile
        File? mergeqc_statsfile = merge_summarystats.statsfile
        File? mergeqc_htmlfile = merge_summarystats.htmlfile
        File? mergeqc_textfile = merge_summarystats.textfile
        File? uno_qc_statsfile = uno_summarystats.statsfile
        File? uno_qc_htmlfile = uno_summarystats.htmlfile
        File? uno_qc_textfile = uno_summarystats.textfile
    }
}
