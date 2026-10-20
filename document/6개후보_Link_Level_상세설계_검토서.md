# SSS·PBCH 6개 후보: Link-level simulation 상세 설계 검토서

작성일: 2026-09-30 · 문서 버전: Review 1.0 · 구현 코드 없이 설계·실험 규칙을 정의합니다.

## 1. 문서 목적과 검토 순서

이 문서는 D1·D2·D3와 첨부 제안서의 Design I·II·III를 각각 G1·G2·G3로 구분합니다. 각 후보가 해결하려는 문제, 송신 resource grid, UE가 단계별로 확보하는 정보, 채널 추정·복호 규칙, 실패 처리, 대조군을 명시합니다. 아래 수치는 구현을 시작하기 위한 **연구용 설정값**이며 성능 결과나 표준 합의값이 아닙니다.

먼저 공통 실험 규칙을 읽고 각 후보의 문제와 필수 구성요소를 검토합니다. 이후 해당 후보의 송수신 절차와 반례를 확인합니다. G 후보는 원안 O와 보완안 R을 반드시 구분합니다. 보완안에서 얻은 결과로 원안의 타당성을 주장할 수 없습니다.

| 후보 | 문제 | 핵심 해결 원리 | 우선 구현할 profile | 원안과의 관계 |
|---|---|---|---|---|
| D1 | 잘못된 PCI 또는 부적합한 SSS 관측이 joint CE를 악화시킵니다. | fitting에 사용하지 않은 DMRS로 SSS 활용 모델을 검증합니다. | D1 | 기존 원리를 유지하며 erasure·ranking 규칙을 구체화합니다. |
| D2 | PBCH의 시간 외삽과 reference 간 일관성 문제가 생깁니다. | 상보 endpoint SSS와 동일-k DMRS로 중앙 보간을 검증합니다. | D2 | 기존 원리를 유지하며 중앙 symbol의 실패 처리를 명확히 합니다. |
| D3 | 반복 coded bit가 공통 CE 오차에 함께 노출됩니다. | reference 영향 집합을 고려해 반복 관측을 분리합니다. | D3 | 기존 432-entry permutation을 그대로 사용합니다. |
| G1 | SSS가 한 symbol에 집중되면 시간 추적이 제한됩니다. | staggered SSS와 별도 tracking reference를 사용합니다. | G1-R 및 동일 자원 G1-M | 원안의 자원 충돌과 chip 수를 수정합니다. |
| G2 | 단일 Tx의 fading 취약성을 줄이려 합니다. | port별 채널 추정과 SFBC를 연결합니다. | G2-O 진단 및 G2-R | R은 직교 sequence 대신 FDM을 사용하므로 발명 구성도 달라집니다. |
| G3 | 반복 시점마다 변하는 정보가 PBCH 누적을 어렵게 합니다. | 동적 timing과 정적 payload를 분리합니다. | G3-O 진단 및 G3-R | R은 SSS 위상변조를 별도 header로 대체하므로 발명 구성도 달라집니다. |

**초기 연구 범위와의 관계:** D1–D3는 Gold 생성·초기화·PCI 연결과 PBCH payload/coding을 유지합니다. G1-R과 G2-R은 동일 Gold codebook의 일부 chip만 사용하는 자원 배분 variant입니다. G2-O와 G3-O는 SSS 변조 또는 sequence 쌍을 바꾸므로 초기의 sequence 변경 제외 조건을 벗어납니다. G3-R도 payload와 coding architecture를 바꾸므로 별도 확장 과제로 평가합니다.

## 2. 공통 실험 규칙

### 2.1 연구용 waveform과 좌표

| 항목 | 주 실험의 고정 규칙 |
|---|---|
| 목표 | 이전 PBCH·SIB 설정이 없는 최초 Initial Access입니다. |
| carrier / SCS | 7 GHz / 30 kHz입니다. 확정된 6GR profile을 뜻하지 않습니다. |
| 시간·주파수 | 240 subcarriers, OFDM symbols l=0,1,2,3을 사용합니다. k=0–239입니다. |
| FFT / sample rate | NFFT=512, Fs=15.36 MHz입니다. FFT bin offset은 k−120으로 고정합니다. DC를 포함하는 연구용 grid이며 DC 추가 puncturing은 하지 않습니다. |
| CP | slot 시작의 NR normal CP를 적용합니다. 해당 numerology·FFT의 OFDM 정보를 사용하고 실제 CP 배열과 symbol 길이를 로그에 기록합니다. |
| 평가 영역 | l=1–3의 720 RE입니다. l=0은 공통 PSS입니다. |
| PSS | 동일한 127-chip 기준 PSS를 l=0, k=56–182에 놓습니다. 나머지 l=0 RE는 null입니다. G2도 PSS는 port 0만 사용합니다. |
| symbol 시간 | t_l은 CP를 제외한 useful symbol의 중심 시각입니다. 시간 보간에는 실제 sample 위치로 계산한 t_l을 사용합니다. |
| 정렬 | RE 목록은 l 오름차순, 같은 l에서 k 오름차순입니다. 모든 문서 index는 0-based입니다. |
| Tx / Rx | 기본 1Tx·1Rx입니다. G2만 2Tx이며 1Rx와 4Rx를 각각 비교합니다. 다른 후보도 4Rx 대조군을 함께 평가합니다. |
| profile 인지 | UE는 현재 시험의 공개된 고정 profile을 압니다. 여섯 profile을 blind detection하는 비용은 포함하지 않습니다. |

모든 time-domain 시험은 동일 OFDM scaling을 사용합니다. channel filter delay에 필요한 zero tail을 추가하고, receiver timing error와 channel 구현의 고정 group delay를 구분합니다. FFT window와 oracle channel의 기준 시점도 일치시킵니다. CP와 OFDM 길이를 구하는 기준은 [MathWorks nrOFDMInfo](https://www.mathworks.com/help/5g/ref/nrofdminfo.html)입니다.

주 실험은 rectangular OFDM이며 추가 windowing·overlap은 0입니다. RF carrier의 공통 symbol phase compensation은 송수신에서 일치시킵니다. 발진기 impairment는 보상 후 waveform에 별도로 주입합니다. channel과 impairment가 없는 상태에서 송신 grid와 복조 grid가 복원되는지를 먼저 확인합니다.

### 2.2 변경하지 않을 sequence와 기준 데이터

SSS는 작업 폴더의 **local baseline Gold codebook G[PCI,n]**을 사용합니다. PCI=0–1007, n=0–239, chip 값은 ±1입니다. 특정 회사 제안과 동일하다고 주장하지 않습니다. 본 문서에서 새 polynomial이나 초기화 규칙을 설계하지 않습니다.

기준 파일은 `six_candidate_lls_20260929/config/gold240.npy`와 `gold240.csv`입니다. 배열을 int8 C row-major raw bytes로 읽었을 때 SHA256은 `ba14e6b00f695dd1a0f95f07f47039e40be53ca2ab9cdf021128002c1ca07c54`입니다. CSV 자체의 파일 hash와 혼동하지 않습니다. sequence의 생성 방법보다 이 고정 배열이 이번 비교의 실행 기준입니다.

DMRS는 기준 PBCH DMRS generator의 PCI와 q 입력을 그대로 사용하고, 출력의 앞 N_R개 QPSK symbols를 해당 profile의 R 위치에 순서대로 놓습니다. q는 0–7인 미지의 연구용 SSB index입니다. G3-R만 header 이전의 순환 의존성을 피하도록 DMRS의 q 입력을 0으로 고정합니다. G1-R의 N_R=12, D1–D3·G1-M·G3-R의 N_R=48입니다. [PBCH DMRS 기준](https://www.mathworks.com/help/5g/ref/nrpbchdmrs.html)

### 2.3 bit 처리·coding·scrambling

| block | payload A | CRC | K=A+CRC | mother N | rate-matched E |
|---|---:|---:|---:|---:|---:|
| D1/D2/D3/G1-M | 32 | 24C | 56 | 512 | 864 |
| G1-R | 32 | 24C | 56 | 512 | 1056 |
| G2-R | 32 | 24C | 56 | 512 | 1080 |
| G3-O static | 48 | 24C | 72 | 512 | 960 |
| G3-R header | 21 | 24C | 45 | 128 | 128 |
| G3-R static | 48 | 24C | 72 | 512 | 736 |

payload는 별도 명시한 G3 필드 외에는 synthetic bits입니다. 실제 NR MIB의 전체 의미와 payload scrambling 절차를 재현한다고 주장하지 않습니다. K=56은 CRC를 포함한 길이이며 56-bit payload를 뜻하지 않습니다.

처리 순서는 payload, CRC-24C, Polar input interleaving, Polar encoding, sub-block interleaving·rate matching, coded-bit scrambling, QPSK modulation, 물리 RE mapping입니다. DL coded-bit interleaving은 끕니다. decoder는 CRC-aided SCL, list size 8을 기본으로 하고 모든 같은-K 비교에 동일 implementation을 사용합니다. Polar 구성은 NR DL 규칙을 기준으로 동결하고 실제 N과 information set을 저장합니다. 특히 E나 K가 달라지면 같은 mother code라고 추정하지 말고 확인합니다. [Polar encoding 기준](https://www.mathworks.com/help/5g/ref/nrpolarencode.html)

sub-block interleaving 이후 mother 좌표를 u_sb라 하면 E>N인 주 profile에서 e[j]=u_sb[j mod N]입니다. D3의 반복 관계는 이 좌표를 사용합니다. 다른 coded-bit interleaver를 켜면 D3 표를 그대로 사용할 수 없습니다.

coded-bit scrambling은 기준 PBCH PRBS를 PCI, phase v, 길이 E로 생성합니다. D1–D3·G1·G2는 v=q, G3-O의 static과 G3-R의 두 block은 v=0입니다. G3에서 v=0은 동적 q를 모르는 상황에서도 복호를 시작하게 하는 연구용 변경입니다. 기준 API의 v는 0–7이며 q와의 연결을 명시해야 합니다. [PBCH PRBS 기준](https://www.mathworks.com/help/5g/ref/nrpbchprbs.html)

unit-energy QPSK는 s(b₀,b₁)=[(1−2b₀)+j(1−2b₁)]/√2로 고정합니다. LLR는 log[P(bit=0)/P(bit=1)]이며 양수가 0을 지지합니다. 수신 순서는 물리 LLR, inverse mapping, 논리 index에 맞춘 descrambling, rate recovery, Polar decoding, CRC입니다.

### 2.4 자원·전력 예산

| profile | SSS RE | R RE | header RE | PBCH/static RE | 합계 | 비고 |
|---|---:|---:|---:|---:|---:|---|
| D1/D2/D3 | 240 | 48 | 0 | 432 | 720 | 동일 자원 주 비교입니다. |
| G1-R | 180 | 12 | 0 | 528 | 720 | R은 tracking DMRS입니다. |
| G1-M | 240 | 48 | 0 | 432 | 720 | G1의 동일 자원 비교안입니다. |
| G2-R | 180 | 0 | 0 | 540 | 720 | SSS 위치는 두 port 중 하나만 사용합니다. |
| G3-O 진단 | 240 | 0 | 0 | 480 | 720 | 위상변조된 SSS를 사용합니다. |
| G3-R | 240 | 48 | 64 | 368 | 720 | 두 독립 codeword를 사용합니다. |

기본 전력은 **모든 Tx port를 합친 active RE당 EPRE=1**입니다. l=1–3의 총 grid energy는 720, 공통 PSS energy는 127입니다. G2의 data는 port마다 진폭 1/√2이고, FDM SSS는 활성 port에 진폭 1입니다. Rx 개수가 늘어나도 noise variance를 나누지 않습니다.

SNR_RE=10 log₁₀(1/N₀)이며 N₀는 Rx별 복소 noise variance입니다. fading 이후 순간 수신 전력을 기준으로 noise를 정규화하지 않습니다. time-domain noise는 실제 FFT scaling에 맞춰 생성합니다. 전력 boosting을 적용하면 총 energy 720을 다시 맞춥니다. CP를 포함한 waveform energy도 별도로 기록하여 RE energy와 혼용하지 않습니다.

실용 noise 추정은 l=0의 null tones k=0–31 및 208–239에서 Rx별 median(|Y|²)/ln2를 사용합니다. 10⁻⁸ floor를 적용합니다. CFO leakage·인접 간섭에 의한 편향은 평가 항목입니다. 정답 N₀를 사용하는 경우 oracle로 구분합니다.

### 2.5 수신기가 언제 어떤 정보를 아는가

| 단계 | 사용 가능한 정보 | 아직 알려지지 않은 정보 |
|---|---|---|
| 수신 전 | numerology, profile, Gold 배열, RE 위치, coding 규칙을 압니다. | PCI, q, timing, CFO, channel, payload를 모릅니다. |
| PSS 이후 | timing·CFO·NID2 후보를 얻습니다. | 후보가 정답인지는 모릅니다. |
| SSS 이후 | PCI 후보 최대 3개와 후보별 score를 얻습니다. | q와 payload는 모릅니다. |
| reference 검증 이후 | 후보별 CE, uncertainty, q score 또는 q 미식별 상태를 얻습니다. | CRC 이전에는 payload를 모릅니다. |
| G3-R header 이후 | CRC를 통과한 SFN·q·epoch 후보를 얻습니다. | static core와 header의 실제 정답 여부는 아직 보장되지 않습니다. |
| 최종 판정 | 유일한 일관된 CRC 결과를 수락합니다. | 정답 대조는 receiver가 아니라 평가기가 수행합니다. |

G2의 SSS는 q를 전달하지 않으므로 q를 복호 전 확정할 수 없습니다. G3-O는 m을 알아야 SSS 위상을 제거해 CE를 할 수 있는데, m 검출도 channel에 영향을 받습니다. 이 순환 의존성 자체가 진단할 문제입니다.

### 2.6 공통 acquisition 시작 규칙

처음에는 PSS부터 전체 수신기를 붙인 시험과, PSS 이후의 SSS·PBCH만 평가하는 시험을 분리합니다. 후자를 full Initial Access 결과로 표시하지 않습니다.

전체 시험에서는 3개 NID2, timing offset 0–127 samples, 초기 CFO 후보 {−0.25,0,+0.25} SCS를 search합니다. CP correlation으로 fractional CFO를 추정합니다. ±5 ppm 확장 시험에서는 7 GHz의 CFO 범위를 덮도록 −2–+2 SCS, 간격 0.25 SCS로 search합니다. 선택한 PSS peak와 NID2는 하나이며 그 선택 실패도 결과에 포함합니다. search window 전체의 false alarm을 calibration합니다.

PSS metric은 후보 CFO로 보정한 각 Rx waveform과 해당 NID2의 CP 포함 PSS template 사이의 normalized squared correlation을 Rx별로 더한 값입니다. 분모는 template energy와 해당 수신 window energy의 곱이며 10⁻⁸ floor를 둡니다. 최대 metric의 timing·NID2·CFO를 선택합니다. CP refinement는 선택한 첫 symbol CP의 뒤 절반에서 C=Σ conj(y[n])y[n+NFFT]를 계산하고, 잔여 CFO를 arg(C)/(2πNFFT/Fs)로 구합니다. 이 값은 ±0.5 SCS의 모호성을 가지므로 초기 CFO grid 후보 주변의 잔여 보정으로만 사용합니다.

PSS 이후 residual CFO 후보는 추정치 중심 {−0.05,0,+0.05} SCS입니다. 각 후보는 raw samples에 적용한 뒤 FFT를 다시 수행합니다. CPE 회전만으로 ICI를 제거했다고 처리하지 않습니다.

SSS screening은 symbol별, 20-tone 구간별, G2-R에서는 port별로 나눈 그룹에서 수행합니다. 각 그룹의 상관 에너지를 더합니다. 그룹 g에서의 score 항은 |Σ G*[n(p)]Y[p,r]|²/(|g|N̂₀,r)입니다. 작은 그룹의 channel이 완만하다는 근사이며 10·20·40-tone 민감도를 확인합니다. 추정 NID2와 일치하는 336개 PCI를 평가하여 상위 3개를 남깁니다. 동점은 PCI 오름차순으로 정합니다.

D1/D2/D3/G1은 PCI 3개 × q 8개 × CFO 3개, 최대 72개 가설을 reference로 평가하고 상위 4개에만 Polar decoding을 적용합니다. G2-R과 G3의 추가 복호 비용은 각각의 절에 따로 정의합니다. 부분 구간을 버린 후보의 score는 유효 구간 normalized residual 평균에 6×erasure 구간 비율을 더합니다. 유효 구간이 하나도 없으면 폐기합니다.

### 2.7 공통 추정·검증·LLR 규칙

reference p의 실제 송신값을 X_p라 하면 Z_p=Y_p/X_p입니다. WLS는 |X_p|²/N̂₀를 weight로 사용합니다. affine 모델은 H(k,l)=a+b x+c t이며, 60-tone 구간 b에서 x=[k−(60b+29.5)]/30, t=(t_l−t₂)/(t₃−t₁)입니다. rank가 부족하거나 condition number가 10⁸을 넘으면 invalid로 처리합니다. slope 항의 ridge는 10⁻⁶×trace(AᴴWA)/모델 차원이며 intercept는 penalty에서 제외합니다.

validation은 fitting, 가설별 CFO refinement, phase fitting에서 제외합니다. 최종 refit 이후에도 기존 out-of-fold residual을 유지합니다. 실험 시작값은 normalized residual threshold T_abs=6, 모델 개선 margin δ=0.10입니다. 성능 시험 전에 §10의 calibration으로 동결하며 SNR별 정답을 사용해 조정하지 않습니다.

data RE의 scalar SIMO demapping metric은 D(s)=Σ_r |Y_r−√E_B Ĥ_r s|²/V_r입니다. V_r=max(N̂₀,r+E_B v_r,10⁻⁸)이고 v_r은 receiver가 추정한 CE uncertainty입니다. bit LLR는 bit=1 집합의 최소 D에서 bit=0 집합의 최소 D를 뺍니다. ±50으로 clipping합니다. erasure RE는 LLR=0입니다. 후보에서 uncertainty를 추가하지 않는 대조군은 v=0으로 명시합니다.

## 3. D1: 검증 DMRS에 기반한 SSS 활용 모델 선택

### 3.1 해결하려는 문제와 가설

SSS를 CE에 추가하면 reference 수가 늘지만, 잘못된 PCI·국소 SSS 간섭·channel aging 때문에 오히려 잘못된 추정을 강화할 수 있습니다. 예를 들어 60개 SSS와 12개 DMRS를 함께 fitting할 때 오염된 SSS가 모델을 지배할 수 있습니다. D1은 **SSS를 사용한 추정이 별도 관측에서도 더 정확한지 확인한 뒤 사용**합니다.

검증할 가설은 추가 reference의 수보다 모델 적합성이 중요하다는 것입니다. 이 가설이 맞으면 깨끗한 구간에서는 SSS를 활용하고, 오염된 구간에서는 DMRS-only로 복귀하는 수신기가 always-joint 수신기보다 전체 실패율을 줄일 수 있습니다. 이득을 전제하지 않습니다.

### 3.2 송신 grid

k=10m+r, m=0–23, r=0–9로 둡니다.

| symbol | SSS 위치 | DMRS 위치 | data 위치 |
|---|---|---|---|
| l=1 | 없습니다. | r=5입니다. | r≠5입니다. |
| l=2 | 모든 k입니다. | 없습니다. | 없습니다. |
| l=3 | 없습니다. | r=5입니다. | r≠5입니다. |

SSS는 G[0–239], DMRS는 d[0–47]를 각각 정렬된 RE에 놓습니다. data 432 RE는 identity mapping입니다. D1과 모든 D1 receiver 대조군에 **동일 송신 waveform**을 입력합니다.

### 3.3 모델과 validation 집합

주파수를 60-tone 네 구간으로 나눕니다. 한 구간에는 l=1과 l=3의 DMRS가 각각 6개 있습니다. local tile j=0–5에서 j mod3=f인 DMRS를 fold f의 validation으로 사용합니다. 매 fold는 validation 4 RE와 fitting 8 RE로 구성됩니다.

M0는 각 endpoint symbol의 fitting DMRS LS값을 complex linear frequency interpolation합니다. 양끝 밖은 가장 가까운 두 pilot로 선형 외삽합니다. M1은 해당 구간의 SSS 60개와 fitting DMRS 8개로 공통 affine 모델을 WLS fitting합니다. Rx별로 독립적인 모델을 만듭니다.

각 모델의 J_b는 3-fold의 validation RE와 Rx에서 |Y−XĤ|²를 평균한 값입니다. unit EPRE에서 J_b/N̂₀,mean을 normalized residual로 사용합니다.

### 3.4 수신 절차와 실패 처리

1. 공통 PSS·SSS screening으로 PCI·CFO 후보를 얻습니다.
2. 각 PCI·q·CFO 가설에서 DMRS 값을 생성하고 네 구간의 M0·M1 out-of-fold residual을 계산합니다.
3. J₁<(1−δ)J₀이고 J₁/N̂₀,mean≤T_abs이면 M1을 선택합니다. 그렇지 않고 M0가 절대 threshold를 통과하면 M0를 선택합니다. 동점은 M0입니다.
4. 둘 다 실패한 구간의 data는 erasure로 처리합니다. 모든 구간이 실패하면 해당 가설을 폐기합니다.
5. 상위 4개 가설에서 선택한 모델을 전체 reference로 다시 fitting합니다. M0는 전체 DMRS, M1은 전체 SSS·DMRS를 사용합니다.
6. v_b=max(0,J_selected−N̂₀,mean)를 unit EPRE의 uncertainty proxy로 사용하고, QPSK LLR부터 CRC까지 공통 절차를 수행합니다. reference power를 바꾸면 residual을 reference energy로 먼저 정규화합니다.
7. 서로 다른 PCI·q·payload가 둘 이상 CRC를 통과하면 ambiguous failure로 처리합니다. 최종 수락에는 적어도 하나의 유효 reference 구간이 필요합니다.

### 3.5 기록·대조군·반례

필수 기록은 구간별 J₀·J₁, 선택 모델, erasure 비율, 정답 PCI의 후보 잔존 여부, q ranking, CE NMSE, decoding 횟수입니다. SSS 기반 RSRP는 선택된 좋은 구간만으로 계산하지 않고 원래 전체 SSS 집합에서 별도로 측정합니다.

대조군은 DMRS-only, always-joint M1, D1, D1에서 uncertainty 제거, D1에서 fallback 제거입니다. validation을 training residual로 대체하는 실험은 data leakage의 영향을 보여 주는 진단이며 정당한 검증 수신기로 분류하지 않습니다.

주요 반례는 낮은 SNR의 작은 validation 표본, fitting·validation을 동시에 오염시키는 간섭, 긴 delay spread에 부적합한 affine 모델입니다. threshold를 강화해 잘못된 후보뿐 아니라 정답 후보까지 제거하는지 확인합니다.

**검토할 필수 구성:** 미사용 DMRS의 예측 비교, SSS 포함·제외 모델 선택, fallback·erasure, uncertainty 전달입니다. 단순 joint CE나 LLR scaling만을 독립적인 차별점으로 삼지 않습니다.

## 4. D2: 상보 endpoint SSS와 동일-k DMRS

### 4.1 해결하려는 문제와 가설

SSS가 한 시점에 집중되면 다른 symbol의 PBCH를 추정할 때 시간 외삽이나 고정 채널 근사가 필요합니다. D2는 PBCH 중앙 symbol의 앞뒤에 reference를 배치하여 보간할 수 있게 하고, 서로 연결되는 reference 관측으로 **그 보간을 적용해도 되는지** 확인합니다.

동일 subcarrier에 놓인 SSS와 DMRS는 같은 sequence도 같은 channel 값도 아닙니다. 각 후보의 송신값을 제거한 뒤 시간 변화 모델이 관측을 설명하는지 평가합니다.

### 4.2 송신 grid와 chip 순서

| symbol | SSS 위치 | DMRS 위치 | data 위치 |
|---|---|---|---|
| l=1 | r=0–4입니다. | r=7입니다. | 나머지입니다. |
| l=2 | 없습니다. | 없습니다. | 모든 k입니다. |
| l=3 | r=5–9입니다. | r=2입니다. | 나머지입니다. |

l=1의 정렬된 SSS에 G[0–119], l=3에는 G[120–239]를 놓습니다. 동일 Gold chip을 반복하지 않습니다. 정렬된 DMRS에 d[0–47]를 놓습니다. S=240, R=48, B=432, E=864를 유지합니다.

각 tile에서 l=1,r=2의 SSS와 l=3,r=2의 DMRS가 연결되고, l=1,r=7의 DMRS와 l=3,r=7의 SSS가 연결됩니다. 전체 48개의 연결입니다.

### 4.3 q 검증과 endpoint 추정

PCI screening은 두 endpoint의 작은 주파수 그룹별 상관 에너지를 더합니다. q·CFO 가설별 검증에서는 D1과 같은 60-tone 구간과 tile modulo-3 DMRS fold를 사용합니다. 해당 구간의 양 endpoint SSS 60개와 fitting DMRS 8개로 affine H(k,l)를 fitting하고, 미사용 DMRS 4개를 예측합니다. 양 endpoint가 관측되어 있으므로 시간 계수를 추정할 수 있지만, 그 모델이 임의의 채널 변화를 설명한다고 가정하지 않습니다.

q 가설은 3-fold normalized bridge residual로 평가합니다. q를 결정하기 전에 DMRS를 모두 사용하여 임의의 채널을 fitting한 후 동일 DMRS에서 q를 검증하지 않습니다. 상위 4개 후보를 유지합니다.

최종 CE는 각 endpoint의 **해당 symbol** SSS·DMRS를 사용한 complex linear frequency interpolation입니다. 양끝은 가까운 두 reference로 선형 외삽합니다. endpoint별 uncertainty는 정렬된 SSS의 modulo-3 holdout interpolation residual에서 noise를 제거한 값으로 구합니다. 이때 DMRS는 training에 포함할 수 있지만 validation SSS는 제외합니다.

### 4.4 중앙 PBCH의 보간과 erasure

α=(t₂−t₁)/(t₃−t₁)로 정의하고, bridge 검증을 통과한 구간에서 Ĥ₂(k)=(1−α)Ĥ₁(k)+αĤ₃(k)를 사용합니다. 실제 CP를 포함한 시각을 사용하며 항상 α=1/2라고 하드코딩하지 않습니다.

v₂의 시작 proxy는 [(1−α)√v₁+α√v₃]²+v_bridge로 둡니다. 이는 endpoint 오차의 독립성을 가정한 단순 제곱합보다 상관에 보수적인 설계이지만, v₁·v₃·v_bridge 자체가 추정치이므로 실제 오차의 보장된 상한은 아닙니다. 기존 9월 29일 문서의 독립형 가중 제곱합은 민감도 대조군으로 분리합니다.

bridge 검증이 실패한 구간은 **l=2 data LLR를 0으로 처리**합니다. 중앙에는 reference가 없으므로 symbol별 CE fallback만으로 중앙 data를 복구할 수 없습니다. endpoint data는 해당 endpoint의 SSS validation을 통과한 경우에만 유지합니다. 전체 data가 erasure이면 가설을 폐기합니다.

### 4.5 대조군·구현 비용·반례

MF와 MT의 동일 자원 비교, MT의 bridge gate 제거, MT의 시간 결합 제거를 수행합니다. 시간 결합 제거 대조군은 q를 endpoint별 SSS 기반 예측으로 평가하고 중앙 data는 erasure로 둡니다. 이 결과는 중앙 복구 기능 전체의 비용·효과를 측정하므로 순수 gate 효과와 구분합니다.

**기하학적 ablation의 주의점:** 현재 MT의 두 SSS 집합은 상보적입니다. endpoint에서 SSS가 아닌 위치로 DMRS를 옮기기만 해도 반대 endpoint에는 SSS가 존재합니다. 따라서 DMRS만 이동하여 ‘같은-k 연결을 제거했다’고 주장할 수 없습니다. 연결 자체를 없애려면 SSS 집합도 변경해야 하고, 이때 주파수 coverage까지 달라진다는 점을 기록해야 합니다.

최소 세 symbol을 buffering해야 하며, split SSS 검출 손실, 마지막 endpoint 대기, 빠른 Doppler의 시간 비상관, beam/port 변화가 주요 비용과 반례입니다. 결과는 conditional PBCH BLER뿐 아니라 PCI miss와 중앙 erasure 비율을 포함해야 합니다.

**검토할 필수 구성:** 상보 Gold 배치, 동일-k 연결, 제한된 q 모델 검증, 검증 결과에 따른 중앙 보간 허용·제한입니다.

## 5. D3: 반복 bit의 reference 영향 영역 분산

### 5.1 해결하려는 문제와 가설

같은 mother bit의 반복 관측이 같은 reference 오류나 보간 오차에 지배되면 LLR를 더해도 독립 관측에서 기대하는 효과를 얻기 어렵습니다. D3는 반복 횟수와 coding을 유지하면서 **반복 관측이 공유하는 CE 오차를 줄이는 mapping**을 찾습니다.

### 5.2 송신 구조와 반복 bit 관계

grid는 D1의 MF, data RE 수는 432입니다. QPSK a[n]은 scrambling된 bit 2n과 2n+1을 담습니다. E=864, N=512, 고정 sub-block interleaving에서 n=0–175와 n+256은 같은 u_sb의 두 bit에 대응합니다. n=176–255의 80개 QPSK symbols에는 이 반복 상대가 없습니다. scrambling index가 다르므로 두 송신 QPSK 복소수는 같지 않을 수 있습니다.

정렬된 data 목록을 P[0–431]이라 하면 a[n]을 P[π(n)]에 배치합니다. 실제 사용할 표는 기존 `sss_pbch_gold_20260927/design_records.json`의 D3_permutation 또는 동일한 `six_candidate_lls_20260929/config/D3_permutation.json`입니다. 새 표로 임의 교체하지 않습니다.

### 5.3 mapping 목적과 표 생성 규칙

data RE p의 reference 지원 집합은 같은 60-tone 구간의 SSS 60개와 DMRS 12개입니다. reference z의 weight는 1/[1+|k_p−k_z|/10+|l_p−l_z|]이고, 전체 vector를 L2 정규화합니다. 구간 밖 weight는 0입니다. 두 vector 내적 C_ref(p,q)는 reference 공유 정도의 proxy입니다.

반복 쌍 n=0–175를 순서대로 처리합니다. 첫 관측은 아직 사용하지 않은 물리 data index 중 가장 작은 곳에 배치합니다. 두 번째는 다른 OFDM symbol의 미사용 위치 중 C_ref가 가장 작은 곳에 놓습니다. 동점이면 주파수 거리가 큰 곳, 다시 동점이면 (l,k)가 작은 곳을 선택합니다. 비반복 n=176–255는 남은 위치에 순서대로 배치합니다.

이 규칙은 재현 가능한 greedy 시작 설계입니다. reference 지원 구간이 다르면 proxy가 0이 되는 것은 정의의 결과이며 실제 fading 상관이나 최적 BLER의 증거가 아닙니다.

### 5.4 수신 절차

1. 공통 acquisition과 reference 가설 검증을 수행합니다. identity와 D3에 같은 절차를 적용합니다.
2. 주 실험의 CE는 60-tone별 고정 affine M1입니다. data mapping만 달라지도록 D1의 최종 모델 선택을 동시에 켜지 않습니다.
3. 물리 RE 순서로 QPSK LLR를 계산합니다.
4. 논리 n의 두 LLR를 물리 P[π(n)]에서 가져와 원래 논리 순서로 복원합니다.
5. 원래 bit index의 scrambling을 제거한 후 rate recovery에서 같은 u_sb 좌표의 LLR를 더합니다.
6. 고정 Polar decoder와 CRC를 적용합니다. permutation의 inverse를 적용하기 전에 물리 index로 descrambling하면 잘못된 수신기입니다.

### 5.5 대조군과 채택 조건

identity, seed를 고정한 random permutation, 주파수 거리만 최대화하는 mapping, D3를 비교합니다. random은 하나의 유리한 seed만 고르지 않고 사전에 정한 최소 10개 표의 분포를 제시합니다. reference 지원 창 20·40·60 tones와 실제 CE 창을 각각 명시합니다. 다른 창에서도 기존 π를 그대로 평가하는 robustness 시험과, 해당 창으로 π를 다시 설계하는 시험을 구분합니다.

필수 기록은 반복 bit별 LLR error correlation, reference 오염 위치, CE NMSE, BLER, general interleaving 대비 차이입니다. perfect CE, 독립 추정 오차, 전대역 공통 phase noise에서는 이득이 없을 수 있습니다. mapping 표·역표는 uint16 기준 총 1,728 bytes이며 runtime에는 index 재배열만 필요합니다.

**검토할 필수 구성:** 반복 mother-bit 관계, reference 영향 집합, 그 겹침을 줄이는 mapping, 대응 inverse mapping입니다. 일반 interleaving보다 추가 이점이 없으면 독립 후보의 우선순위를 낮춥니다.

## 6. G1: staggered SSS와 tracking reference

### 6.1 해결하려는 문제와 원안 G1-O

원안은 SSS를 세 symbols에 나누어 시간 관측을 확보하고, Comb offset을 바꾸어 주파수 보간을 개선하며, 별도 PT-RS로 phase를 추적하려 합니다. 배열은 Comb-4 offsets [0,2,0], SSS 180 RE, PBCH 540 RE입니다.

원안에는 세 가지 구현 충돌이 있습니다. 240-chip sequence 중 어떤 180개를 전송할지 정의되지 않았고, PT-RS 12 RE를 추가하면서 PBCH 540 RE를 그대로 유지하며, 제시한 PT-RS 위치 중 8 RE가 SSS와 겹칩니다. [0,2,0]은 240개 중 120개 subcarriers만 reference로 관측합니다. 이 배열을 모든 방향에서 최적인 육각 sampling으로 가정하지 않습니다.

### 6.2 G1-R의 충돌 없는 송신 profile

| symbol | SSS 위치 | tracking R 위치 | PBCH RE 수 |
|---|---|---|---:|
| l=1 | k=4m, m=0–59입니다. | k=25,89,153,217입니다. | 176 |
| l=2 | k=4m+2입니다. | 같은 네 k입니다. | 176 |
| l=3 | k=4m입니다. | 같은 네 k입니다. | 176 |

SSS에는 G[0–179]를 정렬 순서로 한 번씩 mapping합니다. R에는 기존 d(PCI,q)의 앞 12개 symbols를 사용합니다. 별도 신규 PT-RS sequence는 만들지 않습니다. S=180, R=12, B=528, E=1056입니다. R은 CE·phase·q 식별에 사용하므로 ‘전용 DMRS 0’이라고 표시하지 않습니다.

### 6.3 CE kernel과 q·phase 검증

PCI screening 이후 SSS-only CE를 시작합니다. 기본 covariance kernel은 R(p,z)=exp[−|k_p−k_z|Δf/B_c−|t_p−t_z|/T_c]입니다. B_c=1.2 MHz, T_c=0.5 ms, diagonal variance=1로 고정합니다. 이는 참 channel 통계를 사용한 optimal Wiener filter가 아니라 연구용 고정 kernel입니다.

SSS 관측 Z_P와 D_n=diag(N̂₀/E_pilot)로 Ĥ_D=R_DP(R_PP+D_n)⁻¹Z_P를 구합니다. 실제 계산은 선형 연립방정식으로 수행합니다. noise level에 따라 달라지는 행렬을 cache할 수 있지만 noise bin을 기록합니다. 초기 v_D는 R_DD의 diagonal에서 posterior covariance 감소분을 뺀 값의 비음수 부분입니다. kernel mismatch가 있으면 실제 오차를 과소평가할 수 있습니다.

각 symbol의 R 네 개를 주파수 순서 j=0–3으로 정렬합니다. 두 fold에서 짝수와 홀수 R을 phase fitting·validation으로 교대합니다. q 후보의 phase는 φ_l=arg Σ_r,p∈training Y_p·[d_q,p Ĥ_SSS,p]*로 구합니다. |φ_l|>π/4이면 해당 fold를 invalid로 처리합니다. validation R에서 e^{jφ_l}d_q Ĥ_SSS를 예측하고, 두 fold의 normalized residual로 q·CFO 후보를 정렬합니다.

최종 후보에서는 네 R 모두로 phase를 다시 추정하고, 해당 symbol 전체를 같은 위상으로 보정한 뒤 SSS+R로 CE를 다시 수행합니다. phase gate 실패 시 φ=0의 SSS-only CE를 시도하되, q가 미식별이면 최대 4회 복호 예산 내에서만 q 후보를 시험합니다. R이 적다는 이유로 q를 정답 입력하지 않습니다.

SSS 자체가 이미 symbol별 CPE를 포함하므로 φ가 순수 oscillator phase를 뜻하지는 않습니다. 실제 이득이 phase 추적에서 나오는지, kernel의 시간 smoothing 오차를 보정한 결과인지 구분합니다. raw CFO 보정이 ICI를 처리하고 φ는 남은 CPE 보정만 담당합니다.

### 6.4 동일 자원 profile G1-M

G1-R과 D2를 바로 비교하면 SSS 수, DMRS 수, E가 모두 다릅니다. 동일 자원 실험을 위해 G1-M을 별도로 정의합니다. 세 symbols의 SSS는 Comb-3 offsets [0,1,2], symbol당 80개입니다. DMRS는 모든 symbol에서 k=15j+12, j=0–15입니다. l=1의 겹치는 SSS 16개만 k+1로 이동한 뒤 정렬하여 G[0–239]를 mapping합니다. 다른 symbol에서는 충돌하지 않습니다.

총 S=240, R=48, B=432, E=864입니다. 완전한 uniform comb는 아니므로 이름에 anchor avoidance를 표시합니다. symbol당 R 16개를 modulo-2로 나누어 fitting 8개·validation 8개로 phase를 검증하며, 나머지 CE·q 처리와 calibration 규칙은 G1-R을 따릅니다.

### 6.5 대조군·실패 조건·필수 구성

G1-R의 직접 대조군은 offsets [0,0,0]에 같은 12개 R을 둔 구조입니다. phase correction 제거, R 제거(q oracle와 practical을 분리), kernel의 B_c={0.3,1.2,4.8} MHz·T_c={0.05,0.5,5} ms 민감도, G1-M과 D2의 동일 자원 비교를 수행합니다.

반례는 180-chip PCI miss 증가, 12개 R의 q 식별력 부족, 작은 validation 집합의 과적합, 시간·주파수 covariance mismatch입니다. G1-R이 나아져도 그 원인이 E 증가인지 offset 이동인지 각각 분리해야 합니다.

**검토할 필수 구성:** staggered mapping, 충돌 없는 tracking anchor, q·phase 검증, 불일치 시 fallback의 조합입니다. ‘육각 격자’라는 명칭이나 data RE 증가만으로 차별성을 판단하지 않습니다.

## 7. G2: SSS로 두 port를 추정하는 SFBC PBCH

### 7.1 해결하려는 문제와 원안 G2-O

원안은 2Tx 다이버시티를 사용하면서 전용 DMRS를 없애려 합니다. 같은 RE에 S₁과 S₂를 두 port로 전송하고, SSS의 직교성을 이용해 H₀·H₁을 분리한 뒤 SFBC PBCH를 복호하려는 구조입니다.

제시한 S₂(k)=S₁(k)e^{jπk/240}는 240개 unit-modulus chips에 대해 정규화 상관 제곱이 약 0.40529입니다. 0이 아니므로 직교가 아닙니다. 이는 240-point sequence 자체의 계산값이며, 실제 180개 RE에 sampling한 Gram matrix는 별도로 계산해야 합니다. 독립 Gold seed 역시 정확한 직교를 보장하지 않습니다.

한 RE에서 Y=H₀S₁+H₁S₂+N이고 H₀·H₁을 각 k에서 독립인 미지수로 놓으면 분리할 관측이 부족합니다. 여러 pilot에서 채널이 일정하거나 저차 모델을 따른다는 제약을 사용하면 joint estimation은 가능할 수 있으므로, 이를 명시하여 진단해야 합니다.

### 7.2 G2-O를 검토하기 위한 유한 진단 profile

원안의 모호한 240→180 chip 규칙은 진단에 한해 G[0–179]로 고정합니다. SSS grid는 Comb-4 offsets [0,1,2]이고 logical chip n에 대해 S₁=G[n], S₂=G[n]e^{jπk/240}를 실제 물리 k로 계산합니다. 두 port 각각 진폭 1/√2를 적용합니다. 이 선택을 원안의 확정 규칙으로 소급하지 않습니다.

우선 flat channel에서 두-column pilot matrix의 Gram matrix, singular values, condition number, joint LS NMSE를 측정합니다. 다음으로 symbol·20-tone 구간에서 H_t(k)=a_t+b_t x를 가정하고, pilot 5개의 복소 관측으로 두 port의 네 복소 계수를 fitting합니다. 미사용 pilot 검증에는 fitting 관측이 부족하므로 먼저 이 모델은 진단용으로만 평가하고, 주파수 선택성이 증가할 때의 model bias를 기록합니다. true port CE 결과는 oracle입니다.

SFBC 송수신은 §7.4의 일관된 수식을 사용합니다. 원안의 개별 결합식을 독립적으로 혼합하지 않습니다. zero-noise에서도 제대로 분리되지 않는 조건을 먼저 찾고, 검증 없이 diversity 차수나 dB 이득을 지정하지 않습니다.

### 7.3 G2-R: 고정 Gold chip의 port별 FDM

G2-R은 **원안의 직교 sequence 쌍을 사용하지 않는 대체안**입니다. SSS 위치는 원안의 Comb-4 offsets [0,1,2]로 유지합니다. 정렬된 SSS index n=0–179에서 port=n mod2에만 G[n]을 전송하고 반대 port는 mute합니다. port당 SSS는 90 RE, symbol당 30 RE입니다. 새 Gold 초기화나 위상 회전을 추가하지 않습니다.

SSS가 아닌 RE는 모두 SFBC data입니다. symbol별 data 목록을 k 순서로 정렬한 뒤 연속된 두 원소를 pair로 묶습니다. 실제 k 차이는 1 또는 2일 수 있으며 symbol 경계를 넘지 않습니다. symbol당 90 pairs, 전체 270 pairs에 QPSK 540개를 전달합니다. E=1080이며 2Tx라고 E를 두 배로 세지 않습니다.

### 7.4 SFBC 송수신 수식

논리 QPSK a,b와 두 물리 위치 k_a,k_b의 송신값을 다음처럼 고정합니다.

| 물리 위치 | port 0 | port 1 |
|---|---|---|
| k_a | a/√2 | b/√2 |
| k_b | −b*/√2 | a*/√2 |

Rx r에서 z_r=[Y(k_a,r),Y*(k_b,r)]ᵀ이고, 두 행의 channel matrix는 A_r=(1/√2)[[H₀(k_a,r),H₁(k_a,r)],[H₁*(k_b,r),−H₀*(k_b,r)]]입니다. 따라서 z_r=A_r[a,b]ᵀ+n_r입니다. 모든 Rx를 쌓고 가능한 QPSK 쌍 16개에 대해 Σ_rows |z−A[a,b]ᵀ|²/V_row를 계산합니다. 각 bit의 max-log LLR는 공통 규칙을 따릅니다.

이 식은 pair의 두 tones에서 채널이 같다는 가정을 강제하지 않습니다. 단순 Alamouti 직교 결합은 pair 내 constant-channel 조건의 별도 대조군입니다. pilot 사이 CE 오차와 ICI가 사라지는 것은 아닙니다.

### 7.5 PCI·port CE·q 검출

PCI screening은 symbol·port·20-tone 그룹의 상관 에너지를 합합니다. 각 PCI·CFO 가설에서 port별·symbol별 SSS LS값을 complex linear frequency interpolation합니다. 양끝은 가까운 두 reference로 외삽합니다. port·symbol별 정렬된 30개 SSS를 modulo-3으로 나누어 fitting 20개·validation 10개로 CE를 검증합니다.

최종 CE는 해당 port의 전체 SSS로 refit합니다. 다른 port의 SSS를 같은 channel의 reference로 합치지 않습니다. port·symbol·Rx별 v_t,l,r=max(0,validation residual−N̂₀,r)로 두고, SFBC의 각 row variance는 N̂₀,r+(v₀,l,r+v₁,l,r)/2입니다. 어느 port가 해당 symbol에서 invalid이면 그 symbol의 SFBC pair 전체를 erasure로 처리합니다.

G2-R에는 q reference가 없습니다. PCI별로 SSS validation이 가장 좋은 CFO 하나를 선택하고 q=0–7의 descrambling·Polar decoding을 모두 시도합니다. 최대 3 PCI×8 q=24회입니다. CRC를 통과한 서로 다른 q가 둘 이상이면 ambiguous failure입니다. q를 reference만으로 검출했다고 기록하지 않습니다.

공정한 4회 복호 제한 시험에서는 최고 PCI의 q 중 trial별 미리 정한 순환 시작점부터 네 개만 시험합니다. 정답 q가 목록 밖이면 실패로 남깁니다. 이 대조군은 decoder budget 부족으로 인한 성능 상한을 드러냅니다.

### 7.6 비용·반례·필수 구성

같은 SSS180·data540·총 Tx EPRE·Rx 수를 가진 1Tx 대조군을 사용합니다. port correlation 0·0.5·0.9와 Rx correlation을 각각 평가합니다. 1T1R 대비 2T4R 차이를 SFBC 단독 이득으로 표시하지 않습니다. PSS는 port 0만 사용하므로 PBCH 다이버시티가 전체 acquisition 병목을 해결하지 못할 수 있습니다.

주요 반례는 port당 sparse reference, 주파수 보간 오차, q 검출의 24회 복호 비용, 높은 공간 상관입니다. perfect port CE, joint pair detector와 단순 Alamouti detector, 4회·24회 decoder budget을 ablation합니다.

**원안의 필수 구성:** 같은 RE에서 두 SSS를 분리하는 규칙과 그 channel 식별 가능성입니다. **G2-R의 필수 구성:** port별 고정 Gold mapping, 알려진 mute pattern, port CE와 SFBC의 연결입니다. 두 구성을 같은 발명으로 간주하지 않습니다.

## 8. G3: timing 분리와 정적 PBCH 결합

### 8.1 해결하려는 문제와 원안 G3-O

원안은 SFN·q처럼 변하는 정보를 SSS로 옮기고 정적 payload만 PBCH에 넣어 여러 burst를 누적하려 합니다. 다만 ‘SFN이 변하면 모든 soft combining이 불가능하다’고 전제하지 않습니다. 핵심 문제는 **서로 다른 관측에서 어떤 coded bits가 동일한지 receiver가 확인할 수 있는가**입니다.

G3-O의 l=1은 G[k]e^{j2πmk/8192}, l=2·3은 static data 480 RE입니다. m=8·SFN+q, SFN=0–1023, q=0–7로 정의합니다. static payload 48 bits, CRC24C, K=72,N=512,E=960입니다. static scrambling phase는 0으로 고정하는 진단 규칙을 추가합니다.

### 8.2 G3-O의 식별 가능성 진단

인접 m의 240-point 정규화 상관 제곱은 약 0.99718입니다. 30 kHz SCS에서 m 한 단계의 위상 기울기는 약 4.069 ns의 timing shift와 대응합니다. 임의의 미지 H[k]를 허용하면 다른 m′에 대해 H′[k]=H[k]e^{j2π(m−m′)k/8192}가 같은 관측을 설명합니다. channel·timing 제약이 없으면 m과 channel의 역할이 분리되지 않습니다.

다음 네 단계로 진단하며, 실제 8,192개 m 상태를 사용합니다.

1. **known-H AWGN:** true PCI·H·timing을 제공하고 모든 m의 channel-aware likelihood를 비교합니다. 이는 구별 가능성의 oracle 기준입니다.
2. **unknown flat H:** m마다 복소 scalar H를 LS로 추정한 뒤 residual을 비교합니다. 원안의 DFT 상관 metric은 이 flat-channel 가정 아래의 진단으로 해석합니다.
3. **constrained delay model:** 주파수 channel을 512-point DFT의 delay bins 0–L−1로 제한하고 L=1,4,8을 시험합니다. m마다 해당 channel basis 계수를 LS로 추정한 residual을 비교합니다. CP 내 임의 channel을 허용한 결과와 혼합하지 않습니다.
4. **PSS-assisted practical:** PSS가 차지한 tones의 관측으로만 channel·timing을 예측합니다. SSS 전체 대역의 true H를 보충하지 않습니다. joint PCI·m search와 후보 pruning 비용을 기록합니다.

원안의 data CE는 후보 m의 phase를 제거한 l=1 SSS에서 시작하며 l=2·3에는 zero-order time extension을 기본으로 적용합니다. 이는 높은 Doppler에서 취약한 명시적 baseline입니다. 다른 time predictor를 추가하면 별도 variant로 표시합니다. PCI screening에서 m을 true로 주입하지 않습니다. practical diagnostic의 최대 336 PCI×8192 m×3 CFO라는 초기 search 규모와 실제 pruning 수를 보고합니다.

각 진단의 후보 ranking은 해당 channel 제약에서 fitting한 normalized residual의 오름차순입니다. 동점은 PCI, m, CFO 값의 오름차순으로 정하고 상위 4개만 static Polar decoding을 수행합니다. 실제 구현을 시작할 constrained-delay 진단은 L=4로 고정하며, L=1·8은 민감도 시험입니다. 서로 다른 m이 같은 static payload로 CRC를 통과해도 SFN·q가 다르면 timing ambiguity로 실패 처리합니다. 여러 m이 만든 동일 static CRC를 timing 검출 성공으로 세지 않습니다.

평가 지표는 wrong-m probability, SFN·q별 오류, joint PCI 오류, static BLER, search complexity입니다. 8,192-point zero-padding FFT가 물리 관측 길이를 늘리는 것으로 해석되지 않도록 합니다. 원안에는 epoch·payload 변경 식별 규칙이 없으므로, static 불변 oracle combining과 payload 변경 시의 실패 진단을 분리합니다. 검증 전에는 ‘무한 결합’ 수신기를 정의하지 않습니다.

### 8.3 G3-R: 별도 header를 사용하는 대체 architecture

G3-R은 SSS phase modulation을 제거하고 timing·epoch를 header에 넣습니다. 정적/동적 정보 분리라는 문제의식은 유지하지만, **원안의 0-RE timing 전달과 다른 구성**입니다. 다음 resource를 사용합니다.

| 영역 | 위치·규칙 |
|---|---|
| SSS | l=1 전체에 G[0–239]를 놓습니다. |
| DMRS | l=2·3, k=10m+5, m=0–23입니다. q 입력은 0입니다. |
| data 목록 | l=2·3에서 DMRS를 제외한 432 RE를 정렬합니다. |
| header | 목록 index floor(432j/64), j=0–63인 64 RE입니다. |
| static | 나머지 368 RE입니다. |

header bit layout은 SFN 10 bits, q 3 bits, epoch 8 bits의 순서이며 필드 내 MSB first입니다. A=21,K=45,N=128,E=128입니다. static layout은 core 40 bits와 epoch 8 bits이며 A=48,K=72,N=512,E=736입니다. 두 block은 각각 CRC-24C와 독립 Polar code를 사용하고 scrambling phase는 0입니다.

epoch는 core가 바뀔 때마다 증가합니다. gNB는 최대 cache lifetime 320 ms 안에서 같은 epoch로 서로 다른 core를 전송하지 않는다는 공개 profile 규칙을 지킵니다. epoch wrap·규칙 위반은 별도 stress입니다. 이 규칙이 없다면 8-bit epoch만으로 동일 payload를 보장할 수 없습니다.

### 8.4 single-burst 수신과 header gate

PSS·SSS로 PCI·CFO 후보를 얻습니다. q=0 DMRS로 60-tone 구간별 D1형 validation을 수행합니다. M0는 l=2·3의 DMRS-only frequency interpolation이고, M1은 l=1 SSS와 fitting DMRS를 사용하는 affine 모델입니다. 검증에 실패한 data 구간은 erasure입니다.

상위 4개 후보에 header decoding을 적용합니다. 서로 다른 header가 CRC를 통과하면 해당 burst는 ambiguous failure입니다. 유일한 header와 reference consistency가 확인된 경우에만 static LLR를 생성·결합합니다. header가 실패한 burst의 static LLR는 저장하지 않습니다. 이 보수적 gate 때문에 header가 coverage의 병목이 될 수 있습니다.

### 8.5 결합 상태와 reset 규칙

buffer key는 carrier raster, PCI, q, epoch, static code profile, delay-track identity입니다. 최대 세 개의 독립 delay track buffer를 허용합니다. 같은 PCI만으로 관측을 합치지 않습니다. 다음 예상 PSS 시점의 ±4 samples 안에 들어오는 track이 하나이면 연결하고, 둘 이상이면 해당 관측을 보류합니다. 예측에는 이전 두 검출 시점의 선형 추세를 사용하며 하나만 있으면 주기 20 ms를 사용합니다. buffer가 모두 차면 마지막 갱신 시각이 가장 오래된 buffer를 폐기합니다.

| 상태·사건 | 처리 |
|---|---|
| 새 유효 header | 새 key의 buffer를 만들고 첫 static 관측을 저장합니다. |
| 같은 key·새 관측 | SFN과 local elapsed time의 일관성을 확인한 뒤 mother LLR를 누적합니다. |
| header 실패 또는 중복 관측 | 누적하지 않습니다. 기존 buffer는 timeout까지 유지합니다. |
| epoch 변경 | 같은 track의 이전 buffer를 폐기하고 새 epoch로 시작합니다. |
| q 또는 track 변경 | 기존 buffer와 합치지 않고 별도 key를 사용합니다. |
| static CRC 통과 | static epoch와 header epoch가 같으면 수락하고 해당 buffer를 종료합니다. |
| 16회 누적 또는 320 ms 만료 | 미복호이면 실패로 종료합니다. |

동일 q의 scheduled observation 간격은 20 ms입니다. SFN 차이는 modulo 1024에서 2,4,…,32만 허용하고, local elapsed time과 10 ms×SFN 차이가 0.5 ms 이내여야 합니다. 중복 여부는 local sample interval과 decoded SFN·q를 함께 사용합니다. 첫 관측에서 16번째 관측까지는 300 ms이며, 초기 대기·처리 시간은 추가합니다.

각 burst를 자기 CE로 demapping·descrambling·rate recovery한 뒤 동일 mother 좌표의 LLR를 더합니다. RF sample을 coherent하게 합치지 않습니다. burst 간 phase가 달라도 올바른 개별 복조와 bit 대응이 있으면 LLR 결합은 가능하지만, 공통 간섭·추정 오차가 존재하면 독립 관측의 이득을 기대할 수 없습니다.

buffer는 float32 512개, 순수 LLR 저장량 2,048 bytes입니다. 누적값의 저장 clipping은 ±800, decoder 입력 clipping은 ±50입니다. 최대 세 buffer와 metadata를 포함한 실제 메모리를 별도 기록합니다. 매 유효 burst마다 최대 header 4회와 static 1회 decoding을 수행하므로 16회 동안의 최악 호출 수는 80회입니다. header 실패 burst에도 header 비용과 수신 on-time은 계산합니다.

### 8.6 공정 비교와 핵심 반례

G3-R single-shot, 같은 grid의 oracle-header combining, practical-header combining, 같은 시간·총 에너지를 사용하는 반복 PBCH를 비교합니다. N_obs=1,2,4,8,16이며 header boost 0·3·6 dB는 각 SSB energy 720을 유지하도록 정규화합니다.

다른 후보의 32-bit payload와 G3-R의 core 40 bits+timing을 같은 서비스라고 취급하지 않습니다. 순수 결합 비교에는 같은 core·header·coding을 사용합니다. 서비스 일치 실험이 필요하면 core 32+epoch8의 별도 static block을 정의하고 K=64로 변경한 variant임을 표시합니다.

core 변경, header false acceptance, epoch wrap, missing/duplicate burst, q 전환, 같은 PCI·비슷한 delay의 두 cell, correlated interference를 시험합니다. 초기 header가 복호될 만큼 SNR이 높아야만 static 결합이 가능하다면 전체 coverage 이득이 작을 수 있습니다.

**원안의 필수 구성:** timing의 SSS phase encoding과 초기 식별 가능성입니다. **G3-R의 필수 구성:** self-decodable header, epoch·관측 identity에 따른 유한 결합과 reset입니다. 후자의 성공은 전자의 식별 문제를 해결했다는 증거가 아닙니다.

## 9. 후보별 simulation 입출력과 검토 질문

| 후보 | 추가 입력·고정 데이터 | receiver가 반환할 진단값 | 우선 검토할 질문 |
|---|---|---|---|
| D1 | DMRS fold, 두 CE 모델, δ·T_abs입니다. | 모델 선택·잔차·erasure·uncertainty입니다. | 검증이 틀린 SSS 활용을 차단하면서 정답을 과도하게 버리지 않는가? |
| D2 | endpoint·bridge 집합, 보간 시각입니다. | bridge residual·중앙 erasure·endpoint uncertainty입니다. | split SSS 손실을 포함해 중앙 보간이 유리한가? |
| D3 | 고정 permutation·reference 지원 집합입니다. | 반복 bit LLR error correlation입니다. | 일반 interleaving 이상의 효과가 reference 공유 오차에서 나오는가? |
| G1 | offset, tracking R, 고정 kernel입니다. | q·phase residual·kernel mismatch·SSS miss입니다. | pilot 축소·E 증가와 무관하게 stagger와 tracking의 효과가 있는가? |
| G2 | port 활성 pattern·SFBC pair list입니다. | port CE NMSE·joint metric·q 복호 횟수입니다. | 동일 총 전력과 같은 Rx 수에서 다이버시티 이득이 남는가? |
| G3 | m codebook 또는 header layout·epoch 규칙입니다. | m/header 오류·buffer event·latency·누적 energy입니다. | timing과 동일 payload를 실제로 확인하면서 coverage를 늘릴 수 있는가? |

모든 후보의 공통 출력은 수락 PCI·q·payload, CRC, complete success, 사용한 가설 수, 복호 횟수, 수신 on-time, failure reason입니다. ground truth와 실제 channel은 scorer에만 전달합니다. receiver에게 제공한 oracle 정보는 항목별 flag로 기록합니다.

## 10. 실험 행렬·통계·완료 조건

### 10.1 세 종류의 비교를 분리합니다

**원리 분리 비교:** D1과 always-joint는 같은 waveform, D3와 identity는 같은 CE·coding, G1의 fixed/staggered는 같은 자원, G2의 1Tx/2Tx는 같은 총 power·Rx 수, G3의 single/combining은 같은 block 구조를 사용합니다.

**동일 자원 비교:** D1/D2/D3/G1-M은 S240·R48·B432·E864를 맞춥니다. 송신 구조가 다르면 검출 조건과 실제 CE도 함께 보고합니다. 동일 RE 수만으로 동일 성능 난이도라고 가정하지 않습니다.

**native architecture 비교:** G1-R, G2-R, G3-R의 실제 E·payload·port·시간·복호 비용을 유지합니다. 단일 BLER 순위를 만들기보다 complete acquisition, energy, latency, complexity의 조건별 차이를 비교합니다.

### 10.2 채널과 impairment

독립 trial에서 PCI는 0–1007, q는 0–7의 균등분포, payload는 독립 Bernoulli(1/2)로 생성합니다. 초기 timing offset은 0–127 samples의 균등분포입니다. 특정 q=0만 반복하지 않습니다. G3 episode에서는 PCI·q·core를 유지하고 SFN은 20 ms마다 2씩 증가시킵니다. payload 변경 stress에서는 미리 정한 관측 번호 8에서 core와 epoch를 바꿉니다. seed는 calibration·evaluation·random mapping용 stream을 분리하여 기록합니다.

| 변수 | 시작 설정 | 민감도·stress |
|---|---|---|
| channel | AWGN 기능 확인 후 TDL-C입니다. | TDL-A를 추가합니다. |
| RMS delay spread | 300 ns입니다. | 30,100,1000 ns입니다. maximum excess delay와 구분합니다. |
| 속도 | 3 및 120 km/h입니다. | 500 km/h입니다. f_D=v f_c/c로 계산합니다. |
| SNR_RE | −16–+4 dB, 2 dB 간격입니다. | BLER crossing 부근 0.5 dB 간격입니다. |
| residual CFO | 0, ±0.05 SCS입니다. | ±0.1,±0.2 SCS와 search 범위 밖을 시험합니다. |
| timing error | practical estimator 출력입니다. | 별도 진단에서 ±1,±4 samples 및 CP 경계 밖 오차를 주입합니다. |
| phase noise | 기본 off입니다. | sample별 Wiener phase increment를 사용하며 useful symbol 누적 RMS 1°,3°,10°로 분산을 정합니다. |
| 국소 간섭 | 기본 off입니다. | SSS-only 60-tone 구간 또는 DMRS 위치에 INR 0,10 dB의 독립 간섭을 주입합니다. 이는 RE-domain stress이며 실제 interferer waveform과 구분합니다. |
| 공간 상관 | G2의 Tx correlation 0입니다. | 0.5,0.9 및 Rx correlation을 별도로 적용합니다. |
| G3 시간 | 같은 q가 20 ms마다 도착합니다. | burst 누락·duplication·payload 변경을 포함합니다. |

TDL에서는 path gain normalization을 유지하되 Rx 수로 출력 전력을 추가 정규화하지 않습니다. burst마다 fading process의 시간을 0으로 초기화하지 않습니다. 지속 channel을 사용할지 독립 burst channel을 사용할지 명시하며 둘을 같은 결과로 합치지 않습니다. channel 구현의 RMS delay, Doppler, normalization 설정은 [MathWorks nrTDLChannel](https://www.mathworks.com/help/5g/ref/nrtdlchannel-system-object.html)을 기준으로 기록합니다.

### 10.3 oracle와 practical의 구분

O0는 no-noise·known identity·known channel의 기능 시험입니다. O1은 true PCI·q·timing·CFO에서 practical CE를 사용하는 conditional PBCH 시험입니다. A는 waveform과 공개 profile만 받는 complete acquisition 시험입니다. G3의 oracle header나 oracle m은 별도의 flag로 표시합니다.

전체 성공은 같은 trial에서 PSS·PCI·q·payload가 모두 정답인 사건으로 계산합니다. CRC pass만으로 정답이라고 집계하지 않습니다. component 성공률을 서로 독립이라고 가정하여 곱하지 않습니다. conditional BLER의 조건은 plot마다 명시합니다.

### 10.4 threshold calibration

calibration과 evaluation seed를 분리합니다. threshold 후보 T_abs={1,2,3,4,6,8,12}, D1 δ={0,0.1,0.2}를 사용합니다. PSS detection threshold와 reference acceptance threshold는 서로 다른 gate입니다. noise-only 및 wrong-PCI trial을 각각 100,000개 이상 사용하여 search 전체를 포함한 오류를 측정합니다.

초기 목표는 acquisition false alarm 1% 이하, 최종 잘못된 수락 확률 10⁻³ 이하입니다. 두 지표를 같은 이름으로 부르지 않습니다. 95% upper confidence bound가 목표 이하인 설정 중 별도 signal calibration의 complete success가 가장 높은 것을 선택합니다. 동점이면 낮은 T_abs, 높은 δ를 선택합니다. 목표를 달성하지 못하면 평가 결과에 gate failure를 표시하며 기준을 임의로 완화하지 않습니다.

### 10.5 반복 횟수와 통계

각 SNR·channel 조건에서 최소 10,000 trials를 수행합니다. 그 이후 primary endpoint error 300개에 도달하면 종료하고, 최대 1,000,000 trials로 제한합니다. G3 trial은 burst 한 개가 아니라 전체 acquisition episode입니다. 후보별 실패율에는 Wilson 95% confidence interval을 보고합니다. 0 error를 오류 확률 0으로 해석하지 않습니다.

비교 후보는 같은 payload·channel·noise seed를 최대한 공유합니다. architecture가 다른 경우 bit stream이 같다고 강제하지 말고 물리 channel realization과 관측 조건을 맞춥니다. paired complete-failure 차이는 trial 또는 G3 episode 단위의 paired bootstrap 10,000회로 interval을 계산합니다. kernel·threshold·mapping 선택에 사용한 데이터는 성능 평가에 재사용하지 않습니다.

### 10.6 최소 실험 목록

| ID | 실험 | 확인할 원인 |
|---|---|---|
| V0 | 자원·bit 수·mapping·전력·zero-noise 복원입니다. | 수신기 산술·index 오류를 분리합니다. |
| V1 | D1의 DMRS-only/always-joint/검증 선택 비교입니다. | SSS 활용 검증의 효과를 확인합니다. |
| V2 | D2의 MF/MT와 bridge gate 제거입니다. | 배치와 gate 효과를 구분합니다. |
| V3 | D3의 identity/random/최대거리/제안 mapping입니다. | 일반 interleaving 이상의 효과를 확인합니다. |
| V4 | G1의 fixed/staggered, phase on/off, G1-M입니다. | 배치·tracking·자원 증가를 분리합니다. |
| V5 | G2-O의 Gram·joint LS와 G2-R의 1Tx/2Tx입니다. | 원안의 분리 가능성과 대체안의 다이버시티를 구분합니다. |
| V6 | G3-O의 known-H/unknown-H 및 전체 m search입니다. | timing 정보 식별 가능성을 확인합니다. |
| V7 | G3-R의 oracle/practical header, 1–16회 결합입니다. | header gate 비용과 누적 이득을 구분합니다. |
| V8 | wrong-PCI, noise-only, 동일 PCI 간섭, CRC ambiguity입니다. | 잘못된 수락을 확인합니다. |
| V9 | CFO·timing·Doppler·delay·phase noise stress입니다. | 설계 가정이 깨지는 조건을 찾습니다. |

### 10.7 구현 전·후 완료 조건

구현 전에는 모든 profile의 RE 집합이 배타적이고 합계가 720인지, Gold chip index가 정의되었는지, q 전달·탐색 규칙이 있는지, A/K/N/E와 총 Tx energy가 일치하는지 검토합니다. G1-O처럼 충돌이 있는 원안에는 임의의 성능 곡선을 만들지 않습니다.

기능 시험에서는 D3 permutation·inverse와 bit 복원, G2의 canonical SFBC 행렬과 energy, G3의 header 위치 중복·epoch reset·duplicate 방지를 확인합니다. 이 검사는 무선 성능 검증이 아닙니다.

성능 검토에서는 D1이 clean 조건을 과도하게 악화시키지 않는지, D2의 전체 acquisition이 개선되는지, D3가 일반 interleaving보다 유리한지, G1의 이득이 E 증가만으로 설명되지 않는지, G2의 port CE·q 비용이 이득을 상쇄하지 않는지, G3의 header·timing gate를 포함해 coverage와 latency의 절충이 성립하는지를 판단합니다. 어느 후보도 기준을 충족하지 않으면 기존 baseline을 유지합니다.

## 11. 기존 자료와의 차이 및 근거

이번 문서는 9월 27일의 D1–D3 보고서, 첨부 Gemini 제안서, 작업 폴더에 있던 9월 29일 상세 자료를 검토하여 **코드 없이 읽을 수 있는 simulation 설계서**로 정리했습니다. 기존 simulator나 source code는 수정하지 않았으며 link-level Monte Carlo를 실행하지 않았습니다.

9월 29일 자료와 달리 D2의 중앙 reference 부재에 따른 erasure를 명시하고, endpoint uncertainty의 독립성을 가정하지 않는 시작 proxy를 사용합니다. 상보 SSS 구조에서 DMRS 이동만으로 같은-k 연결을 제거할 수 없다는 ablation 제약도 명시했습니다. G2-O·G3-O의 진단과 G2-R·G3-R의 대체 설계를 분리하고, G3 buffer 수·교체 규칙·총 decoder 비용을 추가했습니다.

**설계 근거 파일**

- [D1–D3 전체 보고서](../sss_pbch_gold_20260927/SSS_PBCH_Gold_특허설계_보고서.md)
- [첨부 G1–G3 원안](../[gemini]6g_ssb_patent_proposal.md)
- [기존 공통 구현 자료](../six_candidate_lls_20260929/01_공통구현계약.md)
- [기존 후보별 상세 자료](../six_candidate_lls_20260929/02_후보별상세설계.md)
- [고정 Gold fixture 정보](../six_candidate_lls_20260929/config/fixture_manifest.json)
- [기존 D3 mapping](../sss_pbch_gold_20260927/design_records.json)

외부 공식 문서는 OFDM·PBCH PRBS·DMRS·Polar·channel block의 정의를 확인하는 데 사용했습니다. 그 문서가 본 후보의 신규성이나 성능을 검증한다는 뜻은 아닙니다. 첨부 제안서의 BLER·dB 이득 및 ‘최적’이라는 표현은 이번 설계서의 확정 사실로 채택하지 않았습니다.
