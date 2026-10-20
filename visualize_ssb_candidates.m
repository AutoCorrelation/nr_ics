% visualize_ssb_candidates.m
% 6GR SSB 특허 아이디어 분석 대시보드의 TOP 5 후보 시각화 스크립트
% 3GPP TS 38.211 5G NR 표준 SSB 규격 (4 symbols x 240 subcarriers) 엄격 적용

close all; clear; clc;

%% 1. mper-01: SSS 관측 범위와 delay support를 결합한 보완 DMRS 배치
figure('Name', 'mper-01: 최소 특이값 최적화 DMRS 배치', 'Position', [100, 100, 800, 600]);
grid1 = getStandardSSB();
% SSS 구간(57~183) 내의 심볼 1, 3 DMRS를 제거(PBCH Data로 전환)
dmrs_idx_sym1 = find(grid1(:, 2) == 4);
dmrs_idx_sym3 = find(grid1(:, 4) == 4);
idx_in_sss_1 = dmrs_idx_sym1(dmrs_idx_sym1 >= 57 & dmrs_idx_sym1 <= 183);
idx_in_sss_3 = dmrs_idx_sym3(dmrs_idx_sym3 >= 57 & dmrs_idx_sym3 <= 183);
grid1(idx_in_sss_1, 2) = 3; 
grid1(idx_in_sss_3, 4) = 3;
% SSS 여집합 구간(1~56, 193~240)의 기존 DMRS를 제거하고 최소 특이값 최적화 형태의 DMRS(5) 배치
opt_dmrs_idx = [1:6:48, 193:6:240]; % 최적화된 비균일 DMRS라고 가정
grid1(grid1(:, 2) == 4, 2) = 3; 
grid1(grid1(:, 4) == 4, 4) = 3; 
grid1(opt_dmrs_idx, 2) = 5; % 최적화 보완 DMRS
grid1(opt_dmrs_idx, 4) = 5;
drawGrid(grid1, 'mper-01: SSS 대역 DMRS 제거 및 여집합 최적화 보완 DMRS 배치');

%% 2. mper-13: PBCH의 검증된 부분 결정을 먼저 활용하는 channel refinement
figure('Name', 'mper-13: Sparse DMRS & Holdout DMRS', 'Position', [150, 150, 800, 600]);
grid2 = getStandardSSB();
% SSS 여집합 구간(가장자리)의 보완 DMRS를 Sparse / Holdout(검증용)으로 분할
dmrs_idx_out_1 = find(grid2(:, 2) == 4 & ( (1:240)' <= 48 | (1:240)' >= 193 ));
dmrs_idx_out_3 = find(grid2(:, 4) == 4 & ( (1:240)' <= 48 | (1:240)' >= 193 ));
grid2(dmrs_idx_out_1(1:2:end), 2) = 5; % Sparse DMRS
grid2(dmrs_idx_out_1(2:2:end), 2) = 6; % Holdout DMRS (검증용)
grid2(dmrs_idx_out_3(1:2:end), 4) = 5; % Sparse DMRS
grid2(dmrs_idx_out_3(2:2:end), 4) = 6; % Holdout DMRS (검증용)
drawGrid(grid2, 'mper-13: 가장자리 구간 Sparse DMRS 및 Holdout(검증) DMRS 분할 전송');

%% 3. sca-02: SSS 관측을 다음 심볼의 보완 DMRS로 연결하는 교차 궤적
figure('Name', 'sca-02: SSS 회전-DMRS 교차 궤적', 'Position', [200, 200, 800, 600]);
grid3 = getStandardSSB();
% 심볼 1의 SSS 대역을 1/3 밀도의 SSS Comb-3 (offset 0)로 변경
grid3(57:183, 2) = 3; 
grid3(57:3:183, 2) = 2; % SSS Comb-3
% 심볼 2의 기존 SSS 대역을 SSS Comb-3 (offset 1)로 변경하고, offset 0 자리에 DMRS 삽입
grid3(57:183, 3) = 3; 
grid3(58:3:183, 3) = 2; % SSS 회전 (offset 1)
grid3(57:3:183, 3) = 4; % 이전 심볼 SSS 위치에 DMRS 교차 배치
drawGrid(grid3, 'sca-02: 심볼 간 SSS Comb 오프셋 순환 및 빈자리 DMRS 교차 궤적');

%% 4. sca-11: 추정 오차 상관을 분산시키는 PBCH rate matching
figure('Name', 'sca-11: Error Group 분할 및 교차 매핑', 'Position', [250, 250, 800, 600]);
grid4 = grid1; % 중앙 DMRS가 제거된 mper-01 상황 가정
pbch_idx_1 = find(grid4(:, 2) == 3);
pbch_idx_3 = find(grid4(:, 4) == 3);
% PBCH Data RE를 두 개의 Error Group으로 분할
grid4(pbch_idx_1(1:2:end), 2) = 7; % Error Group 1
grid4(pbch_idx_1(2:2:end), 2) = 8; % Error Group 2
% 다음 심볼에서는 반대로 교차 매핑
grid4(pbch_idx_3(1:2:end), 4) = 8; % Error Group 2
grid4(pbch_idx_3(2:2:end), 4) = 7; % Error Group 1
drawGrid(grid4, 'sca-11: 오차 분산을 위한 PBCH Data Error Group 교차 매핑');

%% 5. sca-07: 독립 DMRS 검증을 통과한 경우에만 SSS 추정을 채택
figure('Name', 'sca-07: 기존 Grid + 3-Fold Holdout DMRS', 'Position', [300, 300, 800, 600]);
grid5 = getStandardSSB();
% 기존 Grid를 100% 유지하면서 수신기 내부적으로 DMRS의 1/3을 Validation용으로 분리
all_dmrs = find(grid5 == 4);
validation_idx = all_dmrs(1:3:end);
grid5(validation_idx) = 6; % Validation(Holdout) DMRS로 표기
drawGrid(grid5, 'sca-07: 표준 매핑 유지 + 수신기 내부 Validation DMRS 분리 검증');


%% Helper 1: 3GPP TS 38.211 표준 기반 5G NR SSB Grid 생성
function grid = getStandardSSB()
    % 240 서브캐리어 x 4 심볼
    grid = zeros(240, 4); 
    
    v = 0; % PBCH DMRS 주파수 편이 (v = PCI mod 4, 여기서는 편의상 0으로 가정)
    
    % Symbol 0 (1열): PSS
    % 표준: Subcarrier 56 ~ 182 (1-based: 57 ~ 183)
    grid(57:183, 1) = 1; 
    
    % Symbol 1 (2열): PBCH 및 DMRS
    grid(:, 2) = 3; % PBCH Data
    grid(v+1:4:240, 2) = 4; % PBCH DMRS (4간격)
    
    % Symbol 2 (3열): SSS 및 가장자리 PBCH/DMRS
    % 표준 SSS: Subcarrier 56 ~ 182 (1-based: 57 ~ 183)
    grid(57:183, 3) = 2; % SSS
    
    % 표준 가장자리 PBCH: Subcarrier 0~47, 192~239 (1-based: 1~48, 193~240)
    % 주의: Subcarrier 48~55 및 183~191은 Reserved(Empty = 0)로 둠
    grid(1:48, 3) = 3; 
    grid(193:240, 3) = 3; 
    grid(v+1:4:48, 3) = 4; % DMRS
    grid(v+193:4:240, 3) = 4; % DMRS
    
    % Symbol 3 (4열): PBCH 및 DMRS
    grid(:, 4) = 3; % PBCH Data
    grid(v+1:4:240, 4) = 4; % PBCH DMRS (4간격)
end

%% Helper 2: Grid 시각화 함수
function drawGrid(gridData, titleStr)
    imagesc(gridData);
    
    % Colormap 설정
    cmap = [
        1.0 1.0 1.0; % 0: Empty/Reserved (White)
        0.2 0.6 1.0; % 1: PSS (Blue)
        0.1 0.8 0.3; % 2: SSS (Green)
        0.8 0.8 0.8; % 3: PBCH Data (Gray)
        1.0 0.2 0.2; % 4: PBCH DMRS (Red)
        1.0 0.6 0.2; % 5: Sparse / Optimized DMRS (Orange)
        0.6 0.2 0.8; % 6: Validation / Holdout DMRS (Purple)
        0.9 0.9 0.2; % 7: PBCH Error Grp 1 (Yellow)
        0.2 0.9 0.9; % 8: PBCH Error Grp 2 (Cyan)
    ];
    
    colormap(cmap(1:max(gridData(:))+1, :));
    
    % 축 설정 (주파수 축이 위로 갈수록 증가하도록 YDir normal 설정)
    set(gca, 'XTick', 1:4, 'XTickLabel', {'Sym 0', 'Sym 1', 'Sym 2', 'Sym 3'}, 'YDir', 'normal');
    ylabel('Subcarrier Index (0-239)');
    title(titleStr, 'Interpreter', 'none', 'FontWeight', 'bold', 'FontSize', 12);
    
    % SSS 대역폭 경계선 점선 표시 (가독성 향상)
    hold on;
    yline(56.5, 'k--', 'LineWidth', 1, 'Alpha', 0.5);
    yline(183.5, 'k--', 'LineWidth', 1, 'Alpha', 0.5);
    hold off;
    
    % 범례 추가
    labels = {'PSS', 'SSS', 'PBCH', 'PBCH DMRS', 'Sparse/Opt DMRS', 'Validation DMRS', 'Error Grp 1', 'Error Grp 2'};
    colors = cmap(2:end, :);
    L = gobjects(0);
    hold on;
    for i = 1:length(labels)
        L(i) = plot(nan, nan, 's', 'MarkerFaceColor', colors(i,:), 'MarkerEdgeColor', 'k', 'MarkerSize', 8);
    end
    hold off;
    
    uniqueVals = unique(gridData(:));
    validIdx = uniqueVals(uniqueVals > 0);
    legend(L(validIdx), labels(validIdx), 'Location', 'northeastoutside');
end
