// Hutchens lab 
//modified for REEMCIL images 05312021


// ImageJ macro which facilitates automated Cavalieri stereology using slide-scanned images.
// Original code created by Kirsti Golgotiu in the OHSU Anesthesiology & Perioperative Medicine Vascular Imaging Core 
// Project direction Michael Hutchens, MD.  Extensive rewriting by Nick McClellan in the Spring of 2018.  Subsequent modifications Hutchens
// Works best with multichannel jpg images
//_As of Summer 2019 handles 3 color tiff extracted from CZIs also
//
// If you use this macro in published analysis, please consider citing it:
// Wakasaki R, Eiwaz M, Matsushita K, Golgotiu K, Hutchens MP.
// Automated systematic random sampling and Cavalieri stereology of histologic sections demonstrating acute tubular necrosis after cardiac arrest and cardiopulmonary resuscitation in the mouse.
// Histology & Histopathology
// 2018 Nov;33(11):1227-1234. doi: 10.14670/HH-18-012.
// PMID: 29901212
//

// Define parameters with default values
NO_USER_INPUT = false; // if true, does not present any dialogs requesting user input to allow running as part of a batch without interaction
USE_BATCH_MODE = true; // if true, uses batch mode to limit screen updates where possible. improves performance.
USE_RANDOM_ANGLE_FOR_START = false; // if true, use an angle-based method for determining start position rather than a simple random x,y coordinate
ASSUME_LIGHT_BACKGROUND = false; 
QUANTIFY_MORPHOMETRY = false; // use the injury map code



//  Diagram to explain terminology
// 							  ▼ crosshairs (points sampled)
//	┌──────┬──────┐			┌─▼────┬──────┐
//	│ ROI/ │      │			│ xxxx │      │
//	│ FRAME│      │			│ xxxx │      │
//  ├──────┘      │			├──────┘      │
//  │    GRID     │			│             │
//	│             │			│             │
//  └─────────────┘			└─────────────┘
//
//	A "Frame" or ROI is an area sampled. It is a subset of a grid, where
//  the grid is used for spacing out the ROIs / frames. ROI is also used
// to describe, in general, a region selected in ImageJ.
//

CHANNEL_CHOICES = newArray("red", "green", "blue", "grayscale");
CHANNEL_TO_USE = "red"; // options are all, grayscale, red, green, blue
TARGET_DIRECTORY = "D:"+File.separator+"ImageJ_Output"+File.separator;
DEFAULT_SCALE = 5.3; // px/µm
SCALE_BASE_UNIT = 1;
GRID_WIDTH_UM = 100; // µm 
GRID_HEIGHT_UM = 100; // µm 
FRAME_BOX_WIDTH_UM= 50;// µm  // width of an ROI to be created for measurement/sampling
FRAME_BOX_HEIGHT_UM = 50;// µm  // height of an ROI 
FRACTION_TO_SAMPLE = 0.99; //%
ESTIMATE_AREA_SAMPLED = false; // Whether to calculate the tissue area contained in the area sampled
COUNTING_FRAME_CROSSHAIR_COUNT = 64; // Points per ROI - the actual number used will be a square number based on the square root of this number
SD_THRESHOLD_POSITIVE_MIN = 1.5; // Minimum number of SDs away from mean to be a "positive" (significant) point. Points below this level will not be counted.
SD_THRESHOLD_POSITIVE_MAX = 99; // Maximum number of SDs away from mean to be a "positive" (significant) point. Points above this level will not be counted.
SAVE_ROI_OVERLAY = true;
COLOR_DECONVOLVE_BLUE = false;
AUTOMATED_THRESHOLD_ON = true;
ENHANCE_IMAGE=false;


if(ASSUME_LIGHT_BACKGROUND) {
	threshold_step_1 = newArray(45,250); // used for threshold determining tissue to include 
	threshold_step_2 = newArray(0, 45);  // used for threshold determining area to exclude
}
else {
	threshold_step_1 = newArray(5,250);
	threshold_step_2 = newArray(0, 3);
}

// 
// process any arguments that may have been passed to the macro
//  arguments may be set from the command line, or when called 
//  from another macro when running as part of a batch
arguments = getArgument();
if(lengthOf(arguments) > 0) {
	argarray = split(arguments, ";;");
	
	NO_USER_INPUT 				= (parseInt(argarray[0]) == 1);
	QUANTIFY_MORPHOMETRY 		= (parseInt(argarray[1]) == 1);
	AUTOMATED_THRESHOLD_ON		= (parseInt(argarray[2]) == 1);
	USE_BATCH_MODE 				= (parseInt(argarray[3]) == 1);
	ASSUME_LIGHT_BACKGROUND 	= (parseInt(argarray[4]) == 1);
	ENHANCE_IMAGE				= (parseInt(argarray[5]) == 1);
	CHANNEL_TO_USE 				= argarray[6];
	SAVE_ROI_OVERLAY			= (parseInt(argarray[7]) == 1);
	DEFAULT_SCALE 				= parseFloat(argarray[8]);
	GRID_WIDTH_UM 				= parseFloat(argarray[9]);
	GRID_HEIGHT_UM 				= parseFloat(argarray[10]);
	FRAME_BOX_WIDTH_UM 			= parseFloat(argarray[11]);
	FRAME_BOX_HEIGHT_UM 		= parseFloat(argarray[12]);
	threshold_step_1[0]			= parseFloat(argarray[13]);
	threshold_step_1[1]			= parseFloat(argarray[14]);
	threshold_step_2[0]			= parseFloat(argarray[15]);
	threshold_step_2[1]			= parseFloat(argarray[16]);
	FRACTION_TO_SAMPLE 			= parseFloat(argarray[17]);
	ESTIMATE_AREA_SAMPLED		= (parseInt(argarray[18]) == 1);
	COUNTING_FRAME_CROSSHAIR_COUNT = parseFloat(argarray[19]);
	SD_THRESHOLD_POSITIVE_MIN 		= parseFloat(argarray[20]);
	SD_THRESHOLD_POSITIVE_MAX 		= parseFloat(argarray[21]);
	TARGET_DIRECTORY			= argarray[22];
}
else {
	// no arguments were passed.
	NO_USER_INPUT = false;
}

// Ensure a clean staring environment
roiManager("Reset");
run("Clear Results");
run("Set Scale...", "distance=0");

// record original image title
original_image_name = getTitle ();

// Find and create the directories
if(!NO_USER_INPUT) {
	path = getDirectory("Main_folder");
	Dialog.create("Main_folder");
	TARGET_DIRECTORY = path;
}
else {
	path = TARGET_DIRECTORY+File.separator+original_image_name+File.separator;
	
	if(!File.isDirectory(TARGET_DIRECTORY))
		File.makeDirectory(TARGET_DIRECTORY);
	
	if(!File.isDirectory(path))
		File.makeDirectory(path);
}


// create directories
path1 = path + "1_RESULTS & OUTPUT IMAGES";
File.makeDirectory (path1);
path2 = path + "2_FRAMES";
File.makeDirectory (path2);
path3 = path + "3_NTH_TILES_SUBSET";
File.makeDirectory (path3);
path4 = path +  "4_CROSSHAIR_IMAGES_SUBSET";
File.makeDirectory (path4);
path5 = path +  "5_THRESHOLD_POINTS";
File.makeDirectory (path5);

// Set the directories for crosshair, nth tile, and threshold points images
path_nth_tile = path3+File.separator;
path_cross_hairs = path4+File.separator;
path_threshold_points = path5+File.separator;

Dialog.create("Parameters for image procesing");

Dialog.addMessage("General setup");
 //Dialog.addNumber("Subset or All : Subset=1 or All=2",2 );
Dialog.addCheckbox("Area morphometry quantification", QUANTIFY_MORPHOMETRY);
Dialog.addCheckbox("Automated thresholding for area", AUTOMATED_THRESHOLD_ON);
Dialog.addCheckbox("Use batch mode: Yes is faster, no shows more actions",USE_BATCH_MODE);
Dialog.addCheckbox("Image background is LIGHT", ASSUME_LIGHT_BACKGROUND);
Dialog.addCheckbox("Color deconvolve selected ROIs for blue (iron stain)", COLOR_DECONVOLVE_BLUE);
Dialog.addRadioButtonGroup("Color channel to use", CHANNEL_CHOICES, 1, CHANNEL_CHOICES.length, CHANNEL_TO_USE);
Dialog.addCheckbox("Save image with selected ROIs overlaid on the tissue mask", SAVE_ROI_OVERLAY);

Dialog.addMessage("Grid configuration");
Dialog.addMessage("A grid of larger boxes is laid out with smaller frame(ROI) boxes inside the upper-left corner of each. Counting is performed inside the smaller ROIs.");
Dialog.addNumber("Scale - pixels per µm", DEFAULT_SCALE);
Dialog.addNumber("Large grid box width in µm", GRID_WIDTH_UM);
Dialog.addNumber("Large grid box height in µm", GRID_HEIGHT_UM);
Dialog.addNumber("Frame (ROI) box width in µm", FRAME_BOX_WIDTH_UM);
Dialog.addNumber("Frame (ROI) box height in µm", FRAME_BOX_HEIGHT_UM);
Dialog.addNumber("Percent of ROIs to use for counting", FRACTION_TO_SAMPLE);
Dialog.addCheckbox("Estimate percent of total tissue within the area sampled", false);

/*
// These settings are not necessary here as either the user will be prompted for them interactively while macro is running, or they
// will be provided as arguments when running as a batch
Dialog.addMessage("Tissue selection");
Dialog.addMessage("A threshold is applied using pixel values to determine the area of the image containing tissue.");
Dialog.addMessage("This is done in two parts, first with a theshold indicating areas to include, then a threshold for areas to exclude.");
Dialog.addNumber("Inclusion, lower:", threshold_step_1[0]);
Dialog.addNumber("Inclusion, upper:", threshold_step_1[1]);
Dialog.addNumber("Exclusion, lower:", threshold_step_2[0]);
Dialog.addNumber("Exclusion, upper:", threshold_step_2[1]);
*/

Dialog.addMessage("Counting configuration");
Dialog.addMessage("Within each frame/ROI, a number of points are counted. If a square frame/ROI is used, the number of points should be a square number\n to allow an equal number of points in both the horizontal and vertical directions.");
Dialog.addMessage("Points are counted as positive if the pixel value at that point is greater than the lower limit and less than the upper limit number\n of standar devations from the mean tissue pixel value.");
Dialog.addNumber("Number of points to count within each ROI (usually a square number):", COUNTING_FRAME_CROSSHAIR_COUNT);
Dialog.addNumber("Positive point threshold: minimum z-score:", SD_THRESHOLD_POSITIVE_MIN);
Dialog.addNumber("Positive point threshold: maximum z-score:", SD_THRESHOLD_POSITIVE_MAX);

if(!NO_USER_INPUT)
	Dialog.show();

//subset_or_all = Dialog.getNumber();
QUANTIFY_MORPHOMETRY = Dialog.getCheckbox();
AUTOMATED_THRESHOLD_ON = Dialog.getCheckbox();
USE_BATCH_MODE=Dialog.getCheckbox();
ASSUME_LIGHT_BACKGROUND=Dialog.getCheckbox();
COLOR_DECONVOLVE_BLUE=Dialog.getCheckbox();
CHANNEL_TO_USE=Dialog.getRadioButton();
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

boxx = GRID_WIDTH_UM*DEFAULT_SCALE;//grid width in px
boxy = GRID_HEIGHT_UM*DEFAULT_SCALE; //grid height in px
boxxframe = FRAME_BOX_HEIGHT_UM*DEFAULT_SCALE; //frame width in px
boxyframe = FRAME_BOX_HEIGHT_UM*DEFAULT_SCALE;  //frame height in px

MATH_COUNT_FRAME_NUMBER = sqrt(COUNTING_FRAME_CROSSHAIR_COUNT);
scale_conversion_factor = (DEFAULT_SCALE/SCALE_BASE_UNIT);

run("Select None");

// Output parameters being used to a file
recordParametersToFile(path1+File.separator+"PARAMETERS.txt");

// Select only desired channel
if(CHANNEL_TO_USE == "grayscale") {
	// convert to grayscale
	run("16-bit");
}
else {
	// must be one of: red, green, blue

	run("Split Channels");
	
	// close other channels
	if(CHANNEL_TO_USE != "red") {
		selectWindow ("C1-"+original_image_name);
		//selectWindow (original_image_name + " (red)");
		run ("Close");	
	}
	
	if(CHANNEL_TO_USE != "green") {
		selectWindow ("C2-"+original_image_name);
		//selectWindow (original_image_name + " (green)");
		run ("Close");	
	}
	
	//if(CHANNEL_TO_USE != "blue") {	
	//	selectWindow ("C3-"+original_image_name);
	//#	//selectWindow (original_image_name + " (blue)");
	//#	run ("Close");	
//	}	
}

// the title of the image window likely changed, save the new title.
image = getTitle();
run("Grays"); //ensure we are showing grey scale images.   THis just changes the LUT, but sets the LUT for all subsequent image saves.  It could be A different LUT if wanted.

if (COLOR_DECONVOLVE_BLUE==true){//before we resize the image, make a jpg copy -- color deconvolve needs to be done on the original.
	//run("Duplicate...", "duplicate");
	//input_image=image+"-1"; //this is the image we will save as jpg to be used as the source for thresholding and tissue ROI making
	//selectWindow(input_image);
	//rename("INPUT_IMAGE");
	//saveAs("jpeg",path+"INPUT_IMAGE");//might need to dup and rename here.
	run("RGB Color");
	input_image=getTitle();
	//waitForUser("debug");
}

// expand the canvas size by 2 box widths / heights.
origH = getHeight();
origW = getWidth();
origBD = bitDepth();
expandW = (origW+(boxx*2));
expandH = (origH+(boxy*2));


run("Canvas Size...", "width="+expandW+" height="+expandH+" position=Center zero");

run("Set Scale...", "distance=&DEFAULT_SCALE known=&SCALE_BASE_UNIT pixel=1 unit=µm global");
run("Set Measurements...", "area mean min max standard area_fraction display redirect=None decimal=0");
run("Colors...", "foreground=light background=black selection=yellow");


//if we are color deconvolving, we assume the the starting image is opened from the .czi file.  It needs to be made into RGB (done above)
//But the deconvolution needs to happen before there is data loss, and the automated 
//tissue area determination doesn't work on deconvolved images.  So:
//1.  Duplicate the czi-sourced image after the resizing done above
//2.  Save the original image as jpg and make sure the title is correct for future steps
//3.  Use the duplicate (hi res) for deconvolution
//4.  Save the deconvolved image somewhere as hi res tiff
//5.  Generate the ROI's using the jpg
//6.  Get rid of the jpg and load up the deconvolved tiff that we saved in step 4
//7.  Measure/save ROI images of the deconvolved TIFF


setBatchMode (USE_BATCH_MODE);
name=getTitle();
H1 = getHeight();
W1 = getWidth();
H = getHeight();
W = getWidth();

//record some pertinent data about the original image which we will report out at the end -- might be used to normalize across groups of images.

origIMG_AREA=0;
origIMG_MIN=0;
origIMG_MAX=0;
origIMG_MEAN=0;
origIMG_STD=0;;
origIMG_PCTSAT=0;
getStatistics(origIMG_AREA,origIMG_MEAN,origIMG_MIN,origIMG_MAX,origIMG_STD);

// Prepare the tissue map (mask), with or without the QUANTIFY_MORPHOMETRY
// Resulting state should be a final tissue map window, and the original image window.
tissue_map_window_title = '';

if (QUANTIFY_MORPHOMETRY == true) {
	results = prepare_with_injurymap();
	KIDNEY_COMPUTED_AREA = results[0];
	tissue_map_window_title = results[1];
}
else {
	results = prepare_without_injurymap();
	KIDNEY_COMPUTED_AREA = results[0];
	tissue_map_window_title = results[1];
}

selectWindow(tissue_map_window_title); // use the tissue mask.

H = getHeight();
W = getWidth();

//
// Determine random start position
//

startCoordinates = random_start_position(W, H, boxx, boxy, USE_RANDOM_ANGLE_FOR_START);
startX=startCoordinates[0];
startY=startCoordinates[1];

//
// Locate box for start of grid
//

Xvalues=newArray(0);

//Define parameters and start mpoints of boxes

X=startX;
while (X>0) {
	Xvalues=Array.concat(Xvalues,X);
	X=X-boxx;
}

X=startX+boxx;
while (X<W-boxx/2) {
	Xvalues=Array.concat(Xvalues,X);
	X=X+boxx;
}

Yvalues=newArray(0);
Y=startY;
while (Y>0) {
	Yvalues=Array.concat(Yvalues,Y);
	Y=Y-boxy;
}

Y=startY+boxy;
while (Y<H-boxy/2) {
	Yvalues=Array.concat(Yvalues,Y);
	Y=Y+boxy;
}

Xlist=newArray(0);
Xtemp=newArray(Yvalues.length);
Ylist=newArray(0);

for (j=0; j<Xvalues.length; j++) {
	Array.fill(Xtemp, Xvalues[j]);
	Xlist=Array.concat(Xlist,Xtemp);
	Ylist=Array.concat(Ylist,Yvalues);
}

//create a tabulated list with all possible x and y start points -- starting from the center of the image
Array.show("GRID_X_Y_LIST", Xlist,Ylist);

Xlist_length = Xlist.length;

GRID = getImageID();
makeSelection("point", Xlist, Ylist);

roiManager("Add");
roiManager("Save", path1+File.separator+"GRID_POINTS.zip");


run("Set Measurements...", "area mean standard min centroid display redirect=None decimal=0");
roiManager("Select", 0);
run ("Measure");

saveAs("Results", path1+File.separator+"GRID_VALUES.csv");
run ("Close");

roiManager("Reset");
run("Line Width...", "line=4");

selectWindow ("Results");
run ("Close");


//
// Create grid and counting frames / ROIs
//


//open(path1+File.separator+"GRID_VALUES.csv");
//Table.rename("GRID_VALUES.csv", "Results") ;
//n=nResults;
// First create grid boxes
//for (k=0;k<n;k++)  //TO FIX 06302019: This loop is really slow because it keeps having to reload the results window.  Load the grid values into an array before this loop and use that
//{
//	//waitForUser("about to look for results windpw");
//	selectWindow ("ORIGINAL_CROPPED");  //We were! Fixed! I think!  ...measuring zero because we select the wrong window here? (was "results")
//	xpoint= getResult ("Xlist",k);
//	//waitForUser("xpoint is: ",xpoint);
//	xpointscaled = (xpoint*DEFAULT_SCALE);
//	ypoint = getResult ("Ylist",k);
//	ypointscaled = (ypoint*DEFAULT_SCALE);	
//	makeRectangle (xpoint, ypoint, boxx, boxy);
//	run ("Measure");
//	//waitForUser("made rect and measured");
//	me= getResult("Mean");
//	s=getResult("StdDev");
//	//waitForUser("measured mean//stdev mean is:",me);
//
//	if (me>0) {
//		roiManager("Add");
//	}
//
//	
//	//reset the results window
//	selectWindow ("Results");
//	run ("Close");
//	open(path1+File.separator+"GRID_VALUES.csv");
//	Table.rename("GRID_VALUES.csv", "Results") ;
//}


//comment out 406-434.  Rewrite below to use xlist and ylist array instead of loaded file
//BEGIN REWRITTEN LOOP
n=Xlist.length;
//yn=Ylist.length;
//waitForUser("xlist length is ",n);
//waitForUser("ylist length is ",yn);

//This is the first of 2 very similar loops.
//We loop through a list of x/y coordinates and make a rectangle at each one.
//if the mean pixel value of the rectangle is greater than zero, we add it to the ROI manager
//After the loop is done, the ROIs (rectangles which were not zero) are saved to a file called
//ALT_GRID_BOXES.zip
//So this is the loop that measures grid boxes and saves them
// First create grid boxes
for (k=0;k<n;k++)
{
	selectWindow ("ORIGINAL_CROPPED");
	xpoint= Xlist[k];
	xpointscaled = (xpoint*DEFAULT_SCALE);
	ypoint = Ylist[k];
	ypointscaled = (ypoint*DEFAULT_SCALE);
	makeRectangle (xpoint, ypoint, boxx, boxy);
	run ("Measure");
	me= getResult("Mean");
	s=getResult("StdDev");

	if (me>0) {
		roiManager("Add");
	}
	//waitForUser("sorry this is annoying, but k is now",k);
}
//END REWRITTEN LOOP





num_rois=roiManager("Count"); 
for (z=0; z<num_rois; z++) {
	roiManager ("Select", z);
	roiManager ("Rename", z+1);
}

roiManager("Save", path1+File.separator+"ALT_GRID_BOXES.zip");
roiManager("Reset");

// This creates the FRAME/ROI boxes in a similar loop to above
//This is the second of 2 loops.  This loop goes through the same X/Y coordinates above,
//but makes rectangles that are FRAME size, not GRID size
//See the top of the program for the distinction between grids and frames.
//then measures them, and if nonzero adds them to ROI manager.
//Then those ROI's are saved as ALT_SAMPLE_BOXES.zip.
//So this is the loop that saves the ROI's that actually get counted
open(path1+File.separator+"GRID_VALUES.csv");
Table.rename("GRID_VALUES.csv", "Results");
for (k=0;k<n;k++) {
	xpoint= Xlist[k];
	xpointscaled = (xpoint*DEFAULT_SCALE);
	ypoint = Ylist[k];
	ypointscaled = (ypoint*DEFAULT_SCALE);
	makeRectangle (xpoint,ypoint, boxx, boxy);
	run ("Measure");  
	me= getResult("Mean");
	s=getResult("StdDev");
	if (me>0) { 
		makeRectangle (xpoint,ypoint,boxxframe,boxyframe);
		run ("Measure");
		me= getResult("Mean");
		s=getResult("StdDev");
		if (me>0)
			roiManager("Add");
	}
}
//waitForUser("about to count ROIs in the ROI manager in the second loop");
num_rois=roiManager("Count");

//waitForUser("2nd loop Counted",num_rois);

for (z=0; z<num_rois; z++) {
	roiManager ("Select", z);
	roiManager ("Rename", z+101);
}
roiManager("Save", path1+File.separator+"ALT_SAMPLE_BOXES.zip");
	
// 
// calculate number of ROI frames to sample to get the requested FRACTION_TO_SAMPLE
// This is the interval required to create the requested FRACTION_TO_SAMPLE percentage
// of ROI frames (in nth_tile directory) from the complete set (frames directory)
nROIs = roiManager("count");

nROIsbyPCT = round (nROIs*FRACTION_TO_SAMPLE);

INT_FRACTION = (100*FRACTION_TO_SAMPLE);
ROI_INTERVAL = (100/INT_FRACTION);
RANDOM_START = (random*ROI_INTERVAL);

	
	if (COLOR_DECONVOLVE_BLUE==true){  //do the color deconvolution and close all but the blue image before saving the tile image
		//waitForUser("debug");
		setBatchMode (false);
		selectWindow("ORIGINAL_CROPPED"); 
		conv_image=getTitle(); 
		run("Colour Deconvolution", "vectors=[FastRed FastBlue DAB]");
		//waitForUser("debug");
		close(conv_image+"-(Colour_1)");
		close(conv_image+"-(Colour_3)");
		//waitForUser("debug");
		//close(conv_image);//get rid of the starting image to save memory
		close("Colour Deconvolution");
		close("ORIGINAL_CROPPED");
		selectWindow(conv_image+"-(Colour_2)");
		rename("ORIGINAL_CROPPED");
		run("8-bit");
		//waitForUser("debug before sub background");
		//run("Subtract Background...", "rolling=10 light sliding");
		run("Enhance Contrast...", "saturated=0.5 normalize");
		setBatchMode (USE_BATCH_MODE);
		//waitForUser("debug done with deconvolve routine");	
}
//Save histogram of original image for quality control, then enhance contrast (or otherwise manipulate image) and save a new histogram again for QC
selectWindow("ORIGINAL_CROPPED");
myEnhanceImage("ORIGINAL_CROPPED");

selectWindow("ORIGINAL_CROPPED");

// Save ROIs as individual images
t=roiManager("count");
for (m=0;m<t;m++) {
	selectWindow("ORIGINAL_CROPPED"); 
	roiManager("Select",m);
	run("Copy");
	run("Internal Clipboard");
	saveAs("jpeg", path2+File.separator +"B-"+m+1);
	run("Close"); // closes the new clipboard image
}

close("*"); // close all open image windows, sparing other windows . FIX:  THis could be a problem, I put it in and I can take it out any time I want


// Save every nth image in path2 as an image in path_nth_tile
// Uses sequence tool's increment funtion to determine

run("Image Sequence...", "open=&path2 starting=&RANDOM_START increment=&ROI_INTERVAL sort");
run("Stack to Images");

N = nImages;
for (i=0; i<N; i++) {//FIX: This routine assumes that all open images except original_croppped should be saved.  That's a problem since imageJ updates.
//likely the fix is to explicity call each window by title, then saveas, instead of saving all windows which arent original_cropped.
    window_name=getTitle();
    dir = path_nth_tile + window_name +".jpg";
    

	//if(getTitle() != "ORIGINAL_CROPPED") {
	if (startsWith(window_name,"B-")){
		saveAs("jpeg", dir);
		run("Close");
	}
}


// Prepare to draw and measure crosshairs
// In the path_nth_tile folder, there should be the set of base images on which the crosshairs
// will be drawn.
// 
// The function drawCrosshairsAndMeasure is used, which will open the image file from the source directory,
// lay out a grid, measure each point, draw crosshairs/circles on the points, then close.
//
// At the end of this section, path_cross_hairs will contain an image for every image in path_nth_tile,
//  with the addtion of crosshairs/circles laid out in a grid on each.
// The Results window will also be loaded with mean value measurements for under each of these points.

// ensure results are set up cleanly and as expected
run("Set Measurements...", "mean display redirect=None decimal=0");
run("Clear Results");

input=path_nth_tile;
output=path_cross_hairs;

// Process each file with drawCrosshairsAndMeasure(...)
list = getFileList(input);
for (i = 0; i < list.length; i++) {
        drawCrosshairsAndMeasure(input, output, list[i]);
	}

close("*"); // close all open image windows, sparing other windows

saveAs("Results", path1+File.separator+"RESULTS_CROSS_HAIRS.csv");


stats_results = savestats(path1,"RESULTS_CROSS_HAIRS.csv"); // savestats calculates and saves statistics based on the measured points


// Again open the images in the path_nth_tile,
// this time draw circles around points if the measured value at that point is greater
// than the set threshold number of standard devations from the mean - labeling the "positive" points"
list = getFileList(input);
for (i = 0; i < list.length; i++) {
	output=path_threshold_points;
	circlePointsOverThreshold(input, output, list[i], stats_results[0], stats_results[1]);
}

close("*"); // close all open images, sparing other windows



// Estimate the percent area sampled
if(ESTIMATE_AREA_SAMPLED)
	calculatePercentAreaSampled(KIDNEY_COMPUTED_AREA);

// Output ROI overlay image
if(SAVE_ROI_OVERLAY)
	outputROIOverlayImage(path1);

if(!NO_USER_INPUT)
	waitForUser ("All Done");



//////////////////////////////////////////////////////////////////////////// 
///
/// Common Functions
///
////////////////////////////////////////////////////////////////////////////

//////
// drawCrosshairsAndMeasure(input, output, filename)
//  Describe action of this function here.
// 	Arguments:
//   input		Input directory ...
//   output		Output directory ...
//	 filename	...
//	 Lay out points ("crosshairs") being measured, take measurements, and save images
function drawCrosshairsAndMeasure(input, output, filename) {
    open(input + filename);
    

	image=getTitle();
	H = getHeight();
	W = getWidth();
	
	// MATH_COUNT_FRAME_NUMBER is the square root of the parameter COUNTING_FRAME_CROSSHAIR_COUNT,
	//	the number of sample points to put in an ROI

	// create a grid array with all boxes across entire image
	boxx = round(W/MATH_COUNT_FRAME_NUMBER);
	boxy = round(H/MATH_COUNT_FRAME_NUMBER);

	MATH_COUNT_FRAME_NUMBERV2 = (MATH_COUNT_FRAME_NUMBER*2);

	startX=round(W/MATH_COUNT_FRAME_NUMBERV2); //IF YOU WANT TO START FROM THE TOP LEFT CORNER OF THE IMAGE
	startY=round(H/MATH_COUNT_FRAME_NUMBERV2); //IF YOU WANT TO START FROM THE TOP LEFT CORNER OF THE IMAGE

	Xvalues=newArray(0);

	// start at X start point, add point to array, then count to the left (lower values) and repeat until reaching the edge of image
	X=startX;
	while (X>0) {
		Xvalues=Array.concat(Xvalues,X);
		X=X-boxx;
	}

	// start at the next point following the start point, add point to array, then count to the right (higher values) and repeat until reaching edge of image
	X=startX+boxx;
	while (X<W-round(boxx/MATH_COUNT_FRAME_NUMBER)) {
		Xvalues=Array.concat(Xvalues,X);
		X=X+boxx;
	}
	
	// start at Y start point, add point to array, then count to up (lower values) and repeat until reaching the edge of image
	Yvalues=newArray(0);
	Y=startY;
	while (Y>0) {
		Yvalues=Array.concat(Yvalues,Y);
		Y=Y-boxy;
	}

	// start at the next point following the start point, add point to array, then count to the right (higher values) and repeat until reaching edge of image
	Y=startY+boxx;
	while (Y<H-round(boxy/MATH_COUNT_FRAME_NUMBER)) {
		Yvalues=Array.concat(Yvalues,Y);
		Y=Y+boxy;
	}

	
	// create array with all possible Y values for each X
	Xlist=newArray(0);
	Xtemp=newArray(Yvalues.length);
	Ylist=newArray(0);

	for (j=0; j<Xvalues.length; j++) {
		Array.fill(Xtemp, Xvalues[j]);
		Xlist=Array.concat(Xlist,Xtemp);
		Ylist=Array.concat(Ylist,Yvalues);
	}

	// create a tabulated list with all possible x and y start points -- starting from the center of the image
	Array.show(Xlist,Ylist);

	// Select all the points underneath crosshairs and then measure the pixel value under each crosshair
	run("Line Width...", "line=2");
	run("Colors...", "foreground=yellow background=black selection=magenta");
	randomroiID = getImageID();
	run("RGB Color");
	run("Point Tool...", "type=Crosshair color=Yellow size=Large");
	
	makeSelection("point", Xlist, Ylist);
	
	roiManager("Reset");
	roiManager("Add");
	roiManager("Measure");
	
	// TODO: The ROI manager/results could be saved to a file,
	// then reused when returing to draw the circles for points over threshold rather
	// than repeating all the work just completed
	// This could, actually, be broke out to a separate function and save the points here
	// then load the points at this location here in both drawCrosshairsAndMeasure() and circlePointsOverThreshold()
	
	boxid = getTitle();

	run("Select None");
	roiManager("Show None");

	setForegroundColor(255,255,0); // yellow

	setLineWidth(0.5 * DEFAULT_SCALE);
	valueRadius = 5 * DEFAULT_SCALE;
	
	// compare each point's value to the threshold value, then draw a circle if above the threshold
	for(i = 0; i<(nResults);i++) {
		valueX = DEFAULT_SCALE * getResult("X", i);
		valueY = DEFAULT_SCALE * getResult("Y", i);
		
		drawOval(valueX - valueRadius, valueY - valueRadius, valueRadius*2, valueRadius*2);
	}
	
	saveAs("jpeg", output+filename);
	roiManager("Show All without labels");
	run("Select None");
	roiManager ("Reset");
	close();
}

// 
//	
// 
function prepare_with_injurymap() {
	// IF INJURY MAP == YES
	// NEW KIDNEY INJURE COLOR THRESHOLDING SCRIPT SECTION
	KIDNEY_COMPUTED_AREA = 0;

	run("Duplicate...", "title=ORIGINAL_CROPPED");
	selectWindow(image);
	run("Close");
	selectWindow("ORIGINAL_CROPPED");
	setBatchMode (false);
	run("Duplicate...", "title=tissue_thresh_round_1");
	run("16-bit");
	run("Despeckle");
	run("Threshold...");
	setThreshold(5, 255);
	waitForUser("Adjust threshold to capture all kidney tissue (i.e. RED color should include all tissue and not extend into voids)");
	setBatchMode (USE_BATCH_MODE);
	run("Convert to Mask");
	run("Fill Holes");
	run("Close-");
	run("Analyze Particles...", "size=10-Infinity show=Masks");
	run("Create Selection");
	roiManager("Add");
	waitForUser("Confirm that selection was made.  \nYellow line should surround tissue and a line should be in ROI manager window.  \nIF NOT PRESS T, DO NOT PRESS UNLESS MANAGER IS EMPTY");
	selectWindow("tissue_thresh_round_1");
	run("Close");
	selectWindow("Mask of tissue_thresh_round_1");
	run("Close");
	roiManager("Select", 0);
	roiManager("Rename", "OUTLINE");

	selectWindow("ORIGINAL_CROPPED");
	run("Select None");
	setBatchMode (false);
	run("Duplicate...", "title=tissue_thresh_round_2");
	run("16-bit");
	run("Threshold...");
	setThreshold(0, 1);
	waitForUser("Adjust threshold so that excluded tissue is marked, (i.e. red color should cover black regions)");
	setBatchMode (USE_BATCH_MODE);
	run("Convert to Mask");
	run("Analyze Particles...", "size=1000-Infinity show=Masks");
	run("Create Selection");
	roiManager("Add");
	selectWindow("tissue_thresh_round_2");
	run("Close");
	selectWindow("Mask of tissue_thresh_round_2");
	run("Close");
	roiManager("Select", 1);
	roiManager("Rename", "BLACK_EXCLUSIONS");

	selectWindow("ORIGINAL_CROPPED");
	run("Select None");
	run("Duplicate...", "title=tissue_thresh_round_3");
	run("8-bit");
	roiManager("Select", 0);

	run("Clear Outside");

	setForegroundColor(255, 255, 255);
	setBackgroundColor(0, 0, 0);

	run("Fill", "slice");
	roiManager("Select", 1);
	setBackgroundColor(0, 0, 0);
	run("Clear", "slice");
	run("Select None");
	setThreshold(1, 255);
	run("Analyze Particles...", "size=500-Infinity show=Masks");
	run("Create Selection");
	roiManager("Add");
	selectWindow("tissue_thresh_round_3");
	run("Close");
	selectWindow("Mask of tissue_thresh_round_3");
	run("Close");
	roiManager("Select", 2);
	roiManager("Rename", "TISSUE");

	roiManager("Select", 0);
	roiManager("Delete");
	roiManager("Select", 0);
	roiManager("Delete");

	selectWindow("ORIGINAL_CROPPED");
	roiManager("Select", 0);

	setBackgroundColor(0, 0, 0);

	run("Clear Outside");
	roiManager("Select", 0);
	roiManager("Measure");

	KIDNEY_COMPUTED_AREA= getResult("Area");

	// tissue mask image

	//selectWindow("ORIGINAL_CROPPED");
	run("Select None");
	run("Duplicate...", "TISSUE_MASK");
	roiManager("Select", 0);
	//roiManager ("Measure");
	setBackgroundColor(0, 0, 0);
	run("Clear Outside");
	setForegroundColor(0, 75, 0);
	run("Fill");
	run("Select None");
	run("Copy");
	run("Internal Clipboard");
	saveAs("png", path1+File.separator+"TISSUE_MASK");
	mask_window_name = getTitle();
	
	selectWindow("ORIGINAL_CROPPED-1");
	run ("Close");

	// NOW GET RBC, INJURY, AND HEALTHY AREAS SEPARATED
	// GET AUTO ENTROPY MAX AND MIN FOR RBC AND INJURY REGION
	run("Duplicate...", "title=tester");
	run("16-bit");
	run("Set Measurements...", "area mean min max display redirect=None decimal=2");
	setAutoThreshold("MaxEntropy dark");
	run("Create Selection");
	roiManager("Add");
	run("Measure");

	resetThreshold();
	run("Select None");
	MAXENTROPY=getResult("Max",1);
	MINENTROPY=getResult("Min",1);
	NEWMINENTROPY = (MINENTROPY-10);
	print ("THRESHOLD_VALUES:");
	print ("AUTO_ENTROPY_MAX ; INJURY PLUS RBC ", MAXENTROPY);
	print ("AUTO_ENTROPY_MIN ; INJURY PLUS RBC ", NEWMINENTROPY);

	run("Threshold...");
	setThreshold(NEWMINENTROPY, MAXENTROPY);
	waitForUser("Adjust threshold so that stained area is captured and unstained is not.");

	// USER MODIFICATION OPTION, CAPTURE THE RESULTS FOR RBC AND INJURY VALUE
	run("Create Selection");
	roiManager("Add");
	run("Measure");

	maxrbcandinjury=getResult("Max",2);
	minrbcandinjury=getResult("Min",2);
	print ("USER_DEFINED_MAX ; INJURY PLUS RBC ", maxrbcandinjury);
	print ("USER_DEFINED_MIN ; INJURY PLUS RBC ", minrbcandinjury);

	run("Select None");
	resetThreshold();
	run("Select None");
	selectWindow("tester");
	run ("Close");
	roiManager ("Select", 2);
	roiManager ("Delete");
	roiManager ("Select", 1);
	roiManager ("Delete");
	//roiManager("Reset");
	//run("Clear Results");
	//selectWindow("ORIGINAL_CROPPED");

	String.copyResults();
	IJ.deleteRows(2, 3);

	String.copyResults();
	IJ.deleteRows(1, 1);

	// USER TO DEFINE RANGES FOR RBC, INJURED, HEALTHY
	// NOW TIME TO SEPARATE THE INJURY AREA FROM THE RBC REGIONS

	selectWindow("ORIGINAL_CROPPED");
	run("Select None");
	run("Duplicate...", "title=THRESHOLD_RBC_INJURED_HEALTHY");
	run("16-bit");
	run("Set Measurements...", "area mean min max display redirect=None decimal=2");

	setAutoThreshold("Default dark");
	run("Threshold...");
	setThreshold(minrbcandinjury, maxrbcandinjury);
	run("Create Selection");
	roiManager("Add");
	roiManager("Select", 1);
	roiManager("Rename", "INJURY&RBC");

	// NOW WE ARE LOOKING WITHIN THE INJURY AREA FOR RBCS (SOMETIMES THEY ARE BRIGHER, SOMETIMES DIMMER,SO TO TEASE IT OUT OF THE INJURY AREA, WE ARE EXTRACTING THESE BY SIZE AND CIRCULARITY)
	run("Select None");
	run("Analyze Particles...", "size=5-100 circularity=0.30-1.00 show=Masks");
	run("Create Selection");
	roiManager("Add");
	selectWindow("Mask of THRESHOLD_RBC_INJURED_HEALTHY");
	run("Close");

	selectWindow("THRESHOLD_RBC_INJURED_HEALTHY");
	roiManager("Select", 2);
	roiManager("Rename", "RBC");
	run("Measure");


	// GET RBC RESULTS FOR FINAL REPORT
	maxrbc=getResult("Max",1);
	minrbc=getResult("Min",1);
	arearbc = getResult("Area",1);
	run("Select None");
	roiManager("Select", newArray(1,2));
	roiManager("XOR");
	roiManager("Add");
	roiManager("Select", 3);
	roiManager("Rename", "INJURY");
	run("Measure");


	maxinjury=getResult("Max",2);
	mininjury=getResult("Min",2);
	areainjury = getResult("Area",2);
	run("Select None");
	selectWindow("THRESHOLD_RBC_INJURED_HEALTHY");
	roiManager("Select", newArray(0,1));
	roiManager("XOR");
	roiManager("Add");
	roiManager("Select", 4);
	roiManager("Rename", "HEALTHY");
	run("Measure");


	max_healthy=getResult("Max",3);
	min_healthy=getResult("Min",3);
	area_healthy = getResult("Area",3);

	print ("Color_Threshold_Results:");

	print ("Area_RBC_"+name+"_"+arearbc);
	print ("Max_RBC_"+name+"_"+maxrbc);
	print ("Min_RBC_"+name+"_"+minrbc);
	print ("Area_Injury_"+name+"_"+areainjury);
	print ("Max_Injury_"+name+"_"+maxinjury);
	print ("Min_Injury_"+name+"_"+mininjury);
	print ("Area_Healthy_"+name+"_"+area_healthy);
	print ("Max_Healthy_"+name+"_"+max_healthy);
	print ("Min_Healthy_"+name+"_"+min_healthy);

	selectWindow("Log");
	saveAs("Text", path1+File.separator+"HEALTHY_INJURY_&_RBC_AREA_&_THRESHOLD");


	run("Select None");
	resetThreshold();


	selectWindow("THRESHOLD_RBC_INJURED_HEALTHY");
	run("Select None");
	run("8-bit");
	roiManager("Select", 4);
	setForegroundColor(75, 75, 75);
	run("Fill");
	roiManager("Select", 3);
	setForegroundColor(150, 150, 150);
	run("Fill");
	roiManager("Select", 2);
	setForegroundColor(255, 255, 255);
	run("Fill");
	run("Select None");


	saveAs("jpeg", path1+File.separator+"THRESHOLD_RBC_INJURED_HEALTHY_MAP");
	roiManager ("Select All");
	roiManager("Save", path1+File.separator+name+"_THRESH_AREA_ROI.zip");


	setResult("Label", 0, "TOTAL_TISSUE_AREA_"+name);
	updateResults();
	setResult("Label", 1, "RBC_THRESH_AREA_"+name);
	updateResults();
	setResult("Label", 2, "INJURED_THRESH_AREA_"+name);
	updateResults();
	setResult("Label", 3, "HEALTHY_THRES_AREA_"+name);
	updateResults();

	//run("blue orange icb");

	run ("Close");


	// PREP FOR GRIDS

	roiManager("Reset");
	saveAs("Results", path1+File.separator+"RBC_INJURED_HEALTHY_RANGES_&_AREA.csv");
	
	return newArray(KIDNEY_COMPUTED_AREA, mask_window_name);
}

function prepare_without_injurymap() {
	// QUANTIFY_MORPHOMETRY != true
	//	
	// NEW KIDNEY INJURE COLOR THRESHOLDING SCRIPT SECTION
	
	// This section generates a mask for area containing tissue.
	// This is done is several steps
	//  First, the mask is created by what has tissue - "inclusion"
	//  Second, a mask is created by what to exclude - "exclusion" intended to help eliminate some of the specks/noise/artifact outside of the tissue
	//  Third, generate a combined mask by erasing everything outside of "inclusion", and then clearing everything inside "exclusion"
	//	  then cleaning up the resulting image to remove some artifact and produce a clean mask 
	
	KIDNEY_COMPUTED_AREA = 0;

	// Step 1:
	//  First mask, "inclusion"

	setBatchMode(false); // duplicate does not work correctly in batch modes
	run("Duplicate...", "title=ORIGINAL_CROPPED");
	setBatchMode (USE_BATCH_MODE);
	selectWindow(image);
	run("Close");

	setBatchMode (false); // duplicate does not work correctly in batch mode
	selectWindow("ORIGINAL_CROPPED");
	setBatchMode (false);
	run("Duplicate...", "title=tissue_thresh_round_1");
	selectWindow("tissue_thresh_round_1");
	setBatchMode (USE_BATCH_MODE);
	
	run("16-bit");
	
	
	// Invert colors if running with a light background, so all operations can be ran as though the background was dark
	// since original code was designed to work with a dark background.
	// This needs to be done each time a new mask image is generated.
	if(ASSUME_LIGHT_BACKGROUND) {
		run("Invert"); }

	run("Despeckle");
	wait(250);
	
	selectWindow("tissue_thresh_round_1");
	
	setThreshold(threshold_step_1[0], threshold_step_1[1]);
	wait(500);
	
	if (!AUTOMATED_THRESHOLD_ON){
		run("Threshold...");	
		if(!NO_USER_INPUT)
			waitForUser("Adjust threshold to capture all kidney tissue (i.e. RED color should include all tissue and not extend into voids)");
		}
	else{
		setBatchMode (false); 
		setAutoThreshold("Otsu dark");
		setBatchMode (USE_BATCH_MODE);

		}
	selectWindow("tissue_thresh_round_1"); // reselect window since user was asked to click on things, and may have selected the wrong window
	
	run("Convert to Mask");
	run("Fill Holes");
	
	run("Analyze Particles...", "size=10-Infinity show=Masks");
	run("Create Selection");
	roiManager("Add");
	
	selectWindow("tissue_thresh_round_1");
	run("Close");
	selectWindow("Mask of tissue_thresh_round_1");
	run("Close");

	roiManager("Select", 0);
	roiManager("Rename", "OUTLINE");


	// Step 2
	//  Second mask, "exclusion"
	setBatchMode (false); // duplicate does not work correctly in batch mode
	selectWindow("ORIGINAL_CROPPED");
	run("Select None");
	run("Duplicate...", "title=tissue_thresh_round_2");
	selectWindow("tissue_thresh_round_2");
	setBatchMode (USE_BATCH_MODE);		
	run("16-bit");

	if(ASSUME_LIGHT_BACKGROUND)
		run("Invert"); 

	
	wait(250);
	selectWindow("tissue_thresh_round_2");
	setThreshold(threshold_step_2[0], threshold_step_2[1]);
	wait(500); // delay before showing threshold image as there are some occasional errors in the threshold window that may be timing dependent. 
	
	

	if (!AUTOMATED_THRESHOLD_ON){
		if(!NO_USER_INPUT)
			run("Threshold...");
			waitForUser("Adjust to display black exclusion regions, (i.e. RED color should cover empty regions)");
		}
	else{
		setBatchMode (false); 
		setAutoThreshold("Otsu");
		setBatchMode (USE_BATCH_MODE);
	}
	selectWindow("tissue_thresh_round_2"); // select the correct window again, as the user was just asked to click on things and may have selected the wrong window.
	
	run("Convert to Mask");
	run("Analyze Particles...", "size=1000-Infinity show=Masks");
	run("Create Selection");
	roiManager("Add");

	selectWindow("tissue_thresh_round_2");
	run("Close");
	selectWindow("Mask of tissue_thresh_round_2");
	run("Close");

	roiManager("Select", 1);
	roiManager("Rename", "BLACK_EXCLUSIONS");

	
	// Step 3
	//  Third mask, 
	
	// At this point, this is the expected contents of roiManger
	// roiManger:
	//  0	OUTLINE				Outline of the tissue to include
	//	1	BLACK_EXCLUSIONS	Outside area to exclude, called "black" due to the expected black background
	
	selectWindow("ORIGINAL_CROPPED");
	run("Select None");
	run("Duplicate...", "title=tissue_thresh_round_3");
	
	run("8-bit");
	// Invert again.
	if(ASSUME_LIGHT_BACKGROUND)
		run("Invert"); 
	
	// Select outline of area to include (OUTLINE), clear outside this area to black, then fill in the inside with white
	// Background color should be (black) at this point, though it isn't set
	setBackgroundColor(0, 0, 0);
	setForegroundColor(255, 255, 255);
	
	roiManager("Select", 0);
	run("Clear Outside");
	run("Fill", "slice");
	

	// Now select area determined for exclusion (BLACK_EXCLUSIONS), and set it to black.
	// This should largely overlap with the prior area outside the outline, but will additionally exlcude some areas.
	setBackgroundColor(0, 0, 0);
	setForegroundColor(255, 255, 255);
	
	roiManager("Select", 1);
	run("Clear", "slice");
	run("Select None");
	
	// Create a selection of the area to include, the "tissue"
	setThreshold(1, 255);
	run("Analyze Particles...", "size=500-Infinity show=Masks");
	run("Create Selection");
	roiManager("Add");
	roiManager("Select", 2);
	roiManager("Rename", "TISSUE");
	
	// Finish step 3, clean up
	selectWindow("tissue_thresh_round_3");
	run("Close");
	selectWindow("Mask of tissue_thresh_round_3");
	run("Close");

	// Delete the first two regions from the ROI manager, OUTLINE and BLACK_EXCLUSIONS. 
	// After this, the ROI manager should contain only elemet 0, TISSUE
	roiManager("Select", 0);
	roiManager("Delete");
	roiManager("Select", 0);
	roiManager("Delete");


	// The final tissue mask is ready, stored in the ROI manager as TISSUE
	// Now apply the mask to the original image
	selectWindow("ORIGINAL_CROPPED");
	roiManager("Select", 0);

	// Now, depending on the background color, the cleared area should be set
	// to either light or dark. This is solely for visual representation to the user,
	// not for further operations.
	if(ASSUME_LIGHT_BACKGROUND)
		setBackgroundColor(255, 255, 255);
	else
		setBackgroundColor(0, 0, 0);

	run("Clear Outside");
	roiManager("Select", 0);
	roiManager("Measure");

	// store the area of TISSUE in KIDNEY_COMPUTED_AREA
	KIDNEY_COMPUTED_AREA = getResult("Area"); // Gets the correct computed area
	
	//
	// Generate an image containing the tissue mask
	//
	selectWindow("ORIGINAL_CROPPED"); // Explicitly select this window, though it is expected, rather than assume. The user might have clicked somewhere else.
	run("Select None");
	run("Duplicate...", "TISSUE_MASK");
	selectWindow("ORIGINAL_CROPPED-1");
	roiManager("Select", 0); // select TISSUE

	// for the tissue mask, use black background, green tissue
	setBackgroundColor(0, 0, 0);
	setForegroundColor(0, 75, 0);
	
	run("Clear Outside"); // clear outside the tissue
	run("Fill"); // fill the inside
	
	// Save completed image mask to file.
	run("Select None");//FIX this seems unlikely to make saving the tissue mask save anything
	run("Copy"); // copies image to clipboard
	run("Internal Clipboard"); // makes new image from clipboard
	//I told myself to uncomment the folllowing line, and I did it.  So if it doesnt work it's my fault
	saveAs("png", path1+File.separator+"TISSUE_MASK"); // saves image to file
	mask_window_name = getTitle();
	
	selectWindow("ORIGINAL_CROPPED-1");
	run ("Close"); 
	selectWindow("ORIGINAL_CROPPED");
	return newArray(KIDNEY_COMPUTED_AREA, mask_window_name);
}

//////
// random_start_position(use_angle_mode)
//  Generates random x and y start coordinates between 0 and given width and height.
//	arguments:
//		width			width of area
//		height			height of area
//		boxwidth		width of a box
//		boxheight		height of a box
//		use_angle_mode	boolean, true results in basing the start position at a random 
//									distance and angle from the center
//								false results in a simple random coordinates
//	returns:
//		array(x,y)		coordinates as indicies in array
function random_start_position(width, height, boxwidth, boxheight, use_angle_mode) {	
	if(USE_RANDOM_ANGLE_FOR_START) {
		angle = 360;
		RANDOM_START_ANGLE = (random*angle);

		hyp = sqrt((boxwidth*boxwidth)+(boxheight*boxheight));
		box_hypotenus = hyp;
		RANDOM_HYPOTENUS = (random*box_hypotenus);

		a= RANDOM_HYPOTENUS* cos(RANDOM_START_ANGLE);
		b= RANDOM_HYPOTENUS* tan(RANDOM_START_ANGLE);

		print ("random_angle "+RANDOM_START_ANGLE);
		print ("boxx "+boxheight);
		print ("boxy "+boxwidth);
		print ("hyp_calc "+hyp);
		print ("rand_hyp "+RANDOM_HYPOTENUS);
		print ("a "+a);
		print ("b "+b);

		startXorig = 0;
		startYorig = 0;

		if (RANDOM_START_ANGLE < 90) {
			startX=startXorig+b;
			startY=startYorig-a;
		} else {
			if (RANDOM_START_ANGLE < 180 && RANDOM_START_ANGLE > 90) {
				startX=startXorig-b;
				startY=startYorig-a;
			} else {
				if (RANDOM_START_ANGLE > 270) {
					startX=startXorig+b;
					startY=startYorig+a;
				}
				else {
					startX=startXorig-b;
					startY=startYorig+a;
				}
			}
		}
	}
	else {
		X = random*width;
		Y = random*height;
		xstartorig = round (X);
		ystartorig = round (Y);

		startX = xstartorig;
		startY = ystartorig;
	}

	return newArray(startX, startY);
}

//////
// savestats()
//  Saves statistics and some log information to a file
//  assumes the results window is loaded with a list of mean pixel values
function savestats(pathtofilename,filename){
	//SAVESTATS auses a list of mean pixel values underneath each grid point from a single image

	//For cavalieri stereology, you calculate the number of points which are on the tissue (this is the reference)
	//then you calculate the number of points which are positive for the condition (this is positive points)
	//the VV (volume of positive tissue) is ((positive points)/(points on the tissue))/(number of points on the grid).
	//VV% is the VV *100, and can be stated as "percent positive for the condition"
	
	//Since there are multiple sections for each mouse, you can calculate the mean VV per mouse and from this determine a CV for each mouse.
	//The CV(mouse) is the SEM(mouse)/meanVV(mouse).
	//This routine is agnostic as to the source of the data, but was originally written to take the values under all the points for a single section.
	//modification may be needed to calculate all the points for multiple sections -- leading to meaningful "per mouse" values.

	//this routine currently assumes that all grid points are on the tissue.
	//it would be ideal to calculate the number of points which are on the tissue.
	//to do this, you need the value for the background.  I think you can say any mean pixel value under a grid point which is greater than background is "on the tissue"

	//VARIABLES FOR STATS
	ngm=0; //greater than mean
	ngqs=0; //greater than 0.25*SD
	ngs=0;  // number of points greater than 1SD
	ng2s=0; // number of points greater than 2SD
	ng25s=0;
	ng3s=0;
	ngt=0;	// number of points greater than threshold, and on tissue
	nbelowmint=0; // number of points less than low threshold, and on tissue
	nabovemaxt=0; // number of points greater than high threshold, and on tissue
	nghs=0;	// number of points greater than hs (hs = half SD)
	npos=0; // number of "positive points" greater than min threshold, less than max
	ntissue=0; // number of points on tissue
	res_stats=0;
	number_stats=0;
	mean_stats=0;
	SD_stats=0;
	SEM_stats=0;
	CV_stats=0;
	variance_stats=0;
	total_mean=0;
	total_variance=0;
	

	//open the file with the list of mean pixel values measured at each point
	open(pathtofilename+File.separator+filename);
	Table.rename(filename, "Results") ;
	number_stats=nResults();																					//number_stats is the number of counted points

	//count number of values on tissue. tissue is determined by the tissue mask pepared earlier. 
	// if black background, value of point is 0, if white, 255 ->assuming 8bit channel.
	// Some extra math here in case we are analyzing images with light background
	for (a=0; a<number_stats; a++) {	
		value = getResult("Mean",a);
		if((ASSUME_LIGHT_BACKGROUND && (value < 255)) || (!ASSUME_LIGHT_BACKGROUND && (value > 0)))
			ntissue++;																							//	ntissue is the number of measurements on tissue
	}
	
	//Mean "Mean" column
	// for all values on tissue
	for (a=0; a<number_stats; a++) {
		// exclude values of 255 if on white background and 0 if on black, these values are not on tissue
		value = getResult("Mean",a);
		if((ASSUME_LIGHT_BACKGROUND && (value < 255)) || (!ASSUME_LIGHT_BACKGROUND && (value > 0))) {
			total_mean=total_mean+value;																		//	total_mean 	is the total of all mean values
			mean_stats=total_mean/ntissue;																		//	mean_stats 	is the mean of all values on tissue
		}
	}
	
	//Variance of "Mean" column
	for (a=0; a<number_stats; a++) {
		value = getResult("Mean",a);																			
		if((ASSUME_LIGHT_BACKGROUND && (value < 255)) || (!ASSUME_LIGHT_BACKGROUND && (value > 0))) {
			total_variance=total_variance+(value-(mean_stats))*(value-(mean_stats));
			variance_stats=total_variance/(ntissue-1);															//	variance 	is what it sounds like
		}	
	}
	
	//SD of "Area" column (note: requires variance)
	SD_stats=sqrt(variance_stats);																				// 	SD_stats is the standard deviation of the set
	SEM_stats=SD_stats/sqrt(number_stats);																		//	SEM is the SEM of the whole set
	CV_stats=SEM_stats/mean_stats;
	
	//next compute and display # of entries over/under threshold (multiples of SD) and %over/under
	//loop through each value.  Count number of values at mean+0.5SD mean+1 SD, mean +2 SD, and mean+SDthreshold SD
	for (a=0; a<number_stats; a++) {
		res_stats=getResult("Mean",a);
		
		// with light background / (inverted color images), the direction from the mean which is significant is reversed
		distance_from_mean = 0;
		if(ASSUME_LIGHT_BACKGROUND) {
			distance_from_mean = mean_stats - res_stats;
		}
		else {
			distance_from_mean = res_stats - mean_stats;														//distance_from_mean is what it sounds like
		}
		/*count number of values greater than  mean																				ngm*/		
		if (distance_from_mean>0)
			ngm++; 
	
		/*count number of values greater than  mean																				ngm*/
		if (distance_from_mean>(SD_stats*0.25))
			ngqs++; 

		/*count number of values greater than 1 SD above mean																			ngs		*/
		
		if (distance_from_mean>SD_stats)
			ngs++; 
		
		/*count number of values greater than 0.5 SD above mean																 		nghs	*/ 
		if (distance_from_mean>(SD_stats/2))
			nghs++;

		/*count number of values greater than threshold*SD (set at time of start by user) above mean									ngt 	*/
		if (distance_from_mean>(SD_stats*SD_THRESHOLD_POSITIVE_MIN))
			ngt++;
		/*count number of values above min threshold and below max threshold multiples of SD  											npos		
		if (distance_from_mean>(SD_stats*SD_THRESHOLD_POSITIVE_MIN) && distance_from_mean < (SD_stats*SD_THRESHOLD_POSITIVE_MAX)
		    && ((ASSUME_LIGHT_BACKGROUND && (value < 255)) || (!ASSUME_LIGHT_BACKGROUND && (value > 0))))
			npos++;
		*/
		if (distance_from_mean>(SD_stats*SD_THRESHOLD_POSITIVE_MIN) && distance_from_mean < (SD_stats*SD_THRESHOLD_POSITIVE_MAX))
			npos++;
		
		/*count number of values greater than the minimum threshold, less than the maximum, and on tissue---------------------			nbelowmin	*/
		if (distance_from_mean<(SD_stats*SD_THRESHOLD_POSITIVE_MIN)
			&& ((ASSUME_LIGHT_BACKGROUND && (value < 255)) || (!ASSUME_LIGHT_BACKGROUND && (value > 0))))
			nbelowmint++;
			
		/*count number of values greater than the minimum threshold, less than the maximum, and on tissue---------------------			nabovemax	*/
		if (distance_from_mean >(SD_stats*SD_THRESHOLD_POSITIVE_MAX)
			&& ((ASSUME_LIGHT_BACKGROUND && (value < 255)) || (!ASSUME_LIGHT_BACKGROUND && (value > 0))))
			nabovemaxt++;
		
		/*count number of values greater than 2 SD above mean											-----------------------			ng2s		*/
		if (distance_from_mean>(SD_stats*2))
			ng2s++;
		/*count number of values greater than 2.5 SD above mean
																										-----------------------			ng25s		*/
		if (distance_from_mean>(SD_stats*2.5))
			ng25s++;

		/*count number of values greater than 3 SD above mean								-----------------------------------			ng3s		*/
		if (distance_from_mean>(SD_stats*3))
			ng3s++;

	}
	
	pctpos=npos/number_stats*100;									/*	-------------------------------------------------------			pctpos			*/
	pcttissuepos=npos/ntissue*100;									/*	-------------------------------------------------------			pcttissuepos	*/
	pcttissue=ntissue/number_stats*100;							/*	-------------------------------------------------------			pcttissue		*/

	//Return values
	print("\\Clear");
	print("Image Parameters:");
	print("--------------------");
	print("Image name: "+original_image_name);
	print("Run finish date/time: "+gettime());

	print("Image width (pixels):			"+origW );
	print("Image height (pixels):			"+origH );
	print("Image bit depth:			"+origBD); 
	print("Image area (pixels):			"+origIMG_AREA );
	print("Image mean:			"+origIMG_MEAN );
	print("Image min:			"+origIMG_MIN );
	print("Image max:			"+origIMG_MAX );
	print("Image std_dev:			"+origIMG_STD );
	print("");
	print("Analysis Parameters:");
	print("--------------------");
	print("Percent ROIs sampled:   "+FRACTION_TO_SAMPLE );
	print("Number of ROIs sampled: "+nROIsbyPCT);
	print("Points per ROI:         "+COUNTING_FRAME_CROSSHAIR_COUNT);
	print("Total points:           "+number_stats);
	print("");
	print("Mean pixel value:       "+mean_stats);
	print("Variance:               "+variance_stats);
	print("Standard Deviation:     "+SD_stats);
	print("Standard Error:         "+SEM_stats);
	print("");
	print("Threshold for positive points, z-score min = "+SD_THRESHOLD_POSITIVE_MIN);
	print("Threshold for positive points, z-score max = "+SD_THRESHOLD_POSITIVE_MAX);
	
	
	print("");
	print("Points with ...");
	print("z-score > 0.5:				"+nghs);
	print("z-score > 1.0:				"+ngs);
	print("z-score > 2.0:				"+ng2s);
	print("z-score > 2.5:				"+ng25s);
	print("z-score > 3.0:				"+ng3s);
	print("");
	
	
	print("Points greater than minimum z threshold:     "+ngt);
	print("Points in threshold range (min<point<max):   "+npos+"\t(positive points)");
	print("Points below range (point<min<max):          "+nbelowmint);
	print("Points above range (min<max<point):          "+nabovemaxt);
	
	print("");
	print("% positive points/all points counted:		"+pctpos);
	print("Number of points on tissue:			"+ntissue);
	print("% of points on tissue:				"+pcttissue);
	print("% points on tissue which are positive:		"+pcttissuepos);
	
	
	selectWindow ("Log");
	saveAs("Text", path1+File.separator+"FINAL_STATS");
	run ("Close");

	
	//add min, max, SD to line below (also z scoer?)
	//row = 				image,				points,				points on tissue,	,points greater than min,	points positive,	pos/tissue,		,points>mean, points> 0.25 SD, points > 0.5 SD,	points > 1 SD,	points > 2 SD,	points > 2.5 SD,	points > 3 SD,	SD threshold min,			SD threshold max,			mean,		sd,			cv, origIMG_AREA, origIMG_MEAN, origIMG_MIN, origIMG_MAX, origIMG_STD);
	stats_data = newArray(original_image_name,	number_stats,		ntissue,			ngt,						npos,				npos/ntissue,	ngm, ngqs,nghs,				ngs,			ng2s,	ng25s,	ng3s,		SD_THRESHOLD_POSITIVE_MIN,	SD_THRESHOLD_POSITIVE_MAX,	mean_stats,	SD_stats,	CV_stats,origIMG_AREA, origIMG_MEAN, origIMG_MIN, origIMG_MAX, origIMG_STD);
	updateStatsFile(TARGET_DIRECTORY,stats_data);
	
	//END SAVESTATS
	return newArray(mean_stats, SD_stats);
}


//////
// circlePointsOverThreshold(input, output, filename, stats_mean, stats_SD)
//  Circles points with specified distances from mean in multiples of SD
//  Draws crosshairs over points which are within the SD_THRESHOLD_POSITIVE_MIN<range<SD_THRESHOLD_POSITIVE_MAX
//	That is, crosshairs on points defined by user as POSITIVE
//	 uses image from input directory, saves new image to output.
//	Requires savestats() to run first, to generate the mean and SD of all points
//	This function duplicates the action of drawCrosshairsAndMeasure, which lays down the initial pattern of crosshairs,
//   to ensure the same points are selected, but circles only the positive points rather than all points.
// 	Global parameter vairables used:
//				SD_THRESHOLD_POSITIVE_MAX
//				SD_THRESHOLD_POSITIVE_MIN
//   arguments:
//		input		source directory
//		output		output directory
//		filename	name of file
//		stats_mean	mean value of all points
//		stats_SD	standard deviation
function circlePointsOverThreshold(input, output, filename, stats_mean, stats_SD) {
    open(input + filename);
	

	
	image=getTitle();

	H = getHeight();
	W = getWidth();

	// lay out a grid, and later place ROIs("frames") inside each cell of the grid
	// define box size
	boxx = round(W/MATH_COUNT_FRAME_NUMBER);
	boxy = round(H/MATH_COUNT_FRAME_NUMBER);

	MATH_COUNT_FRAME_NUMBERV2 = (MATH_COUNT_FRAME_NUMBER*2);
	// Start from top-left of image
	startX=round(W/MATH_COUNT_FRAME_NUMBERV2);
	startY=round(H/MATH_COUNT_FRAME_NUMBERV2);

	Xvalues=newArray(0);

	//Define parameters and start mpoints of boxes
	X=startX;
	while (X>0) {
		Xvalues=Array.concat(Xvalues,X);
		X=X-boxx;
	}

	X=startX+boxx;
	while (X<W-round(boxx/MATH_COUNT_FRAME_NUMBER)) {
		Xvalues=Array.concat(Xvalues,X);
		X=X+boxx;
	}
	Yvalues=newArray(0);
	Y=startY;
	while (Y>0) {
		Yvalues=Array.concat(Yvalues,Y);
		Y=Y-boxy;
	}

	Y=startY+boxx;
	while (Y<H-round(boxy/MATH_COUNT_FRAME_NUMBER)) {
		Yvalues=Array.concat(Yvalues,Y);
		Y=Y+boxy;
	}

	Xlist=newArray(0);
	Xtemp=newArray(Yvalues.length);
	Ylist=newArray(0);

	for (j=0; j<Xvalues.length; j++) {
		Array.fill(Xtemp, Xvalues[j]);
		Xlist=Array.concat(Xlist,Xtemp);
		Ylist=Array.concat(Ylist,Yvalues);
	}

	// create a tabulated list with all possible x and y start points -- starting from the center of the image
	Array.show(Xlist,Ylist);

	// lay down grid of equally spaced points using the "Point Tool"
	run("Clear Results");
	
	run("Line Width...", "line=1");
	run("Colors...", "foreground=yellow background=black selection=magenta");
	run("RGB Color");
	run("Point Tool...", "type=Crosshair color=Yellow size=Large");

	
	// select all of the points underneath crosshairs and then measures the pixel value under each crosshair
	run("Select None");
	makeSelection("point", Xlist, Ylist);
	run("Measure");
	run("Select None");
	
	// TODO: The ROI manager/results could be saved to a file,
	// then reused when returing to draw the circles for points over threshold rather
	// than repeating all the work just completed
	// This could, actually, be broke out to a separate function and save the points here
	// then load the points at this location here in both drawCrosshairsAndMeasure() and circlePointsOverThreshold()
	

	if(ASSUME_LIGHT_BACKGROUND) {
		setForegroundColor(0,0,0);
	}
	else {
		setForegroundColor(255,255,255);
	}

	valueRadius = 5 * DEFAULT_SCALE;
	
	// compare each point's value to the threshold value, then draw a circle if above the threshold
	for(i = 0; i<(nResults);i++) {
		value = getResult("Mean", i);
		distance_from_mean = 0;
		
		if(ASSUME_LIGHT_BACKGROUND) {
			distance_from_mean = stats_mean - value;
		}
		else {
			distance_from_mean = value - stats_mean;
		}
		
		// color circle based on distance of pixel from theshold
		if(distance_from_mean<0) {
			setForegroundColor(0,0,0);
		}
		else if(distance_from_mean<(stats_SD * 0.5)) {
			setForegroundColor(0,0,150);
		}
		else if(distance_from_mean<stats_SD) {
			setForegroundColor(0,150,150);
		}
		else if(distance_from_mean<(stats_SD*2)) {
			setForegroundColor(50,250,0);
		}
		else if(distance_from_mean<(stats_SD*3)) {
			setForegroundColor(250,100,0);
		}
		else {
			setForegroundColor(255,255,0);
		}
		
		valueX = DEFAULT_SCALE * getResult("X", i);
		valueY = DEFAULT_SCALE * getResult("Y", i);
		
		setLineWidth(1 * DEFAULT_SCALE);
		drawOval(valueX - valueRadius, valueY - valueRadius, valueRadius*2, valueRadius*2);
		
		// additionally draw crosshairs for points between specified SD threshold

		if (distance_from_mean>(stats_SD*SD_THRESHOLD_POSITIVE_MIN) && distance_from_mean < (stats_SD*SD_THRESHOLD_POSITIVE_MAX)
		  && ((ASSUME_LIGHT_BACKGROUND && (value < 255)) || (!ASSUME_LIGHT_BACKGROUND && (value > 0))) ) {
			valueX = DEFAULT_SCALE * getResult("X", i);
			valueY = DEFAULT_SCALE * getResult("Y", i);
			
			setLineWidth(2 * DEFAULT_SCALE);
			drawLine(valueX - valueRadius * 1.75, valueY, valueX - valueRadius * 0.25, valueY);
			drawLine(valueX + valueRadius * 1.75, valueY, valueX + valueRadius * 0.25, valueY);
			drawLine(valueX, valueY - valueRadius * 1.75, valueX, valueY - valueRadius * 0.25);
			drawLine(valueX, valueY + valueRadius * 1.75, valueX, valueY + valueRadius * 0.25);
		}
			
	}

	// save images
	saveAs("jpeg", output+filename+".jpg");
	run("Select None");
	run("Clear Results");
	close();
}

//////
// updateStatsFile(main_directory)
//	Writes current image's statistics to a row in the combined statistics table.
//	Creates the file if it does not exist.
//  arguments:
//	  main_directory	root directory of images currently being processed
function updateStatsFile(main_directory, stats_data) {
	file_path = main_directory+File.separator+"statistics.csv";
	
	if(!File.exists(file_path))
		beginStatsFile(main_directory);
	
	//row = "image,points,points on tissue,points greater than min,points positive,pos/tissue,points > 0.5 SD,points > 1 SD,points > 1.5 SD,points > 2 SD,SD min threshold, SD max threshold,mean,sd\r\n";
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
function beginStatsFile(main_directory) {
	file_path = main_directory+File.separator+"statistics.csv";
	statsfile = File.open(file_path);
	print(statsfile, "image,points,points on tissue,points greater than min, points positive,pos/tissue,>mean,Z> 0.25 SD,Z> 0.5 SD,Z > 1 SD,Z > 2 SD,Z > 2.5 SD,Z > 3 SD,Z threshold min,Z threshold max, mean,sd,cv,origArea,origMean,origMin,origMax,origSTD,\r\n");
	File.close(statsfile);
}


//////
// recordParametersToFile()
//  Writes out the parameters used to a text file for later reference
//  arguments:
//	  filename		path and name of file to save to.
function recordParametersToFile(filename) {
	
	parameters_log_text = "";
	parameters_log_text += "Parameters used for image processing";
	parameters_log_text += "\r\noriginal_image_name: "+ original_image_name;
	parameters_log_text += "\r\n";
	parameters_log_text += "\r\nGrid and Scale";
	parameters_log_text += "\r\nScale (pixels/um):         "+DEFAULT_SCALE;
	parameters_log_text += "\r\nUnits:                     "+"um";
	parameters_log_text += "\r\nGrid width in um:          "+GRID_WIDTH_UM;
	parameters_log_text += "\r\nGrid height in um:         "+GRID_HEIGHT_UM;
	parameters_log_text += "\r\nFrame width in um:         "+FRAME_BOX_HEIGHT_UM;
	parameters_log_text += "\r\r\nFrame height in um:      "+FRAME_BOX_HEIGHT_UM;
	parameters_log_text += "\r\nRatio of ROIs to count:    "+FRACTION_TO_SAMPLE;
	parameters_log_text += "\r\nPoints per ROI:            "+COUNTING_FRAME_CROSSHAIR_COUNT;
	parameters_log_text += "\r\n";
	parameters_log_text += "\r\nGeneral Configuration";
	parameters_log_text += "\r\nNO_USER_INPUT:             "+NO_USER_INPUT;
	parameters_log_text += "\r\nUSE_BATCH_MODE:            "+USE_BATCH_MODE;
	parameters_log_text += "\r\nUSE_RANDOM_ANGLE_FOR_START:"+USE_RANDOM_ANGLE_FOR_START;
	parameters_log_text += "\r\nCHANNEL_TO_USE:            "+CHANNEL_TO_USE;
	parameters_log_text += "\r\nTARGET_DIRECTORY:          "+TARGET_DIRECTORY;
	parameters_log_text += "\r\npath:\t\t"+path;;
	parameters_log_text += "\r\nASSUME_LIGHT_BACKGROUND:   "+ASSUME_LIGHT_BACKGROUND;
	parameters_log_text += "\r\nQUANTIFY_MORPHOMETRY:      "+QUANTIFY_MORPHOMETRY;
	parameters_log_text += "\r\nSD_THRESHOLD_POSITIVE_MIN: "+SD_THRESHOLD_POSITIVE_MIN;
	parameters_log_text += "\r\nSD_THRESHOLD_POSITIVE_MAX: "+SD_THRESHOLD_POSITIVE_MAX;
	parameters_log_text += "\r\nSAVE_ROI_OVERLAY:          "+SAVE_ROI_OVERLAY;
	parameters_log_text += "\r\nCOLOR_DECONVOLVE_BLUE:          "+COLOR_DECONVOLVE_BLUE;

	logfile = File.open(filename);
	print(logfile, parameters_log_text);
	File.close(logfile);
}

//////
// calculatePercentAreaSampled()
//
// Sums all tissue area in the ROIs selected for sampling, then calculates the ratio of tissue sampled vs estimated total tissue area
//
// Uses parameter ASSUME_LIGHT_BACKGROUND
// arguments:
//	total_area	Estimated total tissue area in kidney 
function calculatePercentAreaSampled(total_area) {
	//   Re-opens the nth_tile, does some processing to make a simple "tissue or not" mask,
	//   measures the area of the tissue. Compares this to the previously calculated total tissue area.
	// open all images in path3("nth_tile")
	run("Image Sequence...", "open=&path3 increment=1 sort");

	NTH_labels_list = newArray(0);
	run("8-bit");

	if(ASSUME_LIGHT_BACKGROUND)
		run("Invert", "stack");


	// create a "tissue or not" threshold
	setAutoThreshold("Default dark");
	setOption("BlackBackground", false);

	// select tissue and expand selection to fill holes
	run("Convert to Mask", "method=Default background=Dark calculate");
	run("Dilate","stack");
	run("Fill Holes", "stack");
	run("Dilate","stack");
	run("Fill Holes", "stack");
	run("Dilate","stack");
	run("Fill Holes", "stack");
	run("Dilate","stack");
	run("Fill Holes", "stack");
	run("Dilate","stack");
	run("Fill Holes", "stack");
	run("Dilate","stack");
	run("Fill Holes", "stack");

	Mask_area_list = newArray (0);

	// measure selected area from each open image (open images are the sampled areas)
	run("Set Measurements...", "area display redirect=None decimal=0");
		for (n=1; n<=nSlices; n++) {
		setSlice(n);;
		run("Create Selection");
		run("Measure");
		maskarea = getResult ("Area", nResults-1);
		Mask_area_list = Array.concat (Mask_area_list, maskarea);
	}

	// add the area in each image
	Mask_total_area_sampled=0;
	for (i=0;i<lengthOf(Mask_area_list);i++){
		Mask_total_area_sampled=Mask_total_area_sampled+Mask_area_list[i];
	}

	Sampled_Fraction_Ratio_total =(Mask_total_area_sampled/total_area);
	print ("Mask Total Area: "+Mask_total_area_sampled);
	print ("Kidney Computed Area: "+total_area);
	print ("% Tissue Sampled: "+Sampled_Fraction_Ratio_total*100);

	selectWindow ("Log");
	saveAs("Text", path1+File.separator+"PERCENT_TISSUE_SAMPLED");
	run ("Close");
}

//////
// outputROIOverlayImage(results_directory)
// Create an image with the ROIs created overlaid on the tissue mask
//
// arguments:
//  results_directory	directory containing the tissue mask image and the saved ROI information
function outputROIOverlayImage(results_directory) {
	open(results_directory+File.separator+"TISSUE_MASK.png");
	roiManager("Open", results_directory+File.separator+"ALT_GRID_BOXES.zip");
	roiManager("Open", results_directory+File.separator+"ALT_SAMPLE_BOXES.zip");
	roiManager("Set Color", "yellow");
	roiManager("Set Line Width", 10);
	roiManager("Show All with labels");
	run("Flatten");
	
	saveAs("png", results_directory+File.separator+"ROI_OVERLAY");
	
	close("*");
}

function myEnhanceImage(windowname){
	//Save histogram of original image for quality control, then enhance contrast (or otherwise manipulate image) and save a new histogram again for QC
	setBatchMode (false);  //duplicate doesnt work right in batch mode
	selectWindow(windowname);
	run("Select None");
	bd=bitDepth();
	bd_scale=pow(2,bd)-1;
	run("Duplicate...", "title=image_before_enhance");
	selectWindow("image_before_enhance");
	setKeyDown("shift+alt");
	run("Histogram", "slice"+"bins= "+(bd_scale+1)+ " x_min="+0+" x_max=" +bd_scale);//think about what the scale should be for these histograms

	
	selectWindow(windowname);
	run("Duplicate...", "title=image_after_enhance");
	if (ENHANCE_IMAGE){
		//enhance the contrast (trial) before outputting images so the output images are viewable even if the input is dim
		run("Enhance Contrast...", "normalize");
		//enhance step above
	}
	//put the result of image enhancement in the passed window
	selectWindow("image_after_enhance");
	run("Duplicate...", "title=return_image");
	selectWindow("image_after_enhance");
	
	//save a montage documenting the image enhancement change that was made
	setKeyDown("shift+alt");
	run("Histogram", "slice"+"bins= "+(bd_scale+1)+ " x_min="+0+" x_max=" +bd_scale);//think about what the scale should be for these histograms
	run("Images to Stack", "name=Histogram_stack method=[Scale (largest)] title=enhance use");
	run("Make Montage...", "columns=2 rows=2 scale=0.25 border=1 label use"); //this step isn't giving me the whole image like I want.
	saveAs("png", path1+File.separator +"Image_enhancement_montage");
	close("Image_enhancement_montage.png");
	close("Histogram_stack");

	//put the enhanced image in the window with the passed title
	close(windowname);
	selectWindow("return_image");
	rename(windowname);

	setBatchMode (USE_BATCH_MODE);
}

 function gettime() {
     MonthNames = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
     DayNames = newArray("Sun", "Mon","Tue","Wed","Thu","Fri","Sat");
     getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
     TimeString =DayNames[dayOfWeek]+" ";
     if (dayOfMonth<10) {TimeString = TimeString+"0";}
     TimeString = TimeString+dayOfMonth+"-"+MonthNames[month]+"-"+year+" ";
     if (hour<10) {TimeString = TimeString+"0";}
     TimeString = TimeString+hour+":";
     if (minute<10) {TimeString = TimeString+"0";}
     TimeString = TimeString+minute+":";
     if (second<10) {TimeString = TimeString+"0";}
     TimeString = TimeString+second;
     return TimeString;
  }