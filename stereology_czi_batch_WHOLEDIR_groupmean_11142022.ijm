//This macro iterates a directory of CZI files and sends the selected scene from the czi to a designated quantification script.

NO_USER_INPUT = true; // if true, does not present any dialogs requesting user input to allow running as part of a batch without interaction
USE_BATCH_MODE = true; // if true, uses batch mode to limit screen updates where possible. improves performance.
USE_RANDOM_ANGLE_FOR_START = false; // if true, use an angle-based method for determining start position rather than a simple random x,y coordinate
ASSUME_LIGHT_BACKGROUND = false; 
QUANTIFY_MORPHOMETRY = false; // use the injury map code


CHANNEL_CHOICES = newArray("1","2","3", "single channel image");
CHANNEL_TO_USE = "3";
CHANNEL_TO_THRESH = "2";
TARGET_DIRECTORY = "D:"+File.separator+"ImageJ_Output"+File.separator;
DEFAULT_SCALE = 1.8; // px/µm
SCALE_BASE_UNIT = 1;
GRID_WIDTH_UM = 500; // µm 
GRID_HEIGHT_UM = 500; // µm 
FRAME_BOX_WIDTH_UM= 300;// µm  // width of an ROI to be created for measurement/sampling
FRAME_BOX_HEIGHT_UM = 300;// µm  // height of an ROI 
FRACTION_TO_SAMPLE = 0.99; //%
ESTIMATE_AREA_SAMPLED = false; // Whether to calculate the tissue area contained in the area sampled
COUNTING_FRAME_CROSSHAIR_COUNT = 212; // Points per ROI - the actual number used will be a square number based on the square root of this number
SD_THRESHOLD_POSITIVE_MIN = 0.1; // Minimum number of SDs away from mean to be a "positive" (significant) point. Points below this level will not be counted.
SD_THRESHOLD_POSITIVE_MAX = 2; // Maximum number of SDs away from mean to be a "positive" (significant) point. Points above this level will not be counted.
SAVE_ROI_OVERLAY = true;
COLOR_DECONVOLVE_BLUE = false;
AUTOMATED_THRESHOLD_ON = true;
ENHANCE_IMAGE=false;

if(ASSUME_LIGHT_BACKGROUND) {
	threshold_step_1 = newArray(45,250); // used for threshold determining tissue to include 
	threshold_step_2 = newArray(0, 45);  // used for threshold determining area to exclude
}
else {
	threshold_step_1 = newArray(440,65535);
	threshold_step_2 = newArray(0, 400);
}

DOWNSCALE = false;
DOWNSCALE_FACTOR = 0.125;
// Get directories  and desired series x size and group mean and SD
#@ Integer (label="8 bit group tissue mean", value=50) GROUP_MEAN
#@ Integer (label="8 bit group tissue stdev", value=15) GROUP_SD
#@ Integer (label="X dimension minimum", value=11000) SIZEX_MIN
#@ Integer (label="X dimension maximum", value=65000) SIZEX_MAX
#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory", style = "directory") output
#@ File (label = "Image processing macro", style = "file") scriptpath

// use a dialog to ask for parameters.
// this dialog should match the one used in the image processing script,
// as it is a replacement for running it individually on each script

Dialog.create("Parameters for image procesing");

Dialog.addMessage("General setup");
 //Dialog.addNumber("Subset or All : Subset=1 or All=2",2 );
Dialog.addCheckbox("Area morphometry quantification", QUANTIFY_MORPHOMETRY);
Dialog.addCheckbox("Automated thresholding for area", AUTOMATED_THRESHOLD_ON);
Dialog.addCheckbox("Use batch mode: Yes is faster, no shows more actions",USE_BATCH_MODE);
Dialog.addCheckbox("Image background is LIGHT", ASSUME_LIGHT_BACKGROUND);
Dialog.addCheckbox("Color deconvolve (for IHC)", COLOR_DECONVOLVE_BLUE);
Dialog.addCheckbox("Enhance Image", ENHANCE_IMAGE);
Dialog.addRadioButtonGroup("Color channel to quantify", CHANNEL_CHOICES, 1, CHANNEL_CHOICES.length, CHANNEL_TO_USE);
Dialog.addRadioButtonGroup("Color channel to use for determining area", CHANNEL_CHOICES, 1, CHANNEL_CHOICES.length, CHANNEL_TO_THRESH);
Dialog.addCheckbox("Save image with selected ROIs overlaid on the tissue mask", SAVE_ROI_OVERLAY);
Dialog.addMessage("Grid configuration");
Dialog.addMessage("A grid of larger boxes is laid out with smaller frame(ROI) boxes inside the upper-left corner of each. Counting is performed inside the smaller ROIs.");
Dialog.addNumber("Scale - pixels per µm", DEFAULT_SCALE);
Dialog.addNumber("Large grid box width in µm", GRID_WIDTH_UM);
Dialog.addNumber("Large grid box height in µm", GRID_HEIGHT_UM);
Dialog.addNumber("Frame (ROI) box width in µm", FRAME_BOX_WIDTH_UM);
Dialog.addNumber("Frame (ROI) box height in µm", FRAME_BOX_HEIGHT_UM);
Dialog.addNumber("Percent of ROIs to use for counting", FRACTION_TO_SAMPLE);
Dialog.addCheckbox("Estimate percent of total tissue within the area sampled", ESTIMATE_AREA_SAMPLED);
Dialog.addMessage("Counting configuration");
Dialog.addMessage("Within each frame/ROI, a number of points are counted. If a square frame/ROI is used, the number of points should be a square number\n to allow an equal number of points in both the horizontal and vertical directions.");
Dialog.addMessage("Points are counted as positive if the pixel value at that point is greater than the lower limit and less than the upper limit number\n of standar devations from the mean tissue pixel value.");
Dialog.addNumber("Number of points to count within each ROI (usually a square number):", COUNTING_FRAME_CROSSHAIR_COUNT);
Dialog.addNumber("Positive point threshold: minimum z-score:", SD_THRESHOLD_POSITIVE_MIN);
Dialog.addNumber("Positive point threshold: maximum z-score:", SD_THRESHOLD_POSITIVE_MAX);


Dialog.show();

QUANTIFY_MORPHOMETRY = Dialog.getCheckbox();
AUTOMATED_THRESHOLD_ON = Dialog.getCheckbox();
USE_BATCH_MODE=Dialog.getCheckbox();
ASSUME_LIGHT_BACKGROUND=Dialog.getCheckbox();
COLOR_DECONVOLVE_BLUE=Dialog.getCheckbox();
ENHANCE_IMAGE=Dialog.getCheckbox();
CHANNEL_TO_USE=Dialog.getRadioButton();
CHANNEL_TO_THRESH=Dialog.getRadioButton();
SAVE_ROI_OVERLAY=Dialog.getCheckbox();
DEFAULT_SCALE = Dialog.getNumber();
GRID_WIDTH_UM = Dialog.getNumber();//grid width in um
GRID_HEIGHT_UM = Dialog.getNumber();//grid height in um
FRAME_BOX_WIDTH_UM= Dialog.getNumber(); //frame width in um
FRAME_BOX_HEIGHT_UM= Dialog.getNumber(); //frame height in um
FRACTION_TO_SAMPLE = Dialog.getNumber();
ESTIMATE_AREA_SAMPLED = Dialog.getCheckbox();
COUNTING_FRAME_CROSSHAIR_COUNT = Dialog.getNumber();
SD_THRESHOLD_POSITIVE_MIN=Dialog.getNumber();
SD_THRESHOLD_POSITIVE_MAX=Dialog.getNumber();

if (!AUTOMATED_THRESHOLD_ON){
	Dialog.create("Parameters for tissue selection");
	Dialog.addMessage("Tissue selection");
	Dialog.addMessage("A threshold is applied using pixel values to determine the area of the image containing tissue.");
	Dialog.addMessage("This is done in two parts, first with a theshold indicating areas to include, then a threshold for areas to exclude.");
	Dialog.addNumber("Inclusion, lower:", threshold_step_1[0]);
	Dialog.addNumber("Inclusion, upper:", threshold_step_1[1]);
	Dialog.addNumber("Exclusion, lower:", threshold_step_2[0]);
	Dialog.addNumber("Exclusion, upper:", threshold_step_2[1]);
	Dialog.show();
	threshold_step_1[0] = Dialog.getNumber();
	threshold_step_1[1] = Dialog.getNumber();
	threshold_step_2[0] = Dialog.getNumber();
	threshold_step_2[1] = Dialog.getNumber();
}

if(DOWNSCALE)
	DEFAULT_SCALE = DEFAULT_SCALE * DOWNSCALE_FACTOR;

// the arguments should match the variables set by the dialog and initial setup,
// and also match those used in the image procesing script
// they must be in a format tha tcan be executed as code, to easily allow the variables to be set
// when ran as eval(arguments);
arguments = "";
arguments += ";;"+NO_USER_INPUT;
arguments += ";;"+QUANTIFY_MORPHOMETRY;
arguments += ";;"+AUTOMATED_THRESHOLD_ON;
arguments += ";;"+USE_BATCH_MODE;
arguments += ";;"+ASSUME_LIGHT_BACKGROUND;
arguments += ";;"+COLOR_DECONVOLVE_BLUE;
arguments += ";;"+ENHANCE_IMAGE;
arguments += ";;"+CHANNEL_TO_USE;
arguments += ";;"+CHANNEL_TO_THRESH;
arguments += ";;"+SAVE_ROI_OVERLAY;
arguments += ";;"+DEFAULT_SCALE;
arguments += ";;"+GRID_WIDTH_UM;
arguments += ";;"+GRID_HEIGHT_UM;
arguments += ";;"+FRAME_BOX_WIDTH_UM;
arguments += ";;"+FRAME_BOX_HEIGHT_UM;
arguments += ";;"+threshold_step_1[0];
arguments += ";;"+threshold_step_1[1];
arguments += ";;"+threshold_step_2[0];
arguments += ";;"+threshold_step_2[1];
arguments += ";;"+FRACTION_TO_SAMPLE;
arguments += ";;"+ESTIMATE_AREA_SAMPLED;
arguments += ";;"+COUNTING_FRAME_CROSSHAIR_COUNT;
arguments += ";;"+SD_THRESHOLD_POSITIVE_MIN;
arguments += ";;"+SD_THRESHOLD_POSITIVE_MAX;
arguments += ";;"+GROUP_MEAN;
arguments += ";;"+GROUP_SD;
//for the whole directory batch, each czi needs its own subdir.  So we need to send a new output dir with each call to the stereology macro.
// find a way to make it up (maybe use the first 6 chars of the czi filename), make a new subdir in the chosen output dir, and then send the subdir path to the stereology macro.
//arguments += ";;"+output;



// FIRST, initialize progress bar
	progress_window_title = "[Progress]";
	run("Text Window...", "name="+progress_window_title+" width=80 height=60 monospaced");

//required to use the bio-formats macro extensions
run("Bio-Formats Macro Extensions");
title="";
filename_prefix="";
dirname="";
list = getFileList(input);
list = Array.sort(list);

//path = File.openDialog(title);

for (i = 0; i < list.length; i++) {
path=input+File.separator+list[i];
//filename_prefix=substring(list[i],0,8);
t=list[i];
l=t.lastIndexOf(list[i]);
f=l-5; 
if (f<0) {f=0;}
dirname=substring(list[i],f,l);


Ext.getFormat(path, format);
printToProgressWindow("file format is: "+format,progress_window_title);
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
	for (ser=0; ser<seriesCount; ser++) {
		imgtitle=path+"_Series_"+ser;
		Ext.setSeries(ser);
		Ext.getSizeX(sizeX);
		printToProgressWindow ("Series is: "+ser+" and sizeX is: "+sizeX ,progress_window_title);
		if ( (sizeX<SIZEX_MAX) & (sizeX>SIZEX_MIN) ){
			printToProgressWindow ("adding series "+ser+" to array for counting...",progress_window_title);
			series_values=Array.concat(series_values,ser);
		}
	}
	//ok, now we've loaded an array with the numbers of the series we want to open and quantify.
	//this next for loop goes through the array and opens each series then runs the function that runs the stereology macro in sequence for each selected series. 
	
	

	for (ser=0; ser<lengthOf(series_values); ser++) {
		processCZISeries(path,dirname,series_values[ser]+1,arguments);

	}
}
else{
	printToProgressWindow ("File chosen is not a Zeiss CZI file.",progress_window_title);
}
run("Collect Garbage");
}

//////
// Functions
//////

// function to scan folders/subfolders/files to find files
function processCZISeries(fn,op_prefix,seriesnum,arguments){
		run("Collect Garbage");
		//timestring = currentTime();

		if(DOWNSCALE) {
			xscale = DOWNSCALE_FACTOR;
			yscale = DOWNSCALE_FACTOR;
			run("Scale...", "x=&xscale y=&yscale interpolation=Bilinear average create");
			print ("downscaled, whatever that means");
		}
		updatetxt="OPENING "+ fn+ "series "+ seriesnum+ " because sizeX is >"+SIZEX_MIN+ ", and < "+ SIZEX_MAX;
		printToProgressWindow(updatetxt, progress_window_title);
		run("Bio-Formats Importer", "open=&fn autoscale color_mode=Default view=Hyperstack stack_order=XYCZT series_"+ (seriesnum));
		printToProgressWindow("OPENED, now running stereology macro"+scriptpath,progress_window_title);	
		script_output=createNewDirectory(output,op_prefix);
		printToProgressWindow("will create dir called: "+script_output,progress_window_title);
		arguments += ";;"+script_output;
		printToProgressWindow("Macro arguments string: "+arguments,progress_window_title);
		runMacro(scriptpath, arguments);
		close("*");
		run("Collect Garbage");
}

function createNewDirectory (rootdir,dirname){
  myDir = rootdir+File.separator+dirname;
  printToProgressWindow("making "+myDir,progress_window_title);
  File.makeDirectory(myDir);
  if (!File.exists(myDir))
      exit("Unable to create directory");
  return myDir;	
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

/*
function processFolder(input, progress_description) {
	list = getFileList(input);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		progress_description = progress_description +"";
		progress_description += "" +currentTime() + " - Current file: " + list[i] + "\r\n";
		updateTextBoxProgressBar(progress_window_title,i,list.length,progress_description);
		
		if(File.isDirectory(input + File.separator + list[i]))
		{
			progress_description = processFolder(input + File.separator + list[i], progress_description);
		}
		else {
			processFile(input, list[i]);
		}
	}
	return progress_description;
}





function updateTextBoxProgressBar(window_title,current,max,additional_text) {
	//╔╗╚╝═║█ <- these don't display properly in the text window, unfortunately.

	bar_top =   "|--------------------|";
	bar_bottom ="|--------------------|";
	bar_empty  = "                    ";
	bar_full =   "====================";

	progress_percent = floor((current/max) * 100);
	progress = floor((current/max) * lengthOf(bar_full));
	
	bar_current = "|";
	bar_current = bar_current + substring(bar_full, 0, progress);
	bar_current = bar_current + substring(bar_empty, progress, lengthOf(bar_empty));
	bar_current = bar_current + "|" + " "+  progress_percent+"%";

	progress_bar_contents = bar_top + "\r\n" + bar_current +"\r\n" + bar_bottom +"\r\n" + additional_text;
	
	print(progress_window_title, "\\Update:"+progress_bar_contents);
	
	logfile = File.open(output+File.separator+"batch_log.txt");
	print(logfile, additional_text);
	File.close(logfile);
}
*/
