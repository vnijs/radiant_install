# Radiant package installer / repair script
#
# Works out Radiant's full package requirements, finds which ones are missing on
# this machine, and installs only those. Safe to run as many times as you like.
#
# From an R console (e.g. in RStudio):
#   source("https://raw.githubusercontent.com/vnijs/radiant_install/main/install_packages.R")
#
# From a terminal:
#   Rscript -e 'source("https://raw.githubusercontent.com/vnijs/radiant_install/main/install_packages.R")'

local({
  os <- Sys.info()[["sysname"]]

  # Ask CRAN for pre-built (binary) packages on macOS/Windows; build from source
  # on Linux. The user-agent header lets CRAN serve the right binaries.
  options(
    HTTPUserAgent = sprintf(
      "R/%s R (%s)", getRversion(),
      paste(getRversion(), R.version$platform, R.version$arch, R.version$os)
    ),
    repos = c(CRAN = "https://cloud.r-project.org")
  )
  pkg_type <- if (os == "Linux") "source" else "binary"

  # Top-level packages the course relies on. `radiant` is a meta-package that
  # pulls in radiant.data/.design/.basics/.model/.multivariate; the rest are
  # runtime extras that live in other packages' Suggests and so are NOT installed
  # automatically by install.packages("radiant").
  top <- c(
    "radiant", "miniUI", "webshot", "usethis", "remotes",
    "tinytex", "pdp", "carData"
  )

  message("Determining Radiant package requirements ...")
  # Read the source index: it lists every CRAN package and declares the same
  # dependencies as the binaries, so it is the complete graph to resolve against.
  # The actual install still uses pkg_type (binary on macOS/Windows).
  db <- available.packages(type = "source")

  absent_from_cran <- setdiff(top, rownames(db))
  if (length(absent_from_cran)) {
    warning(
      "Not found on CRAN, skipping: ",
      paste(absent_from_cran, collapse = ", "),
      call. = FALSE
    )
    top <- setdiff(top, absent_from_cran)
  }

  # (1) Full requirement set: recurse through Depends + Imports + LinkingTo.
  deps <- tools::package_dependencies(
    top,
    db = db,
    which = c("Depends", "Imports", "LinkingTo"),
    recursive = TRUE
  )
  needed <- unique(c(top, unlist(deps, use.names = FALSE)))
  needed <- intersect(needed, rownames(db)) # keep only real CRAN packages
  needed <- setdiff(needed, rownames(installed.packages(priority = "base")))

  # (2) Which requirements are missing on this machine.
  installed <- rownames(installed.packages())
  missing <- sort(setdiff(needed, installed))

  message(sprintf(
    "Radiant needs %d packages: %d installed, %d missing.",
    length(needed), length(needed) - length(missing), length(missing)
  ))

  # (3) Install the missing packages, then retry any stragglers once.
  if (length(missing) == 0) {
    message("\nAll Radiant packages are already installed. You're ready to go.")
  } else {
    message("\nInstalling missing packages:\n  ", paste(missing, collapse = "\n  "))
    install.packages(missing, type = pkg_type)

    still <- sort(setdiff(missing, rownames(installed.packages())))
    if (length(still)) {
      message("\nRetrying ", length(still), " package(s) that did not install ...")
      install.packages(still, type = pkg_type)
      still <- sort(setdiff(missing, rownames(installed.packages())))
    }

    if (length(still)) {
      message(
        "\nWARNING: these packages are still missing:\n  ",
        paste(still, collapse = "\n  "),
        "\nRe-run this script, or install them manually with install.packages()."
      )
    } else {
      message("\nAll missing packages installed successfully.")
    }
  }

  # PhantomJS enables screenshots in Radiant's reports. It installs into a
  # per-user directory, so no admin rights are needed. Non-fatal if it fails.
  if ("webshot" %in% rownames(installed.packages())) {
    if (is.null(webshot:::find_phantom())) {
      message("\nInstalling PhantomJS for report screenshots ...")
      try(webshot::install_phantomjs(), silent = TRUE)
    }
  }

  message("\nDone. In RStudio, run  radiant::radiant()  to launch Radiant.")
  invisible(NULL)
})
