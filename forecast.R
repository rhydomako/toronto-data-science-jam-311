library(forecast, quiet=TRUE)

args <- commandArgs(trailingOnly = TRUE)

input <- args[1]
output <- args[2]

data <- read.csv(args[1])

fit <- auto.arima(data$value)
projection <- forecast(fit)

last_date <- data$date[length(data$date)]
projection_dates = seq(as.Date( last_date ), by = paste (1, "months"), length = length(projection)+1 )[-1]

out <- data.frame(projection_dates, projection$mean, projection$lower[,1], projection$upper[,1])

write.table(out, output, row.names=FALSE, col.names=FALSE, sep=",")
