`default_nettype wire

module lt256 (
    input [255:0] a,
    input [255:0] b,
    output lt
);
    wire lt7 = a[255:224] < b[255:224];
    wire lt6 = a[223:192] < b[223:192];
    wire lt5 = a[191:160] < b[191:160];
    wire lt4 = a[159:128] < b[159:128];
    wire lt3 = a[127:96]  < b[127:96];
    wire lt2 = a[95:64]   < b[95:64];
    wire lt1 = a[63:32]   < b[63:32];
    wire lt0 = a[31:0]    < b[31:0];

    wire eq7 = a[255:224] == b[255:224];
    wire eq6 = a[223:192] == b[223:192];
    wire eq5 = a[191:160] == b[191:160];
    wire eq4 = a[159:128] == b[159:128];
    wire eq3 = a[127:96]  == b[127:96];
    wire eq2 = a[95:64]   == b[95:64];
    wire eq1 = a[63:32]   == b[63:32];

    assign lt =
        lt7 ||
        (eq7 && lt6) ||
        (eq7 && eq6 && lt5) ||
        (eq7 && eq6 && eq5 && lt4) ||
        (eq7 && eq6 && eq5 && eq4 && lt3) ||
        (eq7 && eq6 && eq5 && eq4 && eq3 && lt2) ||
        (eq7 && eq6 && eq5 && eq4 && eq3 && eq2 && lt1) ||
        (eq7 && eq6 && eq5 && eq4 && eq3 && eq2 && eq1 && lt0);
endmodule
