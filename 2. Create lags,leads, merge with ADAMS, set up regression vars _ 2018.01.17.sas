libname adamsa 'F:\power\HRS\ADAMS Wave A';
libname adamsb 'F:\power\HRS\ADAMS Wave B';
libname atrk 'F:\power\HRS\ADAMS CrossWave';
libname x 'F:\power\HRS\DerivedData\AD_Disparities_AlgorithmDev\Data 2018_0105'; /*derived hrs files*/
libname hrs 'F:\power\HRS\HRS data (raw)\SAS datasets'; /*raw hrs files, including Hurd probabilities*/
libname rand 'F:\power\HRS\RAND_HRS\sasdata'; /*RAND version P*/
options fmtsearch = (rand.formats);

*set date for output label;
%let dt=2018_0117;

/*********************************************************************************************
* Created for compiling final standardized dataset, to be divided into "training" and "validation" datasets
*	Compiles/creates variables for simple imputation of proxy data (per Wu) and 1-back status (for Hurd)
*	Adds ADAMS data
*	Calculates algorithmic dementia diagnosis for Wu & Crimmens
*
* 1) Create variable leads and lags
*		- no need to create leads/lags for iword/dword/tics - no missing values due to imputations in RAND
*		- create leads lags for proxy items (IQCODE, proxy memory)
* 2) Create proxy 2 waves prior dummy for Hurd; Create lag TICS for self-response->proxy obs
* 3) Merge to ADAMS subset and set up regrsesion variables for Wu and Crimmins
*		- did not set-up Hurd variables for now b/c probabilities are available and merged in
* 
**********************************************************************************************/


*read in wide data created in 1a and 1b code;
data master; set x.master_&dt; run;


/************************************************************
*
*	1. Create lead/lag variables for simple impuation and 1-back variables
*
*************************************************************/

/* 
Create lead/lag proxy cognition scores to use for imputing missing values
		- procedure used by Wu (in Memory and dementia probability score model _April 2013) for both self-respondent and proxy misisngs 
		- use procedure for misisng proxy cognition variables for Wu/Crimmins/Wu
			- (RAND already has imputations for missing self-response, so do not need to apply logic to these)
*/

%macro ll(c, b, f);
	data master; set master;
	/*Wu: IQCODE, IQCODExMale, ProxyMem*/
		iqcode5lag_&c = iqcode5_&b; label iqcode5lag_&c = "prior wave IQCODE, ctrd at 5: -4(much better) to 0(worse), y&c";
		iqcode5lead_&c = iqcode5_&f; label iqcode5lead_&c = "next wave IQCODE, ctrd at 5: -4(much better) to 0(worse), y&c";
		iqcode5_mlag_&c = iqcode5_m_&b; label iqcode5_mlag_&c = "prior wave IQCODE (ctrd at 5) * male interaction, y&c";
		iqcode5_mlead_&c = iqcode5_m_&f; label iqcode5_mlead_&c = "next wave IQCODE (ctrd at 5) * male interaction, y&c";
		pr_memsc5lag_&c = pr_memsc5_&b; label pr_memsc5lag_&c = "prior wave proxy mem score ctrd at 5: -4(excellent) to 0(poor), y&c";
		pr_memsc5lead_&c = pr_memsc5_&f; label pr_memsc5lead_&c = "next wave proxy mem score ctrd at 5: -4(excellent) to 0(poor), y&c";

	/*Hurd: IQCODE, IQCODE-change*/
		iqcodelag_&c = iqcode_&b; label iqcodelag_&c = "prior wave IQCODE: 1(much better) to 5(worse), y&c";
		iqcodelead_&c = iqcode_&f; label iqcodelead_&c = "next wave IQCODE: 1(much better) to 5(worse), y&c";
		iqcodechlag_&c = iqcodech_&b; label iqcodechlag_&c = "prior wave change in IQCODE since last non-missing wave, y&c";
		iqcodechlead_&c = iqcodech_&f; label iqcodechlead_&c = "next wave change in IQCODE since last non-missing wave, y&c";

	/*Crimmins: Jormsymp, ProxyMem, Interviewer assessment*/
		jormsymplag_&c = jormsymp_&b; label jormsymplag_&c = "prior wave total number of Jorm symptoms out of all availble: 0-7 up to 2002 wave, 0-5 after, y&c";
		jormsymplead_&c = jormsymp_&f; label jormsymplead_&c = "next wave total number of Jorm symptoms out of all availble: 0-7 up to 2002 wave, 0-5 after, y&c";
		jorm5symplag_&c = jorm5symp_&b; label jorm5symplag_&c = "prior wave total number of Jorm symptoms out of 5: 0-5 in all waves, y&c";
		jorm5symplead_&c = jorm5symp_&f; label jorm5symplead_&c = "next wave total number of Jorm symptoms out of 5: 0-5 in all waves, y&c";
		pr_memsc1lag_&c = pr_memsc1_&b; label pr_memsc1lag_&c = "prior wave proxy mem score ctrd at 1: 0(excellent) to 4(poor), y&c"; 
		pr_memsc1lead_&c = pr_memsc1_&f; label pr_memsc1lead_&c = "next wave proxy mem score ctrd at 1: 0(excellent) to 4(poor), y&c";
		iwercoglag_&c = iwercog_&b; label iwercoglag_&c = "prior wave interviewer assessmnet of cognitive impairment: 0(none) to 2(prevents interview completion), y&c";
		iwercoglead_&c = iwercog_&f; label iwercoglead_&c = "next wave interviewer assessmnet of cognitive impairment: 0(none) to 2(prevents interview completion), y&c";
run;
%mend;
%ll (00, 98, 02) data master; set master (drop = iwercog_98); run; /*variable not available*/
%ll (02, 00, 04)
%ll (04, 02, 06)
%ll (06, 04, 08)
%ll (08, 06, 10); 

/*proc print data=master (obs = 50);*/
/*	var iqcode_98 iqcodelag_00 iqcode_00 iqcodelead_00 iqcode_02 jorm5symp_06 jorm5symplag_08 jorm5symp_08 jorm5symplead_08 jorm5symp_10;*/
/*	*where proxy_00 = 1 and agee_00 > 65;*/
/*	where proxy_08 = 1 and agee_08 > 65;*/
/*run;*/

/************************************************************
*
*	2. Create prior-proxy dummy & lag TICS variables for Hurd proxy respondents
*
*************************************************************/
/*
	- if current wave is proxy, create tics-lag variables:
		- if lastwave is proxy: set tics-lags to 0, and keep iqcodechange
		- if lastwave is self-response: set tics-lags to last wave tics, set iqcodechange to 0
	
	- Separate regressions for self-response vs. proxies, no need to 

	- Separate regressions run for current-wave self-response vs. proxies - no need to replace values to 0 for current-wave self-response
*/

%macro lag (c, b); 
data master; set master;
	if proxy_&c = 1 then do;
		if proxy_&b = 1 then do;
			proxylag_&c = 1; label proxylag_&c = "PRIOR wave proxy responent status (for proxy respondents only), y&c";
			dateslag_&c = 0; label dateslag_&c = "PRIOR wave Hurd dates test (0-4) (for proxy respondents only), y&c";
			ticscount1lag_&c = 0; label ticscount1lag_&c = "PRIOR wave BackwardsCount: 1=Correct 1st attempt only (for proxy respondents only), y&c";
			ticscount1or2lag_&c = 0; label ticscount1or2lag_&c = "PRIOR wave BackwardsCount: 1=Correct 1st attempt OR 2nd attempt (for proxy respondents only), y&c";
			serial7lag_&c = 0; label serial7lag_&c = "PRIOR wave TICS serial 7: 0-5 (for proxy respondents only), y&c";
			preslag_&c = 0; label preslag_&c = "PRIOR wave TICS serial 7: 0-5 (for proxy respondents only), y&c";
			iwordlag_&c = 0; label iwordlag_&c = "PRIOR wave TICS serial 7: 0-5 (for proxy respondents only), y&c";
			dwordlag_&c = 0; label dwordlag_&c = "PRIOR wave TICS serial 7: 0-5 (for proxy respondents only), y&c";
			*keep iqcodech as is;
		end;

		else if proxy_&b = 0 then do;
			proxylag_&c = 0;
			dateslag_&c = dates_&b;
			ticscount1lag_&c = ticscount1_&b;
			ticscount1or2lag_&c = ticscount1or2_&b;
			serial7lag_&c = serial7_&b;
			preslag_&c = pres_&b;
			iwordlag_&c = iword_&b;
			dwordlag_&c = dword_&b;
			iqcodech_&c = 0;
		end;

	end;
run;
%mend;
%lag (00, 98) 
%lag (02, 00) 
%lag (04, 02)
%lag (06, 04)
%lag (08, 06);

/*proc means data=master ;*/
/*	var proxy_00 proxy_98 dates_98 ticscount1_98 serial7_98 pres_98 iword_98 dword_98 dateslag_00 ticscount1lag_00 serial7lag_00 preslag_00 iwordlag_00 dwordlag_00;*/
/*	where proxy_00 = 0;*/
/*run;*/
/*proc means data=master ;*/
/*	var proxy_00 proxy_98 dates_98 ticscount1_98 serial7_98 pres_98 iword_98 dword_98 dateslag_00 ticscount1lag_00 serial7lag_00 preslag_00 iwordlag_00 dwordlag_00 iqcodech_00;*/
/*	*where proxy_00 = 1 and proxy_98 = 1;*/
/*	where proxy_00 = 1 and proxy_98 = 1 and agee_00 ge 67;*/
/*run;*/
/*proc print data=master;*/
/*	var iqcode_00 iqcode_98 iqcode_dkrf_98 iqcodech_00;*/
/*	where proxy_00 = 1 and proxy_98 = 1 and iqcodech_00 = . and agee_00 ge 67;*/
/*run;*/
/*proc means data=master ;*/
/*	var proxy_00 proxy_98 dates_98 ticscount1_98 serial7_98 pres_98 iword_98 dword_98 dateslag_00 ticscount1lag_00 serial7lag_00 preslag_00 iwordlag_00 dwordlag_00 iqcodech_00;*/
/*	where proxy_00 = 1 and proxy_98 = 0;*/
/*run;*/

/************************************************************
*
*	3. Merge with ADAMS
*
*************************************************************/
proc sort data=master; by hhid pn;
proc sort data=atrk.adams1trk_r; by hhid pn; run;

data master_ad;
	merge master atrk.adams1trk_r (keep = hhid pn afresult bfresult cfresult dfresult
										  amonth ayear bmonth byear cmonth cyear dmonth dyear 
										  outcomec outcomed  
										  aasampwt_f aclongwt adlongwt aage bage cage dage in = a); 
	by hhid pn;
	if a;

	label afresult = "wave A assessment: 1=Completed, 5=RF/non-participation, 7=Deceased";
	label bfresult = "wave B assessment: 1=Completed, 5=RF/non-participation, 7=Deceased";
	label cfresult = "wave C assessment: 1=Completed, 5=RF/non-participation, 7=Deceased";
	label dfresult = "wave D assessment: 1=Completed, 5=RF/non-participation, 7=Deceased";
	
	label ayear = "Year completed wave A assessment"; label amonth = "month completed wave A assessment";
	label byear = "Year completed wave B assessment"; label bmonth = "month completed wave B assessment";
	label cyear = "Year completed wave C assessment"; label cmonth = "month completed wave C assessment";
	label dyear = "Year completed wave D assessment"; label dmonth = "month completed wave D assessment";

	label afresult = "wave A assessment: 1=Completed, 5=RF/non-participation, 7=Deceased";
	label bfresult = "wave B assessment: 1=Completed, 5=RF/non-participation, 7=Deceased";
	label cfresult = "wave C assessment: 1=Completed, 5=RF/non-participation, 7=Deceased";
	label dfresult = "wave D assessment: 1=Completed, 5=RF/non-participation, 7=Deceased";

	label aage = "age at wave A assessment";
	label bage = "age at wave B assessment";
	label cage = "age at wave C assessment";
	label dage = "age at wave D assessment";

	label outcomec = "respondent cognition status as of wave C for longitudinal tracking";
	label outcomed = "respondent cognition status as of wave D for longitudinal tracking";

	rename aasampwt_f = adams_awgt; label aasampwt_f = "ADAMS respondent level sample weight";
	rename aclongwt = adams_c_longwgt; label aclongwt = "ADAMS longitudinal weight waves A-C";
	rename adlongwt = adams_d_longwgt; label adlongwt = "ADAMS longitudinal weight waves A-D";

	if outcomed = 1 & afresult = 1 then dement_A = 1; /*copied from Wu code*/
	else if afresult = 1 & outcomec > 1 then dement_A = 0;

	if outcomed = 11 & bfresult = 1 then dement_B = 1; /*using same logic as Wu code for wave B*/
	else if bfresult = 1 & outcomec NE 11 then dement_B = 0;

	if outcomed = 21 & cfresult = 1 then dement_C = 1; /*using same logic as Wu code for wave C*/
	else if cfresult = 1 & outcomec NE 21 then dement_C = 0;

	if outcomed = 31 & dfresult = 1 then dement_D = 1; /*using same logic as Wu code for wave D*/
	else if dfresult = 1 & outcomed NE 31 then dement_D = 0;

	label dement_A = "Dementia ascertainment in wave A";
	label dement_B = "Dementia ascertainment in wave B";
	label dement_C = "Dementia ascertainment in wave C";
	label dement_D = "Dementia ascertainment in wave D";

	if ayear = 9997 then ayear = .;
	if byear = 9997 then byear = .;
	if cyear = 9997 then cyear = .; 
	if dyear = 9997 then dyear = .; 
run;

/*proc freq; */
/*	tables dement_a dement_b dement_c dement_d;*/
/*run;*/

/*create cogn_A - cogn_B with 3 level classification: normal, CIND, dementia
	- Wave A and B - need to exract from raw files using "FINAL PRIMARY DIAGNOSIS" 
*/
%macro cogn (w);
data wave&w; set adams&w..adams1&w.d_r (keep = hhid pn &w.DFDX1);
	if &w.DFDX1 = 31 then cogn_&w = 1; 
	else if 1 le &w.DFDX1 le 19 then cogn_&w = 3; 
	else if &w.DFDX1 = 32 then cogn_&w = 3; /*code32=possible lewy body dementia; though N=0 for both waves A & B*/
	else if 20 le &w.DFDX1 le 30 then cogn_&w = 2;
	else if &w.DFDX1 = 33 then cogn_&w = 2;

	label cogn_&w = "Cognition classification: 1=Normal, 2=CIND, 3=Dementia, wave &w";
	proc sort; by hhid pn;
run;

proc freq; tables cogn_&w;
run;
%mend;
%cogn (A) %cogn (B);
/*proc freq data=master_ad; tables dement_A dement_B; run;*/
/*NOTE: there is a discrepancy in wave B: N=40 with dementia based on OUTCOMEC/OUTCOMED in tracker file; N=57 in raw ADAMS Wave B file*/

data master_ad; 
	merge master_ad waveA (keep = hhid pn cogn_A) waveB (keep = hhid pn cogn_B);
	by hhid pn;

	if outcomec = 21 & cfresult = 1 then cogn_C = 3; /*using same logic as Wu code for wave A*/
	else if outcomec = 22 and cfresult = 1 then cogn_C = 2; 
	else if cfresult = 1 & outcomec not in (21, 22) then cogn_C = 1;

	if outcomed = 31 & dfresult = 1 then cogn_D = 3; /*using same logic as Wu code for wave A*/
	if outcomed = 32 & dfresult = 1 then cogn_D = 2; /*using same logic as Wu code for wave A*/
	else if dfresult = 1 & outcomed not in (31, 32) then cogn_D = 0;

	label cogn_C = "Cognition classification: 1=Normal, 2=CIND, 3=Dementia, wave C";
	label cogn_D = "Cognition classification: 1=Normal, 2=CIND, 3=Dementia, wave D";
run;
/**/
/*proc freq;*/
/*tables dement_C*cogn_C dement_D*cogn_D;*/
/*run;*/



/************************************************************
*
*	4. Identify HRS wave immediately prior to ADAMS assessment and set to 'useyear'
*
*************************************************************/


/*proc freq data=master_ad; tables ayear byear cyear dyear iweyr_00 iweyr_02 iweyr_04 iweyr_06 iweyr_08; run;*/

data master_ad; set master_ad;
	if inw_00 = 1 and mdy(iwemo_00,1,iweyr_00) <= mdy(amonth,1,ayear) then do; useyear_A = 2000; proxy_A = proxy_00; end;
	if inw_02 = 1 and mdy(iwemo_02,1,iweyr_02) <= mdy(amonth,1,ayear) then do; useyear_A = 2002; proxy_A = proxy_02; end;

	if inw_00 = 1 and mdy(iwemo_00,1,iweyr_00) <= mdy(bmonth,1,byear) then do; useyear_B = 2000; proxy_B = proxy_00; end;
	if inw_02 = 1 and mdy(iwemo_02,1,iweyr_02) <= mdy(bmonth,1,byear) then do; useyear_b = 2002; proxy_B = proxy_02; end;
	if inw_04 = 1 and mdy(iwemo_04,1,iweyr_04) <= mdy(bmonth,1,byear) then do; useyear_B = 2004; proxy_B = proxy_04; end;

	if inw_04 = 1 and mdy(iwemo_04,1,iweyr_04) <= mdy(cmonth,1,cyear) then do; useyear_C = 2004; proxy_C = proxy_04; end;
	if inw_06 = 1 and mdy(iwemo_06,1,iweyr_06) <= mdy(cmonth,1,cyear) then do; useyear_C = 2006; proxy_C = proxy_06; end;
	if inw_08 = 1 and mdy(iwemo_08,1,iweyr_08) <= mdy(cmonth,1,cyear) then do; useyear_C = 2008; proxy_C = proxy_08; end;

	if inw_06 = 1 and mdy(iwemo_06,1,iweyr_06) <= mdy(dmonth,1,dyear) then do; useyear_D = 2006; proxy_D = proxy_06; end;
	if inw_08 = 1 and mdy(iwemo_08,1,iweyr_08) <= mdy(dmonth,1,dyear) then do; useyear_D = 2008; proxy_D = proxy_08; end;

	label useyear_A = "Closest HRS interview completed prior to wave A";
	label useyear_B = "Closest HRS interview completed prior to wave B";
	label useyear_C = "Closest HRS interview completed prior to wave C";
	label useyear_D = "Closest HRS interview completed prior to wave D";

	label proxy_A = "proxy indicator for closest HRS interview completed prior to wave A";
	label proxy_B = "proxy indicator for closest HRS interview completed prior to wave B";
	label proxy_C = "proxy indicator for closest HRS interview completed prior to wave C";
	label proxy_D = "proxy indicator for closest HRS interview completed prior to wave D";

/*	proc freq;*/
/*		tables useyear_a useyear_b useyear_c useyear_d; */
run;


/************************************************************
*
*	5. Simple imputation of missing proxy cognition, set up regression vars for reg algorithims
*
*************************************************************/

/*- Replace missing proxy cognition with prior wave score; 
/*- In Wu, if prior wave is also missing, replace with subsequent wave score -- here we do not do this
in order to make best applicable to "real world" where future data is not available*/
/*- Set up regression variables for Wu/Hurd/Crimmins*/
/*- Note: Only useyear=2002, 2004 for wave B and 2004, 2006 for wave c;

/*set up proxy cognition variables for Wu/Hurd Crimmins regressions, replacing missing variables with lag/leads*/
%macro mis(y);
data master_ad; set master_ad;
	if useyear_&w = 20&y and proxy_&w = 1 then do;

		if &var._&y NE . then &var._&w = &var._&y;
		else if &var._&y = . then do;
			if &var.lag_&y NE . then &var._&w = &var.lag_&y;
/*			else if &var.lag_&y = . and  &var.lead_&y NE . then &var._&w = &var.lead_&y;*/ /*may not be possible for other/new data - do not impute from future wave*/
		end;
	end;

	label  &var._&w = "&varlab: for wave &w dementia prediction"
run;
%mend;

%let w = A;
%let var = iqcode5; %let varlab = IQCODE ctrd at 5 (-4 to 1); %mis(00) %mis(02) 
%let var = iqcode5_m; %let varlab = IQCODE ctrd at 5 * male interaction; %mis(00) %mis(02) 
%let var = pr_memsc5; %let varlab = proxy memory score crd at 5 (-4 to 1); %mis(00) %mis(02) 
%let var = iqcode; %let varlab = IQCODE; %mis(00) %mis(02) 
%let var = iqcodech; %let varlab = change in IQCODE since last non-missing wave; %mis(00) %mis(02) 
%let var = jormsymp; %let varlab = Jorm symptoms out of all items possible; %mis(00) %mis(02) 
%let var = jorm5symp; %let varlab = Jorm symptoms out of 5; %mis(00) %mis(02) 
%let var = pr_memsc1; %let varlab = proxy memory score ctrd at 1 (0-4); %mis(00) %mis(02) 
%let var = iwercog; %let varlab = inteviewer assessment of cogn impairment (0-2); %mis(00) %mis(02)

%let w = B;
%let var = iqcode5; %let varlab = IQCODE ctrd at 5 (-4 to 1); %mis(02) %mis(04) 
%let var = iqcode5_m; %let varlab = IQCODE ctrd at 5 * male interaction; %mis(02) %mis(04) 
%let var = pr_memsc5; %let varlab = proxy memory score crd at 5 (-4 to 1); %mis(02) %mis(04) 
%let var = iqcode; %let varlab = IQCODE; %mis(02) %mis(04) 
%let var = iqcodech; %let varlab = change in IQCODE since last non-missing wave; %mis(02) %mis(04) 
%let var = jormsymp; %let varlab = Jorm symptoms out of all items possible; %mis(02) %mis(04) 
%let var = jorm5symp; %let varlab = Jorm symptoms out of 5; %mis(02) %mis(04) 
%let var = pr_memsc1; %let varlab = proxy memory score ctrd at 1 (0-4); %mis(02) %mis(04) 
%let var = iwercog; %let varlab = inteviewer assessment of cogn impairment (0-2); %mis(02) %mis(04)
*note:  %mis(00) not needed here;

%let w = C;
%let var = iqcode5; %let varlab = IQCODE ctrd at 5 (-4 to 1); %mis(04) %mis(06) 
%let var = iqcode5_m; %let varlab = IQCODE ctrd at 5 * male interaction; %mis(04) %mis(06) 
%let var = pr_memsc5; %let varlab = proxy memory score crd at 5 (-4 to 1); %mis(04) %mis(06) 
%let var = iqcode; %let varlab = IQCODE; %mis(04) %mis(06) 
%let var = iqcodech; %let varlab = change in IQCODE since last non-missing wave; %mis(04) %mis(06) 
%let var = jormsymp; %let varlab = Jorm symptoms out of all items possible; %mis(04) %mis(06) 
%let var = jorm5symp; %let varlab = Jorm symptoms out of 5; %mis(04) %mis(06) 
%let var = pr_memsc1; %let varlab = proxy memory score ctrd at 1 (0-4); %mis(04) %mis(06) 
%let var = iwercog; %let varlab = inteviewer assessment of cogn impairment (0-2); %mis(04) %mis(06)
*note:  %mis(08) not needed here;

%let w = D;
%let var = iqcode5; %let varlab = IQCODE ctrd at 5 (-4 to 1); %mis(06) %mis(08) 
%let var = iqcode5_m; %let varlab = IQCODE ctrd at 5 * male interaction; %mis(06) %mis(08) 
%let var = pr_memsc5; %let varlab = proxy memory score crd at 5 (-4 to 1); %mis(06) %mis(08) 
%let var = iqcode; %let varlab = IQCODE; %mis(06) %mis(08) 
%let var = iqcodech; %let varlab = change in IQCODE since last non-missing wave; %mis(06) %mis(08) 
%let var = jormsymp; %let varlab = Jorm symptoms out of all items possible; %mis(06) %mis(08) 
%let var = jorm5symp; %let varlab = Jorm symptoms out of 5; %mis(06) %mis(08) 
%let var = pr_memsc1; %let varlab = proxy memory score ctrd at 1 (0-4); %mis(06) %mis(08) 
%let var = iwercog; %let varlab = inteviewer assessment of cogn impairment (0-2); %mis(06) %mis(08)
 

/*set up other regression variables*/
%macro reg (w, y);
data master_ad; set master_ad ;

/*proxy*/
	if useyear_&w = 20&y and proxy_&w = 1 then do;
	/*wu - proxies done; self-response need to be set to 0*/
		hrs_age70_&w = hrs_age70_&y; label hrs_age70_&w = "age at HRS interview ctrd at 70: for wave &w dementia prediction";
		tics13_&w = 0; label tics13_&w = "TICS score out of 13 (Wu-alg): for wave &w dementia prediction";
		tics13sq_&w = 0; label tics13sq_&w = "TICS score out of 13 squared (Wu-alg): for wave &w dementia prediction";
		iword_&w = 0; label iword_&w = "immediate word recall (0-10): for wave &w dementia prediction";
		iwordsq_&w = 0; label iwordsq_&w = "immediate word recall squared: for wave &w dementia prediction";
		dword_&w = 0; label dword_&w = "delayed word recall (0-1): for wave &w dementia prediction";
		dword_m_&w = 0; label dword_m_&w = "delayed word recall * male interaction: for wave &w dementia prediction";

	/*hurd*/
		hagecat_&w = hagecat_&y; label hagecat_&w = "age at HRS interview, 1=<75, 2=75-79, 3=80-84, 4=85-89, 5=90+: for wave &w dementia prediction";
		adl5_&w = adl5_&y; label adl5_&w = "total ADL limitations out of 5: for wave &w dementia prediction";
		adl6_&w = adl6_&y; label adl6_&w = "total ADL limitations our of 6: for wave &w dementia prediction";
		iadl5_&w = iadl5_&y; label iadl5_&w = "total IADL limitations out of 5: for wave &w dementia prediction";
		adl5ch_&w = adl5ch_&y;  label adl5ch_&w = "change in ADLs (0-5) since last non-missing wave: for wave &w dementia prediction";
		adl6ch_&w = adl6ch_&y; label adl6ch_&w = "change in ADLs (0-6) since last non-missing wave: for wave &w dementia prediction";
		iadl5ch_&w = iadl5ch_&y; label iadl5ch_&w = "change in IADLs (0-5) since last non-missing wave: for wave &w dementia prediction";
		proxylag_&w = proxylag_&y; label proxylag_&w = "prior wave proxy status: for wave &w dementia prediction";
		dateslag_&w = dateslag_&y; label dateslag_&w = "prior wave dates score (0-4): for wave &w dementia prediction";
		ticscount1lag_&w = ticscount1lag_&y; label ticscount1lag_&w = "prior wave TICS backward count (1=correct attempt 1 only): for wave &w dementia prediction";
		ticscount1or2lag_&w = ticscount1or2lag_&y; label ticscount1or2lag_&w = "prior wave TICS backward count (1=correct attempt 1 or attempt 2): for wave &w dementia prediction";
		serial7lag_&w = serial7lag_&y; label serial7lag_&w = "prior wave TICS serial 7: for wave &w dementia prediction";
		preslag_&w = preslag_&y; label preslag_&w = "prior wave TICS president: for wave &w dementia prediction";
		iwordlag_&w = iwordlag_&y; label iwordlag_&w = "prior waveimmediate word recall: for wave &w dementia prediction";
		dwordlag_&w = dwordlag_&y; label dwordlag_&w = "prior wave delayed word recall: for wave &w dementia prediction";
	/*crimmins - IADLs, done*/
		hrs_age_&w = hrs_age_&y; label hrs_age_&w = "age at HRS interview: for wave &w dementia prediction";
	end;

/*self-response*/
	if useyear_&w = 20&y and proxy_&w = 0 then do;
	/*wu*/
		hrs_age70_&w = hrs_age70_&y;
		iword_&w = iword_&y;
		iwordsq_&w = iwordsq_&y;
		dword_&w = dword_&y;
		tics13_&w = tics13_&y;
		tics13sq_&w = tics13sq_&y;
		dword_m_&w = dword_m_&y;
		iqcode5_&w = 0;
		pr_memsc5_&w = 0;
		iqcode5_m_&w = 0;
	/*hurd*/
		hagecat_&w = hagecat_&y;
		adl5_&w = adl5_&y; 
		adl6_&w = adl6_&y;
		iadl5_&w = iadl5_&y;
		adl5ch_&w = adl5ch_&y; 
		adl6ch_&w = adl6ch_&y;
		iadl5ch_&w = iadl5ch_&y;
		dates_&w = dates_&y; label dates_&w = "TICS dates score (0-4): for wave &w dementia prediction";
		ticscount1_&w = ticscount1_&y; label ticscount1_&w = "TICS backward count (1=correct attempt 1 only): for wave &w dementia prediction";
		ticscount1or2_&w = ticscount1or2_&y; label ticscount1or2_&w = "TICS backward count (1=correct attempt 1 or attempt 2): for wave &w dementia prediction";
		serial7_&w = serial7_&y; label serial7_&w = "TICS serial7: for wave &w dementia prediction";
		scis_&w = scis_&y; label scis_&w = "TICS scissors: for wave &w dementia prediction";
		cact_&w = cact_&y; label cact_&w = "TICS cactus: for wave &w dementia prediction";
		pres_&w = pres_&y; label pres_&w = "TICS president: for wave &w dementia prediction";
		/*iword, dword done*/
		datesch_&w = datesch_&y; label datesch_&w = "change in TICS dates: for wave &w dementia prediction";
		ticscount1ch_&w = ticscount1ch_&y; label ticscount1ch_&w = "change in TICS backward count (1=correct attmept 1 only): for wave &w dementia prediction";
		ticscount1or2ch_&w = ticscount1or2ch_&y; label ticscount1or2ch_&w = "change in TICS backward count (1=correct attempt 1 or 2): for wave &w dementia prediction";
		serial7ch_&w = serial7ch_&y; label serial7ch_&w = "change in TICS serial 7: for wave &w dementia prediction";
		scisch_&w = scisch_&y; label scisch_&w = "change in TICS scissors: for wave &w dementia prediction";
		cactch_&w = cactch_&y; label cactch_&w = "change in TICS cactus: for wave &w dementia prediction";
		presch_&w = presch_&y; label presch_&w = "change in TICS president: for wave &w dementia prediction";
		iwordch_&w = iwordch_&y; label iwordch_&w = "change in immediate word recall: for wave &w dementia prediction";
		dwordch_&w = dwordch_&y; label dwordch_&w = "chage in delayed word recall: for wave &w dementia prediction";
	/*crimmins*/
		/*iword, dword, serial7s done*/
		hrs_age_&w = hrs_age_&y;
		ticshrs_&w = ticshrs_&y; label ticshrs_&w = "TICS score from HRS (0-10): for wave &w dementia prediction";
		cogtot_&w = cogtot_&y; label cogtot_&w = "RAND cognition total, Potentially CRIMMINS TICS (0-35): for wave &w dementia prediction";
		dress_&w = dress_&y; label dress_&w = "ADL getting dressed 0=No Difficulty, 1=Difficulty,: for wave &w dementia prediction";
		bath_&w = bath_&y; label bath_&w = "ADL bathing 0=No Difficulty, 1=Difficulty,: for wave &w dementia prediction";
		eat_&w = eat_&y; label eat_&w = "ADL eating 0=No Difficulty, 1=Difficulty,: for wave &w dementia prediction";
		money_&w = money_&y; label money_&w = "IADL managing finances 0=No Difficulty, 1=Difficulty,: for wave &w dementia prediction";
		phone_&w = phone_&y; label phone_&w = "IADL using phone 0=No Difficulty, 1=Difficulty,: for wave &w dementia prediction";
	end;
run;
%mend;

%reg(A, 00) %reg(A, 02) 
%reg(B, 02) %reg(B, 04)
%reg(C, 04) %reg(C, 06)
%reg(D, 06) %reg(D, 08)

data x.master_ad_&dt; set master_ad; run;

ods pdf body = "contents_1c_master_ad_&dt..pdf";
proc contents data=master_ad; run;
ods pdf close;
