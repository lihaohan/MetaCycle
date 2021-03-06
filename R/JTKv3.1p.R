#### Associated literature: Michael E. Hughes, John B. Hogenesch, and Karl Kornacker. J Biol Rhythms. 25(5):372-80 (2010).
#### Associated website: http://openwetware.org/wiki/HughesLab:JTK_Cycle
#### Shewchuk algorithms for adaptive precision summation used in jtkdist
#### http://www.cs.cmu.edu/afs/cs/project/quake/public/papers/robust-arithmetic.ps
#### This file has some modification aimed to easily run JTK_CYCLE in the package environment
####======================================================================================================================================
runJTK <- function(indata,JTKtime,minper=20,maxper=28, releaseNote=TRUE, para = FALSE, ncores = 1)
{
	##the internal functions
	fast.two.sum <- function(a,b) {                   # known abs(a) >= abs(b)
	  x <- a+b
	  bv <- x-a
	  y <- b-bv
	  if(y==0) return(x)
	  c(x,y)
	}
	####-----------------------------
	two.sum <- function(a,b) {                        # unknown order
	  x <- a+b
	  bv <- x-a
	  av <- x-bv
	  br <- b-bv
	  ar <- a-av
	  y <- ar+br
	  if(y==0) return(x)
	  c(x,y)
	}
	####-----------------------------
	expansion.sum <- function(g) {
	  g <- g[order(abs(g))]
	  z <- fast.two.sum(g[2],g[1])
	  q <- z[1]
	  h <- NULL
	  if(length(z)!=1) h <- z[2]
	  n <- length(g)
	  if(n==2) return(c(h,q))
	  for(i in 3:n) {
		z <- two.sum(q,g[i])
		q <- z[1]
		if(length(z)!=1) h <- c(h,z[2])
	  }
	  c(h,q)                                          # strongly non-overlapping values
	}
	####-----------------------------
	## Hodges-Lehmann estimator of the median
	hlm <- function(z) {
	  zz <- outer(z,z,"+")
	  zz <- zz[lower.tri(zz,diag=TRUE)]
	  median(zz, na.rm=TRUE)/2			              ###v3.1 ignore missing values
	}
	####-----------------------------
	#### jtkdist: calculate the exact null distribution using the Harding algorithm
	#### http://www.jstor.org/pss/2347656
	###v3.1 modified to provide alternative distributions for data with missing values
	jtkdist <- function(timepoints,reps=1,normal=FALSE,alt=FALSE) {
	  
	  if(length(reps)==timepoints) {
		tim <- reps                                   # support for unbalanced replication
	  } else {
		tim <- rep(reps[1],timepoints)                # balanced replication
	  }
	  
	  maxnlp <- lfactorial(sum(tim))-sum(lfactorial(tim)) #maximum possible negative log p-value
	  limit <- log(.Machine$double.xmax)                  #largest representable nlp
	  normal <- normal | (maxnlp>limit-1)                 #switch to normal approximation if maxnlp is too large
	  
	  if(alt) {
		lab <- paste(sort(tim), collapse=",")
		if(lab %in% names(JTK.ALT)) {
		  alt.id <- match(lab, names(JTK.ALT))
		  return(alt.id)
		}
		nn <- sum(tim)
		M <- (nn^2-sum(tim^2))/2
		JTK.ALT[[lab]] <<- list()
		JTK.ALT[[lab]]$MAX <<- M
		if(normal) {
		  var <- (nn^2*(2*nn+3) - 
			  sum(tim^2*(2*tim+3)))/72
		  JTK.ALT[[lab]]$SDV <<- sqrt(var)
		  JTK.ALT[[lab]]$EXV <<- M/2
		  return(length(JTK.ALT))
		}
	  } else {
		JTK.GRP.SIZE <<- tim                          # sizes of each replicate group
		JTK.NUM.GRPS <<- length(tim)                  # timepoints = number of groups
		JTK.NUM.VALS <- nn <- sum(tim)                ###non-global variable; number of data values (independent of period and lag)
		JTK.MAX <<- M <- (nn^2-sum(tim^2))/2          # maximum possible jtk statistic
		JTK.GRPS <<- rep(1:length(tim), ti=tim)	      ### group labels
		JTK.DIMS <<- c(nn*(nn-1)/2,1)

		if(normal) {
		  JTK.VAR <- (nn^2*(2*nn+3) -                 ###non-global in package
				sum(tim^2*(2*tim+3)))/72              # variance of jtk
		  JTK.SDV <<- sqrt(JTK.VAR)                   # standard deviation of jtk
		  JTK.EXV <<- JTK.MAX/2                       # expected value of jtk
		  JTK.EXACT <<- FALSE
		  return(invisible(0))                        # omit calculation of exact distribution
		}
	  }
	  MM <- floor(M/2)                          	  ### mode of this possibly alternative jtk distribution
	  cf <- as.list(rep(1,MM+1))                      # initial lower half cumulative frequency distribution
		
	  size <- tim                            	      ### sizes of each group of known replicate values
	  size <- size[order(size)]                       # ascending order for fastest calculation
	  k <- length(tim)                                ### number of groups of known replicate values
	  
	  N <- size[k]                  
	  if(k>2) for(i in (k-1):2) {
		N <- c(size[i]+N[1],N)
	  }
	  for(i in 1:(k-1)) {                             # count permutations using the Harding algorithm
		m <- size[i]
		n <- N[i]
		
		if(n < MM) {
		  P <- min(m+n,MM)
		  for(t in (n+1):P) {                         # zero-based offset t
			for(u in 1+MM:t) {                        # one-based descending index u
			  cf[[u]] <- expansion.sum(               # Shewchuck algorithm
				c(cf[[u]],-cf[[u-t]]))
			}
		  }
		}
		Q <- min(m,MM)
		for(s in 1:Q) {                               # zero-based offset s
		  for(u in 1+s:MM) {                          # one-based ascending index u
			cf[[u]] <- expansion.sum(                 # Shewchuck algorithm
			  c(cf[[u]],cf[[u-s]]))
		  }
		}
	  }
	  cf <- sapply(cf,sum)
	  
	  # cf now contains the lower-half cumulative frequency distribution;
	  # append the symmetric upper-half cumulative distribution to cf
	  
	  if(M %% 2) {
		cf <- c(cf,2*cf[MM+1]-c(cf[MM:1],0))          # if M is odd (mode is duplicated)
	  } else {
		cf <- c(cf,cf[MM+1]+cf[MM]-c(cf[MM:2-1],0))   # if M is even (unique mode is in lower half)
	  }
	  jtkcf <- rev(cf)                                # upper-tail cumulative frequencies for all integer jtk
	  ajtkcf <- (jtkcf[-length(cf)]+jtkcf[-1])/2      # interpolated cumulative frequency values for all half-integer jtk  
	  
	  id <- 1+0:(2*M)                           	  ### one-based indices for all jtk values
	  cf <- id                                        # container for the jtk frequency distribution
	  cf[!!id%%2] <- jtkcf                            # odd indices for integer jtk
	  cf[!id%%2] <- ajtkcf                            # even indices for half-integer jtk
	  cp <- cf/jtkcf[1]                               # all upper-tail p-values
	  
	  if(alt) {                                       
		JTK.ALT[[lab]]$CP <<- cp
		return(length(JTK.ALT))
	  }
	  JTK.CP <<- cp
	  JTK.EXACT <<- TRUE
	}
	####-----------------------------
	#### jtk.init: initialize the JTK environment for all periods
	jtk.init <- function(periods, interval=1) {
		  
	  JTK.INTERVAL <<- interval
	  JTK.PERIODS <<- periods
	  JTK.PERFACTOR <<- rep(1:length(periods),ti=periods)
	  
	  tim <- JTK.GRP.SIZE
	  timepoints <- JTK.NUM.GRPS
	  timerange <- 1:timepoints-1                     # zero-based time indices
	  #JTK.CGOOSV <<- list()      
	  #JTK.SIGNCOS <<- list()

	  for(i in 1:length(periods)) {
		period <- periods[i]
		time2angle <- 2*JTK.PIHAT/period              # convert time to angle using an approximate pi value
		theta <- timerange*time2angle                 # zero-based angular values across time indices
		cos.v <- cos(theta)                           # unique cosine values at each timepoint
		cos.r <- rank(cos.v)                          # ranks of unique cosine values
		cos.r <- rep(cos.r,ti=tim)                    # replicated ranks
	  
		cgoos <- sign(outer(cos.r,cos.r,"-"))
		cgoos <- cgoos[lower.tri(cgoos)]
		cgoosv <- array(cgoos,dim=JTK.DIMS)
		JTK.CGOOSV[[i]] <<- matrix(
		  ncol=period,nrow=nrow(cgoosv)
		)
		JTK.CGOOSV[[i]][,1] <<- cgoosv
	  
		cycles <- floor(timepoints/period)		      # v2.1
		range <- 1:(cycles*period)			          # v2.1
		cos.s <- sign(cos.v)[range]                   # signs over all full cycles (v2.1)            
		cos.s <- rep(cos.s,ti=tim[range])
		JTK.SIGNCOS[[i]] <<- matrix(
		  ncol=period,nrow=length(cos.s)
		)
		JTK.SIGNCOS[[i]][,1] <<- cos.s
		
		for(j in 2:period) {                          # one-based half-integer lag index j
		  delta.theta <- (j-1)*time2angle/2           # angles of half-integer lags
		  cos.v <- cos(theta+delta.theta)             # cycle left
		  cos.r <- rank(cos.v)                        # ranks of unique phase-shifted cosine values
		  cos.r <- rep(cos.r,ti=tim)                  # phase-shifted replicated ranks
		
		  cgoos <- sign(outer(cos.r,cos.r,"-"))
		  cgoos <- cgoos[lower.tri(cgoos)]
		  cgoosv <- array(cgoos,dim=JTK.DIMS)
		  JTK.CGOOSV[[i]][,j] <<- cgoosv
		
		  cos.s <- sign(cos.v)[range]
		  cos.s <- rep(cos.s,ti=tim[range])
		  JTK.SIGNCOS[[i]][,j] <<- cos.s    
		}
	  }
	}
	####-----------------------------
	#### jtkstat: calculate the p-values for all (period,phase) combos
	###v3.1 modified to analyze data with missing values
	jtkstat <- function(z) {
	  alt <- any(is.na(z))				              ### flag for handling missing values
	  if(alt) {
		tab <- table(JTK.GRPS[is.finite(z)])
		alt.id <- jtkdist(length(tab),
				  as.integer(tab),
				  alt=alt)
	  }
	  M <- switch(1+alt,			  	              ### maximum possible S score for this distribution
			  JTK.MAX,
			  JTK.ALT[[alt.id]]$MAX)
			  
	  foosv <- sign(outer(z,z,"-"))
	  foosv <- foosv[lower.tri(foosv)]
	  dim(foosv) <- JTK.DIMS
	  
	  JTK.CJTK <- list()                              ###non-global variable for running JTK in package environment
	  for(i in 1:length(JTK.PERIODS)) {
		JTK.CJTK[[i]] <- apply(JTK.CGOOSV[[i]],2,
		  function(cgoosv) {
			S <- sum(foosv*cgoosv, na.rm=TRUE)        ### Kendall's S score ignoring missing values
			if(!S) return(c(1,0,0))
			jtk <- (abs(S)+M)/2                       ### two-tailed JTK statistic for this lag and distribution
			if(JTK.EXACT) {
			  jtki <- 1+2*jtk                         # index into the exact upper-tail distribution
			  p <- switch(1+alt,			 
				  2*JTK.CP[jtki],
				  2*JTK.ALT[[alt.id]]$CP[jtki])
			} else {
			  p <- switch(1+alt,			 
				  2*pnorm(-(jtk-1/2),
				-JTK.EXV,JTK.SDV),
				  2*pnorm(-(jtk-1/2),
				-JTK.ALT[[alt.id]]$EXV,
				JTK.ALT[[alt.id]]$SDV))
			}
			c(p,S,S/M)				                  ### include tau = S/M for this lag and distribution
		})
	  }
	  return(JTK.CJTK)                                ### return JTK.CJTK for easily running JTK in the package
	}
	####-----------------------------
	#### jtkx: integration of jtkstat and jtkdist for repeated use
	jtkx <- function(z, ampci=FALSE, conf=0.8) {      ###v3.1 'ampci=TRUE' for calculating amplitude confidence
	  
	  JTK.CJTK  <- jtkstat(z)                         ###transfer calculated values from 'jtkstat' to 'JTK.CJTK'; calculate p and S for all (period,phase) combos
	  pvals <- lapply(JTK.CJTK,function(cjtk) {
		return(cjtk[1,])
	  })                                              # exact two-tailed p-values for all (period,phase) combos
	  padj <- p.adjust(unlist(pvals),"bonf")          # Bonferroni adjusted two-tailed p-values
	  JTK.ADJP <- min(padj)                           ### non-global variables in package environment; global minimum adjusted p-value
	  
	  padj <- split(padj,JTK.PERFACTOR)
	  minpadj <- sapply(padj,min)                     # minimum adjusted p-value for each period
	  
	  peris <- which(JTK.ADJP==minpadj)               # indices of all optimal periods
	  pers <- JTK.PERIODS[peris]                      # all optimal periods
	  
	  lagis <- lapply(padj[peris],function(z) {
		which(JTK.ADJP==z)
	  })                                              # list of optimal lag indices for each optimal period
	  count <- sum(sapply(lagis,length))              # total number of optimal lags for all optimal period
	  
	  bestper <- 0
	  bestlag <- 0
	  besttau <- 0                                    
	  maxamp <- 0
	  maxamp.ci <- numeric(2)                        
	  maxamp.pval <- 0                              
	  
	  for(i in 1:length(pers)) {
		per <- pers[i]
		peri <- peris[i]
		cjtk <- JTK.CJTK[[peri]]
		sc <- JTK.SIGNCOS[[peri]]
		w <- z[1:nrow(sc)]		    		  
		w <- (w-hlm(w))*JTK.AMPFACTOR	    	  
		
		for(lagi in lagis[[i]]) {  
		  S <- cjtk[2,lagi]                           # optimal Kendall's S
		  s <- sign(S)
		  if(!s) s <- 1
	  
		  lag <- (per +(1-s)*per/4 -(lagi-1)/2)%%per
		  signcos <- sc[,lagi]
		  tmp <- s*w*signcos			             
		  amp <- hlm(tmp)				              ###v3.1 allows missing values
		  if (ampci)                                  ###v3.1 the calculation of amplitude confidence is optimal
		  {
			wt <- wilcox.test(tmp[is.finite(tmp)], 
				  conf.int=TRUE, conf.level=conf, exact=FALSE)
			amp <- as.numeric(wt$estimate)
		  }
		  if(amp > maxamp) {
			  maxamp <- amp
			  bestper <- per
			  bestlag <- lag
			  besttau <- abs(cjtk[3,lagi])            ###v3.1
			  if (ampci)                              ###v3.1
			  {
				maxamp.ci <- as.numeric(wt$conf.int)   
				maxamp.pval <- as.numeric(wt$p.value)
			  }
		  }
		}
	  }
	  JTK.PERIOD <- JTK.INTERVAL*bestper        	  ###non-global variable in package environment; period (hours) with max amp
	  JTK.LAG <- JTK.INTERVAL*bestlag           	  ###non-global; lag (hours) to peak with max amp
	  JTK.AMP <- max(0,maxamp)                	      ###non-global; max amp
	  JTK.TAU <- besttau                              ###non-global; v3.1
	  JTK.AMP.CI <- maxamp.ci				          ###non-global; confidence interval for max amp; 'JTK.AMP.CI' is 'c(0,0)' if 'ampci=FALSE'
	  JTK.AMP.PVAL <- maxamp.pval			          ###non-global; p-value for max amp; 'JTK.AMP.PVAL' is '0' if 'ampci=FALSE'            
	  return(c(JTK.ADJP, JTK.PERIOD, JTK.LAG,         ###return calculated values in package
			   JTK.AMP, JTK.AMP.PVAL, JTK.AMP.CI))    
	}
	####---------------------------------------------------------------
	####variables used by multiple internal functions
	##jtkdist global variables
	JTK.GRP.SIZE <- JTK.NUM.GRPS <- JTK.MAX <- JTK.DIMS <- JTK.GRPS <- NULL
	JTK.SDV <- JTK.EXV <- JTK.EXACT <- JTK.CP <- NULL
	##jtk.init global variables
	JTK.INTERVAL <- JTK.PERIODS <- JTK.PERFACTOR <- NULL
	JTK.CGOOSV <- JTK.SIGNCOS <- list()
	JTK.ALT <- list()				                  ###v3.1 container for alternative distributions
	##two pre-defined values used by internal functions
	JTK.AMPFACTOR <- sqrt(2)                          # 1/median(abs(cosine)) used to calculate amplitudes
	JTK.PIHAT <- round(pi,4)                          # replacement for pi to ensure unique cos values
	####---------------------------------------------------------------
	####run multiple functions
	if (releaseNote) {
		cat("The JTK is in process from ",format(Sys.time(), "%X %m-%d-%Y"),"\n");
	}
	##check period range in search
	##JTKtime is already sorted in 'meta2dMainF.R'
	uni_JTKtime <- unique(JTKtime);	
	freq <- uni_JTKtime[2] - uni_JTKtime[1];
	data_endtime <- length(uni_JTKtime)*freq;
	if ( (data_endtime >= maxper) & ( round(maxper/freq) >= 2) ) {
		if (round(minper/freq) >= 2){
			perTK <- seq(round(minper/freq),round(maxper/freq),by=1);
		} else {
			perTK <- seq(2,round(maxper/freq),by=1);
		}
	} else if ( (data_endtime < maxper) & (data_endtime >= minper) & ( round(data_endtime/freq) >= 2 ) ) {
		if (round(minper/freq) >= 2) {
			perTK <- seq(round(minper/freq),round(data_endtime/freq),by=1);
		} else {
			perTK <- seq(2,round(data_endtime/freq),by=1);
		}
	} else {
		stop(c("The input 'minper' and 'maxper' is out of the range that JTK can detect.", 
		       "If hope to use JTK for this analysis, please reset the 'minper' ", 
			   "and 'maxper' between ", 2*freq, " and ", data_endtime, ".\n"));
	}
	if ( (min(perTK)*freq != minper) & (releaseNote) )
  {  cat(c("Warning: the input 'minper' is not suitable for JTK, it was reset as ", min(perTK)*freq, "\n"));  }
  if ( (max(perTK)*freq != maxper) & (releaseNote) )
  {  cat(c("Warning: the input 'maxper' is not suitable for JTK, it was reset as ", max(perTK)*freq, "\n"));  }
	##read-in data
	options(stringsAsFactors=FALSE);
	data <- indata;
	idorder <- dimnames(data)[[1]];
	outID <- as.character(data[,1]);           
	names(outID) <- idorder;
	data <- data[,-1];
	##get number of replicates at each time point
	jtk_replicates <- table(JTKtime);
	if ( ( length(jtk_replicates) == length(uni_JTKtime) )  &
	     ( all(names(jtk_replicates) == as.character(uni_JTKtime)) ) ) {
    ##get the initial distribution 
		jtkdist(length(uni_JTKtime),as.numeric(jtk_replicates));
		periods <- perTK;                  
		jtk.init(periods,freq); 
		flush.console();
		##analyze input data
		if (para){
		  data_rows <- mclapply(as.list(1:dim(data)[1]), function(x) {data[x[1],]}, mc.cores = ncores )
		  res <- mcmapply(
		    function(z) {
		      outz <- jtkx(unlist(z));
		      return(outz[1:4]);
		    },data_rows, mc.cores = ncores
		  )
		  rm(data_rows);
		}else{
		  res <- apply(data,1,function(z) {
		    outz <- jtkx(z);
		    return(outz[1:4]);
		  })
		}
		##return results
		JTKoutM <- t(res);
		bhq <- p.adjust(JTKoutM[,1],"BH");
		JTKoutM <- cbind(outID, bhq, JTKoutM);	       
		rownames(JTKoutM) <- idorder;
		colnames(JTKoutM) <- c("CycID","BH.Q","ADJ.P","PER","LAG","AMP");
		if (releaseNote)  {
			cat("The analysis by JTK is finished at ", format(Sys.time(), "%X %m-%d-%Y"),"\n");
		}
		return(JTKoutM);
	}  else  {
		stop("There is a bug in 'runJTK()', please contact the author.\n");
	}
}