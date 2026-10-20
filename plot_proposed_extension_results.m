function plot_proposed_extension_results(varargin)
%PLOT_PROPOSED_EXTENSION_RESULTS Generates publication-grade comparison figures
%for the Proposed 5-Symbol SSB Extension vs Legacy 5G NR with clean white background.
%
%   Generates:
%     1. figures/fig1_pbch_bler_extension.png (.fig) - PBCH BLER at 3 km/h & 120 km/h
%     2. figures/fig2_sss_mdr_extension.png (.fig)   - SSS MDR at 3 km/h & 120 km/h

    if nargin >= 1 && isstruct(varargin{1})
        results = varargin{1};
    else
        matFile = 'results_proposed_5symbol_extension.mat';
        if ~exist(matFile, 'file')
            error('Results file %s not found. Run run_proposed_extension_simulation first.', matFile);
        end
        data = load(matFile);
        results = data.results;
    end

    if ~exist('figures', 'dir')
        mkdir('figures');
    end

    snr = results.snr;
    numRx = 4;
    if isfield(results, 'numRx'), numRx = results.numRx; end
    if numRx == 1, antStr = '1T1R SISO'; else, antStr = sprintf('1T%dR SIMO', numRx); end

    nTrials = 100;
    if isfield(results, 'nTrials'), nTrials = results.nTrials; end

    c_leg = [0.15 0.15 0.15];     % Dark Gray / Black
    c_epre = [0.85 0.15 0.15];    % Vivid Crimson Red
    c_energy = [0.08 0.45 0.82];  % Deep Ocean Blue
    c_coh = [0.12 0.62 0.25];     % Emerald Green

    %% ====================================================================
    % FIGURE 1: PBCH BLER (3 km/h vs 120 km/h)
    %% ====================================================================
    f1 = figure('Name', 'Fig1: PBCH BLER Comparison', 'Color', 'w', ...
        'Position', [80, 80, 1100, 500], 'Visible', 'off', 'InvertHardcopy', 'off');

    % Subplot 1: Pedestrian 3 km/h
    ax1 = subplot(1, 2, 1);
    apply_light_theme(ax1);
    hold(ax1, 'on');
    p1 = semilogy(ax1, snr, max(results.pedestrian_3kmph.bler_legacy, 1e-4), 'k-s', ...
        'LineWidth', 1.8, 'MarkerSize', 7, 'MarkerFaceColor', c_leg, 'MarkerEdgeColor', 'k');
    p2 = semilogy(ax1, snr, max(results.pedestrian_3kmph.bler_prop_epre, 1e-4), 'r-o', ...
        'Color', c_epre, 'LineWidth', 2.0, 'MarkerSize', 7, 'MarkerFaceColor', c_epre, 'MarkerEdgeColor', 'r');
    p3 = semilogy(ax1, snr, max(results.pedestrian_3kmph.bler_prop_energy, 1e-4), 'b--^', ...
        'Color', c_energy, 'LineWidth', 1.8, 'MarkerSize', 7, 'MarkerFaceColor', c_energy, 'MarkerEdgeColor', 'b');

    yline(ax1, 0.01, 'k:', '1% Target BLER', 'LineWidth', 1.2, 'FontSize', 9, ...
        'LabelHorizontalAlignment', 'left', 'Color', [0.3 0.3 0.3]);
    xlabel(ax1, 'SNR per RE (dB)', 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0.1 0.1 0.1]);
    ylabel(ax1, 'PBCH Block Error Rate (BLER)', 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0.1 0.1 0.1]);
    title(ax1, '(a) Pedestrian (3 km/h, f_d \approx 19.4 Hz)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0.1 0.1 0.1]);
    xlim(ax1, [min(snr), max(snr)]);
    ylim(ax1, [1e-3, 1]);
    set(ax1, 'YScale', 'log', 'YMinorGrid', 'on');
    lgd1 = legend(ax1, [p1, p2, p3], {'Legacy NR (4-Symbol)', ...
                                      'Proposed 5-Symbol (Equal EPRE, +0.97 dB)', ...
                                      'Proposed 5-Symbol (Equal Total Energy)'}, ...
           'Location', 'southwest', 'FontSize', 9.5, 'TextColor', [0.1 0.1 0.1], ...
           'Color', 'w', 'EdgeColor', [0.8 0.8 0.8]);

    % Subplot 2: Vehicular 120 km/h
    ax2 = subplot(1, 2, 2);
    apply_light_theme(ax2);
    hold(ax2, 'on');
    p1 = semilogy(ax2, snr, max(results.vehicular_120kmph.bler_legacy, 1e-4), 'k-s', ...
        'LineWidth', 1.8, 'MarkerSize', 7, 'MarkerFaceColor', c_leg, 'MarkerEdgeColor', 'k');
    p2 = semilogy(ax2, snr, max(results.vehicular_120kmph.bler_prop_epre, 1e-4), 'r-o', ...
        'Color', c_epre, 'LineWidth', 2.0, 'MarkerSize', 7, 'MarkerFaceColor', c_epre, 'MarkerEdgeColor', 'r');
    p3 = semilogy(ax2, snr, max(results.vehicular_120kmph.bler_prop_energy, 1e-4), 'b--^', ...
        'Color', c_energy, 'LineWidth', 1.8, 'MarkerSize', 7, 'MarkerFaceColor', c_energy, 'MarkerEdgeColor', 'b');

    yline(ax2, 0.01, 'k:', '1% Target BLER', 'LineWidth', 1.2, 'FontSize', 9, ...
        'LabelHorizontalAlignment', 'left', 'Color', [0.3 0.3 0.3]);
    xlabel(ax2, 'SNR per RE (dB)', 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0.1 0.1 0.1]);
    ylabel(ax2, 'PBCH Block Error Rate (BLER)', 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0.1 0.1 0.1]);
    title(ax2, '(b) Vehicular (120 km/h, f_d \approx 777.8 Hz)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0.1 0.1 0.1]);
    xlim(ax2, [min(snr), max(snr)]);
    ylim(ax2, [1e-3, 1]);
    set(ax2, 'YScale', 'log', 'YMinorGrid', 'on');
    lgd2 = legend(ax2, [p1, p2, p3], {'Legacy NR (4-Symbol)', ...
                                      'Proposed 5-Symbol (Equal EPRE, +0.97 dB)', ...
                                      'Proposed 5-Symbol (Equal Total Energy)'}, ...
           'Location', 'southwest', 'FontSize', 9.5, 'TextColor', [0.1 0.1 0.1], ...
           'Color', 'w', 'EdgeColor', [0.8 0.8 0.8]);

    sgtitle(sprintf('Figure 1: PBCH BLER Performance (7 GHz, TDL-C 100ns, %s, Polar K=56, N=512 | MC Trials: N = %d)', antStr, nTrials), ...
        'FontSize', 12.5, 'FontWeight', 'bold', 'Color', [0.1 0.1 0.1]);

    try
        exportgraphics(f1, 'figures/fig1_pbch_bler_extension.png', 'Resolution', 300, 'BackgroundColor', 'white');
    catch ME
        warning('Could not overwrite fig1 default name: %s', ME.message);
    end
    exportgraphics(f1, sprintf('figures/fig1_pbch_bler_extension_N%d.png', nTrials), 'Resolution', 300, 'BackgroundColor', 'white');
    savefig(f1, 'figures/fig1_pbch_bler_extension.fig');
    close(f1);
    fprintf('  Saved Figure 1 to figures/fig1_pbch_bler_extension_N%d.png\n', nTrials);

    %% ====================================================================
    % FIGURE 2: SSS MDR (3 km/h vs 120 km/h)
    %% ====================================================================
    f2 = figure('Name', 'Fig2: SSS MDR Comparison', 'Color', 'w', ...
        'Position', [100, 100, 1100, 500], 'Visible', 'off', 'InvertHardcopy', 'off');

    % Subplot 1: Pedestrian 3 km/h
    ax3 = subplot(1, 2, 1);
    apply_light_theme(ax3);
    hold(ax3, 'on');
    m1 = semilogy(ax3, snr, max(results.pedestrian_3kmph.mdr_legacy, 1e-4), 'k-s', ...
        'LineWidth', 1.8, 'MarkerSize', 7, 'MarkerFaceColor', c_leg, 'MarkerEdgeColor', 'k');
    m2 = semilogy(ax3, snr, max(results.pedestrian_3kmph.mdr_prop_nc, 1e-4), 'r-o', ...
        'Color', c_epre, 'LineWidth', 2.0, 'MarkerSize', 7, 'MarkerFaceColor', c_epre, 'MarkerEdgeColor', 'r');
    m3 = semilogy(ax3, snr, max(results.pedestrian_3kmph.mdr_prop_coh, 1e-4), 'g--^', ...
        'Color', c_coh, 'LineWidth', 1.8, 'MarkerSize', 7, 'MarkerFaceColor', c_coh, 'MarkerEdgeColor', 'g');

    yline(ax3, 0.01, 'k:', '1% Target MDR', 'LineWidth', 1.2, 'FontSize', 9, ...
        'LabelHorizontalAlignment', 'left', 'Color', [0.3 0.3 0.3]);
    xlabel(ax3, 'SNR per RE (dB)', 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0.1 0.1 0.1]);
    ylabel(ax3, 'SSS Missed Detection Rate (MDR)', 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0.1 0.1 0.1]);
    title(ax3, '(a) Pedestrian (3 km/h, f_d \approx 19.4 Hz)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0.1 0.1 0.1]);
    xlim(ax3, [min(snr), max(snr)]);
    ylim(ax3, [1e-3, 1]);
    set(ax3, 'YScale', 'log', 'YMinorGrid', 'on');
    legend(ax3, [m1, m2, m3], {'Legacy NR (Single SSS)', ...
                              'Proposed Dual SSS (Non-Coherent Combining)', ...
                              'Proposed Dual SSS (Coherent Combining)'}, ...
           'Location', 'southwest', 'FontSize', 9.5, 'TextColor', [0.1 0.1 0.1], ...
           'Color', 'w', 'EdgeColor', [0.8 0.8 0.8]);

    % Subplot 2: Vehicular 120 km/h
    ax4 = subplot(1, 2, 2);
    apply_light_theme(ax4);
    hold(ax4, 'on');
    m1 = semilogy(ax4, snr, max(results.vehicular_120kmph.mdr_legacy, 1e-4), 'k-s', ...
        'LineWidth', 1.8, 'MarkerSize', 7, 'MarkerFaceColor', c_leg, 'MarkerEdgeColor', 'k');
    m2 = semilogy(ax4, snr, max(results.vehicular_120kmph.mdr_prop_nc, 1e-4), 'r-o', ...
        'Color', c_epre, 'LineWidth', 2.0, 'MarkerSize', 7, 'MarkerFaceColor', c_epre, 'MarkerEdgeColor', 'r');
    m3 = semilogy(ax4, snr, max(results.vehicular_120kmph.mdr_prop_coh, 1e-4), 'g--^', ...
        'Color', c_coh, 'LineWidth', 1.8, 'MarkerSize', 7, 'MarkerFaceColor', c_coh, 'MarkerEdgeColor', 'g');

    yline(ax4, 0.01, 'k:', '1% Target MDR', 'LineWidth', 1.2, 'FontSize', 9, ...
        'LabelHorizontalAlignment', 'left', 'Color', [0.3 0.3 0.3]);
    xlabel(ax4, 'SNR per RE (dB)', 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0.1 0.1 0.1]);
    ylabel(ax4, 'SSS Missed Detection Rate (MDR)', 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0.1 0.1 0.1]);
    title(ax4, '(b) Vehicular (120 km/h, f_d \approx 777.8 Hz)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0.1 0.1 0.1]);
    xlim(ax4, [min(snr), max(snr)]);
    ylim(ax4, [1e-3, 1]);
    set(ax4, 'YScale', 'log', 'YMinorGrid', 'on');
    legend(ax4, [m1, m2, m3], {'Legacy NR (Single SSS)', ...
                              'Proposed Dual SSS (Non-Coherent Combining)', ...
                              'Proposed Dual SSS (Coherent Combining)'}, ...
           'Location', 'southwest', 'FontSize', 9.5, 'TextColor', [0.1 0.1 0.1], ...
           'Color', 'w', 'EdgeColor', [0.8 0.8 0.8]);

    sgtitle(sprintf('Figure 2: SSS Missed Detection Rate (7 GHz, TDL-C 100ns, %s, 1008 Cell-ID | MC Trials: N = %d)', antStr, nTrials), ...
        'FontSize', 12.5, 'FontWeight', 'bold', 'Color', [0.1 0.1 0.1]);

    try
        exportgraphics(f2, 'figures/fig2_sss_mdr_extension.png', 'Resolution', 300, 'BackgroundColor', 'white');
    catch ME
        warning('Could not overwrite fig2 default name: %s', ME.message);
    end
    exportgraphics(f2, sprintf('figures/fig2_sss_mdr_extension_N%d.png', nTrials), 'Resolution', 300, 'BackgroundColor', 'white');
    savefig(f2, 'figures/fig2_sss_mdr_extension.fig');
    close(f2);
    fprintf('  Saved Figure 2 to figures/fig2_sss_mdr_extension_N%d.png\n', nTrials);
end

% --- Helper to enforce crisp light theme on any axes ---
function apply_light_theme(ax)
    set(ax, 'Color', 'w', ...
            'XColor', [0.15 0.15 0.15], ...
            'YColor', [0.15 0.15 0.15], ...
            'GridColor', [0.75 0.75 0.75], ...
            'GridAlpha', 0.5, ...
            'MinorGridColor', [0.88 0.88 0.88], ...
            'MinorGridAlpha', 0.4, ...
            'Box', 'on');
    grid(ax, 'on');
end
