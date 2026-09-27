# asynchronus_fifo
a digital hardware design used to safely transfer data between two systems operating at different clock frequencies. It uses separate read and write clocks, Gray-coded pointers, and two-stage synchronizers to handle Clock Domain Crossing (CDC) and reduce metastability risks. Full and empty detection logic prevents data overflow and underflow.
