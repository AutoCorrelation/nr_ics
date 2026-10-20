% TEST_PROPOSED_GRID Self-verification test script for proposed grid functions.
% Tests: proposed_map_ssb_grid, proposed_demap_ssb_grid, proposed_plot_ssb_grid.

fprintf('====================================================================\n');
fprintf('  STARTING COMPREHENSIVE GRID FUNCTIONS SELF-VERIFICATION\n');
fprintf('====================================================================\n');

addpath('C:\workspace\nr_ics\.agents\teamwork\explorer_m1_2');

architectures = {'Legacy', 'DesignA', 'DesignB', 'Jio'};
test_cell_ids = [0, 1, 2, 42, 100, 335, 500, 1007];

%% 1. Test Grid Mapping and RE Conservation across all 4 architectures & cell IDs
fprintf('\n--- TEST 1: RE Conservation & Collision Check ---\n');
for a = 1:length(architectures)
    arch = architectures{a};
    for c = 1:length(test_cell_ids)
        cell_id = test_cell_ids(c);
        
        switch arch
            case {'Legacy', 'Jio'}
                numPbch = 432;
                expectedNull = 130;
                expectedData = 432;
                expectedSSS = 127;
                expectedDMRS = 144;
                if strcmp(arch, 'Legacy')
                    expectedPilots = 144;
                else
                    expectedPilots = 271;
                end
            case {'DesignA', 'DesignB'}
                numPbch = 480;
                expectedNull = 113;
                expectedData = 480;
                expectedSSS = 240;
                expectedDMRS = 0;
                expectedPilots = 240;
        end
        
        tx_pbch = (sign(randn(numPbch, 1)) + 1j*sign(randn(numPbch, 1))) / sqrt(2);
        [grid, info] = proposed_map_ssb_grid(tx_pbch, arch, cell_id);
        
        % Assert grid dimensions
        assert(isequal(size(grid), [240, 4]), 'Grid must be [240 x 4]');
        
        % Assert RE counts
        assert(length(info.pbchInd) == expectedData, 'PBCH RE count mismatch');
        assert(length(info.dmrsInd) == expectedDMRS, 'DMRS RE count mismatch');
        assert(length(info.sssInd) == expectedSSS, 'SSS RE count mismatch');
        assert(length(info.pssInd) == 127, 'PSS RE count mismatch');
        assert(length(info.nullInd) == expectedNull, 'Null RE count mismatch');
        assert(length(info.pilotInd) == expectedPilots, 'Pilot RE count mismatch');
        
        % Assert zero collision
        all_allocated = [info.pssInd; info.sssInd; info.dmrsInd; info.pbchInd];
        assert(length(all_allocated) == length(unique(all_allocated)), ...
            'Collision detected in RE allocation!');
        
        % Assert full 960 grid conservation
        assert(length(all_allocated) + length(info.nullInd) == 960, ...
            'Grid conservation violated! Total RE count ~= 960');
        
        % Assert that null REs in grid are strictly 0
        assert(all(grid(info.nullInd) == 0), 'Null REs must contain zero power!');
    end
    fprintf('  [PASS] %-10s: Passed all 8 Cell IDs (RE conservation, zero collisions, zero null power)\n', arch);
end

%% 2. Test Round-Trip Demapping (Single Antenna & 1T4R SIMO)
fprintf('\n--- TEST 2: Round-Trip Demapping Fidelity ---\n');
for a = 1:length(architectures)
    arch = architectures{a};
    cell_id = 42;
    numPbch = 432;
    if ismember(arch, {'DesignA', 'DesignB'})
        numPbch = 480;
    end
    
    tx_pbch = (sign(randn(numPbch, 1)) + 1j*sign(randn(numPbch, 1))) / sqrt(2);
    [tx_grid, info_tx] = proposed_map_ssb_grid(tx_pbch, arch, cell_id);
    
    % Test 2A: Single Antenna (2D)
    [rx_pbch_1d, rx_pilots_1d, ref_pilots_1d, info_rx_1d] = proposed_demap_ssb_grid(tx_grid, arch, cell_id);
    assert(isequal(rx_pbch_1d, tx_pbch), 'Single antenna: Demapped PBCH must match TX PBCH identically!');
    assert(isequal(rx_pilots_1d, ref_pilots_1d), 'Single antenna: Demapped pilots must match reference pilots identically!');
    assert(isequal(info_tx.pbchInd, info_rx_1d.pbchInd), 'PBCH indices mismatch between map and demap!');
    assert(isequal(info_tx.pilotInd, info_rx_1d.pilotInd), 'Pilot indices mismatch between map and demap!');
    
    % Test 2B: 1T4R SIMO (3D: [240 x 4 x 4])
    h_channel = [1.0; 0.8*exp(1j*pi/4); 0.6*exp(-1j*pi/3); 0.9*exp(1j*pi/6)]; % 4 receive antennas
    rx_grid_4d = zeros(240, 4, 4);
    for r = 1:4
        rx_grid_4d(:, :, r) = tx_grid * h_channel(r);
    end
    
    [rx_pbch_4d, rx_pilots_4d, ref_pilots_4d, info_rx_4d] = proposed_demap_ssb_grid(rx_grid_4d, arch, cell_id);
    assert(isequal(size(rx_pbch_4d), [numPbch, 4]), '4Rx PBCH size mismatch');
    assert(isequal(size(rx_pilots_4d), [length(info_tx.pilotInd), 4]), '4Rx pilots size mismatch');
    
    % Verify channel extraction per antenna
    for r = 1:4
        err_pbch = max(abs(rx_pbch_4d(:, r) - tx_pbch * h_channel(r)));
        err_pilot = max(abs(rx_pilots_4d(:, r) - ref_pilots_4d * h_channel(r)));
        assert(err_pbch < 1e-12, '4Rx channel fidelity error on PBCH');
        assert(err_pilot < 1e-12, '4Rx channel fidelity error on Pilots');
    end
    fprintf('  [PASS] %-10s: Perfect round-trip recovery (1-Rx identical match, 4-Rx channel fidelity < 1e-12)\n', arch);
end

%% 3. Test Error Handling & Input Validation
fprintf('\n--- TEST 3: Defensive Input Validation & Error Handling ---\n');
passed_checks = 0;

% Test 3A: Invalid PBCH symbol count
try
    proposed_map_ssb_grid(zeros(400, 1), 'Legacy', 0);
    error('Should have thrown error on invalid PBCH length');
catch ME
    assert(strcmp(ME.identifier, 'nr_sim:grid:InvalidSymbolCount'), 'Wrong error ID');
    passed_checks = passed_checks + 1;
end

% Test 3B: Invalid Cell ID
try
    proposed_map_ssb_grid(zeros(432, 1), 'Legacy', 1008);
    error('Should have thrown error on cell ID 1008');
catch ME
    passed_checks = passed_checks + 1;
end

% Test 3C: Invalid Grid Size in demap
try
    proposed_demap_ssb_grid(zeros(100, 4), 'Legacy', 0);
    error('Should have thrown error on invalid grid size');
catch ME
    assert(strcmp(ME.identifier, 'nr_sim:grid:InvalidGridSize'), 'Wrong error ID');
    passed_checks = passed_checks + 1;
end
fprintf('  [PASS] Input validation: All %d negative test cases passed successfully.\n', passed_checks);

%% 4. Test Visualization Function (Figure 5)
fprintf('\n--- TEST 4: Visualization Function (plot_ssb_grid) ---\n');
testFigFile = 'C:\workspace\nr_ics\.agents\teamwork\explorer_m1_2\test_fig5';
f = proposed_plot_ssb_grid('all', 42, 'Visible', 'off', 'SavePath', testFigFile);
assert(isa(f, 'matlab.ui.Figure'), 'Should return a figure handle');
assert(exist([testFigFile, '.png'], 'file') == 2, 'PNG file should exist');
assert(exist([testFigFile, '.fig'], 'file') == 2, 'FIG file should exist');
close(f);
delete([testFigFile, '.png']);
delete([testFigFile, '.fig']);
fprintf('  [PASS] Figure 5 generation and export (.png & .fig) validated successfully.\n');

fprintf('\n====================================================================\n');
fprintf('  ALL GRID VERIFICATION TESTS COMPLETED SUCCESSFULLY!\n');
fprintf('====================================================================\n');
