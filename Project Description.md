EE 316 Computer Engineering Junior Lab (Spring 2023)
Design Project 2
	Specification:  Sine wave generation using PWM with LCD and I2C 7-segment display
	Lab Demonstration Due Date:  	February 14, 2023 
	Report Due: 				February 16, 2023
Parts List:       
1.	Altera DE2-115  Board 
2.	Sparkfun 7-segment display (with I2C)
3.	Op-Amps
4.	Breadboard, resistors, and Capacitors
Design and implement a Pulse Wave Modulator (PWM) to generate sinusoidal waveforms. The system will send a sequence of pulses proportional to the 16-bit samples that reside in the fast asynchronous SRAM of the DE2-115 board. The SRAM is initialized from data stored in a ROM that will be created with a memory initialization file (mif). Create a mif file to represent a 16-bit sinusoidal function with a DC offset that equals the signal's amplitude.
The 256 samples will be read from the SRAM at variable rates. This will allow one to generate PWM signals representing sine waves with varying frequencies of 60, 120, and 1000 Hz. The output of the PWM signal will pass through a low-pass active filter to generate smoother sine functions that can be displayed on an oscilloscope.

Other specifications are the following:

•	The system will have four modes – Initialization, Test, Pause and PWM Generation.  

•	The system will enter the Initialization mode on Power on or when the button KEY0 is pressed. In this mode, the SRAM load a default data sequence from a 1-Port ROM. 

•	The state of the system will be displayed on the LCD panel on the DE2 board. The 16x2 LCD on the DE2 board can show 16 alphanumeric characters in each of its 2 lines. The message on the LCD display should explicitly show the status of the system. 

•	When KEY0 is pressed and held, the SRAM should initialize, and the message displayed on the first line is "Initializing." 

•	Upon the release of KEY0, the system will enter the default Test Mode, which will be displayed on the first line of the LCD.

•	The button KEY1 will be used to toggle between (a) a Test Mode and (b) a Pause Mode. The LCD message on the first line would be either "Test Mode" or "Pause Mode." 

•	In the Test Mode, 

•	the 8-bit address (in Hex) and the 16-bit data (in Hex) from the SRAM will be simultaneously displayed on the second line of the LCD. The display will be updated at a suitable speed that can be comfortably read by the user. In the Pause Mode, the address and the data will freeze at the current value.

•	the 16-bit data (in Hex) from the SRAM will also be displayed on an external 7-segment I2C display.

•	The button KEY2 will be used to toggle between the Test Mode and the PWM Generation mode.

•	The button KEY3 is used to cycle through the three frequencies when the system is in the PWM Generation mode. The second line of the LCD will show the frequency of the PWM signal, e.g., "60 Hz" (default), "120 Hz," or "1000 Hz" on the second line.
Useful Links: (Note: some of the materials included in the links are copyrighted. Do not use any code without explicit permission from the owner of the code developer.)
•	Sparkfun 7-Segment Serial Display (see Documents)
https://www.sparkfun.com/products/11442
•	The I2C-bus and how to use it (including specifications)
http://www.i2c-bus.org/fileadmin/ftp/i2c_bus_specification_1995.pdf
•	I2C master (VHDL) 
https://forum.digikey.com/t/i2c-master-vhdl/12797

Teams:

Team 1	  Team 2	Team 3	Team 4	Team 5	Team 6	Writer
Kubicka	  LaBlue	Morris	Skinner	Ernesto	Mathew	 
Isabelle	Graham	Pamela	Cameron	Shawn	  Kaili	
Nelson	  Nathan	Zander	Keith	  Macy	  Jacob	 
 	 	 	            Ella	 		 
 

 Note: Project reports and posters are to be written individually, not as a team. 
