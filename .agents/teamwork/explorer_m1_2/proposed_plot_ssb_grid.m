function figHandle = proposed_plot_ssb_grid(arch, N_ID_cell, varargin)
% PROPOSED_PLOT_SSB_GRID Publication-grade visualizer for 2D SSB resource grids.
%
%   FIGHANDLE = PLOT_SSB_GRID(ARCH, N_ID_CELL) creates a publication-grade
%   subcarrier-by-symbol 2D visualization of the SSB resource grid for the
%   specified architecture ('Legacy', 'DesignA', 'DesignB', 'Jio', or 'all').
%
%   When ARCH is 'all' or omitted, a 2x2 comparison figure is generated
%   depicting all four architectures side-by-side, satisfying the requirements
%   for Figure 5 (fig5_grid_allocation.png / .fig).
%
%   Inputs:
%     ARCH      - Architecture identifier: 'Legacy', 'DesignA', 'DesignB', 'Jio',
%                 or 'all' (default: 'all')
%     N_ID_CELL - Physical Cell ID (default: 42)
%
%   Optional Name-Value Pairs:
%     'Visible'   - Figure visibility ('on' | 'off', default: 'on')
%     'SavePath'  - Base path without extension to save figure (e.g. 'figures/fig5_grid_allocation')
%     'DPI'       - Resolution for PNG export (default: 300)
%
%   Color Scheme:
%     - Light Gray     : Null / Guard REs
%     - Deep Navy Blue : PSS (127 REs)
%     - Amber Gold     : SSS (127 or 240 REs)
%     - Crimson Red    : Dedicated PBCH DMRS (144 REs)
%     - Emerald Green  : PBCH Data REs (432 or 480 REs)
%
%   Standard Reference:
%     - 3GPP TS 38.211 Section 7.4.3.1
%     - 3GPP Rel-20 Study Item baseline (Figure 5)

% Default arguments
if nargin < 1 || isempty(arch)
    arch = 'all';
end
if nargin < 2 || isempty(N_ID_cell)
    N_ID_cell = 42;
end

p = inputParser;
addParameter(p, 'Visible', 'on', @(x) ismember(lower(string(x)), ["on", "off"]));
addParameter(p, 'SavePath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'DPI', 300, @(x) isnumeric(x) && isscalar(x) && x > 0);
parse(p, varargin{:});
opt = p.Results;

% 5-Color discrete palette:
% 1: Null/Guard, 2: PSS, 3: SSS, 4: PBCH DMRS, 5: PBCH Data
cmap = [
    0.93 0.93 0.93; ... % 1: Null / Guard (Light Gray)
    0.10 0.38 0.72; ... % 2: PSS (Deep Blue)
    0.95 0.68 0.12; ... % 3: SSS (Amber Gold)
    0.85 0.18 0.18; ... % 4: PBCH DMRS (Crimson Red)
    0.18 0.65 0.28      % 5: PBCH Data (Emerald Green)
];

v_shift_legacy = mod(N_ID_cell, 4);
v_shift_comb3  = mod(N_ID_cell, 3);

if strcmpi(arch, 'all')
    % 2x2 Multi-Panel Publication Figure
    figHandle = figure('Name', 'SSB 2D Resource Grid Architectures (Figure 5)', ...
        'Color', 'w', 'Position', [100, 80, 1300, 920], 'Visible', opt.Visible);
    
    arch_list = {'Legacy', 'DesignA', 'DesignB', 'Jio'};
    sub_titles = {
        sprintf('(a) Architecture 1: Legacy 5G NR Baseline (Cell ID = %d, v_{shift} = %d)', N_ID_cell, v_shift_legacy), ...
        '(b) Architecture 2: Qualcomm Design A (Concentrated SSS @ Sym 2, 0 DMRS)', ...
        sprintf('(c) Architecture 3: Qualcomm Design B / Comb-SSS (Comb-3 SSS, v_{shift} = %d)', v_shift_comb3), ...
        '(d) Architecture 4: Jio Platforms SSS-Assisted (271 Joint Pilots)'
    };
    
    sub_stats = {
        sprintf('PBCH Data: 432 REs (E=864, R=0.0648)\nDMRS: 144 REs | SSS: 127 REs\nPSS: 127 REs | Null: 130 REs'), ...
        sprintf('PBCH Data: 480 REs (E=960, R=0.0583)\nExt-SSS (as DMRS): 240 REs\nPSS: 127 REs | Null: 113 REs'), ...
        sprintf('PBCH Data: 480 REs (E=960, R=0.0583)\nComb-3 SSS: 240 REs (80/sym)\nPSS: 127 REs | Null: 113 REs'), ...
        sprintf('PBCH Data: 432 REs (E=864, R=0.0648)\nJoint Pilots: 271 REs (144 DMRS + 127 SSS)\nPSS: 127 REs | Null: 130 REs')
    };
    
    for idx = 1:4
        cur_arch = arch_list{idx};
        grid_map = build_type_grid(cur_arch, N_ID_cell, v_shift_legacy, v_shift_comb3);
        
        ax = subplot(2, 2, idx);
        imagesc(0:3, 0:239, grid_map, [1 5]);
        colormap(ax, cmap);
        set(ax, 'YDir', 'normal', 'XTick', 0:3, 'YTick', [0, 48, 56, 120, 183, 192, 239]);
        grid on;
        set(ax, 'GridColor', [0.3 0.3 0.3], 'GridAlpha', 0.35, 'LineWidth', 0.6);
        
        title(sub_titles{idx}, 'FontSize', 11, 'FontWeight', 'bold');
        xlabel('OFDM Symbol Index (0..3)', 'FontSize', 10);
        ylabel('Subcarrier Index k (0..239)', 'FontSize', 10);
        
        % Inset textbox with exact RE breakdown
        text(ax, 0.05, 0.95, sub_stats{idx}, 'Units', 'normalized', ...
            'VerticalAlignment', 'top', 'FontSize', 8.5, 'BackgroundColor', [1 1 1 0.85], ...
            'EdgeColor', [0.7 0.7 0.7], 'Margin', 5);
    end
    
    % Shared bottom legend using invisible dummy markers
    legend_ax = axes('Position', [0.15, 0.02, 0.70, 0.04], 'Visible', 'off');
    hold(legend_ax, 'on');
    h = gobjects(5, 1);
    labels = {
        'Null / Guard (0 RE)', ...
        'PSS (127 REs)', ...
        'SSS (127 or 240 REs)', ...
        'PBCH DMRS (144 REs)', ...
        'PBCH Data (432 or 480 REs)'
    };
    for c = 1:5
        h(c) = plot(legend_ax, NaN, NaN, 's', 'MarkerFaceColor', cmap(c, :), ...
            'MarkerEdgeColor', [0.2 0.2 0.2], 'MarkerSize', 11, 'LineWidth', 0.8);
    end
    legend(legend_ax, h, labels, 'Orientation', 'horizontal', ...
        'FontSize', 10, 'Box', 'off', 'Location', 'south');
    
    sgtitle(sprintf('Figure 5: 2D SSB Resource Grid Architectures (Carrier: 7 GHz, SCS: 30 kHz, FFT: 512, Cell ID: %d)', N_ID_cell), ...
        'FontSize', 13, 'FontWeight', 'bold');
    
else
    % Single Architecture Detailed Figure
    arch_str = validatestring(arch, {'Legacy', 'DesignA', 'DesignB', 'Jio'}, mfilename, 'arch', 1);
    grid_map = build_type_grid(arch_str, N_ID_cell, v_shift_legacy, v_shift_comb3);
    
    figHandle = figure('Name', sprintf('SSB 2D Grid - %s', arch_str), ...
        'Color', 'w', 'Position', [150, 120, 850, 750], 'Visible', opt.Visible);
    
    ax = gca;
    imagesc(0:3, 0:239, grid_map, [1 5]);
    colormap(ax, cmap);
    set(ax, 'YDir', 'normal', 'XTick', 0:3, 'YTick', [0, 48, 56, 120, 183, 192, 239]);
    grid on;
    set(ax, 'GridColor', [0.3 0.3 0.3], 'GridAlpha', 0.35, 'LineWidth', 0.6);
    
    title(sprintf('SSB 2D Resource Grid: %s (Cell ID = %d)', arch_str, N_ID_cell), ...
        'FontSize', 12, 'FontWeight', 'bold');
    xlabel('OFDM Symbol Index (0..3)', 'FontSize', 11);
    ylabel('Subcarrier Index k (0..239)', 'FontSize', 11);
    
    hold(ax, 'on');
    h = gobjects(5, 1);
    labels = {'Null / Guard', 'PSS (127 REs)', 'SSS', 'PBCH DMRS', 'PBCH Data'};
    for c = 1:5
        h(c) = plot(ax, NaN, NaN, 's', 'MarkerFaceColor', cmap(c, :), ...
            'MarkerEdgeColor', [0.2 0.2 0.2], 'MarkerSize', 10, 'LineWidth', 0.8);
    end
    legend(ax, h, labels, 'Location', 'southoutside', 'Orientation', 'horizontal', 'FontSize', 10);
end

% Optional file saving (.png and .fig)
if ~isempty(opt.SavePath)
    [saveDir, baseName, ~] = fileparts(opt.SavePath);
    if ~isempty(saveDir) && ~exist(saveDir, 'dir')
        mkdir(saveDir);
    end
    pngFile = fullfile(saveDir, [baseName, '.png']);
    figFile = fullfile(saveDir, [baseName, '.fig']);
    
    exportgraphics(figHandle, pngFile, 'Resolution', opt.DPI);
    savefig(figHandle, figFile);
    fprintf('Saved Figure 5 to:\n  %s\n  %s\n', pngFile, figFile);
end

end

% --- Helper Function: Build Discrete RE Type Matrix ---
function grid_map = build_type_grid(arch, ~, v_shift_legacy, v_shift_comb3)
    grid_map = ones(240, 4); % 1: Null
    
    % PSS: Symbol 1 (0-based 0), subcarriers 57:183 (0-based 56:182)
    grid_map(57:183, 1) = 2; % 2: PSS
    
    switch arch
        case {'Legacy', 'Jio'}
            % Symbols 2 & 4 (0-based 1 & 3): 180 PBCH Data + 60 DMRS
            for sym = [2, 4]
                k_dmrs = 4*(0:59) + v_shift_legacy + 1;
                grid_map(:, sym) = 5; % PBCH Data
                grid_map(k_dmrs, sym) = 4; % PBCH DMRS
            end
            
            % Symbol 3 (0-based 2): 127 SSS, 24 DMRS, 72 PBCH Data, 17 Guard (Null)
            grid_map(57:183, 3) = 3; % SSS
            
            % Lower edge (subcarriers 1..48)
            k_d3_lower = 4*(0:11) + v_shift_legacy + 1;
            grid_map(1:48, 3) = 5; % PBCH Data
            grid_map(k_d3_lower, 3) = 4; % DMRS
            
            % Upper edge (subcarriers 193..240)
            k_d3_upper = 4*(48:59) + v_shift_legacy + 1;
            grid_map(193:240, 3) = 5; % PBCH Data
            grid_map(k_d3_upper, 3) = 4; % DMRS
            % (Subcarriers 49..56 and 184..192 remain 1: Null)
            
        case 'DesignA'
            % Concentrated Extended SSS at Symbol 3 (all 240 subcarriers)
            grid_map(:, 3) = 3; % 3: SSS (serves as DMRS)
            
            % Symbol 2: 240 PBCH Data (0 DMRS)
            grid_map(:, 2) = 5;
            
            % Symbol 4: 240 PBCH Data (0 DMRS)
            grid_map(:, 4) = 5;
            
        case 'DesignB'
            % Comb-3 SSS across Symbols 2, 3, 4 (80 REs/symbol)
            for sym = 2:4
                k_sss = 3*(0:79) + v_shift_comb3 + 1;
                grid_map(:, sym) = 5; % 160 PBCH Data
                grid_map(k_sss, sym) = 3; % 80 Comb-3 SSS
            end
    end
end
