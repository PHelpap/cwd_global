#!/usr/bin/env Rscript

# script is called without any arguments

# Example:
# >./collect_cwd_annmax.R

library(dplyr)
library(map2tidy)
library(multidplyr)


indir        <- "/storage/research/giub_geco/data_2/scratch/phelpap/ModESim/m020_tidy/Total_P_1420"
outfile_pcwd <- "/storage/research/giub_geco/data_2/scratch/phelpap/ModESim/m020_tidy/Collected_Total_P_1420/Total_P" # adjust path to where the file should be written to



# 1) Define filenames of files to collect:  -------------------------------
filnams_pcwd <- list.files(indir, pattern = "ModESim_pcwd_(LON_[0-9.+-]*)_tot_p.rds", full.names = TRUE)

# if (length(filnams_cwd) <= 1){
#   stop("Should find multiple files. Only found " ,length(filnams_cwd), ".")
# }

# 3) Process files --------------------------------------------------------
df_pcwd <- lapply(filnams_pcwd,
              function(filnam) {readr::read_rds(filnam) |> tidyr::unnest(data)}) |>
  bind_rows()

dir.create(dirname(outfile_pcwd), showWarnings = FALSE, recursive = TRUE)
readr::write_rds(
  df_pcwd,
  paste0(outfile_pcwd, ".rds"), compress = "xz") # file.path



# 4) Output to global NetCDF file ---------------------------------
library(rgeco)  # get it from https://github.com/geco-bern/rgeco

prepare_write_nc2 <- function(df_cwd, varname){
  # create object that can be used with write_nc2()
  df_cwd <- df_cwd |>
    dplyr::select(lon, lat, year, tot_precip) |>
    arrange(year, lat, lon)

  arr <- array(
    unlist(df_cwd$tot_precip),
    dim = c(
      length(unique(df_cwd$lon)),
      length(unique(df_cwd$lat)),
      length(unique(df_cwd$year))
    )
  )

  # image(arr[,,1])

  # create object for use in rgeco::write_nc2()
  vars_list = list(arr)
  names(vars_list) <- varname

  obj <- list(
    lon = sort(unique(df_cwd$lon)),
    lat = sort(unique(df_cwd$lat)),
    time = lubridate::ymd(
      paste0(
        sort(unique(df_cwd$year)),
        "-01-01"   # taking first of January as a mid-point for each year
      )
    ),
    vars = vars_list
  )

  return(obj)
}

obj_pcwd <- prepare_write_nc2(df_pcwd, varname="total_precip")

# Get meta information on code executed:
get_repo_info <- function(){
  gitrepo_url  <- system("git remote get-url origin", intern=TRUE)
  gitrepo_hash <- system("git rev-parse --short HEAD", intern=TRUE)
  gitrepo_status <-
    ifelse(system("git status --porcelain | wc -l", intern = TRUE) == "0",
           "",  #-clean-repository
           "-dirty-repository")
  gitrepo_id <- paste0(
    gsub(".git$", "", gsub(".*github.com:","github.com/", gitrepo_url)),
    "@", gitrepo_hash, gitrepo_status)

  return(gitrepo_id)
}
get_repo_info()

# Write NetCDF file:

rgeco::write_nc2(
  obj_pcwd,
  varnams = "total_precip",
  make_tdim = TRUE,
  path = paste0(outfile_pcwd, ".nc"),
  units_time = "days since 2001-01-01",
  att_title      = "Annual Total Precipitation",
  att_history    = sprintf(
    "Created on: %s, with R scripts from (%s) processing input data from: %s",
    Sys.Date(), get_repo_info(), indir)
)





