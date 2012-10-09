#' Estimates models with increasing number of comparision subjects increasing from
#' 1:1 to using all comparison groups.
#' 
#' @param df data frame with variables to pass to glm
#' @param treatvar vector representing treatment placement. Should be coded as
#'        0s (for control) and 1s (for treatment).
#' @param formula formula for logistic regression model
#' @param nsteps number of steps to estimate from 1:1 to using all control records.
#' @param nboot number of models to execute for each step.
#' @return a class of psrange that contains a summary data frame, a details data
#'         frame, and a list of each individual result from glm.
#' @export
psrange <- function(df, treatvar, formula, nsteps=10, nboot=10,
					samples=(seq(0,1,1/nsteps) * 
						(length(which(treatvar==0)) - 2*length(which(treatvar==1))) + 
						length(which(treatvar==1))) ) {
	results <- list()
	
	ncontrol <- length(which(treatvar == 0))
	ntreat <- length(which(treatvar == 1))
	#ndiff <- ncontrol - ntreat
	dfrange <- data.frame(p=integer(), i=integer(),
						 ntreat=integer(), ncontrol=integer(), 
						 psmin=numeric(), psmax=numeric())
	pb <- txtProgressBar(min=1, max=(length(samples)*nboot), style=3)
	for(i in 1:length(samples)) {
		tosample <- samples[i]
		#models[[i]] <- list()
		for(j in 1:nboot) {
			rows <- c(which(treatvar == 1),
					 sample(which(treatvar == 0), tosample))
			lr.results <- glm(formula, data=df[rows,], family='binomial')
			dfrange <- rbind(dfrange, data.frame(ind=i, p=tosample/ncontrol*100, i=j,
												ntreat=ntreat, ncontrol=tosample, 
												psmin=range(fitted(lr.results))[1],
												psmax=range(fitted(lr.results))[2]))
			#models[[i]][j] <- lr.results
			setTxtProgressBar(pb, (((i-1)*nboot) + j))
		}
	}
	#results$models <- models
	dfrange$ratio <- dfrange$ncontrol / dfrange$ntreat
	results$details <- dfrange
	smin <- describeBy(dfrange$psmin, group=dfrange$p, mat=TRUE)[,
							c('mean','sd','median','se','min','max')]
	names(smin) <- paste('min', names(smin), sep='.')
	smax <- describeBy(dfrange$psmax, group=dfrange$p, mat=TRUE)[,
							c('mean','sd','median','se','min','max')]
	names(smax) <- paste('max', names(smax), sep='.')
	results$summary <- cbind(dfrange[!duplicated(dfrange$p),c('p','ntreat','ncontrol','ratio')],
							 smin, smax)
	class(results) <- c('psrange')
	return(results)
}

#' Prints the summary results of psrange.
#' 
#' @param object psrange to print summary of.
#' @param ... currently unused.
#' @export
summary.psrange <- function(object, ...) {
	return(object$summary)
}

#' Plots the results of psrange call with ggplot2 displaying the range of fitted
#' values (i.e. propensity scores).
#' 
#' @param x a psrange object
#' @param xlab label for the x axis
#' @param ylab label for the y axis
#' @param ... currently unused.
#' @export
plot.psrange <- function(x, 
						 xlab='Percentage of Control Group',
						 ylab=paste('Propensity Score Range (ntreat = ', 
									prettyNum(x$summary[1,'ntreat'], big.mark=','), ')', sep=''),
						 text.ratio.size=5,
						 text.ncontrol.size=3,
						 point.size=1, point.alpha=.6,
						 ...) {
	text.vjust <- -.4
	p <- ggplot(x$summary, aes(x=p)) + 
		geom_errorbar(aes(ymin=min.mean, ymax=max.mean), colour='blue') + 
		geom_jitter(data=x$details, aes(x=p, y=psmin), size=point.size, alpha=point.alpha) +
		geom_jitter(data=x$details, aes(x=p, y=psmax), size=point.size, alpha=point.alpha) +
		geom_text(aes(label=paste(prettyNum(floor(ncontrol), big.mark=','), sep='')), 
					  y=min(x$summary$min.min)-.01, size=text.ncontrol.size, hjust=1.1, vjust=.5) +
		geom_text(aes(label=paste('1:', round(ratio, digits=1), sep=''), 
					  y=((max.mean-min.mean)/2)), size=text.ratio.size, vjust=text.vjust) +
	  	coord_flip() + ylim(c(-.05,1)) + 
	  	#geom_hline(yintercept=0) + geom_hline(yintercept=1) +
	  	ylab(ylab) + xlab(xlab)
	return(p)
}
