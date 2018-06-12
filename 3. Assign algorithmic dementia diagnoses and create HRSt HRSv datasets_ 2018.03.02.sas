libname adams 'F:\power\HRS\ADAMS Wave A';
libname atrk 'F:\power\HRS\ADAMS CrossWave';
libname x 'F:\power\HRS\DerivedData\AD_Disparities_AlgorithmDev\Data 2018_0105'; /*derived hrs files*/
libname hrs 'F:\power\HRS\HRS data (raw)\SAS datasets'; /*raw hrs files, including Hurd probabilities*/
libname rand 'F:\power\HRS\RAND_HRS\sasdata';
libname xold 'F:\power\HRS\DerivedData\AD_Disparities_AlgorithmDev';
options fmtsearch = (rand.formats);

*set date for output label;
%let pdt=2018_0117;
%let dt=2018_0302;

/*********************************************************************************************
* Created 2018.01.17 
*
* 1) Predict dementia status 
*		- Use cognitive score cut-offs to assign dementia for HW & LKW 98-08, and probabilities provided for Hurd 98-06 
*			- Assign Hurd/HW/LKW dementia status for each wave based on useyear
*			- Two versions for LKW: dementia vs. no dementia; dementia vs. CIND vs. normal 
*		- Fit Wu & Crimmins algorithms to obtain probabilities; 
*			- use 0.5 probability threshold as classification rule 
			- UPDATED for Crimmins to (1) ignore CIND among self-response; and (2) drop Model 4 (with Jorm) for proxies
*		- NOTE: Hurd year 2008 predictions not available
*			- affects 161 out of 217 of Wave D respondents
*
* 2) Create two datasets:
*		- HRSt: training data using ADAMS Wave A
*		- HRSv: validation data using ADAMS Waves B, C, D 
*		- Use newly created "commsampfinal_key" (which accounts for observations with missing Hurd algorithm predictors)
* 
**********************************************************************************************/

data pred; set x.master_ad_&pdt; run;
/************************************************************
*
*	1. Determine dementia Dx for 
*
*************************************************************/

/*Hurd - used transposed probabilities (only avaailable up to 2006)
************for now use threshold of 0.5 */

/* LKW not available for 1998 proxy respondents due to lack of iwercog variable in 1998 HRS*/

data pred; 
	merge pred (in = a) x.hurdprobabilities_wide;
	by hhid pn;
	if a;
run;


/*1998: no proxy for LKW  only*/

%macro dem(py, y);
data pred; set pred;	
/*Hurd*/
************for now use threshold of 0.5;
	if hurd_prob_&py > 0.5 then hurd_dem_&y = 1;
	else if hurd_prob_&py NE . then hurd_dem_&y = 0;
	label hurd_dem_&y = "Hurd dementia Dx using 0.5 threshold from probabilities provided by authors y&y";

	if proxy_&y = 0 then do;
	/*Herzog-Wallace*/
		if 0 le cogtot_&y le 8 then hw_dem_&y = 1;
		else if 9 le cogtot_&y le 35 then hw_dem_&y = 0;
		label hw_dem_&y = "Herzog-Wallace dementia : self-resp use <9 on 0-35 cognition; proxy use 2+ jorm symptoms, y&y";
	/*Langa-Kabeto-Weir*/
		if 0 le cogsc27_&y le 6 then do; lkw_dem_&y = 1; lkw_cogn_&y = 3; end;
		else if 7 le cogsc27_&y le 11 then do; lkw_dem_&y = 0; lkw_cogn_&y = 2; end;
		else if cogsc27_&y NE . then do; lkw_dem_&y = 0; lkw_cogn_&y = 1; end;
		label lkw_dem_&y = "Langa-Kabeto-Weir dementia Dx: self-resp use <7 on 0-27 cognition; proxy use 6+ on 11-pt scale (prmem, iwercog, iadl), y&y";
		label lkw_cogn_&y = "Langa-Kabeto-Weir cognition Dx: 1=normal(12-27  self, 0-2 proxy), 2=CIND(7-11 self, 3-5 proxy), 3=dementia(0-6 self, 6-11 proxy), y&y";
	end;

	if proxy_&y = 1 then do;
	/*Herzog-Wallace*/
		hw_dem_&y = jormsymp2_&y;
	end;
run;
%mend;
%dem(1999, 98)


%macro dem(py, y);
data pred; set pred;	
/*Hurd*/
************for now use threshold of 0.5;
	if hurd_prob_&py > 0.5 then hurd_dem_&y = 1;
	else if hurd_prob_&py NE . then hurd_dem_&y = 0;
	label hurd_dem_&y = "Hurd dementia Dx using 0.5 threshold from probabilities provided by authors y&y";

	if proxy_&y = 0 then do;
	/*Herzog-Wallace*/
		if 0 le cogtot_&y le 8 then hw_dem_&y = 1;
		else if 9 le cogtot_&y le 35 then hw_dem_&y = 0;
		label hw_dem_&y = "Herzog-Wallace dementia : self-resp use <9 on 0-35 cognition; proxy use 2+ jorm symptoms, y&y";
	/*Langa-Kabeto-Weir*/
		if 0 le cogsc27_&y le 6 then do; lkw_dem_&y = 1; lkw_cogn_&y = 3; end;
		else if 7 le cogsc27_&y le 11 then do; lkw_dem_&y = 0; lkw_cogn_&y = 2; end;
		else if cogsc27_&y NE . then do; lkw_dem_&y = 0; lkw_cogn_&y = 1; end;
		label lkw_dem_&y = "Langa-Kabeto-Weir dementia Dx: self-resp use <7 on 0-27 cognition; proxy use 6+ on 11-pt scale (prmem, iwercog, iadl), y&y";
		label lkw_cogn_&y = "Langa-Kabeto-Weir cognition Dx: 1=normal(12-27  self, 0-2 proxy), 2=CIND(7-11 self, 3-5 proxy), 3=dementia(0-6 self, 6-11 proxy), y&y";
	end;

	if proxy_&y = 1 then do;
	/*Herzog-Wallace*/
		hw_dem_&y = jormsymp2_&y;
	/*Langa-Kabeto-Weir*/
		if 6 le (pr_memsc1_&y + iadl5_&y + iwercog_&y) le 11 then do; lkw_dem_&y = 1; lkw_cogn_&y = 3; end;
		else if 3 le (pr_memsc1_&y + iadl5_&y + iwercog_&y) le 5 then do; lkw_dem_&y = 0; lkw_cogn_&y = 2; end;
		else if 0 le (pr_memsc1_&y + iadl5_&y + iwercog_&y) le 2 then do; lkw_dem_&y = 0; lkw_cogn_&y = 1; end;
	end;
run;
%mend;
%dem(2001, 00) %dem(2003, 02) %dem(2005, 04) %dem(2007, 06)


%macro dem(y);
data pred; set pred;	
	if proxy_&y = 0 then do;
	/*Herzog-Wallace*/
		if 0 le cogtot_&y le 8 then hw_dem_&y = 1;
		else if 9 le cogtot_&y le 35 then hw_dem_&y = 0;
		label hw_dem_&y = "Herzog-Wallace dementia : self-resp use <9 on 0-35 cognition; proxy use 2+ jorm symptoms, y&y";
	/*Langa-Kabeto-Weir*/
		if 0 le cogsc27_&y le 6 then do; lkw_dem_&y = 1; lkw_cogn_&y = 3; end;
		else if 7 le cogsc27_&y le 11 then do; lkw_dem_&y = 0; lkw_cogn_&y = 2; end;
		else if cogsc27_&y NE . then do; lkw_dem_&y = 0; lkw_cogn_&y = 1; end;
		label lkw_dem_&y = "Langa-Kabeto-Weir dementia Dx: self-resp use <7 on 0-27 cognition; proxy use 6+ on 11-pt scale (prmem, iwercog, iadl), y&y";
		label lkw_cogn_&y = "Langa-Kabeto-Weir cognition Dx: 1=normal(12-27  self, 0-2 proxy), 2=CIND(7-11 self, 3-5 proxy), 3=dementia(0-6 self, 6-11 proxy), y&y";
	end;

	if proxy_&y = 1 then do;
	/*Herzog-Wallace*/
		hw_dem_&y = jormsymp2_&y;
	/*Langa-Kabeto-Weir*/
		if 6 le (pr_memsc1_&y + iadl5_&y + iwercog_&y) le 11 then do; lkw_dem_&y = 1; lkw_cogn_&y = 3; end;
		else if 3 le (pr_memsc1_&y + iadl5_&y + iwercog_&y) le 5 then do; lkw_dem_&y = 0; lkw_cogn_&y = 2; end;
		else if 0 le (pr_memsc1_&y + iadl5_&y + iwercog_&y) le 2 then do; lkw_dem_&y = 0; lkw_cogn_&y = 1; end;
	end;
%mend;
%dem(08) ;

/**/
/*proc means data=pred;*/
/*	var hurd_prob_2007; where hurd_dem_06 = 0;*/
/*run;*/
/*proc means data=pred;*/
/*	var hurd_prob_2007; where hurd_dem_06 = 1;*/
/*run;*/
/*proc freq;*/
/*	tables cogtot_98 hw_dem_98 cogsc27_98 lkw_dem_98; where proxy_98 = 0;*/
/*run;*/
/*proc freq;*/
/*	tables jormsymp2_08 hw_dem_08  lkw_dem_08; where proxy_08 = 1;*/
/*run;*/

/*Assign dementia status to each wave for Hurd/HW/LKW*/
%macro dem(w, y, py);
data pred; set pred;
if useyear_&w = 20&y then do;
	hurd_p_&w = hurd_prob_&py; label hurd_p_&w = "Hurd dementia probability (from authors), wave &w";
	hurd_dem_&w = hurd_dem_&y; label hurd_dem_&w = "Hurd dementia classification, wave &w";
	hw_dem_&w = hw_dem_&y; label hw_dem_&w = "Herzog-Wallace dementia classification, wave &w";
	lkw_dem_&w = lkw_dem_&y; label lkw_dem_&w = "Langa-Kabeto-Weir dementia classification, wave &w";
	lkw_cogn_&w = lkw_cogn_&y; label lkw_cogn_&w = "Langa-Kabeto-Weir cognition classification (1=normal, 2=CIND, 3=dementia), wave &w";
end;
run;
/*proc freq; tables dement_&w*(hurd_dem_&w hw_dem_&w lkw_dem_&w);*/
/*run;*/
%mend;

%dem(A, 00, 2001) %dem(A, 02, 2003);
%dem(B, 02, 2003) %dem(B, 04, 2005);
%dem(C, 04, 2005) %dem(C, 06, 2007);
%dem(D, 06, 2007) %dem(D, 08, 2009); 
data pred; set pred (drop = hurd_dem_08 hurd_prob_2009); run; /*Hurd probability not provided for 2008*/

/*proc means data=pred; var hurd_p_a hurd_p_b hurd_p_c hurd_p_d; run;*/

/************************************************************
*
*	1. Fit Wu algorithm & determine dementia classification
*
*************************************************************/

%macro wu (w);
data pred; set pred;
	wu_or_&w = exp(4.608 + 1.889*proxy_&w + 0.933*iword_&w - 0.266*iwordsq_&w - 0.797*dword_&w - 1.075*tics13_&w + 0.043*tics13sq_&w + 2.220*iqcode5_&w + 1.096*pr_memsc5_&w 
					 - 0.854*male + 0.095*hrs_age70_&w - 0.695*black + 0.543*dword_m_&w + +1.551*iqcode5_m_&w);
	wu_p_&w = wu_or_&w/(1 + wu_or_&w);

	if wu_p_&w > 0.5 then wu_dem_&w = 1;
	else if wu_p_&w NE . then wu_dem_&w = 0;

	label wu_or_&w = "Wu Dementia odds ratio, wave &w";
	label wu_p_&w = "Wu Dementia probability, wave &w";
	label wu_dem_&w = "Wu Dementia classification, wave &w";
proc freq;
	tables dement_&w*wu_dem_&w;
	*where proxy_&w = 1;
run;
%mend;

%wu(A)%wu(B)%wu(C)%wu(D)

/************************************************************
*
*	2. Fit Crimmins algorithm & determine dementia classification
*
*************************************************************/
/*Fit Crimmins algorithm and determine dementia status:*/
 
%macro crim(w);
data pred; set pred;
*SELF-RESPONSE (use ticshrs score out of 10);
if proxy_&w = 0 then do;
	crim_ors_&w = exp(-8.3247 + log(1.2)*hrs_age_&w + log(1.02)*female + log(0.36)*lowedu_crim + log(0.45)*midedu_crim 
						 + log(0.73)*iword_&w + log(0.65)*dword_&w + log(0.68)*serial7_&w + log(0.6)*ticshrs_&w
						 + log(0.33)*dress_&w + log(1.30)*bath_&w + log(4.34)*eat_&w + log(9.72)*money_&w + log(2.38)*phone_&w);
	crim_ps_&w = crim_ors_&w/(1 + crim_ors_&w);
	if crim_ps_&w > 0.5 then crim_dems_&w = 1;
	else if crim_ps_&w NE . then crim_dems_&w = 0;

	label crim_ors_&w = "Crimmins Dementia odds ratio for self-respondent using HRS TICS (0-10), wave &w";
	label crim_ps_&w = "Crimmins Dementia probability for self-respondent using HRS TICS (0-10), wave &w";
	label crim_dems_&w = "Crimmins Dementia classification for self-respondent using HRS TICS (0-10), wave &w";
end;

*PROXY (use model 3 - no Jorm);
if proxy_&w = 1 then do;
	crim_orp_&w = exp(-2.3448 + log(2.39)*pr_memsc1_&w + log(1.45)*iadl5_&w + log(1.37)*iwercog_&w);
	crim_pp_&w = crim_orp_&w/(1 + crim_orp_&w);
	if crim_pp_&w > 0.5 then crim_demp_&w = 1;
	else if crim_pp_&w NE . then crim_demp_&w = 0;

	label crim_orp_&w = "Crimmins Dementia odds ratio for proxies using model 3 (no Jorm), wave &w";
	label crim_pp_&w = "Crimmins Dementia probability for proxies using model 3 (no Jorm), wave &w";
	label crim_demp_&w = "Crimmins Dementia classification for proxies using model 3 (no Jorm), wave &w";
end;

*Consolidate self-response and proxy;
	if crim_dems_&w NE . then crim_dem_&w = crim_dems_&w;
	if crim_demp_&w NE . then crim_dem_&w = crim_demp_&w;

	if crim_ps_&w NE . then crim_p_&w = crim_ps_&w;
	if crim_pp_&w NE . then crim_p_&w = crim_pp_&w;

	proc freq; tables crim_dem_&w*dement_&w;
run;
%mend;
%crim(A) %crim(B) %crim(C) %crim(D) 

/*check cross-wave dementia diagnosis*/
/*proc freq data=pred;*/
/*	tables dement_a*dement_b dement_a*dement_c dement_b*dement_c dement_b*dement_d dement_c*dement_d;*/
/*run;*/
/*
Create exclude_b & exclude_c variables for confusion tables
	- If Dx'ed dementia in Wave A and re-assessed in Wave B then exclude from Wave B (N=24);
	- If Dx'ed dementia in Wave C and re-assessed in Wave D then exclude from Wave D (N=2);
*/
/**/
/*proc freq data=pred; tables dement_c; *where dfresult = 1; run;*/
data pred; set pred;
	if bfresult = 1 and dement_a = 1 then exclude_b = 1;
	if dfresult = 1 and dement_c = 1 then exclude_d = 1;
	exclude_a = .;
	exclude_c = .;
/*proc freq;*/
/*	tables exclude_b exclude_d; */
run;


/*create common sample flag
	- commsampfinal_&w: non-missing for all algorithmic classifications (HW, LKW, Wu, Crimmins, Hurd) and non-missing Hurd predictors
*/
%macro comm(w);
data pred; set pred;
	if hw_dem_&w NE . and lkw_dem_&w NE . and crim_dem_&w NE . and wu_dem_&w NE . and hurd_dem_&w NE . and 
       hagecat_&w NE . and	midedu_hurd NE . and female NE . and adl5_&w NE . and iadl5_&w NE . and adl5ch_&w NE . and iadl5ch_&w NE . then do;

			if proxy_&w = 0 then do;
				if  dates_&w NE . and ticscount1_&w NE . and serial7_&w NE . and scis_&w NE . and cact_&w NE . and pres_&w NE . and iword_&w NE . and dword_&w NE . and
				datesch_&w NE . and ticscount1ch_&w NE . and serial7ch_&w NE . and scisch_&w NE . and cactch_&w NE . and presch_&w NE . and iwordch_&w NE . and dwordch_&w NE . 
				then commsampfinal_&w = 1;
			end;

			if proxy_&w = 1 then do;
				if iqcode_&w NE . and proxylag_&w NE . and iqcodech_&w NE . and dateslag_&w NE . and serial7lag_&w NE . and preslag_&w NE . and iwordlag_&w NE . and dwordlag_&w NE .
				then commsampfinal_&w = 1;
			end;
	end;

	proc freq; tables commsampfinal_&w; run;
run;
%mend;
%comm(a) %comm(b) %comm(c) %comm(d)

/*save keys*/
data x.commsampfinal_key; set pred (keep = hhid pn commsampfinal_a commsampfinal_b commsampfinal_c commsampfinal_d); run;
	

/*save to drive*/
data x.Master_adpred_wide_&dt; set pred; run;

/***********************************************************
* 	Create Training and Validation Samples
************************************************************/

*only keep relevant data for confusion tables;
data small; set pred;
keep 	hhid pn	
		hw_dem_a	hw_dem_b	hw_dem_c	hw_dem_d 
		lkw_dem_a	lkw_dem_b	lkw_dem_c	lkw_dem_d
		lkw_cogn_a 	lkw_cogn_b	lkw_cogn_c	lkw_cogn_d	
		crim_dem_a  crim_dem_b	crim_dem_c	crim_dem_d
		crim_p_a 	crim_p_b 	crim_p_c 	crim_p_d
		hurd_dem_a 		hurd_dem_b	hurd_dem_c	hurd_dem_d
		hurd_p_a 		hurd_p_b	hurd_p_c	hurd_p_d
		wu_dem_a		wu_dem_b	wu_dem_c	wu_dem_d
		wu_p_a			wu_p_b		wu_p_c		wu_p_d
		dement_a 	dement_b 	dement_c 	dement_d 
		cogn_a		cogn_b		cogn_c		cogn_d
		proxy_a 	proxy_b 	proxy_c 	proxy_d
		exclude_a	exclude_b	exclude_c	exclude_d
		commsampfinal_a  commsampfinal_b  commsampfinal_c  commsampfinal_d
		hrs_age_a	hrs_age_b	hrs_age_c	hrs_age_d
		raceeth4 	NH_white	NH_black	NH_other	hispanic
		edu_hurd	edu_crim	male		female;
run;	

*go from wide->long dataset;
%macro small(w);
*rename for stacking;
data small_&w; set small;
	rename dement_&w = dement;
	rename cogn_&w = cogn;
	rename proxy_&w = proxy;
	rename hrs_age_&w = hrs_age;
	rename hw_dem_&w = hw_dem;
	rename lkw_dem_&w = lkw_dem;
	rename lkw_cogn_&w = lkw_cogn;
	rename crim_dem_&w = crim_dem;
	rename crim_p_&w = crim_p;
	rename hurd_dem_&w = hurd_dem;
	rename hurd_p_&w = hurd_p;
	rename wu_dem_&w = wu_dem;
	rename wu_p_&w = wu_p;

data small_&w; set small_&w;
*exclude if ineligible;
	if commsampfinal_&w = 1;
	if exclude_&w NE 1;
*create wave indicator;
	ADAMSwave = "&w";

	keep 	hhid 	pn			ADAMSwave
		dement 		cogn		proxy 		hrs_age 	
		hw_dem		lkw_dem		hurd_dem	wu_dem
		crim_dem 	hurd_p		wu_p		crim_p 
		raceeth4 	NH_white	NH_black	NH_other	hispanic
		edu_hurd	edu_crim	male		female;
run;
%mend;
%small(a); %small(b); %small(c); %small(d); 

*training data;
data x.HRSt_&dt; set small_a; 
*create edu vars for subgroups;
ltHS = .; geHS=.;
if edu_hurd = 0 then do;
	ltHS=1; geHS=0;
	end;
else if edu_hurd in (1,2) then do;
	ltHS=0; geHS=1;
	end;

*create age vars for subgroups;
lt80 = .; ge80=.;
if hrs_age<80 & hrs_age ne . then do;
	lt80=1; ge80=0;
	end;
else if hrs_age ge 80 & hrs_age ne . then do;
	lt80=0; ge80=1;
	end;
run;

data x.HRSv_&dt; set small_b small_c small_d; 
*create edu vars for subgroups;
ltHS = .; geHS=.;
if edu_hurd = 0 then do;
	ltHS=1; geHS=0;
	end;
else if edu_hurd in (1,2) then do;
	ltHS=0; geHS=1;
	end;

*create age vars for subgroups;
lt80 = .; ge80=.;
if hrs_age<80 & hrs_age ne . then do;
	lt80=1; ge80=0;
	end;
else if hrs_age ge 80 & hrs_age ne . then do;
	lt80=0; ge80=1;
	end;
proc freq; tables ADAMSwave; 
run;

*get Ns for proxy, ADAMS dementia, and overall;
proc freq data=x.HRSt_&dt;
tables proxy dement;
run;

proc freq data=x.HRSv_&dt;
tables proxy dement;
run;
