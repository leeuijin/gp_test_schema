-- ✔ LOT 기반 완전 Traceability
-- ✔ Motion 최소화
-- ✔ AO Columnar + ZSTD 압축 (level 7)
-- ✔ 실제 MES 운영에 가까운 구조

-- MES는 “제품 분석”이 아니라 추적 검사 및 이력확인이 핵심(역추적 / 순추적이 핵심)
-- 특정 LOT → 원자재 → 설비 → 검사 → 출하 

-- 모든 Fact는 lot_id 기준 분산
-- Raw Material도 LOT 단위 입고/사용 이력 분리
-- 모든 대용량 테이블은 AO Columnar + ZSTD
/*
customers: 출하 고객사 마스터 테이블
equipment: 생산 설비 마스터 테이블
equipment_log: LOT 생산 중 설비 이벤트 로그 테이블 (대용량 시계열 데이터)
lot_material_usage: LOT별 원자재 사용 이력 테이블 (Traceability 핵심)
production_lot: 생산 LOT 기본 정보 테이블 (MES 중심 테이블)
products: 배터리 제품 마스터 테이블 (셀/모듈/팩)
quality_inspection: LOT 품질 검사 결과 테이블
raw_materials: 원자재 마스터 테이블
shipments: LOT 출하 정보 테이블
*/

-- ==========================================================================
-- #Dimension 테이블 (상대적으로 작음 → Row AO 유지 가능)
-- ==========================================================================

CREATE TABLE products (
    product_id INT,
    product_name VARCHAR(100),
    product_type VARCHAR(20),
    capacity_mah INT,
    voltage NUMERIC(6,2)
)
DISTRIBUTED BY (product_id);

CREATE TABLE equipment (
    equipment_id INT,
    equipment_name VARCHAR(100),
    line_name VARCHAR(50)
)
DISTRIBUTED BY (equipment_id);

CREATE TABLE customers (
    customer_id INT,
    customer_name VARCHAR(100),
    country VARCHAR(50)
)
DISTRIBUTED BY (customer_id);

CREATE TABLE raw_materials (
    material_id INT,
    material_name VARCHAR(100),
    supplier_name VARCHAR(100)
)
DISTRIBUTED BY (material_id);

-- ==========================================================================
-- #Fact 테이블
-- ==========================================================================

CREATE TABLE production_lot (
    lot_id BIGINT,
    lot_number VARCHAR(50),
    product_id INT,
    equipment_id INT,
    production_date DATE,
    quantity INT,
    status VARCHAR(20)
)
WITH (
    appendoptimized=true,
    orientation=column,
    compresstype=zstd,
    compresslevel=7
)
DISTRIBUTED BY (lot_id)
PARTITION BY RANGE (production_date)
(
    START ('2026-01-01') END ('2026-12-31') EVERY (INTERVAL '1 month')
);

-- LOT별 원자재 사용
CREATE TABLE lot_material_usage (
    id BIGINT,
    lot_id BIGINT,
    material_id INT,
    material_lot_no VARCHAR(50),
    quantity_used NUMERIC(10,2)
)
WITH (
    appendoptimized=true,
    orientation=column,
    compresstype=zstd,
    compresslevel=7
)
DISTRIBUTED BY (lot_id);

-- 품질 검사 테이블

CREATE TABLE quality_inspection (
    inspection_id BIGINT,
    lot_id BIGINT,
    inspection_time TIMESTAMP,
    test_type VARCHAR(50),
    result VARCHAR(20),
    defect_rate NUMERIC(5,2)
)
WITH (
    appendoptimized=true,
    orientation=column,
    compresstype=zstd,
    compresslevel=7
)
DISTRIBUTED BY (lot_id);

-- 설비 로그 (MES 핵심 대용량)

CREATE TABLE equipment_log (
    log_id BIGINT,
    lot_id BIGINT,
    equipment_id INT,
    event_time TIMESTAMP,
    temperature NUMERIC(5,2),
    pressure NUMERIC(5,2),
    status VARCHAR(20)
)
WITH (
    appendoptimized=true,
    orientation=column,
    compresstype=zstd,
    compresslevel=7
)
DISTRIBUTED BY (lot_id);

-- 출하

CREATE TABLE shipments (
    shipment_id BIGINT,
    lot_id BIGINT,
    customer_id INT,
    shipment_date DATE,
    quantity INT
)
WITH (
    appendoptimized=true,
    orientation=column,
    compresstype=zstd,
    compresslevel=7
)
DISTRIBUTED BY (lot_id);

-- ==========================================================================
-- 코맨트 추가
-- ==========================================================================

COMMENT ON TABLE products IS '배터리 제품 마스터 (셀/모듈/팩)';

COMMENT ON COLUMN products.product_id IS '제품 고유 ID';
COMMENT ON COLUMN products.product_name IS '제품명';
COMMENT ON COLUMN products.product_type IS '제품 유형 (CELL, MODULE, PACK)';
COMMENT ON COLUMN products.capacity_mah IS '정격 용량 (mAh)';
COMMENT ON COLUMN products.voltage IS '정격 전압 (V)';

COMMENT ON TABLE equipment IS '생산 설비 마스터';

COMMENT ON COLUMN equipment.equipment_id IS '설비 고유 ID';
COMMENT ON COLUMN equipment.equipment_name IS '설비명';
COMMENT ON COLUMN equipment.line_name IS '생산 라인명';

COMMENT ON TABLE customers IS '출하 고객사 마스터';

COMMENT ON COLUMN customers.customer_id IS '고객사 고유 ID';
COMMENT ON COLUMN customers.customer_name IS '고객사명';
COMMENT ON COLUMN customers.country IS '국가';

COMMENT ON TABLE raw_materials IS '원자재 마스터';

COMMENT ON COLUMN raw_materials.material_id IS '원자재 ID';
COMMENT ON COLUMN raw_materials.material_name IS '원자재명';
COMMENT ON COLUMN raw_materials.supplier_name IS '공급업체명';

COMMENT ON TABLE production_lot IS '생산 LOT 기본 정보 (MES 중심 테이블)';

COMMENT ON COLUMN production_lot.lot_id IS 'LOT 내부 식별자 (분산키)';
COMMENT ON COLUMN production_lot.lot_number IS 'LOT 번호 (업무상 식별번호)';
COMMENT ON COLUMN production_lot.product_id IS '생산 제품 ID';
COMMENT ON COLUMN production_lot.equipment_id IS '주요 사용 설비 ID';
COMMENT ON COLUMN production_lot.production_date IS '생산일자';
COMMENT ON COLUMN production_lot.quantity IS '생산 수량';
COMMENT ON COLUMN production_lot.status IS 'LOT 상태 (COMPLETED, IN_PROGRESS, SCRAPPED)';

COMMENT ON TABLE lot_material_usage IS 'LOT별 원자재 사용 이력 (Traceability 핵심)';

COMMENT ON COLUMN lot_material_usage.id IS 'PK 역할 ID';
COMMENT ON COLUMN lot_material_usage.lot_id IS '생산 LOT ID';
COMMENT ON COLUMN lot_material_usage.material_id IS '원자재 ID';
COMMENT ON COLUMN lot_material_usage.material_lot_no IS '원자재 LOT 번호';
COMMENT ON COLUMN lot_material_usage.quantity_used IS '사용 수량';

COMMENT ON TABLE quality_inspection IS 'LOT 품질 검사 결과';

COMMENT ON COLUMN quality_inspection.inspection_id IS '검사 ID';
COMMENT ON COLUMN quality_inspection.lot_id IS '생산 LOT ID';
COMMENT ON COLUMN quality_inspection.inspection_time IS '검사 수행 시각';
COMMENT ON COLUMN quality_inspection.test_type IS '검사 유형 (Voltage, Charge 등)';
COMMENT ON COLUMN quality_inspection.result IS '검사 결과 (PASS/FAIL)';
COMMENT ON COLUMN quality_inspection.defect_rate IS '불량률 (%)';

COMMENT ON TABLE equipment_log IS 'LOT 생산 중 설비 이벤트 로그 (대용량 시계열)';

COMMENT ON COLUMN equipment_log.log_id IS '로그 ID';
COMMENT ON COLUMN equipment_log.lot_id IS '생산 LOT ID';
COMMENT ON COLUMN equipment_log.equipment_id IS '설비 ID';
COMMENT ON COLUMN equipment_log.event_time IS '이벤트 발생 시각';
COMMENT ON COLUMN equipment_log.temperature IS '공정 온도';
COMMENT ON COLUMN equipment_log.pressure IS '공정 압력';
COMMENT ON COLUMN equipment_log.status IS '설비 상태 (NORMAL/ALERT)';

COMMENT ON TABLE shipments IS 'LOT 출하 정보';

COMMENT ON COLUMN shipments.shipment_id IS '출하 ID';
COMMENT ON COLUMN shipments.lot_id IS '생산 LOT ID';
COMMENT ON COLUMN shipments.customer_id IS '고객사 ID';
COMMENT ON COLUMN shipments.shipment_date IS '출하일자';
COMMENT ON COLUMN shipments.quantity IS '출하 수량';

-- 코맨트 확인 방법
-- SELECT obj_description('production_lot'::regclass);


-- ==========================================================================
-- 테스트 더미 데이터 생성
-- ==========================================================================

INSERT INTO products
SELECT 
    i,
    'Battery_Model_'||i,
    CASE WHEN i%3=0 THEN 'CELL'
         WHEN i%3=1 THEN 'MODULE'
         ELSE 'PACK' END,
    3000 + i*500,
    3.7 + (i*0.1)
FROM generate_series(1,10) i;

INSERT INTO equipment
SELECT 
    i,
    'Equipment_'||i,
    'Line_'||(i%3+1)
FROM generate_series(1,5) i;

INSERT INTO customers
SELECT 
    i,
    'Customer_'||i,
    CASE WHEN i%3=0 THEN 'USA'
         WHEN i%3=1 THEN 'Korea'
         ELSE 'Germany' END
FROM generate_series(1,10) i;

INSERT INTO raw_materials
SELECT 
    i,
    'Material_'||i,
    'Supplier_'||((i%5)+1)
FROM generate_series(1,20) i;

INSERT INTO production_lot
SELECT 
    gs AS lot_id,
    'LOT-'||to_char(gs,'FM000000') AS lot_number,
    (random()*9+1)::int AS product_id,
    (random()*4+1)::int AS equipment_id,
    DATE '2026-01-01' + (random()*180)::int AS production_date,
    (random()*9000+1000)::int AS quantity,
    CASE WHEN random() < 0.92 THEN 'COMPLETED'
         WHEN random() < 0.97 THEN 'IN_PROGRESS'
         ELSE 'SCRAPPED' END
FROM generate_series(1,5000) gs;

--LOT당 평균 3건 → 약 15,000건

INSERT INTO lot_material_usage
SELECT 
    row_number() OVER() AS id,
    pl.lot_id,
    (random()*19+1)::int AS material_id,
    'MATLOT-'||to_char(pl.lot_id,'FM000000')||'-'||gs,
    round((random()*500+50)::numeric, 2)
FROM production_lot pl,
     generate_series(1,3) gs;

-- LOT당 1~2건 → 약 7500건

INSERT INTO quality_inspection
SELECT 
    row_number() OVER() AS inspection_id,
    pl.lot_id,
    pl.production_date + (random()*3)::int,
    CASE WHEN random() < 0.7 THEN 'Voltage Test'
         ELSE 'Charge/Discharge Test' END,
    CASE WHEN random() < 0.95 THEN 'PASS'
         ELSE 'FAIL' END,
    round((random()*3)::numeric,2)
FROM production_lot pl,
     generate_series(1,2);

-- LOT당 10건 → 50,000건 (MES 시뮬레이션용) 

INSERT INTO equipment_log
SELECT 
    row_number() OVER() AS log_id,
    pl.lot_id,
    pl.equipment_id,
    pl.production_date + (gs || ' minutes')::interval,
    round((20 + random()*15)::numeric,2),
    round((1 + random()*5)::numeric,2),
    CASE WHEN random() < 0.98 THEN 'NORMAL'
         ELSE 'ALERT' END
FROM production_lot pl,
     generate_series(1,10) gs;

-- 약 70% 출하 → ~3500건

INSERT INTO shipments
SELECT 
    pl.lot_id AS shipment_id,
    pl.lot_id,
    (random()*9+1)::int,
    pl.production_date + 2,
    (pl.quantity*0.8)::int
FROM production_lot pl
WHERE random() < 0.7;

-- SKEW 확인

SELECT gp_segment_id, count(*)
FROM production_lot
GROUP BY 1
ORDER BY 1;

ANALYZE production_lot;
ANALYZE lot_material_usage;
ANALYZE quality_inspection;
ANALYZE equipment_log;
ANALYZE shipments;

-- | 테이블                | 예상 건수  |
-- | ------------------ | ------ |
-- | production_lot     | 5,000  |
-- | lot_material_usage | 15,000 |
-- | quality_inspection | ~7,500 |
-- | equipment_log      | 50,000 |
-- | shipments          | ~3,500 |