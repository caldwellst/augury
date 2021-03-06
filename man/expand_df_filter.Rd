% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/expand_df.R
\name{expand_df_filter}
\alias{expand_df_filter}
\title{Filter \code{expand_df}}
\usage{
expand_df_filter(
  df,
  response,
  keep_no_obs,
  keep_before_obs,
  sort_col,
  sort_descending,
  group_col
)
}
\arguments{
\item{df}{Data frame.}

\item{response}{Column name of response variables whose missing values will be
infilled and projected, defaults to \code{"value"}.}

\item{keep_no_obs}{Logical value indicating whether or not to keep rows in the
expanded data frame when there is no data. Defaults to \code{TRUE}. This is done based
on the \code{group_col}, if provided.}

\item{keep_before_obs}{Logical value indicating when data is available, whether or not
to keep rows in the expanded data frame that lie before the first observed point.
Defaults to \code{FALSE}. This is done based on the \code{sort_col} and \code{group_col}, if provided.}

\item{sort_col}{Column name(s) to use to \code{\link[dplyr:arrange]{dplyr::arrange()}} the data prior to
supplying type and calculating mean absolute scaled error on data involving
time series. If \code{NULL}, not used. Defaults to \code{"year"}.}

\item{sort_descending}{Logical value on whether the sorted values from \code{sort_col}
should be sorted in descending order. Defaults to \code{FALSE}.}

\item{group_col}{Column name(s) of group(s) to use in \code{\link[dplyr:group_by]{dplyr::group_by()}} when
supplying type, calculating mean absolute scaled error on data involving
time series, and if \code{group_models}, then fitting and predicting models too.
If \code{NULL}, not used. Defaults to \code{"iso3"}.}
}
\value{
Filtered expanded data frame.
}
\description{
Used within \code{expand_df()} to filter out the data based on the arguments \code{keep_no_obs}
and \code{keep_before_obs}.
}
