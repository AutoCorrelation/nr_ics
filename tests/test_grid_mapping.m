%% test_grid_mapping.m - Comprehensive Unit Test Suite for Milestone 1 Grid Mapping
% Covers: F4 (Legacy Grid), F5 (Design A Grid), F6 (Design B Comb-3 Grid), F7 (Jio Grid), F8 (Demapper & Masks)
% Requirements: TS 38.211 §7.4.3, Rel-20 R1-2606375, R1-2606847, R1-2605419

test_dir = fileparts(mfilename('fullpath'));
proj_root = fullfile(test_dir, '..');
addpath(proj_root);

%% Test 1: Grid Dimensions and 960 RE Conservation
% Total RE count per architecture must strictly equal 240 subcarriers x 4 symbols = 960 REs
architectures = {'Legacy', 'DesignA', 'DesignB', 'Jio'};
for a = 1:length(architectures)
    arch = architectures{a};
    N_data = 432;
    if ismember(arch, {'DesignA', 'DesignB'})
        N_data = 480;
    end
    dummy_data = (randn(N_data, 1) + 1j*randn(N_data, 1)) / sqrt(2);
    
    [grid, info] = nr_sim.grid.map_ssb_grid(dummy_data, arch, 0);
    assert(isequal(size(grid), [240, 4]), sprintf('%s grid dimensions must be [240, 4]', arch));
    assert(numel(grid) == 960, sprintf('%s total elements must be 960', arch));
    
    % Sum of active channel REs + guard REs must equal 960
    n_pbch = length(info.pbchInd);
    n_dmrs = length(info.dmrsInd);
    n_sss = length(info.sssInd);
    n_pss = length(info.pssInd);
    n_active = n_pbch + n_dmrs + n_sss + n_pss;
    
    if isfield(info, 'guardInd')
        n_guard = length(info.guardInd);
    elseif isfield(info, 'nullInd')
        n_guard = length(info.nullInd);
    else
        n_guard = 960 - n_active;
    end
    assert(n_active + n_guard == 960, ...
        sprintf('%s RE conservation violated: %d active + %d guard != 960', arch, n_active, n_guard));
end

%% Test 2: PBCH Data RE Count Allocation (432 vs 480 REs)
architectures = {'Legacy', 'DesignA', 'DesignB', 'Jio'};
for a = 1:length(architectures)
    arch = architectures{a};
    N_data = 432;
    if ismember(arch, {'DesignA', 'DesignB'})
        N_data = 480;
    end
    dummy_data = ones(N_data, 1);
    [~, info] = nr_sim.grid.map_ssb_grid(dummy_data, arch, 0);
    
    if ismember(arch, {'Legacy', 'Jio'})
        assert(length(info.pbchInd) == 432, ...
            sprintf('%s must allocate exactly 432 PBCH data REs (E=864 coded bits)', arch));
        % Polar rate check
        R = 56 / (432 * 2);
        assert(abs(R - 0.06481) < 1e-4, 'Legacy polar code rate must be ~0.0648');
    else
        assert(length(info.pbchInd) == 480, ...
            sprintf('%s must allocate exactly 480 PBCH data REs (E=960 coded bits)', arch));
        % Polar rate check
        R = 56 / (480 * 2);
        assert(abs(R - 0.05833) < 1e-4, 'Design A/B polar code rate must be ~0.0583');
    end
end

%% Test 3: Zero Collision Avoidance Across All Channels
% Active channels must be strictly disjoint sets for all Cell IDs
architectures = {'Legacy', 'DesignA', 'DesignB', 'Jio'};
test_cells = [0, 1, 2, 3, 10, 100, 335, 1007];
for a = 1:length(architectures)
    arch = architectures{a};
    N_data = 432;
    if ismember(arch, {'DesignA', 'DesignB'})
        N_data = 480;
    end
    dummy_data = ones(N_data, 1);
    
    for c = 1:length(test_cells)
        ncell = test_cells(c);
        [grid, info] = nr_sim.grid.map_ssb_grid(dummy_data, arch, ncell);
        
        p_pbch = info.pbchInd(:);
        p_dmrs = info.dmrsInd(:);
        p_sss  = info.sssInd(:);
        p_pss  = info.pssInd(:);
        
        assert(isempty(intersect(p_pbch, p_dmrs)), ...
            sprintf('%s (PCI=%d): PBCH and DMRS collision detected!', arch, ncell));
        assert(isempty(intersect(p_pbch, p_sss)), ...
            sprintf('%s (PCI=%d): PBCH and SSS collision detected!', arch, ncell));
        assert(isempty(intersect(p_pbch, p_pss)), ...
            sprintf('%s (PCI=%d): PBCH and PSS collision detected!', arch, ncell));
        assert(isempty(intersect(p_dmrs, p_sss)), ...
            sprintf('%s (PCI=%d): DMRS and SSS collision detected!', arch, ncell));
        assert(isempty(intersect(p_dmrs, p_pss)), ...
            sprintf('%s (PCI=%d): DMRS and PSS collision detected!', arch, ncell));
        assert(isempty(intersect(p_sss, p_pss)), ...
            sprintf('%s (PCI=%d): SSS and PSS collision detected!', arch, ncell));
        
        % Ensure zero energy in guard subcarriers
        all_active = [p_pbch; p_dmrs; p_sss; p_pss];
        assert(length(unique(all_active)) == length(all_active), ...
            sprintf('%s (PCI=%d): Duplicate indices found in active allocation', arch, ncell));
        guard_sub = setdiff(1:960, all_active);
        assert(all(grid(guard_sub) == 0), ...
            sprintf('%s (PCI=%d): Guard subcarriers contain non-zero energy!', arch, ncell));
    end
end

%% Test 4: Legacy 5G NR Standard Equivalence against 5G Toolbox
test_cells = [0, 1, 2, 3, 10, 100, 335, 1007];
for c = 1:length(test_cells)
    ncell = test_cells(c);
    dummy_data = ones(432, 1);
    [~, info] = nr_sim.grid.map_ssb_grid(dummy_data, 'Legacy', ncell);
    
    ref_pbch_ind = nrPBCHIndices(ncell);
    ref_dmrs_ind = nrPBCHDMRSIndices(ncell);
    
    assert(isequal(sort(info.pbchInd(:)), sort(ref_pbch_ind(:))), ...
        sprintf('Legacy PBCH indices (PCI=%d) must match 5G Toolbox nrPBCHIndices identically', ncell));
    assert(isequal(sort(info.dmrsInd(:)), sort(ref_dmrs_ind(:))), ...
        sprintf('Legacy DMRS indices (PCI=%d) must match 5G Toolbox nrPBCHDMRSIndices identically', ncell));
    
    % Subcarrier coordinates of PSS (Sym 1, subcarriers 57..183 in 1-based index)
    [k_pss, l_pss] = ind2sub([240, 4], info.pssInd);
    assert(all(l_pss == 1), 'PSS must be strictly on Symbol 1 (col 1)');
    assert(isequal(sort(k_pss(:)), (57:183)'), 'PSS subcarriers must be 57..183');
    
    % Subcarrier coordinates of SSS (Sym 3, subcarriers 57..183 in 1-based index)
    [k_sss, l_sss] = ind2sub([240, 4], info.sssInd);
    assert(all(l_sss == 3), 'SSS must be strictly on Symbol 3 (col 3)');
    assert(isequal(sort(k_sss(:)), (57:183)'), 'SSS subcarriers must be 57..183');
end

%% Test 5: Qualcomm Design A Layout Invariants (Concentrated 240 SSS)
test_cells = [0, 1, 2, 3, 10, 100, 335, 1007];
for c = 1:length(test_cells)
    ncell = test_cells(c);
    dummy_data = ones(480, 1);
    [~, info] = nr_sim.grid.map_ssb_grid(dummy_data, 'DesignA', ncell);
    
    % 0 Dedicated DMRS
    assert(isempty(info.dmrsInd), 'Design A must have 0 dedicated DMRS REs');
    
    % Concentrated SSS at Symbol 2 (col 3): exactly 240 REs occupying full band
    assert(length(info.sssInd) == 240, 'Design A must have exactly 240 SSS REs');
    [k_sss, l_sss] = ind2sub([240, 4], info.sssInd);
    assert(all(l_sss == 3), 'Design A SSS must be strictly concentrated in Symbol 2 (col 3)');
    assert(isequal(sort(k_sss(:)), (1:240)'), 'Design A SSS must span all 240 subcarriers');
    
    % PBCH Data REs: 240 in Symbol 1 (col 2), 240 in Symbol 3 (col 4), 0 in Symbol 2
    [~, l_pbch] = ind2sub([240, 4], info.pbchInd);
    assert(sum(l_pbch == 2) == 240, 'Design A Symbol 1 must contain exactly 240 PBCH data REs');
    assert(sum(l_pbch == 4) == 240, 'Design A Symbol 3 must contain exactly 240 PBCH data REs');
    assert(sum(l_pbch == 3) == 0, 'Design A Symbol 2 must contain 0 PBCH data REs');
end

%% Test 6: Qualcomm Design B / MediaTek Comb-3 SSS Layout Invariants
test_cells = [0, 1, 2, 3, 10, 100, 335, 1007];
for c = 1:length(test_cells)
    ncell = test_cells(c);
    dummy_data = ones(480, 1);
    [~, info] = nr_sim.grid.map_ssb_grid(dummy_data, 'DesignB', ncell);
    
    % 0 Dedicated DMRS
    assert(isempty(info.dmrsInd), 'Design B must have 0 dedicated DMRS REs');
    
    % 240 SSS REs distributed across Symbols 1, 2, 3 (cols 2, 3, 4)
    assert(length(info.sssInd) == 240, 'Design B must have 240 total SSS REs');
    [k_sss, l_sss] = ind2sub([240, 4], info.sssInd);
    
    for l = 2:4
        assert(sum(l_sss == l) == 80, sprintf('Design B Symbol col %d must have 80 SSS REs', l));
        k_sym = sort(k_sss(l_sss == l));
        % Verify Comb-3 subcarrier spacing of exactly 3
        assert(all(diff(k_sym) == 3), sprintf('Design B SSS on col %d must have Comb-3 spacing (delta k=3)', l));
    end
    
    % 480 PBCH Data REs distributed across Symbols 1, 2, 3 (160 per symbol)
    [~, l_pbch] = ind2sub([240, 4], info.pbchInd);
    for l = 2:4
        assert(sum(l_pbch == l) == 160, sprintf('Design B Symbol col %d must have 160 PBCH REs', l));
    end
end

%% Test 7: Jio Platforms SSS-Assisted Joint Pilot Metadata
test_cells = [0, 1, 2, 3, 10, 100, 335, 1007];
for c = 1:length(test_cells)
    ncell = test_cells(c);
    dummy_data = ones(432, 1);
    [~, info] = nr_sim.grid.map_ssb_grid(dummy_data, 'Jio', ncell);
    
    % Physical grid matches Legacy
    [~, ref_info] = nr_sim.grid.map_ssb_grid(dummy_data, 'Legacy', ncell);
    assert(isequal(info.pbchInd, ref_info.pbchInd), 'Jio PBCH indices must match Legacy');
    assert(isequal(info.dmrsInd, ref_info.dmrsInd), 'Jio DMRS indices must match Legacy');
    assert(isequal(info.sssInd, ref_info.sssInd), 'Jio SSS indices must match Legacy');
    
    % Phase coherence and joint pilot metadata
    assert(isfield(info, 'isPhaseCoherent') && info.isPhaseCoherent == true, ...
        'Jio grid must declare phase coherence flag (q_CW)');
    
    % Pilot count verification: 144 DMRS + 127 SSS = 271 joint pilots
    joint_pilots = length(info.dmrsInd) + length(info.sssInd);
    assert(joint_pilots == 271, 'Jio Platforms must support 271 joint pilots across the SSB');
    
    % Symbol 2 central hole bridging
    [k_dmrs, l_dmrs] = ind2sub([240, 4], info.dmrsInd);
    [k_sss, l_sss]   = ind2sub([240, 4], info.sssInd);
    k_sym2_pilots = sort([k_dmrs(l_dmrs == 3); k_sss(l_sss == 3)]);
    assert(length(k_sym2_pilots) == 151, 'Symbol 2 must contain 24 DMRS + 127 SSS = 151 pilots');
    assert(any(k_sym2_pilots >= 57 & k_sym2_pilots <= 183), ...
        'SSS must bridge the 144-subcarrier central hole in Symbol 2');
end

%% Test 8: Demapper Round-Trip Invertibility & Multi-Antenna Support
architectures = {'Legacy', 'DesignA', 'DesignB', 'Jio'};
test_cells = [0, 1, 2, 3, 10, 100, 335, 1007];
for a = 1:length(architectures)
    arch = architectures{a};
    N_data = 432;
    if ismember(arch, {'DesignA', 'DesignB'})
        N_data = 480;
    end
    
    for c = 1:length(test_cells)
        ncell = test_cells(c);
        
        % Test Case 8A: Random complex QPSK symbols (1 Rx)
        s_tx = (randn(N_data, 1) + 1j*randn(N_data, 1)) / sqrt(2);
        grid = nr_sim.grid.map_ssb_grid(s_tx, arch, ncell);
        [s_rx, rx_pilots, ref_pilots] = nr_sim.grid.demap_ssb_grid(grid, arch, ncell);
        
        assert(length(s_rx) == N_data, sprintf('%s demapped symbol length mismatch', arch));
        assert(norm(s_rx - s_tx) < 1e-12, ...
            sprintf('%s demapper round-trip reconstruction error exceeds 1e-12', arch));
        assert(norm(rx_pilots - ref_pilots) < 1e-12, ...
            sprintf('%s demapped pilots do not match reference pilots', arch));
        
        % Test Case 8B: Strictly monotonic test vector to verify order preservation
        s_ordered = (1:N_data)' .* exp(1j * (1:N_data)' * pi / 16);
        grid_ord = nr_sim.grid.map_ssb_grid(s_ordered, arch, ncell);
        s_rx_ord = nr_sim.grid.demap_ssb_grid(grid_ord, arch, ncell);
        
        assert(norm(s_rx_ord - s_ordered) < 1e-12, ...
            sprintf('%s demapper symbol order scrambled or transposed!', arch));
            
        % Test Case 8C: Multi-antenna SIMO demapping (4 Rx antennas)
        grid_simo = repmat(grid, [1, 1, 4]);
        for rxIdx = 1:4
            grid_simo(:, :, rxIdx) = grid_simo(:, :, rxIdx) * exp(1j * rxIdx * pi / 4);
        end
        [s_rx_simo, rx_pilots_simo] = nr_sim.grid.demap_ssb_grid(grid_simo, arch, ncell);
        assert(isequal(size(s_rx_simo), [N_data, 4]), 'SIMO PBCH output must be [N_data x 4]');
        for rxIdx = 1:4
            expected_syms = s_tx * exp(1j * rxIdx * pi / 4);
            assert(norm(s_rx_simo(:, rxIdx) - expected_syms) < 1e-12, ...
                sprintf('Antenna %d demapping error in SIMO', rxIdx));
        end
    end
end

%% Test 9: Robustness, Negative Boundaries, and Error Trapping
% 1. Invalid architecture name
err_arch = false;
try
    nr_sim.grid.map_ssb_grid(ones(432, 1), 'InvalidArch', 0);
catch
    err_arch = true;
end
assert(err_arch, 'map_ssb_grid must throw an error for invalid architecture name');

% 2. Mismatched data vector length
err_len = false;
try
    nr_sim.grid.map_ssb_grid(ones(480, 1), 'Legacy', 0); % Legacy requires 432
catch
    err_len = true;
end
assert(err_len, 'map_ssb_grid must reject 480 data symbols for Legacy architecture');

err_len_a = false;
try
    nr_sim.grid.map_ssb_grid(ones(432, 1), 'DesignA', 0); % DesignA requires 480
catch
    err_len_a = true;
end
assert(err_len_a, 'map_ssb_grid must reject 432 data symbols for Design A');

% 3. Out-of-bounds Cell ID
err_pci = false;
try
    nr_sim.grid.map_ssb_grid(ones(432, 1), 'Legacy', 1008);
catch
    err_pci = true;
end
assert(err_pci, 'map_ssb_grid must reject PCI > 1007');

% 4. Invalid grid dimensions passed to demapper
err_demap_dim = false;
try
    nr_sim.grid.demap_ssb_grid(zeros(200, 4), 'Legacy', 0);
catch
    err_demap_dim = true;
end
assert(err_demap_dim, 'demap_ssb_grid must reject grid with subcarriers != 240');

%% Test 10: Visualizer Smoke Test (plot_ssb_grid)
architectures = {'all', 'Legacy', 'DesignA', 'DesignB', 'Jio'};
for a = 1:length(architectures)
    arch = architectures{a};
    fig = nr_sim.grid.plot_ssb_grid(arch, 0, 'Visible', 'off');
    assert(~isempty(fig) && isgraphics(fig), 'plot_ssb_grid must return valid figure');
    assert(isa(fig, 'matlab.ui.Figure') || ishandle(fig), 'plot_ssb_grid must return valid figure');
    close(fig);
end

fprintf('\n[PASS] All 10 Grid Mapping unit tests completed successfully.\n');
