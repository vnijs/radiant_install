# Set options
options(HTTPUserAgent = sprintf("R/%s R (%s)", getRversion(), paste(getRversion(), R.version$platform, R.version$arch, R.version$os)))
repos <- c(CRAN = "https://cloud.r-project.org")
options(repos = repos)

# Determine package type based on OS
os_type <- if (Sys.info()[["sysname"]] == "Linux") "source" else "binary"

# Install required packages
cat("Installing Radiant and dependencies ...\n")
cat(os_type)
if (os_type == "source") {
  cat("   Note: Installing from source on Linux (this may take longer)\n")
}
ipkgs <- rownames(installed.packages())
install <- function(x) {
  pkgs <- x[!x %in% ipkgs]
  if (length(pkgs) > 0) {
    cat(paste("   Installing:", paste(pkgs, collapse = ", "), "\n"))
    install.packages(pkgs, lib = .libPaths()[1], type = os_type)
  }
}

# Install core packages
install(c("radiant", "miniUI", "webshot", "usethis", "remotes", "tinytex", "pdp", "carData"))

# Install PhantomJS for webshot
cat("Installing PhantomJS for screenshots...\n")
if (is.null(webshot:::find_phantom())) {
  webshot::install_phantomjs()
}

cat("R packages installation complete\n")
