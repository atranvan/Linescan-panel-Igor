#pragma rtGlobals=1		// Use modern global access method.
#include <All IP Procedures>
//LINESCANPANEL loads linescan images acquired with PrairieView and creates linescan profiles.
//
//-------------
//It is recommended to load each linescan folder in a separate data folder, then to merge folders as needed once profiles have been calculated
//The Load images box in the LineScan Analysis panel calls the function Loadlinescanimages() 
//Select the prairieview xml config file and load tiffs images of corresponding channel. Rename and splits in groups depending similar to neuromatic groups 
// Loaded tiff are renamed as: list_group_filesuffix_Channel_index. Then creates a stack of each tiff and group, named Stack_channel_filesuffix_group
//The Analyze images box in the  LineScan Analysis panel calls the function CalcLSprofiles()
// this allows to select the position of the vertical profile to create (using Igor Imagelineprofile function)
//output waves are named profile_channel_filesuffix_indexofprofile_group_indexofwave
// to display position of calculated profile on image select image and appendtograph lineprofy vs lineprofx in subfolder infoprof...
//-------------
//By Alex Tran-Van-Minh (alexandra.tran.van.minh@gmail.com)
//-------------

//02-JAN-2013: Current PV version (4.3.2.13) does already includes zoom in pixel size. Other versions (e.g. 4.2.1.17) required
//dividing by optical zoom to get real pixel size
//Background subtraction checkbox for subtraction from user-entered value or profile. 
//Output wave (background subtracted) is named c_profile_channel_filesuffix_indexofprofile_group_indexofwave and is the one plotted

//13-MAR-2013: 
//1. Corrected image loading to load and display images properly even when there are no repetitions
//2. All loaded waves are now scaled (including unclassified waves "ls_...")
//3. All profile waves called "profile_Chx_profilenumber_groupnumber_..." or "c_profile_Chx_profilenumber_groupnumber_..."   are now INDIVIDUAL waves, 
// the stack of these waves are now contained in "st_Chx_profilenumber_groupnumber" or "c_st_Chx_profilenumber_groupnumber"
//4. Fixed "rename error" bug that was appearing when creating multiple profiles with background subtraction:
//now unique names are created for background waves each time the "calculate" button is used. Background waves are named bg_channel_indexofprofile_group_indexofwave,
//the average value of each of these background waves is used to subtract from the corresponding profile from the same image.

//27-APR-2013:
//Add option for 4 channels selection and addition of profiles from 2 channels.

//06-MAY-2013:
//Add option for adding images and making a deltaF/F image from one of the 2d image in current folder.

//08-MAY-2013:
//Add background subtraction when making a deltaF/F image and filtering of deltaF/F image.

//22-JAN-2014:
//Fixed Make error when using user-entered value for background subtraction.

//05-MAR-2014:
//Fixed Background subtraction error from profile when only one image is in the stack
//Background profiles are now scaled like loaded image

//11-APR-2014:
//1/ Added Button "profile from all images" : calls function calcall2d() 
//this calculates (using values from the panel) profiles (and background subtracts) for ALL 2d images contained 
//in current data folder, even if they were not loaded with the panel
//the calculated profiles are 1d waves named as "prof_+name of wave+index"
//if applicable the background corrected profiles are named as "c_prof+name of wave+index"
//2/ Redesigned panel
//3/ added dropped-down menu to do 4 basic operations on profiles

//05-JUN-2014:
//From version 5.1 on PrairieView includes ".ome" suffix in their file names. Modified loading procedure accordingly.

//13-AUG-2014:
//Adjusted reading of PrairieView .xml  file in Loadlinescanimages() as order and name of some parameters changed in 5.2 version

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

 Macro linescanpanel()
 	execute "makelinescanpanel()"
 end
 
 ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
 Function Loadlinescanimages()
 
	variable/g FlagCh1, FlagCh2, FlagCh3, FlagCh4, displayflag,groupnum
	DFREF cDF=GetDataFolderdfr()
	DFREF loadfolder

	
// get status of checkboxes and variables set in Load images box of Linescan panel
	Controlinfo/W=linescanpanel loadChannel1check
		FlagCh1=V_Value
	Controlinfo/W=linescanpanel loadChannel2check
		FlagCh2=V_Value
	Controlinfo/W=linescanpanel loadChannel3check
		FlagCh3=V_Value
	Controlinfo/W=linescanpanel loadChannel4check
		FlagCh4=V_Value
	Controlinfo/W=linescanpanel Displaycheck
		displayFlag=V_Value
	Controlinfo/W=linescanpanel Groupsetnum
		groupnum=V_Value
	

// opens Prairie XML config file in chosen folder
	variable/g fileref
	fileref=0

	String/g configfile
	configfile=indexedfile(diskfolderpath,0,".xml")
	open/r/t=".xml" fileref as configfile

	 
	 String/g filesuffix=configfile[(strlen(configfile)-7),strlen(configfile)-5]
	 
	 
	 

//reads config file and extract imaging parameters to use for wave scaling
	 string /g tempstring,locstr,PVversion
 	 variable /g V1,loc,McrnsPerPix,zoom,ScanLinePrd
 	 variable/g PixelSize
 
	 Do
		FReadLine fileref, tempstring
		if (stringmatch(tempstring,"*PVScan*")==1)
				loc=strsearch(tempstring,"version",0)+9
				locstr=tempstring[loc,loc+7]
				PVversion=locstr
				print "PrairieView version", PVversion
				break
		endif

	while(1)
	
	
	if ((stringmatch(PVversion[0,0],"4")==1)||((stringmatch(PVversion[0,0],"5")==1)&&(stringmatch(PVversion[2,2],"0")==1))||((stringmatch(PVversion[0,0],"5")==1)&&(stringmatch(PVversion[2,2],"1")==1)))
	
		Do
			FReadLine fileref, tempstring
				if (stringmatch(tempstring,"*scanlinePeriod*")==1)
					loc=strsearch(tempstring,"value",0)+7
					locstr=tempstring[loc,loc+8]
					v1=str2num(locstr)
					ScanLinePrd=v1*1000
					print "Scanline period is (ms)=",ScanLinePrd
					break
				endif
		while(1) 
	
		Do
			FReadLine fileref, tempstring
			if (stringmatch(tempstring,"*opticalZoom*")==1)
					loc=strsearch(tempstring,"value",0)+7
					locstr=tempstring[loc,loc+5]
					v1=str2num(locstr)
					zoom=v1
					print "Optical zoom=",zoom
					break
			endif
		while(1)
	
		 Do                                          
			FReadLine fileref, tempstring
			if (stringmatch(tempstring,"*micronsPerPixel_XAxis*")==1)
				loc=strsearch(tempstring,"value",0)+7
				locstr=tempstring[loc,loc+5]
				v1=str2num(locstr)
				McrnsPerPix=v1
				print "Microns per pixel=",McrnsPerPix
				break
			Endif
		while(1)
	
	ElseIf ((stringmatch(PVversion[0,0],"5")==1)&&(stringmatch(PVversion[2,2],"2")==1))
			

	
		Do                                          
			FReadLine fileref, tempstring
			if (stringmatch(tempstring,"*micronsPerPixel*")==1)
				FReadLine fileref, tempstring
				if (stringmatch(tempstring,"*XAxis*")==1)
				loc=strsearch(tempstring,"value",0)+7
				locstr=tempstring[loc,loc+5]
				v1=str2num(locstr)
				McrnsPerPix=v1
				print "Microns per pixel=",McrnsPerPix
				Endif
				break
			Endif
		
		while(1)
		
		Do
			FReadLine fileref, tempstring
			if (stringmatch(tempstring,"*opticalZoom*")==1)
					loc=strsearch(tempstring,"value",0)+7
					locstr=tempstring[loc,loc+5]
					v1=str2num(locstr)
					zoom=v1
					break
			endif
		while(1)
		
		Do
			FReadLine fileref, tempstring
				if (stringmatch(tempstring,"*scanLinePeriod*")==1)
					Do
						FReadLine fileref, tempstring
						if (stringmatch(tempstring,"*scanLinePeriod*")==1)
						loc=strsearch(tempstring,"value",0)+7
						locstr=tempstring[loc,loc+8]
						v1=str2num(locstr)
						ScanLinePrd=v1*1000
						print "Scanline period is (ms)=",ScanLinePrd
						break
						endif
					while(1)
					break
				Endif
		while(1) 


	Endif

	If ((stringmatch(PVversion[0,7],"4.3.2.13")==1)||(stringmatch(PVversion[0,0],"5")==1)) // in this version of prairie view at least microns per pixel is changed in config file depending on the optical zoom used.
	
		pixelsize=McrnsPerPix
		print "Pixel size is (um)", pixelsize
		
	Else
		pixelsize=McrnsPerPix/zoom
		print "Pixel size is (um)", pixelsize
	
	Endif
	
	
	
	// loads images containing each channel name
	String/g fileName

	
	
	make/n=4 channelstoload
	channelstoload[0]=FlagCh1
	channelstoload[1]=FlagCh2
	channelstoload[2]=FlagCh3
	channelstoload[3]=FlagCh4
	
 	make/o/n=800  cyclenum
 	variable chindex
 	
 	Variable index,i,ii
	index=0
	i=0
	String tempfilecycle
	
	Do

		fileName = IndexedFile(diskfolderpath, index, ".tif")
		
		if (strlen(fileName) == 0)
			break		
		endif
		
	
		If ((stringmatch(PVversion[0],"5")==1)&&(str2num(PVversion[2])>=1))//From version 5.1 on file names include .ome before .tif
			tempfilecycle=filename[(strlen(filename)-10),strlen(filename)-9]
		Else 
			tempfilecycle=filename[(strlen(filename)-6),strlen(filename)-5]
		EndIf
	
		cyclenum[index]=str2num(tempfilecycle)
		
		for (chindex=0;chindex<4;chindex+=1)
			if (channelstoload[chindex]==1)

				//loads images from ticked channels
				If (GrepString(filename, "Ch"+num2str(chindex+1)+"_"))
					ImageLoad/O/Q/P=diskfolderpath/T=TIFF/N=$("ls_"+filesuffix+"_Ch"+num2str(chindex+1)+"_"+num2str(i)) fileName
				
				endif
			endif
		endfor
		i+=1
		index+=1
		
	while (1)
	


	
	wavestats/q cyclenum
	variable/g varcyclenum=V_max//finds number of cycle if PV has split the linescan

	
	
	string wlist=wavelist("ls_"+"*",";","")
	
	
	variable j,jj,k,m,l
	

	for (l=0;l<(itemsinlist(wlist));l+=1) //scales all raw images
		Setscale/p x,0,pixelsize,"microns", $(stringfromlist(l,wlist))
		Setscale/p y,0,scanlineprd,"ms", $(stringfromlist(l,wlist)) 
	endfor
		
//Splits in groups if needed, makes stacks and averages each stack

		for (chindex=0;chindex<4;chindex+=1)
			if (channelstoload[chindex]==1)
			
				string tempstringlist=wavelist("ls_"+filesuffix+"_Ch"+num2str(chindex+1)+"_"+"*",";","")
				for (k=0;k<groupnum;k+=1) //copies waves, and redistribute and renames according to number of groups
					for (jj=k*varcyclenum;jj<itemsinlist(tempstringlist); jj+=(groupnum*varcyclenum)) //checks for images to concatenate
						j=floor((jj-k)/(groupnum*varcyclenum))
					
						for (m=0; m<varcyclenum;m+=1)	
							Duplicate $Stringfromlist(jj+m,tempstringlist), $("list_"+num2str(k)+"_"+filesuffix+"_Ch"+num2str(chindex+1)+"_"+num2str(j)+num2str(m))
							
						endfor	
						string/g templist=wavelist("list_"+num2str(k)+"_"+filesuffix+"_Ch"+num2str(chindex+1)+"_"+num2str(j)+"*",";","")
						Concatenate/NP=1/KILL templist, $("list_"+num2str(k)+"_"+filesuffix+"_Ch"+num2str(chindex+1)+"_"+num2str(j))
						Setscale/p x,0,pixelsize,"microns", $("list_"+num2str(k)+"_"+filesuffix+"_Ch"+num2str(chindex+1)+"_"+num2str(j))
						Setscale/p y,0,scanlineprd,"ms",$("list_"+num2str(k)+"_"+filesuffix+"_Ch"+num2str(chindex+1)+"_"+num2str(j))
					endfor
			
					string templistk1=wavelist("list_"+num2str(k)+"_"+filesuffix+"_Ch"+num2str(chindex+1)+"_"+"*",";","")

				
					//creates a stack of images for each group and each channel and the average image of each stack to use for display
					if ((itemsinlist(templistk1))>2) 
						
						imagetransform stackimages $("list_"+num2str(k)+"_"+filesuffix+"_Ch"+num2str(chindex+1)+"_0")
						Duplicate M_Stack, $("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(k))
						Setscale/p x,0,pixelsize,"",$("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(k))
						Setscale/p y,0,scanlineprd,"",$("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(k))
						Imagetransform averageimage $("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(k))
						Duplicate M_Aveimage, $("ave_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(k))
						Setscale/p x,0,pixelsize,"microns", $("ave_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(k))
						Setscale/p y,0,scanlineprd,"ms",$("ave_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(k))
						If (displayflag==1) //display average image if box was checked
							Display;appendimage $("ave_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(k)) 
							ModifyGraph nticks(bottom)=30
							Setaxis/a/r left
						endif
					elseif ((itemsinlist(templistk1))==2) // Imagetransform averageimage command works only for 3d wave with >=3 layers
						
						WAVE/Z temp0,  temp1,  tempstack
						Duplicate/o/r=[0,dimsize($("list_"+num2str(k)+"_"+filesuffix+"_Ch"+num2str(chindex+1)+"_0"),0)][0,dimsize($("list_"+num2str(k)+"_"+filesuffix+"_Ch"+num2str(chindex+1)+"_0"),1)] $("list_"+num2str(k)+"_"+filesuffix+"_Ch"+num2str(chindex+1)+"_0"), temp0
						Duplicate/o/r=[0,dimsize($("list_"+num2str(k)+"_"+filesuffix+"_Ch"+num2str(chindex+1)+"_0"),0)][0,dimsize($("list_"+num2str(k)+"_"+filesuffix+"_Ch"+num2str(chindex+1)+"_0"),1)] $("list_"+num2str(k)+"_"+filesuffix+"_Ch"+num2str(chindex+1)+"_1"), temp1
						Make/n=(dimsize($("list_"+num2str(k)+"_"+filesuffix+"_Ch"+num2str(chindex+1)+"_0"),0),dimsize($("list_"+num2str(k)+"_"+filesuffix+"_Ch"+num2str(chindex+1)+"_0"),1),2),tempstack
						tempstack[][][0]=temp0[p][q]
						tempstack[][][1]=temp1[p][q]
						Rename tempstack, $("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(k))
						Setscale/p x,0,pixelsize,"",$("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(k))
						Setscale/p y,0,scanlineprd,"",$("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(k))
						Make/n=(dimsize($("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(k)),0),dimsize($("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(k)),1)) $("ave_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(k))=(temp0+temp1)/2
						Setscale/p x,0,pixelsize,"microns", $("ave_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(k))
						Setscale/p y,0,scanlineprd,"ms",$("ave_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(k))
						If (displayflag==1)
							Display;appendimage $("ave_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(k))
							ModifyGraph nticks(bottom)=30
							Setaxis/a/r left
						endif
						Killwaves temp0,temp1
					elseif ((itemsinlist(templistk1))==1) // If there is only one image per group, display this image and do not create stack or average
						
						wave/Z tempst
						Duplicate/o $stringfromlist(0,templistk1), tempst
						
						Rename tempst, $("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(k))
						Setscale/p x,0,pixelsize,"",$("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(k))
						Setscale/p y,0,scanlineprd,"",$("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(k))
						If (displayflag==1)
							Display;appendimage $stringfromlist(0,templistk1)
							ModifyGraph nticks(bottom)=30
							Setaxis/a/r left
						endif				
					endif
				endfor
	
			endif
		endfor
		
				


	
	// kills temporary waves if imagetransfor Igor function has been used
	If (waveexists(M_Stack)==1)
		Killwaves M_Stack
	Endif
	
	If (waveexists(M_Aveimage)==1)
		Killwaves M_Aveimage
	Endif
	
	If (waveexists(M_Stdvimage)==1)
		Killwaves M_Stdvimage
	Endif
	
	
End

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function CalcLSprofiles()
 
	DFREF cDF=getdatafolderdfr()
	NVAR scanlineprd,FlagCh1,FlagCh2,FlagCh3,FlagCh4, groupnum, pixelsize, varcyclenum
	SVAR filesuffix
	Variable/g Flagbgprofile, Flagbgvalue,Flagbgsub, xbgstart,xbgwidth,Flag2Ch1, Flag2Ch2,Flag2Ch3, Flag2Ch4
	variable i,j,k
	String/g plotoption, plotind
	string wavetoplot	

	
	// get status of checkboxes and variables set in Analyze image box of Linescan panel
	Controlinfo/W=linescanpanel profChannel1check
		Flag2Ch1=V_Value
	Controlinfo/W=linescanpanel profChannel2check
		Flag2Ch2=V_Value
	Controlinfo/W=linescanpanel profChannel3check
		Flag2Ch3=V_Value
	Controlinfo/W=linescanpanel profChannel4check
		Flag2Ch4=V_Value
	Controlinfo/W=linescanpanel bgprofilecheck
		Flagbgprofile=V_Value
	Controlinfo/W=linescanpanel bgvaluecheck
		Flagbgvalue=V_Value
	Controlinfo/W=linescanpanel subbgcheck
		Flagbgsub=V_Value
	Controlinfo/W=linescanpanel plotoptionsmenu
		String toplot=S_Value
	Controlinfo/W=linescanpanel plotindmenu
		String indtoplot=S_Value

	make/o/n=4 channelstocalc
	channelstocalc[0]=Flag2Ch1
	channelstocalc[1]=Flag2Ch2
	channelstocalc[2]=Flag2Ch3
	channelstocalc[3]=Flag2Ch4
	
	variable chindex
	string wlist = wavelist("list_"+"*",";","")
	
	If (itemsinlist(wlist)==0)
		doAlert 0, "no image loaded"
		return 0
	endif
	
	String firstfile=stringfromlist(0,wlist)
	
	
	//Checks if images of channels to analyze have been loaded
	If ((Flag2Ch1==1) && (waveexists($("list_0_"+filesuffix+"_Ch1_"+num2str(0)))!=1))
		doAlert 0, "Channel1 is not loaded"
		return 0
	Elseif ((Flag2Ch2==1) && (waveexists($("list_0_"+filesuffix+"_Ch2_"+num2str(0)))!=1))
		doAlert 0, "Channel2 is not loaded"
		return 0
	Elseif ((Flag2Ch3==1) && (waveexists($("list_0_"+filesuffix+"_Ch3_"+num2str(0)))!=1))
		doAlert 0, "Channel3 is not loaded"
		return 0
	Elseif ((Flag2Ch4==1) && (waveexists($("list_0_"+filesuffix+"_Ch4_"+num2str(0)))!=1))
		doAlert 0, "Channel4 is not loaded"
		return 0
	Endif
	
	string namexprofstart
	namexprofstart=uniquename("xprofstart",3,0)
	variable/g $namexprofstart
	NVAR varprofstart=$namexprofstart
	Controlinfo/W=linescanpanel profxstartset
	varprofstart=V_Value
	
	string namexprofwidth
	namexprofwidth=uniquename("xprofwidth",3,0)
	variable/g $namexprofwidth
	NVAR varprofwidth=$namexprofwidth
	Controlinfo/W=linescanpanel profwidthset
	varprofwidth=V_Value
	
	// checks if values entered for profile are within image
	If (((varprofstart+varprofwidth)>dimsize($firstfile,0)/pixelsize) || (varprofstart<0))
		doAlert 0, "profile out of image"
		return 0
	Endif
	
	If ((Flagbgsub==1)&&((Flagbgvalue+Flagbgprofile)!=1))
		doAlert 0, "choose one method (value or calculate from profile) for background subtraction"
		return 0
	Endif
	
	
	If (Flagbgprofile==1)//Use this if a part of the line has been drawn out of the dendrite
		string namexbgstart
		namexbgstart=uniquename("xbgstart",3,0)
		variable/g $namexbgstart
		NVAR varbgstart=$namexbgstart
		Controlinfo/W=linescanpanel bgxstartset
		varbgstart=V_Value
	
		string namexbgwidth
		namexbgwidth=uniquename("xbgwidth",3,0)
		variable/g $namexbgwidth
		NVAR varbgwidth=$namexbgwidth
		Controlinfo/W=linescanpanel bgwidthset
		varbgwidth=V_Value
		
		If (((varbgstart+varbgwidth)>dimsize($firstfile,0)/pixelsize) || (varbgstart<0))
			doAlert 0, "background profile out of image"
			return 0
		Endif
		


		
	endif
	
	
		
	If (Flagbgvalue==1) // If the "Enter value" checkbox was checked, use Scale by num and bg_value for background subtraction
		Controlinfo/W=linescanpanel bgvalset
		Variable/g bgvalue=V_Value
	Endif

	for (chindex=0;chindex<4;chindex+=1)
		if (channelstocalc[chindex]==1)// Makes profiles from channels to analyze
			//creates from values entered in the panel the x and y waves to use to create profiles
			make/o/n=2 xprof
			xprof[0]=varprofstart+(varprofwidth/2) 
			xprof[1]=varprofstart+(varprofwidth/2)
			make/o/n=2 yprof
			yprof[0]=0
			yprof[1]=dimsize($("list_0_"+filesuffix+"_Ch"+num2str(chindex+1)+"_"+num2str(0)),1)*scanlineprd
			Make/o/n=5 lineprofx={varprofstart, varprofstart, NaN, varprofstart+varprofwidth, varprofstart+varprofwidth} 
			Make/o/n=5 lineprofy={-INF,INF,NaN,-INF,INF}
		
			string tempname0
			tempname0=uniquename("profile_Ch"+num2str(chindex+1)+"_",4,0)
			string/g $tempname0
			If (Flagbgprofile==1)
				Make/o/n=2 xbgprof
				xbgprof[0]=varbgstart+(varbgwidth/2) //xbgprof will be used as xwave in the imagelineprofile command (center of the profile)
				xbgprof[1]=varbgstart+(varbgwidth/2)
				Make/o/n=2 ybgprof
				ybgprof[0]=0
				ybgprof[1]=dimsize($("list_0_"+filesuffix+"_Ch"+num2str(chindex+1)+"_"+num2str(0)),1)*scanlineprd
				Make/o/n=5 linebgx={varbgstart, varbgstart, NaN,varbgstart+varbgwidth, varbgstart+varbgwidth} 
				Make/o/n=5 linebgy={-INF,INF,NaN,-INF,INF}

				string tempnamebg
				tempnamebg=uniquename("bg_Ch"+num2str(chindex+1)+"_",4,0)
				string/g $tempnamebg
				for (j=0; j<groupnum; j+=1)
					Imagelineprofile/P=-2 srcwave=$("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(j)), xwave=xbgprof, ywave=ybgprof, width=floor(varbgwidth/pixelsize)
					If (waveexists(M_Imagelineprofile)==1)
						Duplicate/o M_Imagelineprofile, $("bg_profile_Ch"+num2str(chindex+1)+"_"+num2str(j))
					else
						Duplicate/o W_Imagelineprofile, $("bg_profile_Ch"+num2str(chindex+1)+"_"+num2str(j))
					endif
					
					Setscale/P x,0, dimdelta($("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(j)),0),"" $("bg_profile_Ch"+num2str(chindex+1)+"_"+num2str(j))
					Setscale/P y,0, dimdelta($("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(j)),1),""  $("bg_profile_Ch"+num2str(chindex+1)+"_"+num2str(j))
					
					If (dimsize($("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(j)),2)==0)
						Duplicate/o $("bg_profile_Ch"+num2str(chindex+1)+"_"+num2str(j)), tempwave
						Rename tempwave, $(tempnamebg+"_"+num2str(j)+"_0")
						//print  (tempnamebg+"_"+num2str(j)+"_0")
						Setscale/P x,0, dimdelta($("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(j)),1),"" $(tempnamebg+"_"+num2str(j)+"_0")
			
					Else
						for (k=0; k<dimsize($("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(j)),2);k+=1)
							Make/o/n=(dimsize($("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(j)),1)) tempwave 
							Duplicate/o $("bg_profile_Ch"+num2str(chindex+1)+"_"+num2str(j)), tempwave2
							tempwave[][]=tempwave2[p][k]
							Rename tempwave, $(tempnamebg+"_"+num2str(j)+"_"+num2str(k))
							Setscale/P x,0, dimdelta($("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(j)),1),"" $(tempnamebg+"_"+num2str(j)+"_"+num2str(k))
							
						endfor	
					Endif
					
				endfor
			endif
		
		for (i=0; i<groupnum;i+=1) // for each group creates profile waves "profile_chx_..."
			Imagelineprofile/P=-2 srcwave=$("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(i)), xwave=xprof, ywave=yprof, width=floor(varprofwidth/pixelsize)
			If (waveexists(M_Imagelineprofile)==1)//if the profiles are from a stack with >1 layer
				Duplicate/o M_Imagelineprofile, $("st_"+tempname0+"_"+num2str(i))
			else //if the profiles are from a stack of only 1 image
				Duplicate/o W_Imagelineprofile,  $("st_"+tempname0+"_"+num2str(i))
			endif

			Setscale/p x,0,scanlineprd,"ms",   $("st_"+tempname0+"_"+num2str(i))
			
				If ((Flagbgsub==1)&&(Flagbgvalue==1))//creates background corrected profile waves "c_profile_ch1_..." from entered background values 
					
					make/o/n=(dimsize( $("st_"+tempname0+"_"+num2str(i)),0), dimsize( $("st_"+tempname0+"_"+num2str(i)),1)) tempsub
					Duplicate/o  $("st_"+tempname0+"_"+num2str(i)),  tempsub
					tempsub=tempsub-bgvalue
					Rename tempsub, $("c_"+"st_"+tempname0+"_"+num2str(i))
				Elseif ((Flagbgsub==1)&&(Flagbgprofile==1))//creates background corrected profile waves "c_profile_ch1_..." from profiles background values 
				
					
					make/o/n=(dimsize( $("st_"+tempname0+"_"+num2str(i)),0), dimsize( $("st_"+tempname0+"_"+num2str(i)),1)) tempsub
					Duplicate/o  $("st_"+tempname0+"_"+num2str(i)),  tempsub
						If (dimsize($("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(i)),2)==0)
							
							wavestats/Z $(tempnamebg+"_"+num2str(i)+"_0")
							variable tempvalbg2=V_avg
							tempsub[][j]=tempsub[p][j]-tempvalbg2
						Else
							for (k=0; k<dimsize($("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(i)),2);k+=1)
								wavestats/q $(tempnamebg+"_"+num2str(i)+"_"+num2str(k))
								variable tempvalbg=V_avg
								tempsub[][k]=tempsub[p][k]-tempvalbg
							endfor
						Endif
					
				
					Rename tempsub, $("c_"+"st_"+tempname0+"_"+num2str(i))
				Endif
				
				variable endthisloop
				
				if (wavedims($("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(i)))==3)
					endthisloop= dimsize($("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(i)),2)
				else
					endthisloop=1
				endif
				for (k=0; k<endthisloop;k+=1)
					Make/o/n=(dimsize($("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(i)),1)) tempwave 
					
					Duplicate/o $("st_"+tempname0+"_"+num2str(i)), tempwave2
					tempwave[][]=tempwave2[p][k]
					Rename tempwave, $(tempname0+"_"+num2str(i)+"_"+num2str(k))// creates individual waves corresponding to each layer of the stack "profile_..." 
					//for further analysis with other procedures
					Setscale/p x,0,scanlineprd,"ms", $(tempname0+"_"+num2str(i)+"_"+num2str(k))
					Killwaves tempwave2
					
					if (waveexists($("c_"+"st_"+tempname0+"_"+num2str(i)))==1)
						Make/o/n=(dimsize($("Stack_Ch"+num2str(chindex+1)+"_"+filesuffix+"_"+num2str(i)),1)) tempcwave 
						Duplicate/o $("c_"+"st_"+tempname0+"_"+num2str(i)), tempcwave2
						tempcwave[][]=tempcwave2[p][k]
						Rename tempcwave, $("c_"+tempname0+"_"+num2str(i)+"_"+num2str(k))
						Setscale/p x,0,scanlineprd,"ms", $("c_"+tempname0+"_"+num2str(i)+"_"+num2str(k))
						Killwaves tempcwave2
					endif
					

					
				endfor	
				
			
			If (Flagbgsub==0)
				wavetoplot="st_"+tempname0
			Elseif  (Flagbgsub==1)
				wavetoplot="c_"+"st_"+tempname0
			Endif
			
			
			If (stringmatch(indtoplot,"Yes"))
				If (stringmatch(toplot,"Avg"))
					average2dwave($(wavetoplot+"_"+num2str(i)),0,1,1)
				Elseif (stringmatch(toplot,"Avg+Stdev"))
					average2dwave($(wavetoplot+"_"+num2str(i)),1,1,1)
				Endif
			Else
				If (stringmatch(toplot,"Avg"))
					average2dwave($(wavetoplot+"_"+num2str(i)),0,0,1)
				Elseif (stringmatch(toplot,"Avg+Stdev"))
					average2dwave($(wavetoplot+"_"+num2str(i)),1,0,1)
				Endif
			
			Endif
	
		endfor
		

		
		EndIf
	endfor
	
	

	
	
	//Creates Subfolder with uniquename and moves variables related to profile position in new subfolder
	string namedf
	namedf=uniquename("infoprof",11,0)
	newdatafolder :$namedf
	Setdatafolder :$namedf
	DFREF df=getdatafolderdfr()
	Setdatafolder cDF
	WAVE/Z lineprofx , lineprofy
	WAVE/Z linebgx, linebgy
	movewave :lineprofx, df
	movewave :lineprofy, df
	If ((Flagbgsub==1)&&(Flagbgprofile==1))
		movewave :linebgx, df
		movewave :linebgy, df
	Endif

	///// Now to display position of calculated profile on image select image and appendtograph lineprofy vs lineprofx
	

	killwaves xprof, yprof,xbgprof, ybgprof
	If (waveexists(M_Imagelineprofile)==1)
		killwaves M_Imagelineprofile
	elseif (waveexists(W_Imagelineprofile)==1)
		killwaves W_Imagelineprofile
	endif

End


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


Function average2dwave(wavein,plot,plotind,newname)
	WAVE wavein
	variable plot
	Variable plotind
	Variable newname
	
	If (wavedims(wavein)==1)
		display wavein
	Elseif (wavedims(wavein)==3)
		return 0
	Else
		Variable numcolumns=dimsize(wavein,1)
		Variable numptsx=dimsize(wavein,0)
		variable i,j
		make/o/n=(dimsize(wavein,0)) avg
		make/o/n=(dimsize(wavein,0)) stdev
		

		for (j=0;j<numcolumns;j+=1)
			avg[]+=  wavein[p][j]
		endfor
		avg= avg/numcolumns
		
		for (j=0;j<numcolumns;j+=1)
			stdev[]+=  (wavein[p][j])^2-(avg[p])^2
		endfor
		stdev=stdev/numcolumns
		stdev=sqrt(stdev)
		
		// newname = 0 to give new names to output waves; newname =1 to overwrite  
		If (newname==0)
			string/g nameavg=uniquename("avg_"+nameofwave(wavein),1,0)
			Duplicate/o avg,$nameavg
			Setscale/p x,0, dimdelta(wavein,0),"" $nameavg
			string/g namestdev=uniquename("std_"+nameofwave(wavein),1,0)
			Duplicate/o stdev, $namestdev
			Setscale/p x,0, dimdelta(wavein,0),"" $namestdev
			killstrings nameavg, namestdev
		Elseif (newname==1)
			Duplicate/o avg,$("avg_"+nameofwave(wavein))
			Setscale/p x,0, dimdelta(wavein,0),"", $("avg_"+nameofwave(wavein))
			Duplicate/o stdev,$("std_"+nameofwave(wavein))
			Setscale/p x,0, dimdelta(wavein,0),"", $("std_"+nameofwave(wavein))
			killwaves avg, stdev
		endif
		
		// plot=0 to plot average wave only, plot=1 to plot average + standard deviation
		// plotind=0 to plot average wave only, plotind=1 to plot also individual waves
		If ((plotind==1)&&(plot==0))
			Display
			for (j=0;j<numcolumns;j+=1)
				Appendtograph wavein[][j]
				modifygraph rgb=(0,0,0)
			endfor
			Appendtograph  $("avg_"+nameofwave(wavein))
		Elseif ((plotind==1)&&(plot==1))
			Display
			for (j=0;j<numcolumns;j+=1)
				Appendtograph wavein[][j]
				modifygraph rgb=(0,0,0)
			endfor
			Appendtograph  $("avg_"+nameofwave(wavein))
			Errorbars/L=0/Y=1 $("avg_"+nameofwave(wavein)) Y, wave=($("std_"+nameofwave(wavein)),$("std_"+nameofwave(wavein)))
		Elseif ((plotind==0)&&(plot==0))
			Display $("avg_"+nameofwave(wavein))
		Elseif ((plotind==0)&&(plot==1))
			Display $("avg_"+nameofwave(wavein))
			Errorbars/L=0/Y=1 $("avg_"+nameofwave(wavein)) Y, wave=($("std_"+nameofwave(wavein)),$("std_"+nameofwave(wavein)))
		endif
		


	Endif


End

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function oponprofiles()
	// this function finds the profiles created with CalcLSprofiles() functions, finds in the panel the channels
	// the user wants to add and if they exists create new waves: c_profile_channeltoadd1_channeltoadd2_profilenum_groupnum_waveindex
	
	DFREF cDF=getdatafolderdfr()
	NVAR Flag2Ch1, Flag2Ch2,Flag2Ch3, Flag2Ch4
	string/g chtoadd1,chtoadd2,optype
	variable/g valprofadd,checkbg
	SVAR filesuffix
	
	Controlinfo/W=linescanpanel plotproftoadd1
		 chtoadd1=S_Value
	Controlinfo/W=linescanpanel plotproftoadd2
		chtoadd2=S_Value
	Controlinfo/W=linescanpanel  profoperation
		optype=S_Value
	Controlinfo/W=linescanpanel  valproftoadd
		valprofadd=V_Value
	Controlinfo/W=linescanpanel  subbgcheck
		checkbg=V_Value
	
		
	//checks that the channels selected correspond to existing profiles
	If ( ((stringmatch(chtoadd1,"Ch1")==1) || (stringmatch(chtoadd2,"Ch1")==1)) && (waveexists($("list_0_"+filesuffix+"_Ch1_"+num2str(0)))!=1))
		doAlert 0, "profile from Channel1 does not exist"
		return 0
	Elseif ( ((stringmatch(chtoadd1,"Ch2")==1) || (stringmatch(chtoadd2,"Ch2")==1)) && (waveexists($("list_0_"+filesuffix+"_Ch2_"+num2str(0)))!=1))
		doAlert 0, "profile from Channel2 does not exist"
		return 0
	Elseif ( ((stringmatch(chtoadd1,"Ch3")==1) || (stringmatch(chtoadd2,"Ch3")==1)) && (waveexists($("list_0_"+filesuffix+"_Ch3_"+num2str(0)))!=1))
		doAlert 0, "profile from Channel3 does not exist"
		return 0
	Elseif ( ((stringmatch(chtoadd1,"Ch4")==1) || (stringmatch(chtoadd2,"Ch4")==1)) && (waveexists($("list_0_"+filesuffix+"_Ch4_"+num2str(0)))!=1))
		doAlert 0, "profile from Channel4 does not exist"
		return 0
	Endif
	
	string prefixadd1, prefixadd2, prefixadd12
	If (checkbg==1)
		prefixadd1="c_profile_"+chtoadd1+"_"
		prefixadd2="c_profile_"+chtoadd2+"_"
		if (stringmatch(optype," + ")==1)
			prefixadd12="c_profile_"+chtoadd1+chtoadd2+"_add"
		elseif (stringmatch(optype," - ")==1)
			prefixadd12="c_profile_"+chtoadd1+chtoadd2+"_min"
		elseif (stringmatch(optype," / ")==1)
			prefixadd12="c_profile_"+chtoadd1+chtoadd2+"_over"
		elseif (stringmatch(optype," x ")==1)
			prefixadd12="c_profile_"+chtoadd1+chtoadd2+"_mult"	
		endif
	Elseif (checkbg==0)
		prefixadd1="profile_"+chtoadd1+"_"
		prefixadd2="profile_"+chtoadd2+"_"
		if (stringmatch(optype," + ")==1)
			prefixadd12="profile_"+chtoadd1+chtoadd2+"_add"
		elseif (stringmatch(optype," - ")==1)
			prefixadd12="profile_"+chtoadd1+chtoadd2+"_min"
		elseif (stringmatch(optype," / ")==1)
			prefixadd12="profile_"+chtoadd1+chtoadd2+"_over"
		elseif (stringmatch(optype," x ")==1)
			prefixadd12="profile_"+chtoadd1+chtoadd2+"_mult"	
		endif
		print prefixadd12
	Endif	
	

	
	string wtoadd1=wavelist(prefixadd1+"*",";","")//+wavelist(prefixrawadd1+"*",";","")//lists existing profiles (background corrected and raw) from the first channel to add
	string wtoadd2=wavelist(prefixadd2+"*",";","")//+wavelist(prefixrawadd2+"*",";","")//lists existing profiles (background corrected and raw)  from the second channel to add
	string wtoadd12=wavelist(prefixadd12+"*",";","")//+wavelist(prefixrawadd12+"*",";","")//lists existing profiles (background corrected and raw) already additionned between two selected channels

	variable testw
	
	make/o/n=(itemsinlist(wtoadd1)) wavetestindex1
	make/o/n=(itemsinlist(wtoadd2)) wavetestindex2
	make/o/n=(itemsinlist(wtoadd12)) wavetestindex12
	
	variable indexneww1=0
	for (testw=0;testw<itemsinlist(wtoadd1);testw+=1) // loops through existing waves to find the profile index
		string tempst=stringfromlist(testw,wtoadd1)
		sscanf tempst, prefixadd1+"%f", indexneww1
		wavetestindex1[testw]=indexneww1
	endfor

	
	variable indexprofile1// finds indices of profiles that have been calculated for first chanel to add, this number is stored in variable indexprofile1
	variable numprofile1=1// finds number of profiles that have been calculated for first chanel to add, this number is stored in variable indexprofile1
	make/o/n=(itemsinlist(wtoadd1))  windex1
	for (testw=1;testw<dimsize(wavetestindex1,0);testw+=1)
		if (wavetestindex1[testw]!=wavetestindex1[testw-1])
			numprofile1+=1
			indexprofile1=wavetestindex1[testw]
			windex1[numprofile1-1]=wavetestindex1[testw]
		endif
	endfor
	deletepoints  numprofile1,(itemsinlist(wtoadd1))-numprofile1, windex1


	
	variable indexneww2=0
	for (testw=0;testw<itemsinlist(wtoadd2);testw+=1) // loops through existing waves to find the profile index
		string tempst2=stringfromlist(testw,wtoadd2)
		sscanf tempst2, prefixadd2+"%f", indexneww2
		wavetestindex2[testw]=indexneww2
	endfor

	
	variable indexprofile2// finds indices of profiles that have been calculated for second chanel to add, this number is stored in variable indexprofile2
	variable numprofile2=1// finds number of profiles that have been calculated for second chanel to add, this number is stored in variable indexprofile2
	make/o/n=(itemsinlist(wtoadd2))  windex2
	for (testw=1;testw<dimsize(wavetestindex2,0);testw+=1)
		if (wavetestindex2[testw]!=wavetestindex2[testw-1])
			numprofile2+=1
			indexprofile2=wavetestindex2[testw]
			windex2[numprofile2-1]=wavetestindex2[testw]
		endif
	endfor
	deletepoints  numprofile2,(itemsinlist(wtoadd2))-numprofile2, windex2

	
	variable indexneww12=0
	for (testw=0;testw<itemsinlist(wtoadd12);testw+=1) // loops through existing waves to find the profile index of already added channels
		string tempst12=stringfromlist(testw,wtoadd12)
		sscanf tempst12, prefixadd12+"%f", indexneww12
		wavetestindex12[testw]=indexneww12
	endfor

	
	variable indexprofile12// finds indices of profiles that have been calculated and already added, this number is stored in variable indexprofile12
	variable numprofile12=1// finds number of profiles that have been calculated and already added this number is stored in variable indexprofile12
	make/o/n=(itemsinlist(wtoadd12))  windex12
	for (testw=1;testw<dimsize(wavetestindex12,0);testw+=1)
		if (wavetestindex12[testw]!=wavetestindex12[testw-1])
			numprofile12+=1
			indexprofile12=wavetestindex12[testw]
			windex12[numprofile12-1]=wavetestindex12[testw]
		endif
	endfor
	deletepoints  numprofile12,(itemsinlist(wtoadd12))-numprofile12, windex12

	
	//if the profiles have not been added yet, create a new wave to make the sum of corresponding profiles in each channel
	
	string prefixaddnow1=prefixadd1+num2str(valprofadd)+"_"
	string prefixaddnow2=prefixadd2+num2str(valprofadd)+"_"
	
	string/g toaddnow1=wavelist(prefixaddnow1+"*",";","")
	string/g toaddnow2=wavelist(prefixaddnow2+"*",";","")
	
	variable indadd
	
	findvalue/v=(valprofadd) windex12
	variable prof12=V_value
	///performs operation on profiles depending on the op type chosen
	if (prof12==-1)
		findvalue/v=(valprofadd) windex1
		variable prof1=V_value
		findvalue/v=(valprofadd) windex2
		variable prof2=V_value		
			if ((prof1!=-1)&&(prof2!=-1))
				make/o/n=((dimsize($(stringfromlist(indadd,toaddnow1)),0)),itemsinlist(toaddnow1)) tempstack
				for (indadd=0;indadd<itemsinlist(toaddnow1);indadd+=1)
						make/o/n=((dimsize($(stringfromlist(indadd,toaddnow1)),0))) tempwave
						Duplicate $(stringfromlist(indadd,toaddnow1)) temp0
						Duplicate $(stringfromlist(indadd,toaddnow2)) temp1
						If (stringmatch(optype," + ")==1)
							tempwave=temp0+temp1
						Elseif (stringmatch(optype," - ")==1)
							tempwave=temp0-temp1
						Elseif (stringmatch(optype," / ")==1)
							tempwave=temp0/temp1
						Elseif (stringmatch(optype," x ")==1)
							tempwave=temp0*temp1
						Endif
						setscale/p x,0,dimdelta(temp0,0),"" tempwave
						variable groupindex,traceindex
						sscanf stringfromlist(indadd,toaddnow1), prefixaddnow1+"%f%*[_]%f", groupindex, traceindex
						tempstack[][indadd]=tempwave[p]
						rename tempwave $(prefixadd12+num2str(valprofadd)+"_"+num2str(groupindex)+"_"+num2str(traceindex))
						killwaves temp0, temp1
				endfor
				setscale/p x,0,dimdelta($(prefixadd12+num2str(valprofadd)+"_"+num2str(groupindex)+"_"+num2str(traceindex)),0),"" tempstack
				rename tempstack $("st_"+prefixadd12+num2str(valprofadd)+"_"+num2str(groupindex))
				string nwavetoavg="st_"+prefixadd12+num2str(valprofadd)+"_"+num2str(groupindex)
				average2dwave($nwavetoavg,0,1,1)
			else
				doAlert 0, "These profiles do not exist"
			endif
	else
		doAlert 0, "This operation has already been performed on these profiles!"
		return 0
	endif
	
		
	
	killwaves wavetestindex1, wavetestindex2, wavetestindex12, windex1, windex2, windex12
	
End

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function addimages()
/// this function creates a sum of two images selected in the linescan panel
	
	DFREF cDF=getdatafolderdfr()
	
	Controlinfo/W=linescanpanel plotimagetoadd1
		string/g imtoadd1=S_Value
	Controlinfo/W=linescanpanel plotimagetoadd2
		string/g imtoadd2=S_Value
	Controlinfo/W=linescanpanel dispaddimagecheck
		variable flagdispadd=V_Value
		
	wave/Z image1=$imtoadd1
	wave/Z image2=$imtoadd2
	
	variable dimxim1=dimsize(image1,0)
	variable dimyim1=dimsize(image1,1)
	variable dimxim2=dimsize(image2,0)
	variable dimyim2=dimsize(image2,1)	
	
	variable scalexim1=dimdelta(image1,0)
	variable scaleyim1=dimdelta(image1,1)
	variable scalexim2=dimdelta(image2,0)
	variable scaleyim2=dimdelta(image2,1)
	
	//checks if images sizes are matching	
	if ((dimxim1!=dimxim2)||(dimyim1!=dimyim2))
		doAlert 0, "images selected have different sizes!"
		return 0
	endif
		
	if ((scalexim1!=scalexim2)||(scaleyim1!=scaleyim2))
		doAlert 0, "images selected have different scaling"
		return 0
	endif
	
	string nameaddedwave // creates unique name for the summed image
	nameaddedwave=uniquename("sumimage_",4,0)
	Make/o/n=(dimxim1,dimyim1) waveadded = image1+image2
	
	setscale/p x,0,scalexim1, "microns", waveadded
	setscale/p y,0, scaleyim1, "ms" , waveadded
	
	rename waveadded, $nameaddedwave
	
	If (flagdispadd==1) // if display box is checked, display image
		display;appendimage $nameaddedwave
		Setaxis/a/r left
	endif
	
	
	
End


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function imdff(imageraw,ystart,yend,filter)

	wave imageraw
	variable ystart,yend,filter
	variable i,j,dimx,dimy,ypixstart, ypixend

	
	//wave imagedff, imagef0
	

		
	If (wavedims(imageraw)!=2)
		doAlert 0,"input wave is not an image"
		return 0
	Endif
	
	


	dimx=dimsize(imageraw,0)
	dimy=dimsize(imageraw,1)

	make/o/n=(dimx,dimy) imagedff
	make/o/n=(dimx,dimy) imagef0
	
	ypixstart=floor(ystart/dimdelta(imageraw,1))
	ypixend=floor(yend/dimdelta(imageraw,1))

		
	for (i=0;i<dimx;i+=1)
		for (j=ypixstart;j<ypixend;j+=1)
			imagef0[i]=imagef0[i]+imageraw[i][j]
		endfor
		imagef0[i]=imagef0[i]/(ypixend-ypixstart)
		imagedff[i][]=imageraw[p][q]-imagef0[i]
		imagedff[i][]=imagedff[i][q]/imagef0[i]
	endfor
	
	Setscale/p x,0,dimdelta(imageraw,0),"microns" imagedff
	Setscale/p y,0, dimdelta(imageraw,1),"ms" imagedff
	Duplicate/o imagedff, $("dff"+nameofwave(imageraw))
	
	Display;appendimage $("dff"+nameofwave(imageraw))
	Setaxis/a/r left
	ModifyImage $("dff"+nameofwave(imageraw)) ctab= {-0.5,2,Grays,0}
	
	If (filter>=3)
		Duplicate $("dff"+nameofwave(imageraw)) tempwave
		matrixfilter/n=(filter) gauss tempwave
		rename tempwave,$("f_dff"+nameofwave(imageraw)) 
		Setscale/p x,0,dimdelta(imageraw,0),"microns" $("f_dff"+nameofwave(imageraw)) 
		Setscale/p y,0, dimdelta(imageraw,1),"ms" $("f_dff"+nameofwave(imageraw)) 
		Display;appendimage $("f_dff"+nameofwave(imageraw)) 
		Setaxis/a/r left
		ModifyImage $("f_dff"+nameofwave(imageraw)) ctab= {-0.5,3,Grays,0}
	endif

	killwaves imagedff, imagef0
End


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function subimagebg(imtosub)
	wave imtosub
	Variable/g Flagbgprofile, Flagbgvalue,Flagbgsub, xbgstart,xbgwidth, bgvalue
	NVAR pixelsize,scanlineprd
	
	Controlinfo/W=linescanpanel bgprofilecheck // use profile
		Flagbgprofile=V_Value
	Controlinfo/W=linescanpanel bgvaluecheck// use value entered
		Flagbgvalue=V_Value
	Controlinfo/W=linescanpanel subbgcheck// does user want to subtract background
		Flagbgsub=V_Value
		
	If (wavedims(imtosub)!=2)
		doAlert 0,"input wave is not an image"
		return 0
	Endif
	

	If (Flagbgvalue==1) // If the "Enter value" checkbox was checked, use Scale by num and bg_value for background subtraction
		Controlinfo/W=linescanpanel bgvalset
		 bgvalue=V_Value
	Endif
	
	
	If (Flagbgprofile==1)//Use this if a part of the line has been drawn out of the dendrite
	
		string namexbgstart
		namexbgstart=uniquename("xbgstart",3,0)
		variable/g $namexbgstart
		NVAR varbgstart=$namexbgstart
		Controlinfo/W=linescanpanel bgxstartset
		varbgstart=V_Value
	
		string namexbgwidth
		namexbgwidth=uniquename("xbgwidth",3,0)
		variable/g $namexbgwidth
		NVAR varbgwidth=$namexbgwidth
		Controlinfo/W=linescanpanel bgwidthset
		varbgwidth=V_Value
		
		If (((varbgstart+varbgwidth)>dimsize(imtosub,0)/pixelsize) || (varbgstart<0))
			doAlert 0, "background profile out of image"
			return 0
		Endif
		
		Make/o/n=2 xbgprof
		xbgprof[0]=varbgstart+(varbgwidth/2) //xbgprof will be used as xwave in the imagelineprofile command (center of the profile)
		xbgprof[1]=varbgstart+(varbgwidth/2)
		Make/o/n=2 ybgprof
		ybgprof[0]=0
		ybgprof[1]=dimsize(imtosub,1)*scanlineprd
		Make/o/n=5 linebgx={varbgstart, varbgstart, NaN,varbgstart+varbgwidth, varbgstart+varbgwidth} 
		Make/o/n=5 linebgy={-INF,INF,NaN,-INF,INF}
		
		Imagelineprofile srcwave=imtosub, xwave=xbgprof, ywave=ybgprof, width=floor(varbgwidth/pixelsize)
		Duplicate/o W_Imagelineprofile,$("bg_"+nameofwave(imtosub))
		
		wavestats/q $("bg_"+nameofwave(imtosub))
		bgvalue=V_avg
		
	endif
	
	If ((Flagbgsub==1)&&((Flagbgvalue+Flagbgprofile)!=1))
		doAlert 0, "choose one method (value or calculate from profile) for background subtraction"
		return 0
	Elseif  ((Flagbgsub==1)&&((Flagbgvalue+Flagbgprofile)==1))
		Duplicate/o imtosub, cimtosub
		cimtosub-=bgvalue
		Rename cimtosub, $("c_"+nameofwave(imtosub))
		
	Endif

end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function calcall2d()
	///this function is called by the button calcallprofile. 
	//It uses the values in the panel and calculate the profiles (if possible) from all corresponding images in the folder
	//the profiles calculated will be stored as "prof_nameofwave_index"
	//if applicable the background corrected profile will be calculated and stored as "c_prof_nameofwave_index"
	
	DFREF cDF=getdatafolderdfr()
	Variable/g Flagbgprofile, Flagbgvalue,Flagbgsub, xbgstart,xbgwidth,pixelsize, scanlineprd, num2dw
	variable i
	string list2d
	
	Controlinfo/W=linescanpanel bgprofilecheck
		Flagbgprofile=V_Value
	Controlinfo/W=linescanpanel bgvaluecheck
		Flagbgvalue=V_Value
	Controlinfo/W=linescanpanel subbgcheck
		Flagbgsub=V_Value

	
	list2d=wavelist("*",";","DIMS:2")
	num2dw=itemsinlist(list2d)
	If (num2dw==0)
		doAlert 0, "no image loaded"
		return 0
	endif
	
	String firstfile=stringfromlist(0,list2d)
	
	If ((Flagbgsub==1)&&((Flagbgvalue+Flagbgprofile)!=1))
		doAlert 0, "choose one method (value or calculate from profile) for background subtraction"
		return 0
	Endif
	
	
	
	string namexprofstart
	namexprofstart=uniquename("xprofstart",3,0)
	variable/g $namexprofstart
	NVAR varprofstart=$namexprofstart
	Controlinfo/W=linescanpanel profxstartset
	varprofstart=V_Value
	
	string namexprofwidth
	namexprofwidth=uniquename("xprofwidth",3,0)
	variable/g $namexprofwidth
	NVAR varprofwidth=$namexprofwidth
	Controlinfo/W=linescanpanel profwidthset
	varprofwidth=V_Value
	
	
	
	// checks if values entered for profile are within image

	for (i=0;i<num2dw;i+=1)
		If (((varprofstart+varprofwidth)>dimsize($(stringfromlist(i,list2d)),0)/dimdelta($(stringfromlist(i,list2d)),0)) || (varprofstart<0))
			doAlert 0, "profile out of image for image "+stringfromlist(i,list2d)
		Endif
	endfor

	
	If (Flagbgvalue==1) // If the "Enter value" checkbox was checked, use Scale by num and bg_value for background subtraction
		Controlinfo/W=linescanpanel bgvalset
		Variable/g bgvalue=V_Value
	Endif
		
	If (Flagbgprofile==1)//Use this if a part of the line has been drawn out of the dendrite
		string namexbgstart
		namexbgstart=uniquename("xbgstart",3,0)
		variable/g $namexbgstart
		NVAR varbgstart=$namexbgstart
		Controlinfo/W=linescanpanel bgxstartset
		varbgstart=V_Value
	
		string namexbgwidth
		namexbgwidth=uniquename("xbgwidth",3,0)
		variable/g $namexbgwidth
		NVAR varbgwidth=$namexbgwidth
		Controlinfo/W=linescanpanel bgwidthset
		varbgwidth=V_Value
		
		If (((varbgstart+varbgwidth)>dimsize($firstfile,0)/pixelsize) || (varbgstart<0))
			doAlert 0, "background profile out of image"
			return 0
		Endif
		
	endif
	
	for (i=0;i<num2dw;i+=1)
			make/o/n=2 xprof
			xprof[0]=varprofstart+(varprofwidth/2) 
			xprof[1]=varprofstart+(varprofwidth/2)
			make/o/n=2 yprof
			yprof[0]=0
			yprof[1]=dimsize($(stringfromlist(i,list2d)),1)*dimdelta($(stringfromlist(i,list2d)),1)
			Make/o/n=5 lineprofx={varprofstart, varprofstart, NaN, varprofstart+varprofwidth, varprofstart+varprofwidth} 
			Make/o/n=5 lineprofy={-INF,INF,NaN,-INF,INF}
		
			string tempname0
			tempname0=uniquename("prof_"+stringfromlist(i,list2d)+"_",1,0)
			wave tryw=$tempname0
			
			Imagelineprofile/P=-2 srcwave=$(stringfromlist(i,list2d)), xwave=xprof, ywave=yprof, width=floor(varprofwidth/dimdelta($(stringfromlist(i,list2d)),0))
			
			Duplicate/o W_Imagelineprofile,  $tempname0
			Setscale/P x,0,dimdelta($(stringfromlist(i,list2d)),1),"ms" $tempname0
			
			If ((Flagbgsub==1)&&(Flagbgvalue==1))
				Duplicate/o $tempname0 tempwa
				tempwa-=bgvalue
				Duplicate  tempwa $("c_"+nameofwave($tempname0))
				Setscale/P x,0,dimdelta($(stringfromlist(i,list2d)),1),"ms" $("c_"+nameofwave($tempname0))
				print i,"c_"+nameofwave($tempname0)
				killwaves tempwa
			Elseif ((Flagbgsub==1)&&(Flagbgprofile==1))
				Make/o/n=2 xbgprof
				xbgprof[0]=varbgstart+(varbgwidth/2) //xbgprof will be used as xwave in the imagelineprofile command (center of the profile)
				xbgprof[1]=varbgstart+(varbgwidth/2)
				Make/o/n=2 ybgprof
				ybgprof[0]=0
				ybgprof[1]=dimsize($(stringfromlist(i,list2d)),1)*dimdelta($(stringfromlist(i,list2d)),1)
				Make/o/n=5 linebgx={varbgstart, varbgstart, NaN,varbgstart+varbgwidth, varbgstart+varbgwidth} 
				Make/o/n=5 linebgy={-INF,INF,NaN,-INF,INF}

				string tempnamebg
				tempnamebg=uniquename("bg_Ch"+stringfromlist(i,list2d)+"_",1,0)
				wave tryw2=$tempnamebg
				Imagelineprofile/P=-2 srcwave=$(stringfromlist(i,list2d)), xwave=xbgprof, ywave=ybgprof, width=floor(varbgwidth/dimdelta($(stringfromlist(i,list2d)),0))
				Duplicate/o W_Imagelineprofile, $tempnamebg
				wavestats/q $tempnamebg
				
				variable tempvalbg2=V_avg
				Duplicate/o $tempname0 tempwe
				tempwe=tempwe-tempvalbg2
				Duplicate/o tempwe $("c_"+nameofwave($tempname0))
				Setscale/P x,0,dimdelta($(stringfromlist(i,list2d)),1),"ms" $("c_"+nameofwave($tempname0))
				killwaves tempwe
			Endif
	endfor
	
end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Function SetFolderButtonProc(ba) : buttoncontrol

	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2:
			NewPath/O/Q/M="Select Folder"  diskFolderPath
			SVAR folderPath=root:loadFolder:folderPath
			if(V_flag==0)
				PathInfo diskFolderPath
				folderPath=S_path
			else
				folderPath="_none_"
			endif
		break
	endswitch

	return 0

End


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function LoadLSButtonproc(ba) : buttoncontrol

	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2:
			Loadlinescanimages()
		break
	endswitch
	
	return 0
End
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


Function CalcprofButtonproc(ba) : buttoncontrol

	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2:
			CalcLSprofiles()
		break
	endswitch
	
	return 0
End

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function oponprofbuttonproc(ba) : buttoncontrol

	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2:
			oponprofiles()
		break
	endswitch
	
	return 0
End

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function addimbuttonproc(ba) : buttoncontrol

	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2:
			addimages()
		break
	endswitch
	
	return 0
End

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function makedffbuttonproc(ba) : buttoncontrol

	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2:
			DFREF cDF=getdatafolderdfr()
			Controlinfo/W=linescanpanel imagetodff
			string/g imtodff=S_Value
			Controlinfo/W=linescanpanel valstartdff
			variable/g startdff=V_Value
			Controlinfo/W=linescanpanel valenddff
			variable/g enddff=V_Value
			
			Controlinfo/W=linescanpanel nfilter
			variable/g nnfilter=V_Value
	
			Controlinfo/W=linescanpanel subbgcheck// does user want to subtract background
			variable/g Flagbgsub=V_Value
			
			wave imagetodff=$imtodff
			
			If (flagbgsub==0)
				imdff(imagetodff,startdff,enddff,nnfilter)
			Elseif (flagbgsub==1)
				subimagebg(imagetodff)
				imdff($("c_"+nameofwave(imagetodff)),startdff,enddff,nnfilter)
			endif
		break
	endswitch
	
	return 0
End
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function CalcallButtonproc(ba) : buttoncontrol

	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2:
			Calcall2d()
		break
	endswitch
	
	return 0
End

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function MakeLinescanPanel()

	DFREF cDF=GetDataFolderdfr()
	SetDataFolder root:
	NewDataFolder/O/S loadFolder
	String/g folderpath="_none_"
	Variable/g groupn=2
	Variable/g bgxstart,bgwidth,bgval,profxstart,profwidth,valprof,dffstart,dffend, nnfilter
	SetDataFolder cDF

	DoWindow/F LineScanPanel
	if(V_flag==1)
		return 0
	Endif

	
	
	
	NewPanel /K=1 /W=(835,50,1360,600) as "LineScan Analysis"
	DoWindow/C linescanpanel
	
	Groupbox loadbox, pos={20,4}, size={490,140}, Title="Load images",fstyle=1,fsize=14
	Button SetFolder, pos={32,24},size={70,20},proc=SetFolderButtonProc, title="Set Folder"
	DrawText 115, 42,"Path:"
	TitleBox Namepath, pos={160,24}, size={300,20},variable=root:loadfolder:folderpath
	Drawtext 33, 63,"Select Channels to load:"
	CheckBox loadChannel1check, pos={190,49}, size={95,14},title="Ch1",value=0
	CheckBox loadChannel2check, pos={240,49}, size={95,14},title="Ch2",value=1
	CheckBox loadChannel3check, pos={290,49}, size={95,14},title="Ch3",value=0
	CheckBox loadChannel4check, pos={340,49}, size={95,14},title="Ch4",value=0
	
	SetVariable Groupsetnum,pos={50,68},size={166,15},title="Define groups:",value=root:loadFolder:groupn
	Checkbox displaycheck,pos={50,92}, size={95,14}, title="Display average of each group", value=0
	Button Loadlinescan, pos={32,117},size={80,20},proc=LoadLSButtonproc, title="Load Now"
	
	GroupBox analysisbox, pos={20,150}, size={490,220}, TItle="Calculate profiles",fstyle=1,fsize=14
	DrawText 33,185,"Background subtraction:" 
	Checkbox bgprofilecheck, pos={33,190},size={95,14},title="Use profile",value=1
	Setvariable bgxstartset, pos={130,190},size={70,15}, title="x start", value=root:loadFolder:bgxstart
	Setvariable bgwidthset, pos={220,190},size={125,15}, title="profile width in \F'Symbol'm\F'Arial'm", value=root:loadFolder:bgwidth
	Checkbox bgvaluecheck, pos={33,208}, size={95,14},title="Enter value", value=0
	Setvariable bgvalset, pos={129,208}, size={70,15}, title="value:", value=root:loadfolder:bgval
	Checkbox subbgcheck, pos={33,226}, size={95,14}, title="Subtract background", value=0
	DrawText 33,268,"Profile analysis:"
	Setvariable profxstartset, pos={130,250},size={70,15}, title="x start", value=root:loadFolder:profxstart
	Setvariable profwidthset, pos={220,250}, size={125,15}, title="profile width in \F'Symbol'm\F'Arial'm", value=root:loadFolder:profwidth
	DrawText 33,293,"Plot:"
	PopupMenu plotoptionsmenu, pos={33,293}, size={180,15},title="Display on graph:", mode=1, value="Avg;Avg+Stdev"
	Popupmenu plotindmenu, pos={220,293}, size={150,15}, Title="Plot individual profiles", mode=1, value="Yes;No"
	Drawtext 33, 335,"Analyze from loaded images:"
	CheckBox profChannel1check, pos={210,320}, size={95,14},title="Ch1",value=0
	CheckBox profChannel2check, pos={260,320}, size={95,14},title="Ch2",value=1
	CheckBox profChannel3check, pos={310,320}, size={95,14},title="Ch3",value=0
	CheckBox profChannel4check, pos={360,320}, size={95,14},title="Ch4",value=0
	Button Calcprofile, pos={430,316}, size={75,20}, proc=CalcprofButtonproc, title="Calculate"
	Drawtext 33, 358,"Batch analyze all images in current data folder:"
	Button Calcallprofile, pos={385,340}, size={120,20}, proc=CalcallButtonproc, title="Profiles from all images"
	
	GroupBox analysiimbox, pos={20,377}, size={490,155}, TItle="Operations on profiles and images",fstyle=1,fsize=14
	
	Drawtext 33, 418, "Operation on profiles:"
	Popupmenu plotproftoadd1, pos={152,399}, size={150,15}, Title="channel", mode=2, value="Ch1;Ch2;Ch3;Ch4"
	Popupmenu profoperation, pos={243,399}, size={150,15}, Title="", mode=4, value=" + ; - ; x ; / "
	Popupmenu plotproftoadd2, pos={285,399}, size={150,15}, Title="", mode=4, value="Ch1;Ch2;Ch3;Ch4"
	Setvariable valproftoadd, pos={340,401}, size={70,15}, title="profile:", value=valprof
	Button Addprofile, pos={430,399}, size={75,20},proc=oponprofbuttonproc, title="Calculate"
	
	Drawtext 33, 443, "Add images:"
	Controlupdate/W=linescanpanel  plotimagetoadd1
	Controlupdate/W=linescanpanel  plotimagetoadd2
	Popupmenu plotimagetoadd1, pos={33,445}, size={150,80}, value=wavelist("*",";","DIMS:2")
	Popupmenu plotimagetoadd2, pos={197,445}, size={150,80}, Title="+ ",  value=wavelist("*",";","DIMS:2")
	CheckBox dispaddimagecheck, pos={377,449}, size={95,14}, title="Display",value=1
	Button Addimages, pos={430,445}, size={75,20},proc=addimbuttonproc, title="Add"

	
	Drawtext 33, 493, "\F'Symbol'D\F'Arial'F/F image:"
	Controlupdate/W=linescanpanel imagetodff
	Popupmenu imagetodff, pos={33, 495}, size={150,80},  value=wavelist("*",";","DIMS:2")
	Setvariable valstartdff, pos={195, 497}, size={70,15}, title="t0(ms):", value=dffstart
	Setvariable valenddff, pos={266, 497}, size={50,15}, title="to:", value=dffend
	Setvariable nfilter, pos={325, 497}, size={50,15}, title="NxN", value=nnfilter
	Button Dffimage, pos={430, 495}, size={75,20}, proc=makedffbuttonproc, title="Calculate"	
	
End