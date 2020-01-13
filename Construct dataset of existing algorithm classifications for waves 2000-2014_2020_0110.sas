libname rand 'F:\power\HRS\RAND_HRS\sasdata\2014(V2)';
options fmtsearch = (rand.formats);
libname raw 'F:\power\HRS\HRS data (raw)\SAS datasets';
libname hrs 'F:\power\HRS\DerivedData\AD_Disparities_AlgorithmDev\forHRS';

*set date for output label;
%let dt=2020_0110;

/****************************************************************************************************************************************
*
*	Updated 2020_0110
*		- Predicts dementia status using four existing algorithm (excludes Hurd) across all HRS waves (1993-2014) where variables are available 
*			- Proxy cognition variables extracted from raw HRS files
*			- All other variables extracted from RAND (version 1991_2014v2)
*		- final dataset restricted to age 70+, waves 2000-2014
*
****************************************************************************************************************************************/


/*******************************************************************
*
*	Extract data for HW, LKW, Wu, Hurd, Crimmins algorithms
*
********************************************************************/

data base; set rand.randhrs1992_2014v2 (keep = hhidpn hhid pn hacohort ragender 
									 raedegrm raedyrs /*Hurd-EdDegree, Crimmins-EdYrs*/
									 rahispan raracem); /*1=White, 2=Black/AA, 3=Other*/
/*sex*/
	if ragender = 1 then do; male = 1; female = 0; end;
	else do; male = 0; female = 1; end;
	if ragender = .M then do; male = .; female = .; end;
	label male = "1=male, 0=female";
	label female = "1=female, 0=male";

/*race/ethnicity*/

	/*black v non-black (ref) for Wu algorithm*/
	if raracem = 2 then black = 1; else if raracem NE .M then black = 0; /*for Wu algorithm*/
	label black = '0=White/Caucasian/Other 1=Black/AA';

	/*all three groups*/

	*hispanic;
	if rahispan = 1 then hispanic =1; 
	if rahispan = 0 then hispanic =0;
		label hispanic = "1=hispanic, 0=non-Hispanic";
	*NH_white;
	if rahispan = 0 and raracem = 1 then NH_white = 1; else NH_white = 0;
		label NH_white = "1=NH_white, 0=Hispanic, NH_black, NH_other";
	*NH_black;
	if rahispan = 0 and raracem = 2 then NH_black = 1; else NH_black = 0;
		label NH_black = "1=NH_black, 0=Hispanic, NH_white, NH_other";
	*NH_other;
	if rahispan = 0 and raracem = 3 then NH_other = 1; else NH_other = 0;
		label NH_other= "1=NH_other, 0=Hispanic, NH_white, NH_black";

/*education*/
	if raedegrm in (0) then do; midedu_hurd = 0; highedu_hurd = 0; edu_hurd=0; end; *lt high school;
	else if raedegrm in (1, 2, 3) then do; midedu_hurd = 1; highedu_hurd = 0; edu_hurd=1; end; *high school grad;
	else if raedegrm in (4, 5, 6, 7, 8) then do; midedu_hurd = 0; highedu_hurd = 1; edu_hurd = 2; end; *gt high school;
	label midedu_hurd = 'Hurd edu classification: HS graduate';
	label highedu_hurd = 'Hurd educlassification: More than HS';
	label edu_hurd = 'Hurd educ classification - 3 level, <HS ref';
	
	if 0 le raedyrs le 5 then do; lowedu_crim = 1; midedu_crim = 0; edu_crim = 0; end;
	else if 6 le raedyrs le 11 then do; lowedu_crim = 0; midedu_crim = 1; edu_crim=1; end;
	else if 12 le raedyrs le 17 then do; lowedu_crim = 0; midedu_crim = 0; edu_crim=2; end; 
	label lowedu_crim = 'Crimmins edu classification: 1=1-5yrs';
	label midedu_crim = 'Crimmins edu classification: 2=6-11yrs';
	label edu_crim = 'Crimmins edu classification - 3 level, <6yrs ref';

	drop ragender raedegrm raedyrs raracem;

	proc sort; by hhid pn;
run;

/*extract wave 2 (year 93) separately due to differences in variable names and missing information for HRS group*/
%macro ext2 (w, y);
/*extract*/
	data wave_&y; 
	set rand.randhrs1992_2014v2 
	(keep = hhidpn hhid pn 
			inw&w /*indicator for participation*/
			r&w.proxy /*indicator for proxy interview*/
			r&w.agey_e /*age in years - at end of interview month*/

	/*Summary cognition score (For HW)*/
			r&w.acgtot
	/*Cognition for self-respondents: TICS items (for LKW, Wu, Crimmins, Hurd)*/
			r&w.mo r&w.dy r&w.yr r&w.dw /*TICS date naming - for each one: 0=Incorrect, 1=Correct */
			r&w.bwc20 /* TICS serial backwards count 0=Incorrect, 1=CorrectTry2, 2=CorretTry1 */
			r&w.ser7 /* TICS serial 7's 0-5 */
			r&w.cact r&w.scis /*TICS object naming - for each one: 0=Incorrect, 1=Correct */
			r&w.pres r&w.vp /*TICS president and VP naming - 0=Incorrect, 1=Correct*/
			r&w.aimr10 /* immediate word recall - 0-10 */
			r&w.adlr10 /* delayed word recall 0-10 */

	/*ADL's - starting wave 2A */					  
			r&w.dressa 
			r&w.batha 
			r&w.eata 
			r&w.moneya 
			r&w.phonea  

			r&w.adla /*RAND constructed ADL summary score (0-5) - walk, dress, bath, eat, bed, Uses function sum(walkra...bedra) */
			r&w.iadlza); /*RAND constructed IADL summary score (0-5) not available wave 2H - phone money meds shop meals, Uses sum(phonea...mealsa) */

	rename r&w.proxy = proxy_&y; label r&w.proxy = "proxy indicator, wave &y";
	rename inw&w = inw_&y; label inw&w = "indicator for completing interview, wave &y";
	rename r&w.agey_e = hrs_age_&y; label r&w.agey_e = "age at end of interview month, wave &y";

	rename r&w.mo = ticsmonth_&y; label r&w.mo = "TICS date naming-month: 0=Incorrect, 1=Correct, wave &y";
	rename r&w.dy = ticsdate_&y; label r&w.dy = "TICS date naming-date: 0=Incorrect, 1=Correct, wave &y";
	rename r&w.yr = ticsyear_&y; label r&w.yr = "TICS date naming-year: 0=Incorrect, 1=Correct, wave &y";
	rename r&w.dw = ticsweek_&y; label r&w.dw = "TICS date naming-day of week: 0=Incorrect, 1=Correct, wave &y";
	rename r&w.bwc20 = ticscount_&y; label r&w.bwc20 = "TICS backwards counting 20: 0=Incorrect, 1=CorrectTry2, 2=CorrectTry1, wave &y";
	rename r&w.ser7 = serial7_&y; label r&w.ser7 = "TICS serial y: 0-5, wave &y";
	rename r&w.cact = cact_&y; label r&w.cact = "TICS object naming (cactus): 0=Incorrect, 1=Correct, wave &y";
	rename r&w.scis = scis_&y; label r&w.scis = "TICS object naming (scissors): 0=Incorrect, 1=Correct, wave &y";
	rename r&w.pres = pres_&y; label r&w.pres = "TICS name president: 0=Incorrect, 1=Correct, wave &y";
	rename r&w.vp = vp_&y; label r&w.vp = "TICS name vice-president: 0=Incorrect, 1=Correct, wave &y";
	rename r&w.aimr10 = iword_&y; label r&w.aimr10 = "immediate word recall: 0-10, wave &y";
	rename r&w.adlr10 = dword_&y; label r&w.adlr10 = "delayed word recall: 0-10, wave &y";

	rename r&w.dressa = dress_&y; label r&w.dressa = "ADL get dressed: 0=No Difficulty, 1=Difficulty, .X = Don't do (and did not indicate needing help), wave &y";
	rename r&w.batha = bath_&y; label r&w.batha = "ADL bathing: 0=No Difficulty, 1=Difficulty, .X = Don't do (and did not indicate needing help), wave &y";
	rename r&w.eata = eat_&y; label r&w.eata = "ADL eating: 0=No Difficulty, 1=Difficulty, .X = Don't do (and did not indicate needing help), wave &y";
	rename r&w.moneya = money_&y; label r&w.moneya = "IADL managing finances: 0=No Difficulty, 1=Difficulty, .X = Don't do (and NOT b/c health reason), wave &y";
	rename r&w.phonea = phone_&y; label r&w.phonea = "IADL using phone: 0=No Difficulty, 1=Difficulty, .X = Don't do (and NOT b/c health reason), wave &y";
	rename r&w.adla = adl_&y; label r&w.adla = "RAND total ADL's (counts all missing codes as not having difficulty: 0-5, wave &y";
	rename r&w.iadlza = iadl_&y; label r&w.iadlza = "RAND total IADL's (counts all missing codes as not having difficulty: 0-5, wave &y";
run;

/*construct variables for use in algorithms*/
proc sort data=wave_&y; by hhid pn; run;

data wave_&y; 
	merge base (keep = hhid pn male) wave_&y ;
	by hhid pn;

	/*HW summary score*/
		if 0 le r&w.acgtot le 35 then hw_self_&y = r&w.acgtot;
		label hw_self_&y = "HW cognition score (RAND-created composite): 0-35, wave &y";

	/*LKW summary score*/
		lkw_self_&y = ticscount_&y + serial7_&y + iword_&y + dword_&y; 
		label lkw_self_&y = "LKW cognition continuous (backcount + serial7 + iword + dword): 0-27, wave &y";

	/*WU*/
	hrs_age70_&y = hrs_age_&y - 70; 
		label hrs_age70_&y = "Age at interview centered at 70 (for Wu), wave &y";
	tics13_&y = ticsmonth_&y + ticsdate_&y + ticsweek_&y + ticsyear_&y + cact_&y + pres_&y + vp_&y + serial7_&y + (ticscount_&y = 2); /*0-13;  only counts first attempt at backward counting*/
		label tics13_&y = "TICS13 derivation (for Wu):0-13, wave &y";
	tics13sq_&y = tics13_&y * tics13_&y; 
		label tics13sq_&y = "TICS13_squared (for Wu): 0-169, wave &y";
	iwordsq_&y = iword_&y * iword_&y; 
		label iwordsq_&y = "iword_squared (for Wu): 0-100, wave &y";
	dword_m_&y = dword_&y * male; 
		label dword_m_&y = "DelayedWord x Male Interaction (for Wu): 0-10, wave &y";

	/*HURD*/
/*	dates_&y = ticsmonth_&y + ticsdate_&y + ticsweek_&y + ticsyear_&y; */
/*		label dates_&y = "Hurd dates test (0-4), wave &y";*/
	/*************based on Table S1 MeanBackwardCount suggests 0-1 scale rather than 0-2. Count as correct only if on attempt 1 (like Wu)*/
/*	if ticscount_&y = 2 then ticscount1_&y = 1; else if ticscount_&y in (0, 1) then ticscount1_&y = 0; */
/*		label ticscount1_&y = "BackwardsCount: 1=Correct 1st attempt ONLY, 0=Incorrect or Correct 2nd attempt, wave &y";*/
/*	hagecat_&y = 1 + (hrs_age_&y ge 75) + (hrs_age_&y ge 80) + (hrs_age_&y ge 85) + (hrs_age_&y ge 90);*/
/*		label hagecat_&y  = "Hurd HRS age category 1=<75, 2=75-79, 3=80-84, 4=85-89, 5=90+, wave &y";*/
/*		if hagecat_&y = 2 then hagecat75_&y = 1; else if hagecat_&y NE . then hagecat75_&y = 0; label hagecat75_&y = "age 75-79, wave &y";*/
/*		if hagecat_&y = 3 then hagecat80_&y = 1; else if hagecat_&y NE . then hagecat80_&y = 0; label hagecat80_&y = "age 80-84, wave &y";*/
/*		if hagecat_&y = 4 then hagecat85_&y = 1; else if hagecat_&y NE . then hagecat85_&y = 0; label hagecat85_&y = "age 85-89, wave &y";*/
/*		if hagecat_&y = 5 then hagecat90_&y = 1; else if hagecat_&y NE . then hagecat90_&y = 0; label hagecat90_&y = "age 90+, wave &y";*/

	/*CRIMMINS*/
	tics10_&y = ticsmonth_&y + ticsdate_&y + ticsweek_&y + ticsyear_&y + scis_&y + cact_&y + pres_&y + vp_&y + ticscount_&y; 
	label tics10_&y = "Crimmins TICS10, wave &y";
run;
%mend;
%ext2(2, 93);

/*1996 (wave 3) - 2012 (wave 11)*/
%macro ext (w, y);
/*extract*/
	data wave_&y; 
	set rand.randhrs1992_2014v2 
	(keep = hhidpn hhid pn 
		inw&w /*indicator for interview participation*/
		r&w.agey_e /*age in years - at end of interview month*/
		r&w.proxy /*indicator for proxy interview*/

	/*Summary cognition score (For HW)*/
			r&w.cogtot

	/*Cognition for self-respondents: TICS items*/
		r&w.mo r&w.dy r&w.yr r&w.dw /* TICS date naming - for each one: 0=Incorrect, 1=Correct */
		r&w.bwc20 /* TICS serial backwards count 0=Incorrect, 1=CorrectTry2, 2=CorretTry1 */
		r&w.ser7 /* TICS serial 7's 0-5 */
		r&w.cact r&w.scis /* TICS object naming - for each one: 0=Incorrect, 1=Correct */
		r&w.pres r&w.vp /* TICS president & VP naming - 0=Incorrect, 1=Correct*/
		r&w.imrc /* immediate word recall - 0-10 */
		r&w.dlrc /* delayed word recall 0-10 */
							  
	/*physical functioning */					  
		r&w.dressa 
		r&w.batha 
		r&w.eata 
		r&w.phonea 
		r&w.moneya 

		r&w.adla /*RAND constructed ADL's (0-5) - walk, dress, bath, eat, bed. Uses function sum(walkra...bedra)*/
		r&w.adlc /*RAND constructed change in ADL's (0-5) from last available wave*/
		r&w.adlf /*RAND flag for missed interviews prior to current*/
		r&w.iadlza); /*RAND constructed IADL's (0-5) - phone money meds shop meals, Uses sum(phonea...mealsa)*/

*create user-friendly variable names and labels;
		rename r&w.agey_e = hrs_age_&y; label r&w.agey_e = "age at end of interview month, wave &y";
		rename r&w.proxy = proxy_&y; label r&w.proxy = "proxy indicator, wave &y";
		rename inw&w = inw_&y; label inw&w = "indicator for completing interview, wave &y";

		rename r&w.mo = ticsmonth_&y; label r&w.mo = "TICS date naming-month: 0=Incorrect, 1=Correct, wave &y";
		rename r&w.dy = ticsdate_&y; label r&w.dy = "TICS date naming-date: 0=Incorrect, 1=Correct, wave &y";
		rename r&w.yr = ticsyear_&y; label r&w.yr = "TICS date naming-year: 0=Incorrect, 1=Correct, wave &y";
		rename r&w.dw = ticsweek_&y; label r&w.dw = "TICS date naming-day of week: 0=Incorrect, 1=Correct, wave &y";
		rename r&w.bwc20 = ticscount_&y; label r&w.bwc20 = "TICS backwards counting 20: 0=Incorrect, 1=CorrectTry2, 2=CorrectTry1, wave &y";
		rename r&w.ser7 = serial7_&y; label r&w.ser7 = "TICS serial 7: 0-5, wave &y";
		rename r&w.cact = cact_&y; label r&w.cact = "TICS object naming (cactus): 0=Incorrect, 1=Correct, wave &y";
		rename r&w.scis = scis_&y; label r&w.scis = "TICS object naming (scissors): 0=Incorrect, 1=Correct, wave &y";
		rename r&w.pres = pres_&y; label r&w.pres = "TICS name president: 0=Incorrect, 1=Correct, wave &y";
		rename r&w.vp = vp_&y; label r&w.vp = "TICS name vice-president: 0=Incorrect, 1=Correct, wave &y";
		rename r&w.imrc = iword_&y; label r&w.imrc = "immediate word recall: 0-10, wave &y";
		rename r&w.dlrc = dword_&y; label r&w.dlrc = "delayed word recall: 0-10, wave &y";

		rename r&w.dressa = dress_&y; label r&w.dressa = "ADL get dressed: 0=No Difficulty, 1=Difficulty, .X = Don't do (and did not indicate needing help), wave &y";
		rename r&w.batha = bath_&y; label r&w.batha = "ADL bathing: 0=No Difficulty, 1=Difficulty, .X = Don't do (and did not indicate needing help), wave &y";
		rename r&w.eata = eat_&y; label r&w.eata = "ADL eating: 0=No Difficulty, 1=Difficulty, .X = Don't do (and did not indicate needing help), wave &y";
		rename r&w.phonea = phone_&y; label r&w.phonea = "IADL using phone: 0=No Difficulty, 1=Difficulty, .X = Don't do (and NOT b/c health reason), wave &y";
		rename r&w.moneya = money_&y; label r&w.moneya = "IADL managing finances: 0=No Difficulty, 1=Difficulty, .X = Don't do (and NOT b/c health reason), wave &y";

		rename r&w.adla = adl_&y; label r&w.adla = "RAND total ADL's (counts all missing codes as not having difficulty: 0-5, wave &y";
		rename r&w.adlc = adlch_&y; label r&w.adlc = "RAND constructed chnage in ADL's out of 5, wave &y";
		rename r&w.iadlza = iadl_&y; label r&w.iadlza = "RAND total IADL's (counts all missing codes as not having difficulty: 0-5, wave &y";

		rename r&w.adlf = pwavemiss_&y; label r&w.adlf = "Number missed interviews prior to current wave (based on rWadlf), wave &y";
run;

/*construct wide dataset and derive necessary variables*/
proc sort data=wave_&y; by hhid pn; run;

data wave_&y; 
	merge base (keep = hhid pn male) wave_&y ;
	by hhid pn;

	/*HW summary score*/
		if 0 le r&w.cogtot le 35 then hw_self_&y = r&w.cogtot;
		label hw_self_&y = "HW cognition score (RAND-created composite): 0-35, wave &y";

	/*LKW summary score*/
		lkw_self_&y = ticscount_&y + serial7_&y + iword_&y + dword_&y; 
		label lkw_self_&y = "LKW cognition continuous (backcount + serial7 + iword + dword): 0-27, wave &y";

	/*Create derived variables needed for WU et al. algorithm*/
	hrs_age70_&y = hrs_age_&y - 70; 
		label hrs_age70_&y = "Age at interview centered at 70 (for Wu), wave &y";
	tics13_&y = ticsmonth_&y + ticsdate_&y + ticsweek_&y + ticsyear_&y + cact_&y + pres_&y + vp_&y + serial7_&y + (ticscount_&y = 2); /*0-13;  only counts first attempt at backward counting*/
		label tics13_&y = "TICS13 derivation (for Wu): 0-13, wave &y";
	tics13sq_&y = tics13_&y * tics13_&y; 
		label tics13sq_&y = "TICS13_squared (for Wu): 0-169, wave &y";
	iwordsq_&y = iword_&y * iword_&y; 
		label iwordsq_&y = "iword_squared (for Wu): 0-100, wave &y";
	dword_m_&y = dword_&y * male; 
		label dword_m_&y = "DelayedWord x Male Interaction (for Wu): 0-10, wave &y";

	/*HURD*/
/*	dates_&y = ticsmonth_&y + ticsdate_&y + ticsweek_&y + ticsyear_&y; */
/*		label dates_&y = "Hurd dates test (0-4), wave &y";*/
	/*************based on Table S1 MeanBackwardCount suggests 0-1 scale rather than 0-2. Count as correct only if on attempt 1 (like Wu)*/
/*	if ticscount_&y = 2 then ticscount1_&y = 1; else if ticscount_&y in (0, 1) then ticscount1_&y = 0; */
/*		label ticscount1_&y = "BackwardsCount: 1=Correct 1st attempt ONLY, 0=Incorrect or Correct 2nd attempt, wave &y";*/
/*	hagecat_&y = 1 + (hrs_age_&y ge 75) + (hrs_age_&y ge 80) + (hrs_age_&y ge 85) + (hrs_age_&y ge 90);*/
/*		label hagecat_&y  = "Hurd HRS age category 1=<75, 2=75-79, 3=80-84, 4=85-89, 5=90+, wave &y";*/
/*		if hagecat_&y = 2 then hagecat75_&y = 1; else if hagecat_&y NE . then hagecat75_&y = 0; label hagecat75_&y = "age 75-79, wave &y";*/
/*		if hagecat_&y = 3 then hagecat80_&y = 1; else if hagecat_&y NE . then hagecat80_&y = 0; label hagecat80_&y = "age 80-84, wave &y";*/
/*		if hagecat_&y = 4 then hagecat85_&y = 1; else if hagecat_&y NE . then hagecat85_&y = 0; label hagecat85_&y = "age 85-89, wave &y";*/
/*		if hagecat_&y = 5 then hagecat90_&y = 1; else if hagecat_&y NE . then hagecat90_&y = 0; label hagecat90_&y = "age 90+, wave &y";*/

	/*CRIMMINS*/
	tics10_&y = ticsmonth_&y + ticsdate_&y + ticsweek_&y + ticsyear_&y + scis_&y + cact_&y + pres_&y + vp_&y + ticscount_&y; 
	label tics10_&y = "Crimmins TICS10, wave &y";

run;
%mend;
%ext(3, 96) %ext(4, 98)
%ext(5, 00) %ext(6, 02) %ext(7, 04) %ext(8, 06) %ext(9, 08)
%ext(10, 10) %ext(11, 12) %ext(12, 14) 

data self; 
	merge base wave_93 wave_96 wave_98
			   wave_00 wave_02 wave_04 wave_06 wave_08
			   wave_10 wave_12 wave_14;
	by hhid pn;
run;


/*consruct change variables for Hurd*/
/*%macro ch(v);*/
/*	data self; set self;*/
/*	*1996 (w3);*/
/*		if &v._93 NE . then &v.ch_96 = &v._96 - &v._93;*/
/*		label &v.ch_96 = "change in &v between last non-missing interview and 1996";*/
/**/
/*	*1998 (w4);*/
/*		if &v._96 NE . then &v.ch_98 = &v._98 - &v._96;*/
/*		else if &v._93 NE . then &v.ch_98 = &v._98 - &v._93;*/
/*		label &v.ch_98 = "change in &v between last non-missing interview and 1998";*/
/**/
/*	*2000 (w5);*/
/*		if &v._98 NE . then &v.ch_00 = &v._00 - &v._98; */
/*		else if &v._96 NE . then &v.ch_00 = &v._00 - &v._96; */
/*		else if &v._93 NE . then &v.ch_00 = &v._00 - &v._93; */
/*		label &v.ch_00 = "change in &v between last non-missing interview and 2000";*/
/**/
/*	*2002 (w6);*/
/*		if &v._00 NE . then &v.ch_02 = &v._02 - &v._00; */
/*		else if &v._98 NE . then &v.ch_02 = &v._02 - &v._98; */
/*		else if &v._96 NE . then &v.ch_02 = &v._02 - &v._96; */
/*		else if &v._93 NE . then &v.ch_02 = &v._02 - &v._93; */
/*		label &v.ch_02 = "change in &v between last non-missing interview and 2002";*/
/**/
/*	*2004 (w7);*/
/*		if &v._02 NE . then &v.ch_04 = &v._04 - &v._02; */
/*		else if &v._00 NE . then &v.ch_04 = &v._04 - &v._00; */
/*		else if &v._98 NE . then &v.ch_04 = &v._04 - &v._98; */
/*		else if &v._96 NE . then &v.ch_04 = &v._04 - &v._96; */
/*		else if &v._93 NE . then &v.ch_04 = &v._04 - &v._93; */
/*		label &v.ch_04 = "change in &v between last non-missing interview and 2004";*/
/**/
/*	*2006 (w8);*/
/*		if &v._04 NE . then &v.ch_06 = &v._06 - &v._04; */
/*		else if &v._02 NE . then &v.ch_06 = &v._06 - &v._02; */
/*		else if &v._00 NE . then &v.ch_06 = &v._06 - &v._00; */
/*		else if &v._98 NE . then &v.ch_06 = &v._06 - &v._98; */
/*		else if &v._96 NE . then &v.ch_06 = &v._06 - &v._96; */
/*		else if &v._93 NE . then &v.ch_06 = &v._06 - &v._93; */
/*		label &v.ch_06 = "change in &v between last non-missing interview and 2006";*/
/**/
/*	*2008 (w9);*/
/*		if &v._06 NE . then &v.ch_08 = &v._08 - &v._06; */
/*		else if &v._04 NE . then &v.ch_08 = &v._08 - &v._04; */
/*		else if &v._02 NE . then &v.ch_08 = &v._08 - &v._02; */
/*		else if &v._00 NE . then &v.ch_08 = &v._08 - &v._00; */
/*		else if &v._98 NE . then &v.ch_08 = &v._08 - &v._98; */
/*		else if &v._96 NE . then &v.ch_08 = &v._08 - &v._96; */
/*		else if &v._93 NE . then &v.ch_08 = &v._08 - &v._93;*/
/* */
/*		label &v.ch_08 = "change in &v between last non-missing interview and 2008";*/
/**/
/*	*2010;*/
/*		if &v._08 NE . then &v.ch_10 = &v._10 - &v._08; */
/*		else if &v._06 NE . then &v.ch_10 = &v._10 - &v._06; */
/*		else if &v._04 NE . then &v.ch_10 = &v._10 - &v._04; */
/*		else if &v._02 NE . then &v.ch_10 = &v._10 - &v._02; */
/*		else if &v._00 NE . then &v.ch_10 = &v._10 - &v._00; */
/*		else if &v._98 NE . then &v.ch_10 = &v._10 - &v._98; */
/*		else if &v._96 NE . then &v.ch_10 = &v._10 - &v._96; */
/*		else if &v._93 NE . then &v.ch_10 = &v._10 - &v._93; */
/*		label &v.ch_10 = "change in &v between last non-missing interview and 2010";*/
/**/
/*	*2012;*/
/*		if &v._10 NE . then &v.ch_12 = &v._12 - &v._10; */
/*		else if &v._08 NE . then &v.ch_12 = &v._12 - &v._08; */
/*		else if &v._06 NE . then &v.ch_12 = &v._12 - &v._06; */
/*		else if &v._04 NE . then &v.ch_12 = &v._12 - &v._04; */
/*		else if &v._02 NE . then &v.ch_12 = &v._12 - &v._02; */
/*		else if &v._00 NE . then &v.ch_12 = &v._12 - &v._00; */
/*		else if &v._98 NE . then &v.ch_12 = &v._12 - &v._98; */
/*		else if &v._96 NE . then &v.ch_12 = &v._12 - &v._96; */
/*		else if &v._93 NE . then &v.ch_12 = &v._12 - &v._93; */
/*		label &v.ch_12 = "change in &v between last non-missing interview and 2012";*/
/**/
/*	*2014;*/
/*		if &v._12 NE . then &v.ch_14 = &v._14 - &v._12; */
/*		else if &v._10 NE . then &v.ch_14 = &v._14 - &v._10; */
/*		else if &v._08 NE . then &v.ch_14 = &v._14 - &v._08; */
/*		else if &v._06 NE . then &v.ch_14 = &v._14 - &v._06; */
/*		else if &v._04 NE . then &v.ch_14 = &v._14 - &v._04; */
/*		else if &v._02 NE . then &v.ch_14 = &v._14 - &v._02; */
/*		else if &v._00 NE . then &v.ch_14 = &v._14 - &v._00; */
/*		else if &v._98 NE . then &v.ch_14 = &v._14 - &v._98; */
/*		else if &v._96 NE . then &v.ch_14 = &v._14 - &v._96; */
/*		else if &v._93 NE . then &v.ch_14 = &v._14 - &v._93; */
/*		label &v.ch_14 = "change in &v between last non-missing interview and 2014";*/
/**/
/*	*2016;*/
/*		if &v._14 NE . then &v.ch_16 = &v._16 - &v._14; */
/*		else if &v._12 NE . then &v.ch_16 = &v._16 - &v._12; */
/*		else if &v._10 NE . then &v.ch_16 = &v._16 - &v._10; */
/*		else if &v._08 NE . then &v.ch_16 = &v._16 - &v._08; */
/*		else if &v._06 NE . then &v.ch_16 = &v._16 - &v._06; */
/*		else if &v._04 NE . then &v.ch_16 = &v._16 - &v._04; */
/*		else if &v._02 NE . then &v.ch_16 = &v._16 - &v._02; */
/*		else if &v._00 NE . then &v.ch_16 = &v._16 - &v._00; */
/*		else if &v._98 NE . then &v.ch_16 = &v._16 - &v._98; */
/*		else if &v._96 NE . then &v.ch_16 = &v._16 - &v._96; */
/*		else if &v._93 NE . then &v.ch_16 = &v._16 - &v._93; */
/*		label &v.ch_16 = "change in &v between last non-missing interview and 2016";*/
/*	run;*/
/*%mend;*/
/*%ch(iadl) *adl already constructed by RAND;*/
/*%ch(dates) */
/*%ch(ticscount1) */
/*%ch(serial7) */
/*%ch(scis) %ch(cact)*/
/*%ch(pres) *VP not used in Hurd;*/
/*%ch(iword) %ch(dword)*/

/****************************************************
*
*		EXTRACT PROXY
*
*****************************************************/
data allvars; set self; run;

/*Jorm IQCODE:
	- following Wu's treatment of missing data:
		- drop any observations with 4+ DK/RF in the initial question
		- if initial question is answered with better or worse, but subsequent question is DK/RF then 
			replace DK/RF with value closest to staying the same 

	- For items 'not applicable' (=4 in the data) - do not count in computation of mean IQCODE score, 
			do not count as DK/RF for purposes of dropping observations
*/

%macro jorm (base, better, worse, first, y, raw);

data jorm_&y; set raw.&raw (keep = hhid pn &base &better &worse); 
	array base [16] &base;
	array better [16] &better;
	array worse [16] &worse;
	array jorm [16] jorm_&y._1 - jorm_&y._16;

	if &first NE . then do;

		iqcode_dkrf_&y = 0; 

		do i = 1 to 16;
			
			if base[i] = 1 then do; /*better*/
				if better[i] = 1 then jorm[i] = 1; /*much better*/
				else if better[i] in (2, 8, 9) then jorm[i] = 2; /*a bit better*/
			end;

			else if base[i] = 2 then jorm[i] = 3; /*same*/

			else if base[i] = 3 then do; /*worse*/
				if worse[i] in (4, 8, 9) then jorm[i] = 4; /*a bit worse*/
				else if worse[i] = 5 then jorm[i] = 5; /*much worse*/
			end;

			else if base[i] in (8, 9) then do; /*8=dk/na, 9=rf*/
				jorm[i] = .;
				iqcode_dkrf_&y = iqcode_dkrf_&y + 1; /*count of dk/na*/
			end;

			else if base[i] = 4 then do; /*4=NotApplicable - do NOT count as dk/rf*/
				jorm[i] = .;
			end;

		end;
		
		IQCODE_&y = mean (of jorm[*]); /*mean IQCODE score over non-missing items*/

		if iqcode_dkrf_&y > 3 then IQCODE_&y = .;	/* set to missing 4+ dk/rf*/

	end;

	label IQCODE_&y = "Jorm IQCODE score for Hurd: 1(much better) to 5(much worse), set to missing if 4+ items dk/nf (last-wave value if missing), wave &y";
	label IQCODE_dkrf_&y = "number of Jorm IQCODE items DK/RF: 0-16 (does NOT count Not applicables) y&y ";
	
	/*for Wu - create version centered at 5*/
	IQCODE5_&y = IQCODE_&y - 5; 
	label IQCODE5_&y = "Jorm IQCODE score ctrd at 5 for Wu: -4(much better) to 0(much worse), set to missing if 4+ items dk/nf (last-wave value if missing), wave &y";

proc sort; by hhid pn;
run;

proc means; var IQCODE_&y IQCODE5_&y iqcode_dkrf_&y;

data allvars;
	merge allvars jorm_&y (keep = hhid pn IQCODE_&y IQCODE5_&y);
	by hhid pn;

	IQCODE5_m_&y = IQCODE5_&y * male;
	label IQCODE5_m_&y = "IQCODE (centered at 5) * male interaction for Wu algorithm (last-wave value if missing), wave &y";
run;
%mend;
/*NOT AVAILABLE IN 1993*/

/*compute Jorm IQCODE for 1995 HRS*/
%jorm (D1072 D1077 D1082 D1087 D1092 D1097 D1102 D1107 D1112 D1117 D1122 D1127 D1132 D1135 D1138 D1141, 
	   D1073 D1078 D1083 D1088 D1093 D1098 D1103 D1108 D1113 D1118 D1123 D1128 D1133 D1136 D1139 D1142,
       D1074 D1079 D1084 D1089 D1094 D1099 D1104 D1109 D1114 D1119 D1124 D1129 D1134 D1137 D1140 D1143,
	   D1072, 95, a95pc_r);
/*compute Jorm IQCODE for 1996 HRS*/
%jorm (E1072 E1077 E1082 E1087 E1092 E1097 E1102 E1107 E1112 E1117 E1122 E1127 E1132 E1135 E1138 E1141, 
	   E1073 E1078 E1083 E1088 E1093 E1098 E1103 E1108 E1113 E1118 E1123 E1128 E1133 E1136 E1139 E1142,
       E1074 E1079 E1084 E1089 E1094 E1099 E1104 E1109 E1114 E1119 E1124 E1129 E1134 E1137 E1140 E1143,
	   E1072, 96, h96pc_r);
/*combine wave 3 for AHEAD and HRS - use 96 suffix*/
data allvars; set allvars;
	if IQCODE_95 NE . then IQCODE_96 = IQCODE_95;
	if IQCODE5_95 NE . then IQCODE5_96 = IQCODE5_95;
	if IQCODE5_m_95 NE . then IQCODE5_m_96 = IQCODE5_m_95;

	drop IQCODE_95 IQCODE5_95 IQCODE5_m_95;
	proc means; var IQCODE_96 IQCODE5_96 IQCODE5_m_96;
run;

/*compute Jorm IQCODE for 1998 HRS*/
%jorm (F1389 F1394 F1399 F1404 F1409 F1414 F1419 F1424 F1429 F1434 F1439 F1444 F1448 F1451 F1454 F1457, 
	   F1390 F1395 F1400 F1405 F1410 F1415 F1420 F1425 F1430 F1435 F1440 F1445 F1449 F1452 F1455 F1458,
       F1391 F1396 F1401 F1406 F1411 F1416 F1421 F1426 F1431 F1436 F1441 F1446 F1450 F1453 F1456 F1459,
	   F1389, 98, h98pc_r);
/*compute Jorm IQCODE for 2000 HRS*/
%jorm (G1543 G1548 G1553 G1558 G1563 G1568 G1573 G1578 G1583 G1588 G1593 G1598 G1602 G1605 G1608 G1611, 
	   G1544 G1549 G1554 G1559 G1564 G1569 G1574 G1579 G1584 G1589 G1594 G1599 G1603 G1606 G1609 G1612,
       G1545 G1550 G1555 G1560 G1565 G1570 G1575 G1580 G1585 G1590 G1595 G1600 G1604 G1607 G1610 G1613,
	   G1543, 00, h00pc_r);
/*compute Jorm IQCODE for 2002 HRS*/
%jorm (HD506 HD509 HD512 HD515 HD518 HD521 HD524 HD527 HD530 HD533 HD536 HD539 HD542 HD545 HD548 HD551, 
	   HD507 HD510 HD513 HD516 HD519 HD522 HD525 HD528 HD531 HD534 HD537 HD540 HD543 HD546 HD549 HD552,
       HD508 HD511 HD514 HD517 HD520 HD523 HD526 HD529 HD532 HD535 HD538 HD541 HD544 HD547 HD550 HD553,
	   HD506, 02, h02d_r);
/*compute Jorm IQCODE for 2004 HRS*/
%jorm (JD506 JD509 JD512 JD515 JD518 JD521 JD524 JD527 JD530 JD533 JD536 JD539 JD542 JD545 JD548 JD551, 
	   JD507 JD510 JD513 JD516 JD519 JD522 JD525 JD528 JD531 JD534 JD537 JD540 JD543 JD546 JD549 JD552,
       JD508 JD511 JD514 JD517 JD520 JD523 JD526 JD529 JD532 JD535 JD538 JD541 JD544 JD547 JD550 JD553,
	   JD506, 04, h04d_r);
/*compute Jorm IQCODE for 2006 HRS*/
%jorm (KD506 KD509 KD512 KD515 KD518 KD521 KD524 KD527 KD530 KD533 KD536 KD539 KD542 KD545 KD548 KD551, 
	   KD507 KD510 KD513 KD516 KD519 KD522 KD525 KD528 KD531 KD534 KD537 KD540 KD543 KD546 KD549 KD552,
       KD508 KD511 KD514 KD517 KD520 KD523 KD526 KD529 KD532 KD535 KD538 KD541 KD544 KD547 KD550 KD553,
	   KD506, 06, h06d_r);
/*compute Jorm IQCODE for 2008 HRS*/
%jorm (LD506 LD509 LD512 LD515 LD518 LD521 LD524 LD527 LD530 LD533 LD536 LD539 LD542 LD545 LD548 LD551, 
	   LD507 LD510 LD513 LD516 LD519 LD522 LD525 LD528 LD531 LD534 LD537 LD540 LD543 LD546 LD549 LD552,
       LD508 LD511 LD514 LD517 LD520 LD523 LD526 LD529 LD532 LD535 LD538 LD541 LD544 LD547 LD550 LD553,
	   LD506, 08, h08d_r);
/*compute Jorm IQCODE for 2010 HRS*/
%jorm (MD506 MD509 MD512 MD515 MD518 MD521 MD524 MD527 MD530 MD533 MD536 MD539 MD542 MD545 MD548 MD551, 
	   MD507 MD510 MD513 MD516 MD519 MD522 MD525 MD528 MD531 MD534 MD537 MD540 MD543 MD546 MD549 MD552,
       MD508 MD511 MD514 MD517 MD520 MD523 MD526 MD529 MD532 MD535 MD538 MD541 MD544 MD547 MD550 MD553,
	   MD506, 10, h10d_r);
/*compute Jorm IQCODE for 2012 HRS*/
%jorm (ND506 ND509 ND512 ND515 ND518 ND521 ND524 ND527 ND530 ND533 ND536 ND539 ND542 ND545 ND548 ND551, 
	   ND507 ND510 ND513 ND516 ND519 ND522 ND525 ND528 ND531 ND534 ND537 ND540 ND543 ND546 ND549 ND552,
       ND508 ND511 ND514 ND517 ND520 ND523 ND526 ND529 ND532 ND535 ND538 ND541 ND544 ND547 ND550 ND553,
	   ND506, 12, h12d_r);
/*compute Jorm IQCODE for 2014 HRS*/
%jorm (OD506 OD509 OD512 OD515 OD518 OD521 OD524 OD527 OD530 OD533 OD536 OD539 OD542 OD545 OD548 OD551, 
	   OD507 OD510 OD513 OD516 OD519 OD522 OD525 OD528 OD531 OD534 OD537 OD540 OD543 OD546 OD549 OD552,
       OD508 OD511 OD514 OD517 OD520 OD523 OD526 OD529 OD532 OD535 OD538 OD541 OD544 OD547 OD550 OD553,
	   OD506, 14, h14d_r);

/*compute change in IQCODE (for Hurd)*/
/*%macro ch(y, yb);*/
/*data allvars; set allvars;*/
/*	IQCODEch_&y = IQCODE_&y - IQCODE_&yb;*/
/*	label IQCODEch_&y = "Jorm IQCODE change between past 2 waves for Hurd (last-wave value if missing), wave &y";*/
/*	proc means; var IQCODE_&y IQCODEch_&y; */
/*run;*/
/*%mend;*/
/*%ch(16, 14) %ch(14, 12) %ch(12, 10) %ch(10, 08)*/
/*%ch(08, 06) %ch(06, 04) %ch(04, 02) %ch(02, 00)*/
/*%ch(00, 98) %ch(98, 96) */

/*
PROXY MEMORY SCORES:
	Wu/Crimmins: proxy memory score
		- Raw variable: 1(excellent) to 5(poor)
			- For Wu center at 5: -4(excellent) to 0(poor)
			- For Crimmins center at 1: 0(excellent) to 4(poor)
***/

%macro ext (raw, y, v);
data prmem_&y; set raw.&raw (keep = hhid pn &v);

	if &v not in (8, 9, .) then do;
		pr_memsc5_&y = &v - 5; label pr_memsc5_&y = "proxy mem score ctrd at 5 for Wu: -4(excellent) to 0(poor) (last-wave value if missing), wave &y";
		pr_memsc1_&y = &v - 1; label pr_memsc1_&y = "proxy mem score ctrd at 1 for Crimmins: 0(excellent) to 4(poor) (last-wave value if missing), wave &y";
	end;
	
	proc sort; by hhid pn;
run;

data allvars; 
	merge allvars prmem_&y (keep = hhid pn pr_memsc5_&y pr_memsc1_&y);
	by hhid pn;
	proc means; var pr_memsc5_&y pr_memsc1_&y;
run;
%mend;
%ext (br21, 93, V323);
%ext (a95pc_r, 95, D1056);
%ext (h96pc_r, 96, E1056);
data allvars; set allvars;
	if pr_memsc1_95 NE . then pr_memsc1_96 = pr_memsc1_95;
	if pr_memsc5_95 NE . then pr_memsc5_96 = pr_memsc5_95;

	drop pr_memsc1_95 pr_memsc5_95;
	proc means; var pr_memsc1_96 pr_memsc5_96;
run;
%ext (h98pc_r, 98, F1373);
%ext (h00pc_r, 00, G1527);
%ext (h02d_r, 02, HD501);
%ext (h04d_r, 04, JD501);
%ext (h06d_r, 06, KD501);
%ext (h08d_r, 08, LD501);
%ext (h10d_r, 10, MD501);
%ext (h12d_r, 12, ND501);
%ext (h14d_r, 14, OD501);


/*
Extract interviewer assessment of proxy cognition, derive LKW proxy score

	Crimmins: interviewer assessment for proxy cognition 
	- not available before 2000 wave
	- rescale to 0(no impairment) - 2(cannot do interview)
*/

%macro ext (raw, y, v);
data iwa_&y; set raw.&raw (keep = hhid pn &v);
	if &v in (1, 2, 3) then iwercog_&y = &v - 1;
	label iwercog_&y = "Interviewer assessmnet of cognitive impairment: 0(none) to 2(prevents interview completion) (last-wave value if missing), wave &y"; 
proc sort; by hhid pn; 
run;

data allvars; 
	merge allvars iwa_&y (keep = hhid pn iwercog_&y);
	by hhid pn;
run;
%mend;
%ext (h00cs_r, 00, G517);
%ext (h02a_r, 02, HA011);
%ext (h04a_r, 04, JA011);
%ext (h06a_r, 06, KA011);
%ext (h08a_r, 08, LA011);
%ext (h10a_r, 10, MA011);
%ext (h12a_r, 12, NA011);
%ext (h14a_r, 14, OA011);

/********************************************************************
*	Jorm symptoms score (i.e. hw proxy)
********************************************************************/
%macro cjorm(y, raw, lost, wander, alone, halluc, mem, judg, org); 
data cjorm_&y; 
	set raw.&raw (keep = hhid pn &lost &wander &alone &halluc &mem &judg &org);

	if &lost = 1 then lost_&y = 1; else if &lost = 5 then lost_&y = 0;
	if &wander = 1 then wander_&y = 1; else if &wander = 5 then wander_&y = 0; /*if = 4 (R cannot wander off), count as missing*/
	if &alone = 5 then alone_&y = 1; else if &alone = 1 then alone_&y = 0; /*it is a symptom if R CANNOT be left alone; not a symptom if ok to be left alone*/
	if &halluc = 1 then hallucinate_&y = 1; else if &halluc = 5 then hallucinate_&y = 0;
	if &mem = 5 then memsymp_&y = 1; else if &mem in (1, 2, 3, 4) then memsymp_&y = 0;
	if &judg = 5 then judgment_&y = 1; else if &judg in (1, 2, 3, 4) then judgment_&y = 0;
	if &org = 5 then orgn_&y = 1; else if &org in (1, 2, 3, 4) then orgn_&y = 0;

	hw_proxy_&y = sum(lost_&y, wander_&y, alone_&y, hallucinate_&y, memsymp_&y, judgment_&y, orgn_&y);
		label hw_proxy_&y = "HW proxy score: Total number of Jorm symptoms out of all available (0-7 in 1993-2002, 0-5 in 2004-2016) in wave &y (raw HRS)";
	hw_proxy2_&y = sum(lost_&y, wander_&y, alone_&y, hallucinate_&y, memsymp_&y);
		label hw_proxy2_&y = "HW proxy score: Total number consistently available Jorm symptoms (0-5) wave &y (raw HRS)";

proc sort data=cjorm_&y; by hhid pn; run;
proc sort data=allvars; by hhid pn; run;

data allvars;
	merge allvars cjorm_&y (keep = hhid pn hw_proxy_&y hw_proxy2_&y);
	by hhid pn;
run;
%mend;
%cjorm(93, br21, V342, V343, V344, V345, V323, V328, V333); 
%cjorm(95, a95pc_r, D1144, D1145, D1146, D1147, D1056, D1061, D1066); 
%cjorm(96, h96pc_r, E1144, E1145, E1146, E1147, E1056, E1061, E1066); 
data allvars; set allvars;
	if hw_proxy_95 NE . then hw_proxy_96 = hw_proxy_95;
	if hw_proxy2_95 NE . then hw_proxy2_96 = hw_proxy2_95;

	drop hw_proxy_95 hw_proxy2_95;
	proc means; var hw_proxy_96 hw_proxy2_96;
run;

%cjorm(98, h98pc_r, F1461, F1462, F1463, F1464, F1373, F1378, F1383)
%cjorm(00, h00pc_r, G1615, G1616, G1617, G1618, G1527, G1532, G1537)
%cjorm(02, h02d_r, HD554, HD555, HD556, HD557, HD501, HD503, HD504)

/*04-16*/
%macro cjorm(y, raw, lost, wander, alone, halluc, mem); 
data cjorm_&y; 
	set raw.&raw (keep = hhid pn &lost &wander &alone &halluc &mem);

	if &lost = 1 then lost_&y = 1; else if &lost = 5 then lost_&y = 0;
	if &wander = 1 then wander_&y = 1; else if &wander = 5 then wander_&y = 0; /*if = 4 (R cannot wander off), count as missing*/
	if &alone = 5 then alone_&y = 1; else if &alone = 1 then alone_&y = 0; /*it is a symptom if R CANNOT be left alone; not a symptom if ok to be left alone*/
	if &halluc = 1 then hallucinate_&y = 1; else if &halluc = 5 then hallucinate_&y = 0;
	if &mem = 5 then memsymp_&y = 1; else if &mem in (1, 2, 3, 4) then memsymp_&y = 0;

	hw_proxy_&y = sum(lost_&y, wander_&y, alone_&y, hallucinate_&y, memsymp_&y);
		label hw_proxy_&y = "HW proxy score: Total number of Jorm symptoms out of all available (0-7 in 1993-2002, 0-5 in 2004-2016) in wave &y (raw HRS)";
	hw_proxy2_&y = sum(lost_&y, wander_&y, alone_&y, hallucinate_&y, memsymp_&y);
		label hw_proxy2_&y = "HW proxy score: Total number consistently available Jorm symptoms (0-5) wave &y (raw HRS)";
run;

proc sort data=cjorm_&y; by hhid pn; run;
proc sort data=allvars; by hhid pn; run;

data allvars;
	merge allvars cjorm_&y (keep = hhid pn hw_proxy_&y hw_proxy2_&y);
	by hhid pn;
run;
%mend;
%cjorm(04, h04d_r, JD554, JD555, JD556, JD557, JD501)
%cjorm(06, h06d_r, KD554, KD555, KD556, KD557, KD501)
%cjorm(08, h08d_r, LD554, LD555, LD556, LD557, LD501)
%cjorm(10, h10d_r, MD554, MD555, MD556, MD557, MD501)
%cjorm(12, h12d_r, ND554, ND555, ND556, ND557, ND501); 
%cjorm(14, h14d_r, OD554, OD555, OD556, OD557, OD501); 

/*CHECK*/
proc contents data=allvars; run;


/****************************************************************
*
*	Imputation of missing proxy memory items
*		+ Create LKW summary score
*
*****************************************************************/
/******************************************************************************************************************************
* Impute missing values for proxy-cognitino using LOCF (as per Wu)
*	- create SECOND version of variable for ease of use if we want to subset to non-imputed values
*	- Also create flag to count Ns of imputed values
******************************************************************************************************************************/
%macro imp(var);
data allvars; set allvars;
	array prior[*] &var._93 &var._96 &var._98 &var._00 &var._02 &var._04 &var._06 &var._08 &var._10 &var._12;
	array var[*] &var._96 &var._98 &var._00 &var._02 &var._04 &var._06 &var._08 &var._10 &var._12 &var._14;
	array imp[*] &var._i_96 &var._i_98 &var._i_00 &var._i_02 &var._i_04 &var._i_06 &var._i_08 &var._i_10 &var._i_12 &var._i_14;
	array flag[*] &var._if_96 &var._if_98 &var._if_00 &var._if_02 &var._if_04 &var._if_06 &var._if_08 &var._if_10 &var._if_12 &var._if_14;
	array proxy[*] proxy_96 proxy_98 proxy_00 proxy_02 proxy_04 proxy_06 proxy_08 proxy_10 proxy_12 proxy_14;

	do i = 1 to 10;
		if proxy[i] = 1 then do;
			if var[i] = . and prior[i] NE . then do;
				imp[i] = prior[i];
				flag[i] = 1;
			end;
			else do;
				imp[i] = var[i];
				flag[i] = 0;
			end;
		end;
	end;

	*for 1993 wave (where there is no prior wave), set imputed version equal to non-imputed version for all;
	&var._i_93 = &var._93;

	proc means nolabels;
		var &var._93 &var._i_93 &var._96 &var._i_96 &var._if_96 &var._98 &var._i_98 &var._if_98 &var._00 &var._i_00 &var._if_00 &var._02 &var._i_02 &var._if_02 
			&var._04 &var._i_04 &var._if_04 &var._06 &var._i_06 &var._if_06 &var._08 &var._i_08 &var._if_08 &var._10 &var._i_10 &var._if_10
			&var._12 &var._i_12 &var._if_12 &var._14 &var._i_14 &var._if_14;
run;
%mend;
%imp(IQCODE5) %imp(iqcode5_m) %imp(pr_memsc5) %imp(pr_memsc1) %imp(jormsymp5) %imp(IQCODE) %imp(hw_proxy) %imp(hw_proxy2) %imp(iwercog)
/*%imp(IQCODEch)*/


/*
- Set up Hurd regression variables:
Create prior-proxy dummy & lag TICS variables for Hurd proxy respondents
	- if current wave is proxy, create tics-lag variables:
		- if lastwave is proxy: set tics-lags to 0, and keep iqcodechange
		- if lastwave is self-response: set tics-lags to last wave tics, set iqcodechange to 0
	
	- Separate regressions run for current-wave self-response vs. proxies - no need to replace values to 0 for current-wave self-response
*/
/*%macro lag (c, b); */
/*data allvars; set allvars;*/
/*	if proxy_&c = 1 then do;*/
/*		if proxy_&b = 1 then do;*/
/*			proxylag_&c = 1; label proxylag_&c = "PRIOR wave proxy responent status (for proxy respondents only), wave &c";*/
/*			dateslag_&c = 0; label dateslag_&c = "PRIOR wave Hurd dates test (0-4) (for proxy respondents only), wave &c";*/
/*			ticscount1lag_&c = 0; label ticscount1lag_&c = "PRIOR wave BackwardsCount: 1=Correct 1st attempt only (for proxy respondents only), wave &c";*/
/*			serial7lag_&c = 0; label serial7lag_&c = "PRIOR wave TICS serial 7: 0-5 (for proxy respondents only), wave &c";*/
/*			preslag_&c = 0; label preslag_&c = "PRIOR wave TICS serial 7: 0-5 (for proxy respondents only), wave &c";*/
/*			iwordlag_&c = 0; label iwordlag_&c = "PRIOR wave TICS serial 7: 0-5 (for proxy respondents only), wave &c";*/
/*			dwordlag_&c = 0; label dwordlag_&c = "PRIOR wave TICS serial 7: 0-5 (for proxy respondents only), wave &c";*/
/*			*keep iqcodech as is;*/
/*		end;*/
/**/
/*		else if proxy_&b = 0 then do;*/
/*			proxylag_&c = 0;*/
/*			dateslag_&c = dates_&b;*/
/*			ticscount1lag_&c = ticscount1_&b;*/
/*			serial7lag_&c = serial7_&b;*/
/*			preslag_&c = pres_&b;*/
/*			iwordlag_&c = iword_&b;*/
/*			dwordlag_&c = dword_&b;*/
/*			iqcodech_&c = 0;*/
/*		end;*/
/*	end;*/
/*run;*/
/*%mend;*/
/*%lag (96, 93)*/
/*%lag (98, 96)*/
/*%lag (00, 98) */
/*%lag (02, 00) */
/*%lag (04, 02)*/
/*%lag (06, 04)*/
/*%lag (08, 06)*/
/*%lag (10, 08)*/
/*%lag (12, 10)*/
/*%lag (14, 12)*/

/*set up Wu regression variables*/
%macro reg (y);
data allvars; set allvars;
/*proxy - set self-response vars to 0*/
	if proxy_&y = 1 then do;
		tics13_&y = 0; 
		tics13sq_&y = 0; 
		iword_&y = 0; 
		iwordsq_&y = 0; 
		dword_&y = 0; 
		dword_m_&y = 0; 
	end;

/*self-response - set proxy vars to 0*/
	if proxy_&y = 0 then do;
		iqcode5_i_&y = 0;
		pr_memsc5_i_&y = 0;
		iqcode5_m_i_&y = 0;
	end;
run;
%mend;
%reg(93) 
%reg(96) %reg(98)
%reg(00) %reg(02)%reg(04) %reg(06)%reg(08)
%reg(10) %reg(12)%reg(14)


/*construct LKW proxy score*/
%macro lkw(y);
data allvars; set allvars;
	lkw_proxy_&y = iadl_&y + iwercog_i_&y + pr_memsc1_i_&y;
	label lkw_proxy_&y = "LKW proxy score (0-11, 2000-2016) in wave &y (components from RAND_p & raw HRS)";

	proc means; var lkw_proxy_&y;
run;
%mend;
%lkw(00) %lkw(02) %lkw(04) %lkw(06) %lkw(08)
%lkw(10) %lkw(12) %lkw(14) 

/*********************************************************
*
*	Assign dementia classifications
*
*********************************************************/
/********************
*
*	HW & LKW
*
*******************/
/*1993-1998*/
%macro dem(y);
data allvars; set allvars;
/*Herzog-Wallce*/
	if proxy_&y = 0 and hw_self_&y NE . then do;
		if hw_self_&y le 8 then do;
			hw_dem_&y = 1;
			hw_dem2_&y = 1;
		end;
		else do;
			hw_dem_&y = 0;
			hw_dem2_&y = 0;
		end;
	end;
	if proxy_&y = 1 and hw_proxy_i_&y NE . then do;
		if hw_proxy_i_&y ge 2 then hw_dem_&y = 1;
		else hw_dem_&y = 0;
	end;
	if proxy_&y = 1 and hw_proxy2_i_&y NE . then do;
		if hw_proxy2_i_&y ge 2 then hw_dem2_&y = 1;
		else hw_dem2_&y = 0;
	end;

	/*Langa-Kabeto-Weir*/
	if proxy_&y = 0 and lkw_self_&y NE . then do;
		if lkw_self_&y le 6 then lkw_dem_&y = 1;
		else lkw_dem_&y = 0;
	end;

	label hw_dem_&y  = "HW Dementia classification (proxy out of all available symptoms), wave &y";
	label hw_dem2_&y = "HW Dementia classification (proxy out of 5 consistently available symptoms), wave &y";
	label lkw_dem_&y = "LKW Dementia classification, wave &y";

run;
proc freq data=allvars; tables hw_dem_&y hw_dem2_&y  ;  where proxy_&y = 0; run;
proc freq data=allvars; tables hw_dem_&y hw_dem2_&y  ;  where proxy_&y = 1; run;
%mend;
%dem(93) %dem(96) 
*starting in 1998, pres/VP,cactus/scissors, dates (i.e. the additional items in HW) not asked of re-interviewees aged 65+5;
%dem(98)

/*2000-2016*/
%macro dem(y);
data allvars; set allvars;
/*Herzog-Wallce*/
	if proxy_&y = 0 and hw_self_&y NE . then do;
		if hw_self_&y le 8 then do;
			hw_dem_&y = 1;
			hw_dem2_&y = 1;
		end;
		else do;
			hw_dem_&y = 0;
			hw_dem2_&y = 0;
		end;
	end;
	if proxy_&y = 1 and hw_proxy_i_&y NE . then do;
		if hw_proxy_i_&y ge 2 then hw_dem_&y = 1;
		else hw_dem_&y = 0;
	end;
	if proxy_&y = 1 and hw_proxy2_i_&y NE . then do;
		if hw_proxy2_i_&y ge 2 then hw_dem2_&y = 1;
		else hw_dem2_&y = 0;
	end;
/*Langa-Kabeto-Weir*/
	if proxy_&y = 0 and lkw_self_&y NE . then do;
		if lkw_self_&y le 6 then lkw_dem_&y = 1;
		else lkw_dem_&y = 0;
	end;
	if proxy_&y = 1 and lkw_proxy_&y NE . then do;
		if lkw_proxy_&y ge 6 then lkw_dem_&y = 1;
		else lkw_dem_&y = 0;
	end;

	label hw_dem_&y  = "HW Dementia classification (proxy out of all available symptoms), wave &y";
	label hw_dem2_&y = "HW Dementia classification (proxy out of 5 consistently available symptoms), wave &y";
	label lkw_dem_&y = "LKW Dementia classification, wave &y";
run;
proc freq data=allvars; tables hw_dem_&y hw_dem2_&y lkw_dem_&y ;  where proxy_&y = 0; run;
proc freq data=allvars; tables hw_dem_&y hw_dem2_&y lkw_dem_&y ;  where proxy_&y = 1; run;
%mend;
%dem(00) %dem(02) %dem(04) %dem(06) %dem(08)
%dem(10) %dem(12) %dem(14) 

/********************
*
*	WU
*
*******************/
%macro reg(y);
data allvars; set allvars;
	wu_p_&y = (exp(4.608 + 1.889*proxy_&y + 0.933*iword_&y - 0.266*iwordsq_&y - 0.797*dword_&y - 1.075*tics13_&y + 0.043*tics13sq_&y + 2.220*iqcode5_i_&y + 1.096*pr_memsc5_i_&y 
					 - 0.854*male + 0.095*hrs_age70_&y - 0.695*black + 0.543*dword_m_&y +1.551*iqcode5_m_i_&y)) / 
			   (1 + (exp(4.608 + 1.889*proxy_&y + 0.933*iword_&y - 0.266*iwordsq_&y - 0.797*dword_&y - 1.075*tics13_&y + 0.043*tics13sq_&y + 2.220*iqcode5_i_&y + 1.096*pr_memsc5_i_&y 
					 - 0.854*male + 0.095*hrs_age70_&y - 0.695*black + 0.543*dword_m_&y +1.551*iqcode5_m_i_&y)));
	if wu_p_&y > 0.5 then wu_dem_&y = 1;
	else if wu_p_&y NE . then wu_dem_&y = 0;

	label wu_p_&y = "Wu Dementia probability, wave &y";
	label wu_dem_&y = "Wu Dementia classification, wave &y";
proc freq;
	tables wu_dem_&y;
	where hrs_age70_&y ge -0;
run;
%mend;
%reg(93) %reg(96) %reg(98)
%reg(00) %reg(02)%reg(04) %reg(06)%reg(08)
%reg(10) %reg(12)%reg(14) 

/***********************************************************************
*
*	CRIMMINS
*
*************************************************************************/
/*1993-1998*/
%macro reg(y);
data allvars; set allvars;
*SELF-RESPONSE;
	if proxy_&y = 0 then do;
		crim_ord_&y = exp(-8.3247 + log(1.2)*hrs_age_&y + log(1.02)*female + log(0.36)*lowedu_crim + log(0.45)*midedu_crim 
							 + log(0.73)*iword_&y + log(0.65)*dword_&y + log(0.68)*serial7_&y + log(0.6)*tics10_&y
							 + log(0.33)*dress_&y + log(1.30)*bath_&y + log(4.34)*eat_&y + log(9.72)*money_&y + log(2.38)*phone_&y) ;

		crim_orc_&y = exp(-3.7490 + log(1.11)*hrs_age_&y + log(0.92)*female + log(1.30)*lowedu_crim + log(0.76)*midedu_crim 
						 + log(0.80)*iword_&y + log(0.95)*dword_&y + log(0.83)*serial7_&y + log(0.67)*tics10_&y
						 + log(2.76)*dress_&y + log(0.96)*bath_&y + log(0.94)*eat_&y + log(3.90)*money_&y + log(0.61)*phone_&y);

		crim_p_&y = crim_ord_&y/(1 + crim_ord_&y + crim_orc_&y);
		if crim_p_&y > 0.5 then crim_dem_&y = 1;
		else if crim_p_&y NE . then crim_dem_&y = 0;

		label crim_p_&y = "Crimmins Dementia probability, wave &y";
		label crim_dem_&y = "Crimmins Dementia classification, wave &y";

	end;

	/*PROXY - not available before 2000 due to missing iwercog*/
	proc freq; tables crim_dem_&y;
		where hrs_age70_&y ge 0 and proxy_&y = 0;
run;
%mend;
%reg(93) %reg(96) %reg(98)


/*2000-2016*/
%macro reg(y);
data allvars; set allvars;
	if proxy_&y = 0 then do;
		crim_ord_&y = exp(-8.3247 + log(1.2)*hrs_age_&y + log(1.02)*female + log(0.36)*lowedu_crim + log(0.45)*midedu_crim 
							 + log(0.73)*iword_&y + log(0.65)*dword_&y + log(0.68)*serial7_&y + log(0.6)*tics10_&y
							 + log(0.33)*dress_&y + log(1.30)*bath_&y + log(4.34)*eat_&y + log(9.72)*money_&y + log(2.38)*phone_&y) ;

		crim_orc_&y = exp(-3.7490 + log(1.11)*hrs_age_&y + log(0.92)*female + log(1.30)*lowedu_crim + log(0.76)*midedu_crim 
						 + log(0.80)*iword_&y + log(0.95)*dword_&y + log(0.83)*serial7_&y + log(0.67)*tics10_&y
						 + log(2.76)*dress_&y + log(0.96)*bath_&y + log(0.94)*eat_&y + log(3.90)*money_&y + log(0.61)*phone_&y);

		crim_p_&y = crim_ord_&y/(1 + crim_ord_&y + crim_orc_&y);

		if crim_p_&y > 0.5 then crim_dem_&y = 1;
		else if crim_p_&y NE . then crim_dem_&y = 0;

		label crim_p_&y = "Crimmins Dementia probability, wave &y";
		label crim_dem_&y = "Crimmins Dementia classification, wave &y";

	end;

	*PROXY (use model 3 - no Jorm);
	if proxy_&y = 1 then do;
		crim_p_&y = (exp(-2.3448 + log(2.39)*pr_memsc1_i_&y + log(1.45)*iadl_&y + log(1.37)*iwercog_i_&y)) / (1 + (exp(-2.3448 + log(2.39)*pr_memsc1_i_&y + log(1.45)*iadl_&y + log(1.37)*iwercog_i_&y)));
		if crim_p_&y > 0.5 then crim_dem_&y = 1;
		else if crim_p_&y NE . then crim_dem_&y = 0;
	end;	
proc freq; tables crim_dem_&y;
	where hrs_age70_&y ge 0;
run;
%mend;
%reg(00) %reg(02) %reg(04) %reg(06) %reg(08)
%reg(10) %reg(12) %reg(14) 


/********************
*
*	HURD
*
*******************/
/*cannot use Hurd regression coefficients due to unpublished cut-points
	Use own re-estimated model instead*/

/*self*/
/*proc sql;*/
/*	create table temp as*/
/*	select **/
/*	from allvars, coef.hurd_self_coefficients_2018_0717*/
/*quit;*/
/**/
/*%macro reg(y);*/
/*data temp; set temp;*/
/*	if proxy_&y = 0 then do;*/
/*		hurd_sp_&y = probnorm(cut1 - (c_hagecat75*hagecat75_&y + c_hagecat80*hagecat80_&y + c_hagecat85*hagecat85_&y + c_hagecat90*hagecat90_&y*/
/*										+ c_midedu_hurd*midedu_hurd + c_highedu_hurd*highedu_hurd + c_female*female + c_adl*adl_&y + c_iadl*iadl_&y + c_adlch*adlch_&y + c_iadlch*iadlch_&y*/
/*										+ c_dates*dates_&y + c_ticscount1*ticscount1_&y + c_serial7*serial7_&y + c_scis*scis_&y + c_cact*cact_&y + c_pres*pres_&y + c_iword*iword_&y + c_dword*dword_&y*/
/*										+ c_datesch*datesch_&y + c_ticscount1ch*ticscount1ch_&y + c_serial7ch*serial7ch_&y + c_scisch*scisch_&y + c_cactch*cactch_&y + c_presch*presch_&y + c_iwordch*iwordch_&y + c_dwordch*dwordch_&y));*/
/*		if hurd_sp_&y > 0.5 then hurd_sdem_&y = 1;*/
/*		else if hurd_sp_&y NE . then hurd_sdem_&y = 0;*/
/*	end;*/
/**/
/*	label hurd_sp_&y = "Hurd Dementia probability (self), wave &y";*/
/*	label hurd_sdem_&y = "Hurd Dementia classification (self), wave &y";*/
/*run;*/
/**/
/*data allvars;*/
/*	merge allvars temp (keep = hhid pn hurd_sp_&y hurd_sdem_&y);*/
/*	by hhid pn;*/
/*	proc freq; tables hurd_sdem_&y;*/
/*run;*/
/*%mend;*/
/*%reg(96) %reg(98)*/
/*%reg(00) %reg(02)%reg(04) %reg(06)%reg(08)*/
/*%reg(10) %reg(12)%reg(14)*/

/*proxy*/
/*proc sql;*/
/*	create table temp as*/
/*	select **/
/*	from allvars, coef.hurd_prxy_coefficients_2018_0717*/
/*quit;*/
/**/
/*%macro reg(y);*/
/*data temp; set temp;*/
/*	if proxy_&y = 1 then do;*/
/*		hurd_pp_&y = probnorm(cut1 - (c_hagecat75*hagecat75_&y + c_hagecat80*hagecat80_&y + c_hagecat85*hagecat85_&y + c_hagecat90*hagecat90_&y*/
/*										+ c_midedu_hurd*midedu_hurd + c_highedu_hurd*highedu_hurd + c_female*female + c_adl*adl_&y + c_iadl*iadl_&y + c_adlch*adlch_&y + c_iadlch*iadlch_&y*/
/*										+ c_iqcode*iqcode_&y + c_proxylag*proxylag_&y + c_iqcodech*iqcodech_&y */
/*										+ c_dateslag*dateslag_&y + c_serial7lag*serial7lag_&y + c_preslag*preslag_&y + c_iwordlag*iwordlag_&y + c_dwordlag*dwordlag_&y));*/
/**/
/*		if hurd_pp_&y > 0.5 then hurd_pdem_&y = 1;*/
/*		else if hurd_pp_&y NE . then hurd_pdem_&y = 0;*/
/*	end;*/
/**/
/*	label hurd_pp_&y = "Hurd Dementia probability (proxy), wave &y";*/
/*	label hurd_pdem_&y = "Hurd Dementia classification (proxy), wave &y";*/
/*run;*/
/**/
/*data allvars;*/
/*	merge allvars temp (keep = hhid pn hurd_pp_&y hurd_pdem_&y);*/
/*	by hhid pn;*/
/**/
/*	proc freq; tables hurd_pdem_&y;*/
/*run;*/
/*%mend;*/
/*%reg(98)*/
/*%reg(00) %reg(02)%reg(04) %reg(06)%reg(08)*/
/*%reg(10) %reg(12)%reg(14)*/

/*consolidate self and proxy*/
/*96*/
/*%macro reg(y);*/
/*data allvars; set allvars;*/
/*	if proxy_&y = 0 then do; */
/*		hurd_p_&y = hurd_sp_&y; */
/*		hurd_dem_&y = hurd_sdem_&y;*/
/*	end;*/
/**/
/*	label hurd_p_&y = "Hurd Dementia probability, wave &y";*/
/*	label hurd_dem_&y = "Hurd Dementia classification, wave &y";*/
/**/
/*	drop hurd_sp_&y hurd_sdem_&y;*/
/*run;*/
/**/
/*proc means; var wu_dem_&y crim_dem_&y hurd_dem_&y; where proxy_&y = 0; run;*/
/*proc means; var wu_dem_&y crim_dem_&y hurd_dem_&y; where proxy_&y = 1; run;*/
/*%mend;*/
/*%reg(96) */
/**/
/*%macro reg(y);*/
/*data allvars; set allvars;*/
/*	if proxy_&y = 0 then do; */
/*		hurd_p_&y = hurd_sp_&y; */
/*		hurd_dem_&y = hurd_sdem_&y; */
/*	end;*/
/*	if proxy_&y = 1 then do; */
/*		hurd_p_&y = hurd_pp_&y; */
/*		hurd_dem_&y = hurd_pdem_&y; */
/*	end;*/
/**/
/*	label hurd_p_&y = "Hurd Dementia probability, wave &y";*/
/*	label hurd_dem_&y = "Hurd Dementia classification, wave &y";*/
/**/
/*	drop hurd_sp_&y hurd_sdem_&y hurd_pp_&y hurd_pdem_&y;*/
/*run;*/
/**/
/*proc means; var wu_dem_&y crim_dem_&y hurd_dem_&y; where proxy_&y = 0; run;*/
/*proc means; var wu_dem_&y crim_dem_&y hurd_dem_&y; where proxy_&y = 1; run;*/
/*%mend;*/
/*%reg(98)*/
/*%reg(00) %reg(02)%reg(04) %reg(06)%reg(08)*/
/*%reg(10) %reg(12)%reg(14)*/
/**/
/*proc contents data=allvars; run;*/
/****************************************
*
*	Construct final dataset
*
***************************************/
data allvars; set allvars;
/*	hurd_p_93 = .;*/
/*	hurd_dem_93 = .;*/
	lkw_proxy_93 = .;
	lkw_proxy_96 = .;
	lkw_proxy_98 = .;
run;

%macro final(y);
data allvars; set allvars;
	label inw_&y = "Indicator for survey participation: 1=Yes, 0=No, wave &y";
	label proxy_&y = "Indicator for proxy-respondant: 1=Proxy-repsondent, 0=Self-respondent, wave &y";
run;

data w&y; 
set allvars (keep = hhid pn inw_&y proxy_&y hrs_age_&y NH_white NH_black hispanic 
		   hw_self_&y hw_proxy_&y hw_proxy2_&y hw_dem_&y hw_dem2_&y 
		   lkw_self_&y lkw_proxy_&y lkw_dem_&y
/*		   hurd_p_&y hurd_dem_&y*/
		   crim_p_&y crim_dem_&y
		   wu_p_&y wu_dem_&y);
run;
data w&y; 
	retain hhid pn inw_&y proxy_&y 
		   hw_self_&y hw_proxy_&y hw_proxy2_&y hw_dem_&y hw_dem2_&y 
		   lkw_self_&y lkw_proxy_&y lkw_dem_&y
/*		   hurd_p_&y hurd_dem_&y*/
		   crim_p_&y crim_dem_&y
		   wu_p_&y wu_dem_&y;
	set  w&y;
run;

%mend;
%final(93)%final(96)%final(98)
%final(00)%final(02)%final(04)%final(06)%final(08)
%final(10)%final(12)%final(14)


*keep 2000-2014;
data HRSPredictedDementia;
	merge w00 w02 w04 w06 w08 w10
		  w12 w14;
	by hhid pn;

	proc contents;
run;

%macro see (y);
proc means data=HRSPredictedDementia;
	var hw_self_&y hw_proxy_&y hw_proxy2_&y hw_dem_&y hw_dem2_&y 
		   lkw_self_&y lkw_proxy_&y lkw_dem_&y
/*		   hurd_p_&y hurd_dem_&y*/
		   crim_p_&y crim_dem_&y
		   wu_p_&y wu_dem_&y;
	where proxy_&y = 0;
run;
proc means data=HRSPredictedDementia;
	var hw_self_&y hw_proxy_&y hw_proxy2_&y hw_dem_&y hw_dem2_&y 
		   lkw_self_&y lkw_proxy_&y lkw_dem_&y
/*		   hurd_p_&y hurd_dem_&y*/
		   crim_p_&y crim_dem_&y
		   wu_p_&y wu_dem_&y;
	where proxy_&y = 1;
run;
%mend;
%see(00) %see(02) %see(04) %see(06) %see(08) %see(10) 
%see(12) %see(14) 


%macro see (y);
title "&y";
proc means data=hrspredicteddementia;
	var hw_dem_&y lkw_dem_&y crim_dem_&y wu_dem_&y;
	where hrs_age_&y ge 0 and wu_dem_&y NE .;
run;
proc means data=hrspredicteddementia;
	var hw_dem_&y lkw_dem_&y crim_dem_&y wu_dem_&y;
	where hrs_age_&y ge 0 and proxy_&y = 0 and wu_dem_&y NE .;
run;
proc means data=hrspredicteddementia;
	var hw_dem_&y lkw_dem_&y crim_dem_&y wu_dem_&y;
	where hrs_age_&y ge 0 and proxy_&y = 1 and wu_dem_&y NE .;
run;
%mend;
%see(00) %see(02) %see(04) %see(06)%see(08) %see(10) 
%see(12) %see(14)

proc means data=allvars;
	var hw_proxy_00 hw_proxy_02 hw_proxy_04;
run; 

*convert to long, drop age < 70, and save;
%macro long(y);
data long_&y; set hrspredicteddementia (keep = hhid pn hrs_age_&y 
											   lkw_self_&y lkw_proxy_&y lkw_dem_&y
											   hw_self_&y hw_proxy_&y hw_dem_&y hw_proxy2_&y hw_dem2_&y
											   wu_p_&y wu_dem_&y
											   crim_p_&y crim_dem_&y);
	rename lkw_self_&y = lkw_self;
	rename lkw_proxy_&y = lkw_proxy;
	rename lkw_dem_&y = lkw_dem;
	rename hw_self_&y = hw_self;
	rename hw_proxy_&y = hw_proxy;
	rename hw_dem_&y = hw_dem;
	rename hw_proxy2_&y = hw_proxy2;
	rename hw_dem2_&y = hw_dem2;
	rename wu_p_&y = wu_p;
	rename wu_dem_&y = wu_dem;
	rename crim_p_&y = crim_p;
	rename crim_dem_&y = crim_dem;

	if hrs_age_&y < 70 then delete;

	hrs_year = 2000 + &y;

	drop hrs_age_&y;
run;
%mend;
%long(00) %long(02) %long(04) %long(06) %long(08) %long(10) %long(12) %long(14)

data long_all;
	set long_00 long_02 long_04 long_06 long_08 long_10 long_12 long_14;
	proc sort;
		by hhid pn hrs_year;
run;

data hrs.hrsdem_existingalg_2019_0110; set long_all ;
run;
