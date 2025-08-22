
origIMG_AREA=0;
origIMG_MIN=0;
origIMG_MAX=0;
origIMG_MEAN=0;
origIMG_STD=0;;

//initialize progress window
progress_window_title = "[Progress]";
run("Text Window...", "name="+progress_window_title+" width=120 height=60 monospaced");

//get input and output directories
#@ Integer (label="Channel for mean measurement", value=3) CHANNEL
#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory", style = "directory") output
//set up file to record data into
stats_filename="image_data.csv";
beginStatsFile(output,stats_filename);
//required to use the bio-formats macro extensions
run("Bio-Formats Macro Extensions");
title="";
filename_prefix="";
dirname="";
list = getFileList(input);
list = Array.sort(list);

for (i = 0; i < (list.length); i++) {
path=input+File.separator+list[i];
Ext.getFormat(path, format);
printToProgressWindow("file format is: "+format,progress_window_title);
ser=0;
if (format=="Zeiss CZI"){
	printToProgressWindow ("Zeiss CZI file chosen: "+path,progress_window_title);
	//Ext.openThumbImagePlus(path);
	id=0;
	Ext.setId(path);// this initializes the file for bioformats macro extensions
	Ext.getSeriesCount(seriesCount);
	printToProgressWindow ("***************************************",progress_window_title);
	printToProgressWindow ("**"+currentTime(),progress_window_title);
	printToProgressWindow ("**STARTING PROCESSING OF: "+path,progress_window_title);
	printToProgressWindow ("**THIS IS FILE # "+(i+1)+" OF "+list.length,progress_window_title);
	printToProgressWindow ("***************************************",progress_window_title);
	series_values=newArray(0);

	imgtitle=path+"_Series_"+1;
	Ext.setSeries(ser);
	Ext.getSizeX(sizeX);
	printToProgressWindow ("Series is: "+ser+" and sizeX is: "+sizeX ,progress_window_title);
	getCZIImageInfo(path, ser);

}
else{
	printToProgressWindow ("File chosen is not a Zeiss CZI file.",progress_window_title);
}
run("Collect Garbage");
}
printToProgressWindow ("DONE",progress_window_title);
//////
// Functions
//////

// function to scan folders/subfolders/files to find files
function getCZIImageInfo(fn, ser){
		run("Collect Garbage");

		updatetxt="OPENING "+ fn+ "series "+ ser;
		printToProgressWindow(updatetxt, progress_window_title);
		run("Bio-Formats Importer", "open=&fn autoscale color_mode=Default view=Hyperstack stack_order=XYCZT series_"+ (1));
		Stack.setChannel(CHANNEL);
		getStatistics(origIMG_AREA,origIMG_MEAN,origIMG_MIN,origIMG_MAX,origIMG_STD);
		XDIM = getWidth();
		YDIM = getHeight();
		printToProgressWindow ("area: "+origIMG_AREA +" mean: "+origIMG_MEAN +" min: "+origIMG_MIN +" max: "+origIMG_MAX +" std: "+origIMG_STD ,progress_window_title);
		stats_data=newArray(fn,ser,CHANNEL,XDIM,YDIM,origIMG_AREA,origIMG_MEAN,origIMG_MIN,origIMG_MAX,origIMG_STD);
		updateStatsFile(output, stats_data);
		close("*");
		run("Collect Garbage");
}

function printToProgressWindow (text_to_print, progress_window_title){
	fx = substring(progress_window_title, 1, lengthOf(progress_window_title)-1);     
	if  (!isOpen(fx)) run("Text Window...", "name="+progress_window_title+" width=80 height=60 monospaced"); 

	print(progress_window_title,text_to_print);
	print(progress_window_title,"\n");
	return;
}

function currentTime() {
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
    timestring = "";
	
	if (hour<10) 
		timestring = timestring+"0";
	
	timestring = timestring+hour+":";
	
	if (minute<10)
		timestring = timestring+"0";
	timestring = timestring+minute+":";
	
	if (second<10)
		timestring = timestring+"0";
		
	timestring = timestring+second;
	return timestring;
}


//////
// updateStatsFile(main_directory)
//	Writes current image's statistics to a row in the combined statistics table.
//	Creates the file if it does not exist.
//  arguments:
//	  main_directory	root directory of images currently being processed
function updateStatsFile(main_directory, stats_data) {
	file_path = main_directory+File.separator+stats_filename;
	
	if(!File.exists(file_path))
		beginStatsFile(main_directory,stats_filename);
	
		row = stats_data[0];
	for(i = 1; i<stats_data.length; i++) {
		row += ","+stats_data[i];
	}
	
	File.append(row,file_path);
}

//////
// beginStatsFile(main_directory)
//  Writes a header row to a text document, to be used as a table with comma separated values
//  expected to later have statistics from each processed image added to it.
//	arguments:
//	  main_directory	root directory of image(s) currently being processed
function beginStatsFile(main_directory,sfn) {
	file_path = main_directory+File.separator+sfn;
	statsfile = File.open(file_path);
	print(statsfile, "name, series,channel, width,height,area,mean,min,max,std\r\n");
	File.close(statsfile);
}
