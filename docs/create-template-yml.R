rlang::check_installed(c("fs", "purrr", "stringr", "rmarkdown", "yaml"))
# add more sub-folders for listing, like projects etc...
target_folder <- "practicals"

convert_qmd_to_template <- function(path) {
  if (!fs::file_exists(path)) {
    stop(paste0("The file ", path, " does not exists"))
  }
  output <- stringr::str_replace(path, "\\.qmd$", "_answer.qmd")
  metadata <- rmarkdown::yaml_front_matter(path)
  # (?s): Enables dotall mode, so . matches newlines as well.

  qmd_sans_chunks_no_header <- readLines(path, warn = FALSE) |>
    paste(collapse = "\n") |>
    stringr::str_remove("(?s)^---.*?---\\n*") |>
    stringr::str_replace_all(
      "(?s)```\\{r\\s?[a-zA-Z_\\s\\-]*\\}\\n#\\| unilur-solution\\: true.*?```",
      "```{r}\n# Write answer here\n```"
    )

  writeLines(
    c(
      "---",
      paste0("title: \"", metadata$title, "\""),
      paste0("date: ", metadata$date),
      "author: \"Your name\"",
      "format: html",
      "embed-resources: true",
      "---\n",
      qmd_sans_chunks_no_header
    ),
    con = output
  )
  invisible(output)
}

create_template_yaml <- function(folder) {
  message(paste("create qmd templates from ", folder))
  fs::dir_ls(folder, glob = "*.qmd") |>
    stringr::str_subset("answer", negate = TRUE) |>
    purrr::walk(convert_qmd_to_template)

  # inspired from https://github.com/andrewheiss/datavizsp25.classes.andrewheiss.com/blob/main/data/extract-news-headings.R
  # by Andrew Heiss
  message(paste("read in", folder, "qmd templates"))
  fs::dir_ls(folder, glob = "*.qmd") |>
    stringr::str_subset("answer", negate = TRUE) |>
    purrr::map(\(path) {
      metadata <- rmarkdown::yaml_front_matter(path)
      if (metadata$date == "today") {
        metadata$date <- Sys.Date()
      }
      out <- stringr::str_replace(path, "\\.qmd$", "_answer.qmd")
      list(
        title = metadata$title |> structure(quoted = TRUE),
        # be sure to initialize values if NULL
        date = metadata$date %||% Sys.Date(),
        draft = metadata$draft %||% FALSE,
        href = structure(out, quoted = TRUE),
        file = fs::path_file(out) |>
          structure(quoted = TRUE)
      )
    }) -> answers
  # only look for answers of published practicals
  answers |>
    purrr::keep(\(x) x$draft == FALSE) -> answers
  # ensure the answer templates are present
  if (
    !fs::path(folder, purrr::map_chr(answers, "file")) |>
      fs::file_exists() |>
      all()
  ) {
    stop("Some practicals templates are missing")
  }
  answers |>
    unname() |>
    yaml::as.yaml() -> templates

  writeLines(
    c(
      "# This file is generated automatically; do NOT edit by hand\n",
      templates
    ),
    con = file.path(folder, "templates.yml")
  )
  invisible(folder)
}

purrr::walk(target_folder, create_template_yaml)
