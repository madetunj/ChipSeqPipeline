## Overview

**Single-End Antibody SEQuencing pipeline** (abbreviated as **SEAseq**) is a comprehensive automated pipeline for ChIP-Seq/CUT&RUN data analysis. Speaking broadly, it containerizes and joins field-standard, open-source tools for processing raw data and performing a wide array of basic analyses.  


SEAseq analyses include alignment, peak calling, motif analysis, read coverage profiling, clustered peak (e.g. super-enhancer) identification, and quality assessment metrics, as well as automatic interfacing with data in [GEO]/[SRA]. The easy-to-use and flexibility of SEAseq makes it a reliable and efficient resource for ensuring high quality ChIP-Seq analysis, especially in research environments lacking computational infrastructure or expertise.  


[SRA]: https://www.ncbi.nlm.nih.gov/sra
[GEO]: https://www.ncbi.nlm.nih.gov/geo/

## Inputs

|   Name                                               |   Type                | Description                                                                    |  Example                         |
|------------------------------------------------------|-----------------------|--------------------------------------------------------------------------------|----------------------------------|
|   Sample FASTQ files                                 |   Array of files      |   One or more Sample FASTQ files. The files are recommended to be gzipped.     |   [`*.gz`]                       |
|   Sample SRA run accession identifiers (SRR)         |   Array of strings    |   One or more Sample SRR.                                                      |   [`SRR12345678`]                |
|   Input/Control FASTQ files                          |   Array of files      |   One or more Input/Control FASTQ files. Files are recommended to be gzipped.  |   [`*.gz`]                       |
|   Input/Control SRA run accession identifiers (SRR)  |   Array of strings    |   One or more Input/Control SRR.                                               |   [`SRR12345679`]                |
|   Genome Reference                                   |   File                |   The genome reference in FASTA format.                                        |   [`*.fa`]                       |
|   Genome Bowtie indexes                              |   Array of files      |   The genome bowtie v1 indexes. Should be six index files.                     |   [`*.ebwt`]                     |
|   Gene Annotation                                    |   File                |   A gene position database file.                                               |   [`*.gtf`, `*.gff`, `*.gff3`]   |
|   Blacklists                                         |   File                |   [UHS]/[DER]/[DAC] or custom blacklist regions file.                          |   [`*.bed`]                      |
|   [Motif databases]                                  |   Array of files      |   One or more position weight matrix databases.                                |   [`*.meme`]                     |

### Input configuration

SEAseq supports FASTQ files and SRA identifiers (SRRs) as Samples Input. A combination of both is also supported.

SEAseq requires the Samples Input, Genome Reference, and the Gene Annotation files be provided.

The Input/Control FASTQ files or SRA ids (SRR) for coverage correction are optional.
Bowtie genomic indexes and region-based blacklists are optional.

SEAsrq supports Genome Reference and Gene Annotation (or Gene position database) files from
most genome repositories, such as [UCSC], [ENSEMBL], [RefSeq] or [GENCODE].

[Motif databases]: https://meme-suite.org/meme/db/motifs

## Outputs

SEAseq provides multiple outputs from the different analysis offerings.
Outputs are grouped into subcategories:

| Name                  | Type    | Description                                                                            |
|-----------------------|---------|----------------------------------------------------------------------------------------|
|  [BAM_files]          | Folder  | All mapping (`.bam`) files.                                                            |
|  [BAM_Density]        | Folder  | Reads Coverage profiling in promoter and genic regions matrices, plots and heatmaps.   |
|  [MOTIFS]             | Folder  | Motifs discovery and prediction results files.                                         |
|  [PEAKS]              | Folder  | Identified narrow peaks, broad peaks and linear-stitched peaks files.                  |
|  [PEAKS_Annotation]   | Folder  | Genic annotation of peaks tables and plot.                                             |
|  [PEAKS_Display]      | Folder  | Normalized signal data tracks in wiggle, tdf and bigwig formats.                       |
|  [QC]                 | Folder  | Quality statistics and metrics of FASTQs and peaks as tables and color-coded HTML.     |

More descriptions on SEAseq Inputs and Outputs can be found [here](https://github.com/stjude/seaseq/blob/master/docs/SEAseq_IO.pdf).

[BAM_Density]: #reads-coverage-profiling
[BAM_files]: #reads-alignment-and-filtering
[MOTIFS]: #discovery-and-enrichment-of-motifs
[PEAKS]: #peaks-identification
[PEAKS_Annotation]: #peaks-annotation
[PEAKS_Display]: #peaks-display
[QC]: #qc-metrics

## Workflow Steps

1. If provided, SRRs are downloaded as FASTQs using the [SRA Toolkit].
2. Sequencing FASTQs are aligned to the reference genome using [Bowtie].
3. Mapped reads are further processed by removal of redundant reads and blacklisted regions.
4. Read density profiling in relevant genomic regions such as promoters and gene body using [BamToGFF].
5. Normalized and unnormalized coverage files for display are generated for external browsers such as [GenomePaint], [UCSC genome browser] and [IGV].
6. Identification of enriched regions for two binding profiles:
    * For factors that bind shorter regions, e.g. many sequence-specific transcription factors such as CTCF using [MACS].
    * For broad regions of enrichment, e.g. some histone modifications such as H3K27Ac using [SICER].
7. Identification of stitched clusters of enriched regions and separates exceptionally large regions, e.g. super-enhancers from typical enhancers, using [ROSE].
8. Motif discovery and enrichment using tools from the [MEME Suite].
9. Annotation of peaks in genic regions.
10. Assessment of quality by calculating relevant metrics including those recommmended by the [ENCODE consortium]. More information is provided [here](#qc-metrics).


## SEAseq on Linux or HPC

SEAseq pipeline requires the [Cromwell](https://github.com/broadinstitute/cromwell/releases) runner, docker/singularity,
and about 30GB of supplemental data.
```bash
# For sample FASTQs only
java -jar cromwell.jar run seaseq-case.wdl -i inputs.json -o options.json

# For sample FASTQs with Input Control or IgG
java -jar cromwell.jar run seaseq-control.wdl -i inputs.json -o options.json
```
View [`/test`](https://github.com/stjude/seaseq/tree/master/test) folder for example usage and further instructions.

**Additional Configuration** (Recommended)

[Docker Hub Pull Rates](https://www.docker.com/increase-rate-limits?utm_source=docker&utm_medium=web%20referral&utm_campaign=increase%20rate%20limit&utm_budget=)
are limited to 100 image pulls per six hours. We recommend using a paid (Docker pro or Team subscription) account for multiple (more than 10) in the given instance.


## SEAseq on St. Jude cloud

Before you can run SEAseq on St. Jude Cloud, you must first create a workspace in
DNAnexus for the run. Refer to [the general workflow
guide](https://university.stjude.cloud/docs/genomics-platform/analyzing-data/running-sj-workflows#getting-started) to learn
how to create a DNAnexus workspace for each workflow run.

You can navigate to the SEAseq workflow page
[here](https://platform.stjude.cloud/workflows/seaseq).

## Analysis of Results

All results will be organized in the outputs sub-directories as shown in the
[Outputs Section](#outputs) for easy exploration of results.

## Interpreting results

Upon successful run of SEAseq, all files are saved to the results directory as
listed in the [Outputs Section](#outputs). Here, we will discuss some of the
different output directories in more detail.

### Reads Alignment and Filtering

Reads are stringently mapped to reference genome using [Bowtie]
`bowtie -l readlength -p 20 -k 2 -m 2 --best -S`.

Mapped BAMs are further processed by removal of duplicate reads using [SAMTools]
and blacklisted regions using [bedtools].
Blacklisted regions are sources of bias in most ChIP-Seq experiments. These
problematic regions are identified as regions with significant background noise
or artifically high signal ([UHS]/[DAC]/[DER]), and are recommended to be
excluded in order to assess biologically relevant and true signals of enrichment.

### Peaks Identification

We identify enriched regions based on two binding profiles; factors that bind
shorter regions such as transcription factors using MACS, and for those that
bind broad regions such as some histone marks using SICER.

Parameters specified for peak calls :
  * **Narrow Peaks** : `macs14 -p 1e-9 --keep-dup=auto --space=50 -w -S`
  * **Broad Peaks** : `sicer -rt 1 -w 200 -f 150 -egf 0.86 -g 200 -e 100`

In addition, we identify large clusters of enrichment (enhancers) and
exceptionally large regions (super-enhancers) using the [ROSE] algorithm.
Computed stitched regions are generated as tab-delimited or BED files with
overlapping gene information.

### Peaks Display

Coverage graphical files are normalized and generated to be uploaded for display on your choice of external genomic browsers such as [UCSC genome browser] or [GenomePaint] in [WIG] and [bigWig] format, or [IGV] in [TDF] format.

Parameter specified to generate coverage files: `macs14 --space=50 --shiftsize=200 -w -S`.

### Discovery and Enrichment of Motifs

We discover sequence patterns that are widespread and have biological
significance using the [MEME-ChIP] and [AME] tools from the [MEME Suite].

[AME] discovers known enriched binding motifs.
[MEME-ChIP] performs several motif analysis steps such as novel DNA-binding motif discovery
(MEME and DREME), identify motif enrichment relative to background (CentriMo), visualize
the arrangement of the predicted motif sites (SpaMO, FIMO).

The motifs are identified using the peak regions and 100bp window around peak summit (-50 and +50).

### Reads Coverage Profiling

Read density profiling of major genomic regions such as promoters and gene body using [BamToGFF].

BamToGFF computes the average read densities of the provided gene coordinates creating a
normalized density matrix file.
The density matrix files are then used to generate coverage graphs and heatmap plots using
a custom R script that will also be provided in the results directory
`/BAM_Density/densityplots.R` for further customization if needed.

Below is an example of the average read coverage across all promoters and gene body regions for [SRR10259398].

<p align="center">
<img src="images/SRR10259398-density.png">
</p>

### Peaks Annotation

Genic annotation of peaks including promoters, gene bodies, gene-centric windows, and proximal genes.
We designed custom scripts to provide this information.

Custom scripts are designed to generate the genic annotation of peaks at promoters, gene bodies
and gene-centric windows.
Annotated regions are collated to provide a binary overview
of proximal genes, and the peaks occupancy percentages are graphically presented in a bar plot as
shown for [SRR10259398].

<p align="center">
<img width="50%" height="auto" src="images/SRR10259398-peaksoccupancy.png">
</p>

### QC Metrics

SEAseq provides a vast set of quality metrics for detecting experimental issues, including ChIP-Seq
metrics recommended by the ENCODE consortium.

We incorporated a five-scale color-rank flag system to visually identify excellent
(score = 2), good (score = 1), average (score = 0), below-average (score = -1) or poor (score = -2)
results for each metric in addition to a cross-metric summary score (between -2 and 2), using recommended
thresholds where possible.

The metrics are color flagged for easy visualization of overall performance in HTML format as shown for [SRR10259398].

<img src="images/SRR10259398-QC.png">


SEAseq metrics calculated to infer quality are (in alphabetical order):
| Quality Metric	                                 | Definition	                                                                                                                                                            |
|--------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Aligned Percent                                        | Percentage of mapped reads.                                                                                                                                            |
| Base Quality	                                         | Per-base sequence quality.                                                                                                                                             |
| Estimated Fragment Width                               | Average fragment size of the peak distribution.	                                                                                                                      |
| Estimated Tag Length	                                 | Sequencing read length.                                                                                                                                                |
| [FRiP]	                                         | The fraction of reads within peaks regions.                                                                                                                            |
| Linear Stitched Peaks (Enhancers)                      | Total number of clustered enriched regions.                                                                                                                            |
| Non-Redundant Fraction ([NRF])                         | Fraction of uniquely mapped reads.                                                                                                                                     |
| *Normalized Peaks*                                     | Peaks identified with Input/Control correction *(applicable when Control is provided)*.                                                                                |
| Normalized Strand-correlation Coefficient ([NSC])	 | To determine signal-to-noise ratio using strand cross-correlation. The ratio of the maximum cross-correlation value divided by the background cross-correction.        |
| Sequence Diversity	                                 | Sequence overrepresentation.  If reads/sequences are overrepresented in the library.                                                                                   |
| PCR Bottleneck Coefficient ([PBC])	                 | It is a measure of library complexity determined by the fraction of genomic locations with exactly one unique read versus those covered by at least one unique reads.	|
| Peaks                                                  | Total number of enriched regions.                                                                                                                                      |
| Raw Reads	                                         | Total number of sequencing reads.                                                                                                                                      |
| *Read Length*                                          | Average FASTQ read length *(applicable when multiple FASTQs are provided)*.                                                                                            |
| Relative Strand-correlation Coefficient ([RSC])        | A strand cross-correlation ratio between the fragment-length cross-correlation and the read-length peak.                                                               |
| SE-like enriched regions (Super Enhancers)	         | Total number of SE-like clustered enriched regions.                                                                                                                    |
| Overall Quality	                                 | Cross-metric average score.                                                                                                                                            |

## Frequently asked questions

If you have any questions not covered here, feel free to contact us.

# References

None yet!

[SRR10259398]: https://www.pnas.org/content/117/28/16516
[RefSeq]: https://ftp.ncbi.nlm.nih.gov/refseq/
[GENCODE]: https://www.gencodegenes.org/
[UCSC]: https://hgdownload.soe.ucsc.edu/
[ENSEMBL]: https://useast.ensembl.org/
[UHS]: https://sites.google.com/site/anshulkundaje/projects/blacklists
[DER]: https://genome.ucsc.edu/cgi-bin/hgFileUi?db=hg19&g=wgEncodeMapability
[DAC]: https://genome.ucsc.edu/cgi-bin/hgFileUi?db=hg19&g=wgEncodeMapability
[SAMTools]: https://doi.org/10.1093/bioinformatics/btp352
[bedtools]: https://doi.org/10.1093/bioinformatics/btq033
[SRA Toolkit]: http://www.ncbi.nlm.nih.gov/books/NBK158900/
[Bowtie]: https://doi.org/10.1186/gb-2009-10-3-r25
[BamToGFF]: https://github.com/stjude/BAM2GFF
[GenomePaint]: https://www.cell.com/cancer-cell/fulltext/S1535-6108(20)30659-0
[UCSC genome browser]: https://doi.org/10.1093/bib/bbs038
[IGV]: https://doi.org/10.1093/bib/bbs017
[MACS]: https://doi.org/10.1186/gb-2008-9-9-r137
[SICER]: https://doi.org/10.1093/bioinformatics/btp340
[ROSE]: http://younglab.wi.mit.edu/super_enhancer_code.html
[MEME Suite]: https://doi.org/10.1093/nar/gkv416
[ENCODE consortium]: https://doi.org/10.1101/gr.136184.111
[WIG]: https://genome.ucsc.edu/goldenPath/help/wiggle.html
[bigWig]: https://genome.ucsc.edu/goldenpath/help/bigWig.html
[TDF]: https://software.broadinstitute.org/software/igv/TDF
[AME]: https://meme-suite.org/meme/tools/ame
[MEME-ChIP]: https://meme-suite.org/meme/tools/meme-chip
[seaseq]: https://github.com/stjude/seaseq
[FRiP]: https://github.com/stjude/seaseq/blob/master/definitions.md#fraction-of-reads-in-peaks-frip
[NRF]: https://github.com/stjude/seaseq/blob/master/definitions.md#non-redundant-fraction-nrf
[NSC]: https://github.com/stjude/seaseq/blob/master/definitions.md#normalized-strand-correlation-coefficient-nsc
[RSC]: https://github.com/stjude/seaseq/blob/master/definitions.md#relative-strand-correlation-coefficient-rsc
[PBC]: https://github.com/stjude/seaseq/blob/master/definitions.md#pcr-bottleneck-coefficient-pbc

