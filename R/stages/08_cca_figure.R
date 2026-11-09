# Figure 3: A, species/climate biplot; B, observed and predicted trajectories.
# Constrained-inertia colors summarize all constrained axes. Biplot positions
# and trajectory coordinates retain CCA1–CCA2 site scaling, Hill = FALSE.
source(here::here('R/helpers/config.R'), local = TRUE)
library(here)
render_figures = isTRUE(getOption("paleoaces.render_figures", TRUE))
source(here("R/stages/04_cca_model.R"), local = TRUE)
library(ggrepel)
library(patchwork)
source(here("R/helpers/figure_style.R"), local = TRUE)
holocene_display_mode = "era_centroid"
cca_figure_stem = "fig_cca_trajectories"
base_theme = theme_paleoaces(base_size = 16) +
  theme(legend.title = element_blank(), legend.position = "bottom",
    axis.title=element_text(size=17),axis.text=element_text(size=14),
    panel.grid.minor = element_blank())
imp = summary(cca_model)$cont$importance[2, ] * 100
ax_lab = paste0(c("CCA1", "CCA2"), " ", round(imp[1:2], 1), "%")
clim_full = CLIMATE_VARIABLE_LABELS[CCA_VARIABLES]
full_name = function(x) unname(ifelse(x %in% names(clim_full), clim_full[x], x))

# -----------------------------------------------------------------------------
# Trajectory points: observed (WA) and predicted (LC) centroids through time
# -----------------------------------------------------------------------------
# Anthropocene: identical valid pairs at BOTH dates, prepared in 04_cca_model.R.
# The full legacy calibration cloud remains in the model/background display.
past_pred = predict(cca_model, newdata = env_past_paired,     type = "lc",
                    scaling = cca_scaling, hill = cca_hill)
past_proj = predict(cca_model, newdata = species_past_paired, type = "wa",
                    scaling = cca_scaling, hill = cca_hill)

anth_pts = bind_rows(
  tibble(plot_id = rownames(species_past_paired), t = "legacy",
         o1 = past_proj[, 1], o2 = past_proj[, 2],
         p1 = past_pred[, 1], p2 = past_pred[, 2]),
  tibble(plot_id = rownames(species_present_final), t = "resurvey",
         o1 = projected_present[, 1], o2 = projected_present[, 2],
         p1 = predicted_present[, 1], p2 = predicted_present[, 2])
) %>%
  left_join(site_lookup, by = "plot_id") %>%
  group_by(site, era = "anthropocene", t) %>%
  summarize(across(c(o1, o2, p1, p2), mean), n = n(), .groups = "drop") %>%
  mutate(order = if_else(t == "legacy", 1, 2), lab = t)
stopifnot(identical(rownames(species_past_paired), rownames(species_present_final)),
          all(is.finite(unlist(select(anth_pts, o1, o2, p1, p2)))))
# Persist the exact paired site means so report claims and Figure 3 are auditable.
write_csv(anth_pts, out("figures/cca_trajectory_anthropocene_centroids.csv"))

# Primary occupied-century positions, averaged within lake/period and then
# equally across available lakes. No interpolation or support filtering.
positions=read_csv(out('cca_tracking_holocene_century_positions.csv'),show_col_types=FALSE)
catalog=read_csv(out('holocene_era_catalog.csv'),show_col_types=FALSE)
era_levels=catalog$era_id
positions$era_id=vapply(positions$century_cal_bp,function(age) {
  k=which(age>=catalog$younger_cal_bp & age<catalog$older_cal_bp)
  if(length(k)>1L) stop('Overlapping climate-period boundaries')
  if(length(k)) catalog$era_id[k] else NA_character_
},character(1))
lake_centroids=positions |> filter(!is.na(era_id)) |> group_by(site,lake,era_id) |>
  summarise(across(c(o1,o2,p1,p2),mean),n_dates=n(),n=median(n_samples),.groups='drop')
era_centroid_audit=lake_centroids |> group_by(site,era_id) |>
  summarise(across(c(o1,o2,p1,p2),mean),n_lakes=n(),n_dates=sum(n_dates),n=mean(n),.groups='drop') |>
  left_join(select(catalog,era_id,era_class),by='era_id',relationship='many-to-one') |>
  mutate(era='holocene',order=match(era_id,era_levels),lab=era_id) |> arrange(site,order)
write_csv(lake_centroids,out('figures/cca_trajectory_lake_period_centroids.csv'))
write_csv(era_centroid_audit |> transmute(site,era_id,era_class,
  observed_CCA1=o1,observed_CCA2=o2,predicted_CCA1=p1,predicted_CCA2=p2,
  n_lakes,n_dates,median_samples=n,order),out('figures/cca_trajectory_era_centroids.csv'))
holo_pts=era_centroid_audit

traj = bind_rows(anth_pts %>% select(-t),
                 holo_pts %>% select(site, era, o1, o2, p1, p2, n, order, lab)) %>%
  mutate(grp = interaction(site, era)) %>%
  arrange(grp, order)

# Long form, so observed vs predicted gets a real legend rather than a caption.
traj_long = bind_rows(
  traj %>% transmute(site, era, grp, order, lab, n, type = "observed",  x = o1, y = o2),
  traj %>% transmute(site, era, grp, order, lab, n, type = "predicted", x = p1, y = p2)
) %>%
  mutate(type = factor(type, levels = c("observed", "predicted"))) %>%
  arrange(grp, type, order)

# Initial direct-label positions; the joint repel layer also avoids time labels.
series_label_positions = tribble(
  ~site,  ~era,            ~type,        ~anchor_lab, ~nx_frac, ~ny_frac,
  "MORA", "holocene",     "observed",   "CC4",          0.000,   -0.070,
  "MORA", "holocene",     "predicted",  NA_character_,   0.100,   -0.080,
  "MORA", "anthropocene", "observed",   "legacy",       0.100,    0.080,
  "MORA", "anthropocene", "predicted",  NA_character_,  -0.100,   -0.170,
  "NOCA", "holocene",     "observed",   "CC1",          0.000,    0.070,
  "NOCA", "holocene",     "predicted",  NA_character_,  -0.120,    0.120,
  "NOCA", "anthropocene", "observed",   "resurvey",     0.080,   -0.070,
  "NOCA", "anthropocene", "predicted",  "legacy",       0.100,    0.070)

series_centers = traj_long %>%
  group_by(grp, site, era, type) %>%
  summarize(center_x = mean(x), center_y = mean(y), .groups = "drop")
series_anchors = traj_long %>%
  filter(!is.na(lab)) %>%
  select(site, era, type, anchor_lab = lab, anchor_x = x, anchor_y = y)

series_lab = series_label_positions %>%
  mutate(type = factor(type, levels = levels(traj_long$type))) %>%
  left_join(series_centers, by = c("site", "era", "type")) %>%
  left_join(series_anchors, by = c("site", "era", "type", "anchor_lab")) %>%
  mutate(
    x = if_else(is.na(anchor_lab), center_x, anchor_x),
    y = if_else(is.na(anchor_lab), center_y, anchor_y),
    lab = paste0(site, " ",
      if_else(era == "holocene", "Holocene", "Anthropocene"), "\n",
      str_to_title(as.character(type))),
    nx = nx_frac * diff(range(traj_long$x)),
    ny = ny_frac * diff(range(traj_long$y))
  )

expected_series_labels = as.vector(outer(
  c("MORA", "NOCA"),
  c("Holocene\nObserved", "Holocene\nPredicted",
    "Anthropocene\nObserved", "Anthropocene\nPredicted"),
  paste))
stopifnot(nrow(series_lab) == 8L,
          setequal(series_lab$lab, expected_series_labels),
          !anyDuplicated(series_lab[c("site", "era", "type")]),
          all(is.finite(series_lab$x)), all(is.finite(series_lab$y)),
          all(is.finite(series_lab$nx)), all(is.finite(series_lab$ny)))


steps = traj_long %>% group_by(grp,type) %>%
  mutate(xend=lead(x),yend=lead(y)) %>% ungroup() %>% filter(!is.na(xend))
step_heads = steps
lab_pts = traj_long %>% filter(type=="observed",!is.na(lab))

# Panel A: all species and climate variables, with inertia and occurrence.
env_bp = as_tibble(scores(cca_model,display="bp",choices=1:2,
  scaling=cca_scaling,hill=cca_hill),rownames="variable")
sp_bp = as_tibble(scores(cca_model,display="species",choices=1:2,
  scaling=cca_scaling,hill=cca_hill),rownames="species")
tot_constrained=sum(cca_model$CCA$eig)
sp_inertia=inertcomp(cca_model,display="species")
sp_share=tibble(species=rownames(sp_inertia),
  share_pct=100*sp_inertia[,"CCA"]/tot_constrained)
sp_prev=tibble(species=colnames(species_past_final),
  n_plots=colSums(species_past_final>0),
  prev_pct=100*colSums(species_past_final>0)/nrow(species_past_final))
set.seed(1)
clim_marg=anova(cca_model,by="margin",permutations=499)
nterm=nrow(clim_marg)-1L
clim_share=tibble(variable=rownames(clim_marg)[seq_len(nterm)],
  share_pct=100*clim_marg$ChiSquare[seq_len(nterm)]/tot_constrained)
shared_pct=100-sum(clim_share$share_pct)
arrow_mult=.62*max(sqrt(sp_bp$CCA1^2+sp_bp$CCA2^2))/
  max(sqrt(env_bp$CCA1^2+env_bp$CCA2^2))
sp_bp=sp_bp %>% left_join(sp_share,by="species",relationship="one-to-one") %>%
  left_join(sp_prev,by="species",relationship="one-to-one")
env_bp=env_bp %>% left_join(clim_share,by="variable",relationship="one-to-one")
biplot_labels=bind_rows(
  sp_bp %>% transmute(component="Species",name=species,x=CCA1,y=CCA2,
    share_pct,occurrence_pct=prev_pct,label=sprintf("%s (%.1f%%)",species,prev_pct),
    fontface="italic",nudge_x=0,nudge_y=0),
  env_bp %>% transmute(component="Climate",name=variable,
    x=CCA1*arrow_mult,y=CCA2*arrow_mult,share_pct,occurrence_pct=NA_real_,
    label=full_name(variable),
    fontface="bold",nudge_x=CCA1*arrow_mult*.22,nudge_y=CCA2*arrow_mult*.22))
# Separate crowded central taxa and nearby climate tips before the shared repel
# layer resolves remaining collisions. Leaders still point to the exact scores.
biplot_label_positions=tribble(
  ~name,~label_x,~label_y,
  "Pinus albicaulis",2.3,5.7,
  "Pinus ponderosa",-4.5,3.7,
  "Pinus contorta",-1.0,3.2,
  "Abies lasiocarpa",3.7,2.6,
  "Picea engelmannii",-.7,1.7,
  "Abies grandis",-4.3,1.5,
  "Pinus monticola",2.4,1.1,
  "Pseudotsuga menziesii",-4.1,.7,
  "Thuja plicata",-3.3,-.1,
  "Tsuga mertensiana",3.7,.25,
  "Abies amabilis",2.2,-.65,
  "Tsuga heterophylla",-1.3,-1.0,
  "Callitropsis nootkatensis",3.4,-1.6,
  "Abies procera",-.5,-2.0,
  "MSpT",-5.5,-3.0,
  "MWT",-2.0,-3.0,
  "SP",1.6,-3.0,
  "WP",5.0,-3.0)
biplot_labels=biplot_labels %>% left_join(biplot_label_positions,by="name",relationship="one-to-one") %>%
  mutate(nudge_x=label_x-x,nudge_y=label_y-y)
stopifnot(nrow(sp_bp)==14L,nrow(env_bp)==4L,abs(sum(sp_bp$share_pct)-100)<1e-8,
  all(is.finite(biplot_labels$share_pct)),all(sp_bp$prev_pct>=0 & sp_bp$prev_pct<=100))
write_csv(biplot_labels,out("figures/cca_figure_biplot_annotations.csv"))
p_biplot=ggplot()+
  geom_hline(yintercept=0,color="grey88",linewidth=.4)+
  geom_vline(xintercept=0,color="grey88",linewidth=.4)+
  geom_segment(data=sp_bp,aes(0,0,xend=CCA1,yend=CCA2,color=share_pct),
    linewidth=.45,arrow=arrow(length=unit(.12,"cm")),show.legend=FALSE)+
  geom_point(data=sp_bp,aes(CCA1,CCA2,color=share_pct),size=1.4,show.legend=FALSE)+
  geom_segment(data=env_bp,aes(0,0,xend=CCA1*arrow_mult,yend=CCA2*arrow_mult,color=share_pct),
    linewidth=1.1,arrow=arrow(length=unit(.25,"cm"),type="closed"),show.legend=TRUE)+
  geom_label_repel(data=biplot_labels,
    aes(x,y,label=label,color=share_pct,fontface=fontface),size=4.2,
    fill="white",linewidth=0,label.padding=unit(.10,"lines"),
    nudge_x=biplot_labels$nudge_x,nudge_y=biplot_labels$nudge_y,
    box.padding=.45,point.padding=.2,force=3,force_pull=2,
    segment.size=.3,segment.color="grey65",min.segment.length=0,
    max.overlaps=Inf,max.iter=200000,max.time=8,seed=11,show.legend=FALSE)+
  scale_color_gradientn(colours=c(PAPER_SITE_COLORS[["MORA"]],"#9B79B6","#CF646E",
      PAPER_SITE_COLORS[["NOCA"]]),
    limits=c(0,max(biplot_labels$share_pct)),name="Constrained inertia (%)",
    guide=guide_colorbar(title.position="top",title.hjust=.5,
      barwidth=unit(5,"cm"),barheight=unit(.35,"cm")))+
  scale_discrete_identity(aesthetics="fontface")+
  coord_equal(xlim=c(-7.5,6.5),ylim=c(-3.6,6.1),expand=FALSE,clip="off")+
  labs(tag="A.",x=ax_lab[1],y=ax_lab[2])+
  base_theme+theme(legend.title=element_text(size=14),legend.text=element_text(size=13),
    plot.subtitle=element_text(size=13,color="grey35"),plot.margin=margin(10,20,10,10))

# Panel B: tightly framed trajectories with fully opaque light predicted colors.
# Lighting the actual colors avoids fading lines and text into the background.
lighten=function(hex,amount=.42) {
  v=col2rgb(hex)/255
  rgb(v[1,]+(1-v[1,])*amount,v[2,]+(1-v[2,])*amount,v[3,]+(1-v[3,])*amount)
}
path_colors=c("MORA.observed"=PAPER_SITE_COLORS[["MORA"]],
  "NOCA.observed"=PAPER_SITE_COLORS[["NOCA"]],
  "MORA.predicted"=lighten(PAPER_SITE_COLORS[["MORA"]]),
  "NOCA.predicted"=lighten(PAPER_SITE_COLORS[["NOCA"]]))
add_path_color=function(x) x %>% mutate(path_color=paste(site,type,sep="."))
traj_long=add_path_color(traj_long);steps=add_path_color(steps)
step_heads=add_path_color(step_heads)
trajectory_labels=bind_rows(
  add_path_color(lab_pts) %>% transmute(x,y,label=lab,path_color,
    nudge_x=0,nudge_y=0,fontface="plain",label_size=4),
  add_path_color(series_lab) %>% transmute(x,y,label=lab,path_color,
    nudge_x=nx,nudge_y=ny,fontface="bold",label_size=4.6))
write_csv(traj_long %>% mutate(display_color=unname(path_colors[path_color]),display_alpha=1),
  out("figures/cca_figure_trajectory_display.csv"))
calib_proj=predict(cca_model,newdata=species_past_final,type="wa",scaling=cca_scaling,hill=cca_hill)
calib=tibble(o1=calib_proj[,1],o2=calib_proj[,2])
zpad=.12
zx=range(traj_long$x)+c(-1,1)*zpad*diff(range(traj_long$x))
zy=range(traj_long$y)+c(-1,1)*zpad*diff(range(traj_long$y))
n_out=sum(calib$o1<zx[1] | calib$o1>zx[2] | calib$o2<zy[1] | calib$o2>zy[2])
p_trajectories=ggplot()+
  geom_hline(yintercept=0,color="grey90")+geom_vline(xintercept=0,color="grey90")+
  geom_point(data=calib,aes(o1,o2),color="grey80",size=.6,alpha=.3)+
  geom_point(data=traj_long,aes(x,y,color=path_color),shape=21,fill="white",
    size=2.3,stroke=.8,show.legend=FALSE)+
  geom_segment(data=steps,aes(x,y,xend=xend,yend=yend,color=path_color),
    linewidth=.8,lineend="round",show.legend=FALSE)+
  geom_segment(data = step_heads,aes(x,y,xend=xend,yend=yend,color=path_color,linetype=type),
    arrow=arrow(length=unit(.19,"cm"),type="closed"),linewidth=.8,show.legend=TRUE)+
  geom_text_repel(data=trajectory_labels,aes(x,y,label=label,color=path_color,
    fontface=fontface,size=label_size),
    nudge_x=trajectory_labels$nudge_x,nudge_y=trajectory_labels$nudge_y,
    box.padding=.4,point.padding=.2,force=2.5,force_pull=1.5,
    segment.size=.3,segment.color="grey60",min.segment.length=0,
    max.overlaps=Inf,max.iter=200000,max.time=8,seed=3,lineheight=.95,
    xlim=zx,ylim=zy,show.legend=FALSE)+
  scale_color_manual(values=path_colors,guide="none")+
  scale_linetype_manual(values=c(observed="solid",predicted="solid"),
    labels=c(observed="Observed",predicted="Predicted"),
    guide=guide_legend(override.aes=list(color=c("grey25","grey70"),linewidth=1.1)))+
  scale_size_identity()+scale_discrete_identity(aesthetics="fontface")+
  coord_cartesian(xlim=zx,ylim=zy,expand=FALSE)+
  labs(tag="B.",x=ax_lab[1],y=ax_lab[2])+base_theme+
  theme(legend.text=element_text(size=15),legend.key.width=unit(2.2,"cm"),
    legend.key.height=unit(.65,"cm"),plot.margin=margin(10,12,10,12))

composite=wrap_plots(p_biplot,p_trajectories,nrow=1,widths=c(1,1.15)) &
  theme(plot.tag=element_text(size=24,face="bold"),plot.tag.position="topleft")
if(render_figures) {
  ggsave(fig("main", paste0(cca_figure_stem,".pdf")),composite,width=18.5,height=8.5,
    device=cairo_pdf,bg="white")
  ggsave(fig("main", paste0(cca_figure_stem,".png")),composite,width=18.5,height=8.5,dpi=300,bg="white")
}
# Presentation versions of panel B alone. Every version keeps the full figure's
# axis limits (zx, zy), calibration background and page size, so the slides
# overlay exactly: (1) Anthropocene trajectories only; (2) Anthropocene plus a
# single Holocene step per series from its first to its final era centroid.
trajectory_subset_panel = function(sub_long) {
  sub_steps = sub_long %>% group_by(grp, type) %>% arrange(order, .by_group = TRUE) %>%
    mutate(xend = lead(x), yend = lead(y)) %>% ungroup() %>% filter(!is.na(xend))
  sub_lab_pts = sub_long %>% filter(type == "observed", !is.na(lab))
  # Series labels reuse the main figure's anchors and offsets; an anchor point
  # that is not displayed falls back to the series centre.
  sub_centers = sub_long %>% group_by(site, era, type) %>%
    summarize(center_x = mean(x), center_y = mean(y), .groups = "drop")
  sub_anchors = sub_long %>% filter(!is.na(lab)) %>%
    select(site, era, type, anchor_lab = lab, anchor_x = x, anchor_y = y)
  sub_series = series_label_positions %>%
    mutate(type = factor(type, levels = levels(sub_long$type))) %>%
    semi_join(sub_centers, by = c("site", "era", "type")) %>%
    left_join(sub_centers, by = c("site", "era", "type")) %>%
    left_join(sub_anchors, by = c("site", "era", "type", "anchor_lab")) %>%
    mutate(x = coalesce(anchor_x, center_x), y = coalesce(anchor_y, center_y),
      lab = paste0(site, " ",
        if_else(era == "holocene", "Holocene", "Anthropocene"), "\n",
        str_to_title(as.character(type))),
      nx = nx_frac * diff(range(traj_long$x)),
      ny = ny_frac * diff(range(traj_long$y)))
  sub_labels = bind_rows(
    sub_lab_pts %>% transmute(x, y, label = lab, path_color,
      nudge_x = 0, nudge_y = 0, fontface = "plain", label_size = 4),
    add_path_color(sub_series) %>% transmute(x, y, label = lab, path_color,
      nudge_x = nx, nudge_y = ny, fontface = "bold", label_size = 4.6))
  ggplot() +
    geom_hline(yintercept = 0, color = "grey90") + geom_vline(xintercept = 0, color = "grey90") +
    geom_point(data = calib, aes(o1, o2), color = "grey80", size = .6, alpha = .3) +
    geom_point(data = sub_long, aes(x, y, color = path_color), shape = 21, fill = "white",
      size = 2.3, stroke = .8, show.legend = FALSE) +
    geom_segment(data = sub_steps, aes(x, y, xend = xend, yend = yend, color = path_color,
        linetype = type), arrow = arrow(length = unit(.19, "cm"), type = "closed"),
      linewidth = .8, lineend = "round", show.legend = TRUE) +
    geom_text_repel(data = sub_labels, aes(x, y, label = label, color = path_color,
        fontface = fontface, size = label_size),
      nudge_x = sub_labels$nudge_x, nudge_y = sub_labels$nudge_y,
      box.padding = .4, point.padding = .2, force = 2.5, force_pull = 1.5,
      segment.size = .3, segment.color = "grey60", min.segment.length = 0,
      max.overlaps = Inf, max.iter = 200000, max.time = 8, seed = 3, lineheight = .95,
      xlim = zx, ylim = zy, show.legend = FALSE) +
    scale_color_manual(values = path_colors, guide = "none") +
    scale_linetype_manual(values = c(observed = "solid", predicted = "solid"),
      labels = c(observed = "Observed", predicted = "Predicted"), drop = FALSE,
      guide = guide_legend(override.aes = list(color = c("grey25", "grey70"), linewidth = 1.1))) +
    scale_size_identity() + scale_discrete_identity(aesthetics = "fontface") +
    coord_cartesian(xlim = zx, ylim = zy, expand = FALSE) +
    labs(x = ax_lab[1], y = ax_lab[2]) + base_theme +
    theme(legend.text = element_text(size = 15), legend.key.width = unit(2.2, "cm"),
      legend.key.height = unit(.65, "cm"), plot.margin = margin(10, 12, 10, 12))
}
anthropocene_long = traj_long %>% filter(era == "anthropocene")
holocene_endpoints_long = traj_long %>% filter(era == "holocene") %>%
  group_by(grp, type) %>% filter(order %in% range(order)) %>% ungroup()
stopifnot(nrow(holocene_endpoints_long) == 8L)
presentation_trajectories = list(
  fig_cca_trajectories_anthropocene_observed =
    anthropocene_long %>% filter(type == "observed"),
  fig_cca_trajectories_anthropocene = anthropocene_long,
  fig_cca_trajectories_anthropocene_holocene_endpoints =
    bind_rows(anthropocene_long, holocene_endpoints_long))
if (render_figures) {
  dir.create(fig("main", "presentation_figures"), showWarnings = FALSE)
  for (stem in names(presentation_trajectories)) {
    p = trajectory_subset_panel(presentation_trajectories[[stem]])
    ggsave(fig("presentation",  paste0(stem, ".pdf")), p,
      width = 10, height = 8.5, device = cairo_pdf, bg = "white")
    ggsave(fig("presentation",  paste0(stem, ".png")), p,
      width = 10, height = 8.5, dpi = 300, bg = "white")
  }
}

cat("Panel A: all 14 species and four climate constraints; colors encode % constrained inertia.\n",
  "Species annotations give occurrence percentages. Species shares partition 100%; climate values are unique effects.\n",
  "Shared climate fraction:",shared_pct,"%.\n",
  "Panel B: primary equal-lake centroids connected separately from CC1 through S4; unchanged modern paths.\n",
  "Observed and predicted paths are opaque; predicted paths use lighter colors.\n",
  "Trajectory zoom crops",n_out,"of",nrow(calib),"calibration points without removing them from the fit.\n")
