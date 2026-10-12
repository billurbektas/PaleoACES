# Stream calculation records from completed checkpoints without holding all
# realization geometry or contributions in memory. These are audit records.
export_chronology_records=function(out,kind) {
  paths=file.path(out,'chronology_batches',sprintf('draw_%04d.rds',1:1000))
  if(!all(file.exists(paths))) stop('Cannot export incomplete chronology records')
  target=file.path(out,if(kind=='community') 'transition_calculations.csv.gz' else 'species_contributions.csv.gz')
  temporary=paste0(target,'.pending')
  con=gzfile(temporary,open='wt',compression=6)
  total=0L;signature=NULL
  tryCatch({
    for(i in seq_along(paths)) {
      saved=readRDS(paths[i])
      if(i==1L) signature=saved$signature else if(!identical(signature,saved$signature))
        stop('Mixed chronology checkpoint signatures')
      x=if(kind=='community') saved$calculations else saved$species
      if(any(x$draw!=i) || anyNA(x$draw)) stop('Incorrect realization draw identity')
      write.table(x,con,sep=',',row.names=FALSE,col.names=i==1L,quote=TRUE,na='NA')
      total=total+nrow(x)
    }
  },finally=close(con))
  if(!file.rename(temporary,target)) stop('Cannot publish chronology records')
  cat('Published',total,kind,'chronology calculation records.\n')
}
