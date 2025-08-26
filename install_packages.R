# Set options
options(HTTPUserAgent = sprintf("R/%s R (%s)", getRversion(), paste(getRversion(), R.version$platform, R.version$arch, R.version$os)))
repos <- c(CRAN = "https://cloud.r-project.org")
options(repos = repos)

# Update existing packages
update.packages(lib.loc = .libPaths()[1], ask = FALSE, type = "binary")

# Install required packages
cat("Installing Radiant and dependencies ...\n")
ipkgs <- rownames(installed.packages())
install <- function(x) {
  pkgs <- x[!x %in% ipkgs]
  if (length(pkgs) > 0) {
    cat(paste("   Installing:", paste(pkgs, collapse = ", "), "\n"))
    install.packages(pkgs, lib = .libPaths()[1], type = "binary")
  }
}

# Install core packages
install(c("radiant", "miniUI", "webshot", "usethis", "remotes", "tinytex"))

# Install installr for Windows-specific functionality
install("installr")

# Install PhantomJS for webshot
cat("Installing PhantomJS for screenshots...\n")
if (is.null(webshot:::find_phantom())) {
  webshot::install_phantomjs()
}

cat("R packages installation complete\n")