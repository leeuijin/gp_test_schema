# 📊 Greenplum MES ERD (LOT 기반 Traceability)

본 모델은 제조 MES 환경에서 **LOT 단위 추적(Traceability)**을 중심으로 설계되었습니다.
모든 Fact 테이블은 `lot_id` 기준으로 분산되어 있으며,
원자재 → 생산 → 검사 → 출하까지 전체 흐름을 추적할 수 있습니다.

---

## 🧱 ERD Diagram (Text Version)

```
                +------------------+
                |    products      |
                |------------------|
                | product_id (PK)  |
                | product_name     |
                | product_type     |
                | capacity_mah     |
                | voltage          |
                +--------+---------+
                         |
                         |
                         v
                +------------------+
                |  production_lot  |
                |------------------|
                | lot_id (PK)      |
                | lot_number       |
                | product_id (FK)  |
                | equipment_id(FK) |
                | production_date  |
                | quantity         |
                | status           |
                +----+------+------+ 
                     |      |     
     ----------------      -------------------------
     |                              |              |
     v                              v              v

+---------------------+   +------------------+   +----------------------+
| lot_material_usage  |   | quality_inspection | |    equipment_log     |
|---------------------|   |------------------| |----------------------|
| id (PK)             |   | inspection_id(PK)| | log_id (PK)          |
| lot_id (FK)         |   | lot_id (FK)      | | lot_id (FK)          |
| material_id (FK)    |   | inspection_time  | | equipment_id (FK)    |
| material_lot_no     |   | test_type        | | event_time           |
| quantity_used       |   | result           | | temperature          |
+----------+----------+   | defect_rate      | | pressure             |
           |              +------------------+ | status               |
           |                                   +----------+-----------+
           v                                              |
+---------------------+                                  |
|   raw_materials     |                                  |
|---------------------|                                  |
| material_id (PK)    |                                  |
| material_name       |                                  |
| supplier_name       |                                  |
+---------------------+                                  |
                                                         v
                                                +------------------+
                                                |    equipment     |
                                                |------------------|
                                                | equipment_id(PK) |
                                                | equipment_name   |
                                                | line_name        |
                                                +------------------+

                         |
                         v
                +------------------+
                |    shipments     |
                |------------------|
                | shipment_id (PK) |
                | lot_id (FK)      |
                | customer_id(FK)  |
                | shipment_date    |
                | quantity         |
                +--------+---------+
                         |
                         v
                +------------------+
                |    customers     |
                |------------------|
                | customer_id (PK) |
                | customer_name    |
                | country          |
                +------------------+
```

---

## 🔗 관계 설명 (Relationship)

* `production_lot` (중심 테이블)

  * 모든 데이터는 `lot_id` 기준으로 연결됨
* `products` → `production_lot`

  * 제품 정보 연결
* `equipment` → `production_lot`, `equipment_log`

  * 생산 설비 및 이벤트 로그 연결
* `raw_materials` → `lot_material_usage`

  * 원자재 사용 이력 관리
* `lot_material_usage`

  * LOT별 원자재 사용 (Traceability 핵심)
* `quality_inspection`

  * LOT 품질 검사 결과
* `equipment_log`

  * 생산 중 발생한 설비 로그 (시계열 데이터)
* `shipments` → `customers`

  * 출하 및 고객 정보 연결

---

## 🔍 Traceability 흐름

### ▶ 역추적 (Backward Traceability)

```
출하 → LOT → 원자재 → 설비 → 품질
```

### ▶ 순추적 (Forward Traceability)

```
원자재 → LOT → 검사 → 출하
```

---

## 🧠 설계 특징

* 모든 Fact 테이블 `DISTRIBUTED BY (lot_id)`
* 대용량 테이블:

  * AO Columnar
  * ZSTD 압축 (level 7)
* MES 핵심 요구사항 반영:

  * LOT 기반 완전 추적
  * 시계열 로그 처리 최적화
  * 분석 + 운영 동시 지원

---

## 🚀 활용 예시

* 특정 LOT의 불량 원인 분석
* 원자재 LOT 기준 영향 범위 추적
* 설비 이상 이벤트 기반 품질 문제 분석
* 고객 클레임 대응을 위한 빠른 이력 조회

---
