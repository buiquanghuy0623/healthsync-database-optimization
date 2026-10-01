-- ============================================================
-- DỰ ÁN HEALTHSYNC - TỐI ƯU HÓA CƠ SỞ DỮ LIỆU
-- File script chứa toàn bộ DDL (cấu trúc) và DML (kịch bản mô phỏng)
-- ============================================================

CREATE DATABASE IF NOT EXISTS healthsync_db;
USE healthsync_db;

-- 1. BẢNG BỆNH NHÂN (PATIENTS)
DROP TABLE IF EXISTS Patients;
CREATE TABLE Patients (
    patient_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    phone VARCHAR(15) NOT NULL
);

-- 2. BẢNG BÁC SĨ (DOCTORS)
DROP TABLE IF EXISTS Doctors;
CREATE TABLE Doctors (
    doctor_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    specialty VARCHAR(50)
);

-- 3. BẢNG LỊCH HẸN (APPOINTMENTS) - ĐÃ TỐI ƯU CẤU TRÚC
DROP TABLE IF EXISTS Prescriptions; -- Xóa bảng phụ trước do ràng buộc FK
DROP TABLE IF EXISTS Appointments;

CREATE TABLE Appointments (
    appointment_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT NOT NULL,
    doctor_id INT NOT NULL,
    appointment_date DATETIME NOT NULL,
    
    -- Xử lý vòng đời trạng thái bằng ENUM
    status ENUM('PENDING', 'CONFIRMED', 'CHECKED_IN', 'COMPLETED', 'CANCELLED') DEFAULT 'PENDING',
    
    -- Các trường dữ liệu tài chính & lý do hủy (Dùng DECIMAL tránh lỗi làm tròn Float)
    deposit_amount DECIMAL(10,2) DEFAULT 0.00,
    penalty_fee DECIMAL(10,2) DEFAULT 0.00,
    cancel_reason VARCHAR(255) NULL,
    
    FOREIGN KEY (patient_id) REFERENCES Patients(patient_id) ON DELETE RESTRICT,
    FOREIGN KEY (doctor_id) REFERENCES Doctors(doctor_id) ON DELETE RESTRICT
);

-- 4. BẢNG ĐƠN THUỐC (PRESCRIPTIONS) - BỔ SUNG MỚI
CREATE TABLE Prescriptions (
    prescription_id INT AUTO_INCREMENT PRIMARY KEY,
    appointment_id INT NOT NULL UNIQUE, -- Quan hệ 1-1 với Lịch hẹn
    medication_details TEXT NOT NULL,
    issued_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (appointment_id) REFERENCES Appointments(appointment_id) ON DELETE CASCADE
);

-- ============================================================
-- KỊCH BẢN MÔ PHỎNG VẬN HÀNH & CHÉP LIỆU (DML)
-- ============================================================

-- Thêm dữ liệu mẫu ban đầu
INSERT INTO Patients (full_name, phone) VALUES ('Nguyễn Văn A', '0901234567'), ('Lê Thị B', '0987654321');
INSERT INTO Doctors (full_name, specialty) VALUES ('Bác sĩ Chuyên khoa X', 'Nội khoa');

-- KỊCH BẢN 1: Luồng khám bệnh thành công trọn vẹn
-- B1: Tạo lịch hẹn (PENDING) cọc 500.000đ
INSERT INTO Appointments (patient_id, doctor_id, appointment_date, status, deposit_amount)
VALUES (1, 1, '2026-10-05 09:00:00', 'PENDING', 500000.00);

-- B2: Khách đến khám (Update -> CHECKED_IN)
UPDATE Appointments SET status = 'CHECKED_IN' WHERE appointment_id = 1;

-- B3: Bác sĩ khám xong (Update -> COMPLETED)
UPDATE Appointments SET status = 'COMPLETED' WHERE appointment_id = 1;

-- B4: Bác sĩ kê đơn thuốc cho lịch hẹn 1
INSERT INTO Prescriptions (appointment_id, medication_details)
VALUES (1, 'Paracetamol 500mg (10 viên), Vitamin C (10 viên)');


-- KỊCH BẢN 2: Luồng hủy lịch và phạt cọc
-- B1: Tạo lịch hẹn ban đầu cọc 300.000đ
INSERT INTO Appointments (patient_id, doctor_id, appointment_date, status, deposit_amount)
VALUES (2, 1, '2026-10-06 14:00:00', 'CONFIRMED', 300000.00);

-- B2: Bệnh nhân hủy lịch -> Cập nhật CANCELLED, lý do và trừ phí phạt 150.000đ
UPDATE Appointments 
SET status = 'CANCELLED',
    cancel_reason = 'Bận việc đột xuất',
    penalty_fee = 150000.00
WHERE appointment_id = 2;


-- ============================================================
-- CÂU LỆNH TRUY VẤN KIỂM TRA (SELECT)
-- ============================================================

-- Truy vấn xem danh sách bệnh nhân đã hoàn tất khám kèm chi tiết đơn thuốc
SELECT 
    p.full_name AS ten_benh_nhan,
    d.full_name AS bác_sĩ_khám,
    a.appointment_date AS ngay_kham,
    a.status AS trang_thai,
    pr.medication_details AS đơn_thuốc,
    pr.issued_date AS ngay_ke_don
FROM Appointments a
JOIN Patients p ON a.patient_id = p.patient_id
JOIN Doctors d ON a.doctor_id = d.doctor_id
JOIN Prescriptions pr ON a.appointment_id = pr.appointment_id
WHERE a.status = 'COMPLETED';

-- Truy vấn thống kê tiền phạt hủy lịch
SELECT 
    p.full_name,
    a.deposit_amount AS tien_coc,
    a.penalty_fee AS tien_phat,
    (a.deposit_amount - a.penalty_fee) AS tien_tra_lai,
    a.cancel_reason AS ly_do_huy
FROM Appointments a
JOIN Patients p ON a.patient_id = p.patient_id
WHERE a.status = 'CANCELLED';
