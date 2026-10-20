# SSS 반복 및 PBCH 채널 추정을 위한 SSB 1-symbol 확장 제안

- 작성일: 2026-10-01
- 문서 상태: 개념 설계 제안이며, 성능 검증과 규격 적합성 검토는 수행하지 않았습니다.
- 적용 기준: 240개 subcarrier를 사용하는 일반적인 NR SS/PBCH block을 기준으로 합니다. Narrowband puncturing 등의 예외 구성은 별도 검토가 필요합니다.

## 1. 목적과 제안 요약

기존 NR의 4-symbol SSB를 그대로 유지하면서, 바로 뒤에 SSS 반복과 PBCH 채널 추정용 추가 reference signal을 담은 1개 OFDM symbol을 배치합니다.

추가 symbol의 중앙 127 RE에는 기존 SSS와 동일한 sequence를 전송하고, 양쪽 96 RE에는 추가 reference signal을 전송합니다. 이를 통해 SSS 검출을 보강하고, 기존 PBCH DM-RS와 결합할 채널 관측을 추가합니다.

본 문서에서는 추가 reference signal을 편의상 **E-RS**라고 부릅니다. E-RS는 현재 NR 표준에 정의된 PBCH DM-RS가 아니라, PBCH demodulation을 보조하기 위해 새로 정의해야 하는 signal입니다.

호환성을 위해 표준 SSB 자체는 4개 symbol로 유지하고, 추가 symbol은 **SSB에 연결된 별도의 보강 signal**로 취급합니다. 전체 관측 구간은 5개 symbol이 됩니다. 기존 UE와의 공존 가능성을 확보하는 설계이며, 현재 NR 규격에 이미 포함된 기능이라는 의미는 아닙니다.

## 2. 설계 조건

1. 기존 PSS, SSS, PBCH 및 PBCH DM-RS의 RE mapping을 변경하지 않습니다.
2. 기존 PBCH data를 puncturing하거나 rate matching 규칙을 변경하지 않습니다.
3. 기존 SSB 시작 위치와 SSB index를 유지합니다.
4. 추가 signal은 기존 SSB와 동일한 SCS 및 CP 구성을 사용합니다.
5. 기존 SSB부터 추가 symbol까지 동일한 beam 및 precoding을 유지하도록 정의합니다.
6. 기존 SSB와 E-RS 사이의 유효 채널 관계, 전력 scaling 및 위상 연속성 조건을 새 규격에서 명시해야 합니다.
7. 추가 symbol은 다른 필수 signal이나 다른 UE에 할당된 자원과 충돌하지 않는 경우에만 전송합니다.

## 3. Time-frequency resource mapping

### 3.1 인덱스 정의

- `l=0,1,2,3`은 기존 SSB 내부의 OFDM symbol index입니다.
- `l=4`는 기존 SSB 바로 뒤의 추가 symbol을 나타내는 본 제안의 상대 index입니다.
- `k=0,...,239`는 SSB 내 subcarrier index입니다.
- 아래 표의 `D`는 기존 PBCH DM-RS를 의미합니다.

### 3.2 제안 배치

| Subcarrier k | l=0 | l=1 | l=2 | l=3 | 추가 l=4 |
|---|---|---|---|---|---|
| 192–239 | 0 | PBCH + D | PBCH + D | PBCH + D | E-RS |
| 183–191 | 0 | PBCH + D | 0 | PBCH + D | 0 |
| 56–182 | PSS | PBCH + D | SSS | PBCH + D | 동일 SSS 반복 |
| 48–55 | 0 | PBCH + D | 0 | PBCH + D | 0 |
| 0–47 | 0 | PBCH + D | PBCH + D | PBCH + D | E-RS |

기존 `l=0`–`3`의 배치는 TS 38.211의 SS/PBCH block mapping을 따릅니다. 추가 symbol의 배치는 본 문서에서 제안하는 내용입니다.[1]

### 3.3 추가 symbol의 세부 구성

| 구성 요소 | 위치 | RE 수 | 목적 |
|---|---|---:|---|
| SSS 반복 | k=56–182 | 127 | Cell ID 검출을 보강하고 중앙 대역의 채널을 관측합니다. |
| E-RS | k=0–47, 192–239 | 96 | PBCH 양쪽 대역의 채널을 조밀하게 관측합니다. |
| Zero RE | k=48–55, 183–191 | 17 | 기존 SSS symbol과 같은 주파수 간격을 유지합니다. |
| 합계 | k=0–239 | 240 | 추가 OFDM symbol 하나를 구성합니다. |

17개 zero RE는 초기 설계를 단순하게 유지하기 위한 선택입니다. 이 간격이 모든 확장 설계에서 물리적으로 필수라는 의미는 아닙니다.

## 4. Sequence 및 송신 조건

### 4.1 SSS 반복

추가 symbol에서는 기존 `l=2`와 동일한 SSS sequence를 동일한 subcarrier에 전송합니다. 초기 설계에서는 동일한 SSS EPRE를 가정하되, 총 에너지를 고정하는 비교에서는 전력 배분을 별도로 정의합니다.

SSS 반복 자체에 새로운 정보를 부호화하지 않습니다. 새로운 정보를 추가하면 기존 SSS와의 단순 결합이 어려워지므로, 초기 검증에서는 순수 반복을 기준으로 합니다.

### 4.2 E-RS

초기 설계에서는 다음 구성을 제안합니다.

- 알려진 constant-modulus QPSK sequence를 사용합니다.
- PCI를 기반으로 sequence를 생성하고, 양쪽 대역의 총 96 RE에 고정된 순서로 매핑합니다.
- 기존 PBCH DM-RS와의 EPRE 비율은 지원 UE가 사전에 알 수 있도록 고정하거나 규격으로 정의합니다.
- Sequence generator와 초기화 식은 후속 설계에서 확정합니다. 기존 PBCH DM-RS 생성식을 그대로 사용할 수 있다고 가정하지 않습니다.

SSB index를 sequence 생성에 포함하면 같은 PCI에 속한 여러 SSB의 연결 관계를 확인하기 쉬워질 수 있습니다. 대신 PBCH 복호 전에는 index 후보 탐색이 필요하므로, 초기 설계의 선택 항목으로 둡니다.

E-RS가 기존 PBCH와 같은 유효 채널을 관측하도록 antenna port 관계와 beam 유지 조건을 정의해야 합니다. Beam 방향이 같다는 사실만으로 RF 위상 관계까지 보장되지는 않습니다.

## 5. 지원 UE의 수신 절차

1. 기존 PSS를 검출하여 SSB timing과 PSS sequence 후보를 획득합니다.
2. 기존 SSB와 추가 symbol의 수신 samples를 저장합니다. 추가 signal이 없을 가능성도 고려합니다.
3. `l=2`와 `l=4`에서 SSS 후보별 검출 metric을 계산합니다.
4. 위상 정렬의 신뢰도가 충분하면 coherent combining을 적용합니다. 그렇지 않으면 관측별 likelihood 또는 에너지 기반 metric을 결합합니다.
5. 판별한 PCI를 이용하여 E-RS를 생성하고, 추가 signal의 존재 여부 및 관측 신뢰도를 평가합니다.
6. 기존 PBCH DM-RS, 기존 SSS, 반복 SSS 및 E-RS를 결합하여 PBCH 채널을 추정합니다.
7. 저장한 PBCH를 equalization하고 복호합니다.
8. 추가 signal이 없거나 신뢰도가 낮으면 기존 4-symbol SSB에 기반한 처리 결과를 사용합니다.

SSS 결합 검출과 확장 signal 존재 판정은 서로 연관됩니다. 구현 시에는 확장 존재·부재 가설을 함께 평가하거나, 기존 SSS 결과를 초기값으로 사용하는 등의 절차가 필요합니다. 임의의 data나 noise를 SSS 반복으로 오인하여 기존 검출 성능이 저하되지 않도록 threshold와 fallback 규칙을 검증해야 합니다.

## 6. 기대 효과와 한계

### 6.1 SSS 검출 보강

동일한 SSS를 두 번 관측하므로 Cell ID 후보 판별에 사용하는 관측 에너지가 늘어납니다. 매회 동일한 에너지로 전송하고 이상적으로 결합하면 SSS 검출의 SNR 이득은 약 3 dB가 될 수 있습니다.

이는 추가 에너지를 사용하는 조건의 이득입니다. SSS 총 에너지를 두 관측에 나누어 배분하면 3 dB의 에너지 이득은 발생하지 않습니다. 이 경우 시간 diversity와 수신 알고리즘에 따른 효과를 평가해야 합니다.

### 6.2 PBCH 채널 추정 보강

마지막 PBCH symbol인 `l=3`은 기존 SSS가 있는 `l=2`와 추가 관측이 있는 `l=4` 사이에 위치합니다. 추가 관측을 기존 DM-RS와 결합하여 시간 interpolation과 추정 잡음 억제에 활용할 수 있습니다.

SSS를 정확히 판별한 뒤에는 추가 symbol의 중앙 127 RE도 알려진 reference로 활용할 수 있습니다. 양쪽 E-RS 96 RE와 합치면, 추가 symbol 하나에서 총 223개 RE의 알려진 신호를 이용할 수 있습니다. 단, 17개 zero RE에 대해서는 직접적인 채널 관측이 없습니다.

기존 NR 신호를 대상으로 SSS와 DM-RS를 함께 사용하는 채널 추정 연구가 보고되어 있으나, 해당 결과는 본 문서의 5-symbol 구성을 검증한 결과가 아닙니다.[3]

### 6.3 고속 환경

추가 관측은 채널 추적에 도움이 될 수 있지만, `l=2`와 `l=4`의 SSS 사이에는 두 symbol 간격이 있습니다. 큰 Doppler spread에서 두 관측을 동일한 채널로 가정하면 오히려 추정 오차가 증가할 수 있습니다.

관측 시점별 채널을 구분하고 시간 상관성을 반영하여 결합해야 합니다. 특히 `l=4` 관측은 `l=3` PBCH에 더 가깝기 때문에, 모든 PBCH symbol에 동일한 가중치로 적용하지 않는 것이 적절합니다.

본 배치는 symbol 내부의 채널 변화에 따른 ICI를 직접 제거하지 않습니다.

### 6.4 긴 delay spread

양쪽 대역의 조밀한 E-RS는 주파수 선택성이 큰 채널에서 추가 정보를 제공합니다. 다만 기존 DM-RS보다 늦은 시점의 관측이므로 시간 변화와 주파수 변화의 영향을 함께 고려해야 합니다.

점유 대역폭과 CP는 유지되므로, 지연 해상도나 CP가 수용할 수 있는 delay spread가 직접 증가하지 않습니다. CP를 초과하는 채널의 ISI도 별도로 처리해야 합니다.

## 7. NR 호환성과 자원 충돌 처리

### 7.1 유지하는 요소와 새로 필요한 요소

| 구분 | 내용 |
|---|---|
| 유지하는 요소 | 기존 SSB timing, PSS·SSS mapping, PBCH data mapping, 기존 PBCH DM-RS 및 PBCH coding을 유지합니다. |
| 새로 필요한 요소 | 추가 signal의 위치, sequence, 전력, port 관계, 존재 판정 및 수신 절차를 정의해야 합니다. |
| 기존 UE의 동작 | 원래 4-symbol SSB를 처리합니다. 추가 자원이 해당 UE의 다른 수신 절차와 충돌하지 않도록 네트워크가 관리해야 합니다. |
| 지원 UE의 동작 | 추가 symbol을 관측하고 SSS 검출 및 PBCH 채널 추정에 활용합니다. |

기존 SSB RE를 보존하는 것만으로 모든 backward compatibility가 입증되는 것은 아닙니다. Legacy UE의 검출, 측정, AGC 및 인접 자원 수신에 미치는 영향을 검증해야 합니다.

### 7.2 연속 SSB candidate와의 충돌

일부 NR SSB candidate는 4-symbol 간격으로 배치됩니다. 예를 들어 Case B에는 시작 symbol index가 4와 8인 candidate가 있습니다. 시작 index가 4인 SSB는 4–7을 사용하므로, 즉시 추가한 symbol 8은 다음 candidate의 시작 위치와 겹칩니다.[2]

기본 운용 규칙은 다음과 같습니다.

1. 기존 SSB 시작 위치를 이동하지 않습니다.
2. 바로 뒤에 사용 가능한 DL symbol이 있는 SSB에만 확장을 적용합니다.
3. 다음 SSB candidate가 실제로 전송되거나 다른 필수 자원이 겹치면 확장을 생략합니다.
4. CORESET0, PDSCH, 다른 reference signal 및 UL 자원과의 충돌을 방지합니다.
5. 확장 symbol을 배치하기 위해 SSB candidate를 비활성화한다면, beam 수와 beam sweep 지연에 미치는 영향을 별도로 평가합니다.

별도의 offset에 보강 signal을 배치하는 변형도 가능하지만, 탐색 후보와 시간 간격이 늘어납니다. 최소 복잡도 설계에서는 즉시 뒤에 배치하는 단일 offset을 우선 검증합니다.

### 7.3 PBCH 복호 전의 확장 발견

초기 SSS 검출과 PBCH 복조를 보조하려면, 확장 활성화 정보를 SIB1에서만 제공해서는 안 됩니다. 지원 UE가 사전에 아는 상대 위치와 검출 규칙으로 확장 signal을 탐색할 수 있어야 합니다.

확장 지원 UE가 정해진 위치를 선택적으로 탐색하고, 확장 signal이 없으면 기존 처리로 복귀하는 방식을 기본으로 제안합니다. 첫 접근 이후의 운용을 위해 상위 계층에서 활성화 정보를 제공하는 방식은 보조적으로 사용할 수 있습니다.

## 8. Overhead와 처리 지연

| 항목 | 기존 | 제안 | 변화 |
|---|---:|---:|---|
| 관측 구간 | 4 symbols | 5 symbols | 25% 증가합니다. |
| SSS RE | 127 | 254 | 127 RE가 추가됩니다. |
| 기존 PBCH DM-RS RE | 144 | 144 | 유지됩니다. |
| E-RS RE | 0 | 96 | 96 RE가 추가됩니다. |
| PBCH data RE | 432 | 432 | 유지됩니다. |
| 추가 직사각형 자원 영역 | 0 | 240 RE | 223 RE에 signal을 전송하고 17 RE는 0으로 둡니다. |

기존 PBCH DM-RS와 E-RS의 RE 수를 합치면 144개에서 240개로 약 66.7% 증가합니다. 이는 reference RE 수에 대한 계산이며, 채널 추정 정확도나 coverage가 같은 비율로 증가한다는 의미는 아닙니다.

추가 signal을 사용하는 복호 결과는 적어도 한 symbol을 더 수신한 뒤 얻습니다. 기존 4-symbol 복호를 먼저 시도하고 실패 시 확장 관측을 활용하는 구현도 가능합니다.

실제 burst overhead는 25%보다 커질 수 있습니다. 확장을 위해 다음 SSB candidate를 비우거나 다른 자원을 재배치해야 하는 경우까지 포함하여 평가해야 합니다.

## 9. 대안 비교

| 대안 | Symbol 증가 | 평가 |
|---|---:|---|
| 기존 SSB 뒤에 SSS 반복 + E-RS 추가 | +1 | 기존 SSB mapping을 보존할 수 있으므로 우선 검토합니다. |
| 기존 PBCH RE를 SSS 또는 DM-RS로 대체 | 0 | PBCH mapping과 복호 조건을 변경하므로 legacy 호환성에 불리합니다. |
| PSS 주변 zero RE 활용 | 0 | 기존 zero 가정을 변경하며, 빈 113 RE만으로 길이 127 SSS 전체를 담을 수 없습니다. |
| 인접 주파수 대역에 확장 signal 배치 | 0 | 추가 대역폭과 수신 대역 확장이 필요하며, SSB 주변 자원에 대한 규격 검토가 필요합니다. |

240-subcarrier 대역을 유지하고, 기존 RE를 변경하지 않으며, 완전한 길이 127 SSS 반복과 추가 reference를 RE 중첩 없이 넣는 조건에서는 1-symbol 추가가 가장 단순한 최소 확장입니다. 대역 확장, signal superposition 또는 기존 자원 변경을 허용하는 모든 설계에 대한 절대적 최소값을 주장하는 것은 아닙니다.

## 10. 성능 검증 계획

### 10.1 비교 구성

1. 기존 4-symbol SSB를 baseline으로 사용합니다.
2. 기존 SSB의 SSS를 채널 추정에 활용하는 수신기도 baseline에 포함합니다.
3. 추가 symbol에 SSS만 반복하는 구성을 평가합니다.
4. 추가 symbol에 E-RS만 배치하는 구성을 평가합니다.
5. SSS 반복과 E-RS를 함께 사용하는 제안 구성을 평가합니다.

SSS-only와 E-RS-only 비교에서는 사용 RE 수와 에너지 차이를 명시하여 각각의 기여를 구분합니다.

### 10.2 시험 조건

- 동일 RE EPRE 조건과 동일 총 송신 에너지 조건을 모두 평가합니다.
- Low SNR, 다양한 delay spread, fractional delay 및 timing error를 포함합니다.
- Residual CFO, phase noise, Doppler shift 및 Doppler spread를 포함합니다.
- 동일 PSS를 사용하는 인접 셀과 서로 다른 SSS를 사용하는 인접 셀의 간섭을 포함합니다.
- 확장 signal이 없는 위치에 noise 또는 다른 전송이 존재하는 경우를 포함합니다.
- 연속한 SSB candidate를 사용하는 beam sweep 조건을 포함합니다.

### 10.3 주요 지표

| 지표 | 확인 목적 |
|---|---|
| SSS missed detection 및 false detection | Cell ID 판별이 실제로 개선되는지 확인합니다. |
| 확장 존재 판정 오류율 | 확장 signal을 잘못 결합할 위험을 확인합니다. |
| PBCH 채널 추정 NMSE | 추가 관측의 기여를 확인합니다. |
| PBCH BLER | 최종 복조 성능의 개선을 확인합니다. |
| 전체 initial access 성공률과 지연 | 단계별 개선이 실제 접근 성능으로 이어지는지 확인합니다. |
| Legacy UE 성능 변화 | 기존 UE와의 공존 가능성을 확인합니다. |
| Burst 전체 자원 및 에너지 | SSB candidate 손실을 포함한 비용을 확인합니다. |

## 11. 후속 결정 사항

- E-RS sequence generator 및 초기화 식을 확정해야 합니다.
- E-RS에 SSB index를 포함할지 결정해야 합니다.
- SSS, E-RS 및 기존 PBCH DM-RS 사이의 EPRE 관계를 확정해야 합니다.
- 추가 symbol의 port 관계와 위상 연속성 조건을 규정해야 합니다.
- 확장 존재 판정, 결합 가중치 및 fallback 기준을 설계해야 합니다.
- SSB pattern별 확장 허용 위치와 다른 채널의 자원 예약 절차를 정의해야 합니다.
- 3 MHz 등의 punctured SSB 및 기타 특수 구성에 대한 적용 여부를 별도로 결정해야 합니다.

## 12. 참고 자료

1. [3GPP TS 38.211 V19.1.0, §7.4.1.4 및 §7.4.3](https://www.etsi.org/deliver/etsi_ts/138200_138299/138211/19.01.00_60/ts_138211v190100p.pdf): 기존 PBCH DM-RS와 SS/PBCH block의 sequence 및 resource mapping을 확인하는 기준입니다.
2. [3GPP TS 38.213 V18.6.0, §4.1](https://www.etsi.org/deliver/etsi_ts/138200_138299/138213/18.06.00_60/ts_138213v180600p.pdf): SSB candidate의 시간 위치를 확인하는 기준입니다.
3. [Ohiwa 외, “Block Error Rate Performance of Carrier Frequency Offset Compensation and Channel Estimation Methods Using Synchronization Signals for NR PBCH”, IEICE, 2025](https://globals.ieice.org/en_transactions/communications/10.23919/transcom.2024EBP3195/_f): 기존 synchronization signal과 DM-RS를 결합한 PBCH 채널 추정의 관련 연구입니다.

본 제안은 위 규격에 정의된 기존 구조를 기준으로 도출한 설계안입니다. 참고 자료가 본 확장 구조의 표준 채택, 성능 또는 신규성을 입증하는 것은 아닙니다.
