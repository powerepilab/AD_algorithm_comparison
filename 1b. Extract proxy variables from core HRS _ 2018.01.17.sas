/*libname adams 'F:\power\HRS\ADAMS Wave A';*/
/*libname atrk 'F:\power\HRS\ADAMS CrossWave';*/
/*libname x 'F:\power\HRS\DerivedData\AD_Disparities_AlgorithmDev\Data 2018_0105'; *derived hrs files;*/
/*libname hrs 'F:\power\HRS\HRS data (raw)\SAS datasets'; *raw hrs files, including Hurd probabilities;*/
/*libname rand 'F:\power\HRS\RAND_HRS\sasdata';*/
/*options fmtsearch = (rand.formats);*/

/*pull libnames and final dataset "self" from code 1a.*/

%include "F:\power\HRS\Projects\Ad_Disparities_AlgorithmDev\SAS Programs\Code_2018_0117\1a. Extract self-response variables from RANDp _ 2018.01.17.sas";


/*********************************************************************************************
* Created for compiling final standardized dataset for "validation" and "training" evaluation in HRS/ADAMS
*	Compiles/creates variables from HRS core files, merges with RAND Verion P and Hurd author-provided dementia probabilities from 1a
*	Calculates dementia diagnosis for HW, LKW, Hurd
*
* Extract self-response TICS score count (0-10) computed by HRS - may be used by Crimmins
*
* Extract proxy cognition from HRS core files. 
*	- need standard 00 - 08
*	- also need 98 and 10 for purposes of imputation (as per Wu)
*
* Wu/Hurd - need Jorm 16-item IQCODE, averaged (1-5)
* Wu/Crimmins/LKW - need proxy memory score: 
*	- Wu centered to 5; 
*	- Crimmins/LKW centered to 1
* Crimmins/HW:
*	- Jorm 7-item symptoms (organization & judgment missing after 2002)
*		- 0-7/5 scale for Crimmins
*		- 2+ threshold for HW
* Crimmins/LKW:
*	- interviewer assessment 0-2 (not available in 1998)
*
**********************************************************************************************/

/************************************************************
*
*	1. Extract HRS computed TICS score (0-10, for Crimmins)
*		- dates, backwards count, scis, cactus, pres, vp
*
*************************************************************/

%macro ext(y, raw, v);
data tics_&y; set hrs.&raw (keep = hhid pn &v);
	if 0 le &v le 10 then ticshrs_&y = &v;
	label ticshrs_&y = "HRS computed TICS score: 0-10 y&y";
	proc sort; by hhid pn;
run;

proc sort data=self; by hhid pn;
proc sort data=tics_&y; by hhid pn; run;

data self; 
	merge self tics_&y (keep = hhid pn ticshrs_&y);
	by hhid pn;
	run;

/*	proc means; var ticshrs_&y; run;*/
%mend;

%ext(98, h98c_r, F1677)
%ext(00, h00c_r, G1852)
%ext(02, h02d_r, HD170)
%ext(04, h04d_r, JD170)
%ext(06, h06d_r, KD170)
%ext(08, h08d_r, LD170)
%ext(10, h10d_r, MD170)

/************************************************************
*
*	2. Extract JORM 16-item IQCODE, derive summary measures, ix, change scores
*
*************************************************************

	- following Wu's treatment of missing data:
		- drop any observations with 4+ DK/RF in the initial question
		- if initial question is answered with better or worse, but subsequent question is DK/RF then 
			replace DK/RF with value closest to staying the same 

	- For items 'not applicable' (=4 in the data) - do not count in computation of mean IQCODE score, 
			do not count as DK/RF for purposes of dropping observations
*/

%macro jorm (base, better, worse, first, y, raw);

data jorm_&y; set &raw (keep = hhid pn &base &better &worse); run;

data jorm_&y; set jorm_&y;
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

	label IQCODE_&y = "Jorm IQCODE score for Hurd: 1(much better) to 5(much worse), set to missing if 4+ items dk/nf y&y";
	label IQCODE_dkrf_&y = "number of Jorm IQCODE items DK/RF: 0-16 (does NOT count Not applicables) y&y ";
	
	/*for Wu - create version centered at 5*/
	IQCODE5_&y = IQCODE_&y - 5; 
	label IQCODE5_&y = "Jorm IQCODE score ctrd at 5 for Wu: -4(much better) to 0(much worse), set to missing if 4+ items dk/nf y&y";

proc sort; by hhid pn;
run;

/*proc means; var IQCODE_&y IQCODE5_&y iqcode_dkrf_&y;*/
/*run;*/
%mend;

/*compute Jorm IQCODE for 1998 HRS*/
%jorm (F1389 F1394 F1399 F1404 F1409 F1414 F1419 F1424 F1429 F1434 F1439 F1444 F1448 F1451 F1454 F1457, 
	   F1390 F1395 F1400 F1405 F1410 F1415 F1420 F1425 F1430 F1435 F1440 F1445 F1449 F1452 F1455 F1458,
       F1391 F1396 F1401 F1406 F1411 F1416 F1421 F1426 F1431 F1436 F1441 F1446 F1450 F1453 F1456 F1459,
	   F1389, 98, hrs.h98pc_r);

/*compute Jorm IQCODE for 2000 HRS*/
%jorm (G1543 G1548 G1553 G1558 G1563 G1568 G1573 G1578 G1583 G1588 G1593 G1598 G1602 G1605 G1608 G1611, 
	   G1544 G1549 G1554 G1559 G1564 G1569 G1574 G1579 G1584 G1589 G1594 G1599 G1603 G1606 G1609 G1612,
       G1545 G1550 G1555 G1560 G1565 G1570 G1575 G1580 G1585 G1590 G1595 G1600 G1604 G1607 G1610 G1613,
	   G1543, 00, hrs.h00pc_r);

/*compute Jorm IQCODE for 2002 HRS*/
%jorm (HD506 HD509 HD512 HD515 HD518 HD521 HD524 HD527 HD530 HD533 HD536 HD539 HD542 HD545 HD548 HD551, 
	   HD507 HD510 HD513 HD516 HD519 HD522 HD525 HD528 HD531 HD534 HD537 HD540 HD543 HD546 HD549 HD552,
       HD508 HD511 HD514 HD517 HD520 HD523 HD526 HD529 HD532 HD535 HD538 HD541 HD544 HD547 HD550 HD553,
	   HD506, 02, hrs.h02d_r);

/*compute Jorm IQCODE for 2004 HRS*/
%jorm (JD506 JD509 JD512 JD515 JD518 JD521 JD524 JD527 JD530 JD533 JD536 JD539 JD542 JD545 JD548 JD551, 
	   JD507 JD510 JD513 JD516 JD519 JD522 JD525 JD528 JD531 JD534 JD537 JD540 JD543 JD546 JD549 JD552,
       JD508 JD511 JD514 JD517 JD520 JD523 JD526 JD529 JD532 JD535 JD538 JD541 JD544 JD547 JD550 JD553,
	   JD506, 04, hrs.h04d_r);

/*compute Jorm IQCODE for 2006 HRS*/
%jorm (KD506 KD509 KD512 KD515 KD518 KD521 KD524 KD527 KD530 KD533 KD536 KD539 KD542 KD545 KD548 KD551, 
	   KD507 KD510 KD513 KD516 KD519 KD522 KD525 KD528 KD531 KD534 KD537 KD540 KD543 KD546 KD549 KD552,
       KD508 KD511 KD514 KD517 KD520 KD523 KD526 KD529 KD532 KD535 KD538 KD541 KD544 KD547 KD550 KD553,
	   KD506, 06, hrs.h06d_r);

/*compute Jorm IQCODE for 2008 HRS*/
%jorm (LD506 LD509 LD512 LD515 LD518 LD521 LD524 LD527 LD530 LD533 LD536 LD539 LD542 LD545 LD548 LD551, 
	   LD507 LD510 LD513 LD516 LD519 LD522 LD525 LD528 LD531 LD534 LD537 LD540 LD543 LD546 LD549 LD552,
       LD508 LD511 LD514 LD517 LD520 LD523 LD526 LD529 LD532 LD535 LD538 LD541 LD544 LD547 LD550 LD553,
	   LD506, 08, hrs.h08d_r);

/*compute Jorm IQCODE for 2010 HRS*/
%jorm (MD506 MD509 MD512 MD515 MD518 MD521 MD524 MD527 MD530 MD533 MD536 MD539 MD542 MD545 MD548 MD551, 
	   MD507 MD510 MD513 MD516 MD519 MD522 MD525 MD528 MD531 MD534 MD537 MD540 MD543 MD546 MD549 MD552,
       MD508 MD511 MD514 MD517 MD520 MD523 MD526 MD529 MD532 MD535 MD538 MD541 MD544 MD547 MD550 MD553,
	   MD506, 10, hrs.h10d_r);


/*proc print data=jorm_98 (obs = 20);*/
/*	where F1389 NE .;*/
/*run;*/
/*proc means data=jorm_98;*/
/*	var iqcode_98;*/
/*	where iqcode_dkrf_98 le 3;*/
/*	*where iqcode_dkrf_98 >3;*/
/*run;*/

/*check if wave3(1996/1995) waves are needed for Hurd-change in IQCODE (wave2 does NOT ask Jorm of proxy respondents)*/
/*proc freq data=self;*/
/*	tables pwavemiss_00;*/
/*	where proxy_00 = 1;*/
/*run;*/
/**N=87 would need 1996, N=27 would need 1994 - check cohort and if proxies in those waves;*/
/*proc freq data=self;	*/
/*	tables proxy_96*hacohort;*/
/*	where pwavemiss_00 = 1 and proxy_00 = 1;*/
/*run; *N=29 proxies;*/

/*need both HRS/AHEAD cores for wave 3*/

/*compute Jorm for 1996 interview (HRS wave 3)*/
%jorm (E1072 E1077 E1082 E1087 E1092 E1097 E1102 E1107 E1112 E1117 E1122 E1127 E1132 E1135 E1138 E1141, 
	   E1073 E1078 E1083 E1088 E1093 E1098 E1103 E1108 E1113 E1118 E1123 E1128 E1133 E1136 E1139 E1142,
       E1074 E1079 E1084 E1089 E1094 E1099 E1104 E1109 E1114 E1119 E1124 E1129 E1134 E1137 E1140 E1143,
	   E1072, 96, hrs.h96pc_r);
/*compute Jorm for 1995 interview (AHEAD wave 3)*/
%jorm (D1072 D1077 D1082 D1087 D1092 D1097 D1102 D1107 D1112 D1117 D1122 D1127 D1132 D1135 D1138 D1141, 
	   D1073 D1078 D1083 D1088 D1093 D1098 D1103 D1108 D1113 D1118 D1123 D1128 D1133 D1136 D1139 D1142,
       D1074 D1079 D1084 D1089 D1094 D1099 D1104 D1109 D1114 D1119 D1124 D1129 D1134 D1137 D1140 D1143,
	   D1072, 95, hrs.a95pc_r);

/*rename final variables in 95 file to have 96 suffix for consistency and append*/
data jorm_95; set jorm_95;
	rename IQCODE_95 = IQCODE_96;
	label IQCODE_95 = "Jorm IQCODE score for Hurd: 1(much better) to 5(much worse), set to missing if 4+ items dk/nf y96";
	rename IQCODE5_95 = IQCODE5_96;
	label IQCODE5_95 = "Jorm IQCODE score ctrd at 5 for Wu: -4(much better) to 0(much worse), set to missing if 4+ items dk/nf y96";
	
	rename IQCODE_dkrf_95 = IQCODE_dkrf_96;
	label IQCODE_dkrf_95 = "number of Jorm IQCODE items DK/RF: 0-16 (does NOT count Not applicables) y96 ";
run;

data jorm_96;
	set jorm_96 jorm_95;
	run;

/*	proc means; var IQCODE_96 IQCODE5_96 IQCODE_dkrf_96;*/
/*run;*/

/*
merge jorm scores across waves (keep final variables only)
merge variables pwavemiss_98 - pwavemiss_10 (need waves 98 and 2010 for purposes of immputing missings) 
- create IQCODE male interaction
- compute change in IQCODE for HURD
*/

data proxy; set self (keep = hhid pn male pwavemiss_98 pwavemiss_00 pwavemiss_02 pwavemiss_04 pwavemiss_06 pwavemiss_08); run;
data pw; set rand.rndhrs_p (keep = hhid pn r10adlf rename = r10adlf = pwavemiss_10); run;
data proxy; merge proxy pw; by hhid pn; run;

*keep final IQCODE scores;
*create variable for IQCODE male interaction;
%macro mer(y);
data proxy;
	merge proxy jorm_&y (keep = hhid pn IQCODE_&y IQCODE5_&y IQCODE_dkrf_&y);
	by hhid pn;

	IQCODE5_m_&y = IQCODE5_&y * male;
	label IQCODE5_m_&y = "IQCODE (centered at 5) * male interaction for Wu algorithm y&y";
run;
%mend;

%mer(96) %mer(98) %mer(00) %mer(02) %mer(04) %mer(06) %mer(08) %mer(10) 

*change in IQCODE;
data proxy; set proxy;
	/*1998 (w4) -> earliest available is 1996 (pwavemiss = 0)*/
		if pwavemiss_98 = 0 then IQCODEch_98 = IQCODE_98 - IQCODE_96; 
		label IQCODEch_98 = "change in IQCODE between last non-missing interview and 1998";

	/*2000 (w5) -> earliest available is 1996 (pwavemiss = 1)*/
		if pwavemiss_00 = 0 then IQCODEch_00 = IQCODE_00 - IQCODE_98; 
		else if pwavemiss_00 = 1 then IQCODEch_00 = IQCODE_00 - IQCODE_96; 
		label IQCODEch_00 = "change in IQCODE between last non-missing interview and 2000";

	/*2002 (w6) -> earliest available is 1996 (pwavemiss = 2)*/
		if pwavemiss_02 = 0 then IQCODEch_02 = IQCODE_02 - IQCODE_00; 
		else if pwavemiss_02 = 1 then IQCODEch_02 = IQCODE_02 - IQCODE_98; 
		else if pwavemiss_02 = 2 then IQCODEch_02 = IQCODE_02 - IQCODE_96; 
		label IQCODEch_02 = "change in IQCODE between last non-missing interview and 2002";

	/*2004 (w7) -> earliest available is 1996 (pwavemiss = 3)*/
		if pwavemiss_04 = 0 then IQCODEch_04 = IQCODE_04 - IQCODE_02; 
		else if pwavemiss_04 = 1 then IQCODEch_04 = IQCODE_04 - IQCODE_00; 
		else if pwavemiss_04 = 2 then IQCODEch_04 = IQCODE_04 - IQCODE_98; 
		else if pwavemiss_04 = 3 then IQCODEch_04 = IQCODE_04 - IQCODE_96; 
		label IQCODEch_04 = "change in IQCODE between last non-missing interview and 2004";

	/*2006 (w8) -> earliest available is 1996 (pwavemiss = 4)*/
		if pwavemiss_06 = 0 then IQCODEch_06 = IQCODE_06 - IQCODE_04; 
		else if pwavemiss_06 = 1 then IQCODEch_06 = IQCODE_06 - IQCODE_02; 
		else if pwavemiss_06 = 2 then IQCODEch_06 = IQCODE_06 - IQCODE_00; 
		else if pwavemiss_06 = 3 then IQCODEch_06 = IQCODE_06 - IQCODE_98; 
		else if pwavemiss_06 = 4 then IQCODEch_06 = IQCODE_06 - IQCODE_96; 
		label IQCODEch_06 = "change in IQCODE between last non-missing interview and 2006";

	/*2008 (w9) -> earliest available is 1996 (pwavemiss = 5)*/
		if pwavemiss_08 = 0 then IQCODEch_08 = IQCODE_08 - IQCODE_06; 
		else if pwavemiss_08 = 1 then IQCODEch_08 = IQCODE_08 - IQCODE_04; 
		else if pwavemiss_08 = 2 then IQCODEch_08 = IQCODE_08 - IQCODE_02; 
		else if pwavemiss_08 = 3 then IQCODEch_08 = IQCODE_08 - IQCODE_00; 
		else if pwavemiss_08 = 4 then IQCODEch_08 = IQCODE_08 - IQCODE_98; 
		else if pwavemiss_08 = 5 then IQCODEch_08 = IQCODE_08 - IQCODE_96; 
		label IQCODEch_08 = "change in IQCODE between last non-missing interview and 2008";

	/*2008 (w9) -> earliest available is 1996 (pwavemiss = 5)*/
		if pwavemiss_08 = 0 then IQCODEch_08 = IQCODE_08 - IQCODE_06; 
		else if pwavemiss_08 = 1 then IQCODEch_08 = IQCODE_08 - IQCODE_04; 
		else if pwavemiss_08 = 2 then IQCODEch_08 = IQCODE_08 - IQCODE_02; 
		else if pwavemiss_08 = 3 then IQCODEch_08 = IQCODE_08 - IQCODE_00; 
		else if pwavemiss_08 = 4 then IQCODEch_08 = IQCODE_08 - IQCODE_98; 
		else if pwavemiss_08 = 5 then IQCODEch_08 = IQCODE_08 - IQCODE_96; 
		label IQCODEch_08 = "change in IQCODE between last non-missing interview and 2008";

	/*2010 (w10) -> earliest available is 1996 (pwavemiss = 6)*/
		if pwavemiss_10 = 0 then IQCODEch_10 = IQCODE_10 - IQCODE_08; 
		else if pwavemiss_10 = 1 then IQCODEch_10 = IQCODE_10 - IQCODE_06; 
		else if pwavemiss_10 = 2 then IQCODEch_10 = IQCODE_10 - IQCODE_04; 
		else if pwavemiss_10 = 3 then IQCODEch_10 = IQCODE_10 - IQCODE_02; 
		else if pwavemiss_10 = 4 then IQCODEch_10 = IQCODE_10 - IQCODE_00; 
		else if pwavemiss_10 = 5 then IQCODEch_10 = IQCODE_10 - IQCODE_98; 
		else if pwavemiss_10 = 6 then IQCODEch_10 = IQCODE_10 - IQCODE_96; 
		label IQCODEch_10 = "change in IQCODE between last non-missing interview and 2010";
run;

/*	proc means; var IQCODEch_98 IQCODEch_00 IQCODEch_02 IQCODEch_04 IQCODEch_06 IQCODEch_08 IQCODEch_10;*/
/*run;*/



/************************************************************
*
*	3. Extract proxy memory scores, derive related variables
*
*************************************************************

Wu/Crimmins/LKW: proxy memory score
	- Raw variable: 1(excellent) to 5(poor)
		- For Wu center at 5: -4(excellent) to 0(poor)
		- For Crimmins/LKW center at 1: 0(excellent) to 4(poor)

***/


%macro ext (raw, y, v);
data prmem_&y; set hrs.&raw (keep = hhid pn &v);

	if &v not in (8, 9, .) then do;
		pr_memsc5_&y = &v - 5; label pr_memsc5_&y = "proxy mem score ctrd at 5 for Wu: -4(excellent) to 0(poor) y&y";
		pr_memsc1_&y = &v - 1; label pr_memsc1_&y = "proxy mem score ctrd at 1 for Crimmins/LKW: 0(excellent) to 4(poor) y&y";
	end;
	
	proc sort; by hhid pn;
run;

data proxy; 
	merge proxy prmem_&y (keep = hhid pn pr_memsc5_&y pr_memsc1_&y);
	by hhid pn;
run;

/*	proc means; var pr_memsc5_&y pr_memsc1_&y;*/
/*run;*/

%mend;
%ext (h98pc_r, 98, F1373);
%ext (h00pc_r, 00, G1527);
%ext (h02d_r, 02, HD501);
%ext (h04d_r, 04, JD501);
%ext (h06d_r, 06, KD501);
%ext (h08d_r, 08, LD501);
%ext (h10d_r, 10, MD501);

/************************************************************
*
*	4. Extract interviewer assessment of proxy cognition, derive related variables
*
*************************************************************

/***
Crimmins/LKW: interviewer assessment for proxy cognition 
- not available in 1998 wave
- Note: 00 version linked in quesiton specific linkage (not xs file)
- rescale to 0(no impairment) - 2(cannot do interview)
*/

%macro ext (raw, y, v);
data iwa_&y; set hrs.&raw (keep = hhid pn &v);
	if &v in (1, 2, 3) then iwercog_&y = &v - 1;
	label iwercog_&y = "Interviewer assessmnet of cognitive impairment: 0(none) to 2(prevents interview completion) y&y"; 
proc sort; by hhid pn; 
run;

data proxy; 
merge proxy iwa_&y (keep = hhid pn iwercog_&y);
by hhid pn;
run;

/*proc freq; tables iwercog_&y;*/
/*run;*/

%mend;

%ext (h00cs_r, 00, G517);
%ext (h02a_r, 02, HA011);
%ext (h04a_r, 04, JA011);
%ext (h06a_r, 06, KA011);
%ext (h08a_r, 08, LA011);
%ext (h10a_r, 10, MA011);


/************************************************************
*
*	5. Extract Jorm symptom checklist, derive related variables
*
*************************************************************

/***Crimmins/HW Jorm 7-item symptoms
		- Getting lost: Y/N raw varaible - count "YES" as having symptom
		- Wandering: /N raw variable - count "YES" as having symptom
		- Ability to be left alone: Y/N raw variable - count "NO" as having symptom
		- Hallucinations: Y/N raw variable - count "YES" as having symptom
		- Memory: 1(Excellent)-5(Poor) - count "5" as having symptom
		- Judgment: 1(Excellent)-5(Poor) - count "5" as having symptom
		- Organization: 1(Excellent)-5(Poor) - count "5" as having symptom

	- Judgment and Organization NOT available after 2002: create 2 versions of variable
		- Jormsymp_y&y: 0-7 in years 1998-2002, 0-5 in years 2004-2010
		- Jormsymp5_y&y: 0-5 in all years

	- IN adding # of symptoms, use 'sum' function to ignore missings - this is consistent with how total ADL/IADL limitations are computed by RAND
		-Explore difference between 5 and 7 item version of Jorm symptoms

	- Create 2+ threshold for H-W 
*/

/*Years 98-02*/
%macro cjorm(y, raw, lost, wander, alone, halluc, mem, judg, org); 

data cjorm_&y; 
	set hrs.&raw (keep = hhid pn &lost &wander &alone &halluc &mem &judg &org);

	if &lost = 1 then lost_&y = 1; else if &lost = 5 then lost_&y = 0;
	if &wander = 1 then wander_&y = 1; else if &wander = 5 then wander_&y = 0; /*if = 4 (R cannot wander off), count as missing*/
	if &alone = 5 then alone_&y = 1; else if &alone = 1 then alone_&y = 0; /*it is a symptom if R CANNOT be left alone; not a symptom if ok to be left alone*/
	if &halluc = 1 then hallucinate_&y = 1; else if &halluc = 5 then hallucinate_&y = 0;
	if &mem = 5 then memsymp_&y = 1; else if &mem in (1, 2, 3, 4) then memsymp_&y = 0;
	if &judg = 5 then judgment_&y = 1; else if &judg in (1, 2, 3, 4) then judgment_&y = 0;
	if &org = 5 then orgn_&y = 1; else if &org in (1, 2, 3, 4) then orgn_&y = 0;

	jormsymp_&y = sum(lost_&y, wander_&y, alone_&y, hallucinate_&y, memsymp_&y, judgment_&y, orgn_&y);
		label jormsymp_&y = "Total number of Jorm symptoms out of all availble: 0-7 up to 2002 wave, 0-5 thereafter, y&y";
	jorm5symp_&y = sum(lost_&y, wander_&y, alone_&y, hallucinate_&y, memsymp_&y);
		label jorm5symp_&y = "Total number of Jorm symptoms out of 5: 0-5 in all waves, y&y";

	if jormsymp_&y NE . and jormsymp_&y < 2 then jormsymp2_&y = 0;
	else if jormsymp_&y NE . then jormsymp2_&y = 1;
		label jormsymp2_&y = "Has 2 or more Jorm symptoms out of all available (0-7 up to 2002, 0-5 thereafter, y&y";

	if jorm5symp_&y NE . and jorm5symp_&y < 2 then jorm5symp2_&y = 0;
	else if jorm5symp_&y NE . then jorm5symp2_&y = 1;
		label jormsymp2_&y = "Has 2 or more Jorm symptoms out 0-5 in all waves, y&y";

*check to see how jorm 7 and 5 item compare;
/*proc freq; tables jormsymp2_&y*jorm5symp2_&y; run;*/
/*proc corr pearson polychoric; var jormsymp_&y jorm5symp_&y; run;*/
/*run;*/
*1998:  153/2042 (7.4%) misclassified as <2 when using 5 versus 7 items, pearson r:  0.95807, polychoric r: 0.9882
*2000:  142/2060 (6.9%) misclassified as <2 when using 5 versus 7 items, pearson r:  0.95629, polychoric r: 0.98795
*2002:  146/2034 (7.2%) misclassified as <2 when using 5 versus 7 items, pearson r:  0.96374, polychoric r: 0.99196
*decision: ok to just use what is available - 5 or 7 item version;

proc sort data=cjorm_&y; by hhid pn; run;
proc sort data=proxy; by hhid pn; run;

data proxy;
	merge proxy cjorm_&y (keep = hhid pn jormsymp_&y jorm5symp_&y jormsymp2_&y);
	by hhid pn;
run;
%mend;

%cjorm(98, h98pc_r, F1461, F1462, F1463, F1464, F1373, F1378, F1383)
%cjorm(00, h00pc_r, G1615, G1616, G1617, G1618, G1527, G1532, G1537)
%cjorm(02, h02d_r, HD554, HD555, HD556, HD557, HD501, HD503, HD504)

/*years 04-10 - organization and judgment missing*/

%macro cjorm(y, raw, lost, wander, alone, halluc, mem); 

data cjorm_&y; 
	set hrs.&raw (keep = hhid pn &lost &wander &alone &halluc &mem);

	if &lost = 1 then lost_&y = 1; else if &lost = 5 then lost_&y = 0;
	if &wander = 1 then wander_&y = 1; else if &wander = 5 then wander_&y = 0; /*if = 4 (R cannot wander off), count as missing*/
	if &alone = 5 then alone_&y = 1; else if &alone = 1 then alone_&y = 0; /*it is a symptom if R CANNOT be left alone; not a symptom if ok to be left alone*/
	if &halluc = 1 then hallucinate_&y = 1; else if &halluc = 5 then hallucinate_&y = 0;
	if &mem = 5 then memsymp_&y = 1; else if &mem in (1, 2, 3, 4) then memsymp_&y = 0;

	jormsymp_&y = sum(lost_&y, wander_&y, alone_&y, hallucinate_&y, memsymp_&y);
	label jormsymp_&y = "Total number of Jorm symptoms out of all availble: 0-7 up to 2002 wave, 0-5 thereafter, y&y";
	jorm5symp_&y = sum(lost_&y, wander_&y, alone_&y, hallucinate_&y, memsymp_&y);
	label jorm5symp_&y = "Total number of Jorm symptoms out of 5: 0-5 in all waves, y&y";

	if jormsymp_&y NE . and jormsymp_&y < 2 then jormsymp2_&y = 0;
	else if jormsymp_&y NE . then jormsymp2_&y = 1;
	label jormsymp2_&y = "Has 2 or more Jorm symptoms, y&y";

/*proc freq; tables jormsymp_&y jorm5symp_&y jormsymp2_&y;*/
/*run;*/

proc sort data=cjorm_&y; by hhid pn; run;
proc sort data=proxy; by hhid pn; run;

data proxy;
	merge proxy cjorm_&y (keep = hhid pn jormsymp_&y jorm5symp_&y jormsymp2_&y);
	by hhid pn;
run;
%mend;

%cjorm(04, h04d_r, JD554, JD555, JD556, JD557, JD501)
%cjorm(06, h06d_r, KD554, KD555, KD556, KD557, KD501)
%cjorm(08, h08d_r, LD554, LD555, LD556, LD557, LD501)
%cjorm(10, h10d_r, MD554, MD555, MD556, MD557, MD501)



/************************************************************
*
*	5. Create master dataset with necessary variables, including derived dementia status incl proxy variables (H-W, LKW)
*
*************************************************************

/*
Create clean version of "self" dataset (from 1a) 
	- for Hurd variables, need self-response cognition (dates, serial7, president iword, dword) and proxy-indicator back to 98
	- for proxy cognition variables, need back to 98 for imputation purposes
and merge with proxy
*/

data self_clean; set self (keep = hhid pn inw_00 inw_02 inw_04 inw_06 inw_08 
									male female black NH_black NH_white NH_other hispanic raceeth4 /*include raw race/ethnicity variables*/
									midedu_hurd highedu_hurd lowedu_crim midedu_crim edu_hurd edu_crim
									iweyr_00 iweyr_02 iweyr_04 iweyr_06 iweyr_08 iwemo_00 iwemo_02 iwemo_04 iwemo_06 iwemo_08
									hrs_age_00 hrs_age_02 hrs_age_04 hrs_age_06 hrs_age_08
									hrs_age70_00 hrs_age70_02 hrs_age70_04 hrs_age70_06 hrs_age70_08
									hagecat_00 hagecat_02 hagecat_04 hagecat_06 hagecat_08
									proxy_98 proxy_00 proxy_02 proxy_04 proxy_06 proxy_08 
									tics13_00 tics13_02 tics13_04 tics13_06 tics13_08
									tics13sq_00 tics13sq_02 tics13sq_04 tics13sq_06 tics13sq_08 
									iword_98 iword_00 iword_02 iword_04 iword_06 iword_08 iwordsq_00 iwordsq_02 iwordsq_04 iwordsq_06 iwordsq_08 
									iwordch_00 iwordch_02 iwordch_04 iwordch_06 iwordch_08 
									dword_98 dword_00 dword_02 dword_04 dword_06 dword_08 dword_m_00 dword_m_02 dword_m_04 dword_m_06 dword_m_08
									dwordch_00 dwordch_02 dwordch_04 dwordch_06 dwordch_08 
									dates_98 dates_00 dates_02 dates_04 dates_06 dates_08 datesch_00 datesch_02 datesch_04 datesch_06 datesch_08  
									ticscount_00 ticscount_02 ticscount_04 ticscount_06 ticscount_08 
									ticscount1_98 ticscount1_00 ticscount1_02 ticscount1_04 ticscount1_06 ticscount1_08 
									ticscount1ch_00 ticscount1ch_02 ticscount1ch_04 ticscount1ch_06 ticscount1ch_08 
									ticscount1or2_98 ticscount1or2_00 ticscount1or2_02 ticscount1or2_04 ticscount1or2_06 ticscount1or2_08 
									ticscount1or2ch_00 ticscount1or2ch_02 ticscount1or2ch_04 ticscount1or2ch_06 ticscount1or2ch_08 
									serial7_98 serial7_00 serial7_02 serial7_04 serial7_06 serial7_08 serial7ch_00 serial7ch_02 serial7ch_04 serial7ch_06 serial7ch_08
									scis_00 scis_02 scis_04 scis_06 scis_08 scisch_00 scisch_02 scisch_04 scisch_06 scisch_08 
									cact_00 cact_02 cact_04 cact_06 cact_08 cactch_00 cactch_02 cactch_04 cactch_06 cactch_08 
									pres_98 pres_00 pres_02 pres_04 pres_06 pres_08 presch_00 presch_02 presch_04 presch_06 presch_08
									cogtot_98 cogtot_00 cogtot_02 cogtot_04 cogtot_06 cogtot_08
									cogsc27_98 cogsc27_00 cogsc27_02 cogsc27_04 cogsc27_06 cogsc27_08
									ticshrs_98 ticshrs_00 ticshrs_02 ticshrs_04 ticshrs_06 ticshrs_08 ticshrs_10
									dress_00 dress_02 dress_04 dress_06 dress_08 bath_00 bath_02 bath_04 bath_06 bath_08 eat_00 eat_02 eat_04 eat_06 eat_08
									money_00 money_02 money_04 money_06 money_08 phone_00 phone_02 phone_04 phone_06 phone_08
									adl5_00 adl5_02  adl5_04 adl5_06 adl5_08 adl5ch_00 adl5ch_02 adl5ch_02 adl5ch_04 adl5ch_06 adl5ch_08
									adl6_00 adl6_02  adl6_04 adl6_06 adl6_08 adl6ch_00 adl6ch_02 adl6ch_02 adl6ch_04 adl6ch_06 adl6ch_08
									iadl5_98 iadl5_00 iadl5_02 iadl5_04 iadl5_06 iadl5_08 iadl5ch_00 iadl5ch_02 iadl5ch_04 iadl5ch_06 iadl5ch_08); 
run;

proc sort data=self_clean; by hhid pn;
proc sort data=proxy; by hhid pn; run;

data master;
	merge self_clean proxy;
	by hhid pn;
run;



/************************************************************
*
*	6. Save dataset to disk
*
*************************************************************/

data x.master_&dt; set master; run;

ods pdf body = "contents_1b_master_&dt..pdf";
proc contents data=master; run;
ods pdf close;



