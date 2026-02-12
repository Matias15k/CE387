import uvm_pkg::*;


class my_uvm_transaction extends uvm_sequence_item;
    logic [7:0] data;
    logic       sof;
    logic       eof;

    function new(string name = "");
        super.new(name);
    endfunction: new

    `uvm_object_utils_begin(my_uvm_transaction)
        `uvm_field_int(data, UVM_ALL_ON)
        `uvm_field_int(sof,  UVM_ALL_ON)
        `uvm_field_int(eof,  UVM_ALL_ON)
    `uvm_object_utils_end
endclass: my_uvm_transaction


class my_uvm_sequence extends uvm_sequence#(my_uvm_transaction);
    `uvm_object_utils(my_uvm_sequence)

    function new(string name = "");
        super.new(name);
    endfunction: new

    task body();
        my_uvm_transaction tx;
        int pcap_file, n_bytes;
        logic [7:0] file_data [0:8191];
        int file_size;
        int pos;
        int pkt_len;
        int pkt_num;

        `uvm_info("SEQ_RUN", $sformatf("Loading PCAP file %s...", PCAP_FILE_NAME), UVM_LOW);

        pcap_file = $fopen(PCAP_FILE_NAME, "rb");
        if (!pcap_file) begin
            `uvm_fatal("SEQ_RUN", $sformatf("Failed to open file %s...", PCAP_FILE_NAME));
        end

        // Read entire file into memory
        file_size = $fread(file_data, pcap_file, 0);
        $fclose(pcap_file);

        `uvm_info("SEQ_RUN", $sformatf("Read %0d bytes from PCAP file", file_size), UVM_LOW);

        // Skip PCAP global header (24 bytes)
        pos = PCAP_GLOBAL_HDR;
        pkt_num = 0;

        // Process each packet
        while (pos + PCAP_PKT_HDR <= file_size) begin
            // Extract incl_len from packet header bytes 8-11 (little-endian)
            pkt_len = {file_data[pos+11], file_data[pos+10], file_data[pos+9], file_data[pos+8]};
            pos += PCAP_PKT_HDR;  // skip packet header

            pkt_num++;
            `uvm_info("SEQ_RUN", $sformatf("Sending packet %0d: length = %0d bytes", pkt_num, pkt_len), UVM_LOW);

            if (pos + pkt_len > file_size) begin
                `uvm_warning("SEQ_RUN", "Packet extends beyond file, truncating");
                pkt_len = file_size - pos;
            end

            // Send each byte of the packet data with SOF/EOF markers
            for (int i = 0; i < pkt_len; i++) begin
                tx = my_uvm_transaction::type_id::create(.name("tx"), .contxt(get_full_name()));
                start_item(tx);
                tx.data = file_data[pos + i];
                tx.sof  = (i == 0) ? 1'b1 : 1'b0;
                tx.eof  = (i == pkt_len - 1) ? 1'b1 : 1'b0;
                finish_item(tx);
            end

            pos += pkt_len;
        end

        `uvm_info("SEQ_RUN", $sformatf("Done sending %0d packets", pkt_num), UVM_LOW);
    endtask: body
endclass: my_uvm_sequence

typedef uvm_sequencer#(my_uvm_transaction) my_uvm_sequencer;
