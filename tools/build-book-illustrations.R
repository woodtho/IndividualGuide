# Render the same real Iris plot in each handbook language.
if (.Platform$OS.type == "windows") Sys.setlocale("LC_CTYPE", ".UTF-8")
root <- normalizePath(".",winslash="/")
plots <- list()
for (language in c("en-CA","fr-CA")) {
  french <- identical(language,"fr-CA")
  directory <- file.path(root,"docs/book",if(french)"fr-CA" else "","assets")
  dir.create(directory,recursive=TRUE,showWarnings=FALSE)
  labels <- if(french) c("Mesures des iris par espèce","Longueur du sépale (cm)","Longueur du pétale (cm)","Espèce") else
    c("Iris measurements by species","Sepal length (cm)","Petal length (cm)","Species")
  plot <- ggplot2::ggplot(datasets::iris,ggplot2::aes(x=Sepal.Length,y=Petal.Length,colour=Species)) +
    ggplot2::geom_point(size=2.2,alpha=.85) + ggplot2::theme_minimal(base_size=14) +
    ggplot2::scale_colour_manual(values=c(setosa="#5368f5",versicolor="#237557",virginica="#dc843b")) +
    ggplot2::labs(title=labels[[1]],x=labels[[2]],y=labels[[3]],colour=labels[[4]])
  ggplot2::ggsave(file.path(directory,"iris-chart.png"),plot,width=9,height=6,dpi=180,bg="white")
  plots[[language]] <- ggplot2::ggplot_build(plot)$data[[1]][c("x","y","colour")]
}
stopifnot(identical(plots[[1]],plots[[2]]),nrow(plots[[1]])==150L)
cat("Rendered matching English and French Iris charts; all 150 points agree.\n")
