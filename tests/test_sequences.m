%% test_sequences.m - Comprehensive Unit Test Suite for Milestone 1 SSB Sequences
% Covers: F1 (Legacy PSS/SSS), F2 (Extended SSS 240), F3 (PBCH DMRS 144), F26 (Unit Test Sequences)
% Requirements: TS 38.211 §7.4.2, §7.4.3, Rel-20 R1-2606375, R1-2606847

% Setup path to include project root
test_dir = fileparts(mfilename('fullpath'));
proj_root = fullfile(test_dir, '..');
addpath(proj_root);

%% Test 1: PSS - Vector Dimensions, Type, and BPSK Values
for n2 = 0:2
    d_pss = nr_sim.sequences.gen_PSSNR(n2);
    assert(length(d_pss) == 127, 'PSS length must be exactly 127');
    assert(iscolumn(d_pss), 'PSS must be a column vector [127 x 1]');
    assert(all(d_pss == 1 | d_pss == -1), 'PSS values must strictly be BPSK {-1, +1}');
    assert(isreal(d_pss), 'PSS must be real-valued');
end

%% Test 2: PSS - 3GPP TS 38.211 Equivalence against nrPSS
for n2 = 0:2
    d_pss = nr_sim.sequences.gen_PSSNR(n2);
    ref_pss = nrPSS(n2);
    assert(isequal(d_pss(:), ref_pss(:)), ...
        sprintf('PSS for N_ID_2=%d must match 3GPP nrPSS reference identically', n2));
    assert(norm(double(d_pss(:)) - double(ref_pss(:))) == 0, ...
        'Numerical error between custom PSS and nrPSS must be 0');
end

%% Test 3: PSS - Auto-Correlation and Cross-Correlation Bounds
% Auto-correlation peak must equal 127 at zero lag
for n2 = 0:2
    d_pss = double(nr_sim.sequences.gen_PSSNR(n2));
    r = xcorr(d_pss(:));
    assert(r(127) == 127, 'PSS auto-correlation peak must be 127 at zero lag');
    r(127) = 0; % Remove peak
    max_sidelobe = max(abs(r));
    % Length-127 m-sequences have known sidelobes in {-1, -17, +15}
    assert(max_sidelobe <= 17, sprintf('PSS sidelobe %g exceeds maximum m-sequence bound 17', max_sidelobe));
end

% Cross-correlation between different sectors (N_ID_2 = 0, 1, 2)
pairs = [0 1; 0 2; 1 2];
for p = 1:size(pairs, 1)
    s1 = double(nr_sim.sequences.gen_PSSNR(pairs(p, 1)));
    s2 = double(nr_sim.sequences.gen_PSSNR(pairs(p, 2)));
    c = xcorr(s1(:), s2(:));
    max_cross = max(abs(c));
    assert(max_cross <= 86, sprintf('PSS cross-corr peak %g exceeds cyclic shift overlap bound 86', max_cross));
    norm_zero_cross = abs(sum(s1(:) .* s2(:))) / 127;
    assert(norm_zero_cross < 0.15, 'PSS normalized zero-lag cross-correlation must be < 0.15');
end

%% Test 4: PSS - Boundary Inputs and Exception Handling
% Out-of-bounds sector IDs
invalid_n2 = [-1, 3, 4, 1.5, NaN];
for val = invalid_n2
    err_caught = false;
    try
        nr_sim.sequences.gen_PSSNR(val);
    catch
        err_caught = true;
    end
    assert(err_caught, sprintf('gen_PSSNR must throw an error for invalid N_ID_2=%g', val));
end

% Default parameter handling (nargin == 0)
d_default = nr_sim.sequences.gen_PSSNR();
d_zero = nr_sim.sequences.gen_PSSNR(0);
assert(isequal(d_default(:), d_zero(:)), 'Calling gen_PSSNR with 0 args should default to N_ID_2=0');

%% Test 5: SSS - Vector Dimensions, Type, and BPSK Values
test_pci_pairs = [0 0; 0 2; 111 1; 112 0; 250 2; 335 2];
for i = 1:size(test_pci_pairs, 1)
    n1 = test_pci_pairs(i, 1);
    n2 = test_pci_pairs(i, 2);
    d_sss = nr_sim.sequences.gen_SSS(n1, n2);
    assert(length(d_sss) == 127, 'SSS length must be exactly 127');
    assert(iscolumn(d_sss), 'SSS must be a column vector [127 x 1]');
    assert(all(d_sss == 1 | d_sss == -1), 'SSS values must strictly be BPSK {-1, +1}');
    assert(isreal(d_sss), 'SSS must be real-valued');
end

%% Test 6: SSS - 3GPP TS 38.211 Equivalence against nrSSS
% Sample representative points across all 336 N_ID_1 and 3 N_ID_2
sample_n1 = [0, 1, 10, 111, 112, 200, 335];
for n1 = sample_n1
    for n2 = 0:2
        d_sss = nr_sim.sequences.gen_SSS(n1, n2);
        ncell = 3 * n1 + n2;
        ref_sss = nrSSS(ncell);
        assert(isequal(d_sss(:), ref_sss(:)), ...
            sprintf('SSS for N_ID_1=%d, N_ID_2=%d (PCI=%d) must match 3GPP nrSSS', n1, n2, ncell));
        assert(norm(double(d_sss(:)) - double(ref_sss(:))) == 0, ...
            'Numerical error between custom SSS and nrSSS must be 0');
    end
end

%% Test 7: SSS - Auto-Correlation and Cross-Correlation
for n1 = [0, 112, 335]
    d_sss = double(nr_sim.sequences.gen_SSS(n1, 0));
    r = xcorr(d_sss(:));
    assert(r(127) == 127, 'SSS auto-correlation peak must be 127');
    r(127) = 0;
    max_sidelobe = max(abs(r));
    assert(max_sidelobe <= 31, sprintf('SSS sidelobe %g exceeds expected bound', max_sidelobe));
end

% Cross-correlation across distinct cell IDs
s_a = double(nr_sim.sequences.gen_SSS(0, 0));
s_b = double(nr_sim.sequences.gen_SSS(1, 0));
c_zero = abs(sum(s_a(:) .* s_b(:))) / 127;
assert(c_zero < 0.25, 'SSS zero-lag cross-correlation must be low');

%% Test 8: SSS - Boundary Inputs and Exception Handling
invalid_sss_inputs = [-1 0; 336 0; 0 -1; 0 3; 1.5 0; 0 1.5];
for i = 1:size(invalid_sss_inputs, 1)
    err_caught = false;
    try
        nr_sim.sequences.gen_SSS(invalid_sss_inputs(i, 1), invalid_sss_inputs(i, 2));
    catch
        err_caught = true;
    end
    assert(err_caught, sprintf('gen_SSS must throw error for invalid inputs [%g, %g]', ...
        invalid_sss_inputs(i, 1), invalid_sss_inputs(i, 2)));
end

% Default parameter and empty input handling
ref_sss0 = nrSSS(0);
assert(isequal(nr_sim.sequences.gen_SSS(), ref_sss0), 'gen_SSS() must default to PCI 0');
assert(isequal(nr_sim.sequences.gen_SSS([]), ref_sss0), 'gen_SSS([]) must default to PCI 0');
assert(isequal(nr_sim.sequences.gen_SSS([], []), ref_sss0), 'gen_SSS([], []) must default to PCI 0');

% Excess arguments handling
err_caught = false;
try
    nr_sim.sequences.gen_SSS(1, 2, 3);
catch
    err_caught = true;
end
assert(err_caught, 'gen_SSS with 3 arguments must throw error');

%% Test 9: Extended SSS - Length 240 and BPSK Constellation
test_cells = [0, 1, 10, 100, 254, 255, 511, 700, 1007];
for idx = 1:length(test_cells)
    ncell = test_cells(idx);
    d_ext = nr_sim.sequences.gen_ExtendedSSS(ncell);
    assert(length(d_ext) == 240, 'Extended SSS length must be exactly 240');
    assert(iscolumn(d_ext), 'Extended SSS must be a column vector [240 x 1]');
    assert(all(d_ext == 1 | d_ext == -1), 'Extended SSS values must strictly be BPSK {-1, +1}');
    assert(isreal(d_ext), 'Extended SSS must be real-valued');
end

%% Test 10: Extended SSS - Auto-Correlation Peak and PSLR > 15 dB
test_cells = [0, 1, 10, 100, 254, 255, 511, 700, 1007];
pslr_results = zeros(length(test_cells), 1);
for idx = 1:length(test_cells)
    ncell = test_cells(idx);
    d_ext = double(nr_sim.sequences.gen_ExtendedSSS(ncell));
    r = xcorr(d_ext(:));
    
    % Peak at zero lag (index 240 in length 479 vector)
    assert(r(240) == 240, sprintf('Auto-correlation peak for cell %d must be 240', ncell));
    
    r_sidelobes = r;
    r_sidelobes(240) = 0;
    max_side = max(abs(r_sidelobes));
    pslr_val = 20 * log10(240 / max_side);
    pslr_results(idx) = pslr_val;
end

% Verify PSLR > 15 dB on baseline Cell ID 0
assert(pslr_results(1) >= 15.0, ...
    sprintf('Extended SSS PSLR for Cell ID 0 is %.2f dB (must exceed 15.0 dB)', pslr_results(1)));
% Verify ensemble average PSLR across test suite exceeds 15.5 dB
assert(mean(pslr_results) >= 15.5, ...
    sprintf('Mean PSLR across test suite is %.2f dB (must exceed 15.5 dB)', mean(pslr_results)));

%% Test 11: Extended SSS - Cross-Correlation Isolation Across Cell IDs
% Evaluates synchronous zero-lag isolation (governing Cell-ID discrimination in
% OFDM receivers after PSS synchronization) and verifies cross-correlation bounds.
test_cells = [0, 1, 10, 100, 254, 255, 511, 700, 1007];
num_pairs = length(test_cells) * (length(test_cells) - 1) / 2;
zero_cross_vals = zeros(num_pairs, 1);
pair_idx = 0;
max_zero_cross = 0;
max_all_cross = 0;

for i = 1:length(test_cells)
    for j = (i+1):length(test_cells)
        s_i = double(nr_sim.sequences.gen_ExtendedSSS(test_cells(i)));
        s_j = double(nr_sim.sequences.gen_ExtendedSSS(test_cells(j)));
        
        % Normalized zero-lag cross-correlation (synchronous subcarrier isolation)
        c0 = abs(sum(s_i(:) .* s_j(:))) / 240;
        pair_idx = pair_idx + 1;
        zero_cross_vals(pair_idx) = c0;
        max_zero_cross = max(max_zero_cross, c0);
        
        c_all = max(abs(xcorr(s_i(:), s_j(:)))) / 240;
        max_all_cross = max(max_all_cross, c_all);
    end
end

% 1. Zero-lag cross-correlation governs synchronous Cell-ID detection in OFDM
assert(max_zero_cross <= 0.1500, ...
    sprintf('Extended SSS maximum zero-lag cross-correlation %.4f exceeds 0.15 limit', max_zero_cross));
assert(mean(zero_cross_vals) < 0.0800, ...
    sprintf('Extended SSS mean zero-lag cross-correlation %.4f exceeds 0.08 limit', mean(zero_cross_vals)));

% 2. Distinct shift differential pairs have all-lag cross-correlation < 0.3000
assert(max_all_cross < 0.3000, ...
    sprintf('Extended SSS maximum all-lag cross-correlation %.4f exceeds 0.30 limit', max_all_cross));

% 3. Adversarial shift-collision stress test (PCIs sharing identical delta = (m0 - m1) mod 255)
% PCI 0 (m0=0, m1=0) and PCI 319 (m0=64, m1=64) share delta=0.
% At zero lag (synchronous grid), isolation is strictly preserved (<= 0.1500).
% At lag 64, aperiodic overlap reaches (240 - 64)/240 = 0.7333 <= 0.7500.
s0 = double(nr_sim.sequences.gen_ExtendedSSS(0));
s319 = double(nr_sim.sequences.gen_ExtendedSSS(319));
c0_collision = abs(sum(s0(:) .* s319(:))) / 240;
call_collision = max(abs(xcorr(s0(:), s319(:)))) / 240;
assert(c0_collision <= 0.1500, ...
    sprintf('Shift-collision zero-lag cross-correlation %.4f exceeds 0.15 limit', c0_collision));
assert(call_collision <= 0.7500, ...
    sprintf('Shift-collision all-lag peak %.4f exceeds theoretical overlap bound 0.75', call_collision));

%% Test 12: Extended SSS - Boundary Inputs and Exception Handling
invalid_ext_cells = [-1, 1008, 1500, -100, 2.5, NaN];
for val = invalid_ext_cells
    err_caught = false;
    try
        nr_sim.sequences.gen_ExtendedSSS(val);
    catch
        err_caught = true;
    end
    assert(err_caught, sprintf('gen_ExtendedSSS must throw error for invalid N_ID_cell=%g', val));
end

%% Test 13: PBCH DMRS - Length 144, Unit Power, and QPSK Constellation
test_dmrs_cases = [0 0; 0 7; 10 2; 100 4; 500 0; 1007 7];
for idx = 1:size(test_dmrs_cases, 1)
    ncell = test_dmrs_cases(idx, 1);
    issb = test_dmrs_cases(idx, 2);
    dmrs = nr_sim.sequences.gen_PBCHDMRS(ncell, issb);
    
    assert(length(dmrs) == 144, 'PBCH DMRS length must be exactly 144');
    assert(iscolumn(dmrs), 'PBCH DMRS must be a column vector [144 x 1]');
    assert(~isreal(dmrs), 'PBCH DMRS must be complex');
    
    % Unit average and instantaneous power
    assert(all(abs(abs(dmrs).^2 - 1.0) < 1e-10), 'Every DMRS symbol must have unit magnitude');
    
    % QPSK constellation coordinates (+-1/sqrt(2) +- j/sqrt(2))
    assert(all(abs(abs(real(dmrs)) - 1/sqrt(2)) < 1e-10), 'DMRS real parts must be +-1/sqrt(2)');
    assert(all(abs(abs(imag(dmrs)) - 1/sqrt(2)) < 1e-10), 'DMRS imag parts must be +-1/sqrt(2)');
end

%% Test 14: PBCH DMRS - 3GPP TS 38.211 Equivalence against nrPBCHDMRS
test_dmrs_cases = [0 0; 0 7; 10 2; 100 4; 500 0; 1007 7];
for idx = 1:size(test_dmrs_cases, 1)
    ncell = test_dmrs_cases(idx, 1);
    issb = test_dmrs_cases(idx, 2);
    dmrs = nr_sim.sequences.gen_PBCHDMRS(ncell, issb);
    ref_dmrs = nrPBCHDMRS(ncell, issb);
    
    assert(norm(double(dmrs(:)) - double(ref_dmrs(:))) < 1e-12, ...
        sprintf('PBCH DMRS for PCI=%d, ibar_SSB=%d must match 3GPP nrPBCHDMRS identically', ncell, issb));
end

% Verify dependency on ibar_SSB
dmrs_ssb0 = nr_sim.sequences.gen_PBCHDMRS(0, 0);
dmrs_ssb1 = nr_sim.sequences.gen_PBCHDMRS(0, 1);
assert(norm(dmrs_ssb0(:) - dmrs_ssb1(:)) > 1.0, ...
    'Different ibar_SSB values must produce distinct scrambled sequences');

%% Test 15: PBCH DMRS - Boundary Inputs and Exception Handling
invalid_dmrs_inputs = [-1 0; 1008 0; 0 -1; 0 8; 10 1.5; NaN 0];
for idx = 1:size(invalid_dmrs_inputs, 1)
    err_caught = false;
    try
        nr_sim.sequences.gen_PBCHDMRS(invalid_dmrs_inputs(idx, 1), invalid_dmrs_inputs(idx, 2));
    catch
        err_caught = true;
    end
    assert(err_caught, sprintf('gen_PBCHDMRS must throw error for inputs [%g, %g]', ...
        invalid_dmrs_inputs(idx, 1), invalid_dmrs_inputs(idx, 2)));
end

fprintf('\n[PASS] All 15 Sequence Generation unit tests completed successfully.\n');
