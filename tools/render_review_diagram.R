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
# Independent climate/fire classification feeds the canonical response tables.
connect(c(.25,.25),c(.87,.79)); connect(c(.75,.75),c(.87,.79))
connect(c(.25,.25),c(.69,.61)); connect(c(.75,.75),c(.69,.61))
connect(c(.465,.535),c(.57,.57)); connect(c(.75,.75),c(.53,.45))
connect(c(.25,.25),c(.53,.45)); connect(c(.25,.25),c(.35,.27))
connect(c(.75,.75),c(.35,.27)); connect(c(.465,.535),c(.41,.41))
connect(c(.25,.25),c(.17,.105)); connect(c(.75,.75),c(.17,.105))
node(.25,.925,"Modern observations and fire",c("000_MORA_cleaning.R; 000_NOCA_cleaning.R","01_get_fire_info.R"),height=.11)
node(.75,.925,"Paleo observations and chronology",c("000_PALEO_b_vegetation.R","000_PALEO_a_agedepth.R — optional refit"),height=.11)
node(.25,.74,"Modern climate and consolidation",c("000_MORA_climate.R; 000_NOCA_climate.R","000_occurrence_data_consolidate.R"),height=.10)
node(.75,.74,"Paleo climate and accepted fire",c("000_PALEO_d/e_climate.R","12_walsh_fire_reproduction.R"),height=.10)
node(.25,.57,"Unchanged pooled CCA + reference",c("05_cca_model.R","607 plots, 14 taxa; scores and fixed SDs"),fill="#e7f0e9",height=.08)
node(.75,.57,"Frozen climate/fire classifications",c("13_holocene_climate_fire_eras.R","Independent 1,000-year framework"),fill="#e7f0e9",height=.08)
node(.25,.40,"Tracking and combined model input",c("09_tracking_metrics.R; 09b_tracking_model_data.R","Transitions, uncertainty, support; one 28-column input"),fill="#e7f0e9",height=.10)
node(.75,.40,"Preserved community trajectory",c("05a_cca_figure.R — Figure 3","Existing species and climate contribution panels"),fill="#fbf0df",height=.10)
node(.25,.22,"MA(1) results and manuscript comparison",c("10 / 10a: lag rate, turnover and raw climate","10b_tracking_manuscript_figure.R — Figure 4","09a: tracking context; 12a/13b: fire examples"),fill="#fbf0df",height=.12)
node(.75,.22,"Climate/fire display",c("13a_climate_change_figure.R — Figure 2","Reads modern calculation records"),fill="#fbf0df",height=.10)
grid.text("Scientific Decisions and generated Analysis Review",.5,.065,gp=gpar(col=ink,fontsize=15,fontface='bold'))
dev.off()
