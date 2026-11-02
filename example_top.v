`timescale 1ns/1ps

 


module example_top 
(
	 
	 
	 
	input 			clk_24m,			 
	input 			clk_25m,			 
	input 	[1:0]	key_data,			 
	
	
	 
	 
	output 			sys_pll_rstn_o, 		
	
	input 			clk_sys,			 
	input 			clk_pixel,			 
	input 			clk_pixel_2x,		 
	input 			clk_pixel_10x,		 
	
	input 			sys_pll_lock,		 
	
	 
	 
	output 			dsi_pll_rstn_o,
	
	input 			dsi_refclk_i,		 
	input 			dsi_byteclk_i,		 
	input 			dsi_serclk_i,		 
	input 			dsi_txcclk_i,		 
	
	input 			dsi_pll_lock,
	
	 
	 
	output 			ddr_pll_rstn_o, 
	
	input 			tdqss_clk,			
	input 			core_clk,			 
	input 			tac_clk,			
	input 			twd_clk,			
	
	input 			ddr_pll_lock,		 
	
	 
	 
	output 	[2:0] 	shift,
	output 	[4:0] 	shift_sel,
	output 			shift_ena,
	
	
	
	 
	 
	output 			lvds_pll_rstn_o, 
	
	input 			clk_lvds_1x, 
	input 			clk_lvds_7x, 
	input 			clk_27m, 			 
	input 			clk_54m, 			 
	
	input 			lvds_pll_lock, 
	
	
	
	 
	 
	output 	[15:0] 	addr,
	output 	[2:0] 	ba,
	output 			we,
	output 			reset,
	output 			ras,
	output 			cas,
	output 			odt,
	output 			cke,
	output 			cs,
	
	 
	input 	[15:0] 	i_dq_hi,
	input 	[15:0] 	i_dq_lo,
	
	output 	[15:0] 	o_dq_hi,
	output 	[15:0] 	o_dq_lo,
	output 	[15:0] 	o_dq_oe,
	
	 
	output 	[1:0] 	o_dm_hi,
	output 	[1:0] 	o_dm_lo,
	
	 
	input 	[1:0] 	i_dqs_hi,
	input 	[1:0] 	i_dqs_lo,
	
 
 
	
	output 	[1:0] 	o_dqs_hi,
	output 	[1:0] 	o_dqs_lo,
	
 
 
	
	output 	[1:0] 	o_dqs_oe,
	output 	[1:0] 	o_dqs_n_oe,
	
	 
	output 			clk_p_hi, 
	output 			clk_p_lo, 
	output 			clk_n_hi, 
	output 			clk_n_lo, 
	
	
	
	 
	 
	output 			csi_ctl0_o,
	output 			csi_ctl0_oe,
	input 			csi_ctl0_i,
	
	output 			csi_ctl1_o,
	output 			csi_ctl1_oe,
	input 			csi_ctl1_i,
	
	output 			csi_scl_o,
	output 			csi_scl_oe,
	input 			csi_scl_i,
	
	output 			csi_sda_o,
	output 			csi_sda_oe,
	input 			csi_sda_i,
	
	 
	input 			csi_rxc_lp_p_i,
	input 			csi_rxc_lp_n_i,
	output 			csi_rxc_hs_en_o,
	output 			csi_rxc_hs_term_en_o,
	input 			csi_rxc_i,
	
	 
	output 			csi_rxd0_rst_o,
	output 			csi_rxd0_hs_en_o,
	output 			csi_rxd0_hs_term_en_o,
	
	input 			csi_rxd0_lp_p_i,
	input 			csi_rxd0_lp_n_i,
	input 	[7:0] 	csi_rxd0_hs_i,
	
	 
	output 			csi_rxd1_rst_o,
	output 			csi_rxd1_hs_en_o,
	output 			csi_rxd1_hs_term_en_o,
	
	input 			csi_rxd1_lp_n_i,
	input 			csi_rxd1_lp_p_i,
	input 	[7:0] 	csi_rxd1_hs_i,
	
	 
	output 			csi_rxd2_rst_o,
	output 			csi_rxd2_hs_en_o,
	output 			csi_rxd2_hs_term_en_o,
	
	input 			csi_rxd2_lp_p_i,
	input 			csi_rxd2_lp_n_i,
	input 	[7:0] 	csi_rxd2_hs_i,
	
	 
	output 			csi_rxd3_rst_o,
	output 			csi_rxd3_hs_en_o,
	output 			csi_rxd3_hs_term_en_o,
	
	input 			csi_rxd3_lp_p_i,
	input 			csi_rxd3_lp_n_i,
	input 	[7:0] 	csi_rxd3_hs_i,
	
	 
	 
	 
	 
	 
	 
	 
	 
	
	
	
	 
	 
	output 			dsi_pwm_o,			 
	output 			dsi_resetn_o,		 
	
	 
	output 			dsi_txc_rst_o,
	output 			dsi_txc_lp_p_oe,
	output 			dsi_txc_lp_p_o,
	output 			dsi_txc_lp_n_oe,
	output 			dsi_txc_lp_n_o,
	output 			dsi_txc_hs_oe,
	output 	[7:0] 	dsi_txc_hs_o,
	
	output 			dsi_txd0_rst_o,
	output 			dsi_txd0_hs_oe,
	output 	[7:0] 	dsi_txd0_hs_o,
	output 			dsi_txd0_lp_p_oe,
	output 			dsi_txd0_lp_p_o,
	output 			dsi_txd0_lp_n_oe,
	output 			dsi_txd0_lp_n_o,
	
	output 			dsi_txd1_rst_o,
	output 			dsi_txd1_lp_p_oe,
	output 			dsi_txd1_lp_p_o,
	output 			dsi_txd1_lp_n_oe,
	output 			dsi_txd1_lp_n_o,
	output 			dsi_txd1_hs_oe,
	output 	[7:0] 	dsi_txd1_hs_o,
	
	output 			dsi_txd2_rst_o,
	output 			dsi_txd2_lp_p_oe,
	output 			dsi_txd2_lp_p_o,
	output 			dsi_txd2_lp_n_oe,
	output 			dsi_txd2_lp_n_o,
	output 			dsi_txd2_hs_oe,
	output 	[7:0] 	dsi_txd2_hs_o,
	
	output 			dsi_txd3_rst_o,
	output 			dsi_txd3_lp_p_oe,
	output 			dsi_txd3_lp_p_o,
	output 			dsi_txd3_lp_n_oe,
	output 			dsi_txd3_lp_n_o,
	output 			dsi_txd3_hs_oe,
	output 	[7:0] 	dsi_txd3_hs_o,
	
	input 			dsi_txd0_lp_p_i,
	input 			dsi_txd0_lp_n_i,
	input 			dsi_txd1_lp_p_i,
	input 			dsi_txd1_lp_n_i,
	input 			dsi_txd2_lp_p_i,
	input 			dsi_txd2_lp_n_i,
	input 			dsi_txd3_lp_p_i,
	input 			dsi_txd3_lp_n_i,
	
	
	 
	 
	input 		 	uart_rx_i,			 
	output 		 	uart_tx_o, 
	
	
	output 	[5:0] 	led_o,			 
	
	
	 
	 
	output 			cmos_sclk,
	input 			cmos_sdat_IN,
	output 			cmos_sdat_OUT,
	output 			cmos_sdat_OE,
	
	 
	input 			cmos_pclk,
	input 			cmos_vsync,
	input 			cmos_href,
	input 	[7:0] 	cmos_data,
	input 			cmos_ctl1,
	output 			cmos_ctl2,
	output 			cmos_ctl3,
	
	
	 
	 
	output 			hdmi_txc_oe,
	output 			hdmi_txd0_oe,
	output 			hdmi_txd1_oe,
	output 			hdmi_txd2_oe,
	
	output 			hdmi_txc_rst_o,
	output 			hdmi_txd0_rst_o,
	output 			hdmi_txd1_rst_o,
	output 			hdmi_txd2_rst_o,
	
	output 	[9:0] 	hdmi_txc_o,
	output 	[9:0] 	hdmi_txd0_o,
	output 	[9:0] 	hdmi_txd1_o,
	output 	[9:0] 	hdmi_txd2_o,
	
	
	 
	 
	output 			lvds_txc_oe,
	output 	[6:0] 	lvds_txc_o,
	output 			lvds_txc_rst_o,
	
	output 			lvds_txd0_oe,
	output 	[6:0] 	lvds_txd0_o,
	output 			lvds_txd0_rst_o,
	
	output 			lvds_txd1_oe,
	output 	[6:0] 	lvds_txd1_o,
	output 			lvds_txd1_rst_o,
	
	output 			lvds_txd2_oe,
	output 	[6:0] 	lvds_txd2_o,
	output 			lvds_txd2_rst_o,
	
	output 			lvds_txd3_oe,
	output 	[6:0] 	lvds_txd3_o,
	output 			lvds_txd3_rst_o,
	
	
	 
	 
	output 			lcd_tp_sda_o,		 
	output 			lcd_tp_sda_oe,
	input 			lcd_tp_sda_i,
	
	output 			lcd_tp_scl_o,		 
	output 			lcd_tp_scl_oe,
	input 			lcd_tp_scl_i,
	
	output 			lcd_tp_int_o,		 
	output 			lcd_tp_int_oe,
	input 			lcd_tp_int_i,
	
	output 			lcd_tp_rst_o,		 
	
	output 			lcd_pwm_o,			 
	output 			lcd_blen_o,
	
	 
	output 			lcd_vs_o,			 
	output 			lcd_hs_o,			 
	 

	output 	[7:0] 	lcd_b7_0_o,			 
	output 	[7:0] 	lcd_g7_0_o,			 
	output 	[7:0] 	lcd_r7_0_o,			 
	
	output 	[7:0] 	lcd_b7_0_oe,		 
	output 	[7:0] 	lcd_g7_0_oe,		 
	output 	[7:0] 	lcd_r7_0_oe,		 

	input 	[7:0] 	lcd_b7_0_i,			 
	input 	[7:0] 	lcd_g7_0_i,			 
	input 	[7:0] 	lcd_r7_0_i,			 
	
	 
	output 			spi_sck_o, 
	output 			spi_ssn_o 			
);
	
	wire 			csi_rxd0_fifo_rd_o; 
	wire 			csi_rxd0_fifo_empty_i = 0;  
	wire 			csi_rxd1_fifo_rd_o;  
	wire 			csi_rxd1_fifo_empty_i = 0;  
	wire 			csi_rxd2_fifo_rd_o;  
	wire 			csi_rxd2_fifo_empty_i = 0;  
	wire 			csi_rxd3_fifo_rd_o;  
	wire 			csi_rxd3_fifo_empty_i = 0;  
	
	wire 	[1:0] 	i_dqs_n_hi;
	wire 	[1:0] 	i_dqs_n_lo;
	wire 	[1:0] 	o_dqs_n_hi;
	wire 	[1:0] 	o_dqs_n_lo;
	
	
	parameter 	SIM_DATA 	= 0; 
	
	 
	assign clk_p_hi = 1'b0;	 
	assign clk_p_lo = 1'b1;
	assign clk_n_hi = 1'b1;
	assign clk_n_lo = 1'b0; 
	
	 
	assign sys_pll_rstn_o = 1'b1; 	 
	
	assign dsi_pll_rstn_o = sys_pll_lock; 
	assign ddr_pll_rstn_o = sys_pll_lock; 
	assign lvds_pll_rstn_o = sys_pll_lock; 
	
	wire 			w_pll_lock = sys_pll_lock && dsi_pll_lock && ddr_pll_lock && lvds_pll_lock; 
	
	 
	reg 			rstn_sys = 0, rstn_pixel = 0; 
	wire 			rst_sys = ~rstn_sys, rst_pixel = ~rstn_pixel; 
	
	reg 			rstn_dsi_refclk = 0, rstn_dsi_byteclk = 0; 
	wire 			rst_dsi_refclk = ~rstn_dsi_refclk, rst_dsi_byteclk = ~rstn_dsi_byteclk; 
	
	reg 			rstn_lvds_1x = 0; 
	wire 			rst_lvds_1x = ~rstn_lvds_1x; 
	
	reg 			rstn_27m = 0, rstn_54m = 0; 
	wire 			rst_27m = ~rstn_27m, rst_54m = ~rstn_54m; 
	
	 
	always @(posedge clk_27m or negedge w_pll_lock) begin if(~w_pll_lock) rstn_27m <= 0; else rstn_27m <= 1; end
	always @(posedge clk_54m or negedge w_pll_lock) begin if(~w_pll_lock) rstn_54m <= 0; else rstn_54m <= 1; end
	always @(posedge clk_sys or negedge w_pll_lock) begin if(~w_pll_lock) rstn_sys <= 0; else rstn_sys <= 1; end
	always @(posedge clk_pixel_2x or negedge w_pll_lock) begin if(~w_pll_lock) rstn_pixel <= 0; else rstn_pixel <= 1; end
	always @(posedge dsi_refclk_i or negedge w_pll_lock) begin if(~w_pll_lock) rstn_dsi_refclk <= 0; else rstn_dsi_refclk <= 1; end
	always @(posedge dsi_byteclk_i or negedge w_pll_lock) begin if(~w_pll_lock) rstn_dsi_byteclk <= 0; else rstn_dsi_byteclk <= 1; end
	always @(posedge clk_lvds_1x or negedge w_pll_lock) begin if(~w_pll_lock) rstn_lvds_1x <= 0; else rstn_lvds_1x <= 1; end
	
	
	localparam 	CLOCK_MAIN 	= 96000000; 	 

	 
	 
	 
	wire 	[7:0]	 w_threshold_shadow_sys;
	wire 			 	 w_threshold_update_toggle_sys;
	wire 			 	 w_frame_freeze_active;
	wire 			 	 w_replay_prev_toggle_sys;
	wire 			 	 w_replay_next_toggle_sys;
	wire 			 	 w_replay_mode_axi;

	 
	 
	 
	threshold_key_ctrl #(
		.CLK_FREQ_HZ	(CLOCK_MAIN),
		.DEBOUNCE_MS	(20)
	) u_threshold_key_ctrl (
		.clk		(clk_sys),
		.rst_n		(rstn_sys),
		.key_n		(key_data),
		.threshold_shadow	(w_threshold_shadow_sys),
		.threshold_update_toggle(w_threshold_update_toggle_sys),
		.frame_freeze_active	(w_frame_freeze_active),
		.replay_prev_toggle	(w_replay_prev_toggle_sys),
		.replay_next_toggle	(w_replay_next_toggle_sys)
	);

     
    wire [7:0] mode_rx_byte;
    wire mode_rx_valid;
    wire [2:0] display_mode_pixel, applied_mode_sys;
    wire [1:0] display_slots_pixel, applied_slots_sys;
    wire mode_applied_sys;
    wire slots_applied_sys;
    wire mode_sys_rst_n, mode_video_rst_n;
    (* async_reg="true" *) reg [1:0] mode_sys_reset_sync, mode_video_reset_sync;
    always @(posedge clk_sys or negedge w_pll_lock)
        if (!w_pll_lock) mode_sys_reset_sync<=0;
        else mode_sys_reset_sync<={mode_sys_reset_sync[0],1'b1};
    always @(posedge clk_pixel_2x or negedge w_pll_lock)
        if (!w_pll_lock) mode_video_reset_sync<=0;
        else mode_video_reset_sync<={mode_video_reset_sync[0],1'b1};
    assign mode_sys_rst_n=mode_sys_reset_sync[1];
    assign mode_video_rst_n=mode_video_reset_sync[1];
    uart_rx #(.CLK_FREQ(CLOCK_MAIN),.BAUD_RATE(115200)) u_mode_rx (
        .clk(clk_sys),.rst_n(mode_sys_rst_n),.rx_i(uart_rx_i),
        .rx_byte(mode_rx_byte),.rx_valid(mode_rx_valid));
    display_mode_ctrl u_mode_ctrl (
        .sys_clk(clk_sys),.sys_rst_n(mode_sys_rst_n),
        .rx_byte(mode_rx_byte),.rx_valid(mode_rx_valid),
        .video_clk(clk_pixel_2x),.video_rst_n(mode_video_rst_n),
        .video_blank(!filtered_vsync),.active_mode(display_mode_pixel),
        .applied_mode(applied_mode_sys),.applied_valid(mode_applied_sys),
        .active_slots(display_slots_pixel),.applied_slots(applied_slots_sys),
        .slots_applied_valid(slots_applied_sys));
    uart_mode_reply #(.CLK_FREQ(CLOCK_MAIN),.BAUD_RATE(115200)) u_mode_reply (
        .clk(clk_sys),.rst_n(mode_sys_rst_n),.applied_mode(applied_mode_sys),
        .applied_valid(mode_applied_sys),.applied_slots(applied_slots_sys),
        .slots_applied_valid(slots_applied_sys),.tx_o(uart_tx_o));

	
	
	 
	 
	 
	
	wire 			w_ustick, w_mstick; 
	
	wire  [7:0] 	w_dev_index_o;  
	wire  [7:0] 	w_dev_cmd_o;  
	wire  [31:0] 	w_dev_wdata_o;  
	wire  		w_dev_wvalid_o;  
	wire  		w_dev_rvalid_o;  
	wire 	[31:0] 	w_dev_rdata_i;  
	
	wire 			w_spi_ssn_o, w_spi_sck_o; 
	wire 	[3:0] 	w_spi_data_o, w_spi_data_oe; 
	wire 	[3:0] 	w_spi_data_i; 
	
	 
	reg 			r_flash_en = 0; 		 
	
	always @(posedge clk_sys) begin
		r_flash_en <= (w_dev_wvalid_o && (w_dev_index_o == 8'h00) && (w_dev_cmd_o == 8'h00)) ? w_dev_wdata_o : r_flash_en; 
	end
	
	
	
	
	 
	 
	 
	
	wire 	[7:0] 	w_lcd_b_o, w_lcd_g_o, w_lcd_r_o; 
	
	assign lcd_b7_0_o = r_flash_en ? {4'b0, w_spi_data_o[3:2], 2'b0} : w_lcd_b_o; 
	assign lcd_g7_0_o = r_flash_en ? {6'h0, w_spi_data_o[1:0]} : w_lcd_g_o; 
	assign lcd_r7_0_o = r_flash_en ? {8'h00} : w_lcd_r_o; 
	
	assign lcd_b7_0_oe = r_flash_en ? {4'b0, w_spi_data_oe[3:2], 2'b0} : 8'hFF; 
	assign lcd_g7_0_oe = r_flash_en ? {6'h0, w_spi_data_oe[1:0]} : 8'hFF; 
	assign lcd_r7_0_oe = r_flash_en ? {8'h00} : 8'hFF; 
	
	assign spi_sck_o = w_spi_sck_o; 
	assign spi_ssn_o = w_spi_ssn_o; 
	assign w_spi_data_i = {lcd_b7_0_i[3:2], lcd_g7_0_i[1:0]}; 
	
	
	
	
	
	
	
	 
	 
	 
	wire			w_ddr3_ui_clk = clk_sys;
	wire			w_ddr3_ui_rst = rst_sys;
	wire			w_ddr3_ui_areset = rst_sys;
	wire			w_ddr3_ui_aresetn = rstn_sys;
	

	 
	wire	[3:0] 	w_ddr3_awid;
	wire	[31:0]	w_ddr3_awaddr;
	wire	[7:0]		w_ddr3_awlen;
	wire			w_ddr3_awvalid;
	wire			w_ddr3_awready;
	
	wire 	[3:0]  	w_ddr3_wid;
	wire 	[127:0] 	w_ddr3_wdata;
	wire 	[15:0]	w_ddr3_wstrb;
	wire			w_ddr3_wlast;
	wire			w_ddr3_wvalid;
	wire			w_ddr3_wready;
	
	wire 	[3:0] 	w_ddr3_bid;
	wire 	[1:0] 	w_ddr3_bresp;
	wire			w_ddr3_bvalid;
	wire			w_ddr3_bready;
	
	wire	[3:0] 	w_ddr3_arid;
	wire	[31:0]	w_ddr3_araddr;
	wire	[7:0]		w_ddr3_arlen;
	wire			w_ddr3_arvalid;
	wire			w_ddr3_arready;
	
	wire 	[3:0] 	w_ddr3_rid;
	wire 	[127:0] 	w_ddr3_rdata;
	wire			w_ddr3_rlast;
	wire			w_ddr3_rvalid;
	wire			w_ddr3_rready;
	wire 	[1:0] 	w_ddr3_rresp;
	
	
	 
	wire 	[3:0] 	w_ddr3_aid;
	wire 	[31:0] 	w_ddr3_aaddr;
	wire 	[7:0]  	w_ddr3_alen;
	wire 	[2:0]  	w_ddr3_asize;
	wire 	[1:0]  	w_ddr3_aburst;
	wire 	[1:0]  	w_ddr3_alock;
	wire			w_ddr3_avalid;
	wire			w_ddr3_aready;
	wire			w_ddr3_atype;
	
	wire 			w_ddr3_cal_done, w_ddr3_cal_pass; 
	
	 
	reg 			r_ddr_unlock = 0; 
	always @(posedge w_ddr3_ui_clk or negedge w_ddr3_ui_aresetn) begin
		if(~w_ddr3_ui_aresetn)
			r_ddr_unlock <= 0; 
		else
			r_ddr_unlock <= w_ddr3_cal_done; 
	end
	
	DdrCtrl ddr3_ctl_axi (	
		.core_clk		(core_clk),
		.tac_clk		(tac_clk),
		.twd_clk		(twd_clk),	
		.tdqss_clk		(tdqss_clk),
		
		.reset		(reset),
		.cs			(cs),
		.ras			(ras),
		.cas			(cas),
		.we			(we),
		.cke			(cke),    
		.addr			(addr),
		.ba			(ba),
		.odt			(odt),
		
		.o_dm_hi		(o_dm_hi),
		.o_dm_lo		(o_dm_lo),
		
		.i_dq_hi		(i_dq_hi),
		.i_dq_lo		(i_dq_lo),
		.o_dq_hi		(o_dq_hi),
		.o_dq_lo		(o_dq_lo),
		.o_dq_oe		(o_dq_oe),
		
		.i_dqs_hi		(i_dqs_hi),
		.i_dqs_lo		(i_dqs_lo),
		.i_dqs_n_hi		(i_dqs_n_hi),
		.i_dqs_n_lo		(i_dqs_n_lo),
		.o_dqs_hi		(o_dqs_hi),
		.o_dqs_lo		(o_dqs_lo),
		.o_dqs_n_hi		(o_dqs_n_hi),
		.o_dqs_n_lo		(o_dqs_n_lo),
		.o_dqs_oe		(o_dqs_oe),
		.o_dqs_n_oe		(),				 
		
		.clk			(w_ddr3_ui_clk),
		.reset_n		(w_ddr3_ui_aresetn),
		
		.axi_avalid		(w_ddr3_avalid),		 
		.axi_aready		(w_ddr3_aready),
		.axi_aaddr		(w_ddr3_aaddr),
		.axi_aid		(w_ddr3_aid),
		.axi_alen		(w_ddr3_alen),
		.axi_asize		(w_ddr3_asize),
		.axi_aburst		(w_ddr3_aburst),
		.axi_alock		(w_ddr3_alock),
		.axi_atype		(w_ddr3_atype),
		
		.axi_wid		(w_ddr3_wid),
		.axi_wvalid		(w_ddr3_wvalid),
		.axi_wready		(w_ddr3_wready),
		.axi_wdata		(w_ddr3_wdata),
		.axi_wstrb		(w_ddr3_wstrb),
		.axi_wlast		(w_ddr3_wlast),
		
		.axi_bvalid		(w_ddr3_bvalid),
		.axi_bready		(w_ddr3_bready),
		.axi_bid		(w_ddr3_bid),
		.axi_bresp		(w_ddr3_bresp),
		
		.axi_rvalid		(w_ddr3_rvalid),
		.axi_rready		(w_ddr3_rready),
		.axi_rdata		(w_ddr3_rdata),
		.axi_rid		(w_ddr3_rid),
		.axi_rresp		(w_ddr3_rresp),
		.axi_rlast		(w_ddr3_rlast),
		
		.shift		(shift),
		.shift_sel		(),
		.shift_ena		(shift_ena),
		
		.cal_ena		(1'b1),
		.cal_done		(w_ddr3_cal_done),
		.cal_pass		(w_ddr3_cal_pass)
	);
	 
	assign o_dqs_n_oe = o_dqs_oe; 
	
	assign w_ddr3_bready = 1'b1; 
	assign shift_sel = 5'b00100; 		 
	
	
	AXI4_AWARMux #(.AID_LEN(4), .AADDR_LEN(32)) axi4_awar_mux (
		.aclk_i			(w_ddr3_ui_clk), 
		.arst_i			(w_ddr3_ui_rst), 
		
		.awid_i			(w_ddr3_awid),
		.awaddr_i			(w_ddr3_awaddr),
		.awlen_i			(w_ddr3_awlen),
		.awvalid_i			(w_ddr3_awvalid && r_ddr_unlock),
		.awready_o			(w_ddr3_awready),
		
		.arid_i			(w_ddr3_arid),
		.araddr_i			(w_ddr3_araddr),
		.arlen_i			(w_ddr3_arlen),
		.arvalid_i			(w_ddr3_arvalid && r_ddr_unlock),
		.arready_o			(w_ddr3_arready),
		
		.aid_o			(w_ddr3_aid),
		.aaddr_o			(w_ddr3_aaddr),
		.alen_o			(w_ddr3_alen),
		.atype_o			(w_ddr3_atype),
		.avalid_o			(w_ddr3_avalid),
		.aready_i			(w_ddr3_aready)
	);
	
	assign w_ddr3_asize = 4; 		 
	assign w_ddr3_aburst = 1; 
	assign w_ddr3_alock = 0; 
	
	assign led_o[1:0] = {w_ddr3_cal_pass, w_ddr3_cal_done}; 
	
	
	
	
	
	
	
	
	
	 
	 
	
	 
	wire            [ 8:0]          sc2210_i2c_config_index;
	wire            [23:0]          sc2210_i2c_config_data;
	wire            [ 8:0]          sc2210_i2c_config_size;
	wire                            sc2210_i2c_config_done;
	
	i2c_timing_ctrl_reg16_dat8_wronly
	#(
	    .CLK_FREQ           (CLOCK_MAIN),                               
	    .I2C_FREQ           (50_000    )                                
	) u_i2c_timing_ctrl_16bit (
	     
	    .clk                (clk_sys                 ),                           
	    .rst_n              (rstn_sys                ),                           

	     
	    .i2c_sclk           (csi_scl_o               ),                           
	    .i2c_sdat_IN        (csi_sda_i               ),
	    .i2c_sdat_OUT       (csi_sda_o               ),
	    .i2c_sdat_OE        (csi_sda_oe              ),

	     
	    .i2c_config_index   (sc2210_i2c_config_index        ),                           
	    .i2c_config_data    ({8'h60, sc2210_i2c_config_data}),                      
	    .i2c_config_size    (sc2210_i2c_config_size         ),                           
	    .i2c_config_done    (sc2210_i2c_config_done         )                           
	);
	assign csi_scl_oe = 1; 

	 
	I2C_SC2210_19201080_4Lanes_Config u_I2C_SC2210_19201080_4Lanes_Config
	(
	    .LUT_INDEX  (sc2210_i2c_config_index   ),
	    .LUT_DATA   (sc2210_i2c_config_data    ),
	    .LUT_SIZE   (sc2210_i2c_config_size    )
	);
		
	
		
	 
	 
	 
	 
	 
	 
	 
	 

	
	 
	reg 	[3:0]		r_cmos_fv_o = 0; 
	reg 	[1:0] 	r_cmos_rx_vsync0_in = 0; 
	always @(posedge cmos_pclk) begin
		r_cmos_rx_vsync0_in <= {r_cmos_rx_vsync0_in, cmos_vsync}; 
		r_cmos_fv_o <= r_cmos_fv_o + ((r_cmos_rx_vsync0_in == 2'b01) ? 1 : 0); 
	end
	assign led_o[5] = r_cmos_fv_o[3]; 
	
	
	
	
	
	
	
	
	 
	 
	
	localparam 	CLK_FREQ 	= 96_000_000; 	 
	localparam 	BAUD_RATE 	= 460_800; 		 
	
	
	 
	wire 	[7:0] 	w_sfr_addr_o; 	 
	wire 	[7:0] 	w_sfr_wdata_o; 	 
	wire 			w_sfr_we_o; 		 
	reg 	[7:0] 	w_sfr_rdata_i; 	 
	wire 			w_sfr_rd_o; 		 
	
	
	 
	reg 			r_dsi_tx_rstn = 0; 	 
	reg 	[7:0] 	r_dsi_pwm = 64; 		 
	reg 			r_dsi_resetn_o = 0; 	 
	reg 			r_dsi_data_rstn = 0; 	 
	
	reg 	[3:0] 	r_dsi_lp_p_ovr = 0; 	
	reg 	[3:0] 	r_dsi_lp_n_ovr = 0; 	
	
	
	
	 
	localparam 	CSI_AXILITE_ID 	= 0; 				 
	localparam 	DSI_AXILITE_ID 	= 1; 				 
	
	reg 	[7:0] 	r_axi_addr = 8'h18; 		 
	reg 	[31:0] 	r_axi_wdata = 32'h0000000A; 	 
	wire 	[31:0] 	w_axi_rdata; 			 
	reg 	[0:0] 	r_axi_sel = 1; 			 
	reg 			r_axi_r1w0 = 0; 			 
	reg 			r_axi_req = 0; 			 
	reg 			r_axi_req_o = 0; 			 
	
	
	 
	reg 	[31:0] 	r_axi_rdata = 0; 		 
	reg 			r_axi_idle = 0; 		 
	
	reg 	[3:0] 	rs_axilite = 0; 		 
	wire 	[3:0] 	ws_axilite_idle = 0; 		
	wire 	[3:0] 	ws_axilite_write = 1; 
	wire 	[3:0] 	ws_axilite_read = 2; 
	wire 	[3:0] 	ws_axilite_endread = 3; 
	
	reg 			r_axi_awvalid = 0, r_axi_wvalid = 0, r_axi_arvalid = 0; 
	wire 			w_axi_awready, w_axi_wready, w_axi_arready, w_axi_rvalid; 
	
	
	reg 	[3:0] 	rc_axi_init = 0; 

	always @(posedge clk_sys or posedge rst_sys) begin
		if(rst_sys) begin
			r_dsi_tx_rstn <= 0; 
			r_dsi_pwm <= 64; 
			r_axi_req <= 0; 
			r_dsi_resetn_o <= 0; 
			r_dsi_data_rstn <= 0; 
			
			rs_axilite <= 0; 
			r_axi_awvalid <= 0; 
			r_axi_wvalid <= 0;
			r_axi_arvalid <= 0; 
			
			r_dsi_lp_p_ovr <= 0; 
			r_dsi_lp_n_ovr <= 0; 
			
			rc_axi_init <= 0; 
			r_axi_idle <= 0; 
			
		end else begin
			r_dsi_tx_rstn <= 1; 
			r_dsi_resetn_o <= 1; 
			r_dsi_data_rstn <= 1; 
			
		end
	end
	
	assign dsi_resetn_o = r_dsi_resetn_o; 
	
	assign csi_ctl0_oe = 0; 
	assign csi_ctl1_oe = 0; 
	
	
	PWMLite dsi_pwm (		 
		.clk_i			(clk_sys),
		.rst_i			(rst_sys),
		.pwm_i			(r_dsi_pwm[6:0]),
		.pol_i			(r_dsi_pwm[7]), 
		.pwm_o			(dsi_pwm_o)
	);






	 
	 
	
	 
	localparam 	CSI_RXD_INV 	= 4'b1111; 
	localparam 	CSI_DATA_WIDTH 	= 32; 			
	localparam 	CSI_STRB_WIDTH 	= CSI_DATA_WIDTH / 8; 

	 
	wire 			w_csi_rx_clk; 
	wire 			w_csi_rx_vsync0, w_csi_rx_hsync0, w_csi_rx_dvalid; 
	wire 	[63:0] 	w_csi_rx_data; 
	wire 	[47:0] 	w_csi_rx_data_rel_raw; 
	
	 
	wire 	[31:0] 	w_csi_axi_rdata; 
	wire 			w_csi_axi_awready, w_csi_axi_wready, w_csi_axi_arready, w_csi_axi_rvalid; 
	
	
	
`define PRI_MIPI_IP
	
	
`ifdef PRI_MIPI_IP
	wire 	[7:0] 	w_mipi_d0 = (CSI_RXD_INV[0] ? 8'hFF : 8'h00) ^ csi_rxd0_hs_i; 
	wire 	[7:0] 	w_mipi_d1 = (CSI_RXD_INV[1] ? 8'hFF : 8'h00) ^ csi_rxd1_hs_i; 
	wire 	[7:0] 	w_mipi_d2 = (CSI_RXD_INV[2] ? 8'hFF : 8'h00) ^ csi_rxd2_hs_i; 
	wire 	[7:0] 	w_mipi_d3 = (CSI_RXD_INV[3] ? 8'hFF : 8'h00) ^ csi_rxd3_hs_i; 
	MIPIRx4LaneFre mipi0_rx (
		.sclk_i			(clk_sys), 
		.srst_i			(rst_sys), 
		
		.mipi_rx_byteclk_i	(csi_rxc_i), 
		.mipi_rx_d0_i		({w_mipi_d0[0], w_mipi_d0[1], w_mipi_d0[2], w_mipi_d0[3], w_mipi_d0[4], w_mipi_d0[5], w_mipi_d0[6], w_mipi_d0[7]}), 
		.mipi_rx_d1_i		({w_mipi_d1[0], w_mipi_d1[1], w_mipi_d1[2], w_mipi_d1[3], w_mipi_d1[4], w_mipi_d1[5], w_mipi_d1[6], w_mipi_d1[7]}), 
		.mipi_rx_d2_i		({w_mipi_d2[0], w_mipi_d2[1], w_mipi_d2[2], w_mipi_d2[3], w_mipi_d2[4], w_mipi_d2[5], w_mipi_d2[6], w_mipi_d2[7]}), 
		.mipi_rx_d3_i		({w_mipi_d3[0], w_mipi_d3[1], w_mipi_d3[2], w_mipi_d3[3], w_mipi_d3[4], w_mipi_d3[5], w_mipi_d3[6], w_mipi_d3[7]}), 
		.mipi_rx_clk_lp_p_i	(csi_rxc_lp_p_i), 
		.mipi_rx_clk_lp_n_i	(csi_rxc_lp_n_i), 
		.mipi_rx_d0_lp_p_i	(CSI_RXD_INV[0] ? csi_rxd0_lp_n_i : csi_rxd0_lp_p_i), 
		.mipi_rx_d0_lp_n_i	(CSI_RXD_INV[0] ? csi_rxd0_lp_p_i : csi_rxd0_lp_n_i), 
		.mipi_rx_rst_o		(), 
		.mipi_rx_rst_n_o		(), 
		.mipi_rx_clk_hs_en_o	(csi_rxc_hs_en_o), 
		.mipi_rx_dat_hs_en_o	(csi_rxd0_hs_en_o), 
		.mipi_rx_clk_term_en_o	(csi_rxc_hs_term_en_o), 
		.mipi_rx_dat_term_en_o	(csi_rxd0_hs_term_en_o), 
		
		.CLK				(w_csi_rx_clk), 
		.VSYNC			(w_csi_rx_vsync0), 
		.HSYNC			(w_csi_rx_hsync0), 
		.DE				(w_csi_rx_dvalid), 
		.DAT				(w_csi_rx_data_rel_raw)
	);
	assign w_csi_rx_data = {2{w_csi_rx_data_rel_raw[47:40], w_csi_rx_data_rel_raw[35:28], w_csi_rx_data_rel_raw[23:16], w_csi_rx_data_rel_raw[11:4]}}; 
	assign {csi_rxd3_hs_en_o, csi_rxd2_hs_en_o, csi_rxd1_hs_en_o} = {3{csi_rxd0_hs_en_o}}; 
	assign {csi_rxd3_hs_term_en_o, csi_rxd2_hs_term_en_o, csi_rxd1_hs_term_en_o} = {3{csi_rxd0_hs_term_en_o}}; 
	
	
`else	
	
	 
	reg 			r_reset_pixen_n = 0; 
	reg 	[1:0] 	r_csi_rx_vsync0_i = 0; 
	always @(posedge w_csi_rx_clk or negedge rstn_sys) begin
		if(~rstn_sys) begin
			r_reset_pixen_n <= 0; 
			r_csi_rx_vsync0_i <= 0; 
		end else begin
			r_csi_rx_vsync0_i <= {r_csi_rx_vsync0_i, w_csi_rx_vsync0}; 
			r_reset_pixen_n <= (r_csi_rx_vsync0_i == 2'b10) ? 1'b0 : 1'b1; 
		end
	end
	
	assign w_csi_rx_clk = clk_sys; 
	csi_rx mipi_rx_0(
		.reset_n			(rstn_sys), 
		.clk				(w_csi_rx_clk), 
		.reset_byte_HS_n		(rstn_sys), 
		.clk_byte_HS		(csi_rxc_i), 
		.reset_pixel_n		(r_reset_pixen_n), 	 
		.clk_pixel			(w_csi_rx_clk), 
		.Rx_LP_CLK_P		(csi_rxc_lp_p_i), 
		.Rx_LP_CLK_N		(csi_rxc_lp_n_i), 
		
		.Rx_HS_enable_C		(csi_rxc_hs_en_o), 
		.LVDS_termen_C		(csi_rxc_hs_term_en_o), 
		
		 
		.Rx_LP_D_P			({CSI_RXD_INV[3] ? csi_rxd3_lp_n_i : csi_rxd3_lp_p_i, CSI_RXD_INV[2] ? csi_rxd2_lp_n_i : csi_rxd2_lp_p_i, CSI_RXD_INV[1] ? csi_rxd1_lp_n_i : csi_rxd1_lp_p_i, CSI_RXD_INV[0] ? csi_rxd0_lp_n_i : csi_rxd0_lp_p_i}), 
		.Rx_LP_D_N			({CSI_RXD_INV[3] ? csi_rxd3_lp_p_i : csi_rxd3_lp_n_i, CSI_RXD_INV[2] ? csi_rxd2_lp_p_i : csi_rxd2_lp_n_i, CSI_RXD_INV[1] ? csi_rxd1_lp_p_i : csi_rxd1_lp_n_i, CSI_RXD_INV[0] ? csi_rxd0_lp_p_i : csi_rxd0_lp_n_i}), 
		.Rx_HS_D_0			((CSI_RXD_INV[0] ? 8'hFF : 8'h00) ^ csi_rxd0_hs_i), 
		.Rx_HS_D_1			((CSI_RXD_INV[1] ? 8'hFF : 8'h00) ^ csi_rxd1_hs_i), 
		.Rx_HS_D_2			((CSI_RXD_INV[2] ? 8'hFF : 8'h00) ^ csi_rxd2_hs_i), 
		.Rx_HS_D_3			((CSI_RXD_INV[3] ? 8'hFF : 8'h00) ^ csi_rxd3_hs_i), 
		.Rx_HS_D_4			(), 
		.Rx_HS_D_5			(), 
		.Rx_HS_D_6			(), 
		.Rx_HS_D_7			(), 
		
		.Rx_HS_enable_D		({csi_rxd3_hs_en_o, csi_rxd2_hs_en_o, csi_rxd1_hs_en_o, csi_rxd0_hs_en_o}), 
		.LVDS_termen_D		({csi_rxd3_hs_term_en_o, csi_rxd2_hs_term_en_o, csi_rxd1_hs_term_en_o, csi_rxd0_hs_term_en_o}), 
		.fifo_rd_enable		({csi_rxd3_fifo_rd_o, csi_rxd2_fifo_rd_o, csi_rxd1_fifo_rd_o, csi_rxd0_fifo_rd_o}), 
		.fifo_rd_empty		({csi_rxd3_fifo_empty_i, csi_rxd2_fifo_empty_i, csi_rxd1_fifo_empty_i, csi_rxd0_fifo_empty_i}), 
		.DLY_enable_D		(), 
		.DLY_inc_D			(), 
		.u_dly_enable_D		(0), 
		.u_dly_inc_D		(), 
		
		.vsync_vc1			(), 
		.vsync_vc15			(), 
		.vsync_vc12			(), 
		.vsync_vc9			(), 
		.vsync_vc7			(), 
		.vsync_vc14			(), 
		.vsync_vc13			(), 
		.vsync_vc11			(), 
		.vsync_vc10			(), 
		.vsync_vc8			(), 
		.vsync_vc6			(), 
		.vsync_vc4			(), 
		.vsync_vc0			(w_csi_rx_vsync0), 
		.vsync_vc5			(), 
		.vsync_vc3			(), 
		.vsync_vc2			(), 
	
		.irq				(), 
		
		.pixel_data_valid		(w_csi_rx_dvalid), 
		.pixel_data			(w_csi_rx_data), 
		.pixel_per_clk		(), 
		.datatype			(), 
		.shortpkt_data_field	(), 
		.word_count			(), 
		.vcx				(), 
		.vc				(), 
		.hsync_vc3			(), 
		.hsync_vc2			(), 
		.hsync_vc8			(), 
		.hsync_vc12			(), 
		.hsync_vc7			(), 
		.hsync_vc10			(), 
		.hsync_vc1			(), 
		.hsync_vc0			(w_csi_rx_hsync0), 
		.hsync_vc13			(), 
		.hsync_vc4			(), 
		.hsync_vc11			(), 
		.hsync_vc6			(), 
		.hsync_vc9			(), 
		.hsync_vc15			(), 
		.hsync_vc14			(), 
		.hsync_vc5			(), 
		
		.axi_clk			(clk_sys), 
		.axi_reset_n		(rstn_sys), 
		
		.axi_awaddr			(r_axi_addr), 
		.axi_awvalid		((r_axi_sel == CSI_AXILITE_ID) && r_axi_awvalid), 
		.axi_awready		(w_csi_axi_awready), 
	
		.axi_wvalid			((r_axi_sel == CSI_AXILITE_ID) && r_axi_wvalid), 
		.axi_wdata			(r_axi_wdata), 
		.axi_wready			(w_csi_axi_wready), 
	
		.axi_bvalid			(), 
		.axi_bready			(1), 
		
		.axi_araddr			(r_axi_addr), 
		.axi_arvalid		((r_axi_sel == CSI_AXILITE_ID) && r_axi_arvalid), 
		.axi_arready		(w_csi_axi_arready), 
		
		.axi_rready			(1), 
		.axi_rvalid			(w_csi_axi_rvalid), 
		.axi_rdata			(w_csi_axi_rdata)
		
	);
	 
	 
	localparam ENABLE_EROSION_MULTI_ANALYSIS = 1'b1;
	
	assign csi_rxd0_rst_o = rst_sys; 
	assign csi_rxd1_rst_o = rst_sys; 
	assign csi_rxd2_rst_o = rst_sys; 
	assign csi_rxd3_rst_o = rst_sys; 
`endif
	
	
	
	 
	reg 	[5:0]		r_csi_fv_o = 0; 
	reg 	[1:0] 	r_csi_rx_vsync0_in = 0; 
	always @(posedge w_csi_rx_clk) begin
		r_csi_rx_vsync0_in <= {r_csi_rx_vsync0_in, w_csi_rx_vsync0}; 
		r_csi_fv_o <= r_csi_fv_o + ((r_csi_rx_vsync0_in == 2'b01) ? 1 : 0); 
	end
	assign led_o[4] = r_csi_fv_o[5]; 
	
	
	
	 
	 
	
	wire			XYCrop_frame_vsync; 
	wire			XYCrop_frame_href;
	wire			XYCrop_frame_de;
	wire	[63:0]	XYCrop_frame_Gray;

	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 

	reg			r_XYCrop_frame_vsync = 0; 
	reg			r_XYCrop_frame_href = 0;
	reg			r_XYCrop_frame_de = 0;
	reg	[63:0]	r_XYCrop_frame_Gray = 0;
	
	always @(posedge w_csi_rx_clk) begin
		r_XYCrop_frame_vsync <= XYCrop_frame_vsync; 
		r_XYCrop_frame_href <= XYCrop_frame_href;
		r_XYCrop_frame_de <= XYCrop_frame_de;
		r_XYCrop_frame_Gray <= XYCrop_frame_Gray;
	end
	
	 
	 
	 
	 
	wire			cmos_frame_vsync = w_csi_rx_vsync0;                      
	wire			cmos_frame_href = w_csi_rx_hsync0 && w_csi_rx_dvalid;	  
	wire	[63:0]	cmos_frame_Gray = {w_csi_rx_data[7:0], w_csi_rx_data[15:8], w_csi_rx_data[23:16], w_csi_rx_data[31:24], w_csi_rx_data[39:32], w_csi_rx_data[47:40], w_csi_rx_data[55:48], w_csi_rx_data[63:56]}; 

	












	 
	 
	

	wire                            lcd_de;
	wire                            lcd_hs;      
	wire                            lcd_vs;
	wire 					  lcd_request; 
	wire            [7:0]           lcd_red, lcd_red2;
	wire            [7:0]           lcd_green, lcd_green2;
	wire            [7:0]           lcd_blue, lcd_blue2;
	wire            [15:0]          lcd_data;


	assign w_ddr3_awid = 0; 
	assign w_ddr3_wid = 0; 
	
	wire 			w_wframe_vsync; 
	wire 	[7:0] 	w_axi_tp; 
	
	axi4_ctrl #(.C_RD_END_ADDR(1920 * 1080), .C_W_WIDTH(CSI_DATA_WIDTH), .C_R_WIDTH(8), .C_ID_LEN(4)) u_axi4_ctrl (

		.axi_clk        (w_ddr3_ui_clk            ),
		.axi_reset      (w_ddr3_ui_rst            ),

		.axi_awaddr     (w_ddr3_awaddr       ),
		.axi_awlen      (w_ddr3_awlen        ),
		.axi_awvalid    (w_ddr3_awvalid      ),
		.axi_awready    (w_ddr3_awready      ),

		.axi_wdata      (w_ddr3_wdata        ),
		.axi_wstrb      (w_ddr3_wstrb        ),
		.axi_wlast      (w_ddr3_wlast        ),
		.axi_wvalid     (w_ddr3_wvalid       ),
		.axi_wready     (w_ddr3_wready       ),

		.axi_bid        (0          ),
		.axi_bresp      (0        ),
		.axi_bvalid     (1       ),

		.axi_arid       (w_ddr3_arid         ),
		.axi_araddr     (w_ddr3_araddr       ),
		.axi_arlen      (w_ddr3_arlen        ),
		.axi_arvalid    (w_ddr3_arvalid      ),
		.axi_arready    (w_ddr3_arready      ),

		.axi_rid        (w_ddr3_rid          ),
		.axi_rdata      (w_ddr3_rdata        ),
		.axi_rresp      (0        ),
		.axi_rlast      (w_ddr3_rlast        ),
		.axi_rvalid     (w_ddr3_rvalid       ),
		.axi_rready     (w_ddr3_rready       ),

		.wframe_pclk    (w_csi_rx_clk          ),
		.wframe_vsync   (cmos_frame_vsync),  
		.wframe_data_en (cmos_frame_href   ),
		.wframe_data    (cmos_frame_Gray),
		
		.rframe_pclk    (clk_pixel_2x            ),
		.rframe_vsync   (~lcd_vs             ),		 
		.rframe_data_en (lcd_request             ),
		.rframe_data    (lcd_data           ),
		.frame_freeze_i (w_frame_freeze_active),
		.replay_prev_toggle_i (w_replay_prev_toggle_sys),
		.replay_next_toggle_i (w_replay_next_toggle_sys),
		.replay_mode_o (w_replay_mode_axi),
		
		.tp_o 		(w_axi_tp)
	);
	assign led_o[3:2] = 2'b11; 
	
	
	
	
	 
	 
	
	lcd_driver u_lcd_driver
	(
	     
	    .clk        (clk_pixel_2x   ),
	    .rst_n      (rstn_pixel), 
	    
	     
	    .lcd_dclk   (               ),
	    .lcd_blank  (               ),
	    .lcd_sync   (               ),
	    .lcd_request(lcd_request    ), 	 
	    .lcd_hs     (lcd_hs         ),
	    .lcd_vs     (lcd_vs         ),
	    .lcd_en     (lcd_de         ),
	    .lcd_rgb    ({lcd_red2,lcd_green2,lcd_blue2, lcd_red,lcd_green,lcd_blue}),
	    
	     
	    .lcd_data   ({{3{lcd_data[15:8]}}, {3{lcd_data[7:0]}}}  )
	);
	
	
	

	wire 			w_rgb_vsync, w_rgb_hsync, w_rgb_href; 
	wire 	[7:0] 	w_rgb_r, w_rgb_g, w_rgb_b; 
	
	VIP_RAW8_RGB888 #(.IMG_HDISP(1920), .IMG_VDISP(1080)) bayer2rgb (
		.clk				(clk_pixel_2x),                 
		.rst_n			(rstn_pixel),               
	    
		.mirror			(0),

		     
		.per_frame_vsync		(lcd_vs),     
		.per_frame_href		(lcd_de),      
		.per_frame_hsync		(lcd_hs),      
		.per_img_RAW		(lcd_green),         

		.post_frame_vsync		(w_rgb_vsync),    
		.post_frame_href		(w_rgb_href),     
		.post_frame_hsync		(w_rgb_hsync),     
		.post_img_red		(w_rgb_r),        
		.post_img_green		(w_rgb_g),      
		.post_img_blue		(w_rgb_b)        
	);

	wire 	[7:0]	w_gray_data;
	wire 			w_gray_vsync;
	wire 			w_gray_hsync;
	wire 			w_gray_href;

	grayscale u_grayscale (
		.clk		(clk_pixel_2x),
		.rst_n		(rstn_pixel),
		.in_r		(w_rgb_r),
		.in_g		(w_rgb_g),
		.in_b		(w_rgb_b),
		.in_vsync	(w_rgb_vsync),
		.in_hsync	(w_rgb_hsync),
		.in_href	(w_rgb_href),
		.gray_data	(w_gray_data),
		.out_vsync	(w_gray_vsync),
		.out_hsync	(w_gray_hsync),
		.out_href	(w_gray_href)
	);

	 




























































	 
	wire 	[7:0] 	filtered_edge_data;
	wire 			filtered_edge_valid;
	wire 	[1:0]	filtered_edge_dir;
	wire signed [12:0] filtered_gradient_x;
	wire signed [12:0] filtered_gradient_y;
	wire 			filtered_vsync, filtered_hsync, filtered_href;

	 
	 
	 
	wire 			analysis_frame_done;
	wire 			analysis_bbox_valid;
	wire 	[10:0]	analysis_x_min, analysis_x_max;
	wire 	[10:0]	analysis_y_min, analysis_y_max;
	wire 	[31:0]	analysis_edge_count;
	wire 	[10:0]	analysis_width = (analysis_x_max >= analysis_x_min) ?
						(analysis_x_max - analysis_x_min + 11'd1) : 11'd0;
	wire 	[10:0]	analysis_height = (analysis_y_max >= analysis_y_min) ?
						(analysis_y_max - analysis_y_min + 11'd1) : 11'd0;

	edge_frame_stats #(
		.IMAGE_WIDTH(1920), .IMAGE_HEIGHT(1080), .MIN_EDGE_PIXELS(64),
		.ROI_X_MIN(640), .ROI_Y_MIN(320), .ROI_WIDTH(640), .ROI_HEIGHT(440)
	) u_edge_frame_stats (
		.clk        (clk_pixel_2x),
		.rst_n      (rstn_pixel),
		.in_vsync   (filtered_vsync),
		.in_hsync   (filtered_hsync),
		.in_href    (filtered_href),
		.edge_valid (filtered_edge_valid),
		.edge_data  (filtered_edge_data),
		.frame_done (analysis_frame_done),
		.bbox_valid (analysis_bbox_valid),
		.x_min      (analysis_x_min),
		.x_max      (analysis_x_max),
		.y_min      (analysis_y_min),
		.y_max      (analysis_y_max),
		.edge_count (analysis_edge_count)
	);

	 
	 
	 
	reg 	[7:0] 	threshold_shadow_pix_d1, threshold_shadow_pix_d2;
	reg 			threshold_toggle_pix_d1, threshold_toggle_pix_d2;
	reg 			threshold_toggle_pix_seen;
	reg 			threshold_pending_valid;
	reg 	[7:0] 	threshold_pending;
	reg 	[7:0] 	threshold_pixel;

	always @(posedge clk_pixel_2x or negedge rstn_pixel) begin
		if (!rstn_pixel) begin
			threshold_shadow_pix_d1 <= 8'd64;
			threshold_shadow_pix_d2 <= 8'd64;
			threshold_toggle_pix_d1 <= 1'b0;
			threshold_toggle_pix_d2 <= 1'b0;
			threshold_toggle_pix_seen <= 1'b0;
			threshold_pending_valid <= 1'b0;
			threshold_pending <= 8'd64;
			threshold_pixel <= 8'd64;
		end else begin
			threshold_shadow_pix_d1 <= w_threshold_shadow_sys;
			threshold_shadow_pix_d2 <= threshold_shadow_pix_d1;
			threshold_toggle_pix_d1 <= w_threshold_update_toggle_sys;
			threshold_toggle_pix_d2 <= threshold_toggle_pix_d1;

			 
			 
			 
			 
			if (!w_gray_vsync && threshold_pending_valid) begin
				threshold_pixel <= threshold_pending;
			end

			if (threshold_toggle_pix_d2 != threshold_toggle_pix_seen) begin
				threshold_pending <= threshold_shadow_pix_d2;
				threshold_pending_valid <= 1'b1;
				threshold_toggle_pix_seen <= threshold_toggle_pix_d2;
			end else if (!w_gray_vsync && threshold_pending_valid) begin
				threshold_pending_valid <= 1'b0;
			end
		end
	end

	 
	wire [7:0] canny_rgb_r,canny_rgb_g,canny_rgb_b;
	wire canny_probe_pix_valid,canny_probe_pix_sof,canny_probe_pix_sol;
	wire [7:0] canny_probe_gauss_out;
	wire [9:0] canny_probe_sobel_mag,canny_probe_nms_mag;
	wire canny_probe_edge_out;
	wire [15:0] canny_probe_frame_id;
	wire [9:0] canny_threshold_high={2'b00,threshold_pixel};
	wire [9:0] canny_threshold_low=(canny_threshold_high>>2)+(canny_threshold_high>>3);
	canny_video_frontend #(.IMAGE_WIDTH(1920),.IMAGE_HEIGHT(1080),.H_TOTAL(2200))
	u_canny_frontend (
		.clk(clk_pixel_2x),.rst_n(rstn_pixel),.gray_data(w_gray_data),
		.in_r(w_rgb_r),.in_g(w_rgb_g),.in_b(w_rgb_b),
		.in_vsync(w_gray_vsync),.in_hsync(w_gray_hsync),.in_href(w_gray_href),
		.vio_th_high(canny_threshold_high),.vio_th_low(canny_threshold_low),
		.edge_data(filtered_edge_data),.edge_valid(filtered_edge_valid),
		.aligned_r(canny_rgb_r),.aligned_g(canny_rgb_g),.aligned_b(canny_rgb_b),
		.out_vsync(filtered_vsync),.out_hsync(filtered_hsync),.out_href(filtered_href),
		.probe_pix_valid(canny_probe_pix_valid),.probe_pix_sof(canny_probe_pix_sof),
		.probe_pix_sol(canny_probe_pix_sol),.probe_gauss_out(canny_probe_gauss_out),
		.probe_sobel_mag(canny_probe_sobel_mag),.probe_nms_mag(canny_probe_nms_mag),
		.probe_edge_out(canny_probe_edge_out),.probe_frame_id(canny_probe_frame_id)
	);
	 
	assign filtered_edge_dir=2'b00;
	assign filtered_gradient_x=13'sd0;
	assign filtered_gradient_y=13'sd0;
	 
	 
	wire [7:0] canny_aligned_gray;
	grayscale u_canny_aligned_gray (
		.clk(clk_pixel_2x),.rst_n(rstn_pixel),
		.in_r(canny_rgb_r),.in_g(canny_rgb_g),.in_b(canny_rgb_b),
		.in_vsync(filtered_vsync),.in_hsync(filtered_hsync),.in_href(filtered_href),
		.gray_data(canny_aligned_gray),.out_vsync(),.out_hsync(),.out_href()
	);


    wire erosion_feature_valid,erosion_analysis_done,erosion_overrun;
    wire [1:0] erosion_feature_index,erosion_walk_status;
    wire [31:0] erosion_feature_edge_count,erosion_feature_aspect_x1000,erosion_feature_contour_steps;
    wire [10:0] erosion_feature_x_min,erosion_feature_x_max,erosion_feature_y_min,erosion_feature_y_max;
    wire [31:0] erosion_processing_cycles;
    shape_erosion_multi_candidate_top u_erosion_multi (
        .clk(clk_pixel_2x),.rst_n(rstn_pixel),
        .in_vsync(filtered_vsync),.in_href(filtered_href),
        .edge_valid(filtered_edge_valid),.edge_data(filtered_edge_data),
        .feature_valid(erosion_feature_valid),.feature_last(),.feature_index(erosion_feature_index),
        .feature_edge_count(erosion_feature_edge_count),
        .feature_x_min(erosion_feature_x_min),.feature_x_max(erosion_feature_x_max),
        .feature_y_min(erosion_feature_y_min),.feature_y_max(erosion_feature_y_max),
        .feature_aspect_ratio_x1000(erosion_feature_aspect_x1000),
        .feature_contour_steps_grid(erosion_feature_contour_steps),
        .feature_contour_valid(),.feature_walk_status(erosion_walk_status),
        .analysis_done(erosion_analysis_done),.analysis_overrun(erosion_overrun),
        .analysis_busy(),.processing_cycles(erosion_processing_cycles)
    );

     
     
     
    wire simple_shape_valid, simple_shape_done, simple_shape_busy;
    wire [2:0] simple_shape_class;
    wire [7:0] simple_shape_confidence;
    wire [10:0] simple_shape_x_min,simple_shape_x_max,simple_shape_y_min,simple_shape_y_max;
    wire [11:0] simple_shape_edge_cells;
    shape_simple_recognizer #(
        .IMAGE_WIDTH(1920),.IMAGE_HEIGHT(1080),.BLOCK(16),
        .ROI_X_MIN(560),.ROI_X_MAX(1359),.ROI_Y_MIN(240),.ROI_Y_MAX(839)
    ) u_simple_shape (
        .clk(clk_pixel_2x),.rst_n(rstn_pixel),
        .in_vsync(filtered_vsync),.in_href(filtered_href),
        .edge_valid(filtered_edge_valid),.edge_data(filtered_edge_data),
        .result_valid(simple_shape_valid),.result_shape(simple_shape_class),
        .result_confidence(simple_shape_confidence),
        .result_x_min(simple_shape_x_min),.result_x_max(simple_shape_x_max),
        .result_y_min(simple_shape_y_min),.result_y_max(simple_shape_y_max),
        .result_edge_cells(simple_shape_edge_cells),.analysis_done(simple_shape_done),
        .busy(simple_shape_busy)
    );

	wire 			legacy_target_valid;
	wire 	[1:0]	legacy_target_shape;
	wire 	[31:0]	legacy_target_edge_count;
	wire 	[3:0]	legacy_target_dominant_bin;
	wire 			legacy_target_frame_done;

	 
	 
	 

	 
	 
	wire 			geometry_target_valid;
	wire 	[2:0]	geometry_target_shape;
	wire 	[10:0]	geometry_x_min, geometry_x_max;
	wire 	[10:0]	geometry_y_min, geometry_y_max;
	wire 	[15:0]	geometry_result_frame_id;
	wire 	[15:0]	geometry_input_frame_id;
	wire 	[15:0]	geometry_processing_frame_id;
	wire 	[1:0]	geometry_buffer0_state, geometry_buffer1_state;
	wire 			geometry_busy, geometry_overrun;
	wire 	[31:0]	geometry_processing_cycles;
	wire 			geometry_display_valid;
	wire 	[2:0]	geometry_display_shape;
	wire 	[10:0]	geometry_display_x_min, geometry_display_x_max;
	wire 	[10:0]	geometry_display_y_min, geometry_display_y_max;
	wire 	[15:0]	geometry_display_frame_id;

	wire hu_result_event;
	 
	(* async_reg="true" *) reg [1:0] hu_video_reset_sync, hu_process_reset_sync;
	always @(posedge clk_pixel_2x or negedge w_pll_lock)
		if (!w_pll_lock) hu_video_reset_sync <= 2'b00;
		else hu_video_reset_sync <= {hu_video_reset_sync[0],1'b1};
	always @(posedge clk_54m or negedge w_pll_lock)
		if (!w_pll_lock) hu_process_reset_sync <= 2'b00;
		else hu_process_reset_sync <= {hu_process_reset_sync[0],1'b1};
	wire [31:0] hu_dropped_frames, hu_malformed_frames, hu_det_q24;
	wire [1:0] hu_bank_locked;
	hu_video_adapter #(
		 
		 
		 
		 
		.RECOG_X_MIN		(640),
		.RECOG_Y_MIN		(320),
		.RECOG_WIDTH		(640),
		.RECOG_HEIGHT		(440)
	) u_hu_video_adapter (
		.clk			(clk_pixel_2x),
		.rst_n			(hu_video_reset_sync[1]),
		.process_clk		(clk_54m),
		.process_rst_n		(hu_process_reset_sync[1]),
		.in_vsync		(filtered_vsync),
		.in_href		(filtered_href),
		.edge_valid		(filtered_edge_valid),
		.edge_data		(filtered_edge_data),
		.result_event		(hu_result_event),
		.result_valid		(geometry_target_valid),
		.result_shape		(geometry_target_shape),
		.result_frame_id	(geometry_result_frame_id),
		.input_frame_id		(geometry_input_frame_id),
		.dropped_frames		(hu_dropped_frames),
		.malformed_frames	(hu_malformed_frames),
		.last_hu_det		(hu_det_q24),
		.bank_locked		(hu_bank_locked),
		.last_processing_cycles(geometry_processing_cycles),
		.display_valid		(geometry_display_valid),
		.display_shape		(geometry_display_shape),
		.display_x_min		(geometry_display_x_min),
		.display_x_max		(geometry_display_x_max),
		.display_y_min		(geometry_display_y_min),
		.display_y_max		(geometry_display_y_max),
		.display_frame_id	(geometry_display_frame_id)
	);

	wire 			target_valid;
	wire 	[2:0]	target_shape;
	wire 	[10:0]	target_x_min, target_x_max;
	wire 	[10:0]	target_y_min, target_y_max;
	assign target_valid = 1'b0;
	assign target_shape = geometry_display_shape;
	assign target_x_min = geometry_display_x_min;
	assign target_x_max = geometry_display_x_max;
	assign target_y_min = geometry_display_y_min;
	assign target_y_max = geometry_display_y_max;

	 
	 
	wire [7:0] split_r;
	wire [7:0] split_g;
	wire [7:0] split_b;
	wire display_vsync,display_hsync,display_href;
	wire [7:0] multi_r, multi_g, multi_b;
	wire multi_vsync, multi_hsync, multi_href;

	color_edge_overlay #(
		.IMAGE_WIDTH(1920),
		.SPLIT_WIDTH(960),
		.DISPLAY_MODE(1'b1),
		.RUNTIME_MODE(1'b1),
		.INPUTS_ALIGNED(1'b1),
		.SHOW_ROI_GUIDE(1'b0),
		.ROI_X_MIN(560),
		.ROI_X_MAX(1359),
		.ROI_Y_MIN(240),
		.ROI_Y_MAX(839)
	) u_color_edge_overlay (
		.clk        (clk_pixel_2x),
		.rst_n      (rstn_pixel),
		.in_vsync   (filtered_vsync),
		.in_hsync   (filtered_hsync),
		.in_href    (filtered_href),
		.in_r       (canny_rgb_r),
		.in_g       (canny_rgb_g),
		.in_b       (canny_rgb_b),
		.in_gray    (canny_aligned_gray),
		.edge_data  (filtered_edge_data),
		.edge_valid (filtered_edge_valid),
		.runtime_mode_i(display_mode_pixel),
		.target_valid(target_valid),
		.target_shape(target_shape),
		.bbox_x_min (target_x_min),
		.bbox_x_max (target_x_max),
		.bbox_y_min (target_y_min),
		.bbox_y_max (target_y_max),
		.analysis_valid      (1'b0),
		.analysis_edge_count (analysis_edge_count),
		.analysis_width      (analysis_width),
		.analysis_height     (analysis_height),
		.out_r      (split_r),
		.out_g      (split_g),
		.out_b      (split_b),
		.out_vsync(display_vsync),.out_hsync(display_hsync),.out_href(display_href)
	);

    erosion_analysis_overlay #(.IMAGE_WIDTH(1920)) u_multi_overlay (
        .clk(clk_pixel_2x),.rst_n(rstn_pixel),
        .in_vsync(display_vsync),.in_hsync(display_hsync),.in_href(display_href),
        .in_r(split_r),.in_g(split_g),.in_b(split_b),.runtime_mode(display_mode_pixel),
        .display_slots(display_slots_pixel),
        .feature_valid(erosion_feature_valid),.feature_index(erosion_feature_index),
        .feature_edges(erosion_feature_edge_count),
        .feature_x0(erosion_feature_x_min),.feature_x1(erosion_feature_x_max),
        .feature_y0(erosion_feature_y_min),.feature_y1(erosion_feature_y_max),
        .feature_aspect(erosion_feature_aspect_x1000[15:0]),
        .feature_steps(erosion_feature_contour_steps),.feature_status(erosion_walk_status),
        .analysis_done(erosion_analysis_done),.analysis_error(erosion_overrun),
        .out_r(multi_r),.out_g(multi_g),.out_b(multi_b),
        .out_vsync(multi_vsync),.out_hsync(multi_hsync),.out_href(multi_href)
    );

    wire [7:0] shape_r,shape_g,shape_b;
    wire shape_vsync,shape_hsync,shape_href;
    shape_simple_overlay #(
        .ROI_X_MIN(560),.ROI_X_MAX(1359),.ROI_Y_MIN(240),.ROI_Y_MAX(839)
    ) u_simple_overlay (
        .clk(clk_pixel_2x),.rst_n(rstn_pixel),
        .in_vsync(multi_vsync),.in_hsync(multi_hsync),.in_href(multi_href),
        .in_r(multi_r),.in_g(multi_g),.in_b(multi_b),.runtime_mode(display_mode_pixel),
        .result_valid(simple_shape_valid),.result_shape(simple_shape_class),
        .result_confidence(simple_shape_confidence),
        .result_x_min(simple_shape_x_min),.result_x_max(simple_shape_x_max),
        .result_y_min(simple_shape_y_min),.result_y_max(simple_shape_y_max),
        .result_edge_cells(simple_shape_edge_cells),
        .out_r(shape_r),.out_g(shape_g),.out_b(shape_b),
        .out_vsync(shape_vsync),.out_hsync(shape_hsync),.out_href(shape_href)
    );

	
	
	
	
	 
	 
	 
	 
	
	assign hdmi_txd0_rst_o = rst_pixel; 
	assign hdmi_txd1_rst_o = rst_pixel; 
	assign hdmi_txd2_rst_o = rst_pixel; 
	assign hdmi_txc_rst_o = rst_pixel; 
	
	assign hdmi_txd0_oe = 1'b1; 
	assign hdmi_txd1_oe = 1'b1; 
	assign hdmi_txd2_oe = 1'b1; 
	assign hdmi_txc_oe = 1'b1; 
	
	 
	 
	rgb2dvi #(.ENABLE_OSERDES(0)) u_rgb2dvi 
	(
		.oe_i 		(1), 			 
		.bitflip_i 		(4'b0000), 		 
		
		.aRst			(1'b0), 
		.aRst_n		(1'b1), 
		
		.PixelClk		(clk_pixel_2x        ), 
		.SerialClk		(     ), 
		
		.vid_pVSync		(shape_vsync), 
		.vid_pHSync		(shape_hsync), 
		.vid_pVDE		(shape_href), 
		 
		 
		.vid_pData		({shape_r, shape_g, shape_b}),
		
		.txc_o		(hdmi_txc_o), 
		.txd0_o		(hdmi_txd0_o), 
		.txd1_o		(hdmi_txd1_o), 
		.txd2_o		(hdmi_txd2_o)
	); 
			
	
	
endmodule
