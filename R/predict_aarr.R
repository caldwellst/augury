#' Use annual average rate of reduction (AARR) to predict prevalence
#'
#' `predict_aarr()` is a specific function designed to use annual average rate of
#' reduction (AARR) of prevalence data to forecast future prevalence. This is
#' particularly useful for forecasting future prevalence when there is not a full time
#' series available, but only a few data points for each series.
#'
#' This function, in its current form, only forecast data from its last observed
#' data point, as AARR is not ideal for interpolation. In this case, the `model`
#' being returned by the function is a dataset of AARR values for each group (or
#' a single value if no grouped variables). No confidence bounds are generated
#' by `predict_aarr()`.
#'
#' @param response Column name of prevalence variable to be used to calculate
#'     AARR.
#' @param sort_col_min If provided, a numeric value that sets a minimum value needed
#'     to be met in the `sort_col` for an observation to be used in calculating AARR.
#'     If `sort_col = "year"` and `sort_col_min = 2008`, then only observations
#'     from 2008 onward will be used in calculating AARR.
#'
#' @inherit predict_forecast params return
#'
#' @export
predict_aarr <- function(df,
                         response,
                         sort_col_min = NULL,
                         ret = c("df", "all", "error", "model"),
                         scale = NULL,
                         probit = FALSE,
                         test_col = NULL,
                         test_period = NULL,
                         test_period_flex = NULL,
                         group_col = "iso3",
                         group_models = TRUE,
                         sort_col = "year",
                         sort_descending = FALSE,
                         pred_col = "pred",
                         type_col = NULL,
                         types = "projected",
                         source_col = NULL,
                         source = NULL,
                         replace_obs = c("missing", "all", "none"),
                         replace_filter = NULL) {
  # Assertions and error checking
  df <- assert_df(df)
  assert_columns(df, response, test_col, group_col, sort_col, type_col, source_col)
  assert_columns_unique(response, pred_col, test_col, group_col, sort_col, type_col, source_col)
  ret <- rlang::arg_match(ret)
  assert_test_col(df, test_col)
  assert_string(pred_col, 1)
  assert_string(types, 1)
  assert_string(source, 1)
  assert_numeric(sort_col_min, 1)
  replace_obs <- rlang::arg_match(replace_obs)
  replace_filter <- parse_replace_filter(replace_filter, response)

  if (!is.null(scale)) {
    df <- scale_transform(df, response, scale = scale)
  }

  if (probit) {
    df <- probit_transform(df, response)
  }

  mdl_df <- fit_aarr_model(df = df,
                           response = response,
                           test_col = test_col,
                           group_col = group_col,
                           group_models = group_models,
                           sort_col = sort_col,
                           sort_descending = sort_descending,
                           sort_col_min = sort_col_min,
                           pred_col = pred_col)

  mdl <- mdl_df[["mdl"]]
  df <- mdl_df[["df"]]

  if (ret == "model") {
    return(mdl)
  }

  # Untransform variables
  if (probit) {
    df <- probit_transform(df,
                           c(response,
                             pred_col),
                           inverse = TRUE)
  }

  # Unscale variables
  if (!is.null(scale)) {
    df <- scale_transform(df,
                          c(response,
                            pred_col),
                          scale = scale,
                          divide = FALSE)
  }

  # Get error if being returned
  if (ret %in% c("all", "error")) {
    err <- model_error(df = df,
                       response = response,
                       test_col = test_col,
                       test_period = test_period,
                       test_period_flex = test_period_flex,
                       group_col = group_col,
                       sort_col = sort_col,
                       sort_descending,
                       pred_col = pred_col,
                       upper_col = NULL,
                       lower_col = NULL)

    if (ret == "error") {
      return(err)
    }
  }

  # Merge predictions into observations
  df <- merge_prediction(df = df,
                         response = response,
                         group_col = group_col,
                         sort_col = sort_col,
                         sort_descending = sort_descending,
                         pred_col = pred_col,
                         type_col = type_col,
                         types = c(NA_character_, NA_character_, types),
                         source_col = source_col,
                         source = source,
                         replace_obs = replace_obs,
                         replace_filter = replace_filter)

  if (ret == "df") {
    return(df)
  } else if (ret == "all") {
    list(df = df,
         error = err,
         model = mdl)
  }
}

#' Extract AARR from vector of years and prevalence
#'
#' @param years Vector of year values
#' @param prevalence Vector of prevalence values
calculate_aarr <- function(years, prevalence) {
  df <- data.frame(x = years,
                   y = prevalence)
  fit <- stats::lm(log(y) ~ x, data = df, na.action = stats::na.omit)
  coef <- fit[["coefficients"]][["x"]]
  100 * (1 - exp(coef))
}

#' Generate prediction from model object
#'
#' `fit_aarr_data()` calculates AARR and then generates a prediction based on calculated AARR.
#'
#' @inheritParams predict_aarr
#'
#' @return A data frame.
fit_aarr_model <- function(df,
                           response,
                           test_col,
                           sort_col,
                           sort_descending,
                           sort_col_min,
                           group_col,
                           group_models,
                           pred_col) {
  if (group_models) {
    df <- dplyr::group_by(df, dplyr::across(dplyr::all_of(group_col)))
  }

  if (!is.null(sort_col)) {
    if (sort_descending) {
      fn <- dplyr::desc
    } else {
      fn <- NULL
    }
    df <- dplyr::arrange(df, dplyr::across(dplyr::all_of(sort_col), fn), .by_group = TRUE)
  }

  df <- df %>%
    dplyr::mutate(!!sym(pred_col) := .data[[response]],
                  !!sym(pred_col) := if (!is.null(test_col)) ifelse(.data[[test_col]], NA_real_, .data[[pred_col]]) else .data[[pred_col]],
                  !!sym(pred_col) := if (!is.null(sort_col_min)) ifelse(.data[[sort_col]] >= sort_col_min, .data[[pred_col]], NA_real_) else .data[[pred_col]],
                  "aarr_temp_augury" := if (sum(!is.na(.data[[pred_col]])) > 1) calculate_aarr(.data[[sort_col]], .data[[pred_col]]) else NA_real_,
                  "last_obs_temp" := max(which(!is.na(.data[[pred_col]])), -Inf),
                  !!sym(pred_col) := dplyr::case_when(
                    sum(!is.na(.data[[pred_col]])) <= 1 ~ .data[[pred_col]],
                    dplyr::row_number() > .data[["last_obs_temp"]] ~ .data[[pred_col]][.data[["last_obs_temp"]]] * ((1 - (.data[["aarr_temp_augury"]] / 100)) ^ (.data[[sort_col]] - .data[[sort_col]][.data[["last_obs_temp"]]])),
                    TRUE ~ .data[[pred_col]]
                  ))

  mdl <- dplyr::summarize(df, "aarr" := unique(.data[["aarr_temp_augury"]]), .groups = "drop")
  df <- df %>% dplyr::ungroup() %>% dplyr::select(-c("aarr_temp_augury", "last_obs_temp"))

  list(df = df, mdl = mdl)
}