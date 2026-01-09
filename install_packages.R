# Set options
options(HTTPUserAgent = sprintf("R/%s R (%s)", getRversion(), paste(getRversion(), R.version$platform, R.version$arch, R.version$os)))
repos <- c(CRAN = "https://packagemanager.posit.co/cran/2025-12-01", RSM="https://radiant-rstats.github.io/minicran")
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
    install.packages(pkgs, lib = .libPaths()[1], type = os_type, repos = repos)
  }
}

# Install core packages
install(c("radiant", "miniUI", "webshot", "usethis", "remotes", "tinytex"))

# Install PhantomJS for webshot
cat("Installing PhantomJS for screenshots...\n")
if (is.null(webshot:::find_phantom())) {
  webshot::install_phantomjs()
}

cat("R packages installation complete\n")
