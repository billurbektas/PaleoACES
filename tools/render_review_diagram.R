# Analysis dependencies and associated stages, for Markdown and embedded HTML.
args = commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L)
suppressPackageStartupMessages(library(grid))
png(args[1], width = 2200, height = 2450, res = 170)
grid.newpage()
ink = "#233647"; line = "#607789"
node = function(x, y, title, scripts, fill = "#edf4f8", height = .095) {
  width = .43
  grid.roundrect(x, y, width, height, r = unit(3, "mm"),
                 gp = gpar(fill = fill, col = "#91a7b6", lwd = 1.3))
  grid.text(title, x, y + height/2 - .018,
            gp = gpar(col = ink, fontsize = 15, fontface = "bold"))
  grid.text(paste(scripts, collapse = "\n"), x, y - .012,
            gp = gpar(col = ink, fontsize = 11.5, lineheight = 1.2))
}
connect = function(x, y) {
  grid.lines(x, y, arrow = arrow(type = "closed", length = unit(2.4, "mm")),
             gp = gpar(col = line, lwd = 1.6))
}
# Paths are drawn first, so labels and boxes stay readable at branch points.
connect(c(.25,.25), c(.87,.8175))
connect(c(.75,.75), c(.8675,.8175))
connect(c(.035,.012,.012,.035), c(.925,.925,.61,.61))
connect(c(.535,.50,.50,.25,.25), c(.925,.925,.67,.67,.65))
connect(c(.965,.987,.987,.965), c(.925,.925,.61,.61))
connect(c(.035,.023,.023,.035), c(.77,.77,.475,.475))
connect(c(.535,.50,.50,.465), c(.77,.77,.475,.475))
connect(c(.965,.975,.975,.965), c(.77,.77,.335,.335))
connect(c(.25,.25), c(.57,.515))
connect(c(.25,.25), c(.435,.3875))
connect(c(.75,.75), c(.56,.385))
connect(c(.465,.535), c(.335,.335))
connect(c(.25,.25), c(.2825,.2325))
connect(c(.75,.75), c(.285,.2325))
connect(c(.535,.50,.50,.25,.25), c(.335,.335,.252,.252,.2325))
connect(c(.035,.012,.012,.285), c(.335,.335,.05,.05))
connect(c(.965,.987,.987,.715), c(.335,.335,.05,.05))
node(.25,.925,"Modern vegetation and fire", c("000_MORA_cleaning.R", "000_NOCA_cleaning.R", "01_get_fire_info.R"),height=.11)
node(.75,.925,"Dated paleo vegetation and fire", c("000_PALEO_a_agedepth.R (optional refit)", "000_PALEO_b_vegetation.R", "000_FIRE_cleaning.R; 000_PALEO_c_fire.R"),height=.115)
node(.25,.77,"Modern climate: each adult Y−5…Y", c("000_MORA_climate.R", "000_NOCA_climate.R"))
node(.75,.77,"Paleo climate", c("000_PALEO_d_climate_download.R", "000_PALEO_e_climate.R"))
node(.25,.61,"Taxonomy consolidation", "000_occurrence_data_consolidate.R",height=.08)
node(.75,.61,"Accepted events and source comparison", c("12_walsh_fire_reproduction.R", "12a_fire_event_detection_worked_example.R"),height=.10)
node(.25,.475,"CCA eligibility, fit and projections", "05_cca_model.R", fill="#e7f0e9",height=.08)
node(.25,.335,"Tracking and resolution sensitivity", c("09_tracking_metrics_500yr_sensitivity.R", "09_tracking_metrics.R", "09a_method_example.R"),fill="#e7f0e9",height=.105)
node(.75,.335,"Climate eras and high-fire periods", c("13_holocene_climate_fire_eras.R", "13b_fire_method_worked_example.R"),fill="#e7f0e9",height=.10)
node(.25,.185,"Tracking comparisons: Figure 4", c("09b_tracking_visualization_data.R", "09c_tracking_comparison.R"),fill="#fbf0df")
node(.75,.185,"Community and climate/fire figures", c("05a_cca_figure.R — Figure 3", "13a_climate_change_figure.R — Figure 2"),fill="#fbf0df")
node(.50,.05,"Direction discrepancies: Figure 5", "14_cca_direction_analysis.R",fill="#fbf0df",height=.075)
grid.text("SDs / support", .50, .353, gp=gpar(col=ink,fontsize=8.5))
grid.text("Raw seasonal climate", .975, .475, rot=90,
          gp=gpar(col=ink,fontsize=10))
dev.off()
