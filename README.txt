Ensemble of ImageJ scripts to carry colocalisation analyses. Two 
variations of the same script are provided, according to the needs:
- Colocalization_twochannels.ijm: The basic script considering signal 
  in two channels. The code asks in which channel the DAPI signal is
  to be found in order to ignore it.
- Colocalization_scriptbase-Scrambling.ijm: Scrambles the images to 
  create random images and mimick the zero signal one would expect in
  non-colocalising images.

- In both cases, the script requires the BioFormat and JaCoP plugins.
- When running, the code asks for the directory where all the files to
  be analysed are. The file extension as well as the double negative 
  image have to be specified.
- Before carrying out the colocalisation analysis, a value corresponding
  to the background is subtracted. The value, which has to be adapted to
  the tackled case is to be specified in the sub variable.
- The script asks for each image to select individual cells and to 
  define the threshold. Obviously, the same value throughout all images
  is necessary for the results to be comparable.
- The colocalisation analysis is carried using the JaCoP plugin.
- For each image, an image with the subtracted background is created as
  <image_name>-BackSub.tif for verification.
- The results are saved in <image_name>-log.txt

- The scrambling of the images is done by randomly permutating rows then
  randomly permutating columns of a given image.
