/*
ImageJ script to carry colocalisation analyses of images.
*/ 
setOption("ExpandableArrays", true);
#@ File (label = "Input directory", style = "directory") inputDir
#@ File (label = "Double negative", style = "file") inputDN
#@ String (label = "File suffix", value = ".czi") suffix

// Coloc thresholds
thra=34;
thrb=17;
DAPIChannel="None"; // DAPI channel
// Mean filter radius
meanRad=2.0;
// Limit sizes of structures to filter
lowLim=4;
highLim=10000;
// Subtract value
sub=40;

// Open double negative
run("Bio-Formats Importer", "open=[" + inputDN + "] autoscale color_mode=Composite rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");


// Create output directory
outputDir=inputDir+File.separator+"Results"+File.separator;
File.makeDirectory(outputDir);

list = getFileList(inputDir);
list = Array.sort(list);
toAnalyse = ask_process(list); // Filter files to analyse
imageNumber = 0;
for (i = 0; i < toAnalyse.length; i++) {
	if(! File.isDirectory(inputDir + File.separator + toAnalyse[i])){
		analyse_image(inputDir+File.separator +toAnalyse[i],inputDN,outputDir,i);
	}
}

close(File.getName(inputDN));
print("That's all folks!");


function change_threshold(imageName){
// Test threshold
	run("Set Measurements...", "min redirect=None decimal=3");
	selectWindow(imageName);
	choices = newArray("Yes","No");
	getThreshold(lower,upper);
	run("Measure");
	IJ.renameResults("Results");
  	max = getResult("Max",0);
  	close("Results");
	selectWindow(imageName);
	choice="No";
	while(choice=="No"){
		setThreshold(lower, upper);
		Dialog.create("Threshold");
		Dialog.addSlider("Value",0,max+10,0);
		Dialog.show();
		//updateDisplay();
		thresh = Dialog.getNumber();
		setThreshold(thresh, 65535);
		Dialog.create("Done thresholding?");
		Dialog.addChoice("Done?", choices);
		Dialog.show();
		choice = Dialog.getChoice();
//updateDisplay();
	}
	return thresh;
}

//analyse_image(inputF,outputDir);

function ask_process(filesList) { 
// Select sublist from dialogue box
	Dialog.create("Select images to analyse");
	//Dialog.addMessage("Some message to display");
	n = filesList.length
	defaults = newArray(n)
	Array.fill(defaults, true)
  	Dialog.addCheckboxGroup(n,1,filesList,defaults);
	Dialog.show();
	newList = newArray();
	j=0
  	for (i=0; i<n; i++)
  		if(Dialog.getCheckbox()==1){ 
  			newList[j]=filesList[i];
  			j++;
  		}
	return newList;
}

function ask_crop() { 
// Asks if continue cropping images
	choices = newArray("Yes","No");
	Dialog.create("Crop");
	Dialog.addChoice("Continue croping?", choices);
	Dialog.show();
	choice = Dialog.getChoice();
	if(choice=="Yes") return true;
	return false;


function analyse_image(inputF,inputDN,outputDir,iNum) { 
// Analyse image
	run("Bio-Formats Importer", "open=[" + inputF + "] autoscale color_mode=Composite rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
	ncrop = 0;
	mainImage = File.getName(inputF);
	mainDN=File.getName(inputDN);
	selectWindow(mainImage);
	run("Mean...", "radius="+meanRad);
	run("Subtract...", "value="+sub);
	print("Subtracted background value of "+sub);
	getDimensions(width, height, nChannels, slices, frames);
	enhance_contrast(nChannels);
//	if(iNum==0){
		DAPIChannel = Check_DAPI(nChannels);
//	}
	run("Split Channels");	
	cmd = "";
	for (i = 1; i <= nChannels; i++) {
		cmd += "c"+i+"=[C"+i+"-"+mainImage+"] ";
		if(i==DAPIChannel){
			continue;
		}
		thr = change_threshold("C"+i+"-"+mainImage);
		if(i==1) thra = thr;
		else thrb = thr; 
	}
	cmd += "create";
	run("Merge Channels...", cmd);
//	run("Merge Channels...", "c1=[C1-"+mainImage+"] c2=[C2-"+mainImage+"] c3=[C3-"+mainImage+"] create");
//	run("Bandpass Filter...", "filter_large="+highLim+" filter_small="+lowLim+" suppress=None tolerance=5 process"); 
	crop = ask_crop();
	while (crop) {
		ncrop++;
		setTool("freehand");
		waitForUser("Waiting to select crop region");
		run("Duplicate...", "duplicate");
		run("Clear Outside");	
		rename(substring(mainImage,0,mainImage.length-4)+"-"+ncrop+".czi");
		selectWindow(mainImage);
		crop = ask_crop();	
	}
	if(ncrop==0){
		run_Jacop(mainImage,outputDir);
		run("Merge Channels...", "c1=[C1-"+mainImage+"] c2=[C2-"+mainImage+"] create keep ignore");
		saveAs("Tiff", outputDir+mainImage+"-BackSub.tif");
		close(mainImage+"-BackSub.tif");
	}
	else {
		for(i=1;i<=ncrop;i++){
			cropImage=substring(mainImage,0,mainImage.length-4)+"-"+i+".czi";
			print(cropImage);
			run_Jacop(cropImage,outputDir);
			close("C1-"+cropImage);
			close("C2-"+cropImage);
		}
		selectWindow(mainImage);
		saveAs("Tiff", outputDir+mainImage+"-BackSub.tif");
		close(mainImage+"-BackSub.tif");
	}
}


function subtract_background(C0Back,C1Back,C0,C1) {
// Subtract the background for image of splitted channels
	imageCalculator("Subtract create", C0,C0Back);
	selectWindow("Result of "+C0);
	run("Enhance Contrast", "saturated=0.35");
	imageCalculator("Subtract create", C1,C1Back);
	selectWindow("Result of "+C1);
	run("Enhance Contrast", "saturated=0.35");
}

function enhance_contrast(nChannels){	
// Enhance contast in image
	for (i=1;i<nChannels;i++){
		Stack.setChannel(i);
		run("Enhance Contrast", "saturated=0.35");	
	}
}

function merged_subtract_background(image,background) {
// Subtract the background for images with merged channels
	imageCalculator("Subtract create stack", image,background);
	enhance_contrast(3);
	return "Result of "+image; // return name of the processed image
}

function run_Jacop(imageName,outputDir){
	selectWindow(imageName);
	getDimensions(width, height, nChannels, slices, frames);
	run("Split Channels");
	if(nChannels>=3){ // Add hoc to close 3rd channel if it exists, might not be correct in all cases
		close("C3-"+imageName);
	}
	for (i = 1; i < 3; i++) {
		selectWindow("C"+i+"-"+imageName);
		run("Enhance Contrast", "saturated=0.35");
	}
	JacopAnalysis("C1-"+imageName,"C2-"+imageName);
	selectWindow("Log");
	save(outputDir + imageName +"-log.txt");
	close("Log");
}

function JacopAnalysis(C0,C1) { 
// Run JACoP
	run("JACoP ", "imga=["+C0+"] imgb=["+C1+"] thra="+thra+" thrb="+thrb+" pearson mm costesthr costesrand=2-1-1000-0.001-0-false-true-true");
	close("Costes' method ("+C0+" & "+C1+")");
	close("Randomized images of "+C1);
	close("Costes' mask");
	close("Costes' threshold "+C0+" and "+C1);
}


function Check_DAPI(nChannels) { 
// CHeck if DAPI channel is correct
	choices = newArray("None");
	for(i=1; i<=nChannels;i++){
		choices = Array.concat(choices,toString(i));
		}
	Dialog.create("DAPI channel select");
	Dialog.addChoice("Which is DAPI channel?", choices);
	Dialog.show();
	return Dialog.getChoice();
	}
