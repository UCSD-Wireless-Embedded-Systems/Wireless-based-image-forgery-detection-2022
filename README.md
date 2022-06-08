# Wireless-based-image-forgery-detection
WES 207 - Capstone project. Repository for MATLAB and Python programming for wireless-based image forgery detection using SIFT algorithm

This project has two parts: 
1. Wireless communication using 802.11a WLAN 
2. Image Processing for forgery detection

**************************************************************




******************************************************************************************
FPGA Project

Vivado is the Hardware Development suite used to create a VHDL, Verilog, or any other HDL design on the latest Xilinx FPGA. In other words, when you need to translate your VHDL design into a configuration file to be downloaded into a Xilinx FPGA, you need Vivado framework.
Vivado is an integrated tool that allows you to perform the complete design flow for a Xilinx FPGA:
•	Simulate
•	Synthesize
•	Map
•	Route
•	Analyze Timing
•	Create a bit-stream FPGA configuration File
•	Configure FPGA
•	Debug the FPGA using ILA (Integrated Logic Analyzer)
In this project, we are going to show how to initialize Vivado tool to be ready to create an FPGA bit-stream programming file, starting from a simple VHDL code.

Vitis HLS
In the Vitis application acceleration flow, the Vitis HLS tool automates much of the code modifications required to implement and optimize the C/C++ code in programmable logic and to achieve low latency and high throughput. The inference of required pragmas to produce the right interface for your function arguments and to pipeline loops and functions within your code is the foundation of Vitis HLS in the application acceleration flow. 

Our project following the Vitis HLS design flow:

•	Compile, simulate, and debug the C/C++ algorithm.
•	View reports to analyze and optimize the design.
•	Synthesize the C algorithm into an RTL design.
•	Verify the RTL implementation using RTL co-simulation.
•	Package the RTL implementation into a compiled object file (.xo) extension, or export to an RTL IP.

System Overview



#pragma HLS interface
The INTERFACE pragma specifies how RTL ports are created from the function definition during interface synthesis. Port Level interface protocols are created for each argument in the top-level function and the function return,
The default I/O protocol created depends on the type of C argument.
When the INTERFACE pragma is used on sub-functions, only the register option can be used. Vitis/Vivado HLS automatically determines the I/O protocol used by any sub-functions.

AXI4-Burst Mode (m_axi)
The usual reason for having a burst mode capability, or using burst mode, is to increase data throughput. This example demonstrates how multiple items can be read from global memory to kernel’s local memory in a single burst. This is done to achieve low memory access latency and also for efficient use of bandwidth provided by the m_axi interface. Similarly, computation results are stored in a buffer and are written to global memory in a burst.

Initial code with some basic $pragma

 
Optimization with compact streaming interface and pipelining the sub-functions


Package the RTL implementation export to an RTL IP

Vivado: Generating bitstream from RTL code
●	Create a new Vivado project
   ○	Select xc7z020clg400-1 for your part

●	Import RTL code
●	Add IPs to your design
●	Manual connection

Created Design

●	Generate bitstream
●	Find required addresses

Post bitstream Generation
•	Copy bit file project directory > project_1 > project_1.runs > impl_1 > design_1_wrapper.bit 
•	Copy .hwh file project directory > project_1 > project_1.srcs > sources_1 > bd > design_1 > hw_handoff > design_1.hwh 
•	Move files to Host Program folder




      
Reference:
MATLAB: Image Transmission and Reception Using 802.11 Waveform and SDR

