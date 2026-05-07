module framebuffer_swap_controller #(
    parameter int ADDR_W = 32,
    parameter logic [ADDR_W-1:0] FRONT_BASE_RESET = '0,
    parameter logic [ADDR_W-1:0] BACK_BASE_RESET = '0
) (
    input logic clk,
    input logic rst_n,

    input logic swap_request,
    output logic swap_ready,
    input logic frame_boundary,

    output logic [ADDR_W-1:0] front_base,
    output logic [ADDR_W-1:0] back_base,
    output logic swap_pending,
    output logic swap_pulse
);
    if (ADDR_W < 1) begin : gen_invalid_params
        initial begin
            $fatal(1, "framebuffer_swap_controller requires ADDR_W >= 1");
        end
    end

    logic accept_swap;
    logic commit_swap;

    assign swap_ready = !swap_pending;
    assign accept_swap = swap_request && swap_ready;
    assign commit_swap = frame_boundary && (swap_pending || accept_swap);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            front_base <= FRONT_BASE_RESET;
            back_base <= BACK_BASE_RESET;
            swap_pending <= 1'b0;
            swap_pulse <= 1'b0;
        end else begin
            swap_pulse <= 1'b0;

            if (commit_swap) begin
                front_base <= back_base;
                back_base <= front_base;
                swap_pending <= 1'b0;
                swap_pulse <= 1'b1;
            end else if (accept_swap) begin
                swap_pending <= 1'b1;
            end
        end
    end
endmodule
