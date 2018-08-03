#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma IgorVersion = 6
#pragma version =1

//*****************************************************************************
//    Modified from original LSM Reader by Stephen R. Ikeda 
// 	(following info from original LSM Reader)
//	Module to read in Zeiss LSM 5xx Release 2 confocal image files
//	Stephen R. Ikeda <sikeda@mail.nih.gov>
//	Laboratory of Molecular Physiology
//	NIH/NIAAA
//	Rockville, MD 20852 USA
//	Start date: 03-22-2008
//	Last modified: 04-29-2008
//
//	Currently supported SCANTYPES
//		0: normal xy[z]
//		1: xz scan
//		2: line scan [t]
//		3: xy time series
//		4: xz time series

//	Unnsupported
//		5: Time series - Mean of ROIs
//		6: Time series - x-y-z
//		7: Spline scan
//	 	8: Spline scan x-z"
//	   9: Time series - spline plane x-z
//	  10: Point mode

//****************************** Notes/Reference ******************************
//	http://en.wikipedia.org/wiki/LSM_(Zeiss)
//		A good starting place
//	http://ibb.gsf.de/homepage/karsten.rodenacker/IDL/Lsmfile.doc
//		This contains a very useful word document although it's somewhat out of date
// https://skyking.microscopy.wisc.edu/trac/java/browser/trunk/loci/formats/in/ZeissLSMReader.java
//		Java code that can be useful
//
//	Zeiss doesn't seem to want to supply current documentation of the file format -
//	at least my requests are still unanswered
//
//	The file format is extremely complex so only some data types are read in and
//	tested at this time. Also note that "thumbnail" images are usually stored
// in alternating directories and must be skipped to read in the actual image data.
//
//	The intent of the project was to directly read the images into Igor waves
//	and to transfer some of the meta data to a wavenote for later parsing if 
//	desired. This part turned out to be difficult and the code is a bit of a 
//	kludge. Note that "meta data" is used in the traditional sense and does not
// refer to spectral data collected with the META dectector!
//	The meta data, prior to parsing out the parts I wanted, is stored in the
//	SVAR root:LSMread:scanInfo_store. This string can contain >1000 lines even
//	for single images as "inactive" channels, illumination sources, dectectors,
//	etc. are sometimes stored.
//
//	SCANTYPE 6: "Time series - x-y-z" not supported, file format unclear.
//	No plans to support SCANTYPES 5,7, and above
//
//*****************************************************************************



// Let's put the main function in the Load Waves menu
Menu "Load Waves"
	Submenu "Packages"
	"Load LSM", /Q, LSM_Main ()
	end
end
