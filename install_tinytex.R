# Check if pdflatex already exists
pl <- Sys.which("pdflatex")
if (nchar(pl) == 0) {
  cat("Installing TinyTeX...\n")
  tinytex::install_tinytex()
  cat("TinyTeX installation complete\n")
} else {
  cat("LaTeX already installed, skipping TinyTeX\n")
}