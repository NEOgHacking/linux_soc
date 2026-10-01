<img width="1160" height="1216" alt="Screenshot From 2026-09-27 20-04-39" src="https://github.com/user-attachments/assets/e8436219-aa85-4e10-90c3-ad898d12759b" />

# linux_soc
Linux_soc is a very advanced linux capable module for the hackxpansion console, it consists of a F1C100s soc with integrated stacked ddr1 ram. It also contains a atmega 328p microcontroller, the same found on the arduino uno. It has its own usb ttl converter for programming. In total there are 2 usb ports one for the linux soc and one for the atmega. The pcb also contains a triple buck converter to meet the different requirements that are required by the linux soc

# Design
The linux soc module was designed in Kicad, i choose kicad because its opensource and its rich nature of features.

## Schematic

<img width="1749" height="1232" alt="image" src="https://github.com/user-attachments/assets/6b994ccd-6a2f-42b1-aa09-afb7741a3bac" />
<img width="1749" height="1232" alt="image" src="https://github.com/user-attachments/assets/873f4b14-fb86-43c1-9506-6154519cf770" />
<img width="620" height="631" alt="image" src="https://github.com/user-attachments/assets/0f0ba03a-9a60-43eb-b138-4a13a448ab4d" />
<img width="806" height="434" alt="image" src="https://github.com/user-attachments/assets/dcbb3492-a96e-480f-a668-efa7b4a84555" />
<img width="1513" height="910" alt="image" src="https://github.com/user-attachments/assets/c31ada82-acbc-4ed5-a5f5-75f72d385ef4" />

## PCB
The pcb consist of 4 layers for better power management and routing, it was otherwise also just impossible to do with all the different power rails.
<img width="956" height="1196" alt="image" src="https://github.com/user-attachments/assets/75a5f326-b920-45ef-98d9-5fe9c349ae12" />
<img width="956" height="1196" alt="image" src="https://github.com/user-attachments/assets/4d3dd85c-77c0-4d1e-9af4-5a6316b332e1" />
<img width="956" height="1196" alt="image" src="https://github.com/user-attachments/assets/f900b01d-7b5d-4e4c-9d30-dd8596cf067a" />
<img width="956" height="1196" alt="image" src="https://github.com/user-attachments/assets/b43bb512-ae93-44c9-b1f2-92a9cb9351d2" />

## Case
The case was made in onshape. Here is the public link to access the document [link](https://cad.onshape.com/documents/23acd3255b900cc5b85fa1fc/w/7ef244823df79fb773706f50/e/0ac388d0a99e7c2b0060239b?renderMode=0&uiState=6abee2b1fc9f4045824befa1) The case itself was made pretty complex also because of the complexity of the board, with no space for mouthing holes i had to resort to mounting it by clips.
<img width="1343" height="778" alt="image" src="https://github.com/user-attachments/assets/2db58911-be35-45c0-90b5-0ce3eacb3743" />
<img width="1343" height="778" alt="image" src="https://github.com/user-attachments/assets/d08a110d-9cdf-4725-b2a0-f4903feea3d2" />
