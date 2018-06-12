libname adams 'F:\power\HRS\ADAMS Wave A';
libname atrk 'F:\power\HRS\ADAMS CrossWave';
libname x 'F:\power\HRS\DerivedData\AD_Disparities_AlgorithmDev\Data 2018_0105'; /*derived hrs files*/
libname hrs 'F:\power\HRS\HRS data (raw)\SAS datasets'; /*raw hrs files, including Hurd probabilities*/
libname rand 'F:\power\HRS\RAND_HRS\sasdata';
options fmtsearch = (rand.formats);

*set date for output label;
%let dt=2018_0117;

/*********************************************************************************************
* Created for compiling final standardized dataset, to be divided into "training" and "validation" datasets
*	Compiles/creates variables from RAND Verion P and Hurd author-provided dementia probabilities
*
* Extract and construct self-response cognition, dem, and ADL/IADLvariables from RAND (version p) for:
*		- Wu 
*		- Crimmins
*		- Hurd
*		- Herzog-Wallace
*		- Langa-Weir
*
* For Hurd: 
*	- create change in ADL/IADL over prior 2 waves for all
*	- create change in TICS items scores for those with self-response across both prior waves
*
* Derive dementia status for:
*	- Hurd waves A, B, C, partial D (merge in derived probabilties)
*	- Langa-Weir
*	- Herzog-Wallace
*
**********************************************************************************************/
/**/
/*proc contents data=rand.rndhrs_p; run; proc freq data=rand.rndhrs_p; tables raracem rahispan; run;*/

/************************************************************
*
*	1. Extract and construct time-invariant variables
*
*************************************************************/

data base; set rand.rndhrs_p (keep = hhidpn hhid pn hacohort ragender 
									 raedegrm raedyrs /*Hurd-EdDegree, Crimmins-EdYrs*/
									 raracem /*1=White, 2=Black/AA, 3=Other*/
									 rahispan); /*0=NotHispanic, 1=Hispanic*/

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

	/*hispanic v non-hispanic (ref) */
	if rahispan = 1 then hispanic =1; 
	if rahispan = 0 then hispanic =0;
	label hispanic = "0=non-Hispanic, 1=hispanic";

	/*4-level race/ethnicity - non-Hispanic black, non-Hispanic white (ref), Hispanic, non-Hispanic other*/
	if rahispan = 0 then do;
		if raracem = 1 then raceeth4=0; *NH white;
		else if raracem = 2 then raceeth4=1; *NH black;
		else if raracem = 3 then raceeth4=3; *NH other;
		end;
	else if rahispan = 1 then raceeth4=2; *hispanic;
	label raceeth4 = '0=NH white, 1=NH black, 2=Hispanic, 3=NH other';
		/*Note: codes those missing race (RARACEM = .M) as NH_black/NH_white = 0 as long as RAHISPAN = 1*/

	if raceeth4 = 0 then NH_white = 1; else if raceeth4 ne . then NH_white=0;
	if raceeth4 = 1 then NH_black = 1; else if raceeth4 ne . then NH_black=0;
	*don't need dummy for hispanic, created above;
	if raceeth4 = 3 then NH_other = 1; else if raceeth4 ne . then NH_other=0;
	label NH_white = 'indicator non-hispanic white';
	label NH_black = 'indicator non-hispanic black';
	label NH_other = 'indicator non-hispanic other race';

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
run;

/**check coding;*/
/*proc freq data=base;*/
/*	tables ragender male female/missing;*/
/*	tables raracem rahispan raracem*rahispan raceeth4 black NH_white NH_black hispanic NH_other/missing;*/
/*	tables raedegrm edu_hurd raedyrs edu_crim/missing;*/
/*run; */
/*proc print data=base (obs=10);*/
/*	var raracem rahispan black NH_white NH_black hispanic NH_other raceeth4; where NH_white NE . and (raracem = .M or rahispan = .M); */
/*run;*/

/************************************************************
*
*	2.  Extract and create derived RAND variables for Wave 3 (1996) to Wave 9 (2008)
*
*************************************************************/

%macro ext (w, y);
/*extract*/
	data wave_&y; 
	set rand.rndhrs_p 
	(keep = hhidpn hhid pn inw&w
		r&w.agey_e /*age in years - at end of interview month*/
		r&w.iwendy r&w.iwendm /*interview end month and year*/
		r&w.proxy /*indicator for proxy interview*/

/*Cognition for self-respondents: TICS items*/
		r&w.mo r&w.dy r&w.yr r&w.dw /* Wu/Hurd TICS date naming - for each one: 0=Incorrect, 1=Correct */
		r&w.bwc20 /* Wu/Hurd/Crimmins TICS serial backwards count 0=Incorrect, 1=CorrectTry2, 2=CorretTry1 */
		r&w.ser7 /* Wu/Hurd/Crimmins: TICS serial 7's 0-5 */
		r&w.cact r&w.pres /*Wu/Hurd: TICS object & president naming - for each one: 0=Incorrect, 1=Correct */
		r&w.vp /*Wu: TICS VP naming - 0=Incorrect, 1=Correct*/
		r&w.scis /*Hurd: TICS object naming - 0=Incorrect, 1=Correct */
		r&w.imrc /* Wu/Hurd/crimmins:immediate word recall - 0-10 */
		r&w.dlrc /* Wu/Hurd/crimmins: delayed word recall 0-10 */
		r&w.tr20 /*Not available waves 1/2 - Total imm/del word recall*/
		r&w.mstot /*Not available for wave1/2 - Mental status index (0-15)Sum score of: counting, naming, vocab tasks)*/
		r&w.cogtot /*Not available waves 1/2 H-W/PotentiallyCRIMMINSAlgTICS - Sum word recall and mental status scores (0-35) */

/*rW[adl]a variables not available w1, inconsistent waves 2/2H/3 in how qustions are asked/skipped 
wave 3 onwards: set to 1=Yes if respondent says "yes" or "can't do" to "any dificulty..." question, 
set to 1=Yes if question about "getting help with ADL" is "yes" and response to any difficulty was "don't do, don't know, refuse"

rW[iadl]a variables not available in w1, inconsistent in wording for wave
wave 3 onwards: set to 1=Yes if "yes" to "any difficulty..." question,
				set to 1=Yes if "don't do"/"can't do" BECAUSE OF A HEALTH PROBLEM
				set to .X if "don't do"/"can't do" for some other reason 

for both [adl/iadl]a - coded .X (don't do) if it is not revealed whethr respondent would have difficulty 
if they were to do the activity*/
							  
/*ADL's - starting wave 2 - Hurd manuscript (p.1327) specifically names the following 6 ADL's, 
though it is unclear whether they end up using this construction or a 0-5 count (presumably dropping toileting) as labeled in Table S1*/					  
		r&w.walkra /*Hurd: 0=No, 1=Yes*/
		r&w.dressa /*Hurd/Crimmins: 0=No, 1=Yes*/ 
		r&w.batha /*Hurd/Crimmins: 0=No, 1=Yes*/
		r&w.eata /*Hurd/Crimmins: 0=No, 1=Yes*/
		r&w.beda /*Hurd: 0=No, 1=Yes*/
		r&w.toilta /*Not available wave 2H - Hurd?: 0=No, 1=Yes*/

		r&w.adla /*RAND constructed ADL's (0-5) - walk, dress, bath, eat, bed. 
		Uses function sum(walkra...bedra) 
		- i.e. if any of the functions have a DK/NA/Missing/RF/Skip/Don't do code, they would be counted as NOT 
		having that difficulty is sum score  */
		r&w.adlc /*RAND constructed change in r&w.adla - construction on p.654*/
		r&w.adlf /*RAND flag for missed interviews prior to current*/

/*IADL's - not available wave 1/2H*/
		r&w.mealsa  /*Hurd/Crimmins: 0=No, 1=Yes*/
		r&w.shopa  /*Hurd/Crimmins: 0=No, 1=Yes*/
		r&w.phonea  /*Hurd/Crimmins: 0=No, 1=Yes*/
		r&w.medsa  /*Hurd/Crimmins: 0=No, 1=Yes, .Z = "don't do, but woudln't have difficulty if did"*/
		r&w.moneya /*Hurd/Crimmins: 0=No, 1=Yes*/
		r&w.iadlza); /*RAND constructed IADL's (0-5) not available wave 2H - phone money meds shop meals 
		Uses sum(phonea...mealsa)
		- i.e. if any of the functions have a DK/NA/Missing/RF/Skip/Don't do code, they would be counted as NOT 
		having that difficulty is sum score*/

*create user-friendly variable names and labels;
	rename r&w.agey_e = hrs_age_&y; label r&w.agey_e = "age at end of interview month y&y";
	rename r&w.iwendy = iweyr_&y; label r&w.iwendy = "interview end year y&y";
	rename r&w.iwendm = iwemo_&y; label r&w.iwendm = "interview end month y&y";
	rename r&w.proxy = proxy_&y; label r&w.proxy = "proxy indicator &y";
	rename inw&w = inw_&y; label inw&w = "indicator for completing interview &y";

	rename r&w.mo = ticsmonth_&y; label r&w.mo = "TICS date naming-month: 0=Incorrect, 1=Correct y&y";
	rename r&w.dy = ticsdate_&y; label r&w.dy = "TICS date naming-date: 0=Incorrect, 1=Correct y&y";
	rename r&w.yr = ticsyear_&y; label r&w.yr = "TICS date naming-year: 0=Incorrect, 1=Correct y&y";
	rename r&w.dw = ticsweek_&y; label r&w.dw = "TICS date naming-day of week: 0=Incorrect, 1=Correct y&y";
	rename r&w.bwc20 = ticscount_&y; label r&w.bwc20 = "TICS backwards counting 20: 0=Incorrect, 1=CorrectTry2, 2=CorrectTry1 y&y";
	rename r&w.ser7 = serial7_&y; label r&w.ser7 = "TICS serial 7: 0-5 y&y";
	rename r&w.cact = cact_&y; label r&w.cact = "TICS object naming (cactus): 0=Incorrect, 1=Correct y&y";
	rename r&w.scis = scis_&y; label r&w.scis = "TICS object naming (scissors): 0=Incorrect, 1=Correct y&y";
	rename r&w.pres = pres_&y; label r&w.pres = "TICS name president: 0=Incorrect, 1=Correct y&y";
	rename r&w.vp = vp_&y; label r&w.vp = "TICS name vice-president: 0=Incorrect, 1=Correct y&y";
	rename r&w.imrc = iword_&y; label r&w.imrc = "immediate word recall: 0-10 y&y";
	rename r&w.dlrc = dword_&y; label r&w.dlrc = "delayed word recall: 0-10 y&y";
	rename r&w.tr20 = idword_&y; label r&w.tr20 = "immediate + delayed word recall: 0-20 y&y";
	rename r&w.mstot = mstot_&y; label r&w.mstot = "RAND sum counting, naming, vocab scores: 0-15 y&y";
	rename r&w.cogtot = cogtot_&y; label r&w.cogtot = "RAND cognition total, Potentially CRIMMINS TICS: 0-35 y&y";

	rename r&w.walkra = walk_&y; label r&w.walkra = "ADL walk across room: 0=No Difficulty, 1=Difficulty, .X = Don't do (and did not indicate needing help) y&y";
	rename r&w.dressa = dress_&y; label r&w.dressa = "ADL get dressed: 0=No Difficulty, 1=Difficulty, .X = Don't do (and did not indicate needing help) y&y";
	rename r&w.batha = bath_&y; label r&w.batha = "ADL bathing: 0=No Difficulty, 1=Difficulty, .X = Don't do (and did not indicate needing help) y&y";
	rename r&w.eata = eat_&y; label r&w.eata = "ADL eating: 0=No Difficulty, 1=Difficulty, .X = Don't do (and did not indicate needing help) y&y";
	rename r&w.beda = bed_&y; label r&w.beda = "ADL getting in/out of bed: 0=No Difficulty, 1=Difficulty, .X = Don't do (and did not indicate needing help) y&y";
	rename r&w.toilta = toilet_&y; label r&w.toilta = "ADL toileting: 0=No Difficulty, 1=Difficulty, .X = Don't do (and did not indicate needing help) y&y";
	rename r&w.adla = adl5_&y; label r&w.adla = "RAND total ADL's (counts all missing codes as not having difficulty: 0-5 y&y";
	rename r&w.adlc = adl5ch_&y; label r&w.adlc = "RAND constructed chnage in ADL's out of 5 y&y";
	rename r&w.adlf = pwavemiss_&y; label r&w.adlf = "Number missed interviews prior to current wave (based on rWadlf) y&y ";

	rename r&w.mealsa = meals_&y; label r&w.mealsa = "IADL preparing meals: 0=No Difficulty, 1=Difficulty, .X = Don't do (and NOT b/c health reason) y&y";
	rename r&w.shopa = shop_&y; label r&w.shopa = "IADL shop for groceries: 0=No Difficulty, 1=Difficulty, .X = Don't do(and NOT b/c health reason) y&y";
	rename r&w.phonea = phone_&y; label r&w.phonea = "IADL using phone: 0=No Difficulty, 1=Difficulty, .X = Don't do (and NOT b/c health reason) y&y";
	rename r&w.medsa = meds_&y; label r&w.medsa = "IADL taking meds: 0=No Difficulty, 1=Difficulty, .X = Don't do (and NOT b/c health reason), .Z = wouldn't have difficulty if taking meds y&y";
	rename r&w.moneya = money_&y; label r&w.moneya = "IADL managing finances: 0=No Difficulty, 1=Difficulty, .X = Don't do (and NOT b/c health reason) y&y";
	rename r&w.iadlza = iadl5_&y; label r&w.iadlza = "RAND total IADL's (counts all missing codes as not having difficulty: 0-5 y&y";
run;


/*construct wide dataset and derive necessary variables*/
proc sort data=base; by hhid pn;
proc sort data=wave_&y; by hhid pn; run;

data wave_&y; 
	merge base wave_&y ;
	by hhid pn;

	/*for taking meds, replace .Z (Don't do, but wouldn't have difficulty if did) as 0*/
	if meds_&y = .Z then meds_&y = 0;

	/*Create derived variables needed for WU et al. algorithm*/
	hrs_age70_&y = hrs_age_&y - 70; 
		label hrs_age70_&y = "Age at interview centered at 70 (for Wu alg) y&y";
	tics13_&y = ticsmonth_&y + ticsdate_&y + ticsweek_&y + ticsyear_&y + cact_&y + pres_&y + vp_&y + serial7_&y + (ticscount_&y = 2); /*0-13;  only counts first attempt at backward counting*/
		label tics13_&y = "TICS13 derivation for Wu algorithm:0-13 y&y";
	tics13sq_&y = tics13_&y * tics13_&y; 
		label tics13sq_&y = "TICS13_squared for Wu algorithm: 0-169 y&y";
	iwordsq_&y = iword_&y * iword_&y; 
		label iwordsq_&y = "iword_squared for Wu algorithm: 0-100 y&y";
	dword_m_&y = dword_&y * male; 
		label dword_m_&y = "DelayedWord x Male Interaction for Wu algorithm: 0-10 y&y";

	/*HURD*/
	dates_&y = ticsmonth_&y + ticsdate_&y + ticsweek_&y + ticsyear_&y; 
		label dates_&y = "Hurd dates test (0-4) y&y";
	/***********uncertain whether Hurd uses totADL of 0-5 (as in RAND), or totADL of 0-6 (RAND + toiletin), create alternative version using same method as RAND*/
	adl6_&y = sum(walk_&y, dress_&y, bath_&y, eat_&y, bed_&y, toilet_&y); 
		label adl6_&y = "Hurd ADL's (RAND 5 + toilet, count all missing codes as not having difficulty): 0-6 y&y";
	/***********based on Table S1 MeanBackwardCount suggests 0-1 scale rather than 0-2. Uncertain whether 2nd attempt is counted, create 2 versions*/
	if ticscount_&y = 2 then ticscount1_&y = 1; else if ticscount_&y in (0, 1) then ticscount1_&y = 0; 
		label ticscount1_&y = "BackwardsCount: 1=Correct 1st attempt ONLY, 0=Incorrect 1st, Incorrect or Correct 2nd attempt y&y";
	if ticscount_&y in (1, 2) then ticscount1or2_&y = 1; else if ticscount_&y = 0 then ticscount1or2_&y = 0; 
		label ticscount1or2_&y = "BackwardsCount: 1=Correct 1st OR 2nd attempt, 0=Incorrect y&y";
	hagecat_&y = 1 + (hrs_age_&y ge 75) + (hrs_age_&y ge 80) + (hrs_age_&y ge 85) + (hrs_age_&y ge 90);
		label hagecat_&y  = "Hurd HRS age category 1=<75, 2=75-79, 3=80-84, 4=85-89, 5=90+ y&y";

	/*Langa-Weir total cognition score*/
	cogsc27_&y = iword_&y + dword_&y + serial7_&y + ticscount_&y; label cogsc27_&y = "L-W cognition continuous: 0-27 y&y";
run;

%mend;


/*extract/create for waves 3(1996) - 9(2008)*/

%ext(3, 96)  %ext(4, 98) %ext(5, 00) %ext(6, 02) %ext(7, 04) %ext(8, 06) %ext(9, 08)

/*check variable constructions*/
/*proc freq data=wave_96;*/
/*	tables tics13_96 cogsc27_96 adl6_96 hrs_age_96*hagecat_96;*/
/*	where inw_96 = 1 and hrs_age_96 ge 65; *memory items not asked of those age < 65;*/
/*run;*/
/*proc freq data=wave_96;*/
/*	where inw_96 = 1 and hrs_age_96 ge 65 and (tics13_96 = . or cogsc27_96 = .);*/
/*	tables proxy_96;*/
/*run; *all proxies;*/
/*proc print data=wave_96 (obs = 50);*/
/*	var ticsmonth_96 ticsdate_96 ticsyear_96 ticsweek_96 cact_96 pres_96 vp_96 serial7_96 ticscount_96 tics13_96 tics13sq_96 iword_96 iwordsq_96 dword_96 dword_m_96 male;*/
/*	*where hrs_age_96 ge 65;*/
/*	where hrs_age_96 ge 65 and ticscount_96 = 1;*/
/*run;*/
/*proc print data =wave_96 (obs = 50);*/
/*	var ticsmonth_96 ticsdate_96 ticsyear_96 ticsweek_96 dates_96 walk_96 dress_96 bath_96 eat_96 bed_96 toilet_96 adl5_96 adl6_96 ticscount_96 ticscount1_96 ticscount1or2_96; */
/*	*where hrs_age_96 ge 65;*/
/*	where toilet_96 = 1 and ticscount_96 = 1;*/
/*run;*/
/*proc print data=wave_96 (obs = 50); */
/*	var iword_96 dword_96 serial7_96 ticscount_96 cogsc27_96;*/
/*	*where hrs_age_96 ge 65 ;*/
/*	where hrs_age_96 ge 65 and ticscount_96 = 1;*/
/*run;*/

/*earliest wave used will be 2000 - check frequency of pwavemiss (marker of how far back needed to go for RAND derived 
change in ADL variables - necessary because repeating logic for other variables later)*/

/*proc freq data=wave_00; tables pwavemiss_00; run;*/

/*N=42 with pwavemiss_00 = 3 -> missed 3 interviews, used change = current-(current-4), i.e. w5(2000)-w1(1992)
-> would need to extract waves 1 & 2 as well for purposes to calculating change vars for Hurd
		HOWEVER:
			full IADLS's not available in wave 2H
			cognition not asked in waves 1 or 2H 
No need to extract wave 1 due to missing IADL/cogn -> 
************Could these be the obs that are missing a probability score in Hurd?*/


/************************************************************
*
*	3.  Extract and create derived RAND variables for Wave 2 (1994) for use in getting change since prior for Hurd
*
*************************************************************/


/*%ext (2, 94) ;*/
/*wave 2 has certain different variable names -> rewrite*/

%macro ext2 (w, y);
/*extract*/
	data wave_&y; 
	set rand.rndhrs_p 
	(keep = hhidpn hhid pn inw&w
			r&w.agey_e /*age in years - at end of interview month*/
			r&w.iwendy r&w.iwendm /*interview end month and year*/
			r&w.proxy /*indicator for proxy interview*/

/*Cognition for self-respondents: TICS items*/
			r&w.mo r&w.dy r&w.yr r&w.dw /* Wu/Hurd TICS date naming - for each one: 0=Incorrect, 1=Correct */
			r&w.bwc20 /* Wu/Hurd/Crimmins TICS serial backwards count 0=Incorrect, 1=CorrectTry2, 2=CorretTry1 */
			r&w.ser7 /* Wu/Hurd/Crimmins: TICS serial 7's 0-5 */
			r&w.cact r&w.pres /*Wu/Hurd: TICS object & president naming - for each one: 0=Incorrect, 1=Correct */
			r&w.vp /*Wu: TICS VP naming - 0=Incorrect, 1=Correct*/
			r&w.scis /*Hurd: TICS object naming - 0=Incorrect, 1=Correct */
			r&w.aimr10 /* Wu/Hurd/crimmins:immediate word recall - 0-10 */
			r&w.adlr10 /* Wu/Hurd/crimmins: delayed word recall 0-10 */
			r&w.atr20 /*Not available waves 1/2 - Total imm/del word recall*/
			r&w.amstot /*Not available for wave1/2 - Mental status index (0-15)Sum score of: counting, naming, vocab tasks)*/
			r&w.acgtot /*Not available waves 1/2 H-W/PotentiallyCRIMMINSAlgTICS - Sum word recall and mental status scores (0-35) */

/*rW[adl]a variables not available w1, inconsistent waves 2/2H/3 in how qustions are asked/skipped */

/*ADL's - starting wave 2 */					  
			r&w.walkra /*Hurd: 0=No, 1=Yes*/
			r&w.dressa /*Hurd/Crimmins: 0=No, 1=Yes*/ 
			r&w.batha /*Hurd/Crimmins: 0=No, 1=Yes*/
			r&w.eata /*Hurd/Crimmins: 0=No, 1=Yes*/
			r&w.beda /*Hurd: 0=No, 1=Yes*/
			r&w.toilta /*Not available wave 2H - Hurd: 0=No, 1=Yes*/
			r&w.adla /*RAND constructed ADL's (0-5) - walk, dress, bath, eat, bed. 
				Uses function sum(walkra...bedra) 
				- i.e. if any of the functions have a DK/NA/Missing/RF/Skip/Don't do code, they would be counted as 
			NOT having that difficulty is sum score  */

/*IADL's - not available wave 1/2H*/
			r&w.mealsa  /*Hurd/Crimmins: 0=No, 1=Yes*/
			r&w.shopa  /*Hurd/Crimmins: 0=No, 1=Yes*/
			r&w.phonea  /*Hurd/Crimmins: 0=No, 1=Yes*/
			r&w.medsa  /*Hurd/Crimmins: 0=No, 1=Yes, .Z = "don't do, but woudln't have difficulty if did"*/
			r&w.moneya /*Hurd/Crimmins: 0=No, 1=Yes*/
			r&w.iadlza); /*RAND constructed IADL's (0-5) not available wave 2H - phone money meds shop meals 
				Uses sum(phonea...mealsa)
				- i.e. if any of the functions have a DK/NA/Missing/RF/Skip/Don't do code, they would be counted as 
			NOT having that difficulty is sum score*/

	rename r&w.agey_e = hrs_age_&y; label r&w.agey_e = "age at end of interview month y&y";
	rename r&w.iwendy = iwemo_&y; label r&w.iwendy = "interview end month y&y";
	rename r&w.iwendm = iweyr_&y; label r&w.iwendm = "interview end year y&y";
	rename r&w.proxy = proxy_&y; label r&w.proxy = "proxy indicator &y";
	rename inw&w = inw_&y; label inw&w = "indicator for completing interview &y";

	rename r&w.mo = ticsmonth_&y; label r&w.mo = "TICS date naming-month: 0=Incorrect, 1=Correct y&y";
	rename r&w.dy = ticsdate_&y; label r&w.dy = "TICS date naming-date: 0=Incorrect, 1=Correct y&y";
	rename r&w.yr = ticsyear_&y; label r&w.yr = "TICS date naming-year: 0=Incorrect, 1=Correct y&y";
	rename r&w.dw = ticsweek_&y; label r&w.dw = "TICS date naming-day of week: 0=Incorrect, 1=Correct y&y";
	rename r&w.bwc20 = ticscount_&y; label r&w.bwc20 = "TICS backwards counting 20: 0=Incorrect, 1=CorrectTry2, 2=CorrectTry1 y&y";
	rename r&w.ser7 = serial7_&y; label r&w.ser7 = "TICS serial y: 0-5 y&y";
	rename r&w.cact = cact_&y; label r&w.cact = "TICS object naming (cactus): 0=Incorrect, 1=Correct y&y";
	rename r&w.scis = scis_&y; label r&w.scis = "TICS object naming (scissors): 0=Incorrect, 1=Correct y&y";
	rename r&w.pres = pres_&y; label r&w.pres = "TICS name president: 0=Incorrect, 1=Correct y&y";
	rename r&w.vp = vp_&y; label r&w.vp = "TICS name vice-president: 0=Incorrect, 1=Correct y&y";
	rename r&w.aimr10 = iword_&y; label r&w.aimr10 = "immediate word recall: 0-10 y&y";
	rename r&w.adlr10 = dword_&y; label r&w.adlr10 = "delayed word recall: 0-10 y&y";
	rename r&w.atr20 = idword_&y; label r&w.atr20 = "immediate + delayed word recall: 0-20 y&y";
	rename r&w.amstot = mstot_&y; label r&w.amstot = "RAND sum counting, naming, vocab scores: 0-15 y&y";
	rename r&w.acgtot = cogtot_&y; label r&w.acgtot = "RAND cognition total, Potentially CRIMMINS TICS: 0-35 y&y";

	rename r&w.walkra = walk_&y; label r&w.walkra = "ADL walk across room: 0=No Difficulty, 1=Difficulty, .X = Don't do (and did not indicate needing help) y&y";
	rename r&w.dressa = dress_&y; label r&w.dressa = "ADL get dressed: 0=No Difficulty, 1=Difficulty, .X = Don't do (and did not indicate needing help) y&y";
	rename r&w.batha = bath_&y; label r&w.batha = "ADL bathing: 0=No Difficulty, 1=Difficulty, .X = Don't do (and did not indicate needing help) y&y";
	rename r&w.eata = eat_&y; label r&w.eata = "ADL eating: 0=No Difficulty, 1=Difficulty, .X = Don't do (and did not indicate needing help) y&y";
	rename r&w.beda = bed_&y; label r&w.beda = "ADL getting in/out of bed: 0=No Difficulty, 1=Difficulty, .X = Don't do (and did not indicate needing help) y&y";
	rename r&w.toilta = toilet_&y; label r&w.toilta = "ADL toileting: 0=No Difficulty, 1=Difficulty, .X = Don't do (and did not indicate needing help) y&y";
	rename r&w.adla = adl5_&y; label r&w.adla = "RAND total ADL's (counts all missing codes as not having difficulty: 0-5 y&y";

	rename r&w.mealsa = meals_&y; label r&w.mealsa = "IADL preparing meals: 0=No Difficulty, 1=Difficulty, .X = Don't do (and NOT b/c health reason) y&y";
	rename r&w.shopa = shop_&y; label r&w.shopa = "IADL shop for groceries: 0=No Difficulty, 1=Difficulty, .X = Don't do(and NOT b/c health reason) y&y";
	rename r&w.phonea = phone_&y; label r&w.phonea = "IADL using phone: 0=No Difficulty, 1=Difficulty, .X = Don't do (and NOT b/c health reason) y&y";
	rename r&w.medsa = meds_&y; label r&w.medsa = "IADL taking meds: 0=No Difficulty, 1=Difficulty, .X = Don't do (and NOT b/c health reason), .Z = wouldn't have difficulty if taking meds y&y";
	rename r&w.moneya = money_&y; label r&w.moneya = "IADL managing finances: 0=No Difficulty, 1=Difficulty, .X = Don't do (and NOT b/c health reason) y&y";
	rename r&w.iadlza = iadl5_&y; label r&w.iadlza = "RAND total IADL's (counts all missing codes as not having difficulty: 0-5 y&y";
run;


/*construct*/

proc sort data=base; by hhid pn;
proc sort data=wave_&y; by hhid pn; run;

data wave_&y; 
	merge base wave_&y ;
	by hhid pn;

	/*for taking meds, replace .Z (Don't do, but wouldn't have difficulty if did) as 0*/
	if meds_&y = .Z then meds_&y = 0;

	/*WU*/
	hrs_age70_&y = hrs_age_&y - 70; 
		label hrs_age70_&y = "Age at interview centered at 70 (for Wu alg) y&y";
	tics13_&y = ticsmonth_&y + ticsdate_&y + ticsweek_&y + ticsyear_&y + cact_&y + pres_&y + vp_&y + serial7_&y + (ticscount_&y = 2); /*0-13;  only counts first attempt at backward counting*/
		label tics13_&y = "TICS13 derivation for Wu algorithm:0-13 y&y";
	tics13sq_&y = tics13_&y * tics13_&y; 
		label tics13sq_&y = "TICS13_squared for Wu algorithm: 0-169 y&y";
	iwordsq_&y = iword_&y * iword_&y; 
		label iwordsq_&y = "iword_squared for Wu algorithm: 0-100 y&y";
	dword_m_&y = dword_&y * male; 
		label dword_m_&y = "DelayedWord x Male Interaction for Wu algorithm: 0-10 y&y";

	/*HURD*/
	dates_&y = ticsmonth_&y + ticsdate_&y + ticsweek_&y + ticsyear_&y; 
		label dates_&y = "Hurd dates test (0-4) y&y";
	/*************uncertain whether Hurd uses totADL of 0-5 (as in RAND), or totADL of 0-6 (RAND + toiletin), create alternative version using same method as RAND*/
	adl6_&y = sum(walk_&y, dress_&y, bath_&y, eat_&y, bed_&y, toilet_&y); 
		label adl6_&y = "Hurd ADL's (RAND 5 + toilet, count all missing codes as not having difficulty): 0-6 y&y";
	/*************based on Table S1 MeanBackwardCount suggests 0-1 scale rather than 0-2. Uncertain whether attempt is counted, create 2 versions*/
	if ticscount_&y = 2 then ticscount1_&y = 1; else if ticscount_&y in (0, 1) then ticscount1_&y = 0; 
		label ticscount1_&y = "BackwardsCount: 1=Correct 1st attempt ONLY, 0=Incorrect or Correct 2nd attempt y&y";
	if ticscount_&y in (1, 2) then ticscount1or2_&y = 1; else if ticscount_&y = 0 then ticscount1or2_&y = 0; 
		label ticscount1or2_&y = "BackwardsCount: 1=Correct 1st OR 2nd attempt, 0=Incorrect y&y";
	hagecat_&y = 1 + (hrs_age_&y ge 75) + (hrs_age_&y ge 80) + (hrs_age_&y ge 85) + (hrs_age_&y ge 90);
		label hagecat_&y  = "Hurd HRS age category 1=<75, 2=75-79, 3=80-84, 4=85-89, 5=90+ y&y";

	/*Langa-Weir total cognition score*/
	cogsc27_&y = iword_&y + dword_&y + serial7_&y + ticscount_&y; label cogsc27_&y = "L-W cognition continuous: 0-27 y&y";
run;
%mend;

%ext2(2, 94);

/************************************************************
*
*	4. Merge all waves of RAND data - construct wide dataset
*
*************************************************************/
proc sort data=base; 	by hhid pn;
proc sort data=wave_94; by hhid pn;
proc sort data=wave_96; by hhid pn;
proc sort data=wave_98; by hhid pn;
proc sort data=wave_00; by hhid pn;
proc sort data=wave_02; by hhid pn;
proc sort data=wave_04; by hhid pn;
proc sort data=wave_06; by hhid pn;
proc sort data=wave_08; by hhid pn; run;

data self; 
	merge base wave_94 wave_96 wave_98 wave_00 wave_02 wave_04 wave_06 wave_08;
	by hhid pn;
run;

/************************************************************
*
*	5. Create Hurd change variables based on RAND data
*
*************************************************************/
/************************************************************
- adl5ch already provided by RAND
- For all, need:
	- adl6ch
	- iadl
For self-response -> self-response, need:
	- TICS items

Follow logic of RAND derived adl5ch score.
Use pwavemiss_&y (flag for missing prior interviews) to determine which prior wave to take from 
*************************************************************/

/*proc freq data=self; */
/*	tables pwavemiss_00 pwavemiss_02 pwavemiss_04 pwavemiss_06 pwavemiss_08;*/
/*run;*/

%macro ch(v);
	data self; set self;
	/*2000 (w5) -> earliest available is 1994 (pwavemiss = 2)*/
		if pwavemiss_00 = 0 then &v.ch_00 = &v._00 - &v._98; 
		else if pwavemiss_00 = 1 then &v.ch_00 = &v._00 - &v._96; 
		else if pwavemiss_00 = 2 then &v.ch_00 = &v._00 - &v._94; 
		label &v.ch_00 = "change in &v between last non-missing interview and 2000";

	/*2002 (w6) -> earliest available is 1994 (pwavemiss = 3)*/
		if pwavemiss_02 = 0 then &v.ch_02 = &v._02 - &v._00; 
		else if pwavemiss_02 = 1 then &v.ch_02 = &v._02 - &v._98; 
		else if pwavemiss_02 = 2 then &v.ch_02 = &v._02 - &v._96; 
		else if pwavemiss_02 = 3 then &v.ch_02 = &v._02 - &v._94; 
		label &v.ch_02 = "change in &v between last non-missing interview and 2002";

	/*2004 (w7) -> earliest available is 1994 (pwavemiss = 4)*/
		if pwavemiss_04 = 0 then &v.ch_04 = &v._04 - &v._02; 
		else if pwavemiss_04 = 1 then &v.ch_04 = &v._04 - &v._00; 
		else if pwavemiss_04 = 2 then &v.ch_04 = &v._04 - &v._98; 
		else if pwavemiss_04 = 3 then &v.ch_04 = &v._04 - &v._96; 
		else if pwavemiss_04 = 4 then &v.ch_04 = &v._04 - &v._94; 
		label &v.ch_04 = "change in &v between last non-missing interview and 2004";

	/*2006 (w8) -> earliest available is 1994 (pwavemiss = 5)*/
		if pwavemiss_06 = 0 then &v.ch_06 = &v._06 - &v._04; 
		else if pwavemiss_06 = 1 then &v.ch_06 = &v._06 - &v._02; 
		else if pwavemiss_06 = 2 then &v.ch_06 = &v._06 - &v._00; 
		else if pwavemiss_06 = 3 then &v.ch_06 = &v._06 - &v._98; 
		else if pwavemiss_06 = 4 then &v.ch_06 = &v._06 - &v._96; 
		else if pwavemiss_06 = 5 then &v.ch_06 = &v._06 - &v._94; 
		label &v.ch_06 = "change in &v between last non-missing interview and 2006";

	/*2008 (w9) -> earliest available is 1994 (pwavemiss = 6)*/
		if pwavemiss_08 = 0 then &v.ch_08 = &v._08 - &v._06; 
		else if pwavemiss_08 = 1 then &v.ch_08 = &v._08 - &v._04; 
		else if pwavemiss_08 = 2 then &v.ch_08 = &v._08 - &v._02; 
		else if pwavemiss_08 = 3 then &v.ch_08 = &v._08 - &v._00; 
		else if pwavemiss_08 = 4 then &v.ch_08 = &v._08 - &v._98; 
		else if pwavemiss_08 = 5 then &v.ch_08 = &v._08 - &v._96; 
		else if pwavemiss_08 = 6 then &v.ch_08 = &v._08 - &v._94; 
		label &v.ch_08 = "change in &v between last non-missing interview and 2008";

	run;

/*		proc freq; tables &v.ch_00 &v.ch_02 &v.ch_04 &v.ch_06 &v.ch_08; */
/*	run;*/

%mend;

%ch(adl6);
%ch(iadl5) 
%ch(dates) 
%ch(ticscount1) %ch(ticscount1or2)
%ch(serial7) 
%ch(scis) %ch(cact)
%ch(pres) /*VP not used in Hurd*/
%ch(iword) %ch(dword)

/*check*/
/*proc freq data=self; tables adl6ch_00 adl6ch_02 adl6ch_04 adl6ch_06 adl6ch_08 ; run;*/
/*proc print data=self (obs = 20); */
/*	var adl6_94 adl6_96 adl6_98 adl6_00 adl6_02 adl6_04 adl6_06 adl6_08 adl6ch_00 adl6ch_02 adl6ch_04 adl6ch_06 adl6ch_08 pwavemiss_00 pwavemiss_02 pwavemiss_04 pwavemiss_06 pwavemiss_08; */
/*	*where inw_00 = 1 and pwavemiss_00 = 0; */
/*	*where inw_00 = 1 and pwavemiss_00 = 1; */
/*	*where inw_02 = 1 and pwavemiss_02 = 2; */
/*	*where inw_02 = 1 and pwavemiss_02 = 3; */
/*	*where inw_04 = 1 and (pwavemiss_04 = 3 or pwavemiss_04 =  4);*/
/*	*where inw_06 = 1 and (pwavemiss_06 = 1 or pwavemiss_06 =  2);*/
/*	*where inw_06 = 1 and (pwavemiss_06 = 3 or pwavemiss_06 =  4 or pwavemiss_06 =  5);*/
/*	*where inw_08 = 1 and (pwavemiss_08 = 1 or pwavemiss_08 =  2 or pwavemiss_08 =  3);*/
/*	where inw_08 = 1 and (pwavemiss_08 = 4 or pwavemiss_08 =  5 or pwavemiss_08 =  6);*/
/*run;*/




