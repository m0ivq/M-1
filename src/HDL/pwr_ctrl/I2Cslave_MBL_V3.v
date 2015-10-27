// I2C slave written from scratch by Mario Blunk at www.train-z.de 
// send comments to marioblunk@arcor.de

// version V3.0
// imitates the NXP/PHILIPS I2C Expander PCF8574 (execption: no data read, no interrupt output)
// with asynchronous L-active reset input
// no sampling clock required
// WARNING: FULLY ASYNCHRONOUS DESIGN, NO WARRANTY, YOU GET THIS FILE AS IS !
// NOTE: Simulation never performed ! Works in real world !
// target device: Coolrunner XC2C384
// design tool: XILINX ISE 10.1. SP3
 

`timescale 1ns / 1ps


	module I2CslaveWith8bitsIO_v3 (SDA, SCL, IOout, ADR, reset, debug);

	inout SDA;	// address or data input on SDA is sampled on posedge of SCL
	input SCL;
	input reset;
	input [6:0] ADR; // the device address is always 7 bits wide !
	output reg [7:0] IOout;
	output debug;
			
	reg start = 1; // L-active, must default to 1 on power up !
	reg stop  = 1;
	reg adr_match = 1; // defaults to 1 on power up	
	reg [4:0] ct = -1; // must default to -1 on power up (all bit set) !	
	reg [6:0] address = -1;
	reg [7:0] data_rx = -1;	

	// delay ct_reset by 2 negator propagation delays
	wire ct_reset;
	wire m1_pre_neg /* synthesis keep = 1 */;
	assign m1_pre_neg = !ct_reset;
	wire m1 /* synthesis keep = 1 */;
	assign m1 = !m1_pre_neg;

   always @(negedge SDA or negedge m1)
      if (!m1) begin		// !m1 sets start register
         start <= 1'b1;
      end else 
		begin
         start <= !SCL;	// on bus starting, start goes low for a very short time until set back to high by negedge of m1 
      end


	// delay clear_stop by 2 negator propagation delays
	wire clear_stop = reset & stop;
	wire m2_pre_neg /* synthesis keep = 1 */;
	assign m2_pre_neg = !clear_stop;
	wire m2 /* synthesis keep = 1 */;
	assign m2 = !m2_pre_neg;

   always @(posedge SDA or negedge m2)
      if (!m2) begin		// !m1 sets start register
         stop <= 1'b1;
      end else 
		begin
         stop <= !SCL;	// on bus stopping, stop goes low for a very short time until set back to high by negedge of m2 
      end

	//reg ct_gate = 1;
	//always @(negedge stop or negedge start)
	//	if (!stop) ct_gate <= 1;
	//	else ct_gate <= 0;

	//assign debug = ct_gate;
/*	reg debug;
	always @*
		begin
			if (ct == 5'h1F) debug <= 1;
				else debug <= 0;
		end
	*/	

	always @(posedge SCL or negedge reset) // or negedge start)
		begin
			if (!reset)
				begin
					IOout <= -1;
					address <= -1;
					data_rx <= -1;
				end
			else 
			begin
					case (ct)
						5'h00	: address[6] <= SDA;
						5'h01	: address[5] <= SDA;
						5'h02	: address[4] <= SDA;
						5'h03	: address[3] <= SDA;
						5'h04	: address[2] <= SDA;
						5'h05	: address[1] <= SDA;
						5'h06	: address[0] <= SDA;
						//5'h07	: rw_bit <= SDA;
									
						5'h09	: data_rx[7] <= SDA;
						5'h0A	: data_rx[6] <= SDA;
						5'h0B	: data_rx[5] <= SDA;
						5'h0C	: data_rx[4] <= SDA;
						5'h0D	: data_rx[3] <= SDA;
						5'h0E	: data_rx[2] <= SDA;
						5'h0F	: data_rx[1] <= SDA;
						5'h10	: data_rx[0] <= SDA;
								
						5'h11	: if (address == ADR) IOout <= data_rx;
					endcase
			end
		end

	reg stop_internal = 1;
//	assign ct_reset = start & reset; // ored zeroes
	assign ct_reset = start & stop & stop_internal & reset; // ored zeroes
	
//	assign ct_reset_m3 = ct_reset & stop; // ored zeroes
	always @(negedge SCL or negedge ct_reset)
//	always @(negedge SCL or negedge ct_reset_m3)
		begin
			if (!ct_reset) ct <= -1;
		//	if (!ct_reset_m3) ct <= -1;
			else ct <= ct +1;  // posedge SCL increments counter ct
		//	else if (!ct_gate) ct <= ct +1;  // posedge SCL increments counter ct if ct_gate = 0			
		end
	
	always @(ct, ADR, address)
		begin
			case (ct)
				5'h08	: if (address == ADR) adr_match <= 0;  // address acknowledge
							//else stop_internal <= 0;
							
				5'h11	: if (address == ADR) adr_match <= 0;  // data acknowledge
								
				default	: 	begin
									adr_match <= 1;							
							//		stop_internal <= 1;
								end
			endcase
		end

	always @(posedge SCL or negedge reset)
		begin
			if (!reset) stop_internal <= 1;
			else if ( ct==5'h08 & adr_match ) stop_internal <= 0;
				else stop_internal <= 1;
		end
	
	assign SDA = adr_match ? 1'bz : 1'b0;
	

	endmodule
