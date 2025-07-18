get_chelsa_data = function(coords, variable, time_period = "present", 
                           start_date = NULL, end_date = NULL, 
                           output_dir = "output") {
  
  # Ensure coords is a data frame with lon, lat columns
  coords = as.data.frame(coords)
  
  # Create output directory if it doesn't exist
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  if (time_period == "paleo") {
    # For paleo data: start_date and end_date should be vectors c(month, year_ka)
    # e.g., c(1, -60) for January 60ka BP, c(12, 19) for December 19ka BP
    if (is.null(start_date) || is.null(end_date)) {
      stop("For paleo data, provide start_date and end_date as c(month, year_ka)")
    }
    
    data = getChelsa(variable, coords = coords, 
                     startdate = start_date, enddate = end_date, 
                     freq = "centennial", version = "chelsa_trace21k")
    
    filename = paste0(output_dir, "/", variable, "_paleo_", 
                      start_date[2], "to", end_date[2], "ka.csv")
    
  } else if (time_period == "present") {
    # For present data: dates as Date objects or character strings
    if (is.null(start_date)) start_date = as.Date("1981-1-1")
    if (is.null(end_date)) end_date = as.Date("2020-12-31")
    
    data = getChelsa(variable, coords = coords, 
                     startdate = start_date, enddate = end_date, 
                     freq = "daily")
    
    filename = paste0(output_dir, "/", variable, "_present.csv")
    
  } else {
    stop("time_period must be either 'paleo' or 'present'")
  }
  
  # Save data
  write.csv(data, file = filename, row.names = FALSE)
  
  # Return the data
  return(data)
}