from snakemake.remote.HTTP import RemoteProvider as HTTPRemoteProvider
HTTP = HTTPRemoteProvider()

RMD_FILES, = glob_wildcards("notebooks/{rmd_files}.Rmd")

# declare all input files here
DATA_FILES = [
    "data/ensemble_hgnc.txt",
    "data/immune_cell_reference/immune_cell_reference_tidy.tsv",
    "data/schelker/ascites_bulk_samples.xls",
    "data/schelker/single_cell_schelker.rda",
    "data/schelker/ascites_facs.xlsx",
    "data/racle/GSE93722_RAW/GSM2461007_LAU1255.genes.results.txt",
    "data/racle/GSE93722_RAW/GSM2461009_LAU1314.genes.results.txt",
    "data/racle/GSE93722_RAW/GSM2461005_LAU355.genes.results.txt",
    "data/racle/GSE93722_RAW/GSM2461003_LAU125.genes.results.txt",
    "data/racle/racle2017_flow_cytometry.xlsx",
    "data/hoek/hoek_quantiseq.RData",
    "data/hoek/hoek_star_rsem.rds",
    "data/hoek/HoekPBMC_gtruth.RData"
]


rule book:
  """build book using R bookdown"""
  input:
    # data
    DATA_FILES,
    # content (Rmd files and related stuff)
    expand("notebooks/{rmd_files}.Rmd", rmd_files = RMD_FILES),
    "notebooks/bibliography.bib",
    "notebooks/_bookdown.yml",
    "notebooks/_output.yml"
  output:
    "results/book/index.html",
    "results/cache/.dir",
    # "results/cache/input_data.rda",
    # "results/cache/results_for_figures.rda",
    "results/figures/schelker_single_cell_tsne.pdf",
    "results/figures/spillover_migration_chart.jpg",
    "results/figures/spillover_migration_all.pdf",
    "results/tables/mixing_study_correlations.tsv",
    "results/tables/spillover_signal_noise.tsv"
  conda:
    "envs/bookdown.yml"
  shell:
    """
    touch results/cache/.dir
    rm -f results/book/figures && ln -s ../figures results/book/figures
    cd notebooks && Rscript -e "bookdown::render_book('index.Rmd')"
    """

rule data:
   """download data from archive"""
   output:
     DATA_FILES
   shell:
     "wget 'https://github.com/grst/immune_deconvolution_benchmark/releases/download/v1.0.0-rc1/data.tar.gz' -O data.tar.gz && "
     "mkdir -p data && "
     "tar -xvzf data.tar.gz -C data --strip-components 1"


rule get_cache:
  """
  download precomputed results for sensitivity and specificity analysis.

  Sensitivity and Specificity are very resource-intensive. You can skip this part
  by using our precomputed values.
  """
  output:
     "results/cache/sensitivity_analysis_dataset.rda",
  shell:
     "wget 'https://github.com/grst/immune_deconvolution_benchmark/releases/download/v1.1.0/cache.tar.gz' -O cache.tar.gz && "
     "mkdir -p results/cache && "
     "tar -xvzf cache.tar.gz -C results/cache --strip-components 2"


rule upload_book:
  """publish the book on github pages"""
  input:
    "results/book/index.html",
    "results/figures/spillover_migration_all.pdf",
  shell:
    """
    cd gh-pages && \
    cp -LR ../results/book/* ./ && \
    git add --all * && \
    git commit --allow-empty -m "update docs" && \
    git push github gh-pages
    """


rule clean:
  """remove figures and the HTML report. """
  run:
    _clean()


rule wipe:
  """remove all results, including all caches. """
  run:
    _wipe()


rule test_immunedeconv:
  """run unit tests of the immunedeconv package"""
  conda:
    "envs/bookdown.yml"
  shell:
    "cd immunedeconv && "
    "echo 'not necessary - uses conda env' > .dev_deps_installed && "
    "make test"



rule _data_archive:
    """
    FOR DEVELOPMENT ONLY.

    Generate a data.tar.gz archive from data.in to publish on github.
    """
    input:
      "data.in"
    output:
      "results/data.tar.gz"
    shell:
      "tar cvzf {output} data.in"


rule _cache_archive:
    """
    FOR DEVELOPMENT ONLY.

    Generate a cache.tar.gz archive from results/cache to publish on github.
    """
    input:
      "results/cache/sensitivity_analysis_dataset.rda"
    output:
      "results/cache.tar.gz"
    shell:
      "tar cvzf {output} {input}"


def _clean():
  shell(
    """
    rm -rfv results/book/*
    rm -rfv notebooks/_bookdown_files/*files
    rm -rfv notebooks/_main_files
    rm -rfv notebooks/_main.*
    rm -fv results/figures/*
    """)


rule _wipe_bookdown:
  """wipe bookdown cache only, keep expensive sensitivity/specificity caches. """
  run:
    _wipe_bookdown()


def _wipe():
  _clean()
  shell(
    """
    rm -rfv notebooks/_bookdown_files
    rm -rfv notebooks/_main_cache
    rm -rfv notebooks/_main_files
    rm -rfv results
    """)

def _wipe_bookdown():
  _clean()
  shell(
    """
    rm -rfv notebooks/_bookdown_files
    """)
