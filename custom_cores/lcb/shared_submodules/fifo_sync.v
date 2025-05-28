// Partial credit to H. Fatih Uǧurdaǧ
module fifo_sync #(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 4,  // FIFO depth = 2^ADDR_WIDTH
    parameter ALMOST_FULL_THRESHOLD = 2, // Adjust as needed
    parameter ALMOST_EMPTY_THRESHOLD = 2 // Adjust as needed
)(
    input  wire                   clk,
    input  wire                   resetn,
    input  wire [DATA_WIDTH-1:0]  wr_data,
    input  wire                   wr_en,
    output wire                   full,
    output wire                   almost_full,

    output wire [DATA_WIDTH-1:0]  rd_data,
    input  wire                   rd_en,
    output wire                   empty,
    output wire                   almost_empty
);

    // Write and read pointers
    reg [ADDR_WIDTH:0] wr_ptr_bin;
    reg [ADDR_WIDTH:0] rd_ptr_bin;
    reg [ADDR_WIDTH:0] rd_ptr_bin_nxt;

    // Write logic
    always @(posedge clk) begin
        if (~resetn) begin
            wr_ptr_bin <= 0;
        end else if (wr_en) begin
            wr_ptr_bin <= wr_ptr_bin + 1;
        end
    end

    // BRAM instance
    bram #(
      .DATA_WIDTH(DATA_WIDTH),
      .ADDR_WIDTH(ADDR_WIDTH)
    )
    bram(
      .clk(clk),
      .raddr(rd_ptr_bin_nxt[ADDR_WIDTH-1:0]),
      .dout(rd_data),
      .waddr(wr_ptr_bin[ADDR_WIDTH-1:0]), 
      .wen(wr_en), 
      .din(wr_data)
    );

    // Read logic
    // read_ptr_bin_nxt should be one more than rd_ptr_bin when rd_en is high
    always @* rd_ptr_bin_nxt = rd_ptr_bin + rd_en;
    // Update read pointer on clock edge
    always @(posedge clk) begin
        if (~resetn) begin
            rd_ptr_bin <= 0;
        end else begin
            rd_ptr_bin <= rd_ptr_bin_nxt;
        end
    end

    // Generate full and empty flags
    assign full  = ( (wr_ptr_bin[ADDR_WIDTH] != rd_ptr_bin[ADDR_WIDTH]) &&
                     (wr_ptr_bin[ADDR_WIDTH-1:0] == rd_ptr_bin[ADDR_WIDTH-1:0]) );
    assign empty = (wr_ptr_bin == rd_ptr_bin);

    // FIFO count
    wire [ADDR_WIDTH:0] fifo_count;
    assign fifo_count = wr_ptr_bin - rd_ptr_bin;

    // Almost full/empty
    assign almost_full  = (fifo_count >= ((1 << ADDR_WIDTH) - ALMOST_FULL_THRESHOLD));
    assign almost_empty = (fifo_count <= ALMOST_EMPTY_THRESHOLD);

endmodule

// BRAM module formatted and specced to guarantee BRAM utilization in synthesis
module bram #(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 4
)(
    input  wire                   clk,
    input  wire [DATA_WIDTH-1:0]  din,
    input  wire                   wen,
    output reg  [DATA_WIDTH-1:0]  dout,

    input  wire [ADDR_WIDTH-1:0]  raddr,
    input  wire [ADDR_WIDTH-1:0]  waddr
);

    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    always @(posedge clk) begin
        if(wen) mem[waddr] <= din;
        dout <= mem[raddr];
    end

endmodule
