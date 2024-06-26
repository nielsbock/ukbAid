dare_project_record_id <- "record-GXZ2k40JbxZx7xYGF66y45Yq"

#' Extract variables you want from the UKB database and create a CSV file to later upload to your own project.
#'
#' This function tells RAP to extract the variables you want from the `.dataset`
#' database file and to create a CSV file within the main RAP project folder.
#' When you want to use the CSV file in your own data analysis project, use
#' `download_project_data()`. You probably don't need to run this function often,
#' probably only once at the start of your project. NOTE: This function takes
#' 5 minutes to run on the UKB RAP, so be careful with just randomly running it.
#'
#' @param variables_to_extract A character vector of variables you want to
#'   extract from the UKB database (from the `.dataset` file). Use
#'   `save_database_variables_to_project()` to create the
#'   `data-raw/rap-variables.csv` file, open that file, and delete all variables you
#'   don't want to keep. This is the file that contains the `variable_name` column
#'   you would use for this argument.
#' @param dataset_record_id The "record ID" of the database, found when clicking
#'   the `.dataset` file in the RAP project folder. Defaults to the ID for the
#'   Steno project `dare_project_record_id`.
#' @param project_id The project's abbreviation. Defaults to using
#'   `get_rap_project_id()`, which is the name of the project folder.
#' @param username The username to set where the dataset is saved to. Defaults to using
#'   `rap_get_user()`, which is the name of the current user of the session.
#' @param file_prefix The prefix to add to the start of the file name. Defaults to "data".
#'
#' @return Outputs whether the extraction and creation of the data was
#'   successful or not. Used for the side effect of creating the CSV on the RAP
#'   server. The newly created CSV will have your username in the filename.
#' @export
#'
#' @examples
#' \dontrun{
#' library(tidyverse)
#' rap_variables %>%
#'   pull(id) %>%
#'   create_csv_from_database(project_id = "mesh", username = "lwjohnst")
#' }
create_csv_from_database <- function(variables_to_extract, field = c("name", "title"),
                                     file_prefix = "data",
                                     project_id = get_rap_project_id(),
                                     dataset_record_id = dare_project_record_id,
                                     username = rap_get_user()) {
  table_exporter_command <- builder_table_exporter(
    variables_to_extract = variables_to_extract,
    field = field,
    file_prefix = file_prefix,
    project_id = project_id,
    dataset_record_id = dare_project_record_id,
    username = username
  )

  cli::cli_alert_info("Started extracting the variables and converting to CSV.")
  cli::cli_alert_warning("This function runs for quite a while, at least 5 minutes or more. Please be patient to let it finish.")
  table_exporter_results <- system(table_exporter_command, intern = TRUE)
  data_path <- rap_get_path_files(".") |>
    stringr::str_subset("\\.csv$") |>
    stringr::str_subset(username) |>
    stringr::str_subset(project_id) |>
    stringr::str_sort(decreasing = TRUE) |>
    head(1)

  new_path <- data_path |>
    stringr::str_remove(username)
  system(glue::glue("dx mv {data_path} /users/{username}/{new_path}"))
  cli::cli_alert_success("Finished saving to CSV.")
  relevant_results <- tail(table_exporter_results, 3)[1:2]
  return(relevant_results)
}

timestamp_now <- function() {
  lubridate::now() |>
    lubridate::format_ISO8601() |>
    stringr::str_replace_all("[:]", "-")
}

#' Build, but not run, the dx table exporter command.
#'
#' This is mostly for testing purposes.
#'
#' @inheritParams create_csv_from_database
#'
#' @return Outputs character string of command sent to `dx`.
#'
#' @examples
#' library(tibble)
#' library(dplyr)
#' library(stringr)
#' library(magrittr)
#' rap_variables %>%
#'   sample_n(10) %>%
#'   pull(id) %>%
#'   builder_table_exporter(project_id = "test", username = "lwj") %>%
#'   cat()
builder_table_exporter <- function(variables_to_extract, field = c("name", "title"),
                                   file_prefix = "data",
                                   project_id = get_rap_project_id(),
                                   dataset_record_id = dare_project_record_id,
                                   username = rap_get_user()) {
  stopifnot(is.character(dataset_record_id), is.character(variables_to_extract))
  field <- rlang::arg_match(field)
  field <- switch(field,
    title = "ifield_titles",
    name = "ifield_names"
  )

  # Need to escape the ' because of issue with dx
  variables_to_extract <- stringr::str_replace_all(
    variables_to_extract,
    "('|\\(|\\)|\")",
    "\\\\\\1"
  )

  fields_to_get <- paste0(glue::glue('-{field}="{variables_to_extract}"'), collapse = " ")
  data_file_name <- glue::glue("{username}-data-{project_id}-{timestamp_now()}")
  glue::glue(
    paste0(
      c(
        "dx run app-table-exporter --brief --wait -y",
        "-idataset_or_cohort_or_dashboard={dataset_record_id}",
        "{fields_to_get}",
        "-ioutput={data_file_name}"
      ),
      collapse = " "
    )
  )
}
