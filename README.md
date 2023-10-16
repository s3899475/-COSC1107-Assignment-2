# COSC1107-Assignment-1
This is a web simulation of Langton's Ant

## Running the Simulaton
Either clone the repo or download the html file in the releases  
Open the `out.html` file in a browser  
Click 'Run'  

### Controls
Change 'Ant Definition' to any string containing R, L, U, N  
The 'Jump' slider changes how many iterations are run each 'Interval'  
The 'Interval' slider changes how fast the simulation runs  
The grey bars are the bounds that the ant uses, move them by clicking and dragging  
Then restart the simulation to update the settings of the ant  

## Web Build Instructions
run `nim c main.nim` in the `js` folder  
then run `nim r --backend:c package_into_html.nim page.html`  

## Terminal Build Instructions
run `nim c main.nim` in the `term` folder

